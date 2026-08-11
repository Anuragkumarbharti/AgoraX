-- Migration: 202608110004_fix_silver_and_volt_room_gifting.sql
-- Description: Fix Silver Coin and Volt (Vault) room gifting, ensure Silver and Volt gifts increment ONLY Normal (Free) Tasks and NEVER Gold Tasks.

BEGIN;

-- 1. Ensure wallets table defaults and topup values for silver coins
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS silver_coins_balance INTEGER DEFAULT 1000000;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS silver_coins INTEGER DEFAULT 1000000;

UPDATE public.wallets
SET silver_coins_balance = GREATEST(COALESCE(silver_coins_balance, 0), COALESCE(silver_coins, 0), 1000000),
    silver_coins = GREATEST(COALESCE(silver_coins, 0), COALESCE(silver_coins_balance, 0), 1000000),
    coins_balance = GREATEST(COALESCE(coins_balance, 0), COALESCE(gold_coins, 0), 1000000),
    gold_coins = GREATEST(COALESCE(gold_coins, 0), COALESCE(coins_balance, 0), 1000000);

-- 2. Core Centralized Atomic RPC: process_room_dual_progress
CREATE OR REPLACE FUNCTION public.process_room_dual_progress(
  p_room_id text,
  p_user_id uuid,
  p_points integer,
  p_source text DEFAULT 'gold_gift'
) RETURNS jsonb AS $$
DECLARE
  v_rec record;
  v_source_clean text := lower(coalesce(p_source, 'gold_gift'));
  v_is_gold boolean := (v_source_clean in ('gold_gift', 'gold', 'gold_coin'));
  v_is_silver boolean := (v_source_clean in ('silver_gift', 'silver', 'silver_coin'));
  v_is_volt boolean := (v_source_clean in ('volt_gift', 'volt', 'volt_coin'));
  v_effective_points integer := 0;

  v_current_reset_date date := ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date;
  v_last_reset_date date;

  v_is_weekend boolean := (extract(isodow from ((now() at time zone 'Asia/Kolkata') - interval '4 hours')) in (6, 7));

  v_daily_free integer := 0;
  v_daily_gold integer := 0;
  v_total_task integer := 0;
  v_total_lifetime integer := 0;

  -- Weekday: Free 700 + Gold 1000 = 1700 AP Limit
  -- Weekend: Free 1400 + Gold 2000 = 3400 AP Limit (2x Boost)
  v_free_limit integer := case when v_is_weekend then 1400 else 700 end;
  v_gold_limit integer := case when v_is_weekend then 2000 else 1000 end;

  v_free_capacity integer := 0;
  v_gold_capacity integer := 0;
  v_remaining_gold_points integer := 0;

  v_added_free integer := 0;
  v_added_gold integer := 0;
  v_added_total integer := 0;

  v_room_level integer := 1;
  v_required_task integer := 35500;
  v_did_level_up boolean := false;
