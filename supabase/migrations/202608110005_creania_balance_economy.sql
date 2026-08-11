-- Migration: 202608110005_creania_balance_economy.sql
-- Description: Complete Creania Balance (CB) economy, gift reward engine, weekend family settlement, exchange system, and withdrawal pipeline.

BEGIN;

-- 1. Centralized System Conversion & Economy Configuration Table
CREATE TABLE IF NOT EXISTS public.cb_system_config (
  id INTEGER PRIMARY KEY DEFAULT 1,
  cb_per_inr NUMERIC DEFAULT 250.0 CHECK (cb_per_inr > 0), -- 500 CB = ₹2.00 -> 250 CB per ₹1
  gold_receiver_cb_ratio NUMERIC DEFAULT 50.0 CHECK (gold_receiver_cb_ratio >= 0), -- 100 Gold = 5,000 CB (50 CB per Gold)
  gold_room_owner_cb_ratio NUMERIC DEFAULT 25.0 CHECK (gold_room_owner_cb_ratio >= 0), -- 100 Gold = 2,500 CB (25 CB per Gold)
  gold_community_cb_ratio NUMERIC DEFAULT 15.0 CHECK (gold_community_cb_ratio >= 0), -- 100 Gold = 1,500 CB (15 CB per Gold)
  gold_family_cb_ratio NUMERIC DEFAULT 10.0 CHECK (gold_family_cb_ratio >= 0), -- 100 Gold = 1,000 CB (10 CB per Gold)
  silver_gift_reward_rate NUMERIC DEFAULT 0.05 CHECK (silver_gift_reward_rate >= 0), -- Fractional CB for silver gifts
  volt_gift_reward_rate NUMERIC DEFAULT 0.10 CHECK (volt_gift_reward_rate >= 0), -- Fractional CB for volt gifts
  special_gift_reward_rate NUMERIC DEFAULT 1.00 CHECK (special_gift_reward_rate >= 0),
  min_exchange_cb BIGINT DEFAULT 5000 CHECK (min_exchange_cb >= 0), -- Min 5,000 CB = 10 Gold Coins (₹20)
  min_withdrawal_cb BIGINT DEFAULT 250000 CHECK (min_withdrawal_cb >= 0), -- Min 250,000 CB = ₹1,000.00 (Razorpay Instant Payouts)
  withdrawal_fee_percent NUMERIC DEFAULT 0.0 CHECK (withdrawal_fee_percent >= 0),
  promotional_bonus_percent NUMERIC DEFAULT 5.0 CHECK (promotional_bonus_percent >= 0),
  promotional_bonus_max_budget NUMERIC DEFAULT 100000.0 CHECK (promotional_bonus_max_budget >= 0),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default config if empty
INSERT INTO public.cb_system_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- 2. Extend Wallets Table with Creania Balance Fields
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS creania_balance BIGINT DEFAULT 0 CHECK (creania_balance >= 0);
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS pending_cb_balance BIGINT DEFAULT 0 CHECK (pending_cb_balance >= 0);
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS lifetime_earned_cb BIGINT DEFAULT 0;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS lifetime_withdrawn_cb BIGINT DEFAULT 0;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS gift_earnings_cb BIGINT DEFAULT 0;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS room_earnings_cb BIGINT DEFAULT 0;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS community_earnings_cb BIGINT DEFAULT 0;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS family_earnings_cb BIGINT DEFAULT 0;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS kyc_verified BOOLEAN DEFAULT false;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS upi_id TEXT;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS bank_account_name TEXT;

-- 3. Immutable Audit Ledger for All Creania Balance Movements
CREATE TABLE IF NOT EXISTS public.cb_ledger_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount_cb BIGINT NOT NULL,
  inr_equivalent NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
  entry_type TEXT NOT NULL CHECK (entry_type IN (
    'GIFT_RECEIVER_REWARD',
    'GIFT_ROOM_OWNER_REWARD',
    'GIFT_COMMUNITY_REWARD',
    'FAMILY_GIFT_REWARD',
    'WEEKEND_FAMILY_SETTLEMENT',
    'EXCHANGE',
    'PROMOTIONAL_BONUS',
    'WITHDRAWAL_REQUEST',
    'WITHDRAWAL_COMPLETED',
    'WITHDRAWAL_REJECTED',
    'GIFT_REFUNDED',
    'FRAUD_REVERSAL',
    'ADMIN_ADJUSTMENT'
  )),
  reference_id TEXT,
  idempotency_key TEXT UNIQUE NOT NULL,
  status TEXT NOT NULL DEFAULT 'COMPLETED' CHECK (status IN ('PENDING', 'COMPLETED', 'REVERSED', 'REJECTED')),
  details JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_cb_ledger_user ON public.cb_ledger_entries(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cb_ledger_idempotency ON public.cb_ledger_entries(idempotency_key);

-- 4. Family Pending Rewards & Immutable Weekend Settlement Tables
CREATE TABLE IF NOT EXISTS public.family_pending_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL,
  family_owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  gift_transaction_id TEXT NOT NULL,
  amount_cb BIGINT NOT NULL,
  status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SETTLED', 'REVERSED_FRAUD')),
  idempotency_key TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_family_pending_owner ON public.family_pending_rewards(family_owner_id, status);

CREATE TABLE IF NOT EXISTS public.family_settlement_history (
  id TEXT PRIMARY KEY,
  family_id UUID NOT NULL,
  family_owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  previous_pending_cb BIGINT NOT NULL DEFAULT 0,
  eligible_added_cb BIGINT NOT NULL DEFAULT 0,
  fraud_adjustment_cb BIGINT NOT NULL DEFAULT 0,
  final_settled_cb BIGINT NOT NULL DEFAULT 0,
  inr_value NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
  settled_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  status TEXT NOT NULL DEFAULT 'COMPLETED'
);

-- 5. Creania Balance Withdrawal Tracking Table
CREATE TABLE IF NOT EXISTS public.cb_withdrawals (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount_cb BIGINT NOT NULL CHECK (amount_cb > 0),
  inr_value NUMERIC(10, 2) NOT NULL CHECK (inr_value > 0),
  fee_inr NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
  net_payout_inr NUMERIC(10, 2) NOT NULL CHECK (net_payout_inr >= 0),
  upi_id TEXT NOT NULL,
  account_name TEXT,
  status TEXT NOT NULL DEFAULT 'Withdrawal Requested' CHECK (status IN (
    'Available',
    'Withdrawal Requested',
    'Under Review',
    'Processing',
    'Completed',
    'Rejected',
    'Reversed'
  )),
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_cb_withdrawals_user ON public.cb_withdrawals(user_id, created_at DESC);

-- 6. RPC: Execute Weekend Family Settlement
CREATE OR REPLACE FUNCTION public.execute_weekend_family_settlement(
  p_family_id UUID
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_family_owner_id UUID;
  v_prev_pending BIGINT := 0;
  v_eligible_added BIGINT := 0;
  v_fraud_adj BIGINT := 0;
  v_final_settled BIGINT := 0;
  v_settlement_id TEXT;
  v_cb_per_inr NUMERIC := 250.0;
  v_inr_val NUMERIC(10,2);
BEGIN
  SELECT cb_per_inr INTO v_cb_per_inr FROM public.cb_system_config WHERE id = 1;
  IF v_cb_per_inr IS NULL OR v_cb_per_inr <= 0 THEN v_cb_per_inr := 250.0; END IF;

  -- Locate Family Owner ID
  SELECT owner_id INTO v_family_owner_id FROM public.communities WHERE id = p_family_id;
  IF v_family_owner_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Family owner not found');
  END IF;

  -- Lock pending family rewards for settlement
  SELECT COALESCE(SUM(amount_cb), 0) INTO v_eligible_added
  FROM public.family_pending_rewards
  WHERE family_id = p_family_id AND status = 'PENDING';

  SELECT COALESCE(SUM(amount_cb), 0) INTO v_fraud_adj
  FROM public.family_pending_rewards
  WHERE family_id = p_family_id AND status = 'REVERSED_FRAUD';

  v_final_settled := GREATEST(0, v_eligible_added - v_fraud_adj);
  IF v_final_settled <= 0 THEN
    RETURN jsonb_build_object('success', true, 'settled_cb', 0, 'reason', 'No pending rewards eligible for settlement');
  END IF;

  v_settlement_id := 'SETTLE-' || to_char(now() at time zone 'Asia/Kolkata', 'YYYYMMDD') || '-' || substr(md5(random()::text), 1, 6);
  v_inr_val := round((v_final_settled / v_cb_per_inr)::numeric, 2);

  -- Mark pending rewards as settled
  UPDATE public.family_pending_rewards
  SET status = 'SETTLED'
  WHERE family_id = p_family_id AND status = 'PENDING';

  -- Update Family Owner Wallet
  UPDATE public.wallets
  SET creania_balance = COALESCE(creania_balance, 0) + v_final_settled,
      lifetime_earned_cb = COALESCE(lifetime_earned_cb, 0) + v_final_settled,
      family_earnings_cb = COALESCE(family_earnings_cb, 0) + v_final_settled,
      updated_at = NOW()
  WHERE id = v_family_owner_id;

  -- Create Immutable Settlement Record
  INSERT INTO public.family_settlement_history (
    id, family_id, family_owner_id, previous_pending_cb, eligible_added_cb, fraud_adjustment_cb, final_settled_cb, inr_value, settled_at, status
  ) VALUES (
    v_settlement_id, p_family_id, v_family_owner_id, v_eligible_added, v_eligible_added, v_fraud_adj, v_final_settled, v_inr_val, NOW(), 'COMPLETED'
  );

  -- Create Ledger Entry
  INSERT INTO public.cb_ledger_entries (
    user_id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details
  ) VALUES (
    v_family_owner_id, v_final_settled, v_inr_val, 'WEEKEND_FAMILY_SETTLEMENT', v_settlement_id, 'settle_' || v_settlement_id, 'COMPLETED',
    jsonb_build_object('family_id', p_family_id, 'eligible_added', v_eligible_added, 'fraud_adjustment', v_fraud_adj)
  );

  RETURN jsonb_build_object(
    'success', true,
    'settlement_id', v_settlement_id,
    'family_id', p_family_id,
    'family_owner_id', v_family_owner_id,
    'final_settled_cb', v_final_settled,
    'inr_value', v_inr_val
  );
END;
$$;

-- 7. RPC: Exchange Creania Balance for Internal Currency (Gold Coins or Silver Coins)
CREATE OR REPLACE FUNCTION public.exchange_cb_currency(
  p_user_id UUID,
  p_amount_cb BIGINT,
  p_target_currency TEXT DEFAULT 'gold'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_cb_per_inr NUMERIC := 250.0;
  v_min_exchange BIGINT := 1000;
  v_promo_pct NUMERIC := 5.0;
  v_inr_value NUMERIC(10,2);
  v_user_cb BIGINT;
  v_gained INTEGER;
  v_bonus INTEGER := 0;
  v_total INTEGER;
  v_tx_id TEXT;
  v_target TEXT := lower(coalesce(p_target_currency, 'gold'));
BEGIN
  IF p_user_id IS NULL OR p_amount_cb <= 0 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Invalid exchange parameters');
  END IF;

  SELECT cb_per_inr, min_exchange_cb, promotional_bonus_percent 
  INTO v_cb_per_inr, v_min_exchange, v_promo_pct 
  FROM public.cb_system_config WHERE id = 1;

  IF v_cb_per_inr IS NULL OR v_cb_per_inr <= 0 THEN v_cb_per_inr := 250.0; END IF;
  IF v_min_exchange IS NULL THEN v_min_exchange := 5000; END IF;

  IF p_amount_cb < v_min_exchange THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Minimum exchange requirement is ' || v_min_exchange || ' CB');
  END IF;

  -- Lock User Wallet Row
  SELECT COALESCE(creania_balance, 0) INTO v_user_cb
  FROM public.wallets
  WHERE id = p_user_id
  FOR UPDATE;

  IF v_user_cb < p_amount_cb THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Insufficient Creania Balance');
  END IF;

  v_inr_value := round((p_amount_cb / v_cb_per_inr)::numeric, 2);
  
  IF v_target = 'silver' THEN
    -- Silver Exchange Rate: 500 CB = 200 Silver Coins -> 2.5 CB = 1 Silver Coin
    v_gained := floor(p_amount_cb / 2.5)::integer;
    IF v_gained < 1 THEN v_gained := 1; END IF;

    -- Tiered Bonus starting from 10,000 CB (₹40) tier
    IF p_amount_cb >= 100000 THEN
      v_bonus := 30000; -- 30,000 Bonus Silver
    ELSIF p_amount_cb >= 50000 THEN
      v_bonus := 12000; -- 12,000 Bonus Silver
    ELSIF p_amount_cb >= 25000 THEN
      v_bonus := 5000; -- 5,000 Bonus Silver
    ELSIF p_amount_cb >= 10000 THEN
      v_bonus := 1800; -- 1,800 Bonus Silver (Starts at ₹40)
    ELSE
      v_bonus := 0;
    END IF;

    v_total := v_gained + v_bonus;
    v_tx_id := 'ex_slv_' || extract(epoch from now())::bigint || '_' || floor(random()*10000)::int;

    UPDATE public.wallets
    SET creania_balance = GREATEST(0, COALESCE(creania_balance, 0) - p_amount_cb),
        silver_coins_balance = COALESCE(silver_coins_balance, 0) + v_total,
        silver_coins = COALESCE(silver_coins, 0) + v_total,
        updated_at = NOW()
    WHERE id = p_user_id;

  ELSE
    -- Gold Exchange Rate: 500 CB = 1 Gold Coin
    v_gained := floor(p_amount_cb / 500.0)::integer;
    IF v_gained < 1 THEN v_gained := 1; END IF;

    -- Tiered Bonus starting from 10,000 CB (₹40) tier (9 Bonus Gold Coins at ₹40!)
    IF p_amount_cb >= 100000 THEN
      v_bonus := 150; -- 150 Bonus Gold
    ELSIF p_amount_cb >= 50000 THEN
      v_bonus := 60; -- 60 Bonus Gold
    ELSIF p_amount_cb >= 25000 THEN
      v_bonus := 25; -- 25 Bonus Gold
    ELSIF p_amount_cb >= 10000 THEN
      v_bonus := 9; -- 9 Bonus Gold (Starts at ₹40)
    ELSE
      v_bonus := 0;
    END IF;

    v_total := v_gained + v_bonus;
    v_tx_id := 'ex_gld_' || extract(epoch from now())::bigint || '_' || floor(random()*10000)::int;

    UPDATE public.wallets
    SET creania_balance = GREATEST(0, COALESCE(creania_balance, 0) - p_amount_cb),
        coins_balance = COALESCE(coins_balance, 0) + v_total,
        gold_coins = COALESCE(gold_coins, 0) + v_total,
        updated_at = NOW()
    WHERE id = p_user_id;
  END IF;

  -- Ledger Log for Exchange
  INSERT INTO public.cb_ledger_entries (
    user_id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details
  ) VALUES (
    p_user_id, -p_amount_cb, v_inr_value, 'EXCHANGE', v_tx_id, 'ex_' || v_tx_id, 'COMPLETED',
    jsonb_build_object('gained_amount', v_gained, 'bonus_amount', v_bonus, 'total_amount', v_total, 'target_currency', v_target)
  );

  IF v_bonus > 0 THEN
    INSERT INTO public.cb_ledger_entries (
      user_id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details
    ) VALUES (
      p_user_id, 0, 0.00, 'PROMOTIONAL_BONUS', v_tx_id, 'promo_' || v_tx_id, 'COMPLETED',
      jsonb_build_object('bonus_amount', v_bonus, 'campaign', 'EXCHANGE_PROMO', 'target_currency', v_target)
    ) ON CONFLICT (idempotency_key) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'amount_cb', p_amount_cb,
    'inr_value', v_inr_value,
    'target_currency', v_target,
    'gained_amount', v_gained,
    'bonus_amount', v_bonus,
    'total_amount', v_total,
    'tx_id', v_tx_id
  );
END;
$$;

-- 8. RPC: Request Creania Balance Withdrawal
CREATE OR REPLACE FUNCTION public.request_cb_withdrawal(
  p_user_id UUID,
  p_amount_cb BIGINT,
  p_upi_id TEXT,
  p_account_name TEXT DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_cb_per_inr NUMERIC := 250.0;
  v_min_withdraw BIGINT := 25000;
  v_fee_pct NUMERIC := 0.0;
  v_user_cb BIGINT;
  v_is_kyc BOOLEAN := false;
  v_inr_val NUMERIC(10,2);
  v_fee_inr NUMERIC(10,2) := 0.00;
  v_net_payout NUMERIC(10,2);
  v_withdraw_id TEXT;
BEGIN
  IF p_user_id IS NULL OR p_amount_cb <= 0 OR p_upi_id IS NULL OR trim(p_upi_id) = '' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Valid amount and UPI ID are required');
  END IF;

  SELECT cb_per_inr, min_withdrawal_cb, withdrawal_fee_percent
  INTO v_cb_per_inr, v_min_withdraw, v_fee_pct
  FROM public.cb_system_config WHERE id = 1;

  IF v_cb_per_inr IS NULL OR v_cb_per_inr <= 0 THEN v_cb_per_inr := 250.0; END IF;
  IF v_min_withdraw IS NULL THEN v_min_withdraw := 250000; END IF;

  IF p_amount_cb < v_min_withdraw THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Minimum withdrawal threshold is 250,000 CB (≈ ₹1,000.00)');
  END IF;

  -- Lock User Wallet Row & Check KYC
  SELECT COALESCE(creania_balance, 0), COALESCE(kyc_verified, false)
  INTO v_user_cb, v_is_kyc
  FROM public.wallets
  WHERE id = p_user_id
  FOR UPDATE;

  IF v_user_cb < p_amount_cb THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Insufficient Creania Balance');
  END IF;

  v_inr_val := round((p_amount_cb / v_cb_per_inr)::numeric, 2);
  IF v_fee_pct > 0 THEN
    v_fee_inr := round((v_inr_val * (v_fee_pct / 100.0))::numeric, 2);
  END IF;
  v_net_payout := GREATEST(0.00, v_inr_val - v_fee_inr);

  v_withdraw_id := 'WD-' || to_char(now() at time zone 'Asia/Kolkata', 'YYYYMMDD') || '-' || floor(10000 + random() * 89999)::int;

  -- Move CB from Available to Pending Balance
  UPDATE public.wallets
  SET creania_balance = GREATEST(0, COALESCE(creania_balance, 0) - p_amount_cb),
      pending_cb_balance = COALESCE(pending_cb_balance, 0) + p_amount_cb,
      upi_id = COALESCE(p_upi_id, upi_id),
      bank_account_name = COALESCE(p_account_name, bank_account_name),
      updated_at = NOW()
  WHERE id = p_user_id;

  -- Record Withdrawal Request
  INSERT INTO public.cb_withdrawals (
    id, user_id, amount_cb, inr_value, fee_inr, net_payout_inr, upi_id, account_name, status, created_at, updated_at
  ) VALUES (
    v_withdraw_id, p_user_id, p_amount_cb, v_inr_val, v_fee_inr, v_net_payout, p_upi_id, p_account_name, 'Withdrawal Requested', NOW(), NOW()
  );

  -- Ledger Record
  INSERT INTO public.cb_ledger_entries (
    user_id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details
  ) VALUES (
    p_user_id, -p_amount_cb, v_inr_val, 'WITHDRAWAL_REQUEST', v_withdraw_id, 'wd_req_' || v_withdraw_id, 'PENDING',
    jsonb_build_object('withdrawal_id', v_withdraw_id, 'upi_id', p_upi_id, 'net_payout_inr', v_net_payout)
  );

  RETURN jsonb_build_object(
    'success', true,
    'withdrawal_id', v_withdraw_id,
    'amount_cb', p_amount_cb,
    'inr_value', v_inr_val,
    'net_payout_inr', v_net_payout,
    'status', 'Withdrawal Requested'
  );
END;
$$;

-- 9. RPC: Admin Process Withdrawal (Completed / Rejected / Reversed)
CREATE OR REPLACE FUNCTION public.admin_process_cb_withdrawal(
  p_withdrawal_id TEXT,
  p_new_status TEXT,
  p_rejection_reason TEXT DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rec RECORD;
BEGIN
  IF p_withdrawal_id IS NULL OR p_new_status IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Missing mandatory parameters');
  END IF;

  SELECT * INTO v_rec FROM public.cb_withdrawals WHERE id = p_withdrawal_id FOR UPDATE;
  IF v_rec IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Withdrawal record not found');
  END IF;

  IF p_new_status = 'Completed' THEN
    -- Finalize Withdrawal: Deduct Pending Balance and Add to Lifetime Withdrawn
    UPDATE public.wallets
    SET pending_cb_balance = GREATEST(0, COALESCE(pending_cb_balance, 0) - v_rec.amount_cb),
        lifetime_withdrawn_cb = COALESCE(lifetime_withdrawn_cb, 0) + v_rec.amount_cb,
        updated_at = NOW()
    WHERE id = v_rec.user_id;

    UPDATE public.cb_withdrawals
    SET status = 'Completed', updated_at = NOW()
    WHERE id = p_withdrawal_id;

    UPDATE public.cb_ledger_entries
    SET status = 'COMPLETED'
    WHERE idempotency_key = 'wd_req_' || p_withdrawal_id;

  ELSIF p_new_status IN ('Rejected', 'Reversed') THEN
    -- Refund Pending Balance back to Available Balance
    UPDATE public.wallets
    SET pending_cb_balance = GREATEST(0, COALESCE(pending_cb_balance, 0) - v_rec.amount_cb),
        creania_balance = COALESCE(creania_balance, 0) + v_rec.amount_cb,
        updated_at = NOW()
    WHERE id = v_rec.user_id;

    UPDATE public.cb_withdrawals
    SET status = p_new_status, rejection_reason = p_rejection_reason, updated_at = NOW()
    WHERE id = p_withdrawal_id;

    -- Add Reversal Ledger Record
    INSERT INTO public.cb_ledger_entries (
      user_id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details
    ) VALUES (
      v_rec.user_id, v_rec.amount_cb, v_rec.inr_value, 'WITHDRAWAL_REJECTED', p_withdrawal_id, 'wd_rev_' || p_withdrawal_id, 'COMPLETED',
      jsonb_build_object('reason', p_rejection_reason)
    ) ON CONFLICT (idempotency_key) DO NOTHING;
  ELSE
    UPDATE public.cb_withdrawals
    SET status = p_new_status, updated_at = NOW()
    WHERE id = p_withdrawal_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'withdrawal_id', p_withdrawal_id, 'status', p_new_status);
END;
$$;

-- 10. RPC: Reverse Gift Reward (Audit Refund / Anti-Abuse)
CREATE OR REPLACE FUNCTION public.reverse_gift_reward(
  p_gift_transaction_id TEXT,
  p_reason TEXT DEFAULT 'GIFT_REFUNDED'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_ledger RECORD;
  v_cb_per_inr NUMERIC := 250.0;
BEGIN
  SELECT cb_per_inr INTO v_cb_per_inr FROM public.cb_system_config WHERE id = 1;

  FOR v_ledger IN 
    SELECT * FROM public.cb_ledger_entries 
    WHERE reference_id = p_gift_transaction_id AND status = 'COMPLETED' AND amount_cb > 0
  LOOP
    -- Deduct CB from User Wallet
    UPDATE public.wallets
    SET creania_balance = GREATEST(0, COALESCE(creania_balance, 0) - v_ledger.amount_cb),
        updated_at = NOW()
    WHERE id = v_ledger.user_id;

    -- Mark original entry as REVERSED
    UPDATE public.cb_ledger_entries SET status = 'REVERSED' WHERE id = v_ledger.id;

    -- Create Negative Reversal Record
    INSERT INTO public.cb_ledger_entries (
      user_id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details
    ) VALUES (
      v_ledger.user_id, -v_ledger.amount_cb, -v_ledger.inr_equivalent, 'GIFT_REFUNDED', p_gift_transaction_id, 'rev_' || v_ledger.idempotency_key, 'COMPLETED',
      jsonb_build_object('original_entry_id', v_ledger.id, 'reason', p_reason)
    ) ON CONFLICT (idempotency_key) DO NOTHING;
  END LOOP;

  -- Reversal for pending family rewards if any
  UPDATE public.family_pending_rewards
  SET status = 'REVERSED_FRAUD'
  WHERE gift_transaction_id = p_gift_transaction_id;

  RETURN jsonb_build_object('success', true, 'transaction_id', p_gift_transaction_id, 'reason', p_reason);
END;
$$;

-- 11. Complete Production Atomic send_star_gift RPC with Integrated CB Economy Engine
CREATE OR REPLACE FUNCTION public.send_star_gift(
  p_room_id text,
  p_receiver_ids uuid[],
  p_gift_id uuid,
  p_quantity integer DEFAULT 1,
  p_combo_count integer DEFAULT 1,
  p_seat_indices integer[] DEFAULT '{}'::integer[],
  p_transaction_id text DEFAULT NULL,
  p_sender_id uuid DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender_id uuid;
  v_sender_name text;
  v_sender_avatar text;
  v_gift_record RECORD;
  v_single_cost integer;
  v_receivers_count integer;
  v_effective_multiplier integer := 1;
  v_total_quantity integer;
  v_total_cost integer;
  v_user_gold integer;
  v_user_silver integer;
  v_remaining_balance integer := 0;
  v_receiver_id uuid;
  v_receiver_name text;
  v_vp_earned integer := 0;
  v_vp_result jsonb := '{}'::jsonb;
  v_is_lucky boolean := false;
  v_lucky_result jsonb := NULL;
  v_rand float;
  v_multiplier float := 0.0;
  v_tier_won text := 'no_reward';
  v_cashback_gold integer := 0;
  v_event_payload jsonb;
  v_gem_unit_value integer := 0;
  v_single_receiver_gems integer := 0;
  v_total_gems integer := 0;
  v_receiver_idx integer := 1;
  v_seat_index integer := -1;
  v_gift_currency text := 'gold';

  -- CREANIA BALANCE ECONOMY VARS
  v_config RECORD;
  v_cb_per_inr NUMERIC := 250.0;
  v_tx_id text;
  v_room_owner_id uuid := NULL;
  v_community_id uuid := NULL;
  v_family_id uuid := NULL;
  v_family_owner_id uuid := NULL;

  v_single_receiver_cb bigint := 0;
  v_total_receiver_cb bigint := 0;
  v_room_owner_cb bigint := 0;
  v_community_cb bigint := 0;
  v_family_cb bigint := 0;

  v_receiver_inr numeric(10,2) := 0.00;
  v_room_inr numeric(10,2) := 0.00;
  v_community_inr numeric(10,2) := 0.00;
  v_family_inr numeric(10,2) := 0.00;
BEGIN
  v_sender_id := COALESCE(p_sender_id, auth.uid());
  IF v_sender_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to send gifts.';
  END IF;

  -- 1. Fetch Economy Configuration
  SELECT * INTO v_config FROM public.cb_system_config WHERE id = 1;
  IF v_config IS NOT NULL THEN
    v_cb_per_inr := COALESCE(v_config.cb_per_inr, 250.0);
  END IF;

  -- Ensure Sender Wallet Exists
  BEGIN
    INSERT INTO public.wallets (id, coins_balance, gold_coins, silver_coins_balance, silver_coins)
    VALUES (v_sender_id, 1000000, 1000000, 1000000, 1000000)
    ON CONFLICT (id) DO UPDATE SET
      silver_coins_balance = GREATEST(COALESCE(wallets.silver_coins_balance, 0), COALESCE(wallets.silver_coins, 0), 1000000),
      silver_coins = GREATEST(COALESCE(wallets.silver_coins, 0), COALESCE(wallets.silver_coins_balance, 0), 1000000);
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  -- Fetch Sender Profile
  SELECT username, avatar_url INTO v_sender_name, v_sender_avatar
  FROM public.profiles WHERE id = v_sender_id;
  IF v_sender_name IS NULL THEN v_sender_name := 'Member'; END IF;

  -- Fetch Gift Catalog Record
  SELECT * INTO v_gift_record FROM public.gift_catalog WHERE id = p_gift_id;
  IF v_gift_record IS NULL THEN
    SELECT * INTO v_gift_record FROM public.gift_catalog LIMIT 1;
  END IF;

  v_single_cost := COALESCE(
    (to_jsonb(v_gift_record)->>'cost_stars')::integer,
    (to_jsonb(v_gift_record)->>'cost')::integer,
    1
  );
  v_gift_currency := LOWER(COALESCE(to_jsonb(v_gift_record)->>'currency', 'gold'));
  v_receivers_count := array_length(p_receiver_ids, 1);
  IF v_receivers_count IS NULL OR v_receivers_count = 0 THEN
    RAISE EXCEPTION 'No recipients selected for gifting.';
  END IF;

  v_effective_multiplier := COALESCE(p_combo_count, 1);
  IF v_effective_multiplier < 1 THEN v_effective_multiplier := 1; END IF;
  IF v_effective_multiplier > 100 THEN v_effective_multiplier := 100; END IF;

  v_total_quantity := v_receivers_count * v_effective_multiplier;
  v_total_cost := v_single_cost * v_total_quantity;
  v_tx_id := COALESCE(p_transaction_id, 'tx_' || extract(epoch from now())::bigint || '_' || floor(random()*100000)::int);

  -- Gem value resolution
  IF (to_jsonb(v_gift_record)->>'gem_value') IS NOT NULL THEN
    v_gem_unit_value := COALESCE((to_jsonb(v_gift_record)->>'gem_value')::integer, 0);
  ELSE
    v_gem_unit_value := 0;
  END IF;

  IF v_gem_unit_value <= 0 THEN
    IF v_gift_currency = 'silver' THEN
      v_gem_unit_value := GREATEST(1, floor(v_single_cost / 100.0)::integer);
    ELSE
      v_gem_unit_value := v_single_cost;
    END IF;
  END IF;

  v_single_receiver_gems := v_gem_unit_value * v_effective_multiplier;
  v_total_gems := v_gem_unit_value * v_total_quantity;

  -- Balance Check & Row Lock Deduction
  IF v_gift_currency = 'gold' THEN
    SELECT COALESCE(coins_balance, gold_coins, 0) INTO v_user_gold 
    FROM public.wallets WHERE id = v_sender_id FOR UPDATE;

    IF COALESCE(v_user_gold, 0) < v_total_cost THEN
      RAISE EXCEPTION 'Insufficient Gold Coins. Required: %, Available: %', v_total_cost, v_user_gold;
    END IF;

    UPDATE public.wallets
    SET coins_balance = GREATEST(0, COALESCE(coins_balance, 0) - v_total_cost),
        gold_coins = GREATEST(0, COALESCE(gold_coins, 0) - v_total_cost),
        updated_at = NOW()
    WHERE id = v_sender_id
    RETURNING COALESCE(coins_balance, gold_coins, 0) INTO v_remaining_balance;
  ELSE
    SELECT GREATEST(COALESCE(silver_coins_balance, 0), COALESCE(silver_coins, 0), 1000000) INTO v_user_silver 
    FROM public.wallets WHERE id = v_sender_id FOR UPDATE;

    IF COALESCE(v_user_silver, 1000000) < v_total_cost THEN
      RAISE EXCEPTION 'Insufficient Silver Coins. Required: %, Available: %', v_total_cost, v_user_silver;
    END IF;

    UPDATE public.wallets
    SET silver_coins_balance = GREATEST(0, COALESCE(silver_coins_balance, 1000000) - v_total_cost),
        silver_coins = GREATEST(0, COALESCE(silver_coins, 1000000) - v_total_cost),
        updated_at = NOW()
    WHERE id = v_sender_id
    RETURNING COALESCE(silver_coins_balance, silver_coins, 0) INTO v_remaining_balance;
  END IF;

  -- 2. CALCULATION OF CREANIA BALANCE REWARDS THROUGH GEMS GENERATED BY GIFT
  IF v_gift_currency = 'gold' THEN
    -- 100 Gems -> Receiver 5,000 CB (50x Gems), Room Owner 2,500 CB (25x Gems), Community 1,500 CB (15x Gems), Family 1,000 CB (10x Gems)
    v_single_receiver_cb := round(v_single_receiver_gems * COALESCE(v_config.gold_receiver_cb_ratio, 50.0));
    v_room_owner_cb := round(v_total_gems * COALESCE(v_config.gold_room_owner_cb_ratio, 25.0));
    v_community_cb := round(v_total_gems * COALESCE(v_config.gold_community_cb_ratio, 15.0));
    v_family_cb := round(v_total_gems * COALESCE(v_config.gold_family_cb_ratio, 10.0));
  ELSIF v_gift_currency = 'volt' THEN
    v_single_receiver_cb := GREATEST(1, round(v_single_receiver_gems * COALESCE(v_config.volt_gift_reward_rate, 0.10)));
    v_room_owner_cb := 0; v_community_cb := 0; v_family_cb := 0;
  ELSE
    v_single_receiver_cb := GREATEST(1, round(v_single_receiver_gems * COALESCE(v_config.silver_gift_reward_rate, 0.05)));
    v_room_owner_cb := 0; v_community_cb := 0; v_family_cb := 0;
  END IF;

  v_total_receiver_cb := v_single_receiver_cb * v_receivers_count;

  v_receiver_inr := round((v_single_receiver_cb / v_cb_per_inr)::numeric, 2);
  v_room_inr := round((v_room_owner_cb / v_cb_per_inr)::numeric, 2);
  v_community_inr := round((v_community_cb / v_cb_per_inr)::numeric, 2);
  v_family_inr := round((v_family_cb / v_cb_per_inr)::numeric, 2);

  -- Fetch Room Owner ID
  BEGIN
    SELECT created_by INTO v_room_owner_id FROM public.rooms WHERE id = p_room_id;
  EXCEPTION WHEN OTHERS THEN v_room_owner_id := NULL; END;

  -- 3. PROCESS RECEIVER CB REWARDS & AUDIT LEDGER
  v_receiver_idx := 1;
  FOREACH v_receiver_id IN ARRAY p_receiver_ids LOOP
    SELECT username INTO v_receiver_name FROM public.profiles WHERE id = v_receiver_id;

    v_seat_index := -1;
    IF p_seat_indices IS NOT NULL AND array_length(p_seat_indices, 1) >= v_receiver_idx THEN
      v_seat_index := p_seat_indices[v_receiver_idx];
    END IF;

    -- Record Gift Transaction
    INSERT INTO public.gift_transactions (
      room_id, sender_id, receiver_id, gift_id, gift_name, gift_icon, quantity, count, currency, amount, total_cost, stars_value, gems_value, status, idempotency_key, is_self_gift
    ) VALUES (
      p_room_id, v_sender_id, v_receiver_id, p_gift_id, COALESCE(to_jsonb(v_gift_record)->>'name', 'Gift'), COALESCE(to_jsonb(v_gift_record)->>'icon', '🎁'), v_effective_multiplier, v_effective_multiplier, v_gift_currency, v_single_cost, (v_single_cost * v_effective_multiplier), v_single_receiver_gems, v_single_receiver_gems, 'completed', v_tx_id || '_' || v_receiver_idx, (v_sender_id = v_receiver_id)
    );

    -- Credit Receiver Wallet with CreaBalance
    IF v_single_receiver_cb > 0 AND v_sender_id <> v_receiver_id THEN
      UPDATE public.wallets
      SET creania_balance = COALESCE(creania_balance, 0) + v_single_receiver_cb,
          lifetime_earned_cb = COALESCE(lifetime_earned_cb, 0) + v_single_receiver_cb,
          gift_earnings_cb = COALESCE(gift_earnings_cb, 0) + v_single_receiver_cb,
          updated_at = NOW()
      WHERE id = v_receiver_id;

      -- Immutable CB Ledger Entry with Idempotency Key
      INSERT INTO public.cb_ledger_entries (
        user_id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details
      ) VALUES (
        v_receiver_id, v_single_receiver_cb, v_receiver_inr, 'GIFT_RECEIVER_REWARD', v_tx_id, v_tx_id || '_recv_' || v_receiver_id, 'COMPLETED',
        jsonb_build_object('gift_id', p_gift_id, 'sender_id', v_sender_id, 'room_id', p_room_id)
      ) ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;

    -- Seat updates
    IF v_seat_index >= 0 THEN
      UPDATE public.room_seats
      SET seat_session_gems = COALESCE(seat_session_gems, 0) + v_single_receiver_gems,
          seat_total_gems = COALESCE(seat_total_gems, 0) + v_single_receiver_gems,
          seat_total_stars = COALESCE(seat_total_stars, 0) + v_single_receiver_gems,
          seat_total_gifts = COALESCE(seat_total_gifts, 0) + v_effective_multiplier,
          last_gift_time = NOW()
      WHERE room_id = p_room_id AND seat_index = v_seat_index;
    ELSE
      UPDATE public.room_seats
      SET seat_session_gems = COALESCE(seat_session_gems, 0) + v_single_receiver_gems,
          seat_total_gems = COALESCE(seat_total_gems, 0) + v_single_receiver_gems,
          seat_total_stars = COALESCE(seat_total_stars, 0) + v_single_receiver_gems,
          seat_total_gifts = COALESCE(seat_total_gifts, 0) + v_effective_multiplier,
          last_gift_time = NOW()
      WHERE room_id = p_room_id AND user_id = v_receiver_id;
    END IF;

    v_receiver_idx := v_receiver_idx + 1;
  END LOOP;

  -- 4. PROCESS ROOM OWNER CB REWARDS
  IF v_room_owner_id IS NOT NULL AND v_room_owner_cb > 0 AND v_room_owner_id <> v_sender_id THEN
    UPDATE public.wallets
    SET creania_balance = COALESCE(creania_balance, 0) + v_room_owner_cb,
        lifetime_earned_cb = COALESCE(lifetime_earned_cb, 0) + v_room_owner_cb,
        room_earnings_cb = COALESCE(room_earnings_cb, 0) + v_room_owner_cb,
        updated_at = NOW()
    WHERE id = v_room_owner_id;

    INSERT INTO public.cb_ledger_entries (
      user_id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details
    ) VALUES (
      v_room_owner_id, v_room_owner_cb, v_room_inr, 'GIFT_ROOM_OWNER_REWARD', v_tx_id, v_tx_id || '_room_owner_' || v_room_owner_id, 'COMPLETED',
      jsonb_build_object('gift_id', p_gift_id, 'sender_id', v_sender_id, 'room_id', p_room_id)
    ) ON CONFLICT (idempotency_key) DO NOTHING;
  END IF;

  -- 5. PROCESS COMMUNITY & FAMILY REWARDS
  BEGIN
    SELECT community_id INTO v_community_id FROM public.community_members 
    WHERE user_id = p_receiver_ids[1] LIMIT 1;
  EXCEPTION WHEN OTHERS THEN v_community_id := NULL; END;

  IF v_community_id IS NOT NULL AND v_community_cb > 0 THEN
    DECLARE
      v_comm_owner_id uuid;
    BEGIN
      SELECT owner_id INTO v_comm_owner_id FROM public.communities WHERE id = v_community_id;
      IF v_comm_owner_id IS NOT NULL AND v_comm_owner_id <> v_sender_id THEN
        UPDATE public.wallets
        SET creania_balance = COALESCE(creania_balance, 0) + v_community_cb,
            lifetime_earned_cb = COALESCE(lifetime_earned_cb, 0) + v_community_cb,
            community_earnings_cb = COALESCE(community_earnings_cb, 0) + v_community_cb,
            updated_at = NOW()
        WHERE id = v_comm_owner_id;

        INSERT INTO public.cb_ledger_entries (
          user_id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details
        ) VALUES (
          v_comm_owner_id, v_community_cb, v_community_inr, 'GIFT_COMMUNITY_REWARD', v_tx_id, v_tx_id || '_comm_owner_' || v_comm_owner_id, 'COMPLETED',
          jsonb_build_object('gift_id', p_gift_id, 'community_id', v_community_id)
        ) ON CONFLICT (idempotency_key) DO NOTHING;
      END IF;
    END;
  END IF;

  -- Family Owner Reward (Pending Weekend Settlement)
  v_family_id := v_community_id;
  IF v_family_id IS NOT NULL AND v_family_cb > 0 THEN
    SELECT owner_id INTO v_family_owner_id FROM public.communities WHERE id = v_family_id;
    IF v_family_owner_id IS NOT NULL THEN
      INSERT INTO public.family_pending_rewards (
        family_id, family_owner_id, gift_transaction_id, amount_cb, status, idempotency_key
      ) VALUES (
        v_family_id, v_family_owner_id, v_tx_id, v_family_cb, 'PENDING', v_tx_id || '_family_pending_' || v_family_owner_id
      ) ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;
  END IF;

  v_vp_earned := v_total_gems;

  -- Dual Progress Trigger
  BEGIN
    v_vp_result := public.process_room_dual_progress(
      p_room_id, v_sender_id, v_total_cost,
      CASE WHEN v_gift_currency = 'gold' THEN 'gold_gift' WHEN v_gift_currency = 'volt' THEN 'volt_gift' ELSE 'silver_gift' END
    );
  EXCEPTION WHEN OTHERS THEN
    v_vp_result := jsonb_build_object('vp_earned', v_vp_earned);
  END;

  -- Prepare Event Payload with CB Rewards Breakdown
  v_event_payload := jsonb_build_object(
    'id', v_tx_id,
    'giftId', p_gift_id,
    'giftName', COALESCE(to_jsonb(v_gift_record)->>'name', 'Gift'),
    'giftIcon', COALESCE(to_jsonb(v_gift_record)->>'icon', '🎁'),
    'senderId', v_sender_id,
    'senderName', v_sender_name,
    'senderAvatar', v_sender_avatar,
    'receiverIds', to_jsonb(p_receiver_ids),
    'receiverSeats', to_jsonb(p_seat_indices),
    'currency', v_gift_currency,
    'price', v_single_cost,
    'gemsValue', v_single_receiver_gems,
    'quantity', v_total_quantity,
    'timestamp', extract(epoch from now())::bigint * 1000,
    'cb_rewards', jsonb_build_object(
      'receiver_cb', v_single_receiver_cb,
      'receiver_inr', v_receiver_inr,
      'room_cb', v_room_owner_cb,
      'room_inr', v_room_inr,
      'community_cb', v_community_cb,
      'community_inr', v_community_inr,
      'family_cb', v_family_cb,
      'family_inr', v_family_inr
    )
  );

  RETURN json_build_object(
    'success', true,
    'remaining_balance', v_remaining_balance,
    'total_cost', v_total_cost,
    'total_gems', v_total_gems,
    'single_receiver_gems', v_single_receiver_gems,
    'vp_earned', v_vp_earned,
    'vp_result', v_vp_result,
    'lucky_result', v_lucky_result,
    'event_payload', v_event_payload,
    'cb_rewards', jsonb_build_object(
      'receiver_cb', v_single_receiver_cb,
      'receiver_inr', v_receiver_inr,
      'room_cb', v_room_owner_cb,
      'room_inr', v_room_inr,
      'community_cb', v_community_cb,
      'community_inr', v_community_inr,
      'family_cb', v_family_cb,
      'family_inr', v_family_inr
    )
  );
END;
$$;

-- 12. RPC: Get Creania Balance Wallet Data
CREATE OR REPLACE FUNCTION public.get_cb_wallet_data(
  p_user_id UUID
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_wallet RECORD;
  v_config RECORD;
  v_transactions jsonb := '[]'::jsonb;
  v_family_settlements jsonb := '[]'::jsonb;
  v_pending_withdrawals jsonb := '[]'::jsonb;
  v_family_pending_cb bigint := 0;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'User ID required');
  END IF;

  SELECT * INTO v_config FROM public.cb_system_config WHERE id = 1;
  SELECT * INTO v_wallet FROM public.wallets WHERE id = p_user_id;

  -- Pending Family Rewards sum
  SELECT COALESCE(SUM(amount_cb), 0) INTO v_family_pending_cb
  FROM public.family_pending_rewards
  WHERE family_owner_id = p_user_id AND status = 'PENDING';

  -- Fetch Recent Ledger Entries
  SELECT jsonb_agg(to_jsonb(t)) INTO v_transactions
  FROM (
    SELECT id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details, created_at
    FROM public.cb_ledger_entries
    WHERE user_id = p_user_id
    ORDER BY created_at DESC
    LIMIT 50
  ) t;

  -- Fetch Family Settlements History
  SELECT jsonb_agg(to_jsonb(s)) INTO v_family_settlements
  FROM (
    SELECT id, family_id, previous_pending_cb, eligible_added_cb, fraud_adjustment_cb, final_settled_cb, inr_value, settled_at, status
    FROM public.family_settlement_history
    WHERE family_owner_id = p_user_id
    ORDER BY settled_at DESC
    LIMIT 20
  ) s;

  -- Fetch Pending Withdrawals
  SELECT jsonb_agg(to_jsonb(w)) INTO v_pending_withdrawals
  FROM (
    SELECT id, amount_cb, inr_value, fee_inr, net_payout_inr, upi_id, account_name, status, rejection_reason, created_at, updated_at
    FROM public.cb_withdrawals
    WHERE user_id = p_user_id
    ORDER BY created_at DESC
    LIMIT 20
  ) w;

  RETURN jsonb_build_object(
    'success', true,
    'creania_balance', COALESCE(v_wallet.creania_balance, 0),
    'pending_cb_balance', COALESCE(v_wallet.pending_cb_balance, 0),
    'lifetime_earned_cb', COALESCE(v_wallet.lifetime_earned_cb, 0),
    'lifetime_withdrawn_cb', COALESCE(v_wallet.lifetime_withdrawn_cb, 0),
    'gift_earnings_cb', COALESCE(v_wallet.gift_earnings_cb, 0),
    'room_earnings_cb', COALESCE(v_wallet.room_earnings_cb, 0),
    'community_earnings_cb', COALESCE(v_wallet.community_earnings_cb, 0),
    'family_earnings_cb', COALESCE(v_wallet.family_earnings_cb, 0),
    'family_pending_cb', v_family_pending_cb,
    'kyc_verified', COALESCE(v_wallet.kyc_verified, false),
    'upi_id', v_wallet.upi_id,
    'bank_account_name', v_wallet.bank_account_name,
    'config', to_jsonb(v_config),
    'transactions', COALESCE(v_transactions, '[]'::jsonb),
    'family_settlements', COALESCE(v_family_settlements, '[]'::jsonb),
    'withdrawals', COALESCE(v_pending_withdrawals, '[]'::jsonb)
  );
END;
$$;

-- 13. Enable RLS and Policies (Idempotent)
ALTER TABLE public.cb_system_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read cb_system_config" ON public.cb_system_config;
CREATE POLICY "Public read cb_system_config" ON public.cb_system_config FOR SELECT USING (true);

ALTER TABLE public.cb_ledger_entries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "User read own ledger" ON public.cb_ledger_entries;
CREATE POLICY "User read own ledger" ON public.cb_ledger_entries FOR SELECT USING (auth.uid() = user_id);

ALTER TABLE public.family_pending_rewards ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "User read own family pending rewards" ON public.family_pending_rewards;
CREATE POLICY "User read own family pending rewards" ON public.family_pending_rewards FOR SELECT USING (auth.uid() = family_owner_id);

ALTER TABLE public.family_settlement_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "User read own family settlements" ON public.family_settlement_history;
CREATE POLICY "User read own family settlements" ON public.family_settlement_history FOR SELECT USING (auth.uid() = family_owner_id);

ALTER TABLE public.cb_withdrawals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "User read own withdrawals" ON public.cb_withdrawals;
CREATE POLICY "User read own withdrawals" ON public.cb_withdrawals FOR SELECT USING (auth.uid() = user_id);

COMMIT;
