-- Migration: 202608080007_authoritative_gift_transaction_system.sql
-- Description: Server-authoritative, atomic, idempotent gifting transactions with race-condition safety and permanent persistence across room leave/re-entry/app restart.

-- 1. Ensure gift_transactions schema compatibility & idempotency_key column
ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS idempotency_key text;
ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS total_cost numeric;
ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS amount numeric;
ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS gift_name text;
ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS gift_icon text;
ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS stars_value numeric DEFAULT 0;
ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS gems_value numeric DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_gift_tx_idempotency ON public.gift_transactions(idempotency_key);
CREATE INDEX IF NOT EXISTS idx_gift_tx_sender_room ON public.gift_transactions(sender_id, room_id);

-- 2. Drop legacy signatures of send_star_gift to avoid overload ambiguity
DROP FUNCTION IF EXISTS public.send_star_gift(text, uuid[], uuid, integer, integer, integer[]);
DROP FUNCTION IF EXISTS public.send_star_gift(uuid, uuid[], uuid, integer, integer, integer[]);
DROP FUNCTION IF EXISTS public.send_star_gift(text, uuid[], uuid, integer, integer, integer[], text);
DROP FUNCTION IF EXISTS public.send_star_gift(text, uuid[], uuid, integer, integer, integer[], text, uuid);

-- 3. Create Canonical, Atomic, Idempotent send_star_gift RPC
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
BEGIN
  v_sender_id := COALESCE(p_sender_id, auth.uid());
  IF v_sender_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to send gifts.';
  END IF;

  -- Idempotency protection: If transaction_id already exists in gift_transactions, return previous result
  IF p_transaction_id IS NOT NULL AND p_transaction_id <> '' THEN
    IF EXISTS (
      SELECT 1 FROM public.gift_transactions 
      WHERE idempotency_key = p_transaction_id OR id::text = p_transaction_id
    ) THEN
      SELECT COALESCE(coins_balance, gold_coins, 0) INTO v_user_gold 
      FROM public.wallets WHERE id = v_sender_id;

      SELECT COALESCE(total_room_gems, 0) INTO v_total_gems 
      FROM public.rooms WHERE id = p_room_id;

      RETURN json_build_object(
        'success', true,
        'duplicate', true,
        'remaining_balance', COALESCE(v_user_gold, 0),
        'total_gems', COALESCE(v_total_gems, 0),
        'message', 'Gift transaction already processed (Idempotent).'
      );
    END IF;
  END IF;

  -- Ensure Sender Wallet Exists
  BEGIN
    INSERT INTO public.wallets (id, coins_balance, gold_coins, silver_coins_balance, silver_coins)
    VALUES (v_sender_id, 1000000, 1000000, 1000000, 1000000)
    ON CONFLICT (id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  -- Fetch Sender Profile
  SELECT username, avatar_url INTO v_sender_name, v_sender_avatar
  FROM public.profiles WHERE id = v_sender_id;
  IF v_sender_name IS NULL THEN
    v_sender_name := 'Member';
  END IF;

  -- Fetch Gift Catalog Record
  SELECT * INTO v_gift_record FROM public.gift_catalog WHERE id = p_gift_id;
  IF v_gift_record IS NULL THEN
    SELECT * INTO v_gift_record FROM public.gift_catalog LIMIT 1;
  END IF;

  v_single_cost := COALESCE(v_gift_record.cost_stars, 1);
  v_gift_currency := LOWER(COALESCE(v_gift_record.currency, 'gold'));
  v_receivers_count := array_length(p_receiver_ids, 1);
  IF v_receivers_count IS NULL OR v_receivers_count = 0 THEN
    v_receivers_count := 1;
  END IF;

  v_total_quantity := COALESCE(p_quantity, 1) * COALESCE(p_combo_count, 1);
  v_total_cost := v_single_cost * v_total_quantity * v_receivers_count;

  -- Calculate Universal Gem Values
  v_gem_unit_value := COALESCE(v_gift_record.gem_value, 0);
  IF v_gem_unit_value <= 0 THEN
    IF v_gift_currency = 'silver' THEN
      v_gem_unit_value := GREATEST(1, floor(v_single_cost / 100.0)::integer);
    ELSE
      v_gem_unit_value := v_single_cost;
    END IF;
  END IF;

  v_single_receiver_gems := v_gem_unit_value * v_total_quantity;
  v_total_gems := v_single_receiver_gems * v_receivers_count;

  -- Atomic Balance Verification & Row-Lock Deduction
  IF v_gift_currency = 'gold' THEN
    SELECT COALESCE(coins_balance, gold_coins, 0) INTO v_user_gold 
    FROM public.wallets 
    WHERE id = v_sender_id 
    FOR UPDATE;

    v_user_gold := COALESCE(v_user_gold, 0);

    IF v_user_gold < v_total_cost THEN
      RAISE EXCEPTION 'Insufficient Gold Coins. Required: %, Available: %', v_total_cost, v_user_gold;
    END IF;

    UPDATE public.wallets
    SET coins_balance = GREATEST(0, COALESCE(coins_balance, 0) - v_total_cost),
        gold_coins = GREATEST(0, COALESCE(gold_coins, 0) - v_total_cost),
        updated_at = NOW()
    WHERE id = v_sender_id
    RETURNING COALESCE(coins_balance, gold_coins, 0) INTO v_remaining_balance;
  ELSE
    SELECT COALESCE(silver_coins_balance, silver_coins, 0) INTO v_user_silver 
    FROM public.wallets 
    WHERE id = v_sender_id 
    FOR UPDATE;

    v_user_silver := COALESCE(v_user_silver, 0);

    IF v_user_silver < v_total_cost THEN
      RAISE EXCEPTION 'Insufficient Silver Coins. Required: %, Available: %', v_total_cost, v_user_silver;
    END IF;

    UPDATE public.wallets
    SET silver_coins_balance = GREATEST(0, COALESCE(silver_coins_balance, 0) - v_total_cost),
        silver_coins = GREATEST(0, COALESCE(silver_coins, 0) - v_total_cost),
        updated_at = NOW()
    WHERE id = v_sender_id
    RETURNING COALESCE(silver_coins_balance, silver_coins, 0) INTO v_remaining_balance;
  END IF;

  -- Lucky Gift Cashback Logic
  v_is_lucky := COALESCE(v_gift_record.is_magic, false) OR COALESCE(v_gift_record.is_lucky, false);
  IF v_is_lucky AND v_gift_currency = 'gold' THEN
    v_rand := random();
    IF v_rand < 0.01 THEN
      v_multiplier := 10.0; v_tier_won := 'jackpot';
    ELSIF v_rand < 0.05 THEN
      v_multiplier := 5.0; v_tier_won := 'huge_win';
    ELSIF v_rand < 0.20 THEN
      v_multiplier := 2.0; v_tier_won := 'big_win';
    ELSIF v_rand < 0.50 THEN
      v_multiplier := 1.0; v_tier_won := 'full_back';
    ELSIF v_rand < 0.80 THEN
      v_multiplier := 0.5; v_tier_won := 'half_back';
    ELSE
      v_multiplier := 0.0; v_tier_won := 'no_reward';
    END IF;

    v_cashback_gold := floor(v_total_cost * v_multiplier)::integer;
    IF v_cashback_gold > 0 THEN
      UPDATE public.wallets
      SET coins_balance = COALESCE(coins_balance, 0) + v_cashback_gold,
          gold_coins = COALESCE(gold_coins, 0) + v_cashback_gold,
          updated_at = NOW()
      WHERE id = v_sender_id
      RETURNING COALESCE(coins_balance, gold_coins, 0) INTO v_remaining_balance;
    END IF;

    v_lucky_result := jsonb_build_object(
      'is_lucky_gift', true,
      'tier', v_tier_won,
      'multiplier', v_multiplier,
      'cashback_gold', v_cashback_gold,
      'coins_back', v_cashback_gold,
      'currency', 'gold'
    );
  END IF;

  -- Record Gift Transactions & Atomically Update Target Seats
  v_receiver_idx := 1;
  FOREACH v_receiver_id IN ARRAY p_receiver_ids LOOP
    SELECT username INTO v_receiver_name FROM public.profiles WHERE id = v_receiver_id;

    v_seat_index := -1;
    IF p_seat_indices IS NOT NULL AND array_length(p_seat_indices, 1) >= v_receiver_idx THEN
      v_seat_index := p_seat_indices[v_receiver_idx];
    END IF;

    -- Insert Transaction Record
    INSERT INTO public.gift_transactions (
      room_id, sender_id, receiver_id, gift_id, gift_name, gift_icon, quantity, count, currency, amount, total_cost, stars_value, gems_value, status, idempotency_key
    ) VALUES (
      p_room_id, v_sender_id, v_receiver_id, p_gift_id, COALESCE(v_gift_record.name, 'Gift'), COALESCE(v_gift_record.icon, '🎁'), v_total_quantity, v_total_quantity, v_gift_currency, v_single_cost * v_total_quantity, v_single_cost * v_total_quantity, v_single_receiver_gems, v_single_receiver_gems, 'completed', p_transaction_id
    );

    -- Update Seat Session Gem Counter Atomically on room_seats
    IF v_seat_index >= 0 THEN
      UPDATE public.room_seats
      SET seat_session_gems = COALESCE(seat_session_gems, 0) + v_single_receiver_gems,
          seat_total_gems = COALESCE(seat_total_gems, 0) + v_single_receiver_gems,
          seat_total_stars = COALESCE(seat_total_stars, 0) + v_single_receiver_gems,
          seat_total_gifts = COALESCE(seat_total_gifts, 0) + v_total_quantity,
          last_gift_time = NOW()
      WHERE room_id = p_room_id AND seat_index = v_seat_index;
    ELSE
      UPDATE public.room_seats
      SET seat_session_gems = COALESCE(seat_session_gems, 0) + v_single_receiver_gems,
          seat_total_gems = COALESCE(seat_total_gems, 0) + v_single_receiver_gems,
          seat_total_stars = COALESCE(seat_total_stars, 0) + v_single_receiver_gems,
          seat_total_gifts = COALESCE(seat_total_gifts, 0) + v_total_quantity,
          last_gift_time = NOW()
      WHERE room_id = p_room_id AND user_id = v_receiver_id;
    END IF;

    v_receiver_idx := v_receiver_idx + 1;
  END LOOP;

  -- VP Progress Calculation
  v_vp_earned := v_total_gems;

  -- Process Dual Progress System (1 Gold Coin = +1 Room AP) & Daily Tasks
  BEGIN
    v_vp_result := public.process_room_dual_progress(
      p_room_id,
      v_sender_id,
      v_total_cost,
      CASE WHEN v_gift_currency = 'gold' THEN 'gold_gift' ELSE 'silver_gift' END
    );
  EXCEPTION WHEN OTHERS THEN
    v_vp_result := jsonb_build_object('vp_earned', v_vp_earned);
  END;

  BEGIN
    PERFORM public.update_user_daily_tasks_on_gift(
      v_sender_id,
      v_total_cost,
      v_gift_currency
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  -- Update Room Total & Today Gems Atomically on public.rooms
  BEGIN
    UPDATE public.rooms
    SET total_room_gems = COALESCE(total_room_gems, 0) + v_total_gems,
        today_room_gems = COALESCE(today_room_gems, 0) + v_total_gems,
        total_room_stars = COALESCE(total_room_stars, 0) + v_total_gems,
        today_room_stars = COALESCE(today_room_stars, 0) + v_total_gems,
        total_room_gifts = COALESCE(total_room_gifts, 0) + (v_total_quantity * v_receivers_count),
        today_room_gifts = COALESCE(today_room_gifts, 0) + (v_total_quantity * v_receivers_count),
        room_xp = COALESCE(room_xp, 0) + v_total_gems,
        today_room_xp = COALESCE(today_room_xp, 0) + v_total_gems,
        updated_at = NOW()
    WHERE id = p_room_id;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  -- Prepare Standard Realtime Event Payload
  v_event_payload := jsonb_build_object(
    'id', COALESCE(p_transaction_id, 'evt_' || extract(epoch from now())::bigint || '_' || (random()*1000)::int),
    'giftId', p_gift_id,
    'giftName', v_gift_record.name,
    'giftIcon', v_gift_record.icon,
    'senderId', v_sender_id,
    'senderName', v_sender_name,
    'senderAvatar', v_sender_avatar,
    'receiverIds', to_jsonb(p_receiver_ids),
    'receiverSeats', to_jsonb(p_seat_indices),
    'currency', v_gift_currency,
    'price', v_single_cost,
    'giftValue', v_gem_unit_value,
    'gemsValue', v_single_receiver_gems,
    'quantity', v_total_quantity,
    'count', v_total_quantity,
    'timestamp', extract(epoch from now())::bigint * 1000,
    'lucky_result', v_lucky_result
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