BEGIN
  -- Validate Inputs
  IF p_room_id IS NULL OR p_room_id = '' OR p_points <= 0 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Invalid input parameters');
  END IF;

  -- 1. Calculate Effective AP Task Points from Source
  IF v_is_gold THEN
    v_effective_points := p_points; -- 1 Gold Coin = 1 AP = 1 Gem
  ELSIF v_is_silver THEN
    v_effective_points := floor(p_points / 100.0)::integer; -- 100 Silver Coins = 1 Free AP = 1 Gem
  ELSIF v_is_volt THEN
    v_effective_points := p_points; -- Volt AP = 1 Gem
  ELSIF v_source_clean in ('like', 'likes') THEN
    v_effective_points := greatest(1, floor(p_points / 10.0)::integer);
  ELSIF v_source_clean in ('room_stay', 'stay') THEN
    v_effective_points := greatest(1, floor(p_points / 3.0)::integer);
  ELSE
    v_effective_points := p_points; -- Mic time, seat bonus, first gift bonus, etc.
  END IF;

  IF v_effective_points <= 0 THEN
    RETURN jsonb_build_object('success', true, 'added_free', 0, 'added_gold', 0, 'reason', 'Below minimum AP conversion threshold');
  END IF;

  -- 2. Lock & Fetch or Create room_dual_progress record atomically
  INSERT INTO public.room_dual_progress (
    room_id,
    daily_free_progress, free_task_limit,
    daily_gold_progress, gold_task_limit,
    total_task, total_lifetime_task, last_reset_date,
    gold_points, gold_target,
    normal_points, normal_target,
    room_level
  ) VALUES (
    p_room_id,
    0, v_free_limit,
    0, v_gold_limit,
    0, 0, v_current_reset_date,
    0, v_gold_limit,
    0, v_free_limit,
    1
  ) ON CONFLICT (room_id) DO NOTHING;

  SELECT * INTO v_rec
  FROM public.room_dual_progress
  WHERE room_id = p_room_id
  FOR UPDATE;

  -- 3. Execute 4:00 AM Server Timezone Daily Reset Check
  v_last_reset_date := coalesce(v_rec.last_reset_date, v_current_reset_date - interval '1 day');
  v_total_task := coalesce(v_rec.total_task, 0);
  v_total_lifetime := coalesce(v_rec.total_lifetime_task, 0);

  IF v_last_reset_date < v_current_reset_date THEN
    v_daily_free := 0;
    v_daily_gold := 0;
    v_last_reset_date := v_current_reset_date;
  ELSE
    v_daily_free := coalesce(v_rec.daily_free_progress, v_rec.normal_points, 0);
    v_daily_gold := coalesce(v_rec.daily_gold_progress, v_rec.gold_points, 0);
  END IF;

  v_room_level := coalesce(v_rec.room_level, 1);

  -- 4. Execute Daily Task Bucket Allocation Logic
  IF v_is_gold THEN
    -- Gold Gifts FIRST fill GOLD TASK up to v_gold_limit
    v_gold_capacity := greatest(0, v_gold_limit - v_daily_gold);
    v_added_gold := least(v_effective_points, v_gold_capacity);

    -- Excess gold AP after Gold Task is complete spills over into NORMAL/FREE TASK
    v_remaining_gold_points := v_effective_points - v_added_gold;
    IF v_remaining_gold_points > 0 THEN
      v_free_capacity := greatest(0, v_free_limit - v_daily_free);
      v_added_free := least(v_remaining_gold_points, v_free_capacity);
    ELSE
      v_added_free := 0;
    END IF;
  ELSE
    -- Silver gifts, Volt gifts, Mic time, Seat bonus, Free activities ONLY increase Free Task!
    -- MUST NEVER increase Gold Task!
    v_free_capacity := greatest(0, v_free_limit - v_daily_free);
    v_added_free := least(v_effective_points, v_free_capacity);
    v_added_gold := 0;
  END IF;

  -- 5. Update State Counters
  v_daily_free := v_daily_free + v_added_free;
  v_daily_gold := v_daily_gold + v_added_gold;

  -- Every valid Daily Task contribution is permanently added to Total Task and Total Lifetime Task
  v_added_total := v_added_free + v_added_gold;
  v_total_task := v_total_task + v_added_total;
  v_total_lifetime := v_total_lifetime + v_added_total;

  -- 6. Room Level Calculation
  v_required_task := public.get_required_task_for_level(v_room_level);

  WHILE v_room_level < 7 AND v_total_task >= v_required_task LOOP
    v_room_level := v_room_level + 1;
    v_total_task := v_total_task - v_required_task;
    v_did_level_up := true;
    v_required_task := public.get_required_task_for_level(v_room_level);
  END LOOP;

  -- 7. Persist to room_dual_progress table
  UPDATE public.room_dual_progress
  SET daily_free_progress = v_daily_free,
      free_task_limit = v_free_limit,
      daily_gold_progress = v_daily_gold,
      gold_task_limit = v_gold_limit,
      total_task = v_total_task,
      total_lifetime_task = v_total_lifetime,
      last_reset_date = v_last_reset_date,
      normal_points = v_daily_free,
      normal_target = v_free_limit,
      gold_points = v_daily_gold,
      gold_target = v_gold_limit,
      room_level = v_room_level,
      updated_at = NOW()
  WHERE room_id = p_room_id;

  RETURN jsonb_build_object(
    'success', true,
    'added_free', v_added_free,
    'added_gold', v_added_gold,
    'daily_free_progress', v_daily_free,
    'free_task_limit', v_free_limit,
    'daily_gold_progress', v_daily_gold,
    'gold_task_limit', v_gold_limit,
    'total_task', v_total_task,
    'total_task_target', v_required_task,
    'total_lifetime_task', v_total_lifetime,
    'room_level', v_room_level,
    'did_level_up', v_did_level_up,
    'is_free_limit_reached', (v_daily_free >= v_free_limit),
    'is_gold_limit_reached', (v_daily_gold >= v_gold_limit)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Production Atomic send_star_gift RPC
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
BEGIN
  v_sender_id := COALESCE(p_sender_id, auth.uid());
  IF v_sender_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to send gifts.';
  END IF;

  -- Ensure Sender Wallet Exists with Default 1,000,000 Coins
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
  IF v_sender_name IS NULL THEN
    v_sender_name := 'Member';
  END IF;

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

  -- Universal Gem Values
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
    SELECT GREATEST(COALESCE(silver_coins_balance, 0), COALESCE(silver_coins, 0), 1000000) INTO v_user_silver 
    FROM public.wallets 
    WHERE id = v_sender_id 
    FOR UPDATE;

    v_user_silver := COALESCE(v_user_silver, 1000000);

    IF v_user_silver < v_total_cost THEN
      RAISE EXCEPTION 'Insufficient Silver Coins. Required: %, Available: %', v_total_cost, v_user_silver;
    END IF;

    UPDATE public.wallets
    SET silver_coins_balance = GREATEST(0, COALESCE(silver_coins_balance, 1000000) - v_total_cost),
        silver_coins = GREATEST(0, COALESCE(silver_coins, 1000000) - v_total_cost),
        updated_at = NOW()
    WHERE id = v_sender_id
    RETURNING COALESCE(silver_coins_balance, silver_coins, 0) INTO v_remaining_balance;
  END IF;

  -- Lucky Gift Cashback Logic (Gold only)
  v_is_lucky := COALESCE((to_jsonb(v_gift_record)->>'is_magic')::boolean, false) OR COALESCE((to_jsonb(v_gift_record)->>'is_lucky')::boolean, false);
  IF v_is_lucky AND v_gift_currency = 'gold' THEN
    v_rand := random();
    IF v_rand < 0.01 THEN v_multiplier := 10.0; v_tier_won := 'jackpot';
    ELSIF v_rand < 0.05 THEN v_multiplier := 5.0; v_tier_won := 'huge_win';
    ELSIF v_rand < 0.20 THEN v_multiplier := 2.0; v_tier_won := 'big_win';
    ELSIF v_rand < 0.50 THEN v_multiplier := 1.0; v_tier_won := 'full_back';
    ELSIF v_rand < 0.80 THEN v_multiplier := 0.5; v_tier_won := 'half_back';
    ELSE v_multiplier := 0.0; v_tier_won := 'no_reward';
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

  -- Record Gift Transactions & Update Target Seats
  v_receiver_idx := 1;
  FOREACH v_receiver_id IN ARRAY p_receiver_ids LOOP
    SELECT username INTO v_receiver_name FROM public.profiles WHERE id = v_receiver_id;

    v_seat_index := -1;
    IF p_seat_indices IS NOT NULL AND array_length(p_seat_indices, 1) >= v_receiver_idx THEN
      v_seat_index := p_seat_indices[v_receiver_idx];
    END IF;

    INSERT INTO public.gift_transactions (
      room_id, sender_id, receiver_id, gift_id, gift_name, gift_icon, quantity, count, currency, amount, total_cost, stars_value, gems_value, status, idempotency_key, is_self_gift
    ) VALUES (
      p_room_id, v_sender_id, v_receiver_id, p_gift_id, COALESCE(to_jsonb(v_gift_record)->>'name', 'Gift'), COALESCE(to_jsonb(v_gift_record)->>'icon', '🎁'), v_effective_multiplier, v_effective_multiplier, v_gift_currency, v_single_cost, (v_single_cost * v_effective_multiplier), v_single_receiver_gems, v_single_receiver_gems, 'completed', p_transaction_id, (v_sender_id = v_receiver_id)
    );

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

  v_vp_earned := v_total_gems;

  -- Process Dual Progress (Gold -> Gold Task; Silver/Volt -> Normal Task ONLY)
  BEGIN
    v_vp_result := public.process_room_dual_progress(
      p_room_id,
      v_sender_id,
      v_total_cost,
      CASE 
        WHEN v_gift_currency = 'gold' THEN 'gold_gift'
        WHEN v_gift_currency = 'volt' THEN 'volt_gift'
        ELSE 'silver_gift' 
      END
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
        total_room_gifts = COALESCE(total_room_gifts, 0) + v_total_quantity,
        today_room_gifts = COALESCE(today_room_gifts, 0) + v_total_quantity,
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
    'giftName', COALESCE(to_jsonb(v_gift_record)->>'name', 'Gift'),
    'giftIcon', COALESCE(to_jsonb(v_gift_record)->>'icon', '🎁'),
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
    'multiplier', v_effective_multiplier,
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

COMMIT;
