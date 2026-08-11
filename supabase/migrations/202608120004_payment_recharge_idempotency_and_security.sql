-- 202608120004_payment_recharge_idempotency_and_security.sql
-- AUTHORITATIVE PAYMENT RECHARGE IDEMPOTENCY, SECURITY & PER-TRANSACTION CAP ENGINE

-- 1. Ensure public.payments table has all required columns and constraints
CREATE TABLE IF NOT EXISTS public.payments (
  payment_id text PRIMARY KEY,
  order_id text NOT NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  amount numeric NOT NULL,
  vip_plan text NOT NULL,
  status text NOT NULL DEFAULT 'Success',
  purchase_date timestamptz DEFAULT now() NOT NULL,
  gateway_response jsonb
);

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select payments for self and admins" ON public.payments;
CREATE POLICY "Allow select payments for self and admins" ON public.payments
  FOR SELECT USING (auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.admins WHERE id = auth.uid()));

-- 2. Master Verified Payment Recharge & Fulfillment RPC
CREATE OR REPLACE FUNCTION public.process_verified_payment_recharge_rpc(
  p_user_id        uuid,
  p_payment_id     text,
  p_amount         numeric,
  p_coins_amount   integer,
  p_product_name   text DEFAULT '50,000 Gold Coins Package',
  p_order_id       text DEFAULT NULL,
  p_signature      text DEFAULT NULL,
  p_secret_key     text DEFAULT 'ehrQ4edUdNzEZqtTE334Lcsf'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_computed_sig     text;
  v_existing_pay     RECORD;
  v_existing_pur     RECORD;
  v_wallet           RECORD;
  v_prev_coins       integer := 0;
  v_new_coins        integer := 0;
  v_tx_id            text;
BEGIN
  -- Validate basic inputs
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid user ID');
  END IF;

  IF p_payment_id IS NULL OR length(trim(p_payment_id)) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Missing or empty payment ID');
  END IF;

  IF p_amount <= 0 OR p_coins_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid payment or coin amount');
  END IF;

  -- Per-transaction cap: single recharge package cannot exceed 6,000 coins per transaction (allows 5,000 base + 599 bonus coins)
  IF p_coins_amount > 6000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Recharge coins amount exceeds single transaction cap of 6,000 coins');
  END IF;

  -- 1. Idempotency Check on public.purchases
  SELECT * INTO v_existing_pur
  FROM public.purchases
  WHERE payment_id = p_payment_id
  FOR UPDATE;

  IF FOUND THEN
    -- Check user match
    IF v_existing_pur.user_id <> p_user_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'Payment ID belongs to a different user');
    END IF;

    -- Check amount match
    IF v_existing_pur.amount <> p_amount AND v_existing_pur.final_amount <> p_amount THEN
      RETURN jsonb_build_object('success', false, 'error', 'Payment ID amount mismatch');
    END IF;

    -- Check status
    IF v_existing_pur.status = 'Success' THEN
      -- Fetch current balance for idempotent response
      SELECT COALESCE(coins_balance, gold_coins, 0) INTO v_prev_coins
      FROM public.wallets WHERE id = p_user_id;

      RETURN jsonb_build_object(
        'success', true,
        'already_processed', true,
        'payment_id', p_payment_id,
        'coins_added', 0,
        'new_balance', COALESCE(v_prev_coins, 0),
        'message', 'Payment already processed successfully'
      );
    ELSIF v_existing_pur.status = 'Failed' THEN
      RETURN jsonb_build_object('success', false, 'error', 'Payment marked failed cannot be fulfilled');
    END IF;
  END IF;

  -- 2. Check public.payments table if recorded by webhook/gateway
  SELECT * INTO v_existing_pay
  FROM public.payments
  WHERE payment_id = p_payment_id
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing_pay.user_id <> p_user_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'Payment ID user mismatch');
    END IF;

    IF v_existing_pay.amount <> p_amount THEN
      RETURN jsonb_build_object('success', false, 'error', 'Payment ID amount mismatch');
    END IF;

    IF v_existing_pay.status = 'Failed' THEN
      RETURN jsonb_build_object('success', false, 'error', 'Unverified or failed payment status');
    END IF;
  ELSE
    -- If not found in payments, check if a valid Razorpay signature is provided
    IF p_order_id IS NOT NULL AND p_signature IS NOT NULL THEN
      BEGIN
        v_computed_sig := encode(extensions.hmac((p_order_id || '|' || p_payment_id)::bytea, p_secret_key::bytea, 'sha256'), 'hex');
      EXCEPTION WHEN OTHERS THEN
        v_computed_sig := encode(public.hmac((p_order_id || '|' || p_payment_id)::bytea, p_secret_key::bytea, 'sha256'), 'hex');
      END;

      IF LOWER(v_computed_sig) <> LOWER(p_signature) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Razorpay signature verification failed');
      END IF;
    ELSE
      -- Payment ID not found in verified payments table AND no valid signature -> REJECT FAKE PAYMENT
      RETURN jsonb_build_object('success', false, 'error', 'Unverified or fake payment ID');
    END IF;
  END IF;

  -- 3. Lock user wallet row for atomic update
  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.wallets (id, coins_balance, gold_coins, silver_coins_balance, silver_coins, withdrawable_balance)
    VALUES (p_user_id, 0, 0, 0, 0, 0.00)
    RETURNING * INTO v_wallet;
  END IF;

  v_prev_coins := COALESCE(v_wallet.coins_balance, v_wallet.gold_coins, 0);
  v_new_coins  := v_prev_coins + p_coins_amount;

  -- Update wallet balance (No artificial total balance cap! Multiple 50k purchases accumulate legally)
  UPDATE public.wallets
  SET coins_balance = v_new_coins,
      gold_coins    = v_new_coins
  WHERE id = p_user_id;

  v_tx_id := 'tx_pay_' || p_payment_id;

  -- Insert into public.purchases (Idempotency Record)
  INSERT INTO public.purchases (
    user_id,
    product_name,
    category,
    amount,
    final_amount,
    payment_method,
    status,
    duration,
    payment_id
  ) VALUES (
    p_user_id,
    p_product_name,
    'Coins',
    p_amount,
    p_amount,
    'Razorpay Gateway',
    'Success',
    'One-time',
    p_payment_id
  )
  ON CONFLICT (payment_id) DO UPDATE
  SET status = 'Success';

  -- Insert into public.payments if not present
  INSERT INTO public.payments (
    payment_id,
    order_id,
    user_id,
    amount,
    vip_plan,
    status,
    purchase_date,
    gateway_response
  ) VALUES (
    p_payment_id,
    COALESCE(p_order_id, 'ord_' || p_payment_id),
    p_user_id,
    p_amount,
    p_product_name,
    'Success',
    now(),
    jsonb_build_object('payment_id', p_payment_id, 'coins_added', p_coins_amount)
  )
  ON CONFLICT (payment_id) DO UPDATE
  SET status = 'Success';

  -- Record Audit Log Entry
  INSERT INTO public.wallet_transactions (
    id,
    wallet_id,
    user_id,
    currency_type,
    currency,
    amount,
    previous_balance,
    new_balance,
    type,
    source,
    transaction_id,
    reference_id,
    details,
    status,
    created_at
  ) VALUES (
    gen_random_uuid(),
    p_user_id,
    p_user_id,
    'Gold',
    'Gold',
    p_coins_amount,
    v_prev_coins,
    v_new_coins,
    'Credit',
    'VerifiedPayment',
    v_tx_id,
    p_payment_id,
    'Verified Recharge: ' || p_product_name || ' (' || p_payment_id || ')',
    'Completed',
    now()
  )
  ON CONFLICT (transaction_id) DO NOTHING;

  RETURN jsonb_build_object(
    'success', true,
    'already_processed', false,
    'payment_id', p_payment_id,
    'coins_added', p_coins_amount,
    'previous_balance', v_prev_coins,
    'new_balance', v_new_coins
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.process_verified_payment_recharge_rpc(uuid, text, numeric, integer, text, text, text, text) TO authenticated, service_role;

-- 4. Update process_authoritative_wallet_transaction to reject payment source strings without verified payment
CREATE OR REPLACE FUNCTION public.process_authoritative_wallet_transaction(
  p_user_id uuid,
  p_currency text,
  p_amount bigint,
  p_type text DEFAULT 'Credit',
  p_source text DEFAULT 'System',
  p_transaction_id text DEFAULT NULL,
  p_reference_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_wallet RECORD;
  v_prev_bal bigint := 0;
  v_new_bal bigint := 0;
  v_clean_currency text;
  v_clean_tx_id text;
  v_existing_tx RECORD;
BEGIN
  -- Validate Inputs
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid user ID');
  END IF;

  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Transaction amount must be greater than 0');
  END IF;

  -- Reject fake payment source claims (payment recharges must use process_verified_payment_recharge_rpc)
  IF LOWER(p_source) LIKE '%payment%' OR LOWER(p_source) LIKE '%razorpay%' OR LOWER(p_source) LIKE '%inapp%' THEN
    IF p_reference_id IS NULL AND p_transaction_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Payment transactions require verified payment confirmation RPC');
    END IF;
    -- Verify payment ID exists in purchases or payments with status Success
    IF NOT EXISTS (
      SELECT 1 FROM public.purchases WHERE (payment_id = p_reference_id OR payment_id = p_transaction_id) AND status = 'Success'
    ) AND NOT EXISTS (
      SELECT 1 FROM public.payments WHERE (payment_id = p_reference_id OR payment_id = p_transaction_id) AND status = 'Success'
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Unverified payment source attempt blocked');
    END IF;
  END IF;

  -- Validate Currency Type
  v_clean_currency := CASE LOWER(p_currency)
    WHEN 'silver' THEN 'Silver'
    WHEN 'silver_coins' THEN 'Silver'
    WHEN 'gold' THEN 'Gold'
    WHEN 'gold_coins' THEN 'Gold'
    WHEN 'coins' THEN 'Gold'
    ELSE 'Gold'
  END;

  -- Per-Transaction Cap: Single non-payment transaction cannot exceed 6,000 coins
  IF p_amount > 6000 THEN
    RAISE WARNING '[WALLET SECURITY ALERT] Abnormally large transaction attempt blocked: User %, Amount %, Source %', p_user_id, p_amount, p_source;
    RETURN jsonb_build_object('success', false, 'error', 'Abnormally large transaction amount rejected by security rules');
  END IF;

  -- Generate transaction ID if not provided
  v_clean_tx_id := COALESCE(p_transaction_id, 'tx_' || gen_random_uuid()::text);

  -- Idempotency Check: Avoid double crediting on retries or duplicate realtime events
  SELECT id, amount, previous_balance, new_balance INTO v_existing_tx
  FROM public.wallet_transactions
  WHERE transaction_id = v_clean_tx_id;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_processed', true,
      'transaction_id', v_clean_tx_id,
      'amount', v_existing_tx.amount,
      'new_balance', v_existing_tx.new_balance
    );
  END IF;

  -- Lock wallet row for atomic thread-safe update
  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE id = p_user_id
  FOR UPDATE;

  -- Create wallet row if it does not exist
  IF NOT FOUND THEN
    INSERT INTO public.wallets (id, coins_balance, gold_coins, silver_coins_balance, silver_coins)
    VALUES (p_user_id, 0, 0, 0, 0)
    RETURNING * INTO v_wallet;
  END IF;

  -- Compute balances (No cumulative total balance cap! Balance increases legitimately per transaction)
  IF v_clean_currency = 'Gold' THEN
    v_prev_bal := COALESCE(v_wallet.coins_balance, v_wallet.gold_coins, 0);
    IF LOWER(p_type) = 'debit' OR LOWER(p_type) = 'used' THEN
      IF v_prev_bal < p_amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient Gold Coins balance');
      END IF;
      v_new_bal := v_prev_bal - p_amount;
    ELSE
      v_new_bal := v_prev_bal + p_amount;
    END IF;

    UPDATE public.wallets
    SET coins_balance = v_new_bal,
        gold_coins    = v_new_bal
    WHERE id = p_user_id;

  ELSIF v_clean_currency = 'Silver' THEN
    v_prev_bal := COALESCE(v_wallet.silver_coins_balance, v_wallet.silver_coins, 0);
    IF LOWER(p_type) = 'debit' OR LOWER(p_type) = 'used' THEN
      IF v_prev_bal < p_amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient Silver Coins balance');
      END IF;
      v_new_bal := v_prev_bal - p_amount;
    ELSE
      v_new_bal := v_prev_bal + p_amount;
    END IF;

    UPDATE public.wallets
    SET silver_coins_balance = v_new_bal,
        silver_coins         = v_new_bal
    WHERE id = p_user_id;
  END IF;

  -- Insert Audit Log Entry
  INSERT INTO public.wallet_transactions (
    id,
    wallet_id,
    user_id,
    currency_type,
    currency,
    amount,
    previous_balance,
    new_balance,
    type,
    source,
    transaction_id,
    reference_id,
    details,
    status,
    created_at
  ) VALUES (
    gen_random_uuid(),
    p_user_id,
    p_user_id,
    v_clean_currency,
    v_clean_currency,
    p_amount,
    v_prev_bal,
    v_new_bal,
    p_type,
    p_source,
    v_clean_tx_id,
    p_reference_id,
    p_source || ': ' || p_type || ' ' || p_amount || ' ' || v_clean_currency,
    'Completed',
    now()
  );

  RETURN jsonb_build_object(
    'success', true,
    'already_processed', false,
    'transaction_id', v_clean_tx_id,
    'currency', v_clean_currency,
    'previous_balance', v_prev_bal,
    'new_balance', v_new_bal,
    'amount', p_amount
  );
END;
$$;
