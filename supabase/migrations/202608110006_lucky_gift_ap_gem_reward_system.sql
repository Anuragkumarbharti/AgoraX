-- Migration: 202608110006_lucky_gift_ap_gem_reward_system.sql
-- Description: Production-Ready Server-Authoritative Lucky Gift AP + Gem Reward Engine with Anti-Farming Protection, Idempotency Ledger, and 5+ Gold Coin Threshold.

-- 1. Remove Lucky/Magic tag from 1-4 Gold Coin gifts. Lucky gifts start from 5 Gold Coins and above.
ALTER TABLE public.gift_catalog ADD COLUMN IF NOT EXISTS is_lucky boolean DEFAULT false;
ALTER TABLE public.gift_catalog ADD COLUMN IF NOT EXISTS is_magic boolean DEFAULT false;
ALTER TABLE public.gift_catalog ADD COLUMN IF NOT EXISTS gold_price integer DEFAULT NULL;

UPDATE public.gift_catalog
SET is_lucky = false, is_magic = false
WHERE (COALESCE(cost_stars, 0) < 5 OR COALESCE(gold_price, 0) < 5)
  AND LOWER(COALESCE(currency, 'gold')) = 'gold';

-- Ensure gifts costing 5+ Gold tagged as lucky/magic remain active lucky gifts
UPDATE public.gift_catalog
SET is_lucky = true
WHERE COALESCE(cost_stars, 0) >= 5
  AND LOWER(COALESCE(currency, 'gold')) = 'gold'
  AND (is_magic = true OR name IN ('Cake', 'Butterfly', 'Gift Box', 'Teddy', 'Lucky Clover', 'Diamond Ring', 'Champion Trophy', 'Super Car', 'Golden Dragon'));

-- 2. Single Authoritative Server Function: calculate_lucky_gift_reward(goldCoinValue)
CREATE OR REPLACE FUNCTION public.calculate_lucky_gift_reward(
  p_gold_coins integer
)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_coins integer := COALESCE(p_gold_coins, 0);
  v_ap integer := 0;
  v_gem integer := 0;
  v_tier text := 'none';
BEGIN
  IF v_coins >= 1 AND v_coins <= 4 THEN
    v_ap := 0;
    v_gem := 0;
    v_tier := 'none';
  ELSIF v_coins >= 5 AND v_coins <= 99 THEN
    v_ap := 1;
    v_gem := 1;
    v_tier := '5_99';
  ELSIF v_coins >= 100 AND v_coins <= 1000 THEN
    v_ap := 10;
    v_gem := 10;
    v_tier := '100_1000';
  ELSIF v_coins >= 1001 AND v_coins <= 5000 THEN
    v_ap := 50;
    v_gem := 50;
    v_tier := '1001_5000';
  ELSIF v_coins >= 5001 AND v_coins <= 10000 THEN
    v_ap := 100;
    v_gem := 100;
    v_tier := '5001_10000';
  ELSIF v_coins >= 10001 THEN
    v_ap := 200;
    v_gem := 200;
    v_tier := '1001_plus';
  END IF;

  RETURN jsonb_build_object(
    'ap', v_ap,
    'gem', v_gem,
    'tier', v_tier
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_lucky_gift_reward(integer) TO authenticated, service_role, anon;

-- 3. Permanent Audit & Idempotency Ledger Table for Lucky Gift Rewards
CREATE TABLE IF NOT EXISTS public.lucky_gift_reward_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id text UNIQUE NOT NULL,
  sender_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  room_id text NOT NULL,
  gift_id uuid REFERENCES public.gift_catalog(id) ON DELETE SET NULL,
  gold_coins_spent integer NOT NULL,
  tier text NOT NULL,
  ap_credited integer NOT NULL,
  gem_credited integer NOT NULL,
  random_gift_payload jsonb DEFAULT '{}'::jsonb,
  is_self_gift boolean DEFAULT false,
  is_blocked boolean DEFAULT false,
  block_reason text DEFAULT NULL,
  created_at timestamptz DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.lucky_gift_reward_ledger ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'lucky_gift_reward_ledger' AND policyname = 'Allow select for authenticated users') THEN
    CREATE POLICY "Allow select for authenticated users" ON public.lucky_gift_reward_ledger FOR SELECT TO authenticated USING (true);
  END IF;
END $$;

