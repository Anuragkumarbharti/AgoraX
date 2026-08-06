-- Migration: Voice Room Seat System Naming Fix (Host, Co Host, No.1 to No.8)
-- Date: 2026-08-06

-- 1. Helper Postgres function to resolve standard seat name by 0-based seat_index
CREATE OR REPLACE FUNCTION public.get_seat_name(p_seat_index int)
RETURNS text LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  CASE p_seat_index
    WHEN 0 THEN RETURN 'Host';
    WHEN 1 THEN RETURN 'Co Host';
    WHEN 2 THEN RETURN 'No.1';
    WHEN 3 THEN RETURN 'No.2';
    WHEN 4 THEN RETURN 'No.3';
    WHEN 5 THEN RETURN 'No.4';
    WHEN 6 THEN RETURN 'No.5';
    WHEN 7 THEN RETURN 'No.6';
    WHEN 8 THEN RETURN 'No.7';
    WHEN 9 THEN RETURN 'No.8';
    ELSE RETURN 'No.' || (p_seat_index - 1)::text;
  END CASE;
END;
$$;

-- 2. Update join_room_seat_v3 to use standard seat names in exception messages
CREATE OR REPLACE FUNCTION public.join_room_seat_v3(
  p_room_id text,
  p_seat_index int
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_user_id uuid := auth.uid();
  v_room_id uuid;
  v_is_locked boolean := false;
  v_current_occupant uuid;
  v_user_role text := 'Visitor';
  v_is_owner boolean := false;
  v_max_co_hosts int := 1;
BEGIN
  -- Resolve Room UUID
  IF p_room_id ~* '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    v_room_id := p_room_id::uuid;
  ELSE
    SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      BEGIN v_room_id := p_room_id::uuid; EXCEPTION WHEN OTHERS THEN v_room_id := NULL; END;
    END IF;
  END IF;

  IF v_room_id IS NULL THEN
    RAISE EXCEPTION 'Room not found.';
  END IF;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated.';
  END IF;

  -- Validate seat index boundaries
  IF p_seat_index < 0 OR p_seat_index >= 10 THEN
    RAISE EXCEPTION 'Invalid seat index. Must be between 0 and 9.';
  END IF;

  -- Check current seat lock status and occupant
  SELECT is_locked, user_id INTO v_is_locked, v_current_occupant
  FROM public.room_seats WHERE room_id = v_room_id AND seat_index = p_seat_index;

  -- Reject if seat is locked and user is not current occupant
  IF v_is_locked IS TRUE AND (v_current_occupant IS NULL OR v_current_occupant != v_user_id) THEN
    RAISE EXCEPTION 'This seat (%s) is locked by room management.', public.get_seat_name(p_seat_index);
  END IF;

  -- Check user permissions for Host and Co Host seats
  SELECT (host_id = v_user_id OR room_owner = v_user_id) INTO v_is_owner FROM public.rooms WHERE id = v_room_id;
  SELECT role INTO v_user_role FROM public.room_members WHERE room_id = v_room_id AND user_id = v_user_id;

  -- Host Seat (seat_index 0)
  IF p_seat_index = 0 THEN
    IF NOT (v_is_owner OR v_user_role IN ('Owner', 'Creator', 'Co-Owner', 'Co Owner', 'Admin', 'Moderator', 'Host')) THEN
      RAISE EXCEPTION 'Host seat is restricted to Room Host, Admins, Co-Owners, or Owner.';
    END IF;
  END IF;

  -- Co Host Seat (seat_index 1)
  IF p_seat_index = 1 THEN
    IF NOT (v_is_owner OR v_user_role IN ('Owner', 'Creator', 'Co-Owner', 'Co Owner', 'Admin', 'Moderator', 'Host')) THEN
      RAISE EXCEPTION 'Co Host seat is restricted to Co-Hosts, Admins, Co-Owners, or Owner.';
    END IF;
  END IF;

  -- Execute seat join in room_seats
  INSERT INTO public.room_seats (room_id, seat_index, user_id, updated_at)
  VALUES (v_room_id, p_seat_index, v_user_id, now())
  ON CONFLICT (room_id, seat_index) DO UPDATE 
    SET user_id = EXCLUDED.user_id, updated_at = now();

  -- Execute seat join in room_members
  INSERT INTO public.room_members (room_id, user_id, seat_number, updated_at)
  VALUES (v_room_id, v_user_id, p_seat_index + 1, now())
  ON CONFLICT (room_id, user_id) DO UPDATE 
    SET seat_number = EXCLUDED.seat_number, updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'seat_index', p_seat_index,
    'seat_name', public.get_seat_name(p_seat_index),
    'user_id', v_user_id
  );
END;
$$;
