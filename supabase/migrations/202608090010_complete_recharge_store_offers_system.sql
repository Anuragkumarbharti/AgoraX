-- ============================================================================
-- CREANIA COMPLETE RECHARGE, FIRST PURCHASE, VIP & NOVEL OFFER SYSTEM
-- Migration File: 202608090010_complete_recharge_store_offers_system.sql
-- Description:
--   1. Adds first purchase & signup reward tracking columns to profiles.
--   2. Creates store_configurations table for admin-configurable packages, offers, and bonus days.
--   3. Adds claim_signup_reward_rpc for idempotent coin wallet signup reward.
--   4. Updates purchase_and_activate_rpc with strict floor(INR / 2) coin rate, recharge bonuses,
--      idempotent first purchase offers, exact VIP/Novel duration mapping (+bonus extra days),
--      and detailed wallet transaction logging.
-- ============================================================================

-- 1. Profile Tracking Columns
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS first_purchase_completed boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS first_vip_purchase_completed boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS first_novel_purchase_completed boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS signup_reward_claimed boolean DEFAULT false;

-- Drop legacy table constraints to allow Coins, Gold Coins, Signup Reward, etc.
ALTER TABLE public.wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_type_check;
ALTER TABLE public.wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_currency_check;

-- 2. Store Configurations Table
CREATE TABLE IF NOT EXISTS public.store_configurations (
  key text PRIMARY KEY,
  config jsonb NOT NULL,
  updated_at timestamptz DEFAULT now()
);

-- Pre-seed production default configurations
INSERT INTO public.store_configurations (key, config, updated_at)
VALUES
  ('recharge_packages', '[
    {"id": "coins_99", "name": "Starter Pack", "price": 99, "base_coins": 50, "bonus_coins": 5, "tag": "Popular"},
    {"id": "coins_199", "name": "Basic Pack", "price": 199, "base_coins": 100, "bonus_coins": 15, "tag": null},
    {"id": "coins_499", "name": "Silver Pack", "price": 499, "base_coins": 250, "bonus_coins": 50, "tag": "Best Value"},
    {"id": "coins_999", "name": "Gold Pack", "price": 999, "base_coins": 500, "bonus_coins": 125, "tag": "Popular"},
    {"id": "coins_1999", "name": "Diamond Pack", "price": 1999, "base_coins": 1000, "bonus_coins": 199, "tag": "Mega Bonus"},
    {"id": "coins_4999", "name": "Elite Pack", "price": 4999, "base_coins": 2500, "bonus_coins": 399, "tag": "Pro Choice"},
    {"id": "coins_9999", "name": "Legend Pack", "price": 9999, "base_coins": 5000, "bonus_coins": 599, "tag": "Crown Value"}
  ]'::jsonb, now()),

  ('first_purchase_config', '{
    "enabled": true,
    "bonus_coins": 50,
    "vip_bonus_days": 3,
    "novel_bonus_days": 3,
    "frame_name": "Royal Frame",
    "badge_name": "Pioneer Badge"
  }'::jsonb, now()),

  ('first_vip_purchase_config', '{
    "enabled": true,
    "bonus_days": 3,
    "bonus_coins": 20,
    "frame_name": "VIP Crown Frame",
    "badge_name": "VIP Pioneer"
  }'::jsonb, now()),

  ('first_novel_purchase_config', '{
    "enabled": true,
    "bonus_days": 3,
    "bonus_coins": 20,
    "frame_name": "Novel Reader Frame",
    "badge_name": "Novel Pioneer"
  }'::jsonb, now()),

  ('vip_packages_config', '{
    "30 Days": {"base_days": 30, "bonus_days": 3},
    "1 Month": {"base_days": 30, "bonus_days": 3},
    "90 Days": {"base_days": 90, "bonus_days": 10},
    "3 Months": {"base_days": 90, "bonus_days": 10},
    "365 Days": {"base_days": 365, "bonus_days": 30},
    "1 Year": {"base_days": 365, "bonus_days": 30}
  }'::jsonb, now()),

  ('novel_packages_config', '{
    "30 Days": {"base_days": 30, "bonus_days": 3},
    "1 Month": {"base_days": 30, "bonus_days": 3},
    "90 Days": {"base_days": 90, "bonus_days": 10},
    "3 Months": {"base_days": 90, "bonus_days": 10},
    "365 Days": {"base_days": 365, "bonus_days": 30},
    "1 Year": {"base_days": 365, "bonus_days": 30}
  }'::jsonb, now()),

  ('signup_reward_coins', '50'::jsonb, now())