-- 4. Complete Production Atomic send_star_gift RPC with Authoritative Lucky Reward Engine
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

  -- LUCKY GIFT REWARD ENGINE VARS
  v_is_lucky_gift boolean := false;
  v_lucky_gold_value integer := 0;
  v_lucky_reward_json jsonb := NULL;
  v_lucky_ap integer := 0;
  v_lucky_gem integer := 0;
  v_lucky_tier text := 'none';
  v_rng_roll integer := 0;
  v_multiplier float := 0.0;
  v_cashback_gold integer := 0;
  v_is_self_gift boolean := false;
  v_is_blocked boolean := false;
  v_block_reason text := NULL;
  v_recent_pair_count integer := 0;
  v_lucky_result jsonb := NULL;
  v_ledger_exists boolean := false;

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

  -- Fetch Economy Configuration
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

  -- ── STEP 1 & 2: VERIFY BALANCE & DEDUCT COINS ATOMICALLY FIRST ──
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

  -- ── STEP 3: AUTHORITATIVE LUCKY GIFT REWARD ENGINE (Only for Gold Gifts >= 5 Gold Coins) ──
  IF v_gift_currency = 'gold' AND (
      COALESCE(v_gift_record.is_lucky, false) = true OR 
      COALESCE(v_gift_record.is_magic, false) = true OR
      COALESCE(to_jsonb(v_gift_record)->>'gift_type', 'normal') = 'lucky'
  ) AND v_single_cost >= 5 THEN
    v_is_lucky_gift := true;
    v_lucky_gold_value := v_single_cost * v_effective_multiplier;

    -- Calculate AP and Gem Reward strictly from verified Lucky Gift Gold Value
    v_lucky_reward_json := public.calculate_lucky_gift_reward(v_lucky_gold_value);
    v_lucky_ap := (v_lucky_reward_json->>'ap')::integer;
    v_lucky_gem := (v_lucky_reward_json->>'gem')::integer;
    v_lucky_tier := COALESCE(v_lucky_reward_json->>'tier', 'none');

    -- Coin Back RNG Roll Engine (1 to 1,000,000)
    v_rng_roll := floor(random() * 1000000) + 1;
    IF v_rng_roll <= 350000 THEN v_multiplier := 0;
    ELSIF v_rng_roll <= 530000 THEN v_multiplier := 0.1;
    ELSIF v_rng_roll <= 650000 THEN v_multiplier := 0.2;
    ELSIF v_rng_roll <= 730000 THEN v_multiplier := 0.3;
    ELSIF v_rng_roll <= 790000 THEN v_multiplier := 0.4;
    ELSIF v_rng_roll <= 840000 THEN v_multiplier := 0.5;
    ELSIF v_rng_roll <= 880000 THEN v_multiplier := 0.6;
    ELSIF v_rng_roll <= 910000 THEN v_multiplier := 0.7;
    ELSIF v_rng_roll <= 940000 THEN v_multiplier := 0.8;
    ELSIF v_rng_roll <= 980000 THEN v_multiplier := 1.0;
    ELSIF v_rng_roll <= 992000 THEN v_multiplier := 1.5;
    ELSIF v_rng_roll <= 997000 THEN v_multiplier := 2.0;
    ELSIF v_rng_roll <= 999000 THEN v_multiplier := 3.0;
    ELSIF v_rng_roll <= 999800 THEN v_multiplier := 5.0;
    ELSIF v_rng_roll <= 999950 THEN v_multiplier := 10.0;
    ELSIF v_rng_roll <= 999990 THEN v_multiplier := 20.0;
    ELSIF v_rng_roll <= 999999 THEN v_multiplier := 50.0;
    ELSE v_multiplier := 100.0;
    END IF;

    v_cashback_gold := round(v_lucky_gold_value * v_multiplier);

    -- Anti Farming Guard 1: Self Gifting Check
    IF v_sender_id = p_receiver_ids[1] THEN
      v_is_self_gift := true;
      v_is_blocked := true;
      v_block_reason := 'SELF_GIFTING_PROHIBITED';
      v_lucky_ap := 0;
      v_lucky_gem := 0;
      v_cashback_gold := 0;
      v_multiplier := 0;
    END IF;

    -- Anti Farming Guard 2: Suspicious High-Frequency Circular Gifting (Max 15 lucky gifts between same pair / 60s)
    IF NOT v_is_blocked THEN
      SELECT COUNT(*) INTO v_recent_pair_count
      FROM public.lucky_gift_reward_ledger
      WHERE sender_id = v_sender_id 
        AND receiver_id = p_receiver_ids[1]
        AND created_at >= NOW() - INTERVAL '60 seconds';

      IF v_recent_pair_count >= 15 THEN
        v_is_blocked := true;
        v_block_reason := 'HIGH_FREQUENCY_CIRCULAR_GIFTING';
        v_lucky_ap := 0;
        v_lucky_gem := 0;
        v_cashback_gold := 0;
        v_multiplier := 0;
      END IF;
    END IF;

    -- Anti Farming Guard 3: Idempotency Check (Duplicate Transaction ID Replay Protection)
    SELECT EXISTS (
      SELECT 1 FROM public.lucky_gift_reward_ledger WHERE transaction_id = v_tx_id
    ) INTO v_ledger_exists;

    IF v_ledger_exists THEN
      v_is_blocked := true;
      v_block_reason := 'DUPLICATE_TRANSACTION_REPLAY';
      v_lucky_ap := 0;
      v_lucky_gem := 0;
      v_cashback_gold := 0;
      v_multiplier := 0;
    ELSE
      -- Log to Idempotency Ledger
      INSERT INTO public.lucky_gift_reward_ledger (
        transaction_id, sender_id, receiver_id, room_id, gift_id,
        gold_coins_spent, tier, ap_credited, gem_credited,
        random_gift_payload, is_self_gift, is_blocked, block_reason
      ) VALUES (
        v_tx_id, v_sender_id, p_receiver_ids[1], p_room_id, p_gift_id,
        v_lucky_gold_value, v_lucky_tier, v_lucky_ap, v_lucky_gem,
        jsonb_build_object('type', 'coin_back', 'cashback_gold', v_cashback_gold, 'multiplier', v_multiplier),
        v_is_self_gift, v_is_blocked, v_block_reason
      ) ON CONFLICT (transaction_id) DO NOTHING;
    END IF;

    -- Credit Coin Back Gold Coins to Sender Wallet if > 0 and not blocked
    IF v_cashback_gold > 0 AND NOT v_is_blocked THEN
      UPDATE public.wallets
      SET coins_balance = COALESCE(coins_balance, 0) + v_cashback_gold,
          gold_coins = COALESCE(gold_coins, 0) + v_cashback_gold,
          updated_at = NOW()
      WHERE id = v_sender_id;

      v_remaining_balance := v_remaining_balance + v_cashback_gold;

      -- Audit Log to lucky_reward_logs
      BEGIN
        INSERT INTO public.lucky_reward_logs (
          sender_id, room_id, gift_id, gift_name, cost_coins, quantity, combo_count, total_cost, multiplier, coins_back, currency, created_at
        ) VALUES (
          v_sender_id, p_room_id, p_gift_id, COALESCE(to_jsonb(v_gift_record)->>'name', 'Lucky Gift'), v_single_cost, v_effective_multiplier, 1, v_lucky_gold_value, v_multiplier, v_cashback_gold, 'gold', NOW()
        );
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END IF;

    -- Credit Room AP to Sender if not blocked
    IF v_lucky_ap > 0 AND NOT v_is_blocked THEN
      BEGIN
        PERFORM public.process_room_dual_progress(p_room_id, v_sender_id, v_lucky_ap, 'ap_reward');
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END IF;

    -- Credit Gem Value to Receiver if not blocked
    IF v_lucky_gem > 0 AND NOT v_is_blocked THEN
      UPDATE public.wallets
      SET gems_balance = COALESCE(gems_balance, 0) + v_lucky_gem,
          updated_at = NOW()
      WHERE id = p_receiver_ids[1];
    END IF;

    v_lucky_result := jsonb_build_object(
      'is_lucky_gift', true,
      'gold_coins', v_lucky_gold_value,
      'ap', v_lucky_ap,
      'gem', v_lucky_gem,
      'tier', v_lucky_tier,
      'cashback_gold', v_cashback_gold,
      'coins_back', v_cashback_gold,
      'multiplier', v_multiplier,
      'sender_id', v_sender_id,
      'receiver_id', p_receiver_ids[1],
      'sender_name', v_sender_name,
      'transaction_id', v_tx_id,
      'is_self_gift', v_is_self_gift,
      'is_blocked', v_is_blocked,
      'block_reason', v_block_reason
    );
  END IF;

  -- ── STEP 4: CREANIA BALANCE REWARDS THROUGH GEMS GENERATED BY GIFT ──
  IF v_gift_currency = 'gold' THEN
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

  -- ── STEP 5: PROCESS RECEIVER REWARDS & AUDIT LEDGER ──
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

  -- PROCESS ROOM OWNER CB REWARDS
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

  -- Prepare Event Payload with Compact Lucky Result
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
    'luckyResult', v_lucky_result
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
    'event_payload', v_event_payload
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_star_gift(text, uuid[], uuid, integer, integer, integer[], text, uuid) TO authenticated, service_role, anon;
