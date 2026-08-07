-- Migration: 202608080003_fix_send_star_gift_overload_conflict.sql
-- Description: Ensure total_cost & amount schema compatibility on gift_transactions, drop overloaded send_star_gift signatures, update room dual progress AP tasks, and create canonical send_star_gift RPC.

BEGIN;

-- 1. Ensure gift_transactions schema compatibility for total_cost, amount, gift_name, gift_icon, stars_value
ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS total_cost numeric;
ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS amount numeric;
ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS gift_name text;
ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS gift_icon text;
ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS stars_value numeric DEFAULT 0;
ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS gems_value numeric DEFAULT 0;

-- 2. Explicitly drop all historical overloaded send_star_gift RPC signatures
DROP FUNCTION IF EXISTS public.send_star_gift(text, uuid[], uuid, integer, integer, integer[]);
DROP FUNCTION IF EXISTS public.send_star_gift(uuid, uuid[], uuid, integer, integer, integer[]);
DROP FUNCTION IF EXISTS public.send_star_gift(text, uuid[], uuid, integer, integer);
DROP FUNCTION IF EXISTS public.send_star_gift(uuid, uuid[], uuid, integer, integer);
DROP FUNCTION IF EXISTS public.send_star_gift(text, uuid[], uuid, integer);
DROP FUNCTION IF EXISTS public.send_star_gift(uuid, uuid[], uuid, integer);
DROP FUNCTION IF EXISTS public.send_star_gift(text, uuid[], uuid);
DROP FUNCTION IF EXISTS public.send_star_gift(uuid, uuid[], uuid);
DROP FUNCTION IF EXISTS public.send_star_gift(text, uuid[], uuid, integer, integer, integer[], text);
DROP FUNCTION IF EXISTS public.send_star_gift(uuid, uuid[], uuid, integer, integer, integer[], text);

-- 3. Create single canonical production send_star_gift RPC with p_room_id text
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
  v_lucky_result jsonb := null;
  v_rand float;
  v_multiplier float := 0.0;
  v_tier_won text := 'no_reward';
  v_cashback_gold integer := 0;
  v_event_payload jsonb;
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

  -- Balance Verification & Deduction
  IF COALESCE(v_gift_record.currency, 'gold') = 'gold' THEN
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
  v_is_lucky := COALESCE(v_gift_record.is_magic, false);
  IF v_is_lucky AND COALESCE(v_gift_record.currency, 'gold') = 'gold' THEN
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

  -- Record Gifting Log & Room Activity
  FOREACH v_receiver_id IN ARRAY p_receiver_ids LOOP
    SELECT username INTO v_receiver_name FROM public.profiles WHERE id = v_receiver_id;

    BEGIN
      INSERT INTO public.gift_transactions (
        room_id, sender_id, receiver_id, gift_id, gift_name, gift_icon, quantity, currency, amount, total_cost, stars_value, status
      ) VALUES (
        p_room_id, v_sender_id, v_receiver_id, p_gift_id, COALESCE(v_gift_record.name, 'Gift'), COALESCE(v_gift_record.icon, '🎁'), v_total_quantity, COALESCE(v_gift_record.currency, 'gold'), v_single_cost * v_total_quantity, v_single_cost * v_total_quantity, v_single_cost * v_total_quantity, 'completed'
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;

  -- VP Progress Calculation
  v_vp_earned := (v_total_cost * 1.5)::integer;

  -- Process Dual Progress System (Gold Progress + Normal AP Overflow) & Daily Tasks
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

  -- Update Room Stars / Gifts Stats if rooms table exists
  BEGIN
    UPDATE public.rooms
    SET total_room_stars = COALESCE(total_room_stars, 0) + v_total_cost,
        today_room_stars = COALESCE(today_room_stars, 0) + v_total_cost,
        total_room_gifts = COALESCE(total_room_gifts, 0) + (v_total_quantity * v_receivers_count),
        today_room_gifts = COALESCE(today_room_gifts, 0) + (v_total_quantity * v_receivers_count),
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
    'quantity', v_total_quantity,
    'count', v_total_quantity,
    'timestamp', extract(epoch from now())::bigint * 1000,
    'lucky_result', v_lucky_result
  );

  RETURN json_build_object(
    'success', true,
    'remaining_balance', v_remaining_balance,
    'total_cost', v_total_cost,
    'vp_earned', v_vp_earned,
    'vp_result', v_vp_result,
    'lucky_result', v_lucky_result,
    'event_payload', v_event_payload
  );
END;
$$;

COMMIT;
