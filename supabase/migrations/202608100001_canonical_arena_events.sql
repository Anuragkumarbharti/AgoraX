-- Migration: 202608100001_canonical_arena_events.sql
-- Description: Enforce single canonical Arena activity event pipeline, remove redundant unformatted DB activity inserts in join_room_seat and leave_room_seat.

-- 1. Ensure event_id column exists on room_activity_events table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'room_activity_events'
    AND column_name = 'event_id'
  ) THEN
    ALTER TABLE public.room_activity_events ADD COLUMN event_id text;
  END IF;
END $$;

-- 2. Update join_room_seat to perform state updates without emitting raw duplicate strings
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
    -- User is re-asserting occupancy on the SAME seat
    v_seat_session_id := v_existing_session_id;
    v_seat_session_gems := v_existing_session_gems;

    UPDATE public.room_seats
    SET username = v_username,
        mic_status = 'unmuted',
        updated_at = NOW()
    WHERE room_id = p_room_id AND seat_index = p_seat_index;
  ELSE
    -- User is taking a NEW seat
    -- Clear user from any OTHER seat in this room
    UPDATE public.room_seats
    SET user_id = NULL,
        seat_session_id = NULL,
        seat_session_gems = 0,
        seat_total_gems = 0,
        seat_total_stars = 0,
        mic_status = 'muted',
        is_speaking = false
    WHERE room_id = p_room_id AND user_id = v_user_id AND seat_index != p_seat_index;

    -- Generate unique seat-session identifier
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

  RETURN jsonb_build_object(
    'success', true,
    'seat_index', p_seat_index,
    'seat_session_id', v_seat_session_id,
    'seat_session_gems', v_seat_session_gems,
    'user_id', v_user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. Update leave_room_seat to perform state updates without emitting raw duplicate strings
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

  RETURN jsonb_build_object(
    'success', true,
    'seat_index', p_seat_index,
    'seat_session_gems', 0
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
