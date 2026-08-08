-- Migration: 202608080006_seat_session_gem_system.sql
-- Description: State-based seat-session Gem counter system, root cause fix for unwanted 0 resets, atomic backend gift processing, room total/today gems tracking, duplicate event protection, and 1:1 Gold Coin to Room AP conversion.

BEGIN;

-- 1. Schema Enhancements on public.room_seats, public.room_members & public.rooms
ALTER TABLE public.room_seats ADD COLUMN IF NOT EXISTS seat_session_id text DEFAULT NULL;
ALTER TABLE public.room_seats ADD COLUMN IF NOT EXISTS seat_session_gems integer DEFAULT 0;
ALTER TABLE public.room_seats ADD COLUMN IF NOT EXISTS seat_total_gems numeric DEFAULT 0;
ALTER TABLE public.room_seats ADD COLUMN IF NOT EXISTS seat_total_stars numeric DEFAULT 0;

ALTER TABLE public.room_members ADD COLUMN IF NOT EXISTS seat_number integer DEFAULT NULL;
ALTER TABLE public.room_members ADD COLUMN IF NOT EXISTS seat_index integer DEFAULT NULL;

ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS total_room_gems numeric DEFAULT 0;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS today_room_gems numeric DEFAULT 0;

-- 2. Enhanced join_room_seat RPC to generate unique seat_session_id and initialize counter to 0
DROP FUNCTION IF EXISTS public.join_room_seat(text, integer);
DROP FUNCTION IF EXISTS public.join_room_seat(uuid, integer);
CREATE OR REPLACE FUNCTION public.join_room_seat(
  p_room_id text,
  p_seat_index integer
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_username text;
  v_new_role text;
  v_seat_session_id text;
  v_seat_session_gems integer;
  v_existing_session_id text;
  v_existing_session_gems integer;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated';
  END IF;

  SELECT username INTO v_username FROM public.profiles WHERE id = v_user_id;

  -- Check if user is ALREADY sitting on this exact seat in this room
  SELECT seat_session_id, COALESCE(seat_session_gems, 0)
  INTO v_existing_session_id, v_existing_session_gems
  FROM public.room_seats
  WHERE room_id = p_room_id AND seat_index = p_seat_index AND user_id = v_user_id;

  IF v_existing_session_id IS NOT NULL THEN
    -- User is re-asserting occupancy on the SAME seat! PRESERVE session ID and session gems!
    v_seat_session_id := v_existing_session_id;
    v_seat_session_gems := v_existing_session_gems;

    UPDATE public.room_seats
    SET username = v_username,
        mic_status = 'unmuted',
        updated_at = NOW()
    WHERE room_id = p_room_id AND seat_index = p_seat_index;
  ELSE
    -- User is taking a NEW seat!
    -- 1. Clear user from any OTHER seat in this room
    UPDATE public.room_seats
    SET user_id = NULL,
        seat_session_id = NULL,
        seat_session_gems = 0,
        seat_total_gems = 0,
        seat_total_stars = 0,
        mic_status = 'muted',
        is_speaking = false
    WHERE room_id = p_room_id AND user_id = v_user_id AND seat_index != p_seat_index;

    -- 2. Generate unique seat-session identifier and start at 0 gems
    v_seat_session_id := 'ss_' || replace(gen_random_uuid()::text, '-', '');
    v_seat_session_gems := 0;

    UPDATE public.room_seats
    SET user_id = v_user_id,
        username = v_username,
        seat_session_id = v_seat_session_id,
        seat_session_gems = 0,
        seat_total_gems = 0,
        seat_total_stars = 0,
        mic_status = 'unmuted',
        is_speaking = false,
        updated_at = NOW()
    WHERE room_id = p_room_id AND seat_index = p_seat_index;
  END IF;

  -- Determine role based on seat index
  IF p_seat_index = 0 THEN
    v_new_role := 'Host';
  ELSIF p_seat_index = 1 THEN
    v_new_role := 'Co-Host';
  ELSE
    v_new_role := 'Speaker';
  END IF;

  -- Update member role in room_members
  UPDATE public.room_members
  SET role = v_new_role,
      seat_number = p_seat_index + 1,
      last_heartbeat_at = NOW()
  WHERE room_id = p_room_id AND user_id = v_user_id;

  -- Broadcast activity event
  INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, seat_number, message)
  VALUES (p_room_id, 'seat_join', v_user_id, v_username, p_seat_index + 1, COALESCE(v_username, 'Member') || ' took Seat #' || (p_seat_index + 1));

  RETURN jsonb_build_object(
    'success', true,
    'seat_index', p_seat_index,
    'seat_session_id', v_seat_session_id,
    'seat_session_gems', v_seat_session_gems,
    'user_id', v_user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. Enhanced leave_room_seat RPC (resets ONLY specific left seat to 0)
DROP FUNCTION IF EXISTS public.leave_room_seat(text, integer);
DROP FUNCTION IF EXISTS public.leave_room_seat(uuid, integer);
CREATE OR REPLACE FUNCTION public.leave_room_seat(
  p_room_id text,
  p_seat_index integer
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_username text;
BEGIN
  IF v_user_id IS NOT NULL THEN
    SELECT username INTO v_username FROM public.profiles WHERE id = v_user_id;
  END IF;

  -- Reset ONLY the specific seat requested
  UPDATE public.room_seats
  SET user_id = NULL,
      seat_session_id = NULL,
      seat_session_gems = 0,
      seat_total_gems = 0,
      seat_total_stars = 0,
      mic_status = 'muted',
      is_speaking = false,
      updated_at = NOW()
  WHERE room_id = p_room_id AND seat_index = p_seat_index;

  -- Demote user to Listener in room_members
  IF v_user_id IS NOT NULL THEN
    UPDATE public.room_members
    SET role = 'Listener',
        seat_number = NULL
    WHERE room_id = p_room_id AND user_id = v_user_id;
  END IF;

  INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, seat_number, message)
  VALUES (p_room_id, 'seat_leave', v_user_id, v_username, p_seat_index + 1, COALESCE(v_username, 'Member') || ' left Seat #' || (p_seat_index + 1));

  RETURN jsonb_build_object(
    'success', true,
    'seat_index', p_seat_index,
    'seat_session_gems', 0
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. Atomic send_star_gift RPC with Seat Session Gem & Room Total/Today Gems
DROP FUNCTION IF EXISTS public.send_star_gift(text, uuid[], uuid, integer, integer, integer[]);
DROP FUNCTION IF EXISTS public.send_star_gift(uuid, uuid[], uuid, integer, integer, integer[]);
CREATE OR REPLACE FUNCTION public.send_star_gift(
  p_room_id text,
  p_receiver_ids uuid[],
  p_gift_id uuid,
  p_quantity integer DEFAULT 1,
  p_combo_count integer DEFAULT 1,
  p_seat_indices integer[] DEFAULT '{}'::integer[]
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sender_id uuid := auth.uid();
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
  v_seat_session_id text;
  v_seat_gems_array jsonb := '[]'::jsonb;
BEGIN
  IF v_sender_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to send gifts.';
  END IF;

  -- Auto-provision wallet if missing for sender
  BEGIN
    INSERT INTO public.wallets (id, coins_balance, gold_coins, silver_coins)
    VALUES (v_sender_id, 1000000, 1000000, 1000000)
    ON CONFLICT (id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  -- Fetch Sender Profile
  SELECT username, avatar_url INTO v_sender_name, v_sender_avatar
  FROM public.profiles WHERE id = v_sender_id;
  IF v_sender_name IS NULL THEN
    v_sender_name := 'Creania Member';
  END IF;

  -- Fetch Gift Catalog Record
  SELECT * INTO v_gift_record FROM public.gift_catalog WHERE id = p_gift_id;
  IF v_gift_record IS NULL THEN
    SELECT * INTO v_gift_record FROM public.gift_catalog LIMIT 1;
  END IF;

  v_single_cost := COALESCE(v_gift_record.cost_stars, 1);
  v_receivers_count := array_length(p_receiver_ids, 1);
  IF v_receivers_count IS NULL OR v_receivers_count = 0 THEN
    v_receivers_count := 1;
  END IF;

  v_total_quantity := COALESCE(p_quantity, 1) * COALESCE(p_combo_count, 1);
  v_total_cost := v_single_cost * v_total_quantity * v_receivers_count;

  -- Calculate Universal Gem Values
  v_gem_unit_value := COALESCE(v_gift_record.gem_value, 0);
  IF v_gem_unit_value <= 0 THEN
    IF LOWER(COALESCE(v_gift_record.currency, 'gold')) = 'silver' THEN
      v_gem_unit_value := GREATEST(1, floor(v_single_cost / 100.0)::integer);
    ELSE
      v_gem_unit_value := v_single_cost;
    END IF;
  END IF;

  v_single_receiver_gems := v_gem_unit_value * v_total_quantity;
  v_total_gems := v_single_receiver_gems * v_receivers_count;

  -- Balance Verification & Deduction
  IF LOWER(COALESCE(v_gift_record.currency, 'gold')) = 'gold' THEN
    SELECT COALESCE(coins_balance, gold_coins, 0) INTO v_user_gold 
    FROM public.wallets 
    WHERE id = v_sender_id 
    LIMIT 1 
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
    LIMIT 1 
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

  -- Process Lucky Gift Cashback Logic for designated Lucky Gifts
  v_is_lucky := COALESCE(v_gift_record.is_magic, false) OR COALESCE(v_gift_record.is_lucky, false);
  IF v_is_lucky AND LOWER(COALESCE(v_gift_record.currency, 'gold')) = 'gold' THEN
    v_rand := random();
    IF v_rand < 0.01 THEN
      v_multiplier := 10.0;
      v_tier_won := 'jackpot';
    ELSIF v_rand < 0.05 THEN
      v_multiplier := 5.0;
      v_tier_won := 'huge_win';
    ELSIF v_rand < 0.20 THEN
      v_multiplier := 2.0;
      v_tier_won := 'big_win';
    ELSIF v_rand < 0.50 THEN
      v_multiplier := 1.0;
      v_tier_won := 'full_back';
    ELSIF v_rand < 0.80 THEN
      v_multiplier := 0.5;
      v_tier_won := 'half_back';
    ELSE
      v_multiplier := 0.0;
      v_tier_won := 'no_reward';
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

  -- Record Gifting Logs & Atomically Update Target Seats
  v_receiver_idx := 1;
  FOREACH v_receiver_id IN ARRAY p_receiver_ids LOOP
    SELECT username INTO v_receiver_name FROM public.profiles WHERE id = v_receiver_id;

    v_seat_index := -1;
    IF p_seat_indices IS NOT NULL AND array_length(p_seat_indices, 1) >= v_receiver_idx THEN
      v_seat_index := p_seat_indices[v_receiver_idx];
    END IF;

    BEGIN
      INSERT INTO public.gift_transactions (
        room_id, sender_id, receiver_id, gift_id, gift_name, gift_icon, quantity, currency, amount, total_cost, stars_value, gems_value, status
      ) VALUES (
        p_room_id, v_sender_id, v_receiver_id, p_gift_id, COALESCE(v_gift_record.name, 'Gift'), COALESCE(v_gift_record.icon, '🎁'), v_total_quantity, COALESCE(v_gift_record.currency, 'gold'), v_single_cost * v_total_quantity, v_single_cost * v_total_quantity, v_single_receiver_gems, v_single_receiver_gems, 'completed'
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

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
      CASE WHEN LOWER(COALESCE(v_gift_record.currency, 'gold')) = 'gold' THEN 'gold_gift' ELSE 'silver_gift' END
    );
  EXCEPTION WHEN OTHERS THEN
    v_vp_result := jsonb_build_object('vp_earned', v_vp_earned);
  END;

  BEGIN
    PERFORM public.update_user_daily_tasks_on_gift(
      v_sender_id,
      v_total_cost,
      COALESCE(v_gift_record.currency, 'gold')
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
    'id', 'evt_' || extract(epoch from now())::bigint || '_' || (random()*1000)::int,
    'giftId', p_gift_id,
    'giftName', v_gift_record.name,
    'giftIcon', v_gift_record.icon,
    'senderId', v_sender_id,
    'senderName', v_sender_name,
    'senderAvatar', v_sender_avatar,
    'receiverIds', to_jsonb(p_receiver_ids),
    'receiverSeats', to_jsonb(p_seat_indices),
    'currency', COALESCE(v_gift_record.currency, 'gold'),
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

-- 5. Enhanced get_room_state_snapshot RPC to include seat_session_gems and total_room_gems
DROP FUNCTION IF EXISTS public.get_room_state_snapshot(text);
DROP FUNCTION IF EXISTS public.get_room_state_snapshot(uuid);
CREATE OR REPLACE FUNCTION public.get_room_state_snapshot(
  p_room_id text
) RETURNS jsonb AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_room jsonb;
  v_seats jsonb;
  v_members jsonb;
  v_requests jsonb;
  v_settings jsonb;
  v_chat_history jsonb;
  v_eye_count integer;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated';
  END IF;

  PERFORM public.cleanup_expired_room_members();

  -- Room metadata
  SELECT jsonb_build_object(
    'id', r.id,
    'name', r.name,
    'username', r.username,
    'description', r.description,
    'category', r.category,
    'language', r.language,
    'host_id', r.host_id,
    'status', r.status,
    'visibility', r.visibility,
    'online_members', r.online_members,
    'livekit_room_name', r.livekit_room_name,
    'avatar', r.avatar,
    'banner', r.banner,
    'is_permanent', r.is_permanent,
    'room_level', r.room_level,
    'room_xp', r.room_xp,
    'total_room_gems', COALESCE(r.total_room_gems, r.total_room_stars, 0),
    'today_room_gems', COALESCE(r.today_room_gems, r.today_room_stars, 0),
    'total_room_stars', COALESCE(r.total_room_stars, 0),
    'today_room_stars', COALESCE(r.today_room_stars, 0)
  ) INTO v_room
  FROM public.rooms r
  WHERE r.id = p_room_id;

  IF v_room IS NULL THEN
    RAISE EXCEPTION 'Room not found';
  END IF;

  SELECT count(*) INTO v_eye_count
  FROM public.room_members
  WHERE room_id = p_room_id;

  -- Room seats with seat_session_id & seat_session_gems
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'seatIndex', s.seat_index,
      'role', s.role,
      'userId', s.user_id,
      'seatSessionId', s.seat_session_id,
      'seatSessionGems', COALESCE(s.seat_session_gems, s.seat_total_gems, s.seat_total_stars, 0),
      'seatTotalGems', COALESCE(s.seat_total_gems, s.seat_total_stars, 0),
      'seatTotalStars', COALESCE(s.seat_total_stars, 0),
      'username', COALESCE(s.username, p.username, 'Seat ' || (s.seat_index + 1)),
      'avatar', COALESCE(s.avatar, p.avatar),
      'avatarFrame', s.avatar_frame,
      'level', COALESCE(s.level, p.level, 1),
      'vipLevel', COALESCE(s.vip_level, p.vip_level, 0),
      'nobleLevel', COALESCE(s.noble_level, p.novel_level, 0),
      'micStatus', s.mic_status,
      'isSpeaking', s.is_speaking,
      'silverGiftCount', COALESCE(g.silver_gift_count, 0)
    ) ORDER BY s.seat_index
  ), '[]'::jsonb) INTO v_seats
  FROM public.room_seats s
  LEFT JOIN public.profiles p ON p.id = s.user_id
  LEFT JOIN public.room_seat_gifts g ON g.room_id = s.room_id AND g.seat_index = s.seat_index
  WHERE s.room_id = p_room_id;

  -- Room members
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'userId', m.user_id,
      'username', p.username,
      'avatar', p.avatar,
      'role', m.role,
      'isMuted', m.is_muted,
      'hasRaisedHand', m.has_raised_hand,
      'joinedAt', m.joined_at,
      'level', p.level,
      'vipLevel', p.vip_level,
      'nobleLevel', p.novel_level
    ) ORDER BY m.joined_at ASC
  ), '[]'::jsonb) INTO v_members
  FROM public.room_members m
  LEFT JOIN public.profiles p ON p.id = m.user_id
  WHERE m.room_id = p_room_id;

  RETURN jsonb_build_object(
    'room', v_room,
    'seats', v_seats,
    'members', v_members,
    'eyeCount', v_eye_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMIT;
