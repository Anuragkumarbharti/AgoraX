-- Migration: Complete Seat Lock System v3.1 (UUID & Numeric ID Resolution Fix)
-- Created At: 2026-08-04

-- 1. Ensure seat lock columns exist on public.room_seats
ALTER TABLE public.room_seats
ADD COLUMN IF NOT EXISTS is_locked boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS locked_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS locked_at timestamptz;

-- 2. RPC: Toggle seat lock with backend permission validation and UUID resolution
CREATE OR REPLACE FUNCTION public.toggle_seat_lock(
  p_room_id text,
  p_seat_index int
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id uuid;
  v_caller_role text := 'Visitor';
  v_is_owner boolean := false;
  v_current_locked boolean := false;
  v_new_locked boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Resolve room UUID dynamically
  IF p_room_id ~* '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    v_room_id := p_room_id::uuid;
  ELSE
    SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      BEGIN
        v_room_id := p_room_id::uuid;
      EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Room not found for ID: %', p_room_id;
      END;
    END IF;
  END IF;

  -- Check if caller is room owner from rooms table
  SELECT (host_id = v_caller_id) INTO v_is_owner FROM public.rooms WHERE id = v_room_id;

  -- Fetch caller role from room_members
  SELECT role INTO v_caller_role FROM public.room_members 
  WHERE room_id = v_room_id AND user_id = v_caller_id;

  IF v_is_owner THEN v_caller_role := 'Owner'; END IF;

  -- Verify lock permissions (Owner, Co-Owner, Admin only)
  IF v_caller_role NOT IN ('Owner', 'Co-Owner', 'Co Owner', 'Admin') THEN
    RAISE EXCEPTION 'Only Room Owner, Co-Owners, or Admins can manage seat locks.';
  END IF;

  -- Get current seat lock status
  SELECT COALESCE(is_locked, false) INTO v_current_locked 
  FROM public.room_seats 
  WHERE room_id = v_room_id AND seat_index = p_seat_index;

  v_new_locked := NOT v_current_locked;

  -- Update room_seats table
  INSERT INTO public.room_seats (room_id, seat_index, is_locked, locked_by, locked_at, updated_at)
  VALUES (v_room_id, p_seat_index, v_new_locked, v_caller_id, now(), now())
  ON CONFLICT (room_id, seat_index) DO UPDATE 
  SET is_locked = v_new_locked,
      locked_by = CASE WHEN v_new_locked THEN v_caller_id ELSE NULL END,
      locked_at = CASE WHEN v_new_locked THEN now() ELSE NULL END,
      updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'seat_index', p_seat_index,
    'is_locked', v_new_locked,
    'locked_by', v_caller_id
  );
END;
$$;

-- 3. Update join_room_seat_v3 to reject joins on locked seats with UUID resolution
CREATE OR REPLACE FUNCTION public.join_room_seat_v3(
  p_room_id text,
  p_seat_index int
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_room_id uuid;
  v_role text := 'Visitor';
  v_is_owner boolean := false;
  v_room_level int := 1;
  v_max_co_hosts int := 2;
  v_is_locked boolean := false;
  v_occupant_id uuid := null;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Resolve room UUID dynamically
  IF p_room_id ~* '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    v_room_id := p_room_id::uuid;
  ELSE
    SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      BEGIN
        v_room_id := p_room_id::uuid;
      EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Room not found for ID: %', p_room_id;
      END;
    END IF;
  END IF;

  -- Check current seat lock status and occupant
  SELECT COALESCE(is_locked, false), user_id INTO v_is_locked, v_occupant_id
  FROM public.room_seats WHERE room_id = v_room_id AND seat_index = p_seat_index;

  -- Reject if seat is locked and user is not current occupant
  IF v_is_locked AND (v_occupant_id IS NULL OR v_occupant_id != v_user_id) THEN
    RAISE EXCEPTION 'This seat is locked by room management.';
  END IF;

  SELECT COALESCE(level, 1), (host_id = v_user_id)
  INTO v_room_level, v_is_owner
  FROM public.rooms WHERE id = v_room_id;

  SELECT role INTO v_role FROM public.room_members 
  WHERE room_id = v_room_id AND user_id = v_user_id;

  IF v_is_owner THEN v_role := 'Owner'; END IF;

  v_max_co_hosts := 2 * v_room_level;

  -- Seat 0 is Host Seat
  IF p_seat_index = 0 THEN
    IF v_role NOT IN ('Owner', 'Co-Owner', 'Co Owner', 'Admin', 'Host') THEN
      RAISE EXCEPTION 'Seat 1 (Host Seat) is restricted to Room Host, Admins, Co-Owners, or Owner.';
    END IF;
  END IF;

  -- Seats 1 to v_max_co_hosts are Co-Host Seats
  IF p_seat_index > 0 AND p_seat_index <= v_max_co_hosts THEN
    IF v_role NOT IN ('Owner', 'Co-Owner', 'Co Owner', 'Admin', 'Host', 'Co-Host', 'Co Host') THEN
      RAISE EXCEPTION 'Seat % (Co-Host Seat) is restricted to Co-Hosts, Admins, Co-Owners, or Owner.', p_seat_index + 1;
    END IF;
  END IF;

  -- Execute seat join in room_seats
  INSERT INTO public.room_seats (room_id, seat_index, user_id, updated_at)
  VALUES (v_room_id, p_seat_index, v_user_id, now())
  ON CONFLICT (room_id, seat_index) DO UPDATE 
  SET user_id = v_user_id, updated_at = now();

  -- Execute seat join in room_members
  INSERT INTO public.room_members (room_id, user_id, role, assigned_at, updated_at)
  VALUES (v_room_id, v_user_id, COALESCE(v_role, 'Member'), now(), now())
  ON CONFLICT (room_id, user_id) DO UPDATE SET updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'seat_index', p_seat_index,
    'role', COALESCE(v_role, 'Member')
  );
END;
$$;
