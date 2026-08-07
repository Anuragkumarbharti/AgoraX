-- Migration: 202608080001_rebuild_gift_system_35_gifts.sql
-- Complete rebuild of Gift Catalog with 35 gifts (29 Gold, 6 Silver) across 5 Tiers.
-- Uses valid UUIDs (hex characters 0-9, a-f). Updated 10 Gold items to 9 Gold.

BEGIN;

-- 1. Clear out previous gift catalog and categories
DELETE FROM public.gift_catalog;
DELETE FROM public.gift_categories;

-- 2. Seed Tier Categories
INSERT INTO public.gift_categories (id, name, icon, display_order) VALUES
('c1000000-0000-0000-0000-000000000001', 'Tier 1', '🥈', 1),
('c1000000-0000-0000-0000-000000000002', 'Tier 2', '🥇', 2),
('c1000000-0000-0000-0000-000000000003', 'Tier 3', '👑', 3),
('c1000000-0000-0000-0000-000000000004', 'Tier 4', '💎', 4),
('c1000000-0000-0000-0000-000000000005', 'Tier 5', '⚡', 5);

-- 3. Seed 35 New Gifts with Valid Hex UUIDs
-- 🥈 Tier 1 (15 Gifts: 3 Silver, 12 Gold)
INSERT INTO public.gift_catalog (id, category_id, name, icon, cost_stars, currency, rarity, is_active, is_magic) VALUES
-- Silver (3)
('f1000001-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'Rose', '🌹', 100, 'silver', 'Common', true, false),
('f1000001-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001', 'Heart', '❤️', 300, 'silver', 'Common', true, false),
('f1000001-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000001', 'Coffee', '☕', 800, 'silver', 'Common', true, false),
-- Gold (12)
('f1000001-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000001', 'Sakura', '🌸', 2, 'gold', 'Common', true, true), -- Lucky 1
('f1000001-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000001', 'Lucky Star', '⭐', 2, 'gold', 'Common', true, false),
('f1000001-0000-0000-0000-000000000006', 'c1000000-0000-0000-0000-000000000001', 'Chocolate', '🍫', 4, 'gold', 'Common', true, false),
('f1000001-0000-0000-0000-000000000007', 'c1000000-0000-0000-0000-000000000001', 'Balloon', '🎈', 4, 'gold', 'Common', true, false),
('f1000001-0000-0000-0000-000000000008', 'c1000000-0000-0000-0000-000000000001', 'Cake', '🍰', 5, 'gold', 'Common', true, false),
('f1000001-0000-0000-0000-000000000009', 'c1000000-0000-0000-0000-000000000001', 'Butterfly', '🦋', 5, 'gold', 'Common', true, false),
('f1000001-0000-0000-0000-000000000010', 'c1000000-0000-0000-0000-000000000001', 'Love Letter', '💌', 8, 'gold', 'Common', true, false),
('f1000001-0000-0000-0000-000000000011', 'c1000000-0000-0000-0000-000000000001', 'Gift Box', '🎁', 9, 'gold', 'Common', true, true), -- Lucky 2 (Updated to 9 Gold)
('f1000001-0000-0000-0000-000000000012', 'c1000000-0000-0000-0000-000000000001', 'Teddy', '🧸', 9, 'gold', 'Common', true, false), -- Updated to 9 Gold
('f1000001-0000-0000-0000-000000000013', 'c1000000-0000-0000-0000-000000000001', 'Lucky Clover', '🍀', 15, 'gold', 'Common', true, false),
('f1000001-0000-0000-0000-000000000014', 'c1000000-0000-0000-0000-000000000001', 'Moon', '🌙', 19, 'gold', 'Rare', true, false),
('f1000001-0000-0000-0000-000000000015', 'c1000000-0000-0000-0000-000000000001', 'Sunshine', '☀️', 19, 'gold', 'Rare', true, false),

-- 🥇 Tier 2 (7 Gifts: 2 Silver, 5 Gold)
-- Silver (2)
('f1000002-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000002', 'Bouquet', '💐', 2000, 'silver', 'Rare', true, false),
('f1000002-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000002', 'Birthday Cake', '🎂', 5000, 'silver', 'Rare', true, false),
-- Gold (5)
('f1000002-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000002', 'Diamond Ring', '💍', 29, 'gold', 'Epic', true, true), -- Lucky 3
('f1000002-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000002', 'Crown', '👑', 49, 'gold', 'Epic', true, false),
('f1000002-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000002', 'Golden Mic', '🎤', 79, 'gold', 'Epic', true, false),
('f1000002-0000-0000-0000-000000000006', 'c1000000-0000-0000-0000-000000000002', 'Champion Trophy', '🏆', 119, 'gold', 'Epic', true, true), -- Lucky 4
('f1000002-0000-0000-0000-000000000007', 'c1000000-0000-0000-0000-000000000002', 'Crystal Diamond', '💎', 149, 'gold', 'Epic', true, false),

-- 👑 Tier 3 (5 Gifts: 1 Silver, 4 Gold)
-- Silver (1)
('f1000003-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000003', 'Fireworks', '🎆', 10000, 'silver', 'Legendary', true, false),
-- Gold (4)
('f1000003-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000003', 'Super Car', '🏎️', 299, 'gold', 'Legendary', true, true), -- Lucky 5
('f1000003-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000003', 'Rocket', '🚀', 499, 'gold', 'Legendary', true, false),
('f1000003-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000003', 'Private Jet', '✈️', 799, 'gold', 'Legendary', true, false),
('f1000003-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000003', 'Treasure Chest', '💰', 999, 'gold', 'Legendary', true, false),

-- 💎 Tier 4 (4 Gifts: 0 Silver, 4 Gold)
('f1000004-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000004', 'Golden Dragon', '🐉', 1999, 'gold', 'Mythic', true, true), -- Lucky 6
('f1000004-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000004', 'Phoenix', '🔥', 2999, 'gold', 'Mythic', true, false),
('f1000004-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000004', 'Galaxy Portal', '🌌', 4499, 'gold', 'Mythic', true, false),
('f1000004-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000004', 'Crystal Castle', '🏰', 6999, 'gold', 'Mythic', true, false),

-- ⚡ Tier 5 (4 Gifts: 0 Silver, 4 Gold)
('f1000005-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000005', 'Celestial Emperor', '👑', 7999, 'gold', 'Mythic', true, false),
('f1000005-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000005', 'Planet Creation', '🌍', 19999, 'gold', 'Mythic', true, false),
('f1000005-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000005', 'World Tree', '🌳', 19999, 'gold', 'Mythic', true, false),
('f1000005-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000005', 'Infinity Cosmos', '🌠', 29999, 'gold', 'Mythic', true, false);

-- 4. Update send_star_gift RPC to seamlessly support 35 gifts & lucky rewards
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
  v_remaining_balance integer;
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

  v_single_cost := v_gift_record.cost_stars;
  v_receivers_count := array_length(p_receiver_ids, 1);
  IF v_receivers_count IS NULL OR v_receivers_count = 0 THEN
    v_receivers_count := 1;
  END IF;

  v_total_quantity := COALESCE(p_quantity, 1) * COALESCE(p_combo_count, 1);
  v_total_cost := v_single_cost * v_total_quantity * v_receivers_count;

  -- Balance Verification & Deduction
  IF v_gift_record.currency = 'gold' THEN
    SELECT coins_balance INTO v_user_gold FROM public.wallets WHERE id = v_sender_id FOR UPDATE;
    v_user_gold := COALESCE(v_user_gold, 0);

    IF v_user_gold < v_total_cost THEN
      RAISE EXCEPTION 'Insufficient Gold Coins. Required: %, Available: %', v_total_cost, v_user_gold;
    END IF;

    UPDATE public.wallets
    SET coins_balance = coins_balance - v_total_cost, updated_at = NOW()
    WHERE id = v_sender_id
    RETURNING coins_balance INTO v_remaining_balance;
  ELSE
    SELECT silver_coins_balance INTO v_user_silver FROM public.wallets WHERE id = v_sender_id FOR UPDATE;
    v_user_silver := COALESCE(v_user_silver, 0);

    IF v_user_silver < v_total_cost THEN
      RAISE EXCEPTION 'Insufficient Silver Coins. Required: %, Available: %', v_total_cost, v_user_silver;
    END IF;

    UPDATE public.wallets
    SET silver_coins_balance = silver_coins_balance - v_total_cost, updated_at = NOW()
    WHERE id = v_sender_id
    RETURNING silver_coins_balance INTO v_remaining_balance;
  END IF;

  -- Process Lucky Gift Cashback Logic for designated Lucky Gifts
  v_is_lucky := COALESCE(v_gift_record.is_magic, false);
  IF v_is_lucky AND v_gift_record.currency = 'gold' THEN
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
      SET coins_balance = coins_balance + v_cashback_gold, updated_at = NOW()
      WHERE id = v_sender_id
      RETURNING coins_balance INTO v_remaining_balance;
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

    INSERT INTO public.gift_transactions (
      room_id, sender_id, receiver_id, gift_id, gift_name, gift_icon, quantity, currency, amount, total_cost, stars_value, status
    ) VALUES (
      p_room_id, v_sender_id, v_receiver_id, p_gift_id, COALESCE(v_gift_record.name, 'Gift'), COALESCE(v_gift_record.icon, '🎁'), v_total_quantity, COALESCE(v_gift_record.currency, 'gold'), v_single_cost * v_total_quantity, v_single_cost * v_total_quantity, v_single_cost * v_total_quantity, 'completed'
    );
  END LOOP;

  -- VP Progress Calculation
  v_vp_earned := (v_total_cost * 1.5)::integer;

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
    'currency', v_gift_record.currency,
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
    'vp_result', jsonb_build_object('vp_earned', v_vp_earned),
    'lucky_result', v_lucky_result,
    'event_payload', v_event_payload
  );
END;
$$;

COMMIT;