ON CONFLICT (key) DO UPDATE
SET config = EXCLUDED.config, updated_at = now();

-- 3. Idempotent Signup Reward Claim RPC
CREATE OR REPLACE FUNCTION public.claim_signup_reward_rpc(
  p_user_id uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_id uuid := COALESCE(p_user_id, auth.uid());
  v_already_claimed boolean := false;
  v_reward_coins integer := 50;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT signup_reward_claimed INTO v_already_claimed
  FROM public.profiles WHERE id = v_caller_id;

  IF v_already_claimed = true THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_claimed', true,
      'coins_added', 0,
      'message', 'Signup reward already claimed'
    );
  END IF;

  -- Add to Coin Wallet
  INSERT INTO public.wallets (id, gold_coins, coins_balance, silver_coins, withdrawable_balance)
  VALUES (v_caller_id, v_reward_coins, v_reward_coins, 0, 0.0)
  ON CONFLICT (id) DO UPDATE
  SET gold_coins = COALESCE(public.wallets.gold_coins, 0) + v_reward_coins,
      coins_balance = COALESCE(public.wallets.coins_balance, 0) + v_reward_coins;

  -- Ledger Log
  INSERT INTO public.wallet_transactions (wallet_id, amount, currency, type, status, details)
  VALUES (v_caller_id, v_reward_coins, 'Coins', 'Reward', 'Completed', 'First Account Creation Reward');

  -- Mark claimed
  UPDATE public.profiles
  SET signup_reward_claimed = true
  WHERE id = v_caller_id;

  RETURN jsonb_build_object(
    'success', true,
    'already_claimed', false,
    'coins_added', v_reward_coins,
    'message', 'Successfully credited signup reward to Coin Wallet'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_signup_reward_rpc(uuid) TO authenticated, service_role;

-- 4. Master Purchase & Activation RPC
CREATE OR REPLACE FUNCTION public.purchase_and_activate_rpc(
  p_user_id        uuid,
  p_product_name   text,
  p_category       text,
  p_amount         numeric,
  p_final_amount   numeric,
  p_payment_method text,
  p_duration       text,
  p_payment_id     text DEFAULT NULL,
  p_order_id       text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_level              integer := 0;
  v_base_days          integer := 30;
  v_bonus_days         integer := 0;
  v_total_days         integer := 30;
  v_old_level          integer := 0;
  v_old_expiry         timestamptz;
  v_new_expiry         timestamptz;
  v_frame_name         text;
  v_has_frame          boolean := false;
  
  -- Coin & Reward calculations
  v_base_coins         integer := 0;
  v_recharge_bonus     integer := 0;
  v_first_bonus_coins  integer := 0;
  v_total_coins_credit integer := 0;
  
  -- Profiles first-purchase flags
  v_is_first_purchase       boolean := false;
  v_is_first_vip_purchase   boolean := false;
  v_is_first_novel_purchase boolean := false;
  v_user_profile            public.profiles%ROWTYPE;
BEGIN
  IF p_user_id IS NULL OR p_product_name IS NULL OR p_category IS NULL THEN
    RAISE EXCEPTION 'purchase_and_activate_rpc: missing required parameters';
  END IF;

  -- 1. Idempotency Check: Avoid double-crediting if payment already processed
  IF p_payment_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.purchases WHERE payment_id = p_payment_id AND status = 'Success'
  ) THEN
    RETURN jsonb_build_object(
      'success', true,
      'idempotent', true,
      'product', p_product_name,
      'category', p_category,
      'message', 'Payment already processed successfully'
    );
  END IF;

  -- Load user profile flags with row lock
  SELECT * INTO v_user_profile FROM public.profiles WHERE id = p_user_id FOR UPDATE;

  v_is_first_purchase       := COALESCE(v_user_profile.first_purchase_completed, false) = false;
  v_is_first_vip_purchase   := COALESCE(v_user_profile.first_vip_purchase_completed, false) = false;
  v_is_first_novel_purchase := COALESCE(v_user_profile.first_novel_purchase_completed, false) = false;

  v_level := COALESCE((regexp_match(p_product_name, E'(\\d+)'))[1]::integer, 1);

  -- Record purchase log in purchases table
  INSERT INTO public.purchases
    (user_id, product_name, category, amount, final_amount, payment_method, status, duration, payment_id)
  VALUES (p_user_id, p_product_name, p_category, p_amount, p_final_amount,
          p_payment_method, 'Success', p_duration, p_payment_id);

  -- ── CATEGORY 1: COINS (RECHARGE) ──────────────────────────────────────────
  IF p_category = 'Coins' THEN
    -- CONVERSION RULE: Base Coins = floor((p_final_amount + 1) / 2) for round values (50, 100, 250, 500, etc.)
    v_base_coins := FLOOR((p_final_amount + 1.0) / 2.0)::integer;
    
    -- Recharge Package Bonus Coins (Tiered structure)
    IF p_final_amount >= 9999 THEN
      v_recharge_bonus := 599;
    ELSIF p_final_amount >= 4999 THEN
      v_recharge_bonus := 399;
    ELSIF p_final_amount >= 1999 THEN
      v_recharge_bonus := 199;
    ELSIF p_final_amount >= 999 THEN
      v_recharge_bonus := 125;
    ELSIF p_final_amount >= 499 THEN
      v_recharge_bonus := 50;
    ELSIF p_final_amount >= 199 THEN
      v_recharge_bonus := 15;
    ELSIF p_final_amount >= 99 THEN
      v_recharge_bonus := 5;
    ELSE
      v_recharge_bonus := 0;
    END IF;

    -- First Time Purchase Bonus
    IF v_is_first_purchase THEN
      v_first_bonus_coins := 50;
      
      -- Grant First Purchase Frame
      INSERT INTO public.user_customizations (user_id, type, name, is_equipped)
      VALUES (p_user_id, 'Avatar Frame', 'Royal Frame', false)
      ON CONFLICT DO NOTHING;

      -- Mark first purchase completed permanently
      UPDATE public.profiles
      SET first_purchase_completed = true
      WHERE id = p_user_id;
    END IF;

    v_total_coins_credit := v_base_coins + v_recharge_bonus + v_first_bonus_coins;

    -- Credit to Coin Wallet
    INSERT INTO public.wallets (id, gold_coins, coins_balance, silver_coins, withdrawable_balance)
    VALUES (p_user_id, v_total_coins_credit, v_total_coins_credit, 0, 0.0)
    ON CONFLICT (id) DO UPDATE
    SET gold_coins = COALESCE(public.wallets.gold_coins, 0) + v_total_coins_credit,
        coins_balance = COALESCE(public.wallets.coins_balance, 0) + v_total_coins_credit;

    -- Transaction ledger with clear breakdown
    INSERT INTO public.wallet_transactions (wallet_id, amount, currency, type, status, details)
    VALUES (
      p_user_id,
      v_total_coins_credit,
      'Gold Coins',
      'Recharge',
      'Completed',
      'Base: ' || v_base_coins || ' Coins, Bonus: ' || v_recharge_bonus || ' Coins, First Purchase Bonus: ' || v_first_bonus_coins || ' Coins, Total Credited: ' || v_total_coins_credit || ' Coins'
    );

    RETURN jsonb_build_object(
      'success', true,
      'category', 'Coins',
      'base_coins', v_base_coins,
      'recharge_bonus', v_recharge_bonus,
      'first_purchase_bonus', v_first_bonus_coins,
      'total_coins_added', v_total_coins_credit
    );

  -- ── CATEGORY 2: VIP ────────────────────────────────────────────────────────
  ELSIF p_category = 'VIP' THEN
    -- Exact duration mapping
    v_base_days := CASE p_duration
      when '3 Days'   then 3
      when '7 Days'   then 7
      when '15 Days'  then 15
      when '30 Days'  then 30
      when '1 Month'  then 30
      when '90 Days'  then 90
      when '3 Months' then 90
      when '1 Year'   then 365
      when '365 Days' then 365
      else 30
    END;

    -- Promotional bonus days
    v_bonus_days := CASE v_base_days
      when 30  then 3
      when 90  then 10
      when 365 then 30
      else 0
    END;

    -- First Time VIP Purchase Offer
    IF v_is_first_vip_purchase THEN
      v_bonus_days := v_bonus_days + 3; -- +3 Extra First VIP Days
      v_first_bonus_coins := 20;

      -- Credit first VIP bonus coins
      INSERT INTO public.wallets (id, gold_coins, coins_balance, silver_coins, withdrawable_balance)
      VALUES (p_user_id, 20, 20, 0, 0.0)
      ON CONFLICT (id) DO UPDATE
      SET gold_coins = COALESCE(public.wallets.gold_coins, 0) + 20,
          coins_balance = COALESCE(public.wallets.coins_balance, 0) + 20;

      INSERT INTO public.wallet_transactions (wallet_id, amount, currency, type, status, details)
      VALUES (p_user_id, 20, 'Gold Coins', 'VIP First Purchase Reward', 'Completed', 'First VIP Purchase Bonus Coins');

      UPDATE public.profiles
      SET first_vip_purchase_completed = true,
          first_purchase_completed = true
      WHERE id = p_user_id;
    END IF;

    v_total_days := v_base_days + v_bonus_days;

    -- Fetch current active VIP subscription
    SELECT level, expiry_date INTO v_old_level, v_old_expiry
    FROM public.subscriptions
    WHERE user_id = p_user_id AND membership_type = 'VIP' AND status = 'Active'
    ORDER BY level DESC LIMIT 1;
    v_old_level := COALESCE(v_old_level, 0);

    -- Calculate expiry strictly without arbitrary multipliers
    IF v_old_expiry IS NOT NULL AND v_old_expiry > now() THEN
      v_new_expiry := v_old_expiry + (v_total_days || ' days')::interval;
    ELSE
      v_new_expiry := now() + (v_total_days || ' days')::interval;
    END IF;

    v_frame_name := CASE v_level
      when 1 then 'Royal Frame'            when 2 then 'Neon Frame (Animated)'
      when 3 then 'Gold Glow Frame'        when 4 then 'Diamond Frame'
      when 5 then 'Crystal Cyan Frame'     when 6 then 'Rainbow Frame (Animated)'
      when 7 then 'Royal Crown (Animated)' else 'Royal Frame' END;

    IF EXISTS (SELECT 1 FROM public.subscriptions WHERE user_id = p_user_id AND membership_type = 'VIP') THEN
      UPDATE public.subscriptions
      SET level           = GREATEST(subscriptions.level, v_level),
          activation_date = now(),
          expiry_date     = GREATEST(subscriptions.expiry_date, v_new_expiry),
          status          = 'Active',
          payment_id      = p_payment_id
      WHERE user_id = p_user_id AND membership_type = 'VIP';
    ELSE
      INSERT INTO public.subscriptions
        (user_id, membership_type, level, purchase_date, activation_date, expiry_date, auto_renewal, status, payment_id)
      VALUES (p_user_id, 'VIP', v_level, now(), now(), v_new_expiry, true, 'Active', p_payment_id);
    END IF;

    UPDATE public.profiles
    SET vip_level  = GREATEST(COALESCE(vip_level, 0), v_level),
        vip_expiry = GREATEST(COALESCE(vip_expiry, now()), v_new_expiry)
    WHERE id = p_user_id;

    -- Frame Equip
    INSERT INTO public.user_customizations (user_id, type, name, is_equipped)
    VALUES (p_user_id, 'Avatar Frame', v_frame_name, false)
    ON CONFLICT DO NOTHING;

    RETURN jsonb_build_object(
      'success', true,
      'category', 'VIP',
      'level', v_level,
      'base_days', v_base_days,
      'bonus_days', v_bonus_days,
      'total_days', v_total_days,
      'expiry', v_new_expiry,
      'frame_name', v_frame_name
    );

  -- ── CATEGORY 3: NOVEL ──────────────────────────────────────────────────────
  ELSIF p_category = 'Novel' THEN
    v_base_days := CASE p_duration
      when '3 Days'   then 3
      when '7 Days'   then 7
      when '15 Days'  then 15
      when '30 Days'  then 30
      when '1 Month'  then 30
      when '90 Days'  then 90
      when '3 Months' then 90
      when '1 Year'   then 365
      when '365 Days' then 365
      else 30
    END;

    v_bonus_days := CASE v_base_days
      when 30  then 3
      when 90  then 10
      when 365 then 30
      else 0
    END;

    -- First Time Novel Purchase Offer
    IF v_is_first_novel_purchase THEN
      v_bonus_days := v_bonus_days + 3;
      v_first_bonus_coins := 20;

      INSERT INTO public.wallets (id, gold_coins, coins_balance, silver_coins, withdrawable_balance)
      VALUES (p_user_id, 20, 20, 0, 0.0)
      ON CONFLICT (id) DO UPDATE
      SET gold_coins = COALESCE(public.wallets.gold_coins, 0) + 20,
          coins_balance = COALESCE(public.wallets.coins_balance, 0) + 20;

      INSERT INTO public.wallet_transactions (wallet_id, amount, currency, type, status, details)
      VALUES (p_user_id, 20, 'Gold Coins', 'Novel First Purchase Reward', 'Completed', 'First Novel Purchase Bonus Coins');

      UPDATE public.profiles
      SET first_novel_purchase_completed = true,
          first_purchase_completed = true
      WHERE id = p_user_id;
    END IF;

    v_total_days := v_base_days + v_bonus_days;

    SELECT level, expiry_date INTO v_old_level, v_old_expiry
    FROM public.subscriptions
    WHERE user_id = p_user_id AND membership_type = 'Novel' AND status = 'Active'
    ORDER BY level DESC LIMIT 1;

    IF v_old_expiry IS NOT NULL AND v_old_expiry > now() THEN
      v_new_expiry := v_old_expiry + (v_total_days || ' days')::interval;
    ELSE
      v_new_expiry := now() + (v_total_days || ' days')::interval;
    END IF;

    IF EXISTS (SELECT 1 FROM public.subscriptions WHERE user_id = p_user_id AND membership_type = 'Novel') THEN
      UPDATE public.subscriptions
      SET level           = GREATEST(subscriptions.level, v_level),
          activation_date = now(),
          expiry_date     = GREATEST(subscriptions.expiry_date, v_new_expiry),
          status          = 'Active',
          payment_id      = p_payment_id
      WHERE user_id = p_user_id AND membership_type = 'Novel';
    ELSE
      INSERT INTO public.subscriptions
        (user_id, membership_type, level, purchase_date, activation_date, expiry_date, auto_renewal, status, payment_id)
      VALUES (p_user_id, 'Novel', v_level, now(), now(), v_new_expiry, true, 'Active', p_payment_id);
    END IF;

    UPDATE public.profiles
    SET novel_level  = GREATEST(COALESCE(novel_level, 0), v_level),
        novel_expiry = GREATEST(COALESCE(novel_expiry, now()), v_new_expiry)
    WHERE id = p_user_id;

    RETURN jsonb_build_object(
      'success', true,
      'category', 'Novel',
      'level', v_level,
      'base_days', v_base_days,
      'bonus_days', v_bonus_days,
      'total_days', v_total_days,
      'expiry', v_new_expiry
    );
  END IF;

  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RAISE;
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.purchase_and_activate_rpc(uuid,text,text,numeric,numeric,text,text,text,text) TO authenticated, service_role;
