-- 202608120003_authoritative_wallet_security_and_audit.sql
-- AUTHORITATIVE WALLET SECURITY, IDEMPOTENT TRANSACTION PROCESSOR & COMPLETE AUDIT TRAIL

-- 1. Ensure wallets table schema columns exist
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS coins_balance bigint DEFAULT 0;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS gold_coins bigint DEFAULT 0;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS silver_coins_balance bigint DEFAULT 0;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS silver_coins bigint DEFAULT 0;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS withdrawable_balance numeric(12,2) DEFAULT 0.00;

-- 2. Ensure wallet_transactions audit table and required columns exist
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  currency_type text NOT NULL DEFAULT 'Gold',
  currency text NOT NULL DEFAULT 'Gold',
  amount numeric(12,2) NOT NULL DEFAULT 0.00,
  previous_balance numeric(12,2) NOT NULL DEFAULT 0.00,
  new_balance numeric(12,2) NOT NULL DEFAULT 0.00,
  type text NOT NULL DEFAULT 'Reward',
  source text NOT NULL DEFAULT 'System',
  transaction_id text UNIQUE,
  reference_id text,
  details text,
  status text NOT NULL DEFAULT 'Completed',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Safely add missing columns to pre-existing wallet_transactions table if created in earlier migrations
ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS wallet_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS currency_type text DEFAULT 'Gold';
ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS currency text DEFAULT 'Gold';
ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS previous_balance numeric(12,2) DEFAULT 0.00;
ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS new_balance numeric(12,2) DEFAULT 0.00;
ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS transaction_id text;
ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS reference_id text;
ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS details text;

-- Backfill user_id from wallet_id if pre-existing rows have user_id null
UPDATE public.wallet_transactions 
SET user_id = wallet_id 
WHERE user_id IS NULL AND wallet_id IS NOT NULL;

-- Backfill wallet_id from user_id if pre-existing rows have wallet_id null
UPDATE public.wallet_transactions 
SET wallet_id = user_id 
WHERE wallet_id IS NULL AND user_id IS NOT NULL;

-- Add UNIQUE constraint to transaction_id if not present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'wallet_transactions_transaction_id_key'
  ) THEN
    ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_transaction_id_key UNIQUE (transaction_id);
  END IF;
END $$;

-- Index for fast idempotency lookups & audit logs
CREATE INDEX IF NOT EXISTS idx_wallet_tx_transaction_id ON public.wallet_transactions(transaction_id);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_user_created ON public.wallet_transactions(user_id, created_at DESC);

-- 3. Row Level Security (RLS) on wallets table:
-- Revoke direct UPDATE & INSERT for authenticated users to prevent client-side balance spoofing.
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own wallet" ON public.wallets;
CREATE POLICY "Users can view own wallet" ON public.wallets
  FOR SELECT USING (auth.uid() = id);

-- Revoke direct table updates from client-side REST requests
DROP POLICY IF EXISTS "Users cannot update own wallet directly" ON public.wallets;
DROP POLICY IF EXISTS "Users cannot insert wallet directly" ON public.wallets;

-- 4. Authoritative Idempotent Wallet Mutation & Audit RPC Function
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

  -- Validate Currency Type
  v_clean_currency := CASE LOWER(p_currency)
    WHEN 'silver' THEN 'Silver'
    WHEN 'silver_coins' THEN 'Silver'
    WHEN 'gold' THEN 'Gold'
    WHEN 'gold_coins' THEN 'Gold'
    WHEN 'coins' THEN 'Gold'
    ELSE 'Gold'
  END;

  -- Anomaly / Anti-Abuse Cap: Reject single transactions > 50,000 unless from explicit gateway payment
  IF p_amount > 50000 AND LOWER(p_source) NOT LIKE '%payment%' AND LOWER(p_source) NOT LIKE '%razorpay%' AND LOWER(p_source) NOT LIKE '%inapp%' THEN
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
    -- Return success with existing record info (idempotent skip)
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

  -- Compute balances
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

-- 5. Sanitize any legacy test/artificially inflated balances (> 100,000,000) down to reasonable caps
UPDATE public.wallets
SET 
  coins_balance        = LEAST(coins_balance, 50000),
  gold_coins           = LEAST(gold_coins, 50000),
  silver_coins_balance = LEAST(silver_coins_balance, 100000),
  silver_coins         = LEAST(silver_coins, 100000)
WHERE coins_balance > 100000000 OR silver_coins_balance > 100000000 OR gold_coins > 100000000;
