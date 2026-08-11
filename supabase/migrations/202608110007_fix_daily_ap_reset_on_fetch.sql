-- Migration: 202608110007_fix_daily_ap_reset_on_fetch.sql
-- Description: Authoritative Room Dual Progress Fetch & Automatic 4 AM Daily Reset RPC engine.

-- 1. Create or Replace get_or_reset_room_dual_progress RPC
CREATE OR REPLACE FUNCTION public.get_or_reset_room_dual_progress(
  p_room_id text
) RETURNS jsonb AS $$
DECLARE
  v_rec record;
  v_current_reset_date date := ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date;
  v_last_reset_date date;
  v_is_weekend boolean := (extract(isodow from ((now() at time zone 'Asia/Kolkata') - interval '4 hours')) in (6, 7));
  v_free_limit integer := case when v_is_weekend then 1400 else 700 end;
  v_gold_limit integer := case when v_is_weekend then 2000 else 1000 end;
BEGIN
  IF p_room_id IS NULL OR p_room_id = '' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Invalid room_id');
  END IF;

  -- Lock & Fetch or Create room_dual_progress record atomically
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

  v_last_reset_date := coalesce(v_rec.last_reset_date, v_current_reset_date - interval '1 day');

  -- Execute 4:00 AM Server Timezone Daily Reset Check if stale date
  IF v_last_reset_date < v_current_reset_date THEN
    UPDATE public.room_dual_progress
    SET daily_free_progress = 0,
        normal_points = 0,
        free_task_limit = v_free_limit,
        normal_target = v_free_limit,
        daily_gold_progress = 0,
        gold_points = 0,
        gold_task_limit = v_gold_limit,
        gold_target = v_gold_limit,
        last_reset_date = v_current_reset_date,
        updated_at = NOW()
    WHERE room_id = p_room_id
    RETURNING * INTO v_rec;
  END IF;

  RETURN to_jsonb(v_rec);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_or_reset_room_dual_progress(text) TO authenticated, service_role, anon;
