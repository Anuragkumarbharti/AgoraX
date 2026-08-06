-- Migration: Creaniaa Room Role System (Unified Creator/Owner, Level-Based Limits, Entry Permissions)
-- Date: 2026-08-06

-- 0. Drop existing functions to allow changing return signatures cleanly
DROP FUNCTION IF EXISTS public.get_room_role_limits(text);
DROP FUNCTION IF EXISTS public.can_change_room_entry_rules(text, uuid);
DROP FUNCTION IF EXISTS public.promote_room_member_role(text, uuid, text);
DROP FUNCTION IF EXISTS public.demote_room_member_role(text, uuid);

-- 1. Helper function to compute level-based role limits
CREATE OR REPLACE FUNCTION public.get_room_role_limits(p_room_id text)
RETURNS TABLE (
  max_owners int,
  max_co_owners int,
  max_admins int
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_room_id uuid;
  v_level int := 1;
  v_co_owners int := 1;
  v_admins int := 4;
BEGIN
  -- Resolve room UUID
  IF p_room_id ~* '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    v_room_id := p_room_id::uuid;
  ELSE
    SELECT id INTO v_room_id FROM public.rooms WHERE numeric_id = p_room_id OR sid = p_room_id OR id::text = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      BEGIN v_room_id := p_room_id::uuid; EXCEPTION WHEN OTHERS THEN v_room_id := NULL; END;
    END IF;
  END IF;

  SELECT COALESCE(level, room_level, 1) INTO v_level FROM public.rooms WHERE id = v_room_id;
  IF v_level < 1 THEN v_level := 1; END IF;

  -- Level-Based Capacities
  IF v_level = 1 THEN
    v_co_owners := 1; v_admins := 4;
  ELSIF v_level = 2 THEN
    v_co_owners := 1; v_admins := 10;
  ELSIF v_level = 3 THEN
    v_co_owners := 2; v_admins := 15;
  ELSIF v_level = 4 THEN
    v_co_owners := 2; v_admins := 20;
  ELSIF v_level = 5 THEN
    v_co_owners := 3; v_admins := 25;
  ELSIF v_level = 6 THEN
    v_co_owners := 4; v_admins := 35;
  ELSE
    v_co_owners := 5; v_admins := 50;
  END IF;

  RETURN QUERY SELECT 1 AS max_owners, v_co_owners AS max_co_owners, v_admins AS max_admins;
END;
$$;

-- 2. Function to check if user can modify room entry rules (Creator/Owner & Co-Owner ONLY)
CREATE OR REPLACE FUNCTION public.can_change_room_entry_rules(
  p_room_id text,
  p_user_id uuid
) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_room_id uuid;
  v_is_owner boolean := false;
  v_role text := 'Visitor';
BEGIN
  IF p_room_id ~* '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    v_room_id := p_room_id::uuid;
  ELSE
    SELECT id INTO v_room_id FROM public.rooms WHERE numeric_id = p_room_id OR sid = p_room_id OR id::text = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      BEGIN v_room_id := p_room_id::uuid; EXCEPTION WHEN OTHERS THEN v_room_id := NULL; END;
    END IF;
  END IF;

  SELECT (host_id = p_user_id OR room_owner = p_user_id) INTO v_is_owner FROM public.rooms WHERE id = v_room_id;
  IF v_is_owner THEN
    RETURN true;
  END IF;

  SELECT role INTO v_role FROM public.room_members WHERE room_id = v_room_id AND user_id = p_user_id;
  IF v_role IN ('Co-Owner', 'Co Owner', 'Creator', 'Owner') THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

-- 3. RPC: Promote room member role with authority check
CREATE OR REPLACE FUNCTION public.promote_room_member_role(
  p_room_id text,
  p_target_user_id uuid,
  p_new_role text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id uuid;
  v_caller_role text := 'Visitor';
  v_is_room_owner boolean := false;
  v_limits RECORD;
  v_current_count int := 0;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Resolve room UUID
  IF p_room_id ~* '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    v_room_id := p_room_id::uuid;
  ELSE
    SELECT id INTO v_room_id FROM public.rooms WHERE numeric_id = p_room_id OR sid = p_room_id OR id::text = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      BEGIN v_room_id := p_room_id::uuid; EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'Room not found for ID: %', p_room_id; END;
    END IF;
  END IF;

  SELECT (host_id = v_caller_id OR room_owner = v_caller_id) INTO v_is_room_owner FROM public.rooms WHERE id = v_room_id;
  SELECT role INTO v_caller_role FROM public.room_members WHERE room_id = v_room_id AND user_id = v_caller_id;

  IF v_is_room_owner THEN
    v_caller_role := 'Creator';
  END IF;

  -- Standardize new role
  IF p_new_role = 'Co Owner' THEN p_new_role := 'Co-Owner'; END IF;

  -- Authority Validation
  IF v_caller_role IN ('Creator', 'Owner') THEN
    IF p_new_role NOT IN ('Co-Owner', 'Admin') THEN
      RAISE EXCEPTION 'Invalid target role promotion: %', p_new_role;
    END IF;
  ELSIF v_caller_role IN ('Co-Owner', 'Co Owner') THEN
    IF p_new_role NOT IN ('Admin') THEN
      RAISE EXCEPTION 'Co-Owners can only promote members to Admin.';
    END IF;
  ELSE
    RAISE EXCEPTION 'Insufficient permissions to promote members.';
  END IF;

  -- Check Limits
  SELECT * FROM public.get_room_role_limits(v_room_id::text) INTO v_limits;

  IF p_new_role = 'Co-Owner' THEN
    SELECT COUNT(*) INTO v_current_count FROM public.room_members 
    WHERE room_id = v_room_id AND role IN ('Co-Owner', 'Co Owner') AND user_id != p_target_user_id;

    IF v_current_count >= v_limits.max_co_owners THEN
      RAISE EXCEPTION 'Maximum Co-Owners limit reached for this room level (Limit: %).', v_limits.max_co_owners;
    END IF;
  ELSIF p_new_role = 'Admin' THEN
    SELECT COUNT(*) INTO v_current_count FROM public.room_members 
    WHERE room_id = v_room_id AND role = 'Admin' AND user_id != p_target_user_id;

    IF v_current_count >= v_limits.max_admins THEN
      RAISE EXCEPTION 'Maximum Admins limit reached for this room level (Limit: %).', v_limits.max_admins;
    END IF;
  END IF;

  -- Insert/Update role in room_members
  INSERT INTO public.room_members (room_id, user_id, role, assigned_by, assigned_at, updated_at)
  VALUES (v_room_id, p_target_user_id, p_new_role, v_caller_id, now(), now())
  ON CONFLICT (room_id, user_id) DO UPDATE 
  SET role = p_new_role, assigned_by = v_caller_id, assigned_at = now(), updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'new_role', p_new_role
  );
END;
$$;

-- 4. RPC: Demote room member role
CREATE OR REPLACE FUNCTION public.demote_room_member_role(
  p_room_id text,
  p_target_user_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id uuid;
  v_caller_role text := 'Visitor';
  v_target_role text := 'Visitor';
  v_is_room_owner boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Resolve room UUID
  IF p_room_id ~* '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    v_room_id := p_room_id::uuid;
  ELSE
    SELECT id INTO v_room_id FROM public.rooms WHERE numeric_id = p_room_id OR sid = p_room_id OR id::text = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      BEGIN v_room_id := p_room_id::uuid; EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'Room not found for ID: %', p_room_id; END;
    END IF;
  END IF;

  SELECT (host_id = v_caller_id OR room_owner = v_caller_id) INTO v_is_room_owner FROM public.rooms WHERE id = v_room_id;
  SELECT role INTO v_caller_role FROM public.room_members WHERE room_id = v_room_id AND user_id = v_caller_id;
  SELECT role INTO v_target_role FROM public.room_members WHERE room_id = v_room_id AND user_id = p_target_user_id;

  IF v_is_room_owner THEN v_caller_role := 'Creator'; END IF;

  -- Cannot demote Creator
  IF p_target_user_id IN (SELECT host_id FROM public.rooms WHERE id = v_room_id) THEN
    RAISE EXCEPTION 'Room Creator cannot be demoted.';
  END IF;

  IF v_caller_role IN ('Creator', 'Owner') THEN
    -- Creator can demote Co-Owners and Admins
    NULL;
  ELSIF v_caller_role IN ('Co-Owner', 'Co Owner') THEN
    IF v_target_role IN ('Creator', 'Owner', 'Co-Owner', 'Co Owner') THEN
      RAISE EXCEPTION 'Co-Owners can only demote Admins.';
    END IF;
  ELSE
    RAISE EXCEPTION 'Insufficient permissions to demote members.';
  END IF;

  UPDATE public.room_members 
  SET role = 'Listener', assigned_by = v_caller_id, updated_at = now()
  WHERE room_id = v_room_id AND user_id = p_target_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'new_role', 'Listener'
  );
END;
$$;
