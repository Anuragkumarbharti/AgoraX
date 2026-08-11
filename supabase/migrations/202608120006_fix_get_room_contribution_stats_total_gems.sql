-- ============================================================================
-- MIGRATION: 202608120006_fix_get_room_contribution_stats_total_gems.sql
-- DESCRIPTION: Ensure get_room_contribution_stats RPC computes accurate Total
--              and Today's Room Gems from both rooms table and gift_transactions.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_room_contribution_stats(p_room_id text)
RETURNS jsonb AS $$
DECLARE
  v_total_gems numeric := 0;
  v_total_gifts integer := 0;
  v_today_gems numeric := 0;
  v_today_gifts integer := 0;
  v_tx_total_gems numeric := 0;
  v_tx_today_gems numeric := 0;
  v_total_top_contributors jsonb;
  v_total_top_receivers jsonb;
  v_today_top_contributors jsonb;
  v_today_top_receivers jsonb;
BEGIN
  -- 1. Fetch current room table values
  SELECT COALESCE(total_room_gems, total_room_stars, 0), COALESCE(total_room_gifts, 0), COALESCE(today_room_gems, today_room_stars, 0), COALESCE(today_room_gifts, 0)
  INTO v_total_gems, v_total_gifts, v_today_gems, v_today_gifts
  FROM public.rooms WHERE id = p_room_id;

  -- 2. Calculate actual sums from gift_transactions
  SELECT COALESCE(SUM(COALESCE(gems_value, stars_value, 0)), 0)
  INTO v_tx_total_gems
  FROM public.gift_transactions
  WHERE room_id = p_room_id;

  SELECT COALESCE(SUM(COALESCE(gems_value, stars_value, 0)), 0)
  INTO v_tx_today_gems
  FROM public.gift_transactions
  WHERE room_id = p_room_id AND created_at >= CURRENT_DATE;

  -- 3. Take max value to ensure accuracy and repair room table if lagging
  IF v_tx_total_gems > v_total_gems THEN
    v_total_gems := v_tx_total_gems;
    UPDATE public.rooms SET total_room_gems = v_tx_total_gems WHERE id = p_room_id;
  END IF;

  IF v_tx_today_gems > v_today_gems THEN
    v_today_gems := v_tx_today_gems;
    UPDATE public.rooms SET today_room_gems = v_tx_today_gems WHERE id = p_room_id;
  END IF;

  -- 4. Total Top Contributors (Lifetime Givers by Gems)
  SELECT jsonb_agg(d) INTO v_total_top_contributors FROM (
    SELECT 
      t.sender_id AS user_id, 
      p.display_name AS username, 
      p.avatar_url AS avatar,
      SUM(COALESCE(t.gems_value, t.stars_value, 0)) AS gems_value,
      SUM(COALESCE(t.gems_value, t.stars_value, 0)) AS stars_value
    FROM public.gift_transactions t
    JOIN public.profiles p ON p.id = t.sender_id
    WHERE t.room_id = p_room_id
    GROUP BY t.sender_id, p.display_name, p.avatar_url
    ORDER BY gems_value DESC
    LIMIT 30
  ) d;

  -- 5. Total Top Receivers (Lifetime Receivers by Gems)
  SELECT jsonb_agg(d) INTO v_total_top_receivers FROM (
    SELECT 
      t.receiver_id AS user_id, 
      p.display_name AS username, 
      p.avatar_url AS avatar,
      SUM(COALESCE(t.gems_value, t.stars_value, 0)) AS gems_value,
      SUM(COALESCE(t.gems_value, t.stars_value, 0)) AS stars_value
    FROM public.gift_transactions t
    JOIN public.profiles p ON p.id = t.receiver_id
    WHERE t.room_id = p_room_id
    GROUP BY t.receiver_id, p.display_name, p.avatar_url
    ORDER BY gems_value DESC
    LIMIT 30
  ) d;

  -- 6. Today's Top Contributors (Today Givers by Gems)
  SELECT jsonb_agg(d) INTO v_today_top_contributors FROM (
    SELECT 
      t.sender_id AS user_id, 
      p.display_name AS username, 
      p.avatar_url AS avatar,
      SUM(COALESCE(t.gems_value, t.stars_value, 0)) AS gems_value,
      SUM(COALESCE(t.gems_value, t.stars_value, 0)) AS stars_value
    FROM public.gift_transactions t
    JOIN public.profiles p ON p.id = t.sender_id
    WHERE t.room_id = p_room_id AND t.created_at >= CURRENT_DATE
    GROUP BY t.sender_id, p.display_name, p.avatar_url
    ORDER BY gems_value DESC
    LIMIT 30
  ) d;

  -- 7. Today's Top Receivers (Today Receivers by Gems)
  SELECT jsonb_agg(d) INTO v_today_top_receivers FROM (
    SELECT 
      t.receiver_id AS user_id, 
      p.display_name AS username, 
      p.avatar_url AS avatar,
      SUM(COALESCE(t.gems_value, t.stars_value, 0)) AS gems_value,
      SUM(COALESCE(t.gems_value, t.stars_value, 0)) AS stars_value
    FROM public.gift_transactions t
    JOIN public.profiles p ON p.id = t.receiver_id
    WHERE t.room_id = p_room_id AND t.created_at >= CURRENT_DATE
    GROUP BY t.receiver_id, p.display_name, p.avatar_url
    ORDER BY gems_value DESC
    LIMIT 30
  ) d;

  RETURN jsonb_build_object(
    'total_gems', v_total_gems,
    'total_stars', v_total_gems,
    'total_gifts', v_total_gifts,
    'today_gems', v_today_gems,
    'today_stars', v_today_gems,
    'today_gifts', v_today_gifts,
    'total_top_contributors', COALESCE(v_total_top_contributors, '[]'::jsonb),
    'total_top_receivers', COALESCE(v_total_top_receivers, '[]'::jsonb),
    'today_top_contributors', COALESCE(v_today_top_contributors, '[]'::jsonb),
    'today_top_receivers', COALESCE(v_today_top_receivers, '[]'::jsonb)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
