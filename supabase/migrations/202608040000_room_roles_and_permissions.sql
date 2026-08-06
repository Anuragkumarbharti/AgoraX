-- Migration: Complete Room Role & Permission System v3.1 (UUID & Numeric ID Resolution Fix)
-- Created At: 2026-08-04

-- 1. Ensure assigned_by and assigned_at columns exist in public.room_members
ALTER TABLE public.room_members 
ADD COLUMN IF NOT EXISTS assigned_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS assigned_at timestamptz DEFAULT now();

-- 2. Helper function to compute dynamic role limits based on room level
CREATE OR REPLACE FUNCTION public.get_room_role_limits(p_room_id text)
RETURNS TABLE (
  max_owners int,
  max_co_owners int,
  max_admins int,
  max_hosts int,
  max_co_hosts int
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_room_id uuid;
  v_level int := 1;
BEGIN
  IF p_room_id ~* '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    v_room_id := p_room_id::uuid;
  ELSE
    SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      BEGIN v_room_id := p_room_id::uuid; EXCEPTION WHEN OTHERS THEN v_room_id := NULL; END;
    END IF;
  END IF;

  SELECT COALESCE(level, 1) INTO v_level FROM public.rooms WHERE id = v_room_id;
  IF v_level < 1 THEN v_level := 1; END IF;

  RETURN QUERY SELECT 
    1 AS max_owners,
    v_level AS max_co_owners,
    (4 * v_level) AS max_admins,
    1 AS max_hosts,
    (2 * v_level) AS max_co_hosts;
END;
$$;

-- 3. RPC: Promote room member role with backend validation
CREATE OR REPLACE FUNCTION public.promote_room_member_role(
  p_room_id text,
  p_target_user_id uuid,
  p_new_role text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id uuid;
  v_caller_role text := 'Visitor';
  v_target_role text := 'Visitor';
  v_is_room_owner boolean := false;
  v_room_level int := 1;
  v_current_count int := 0;
  v_max_allowed int := 0;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Resolve room UUID
  IF p_room_id ~* '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    v_room_id := p_room_id::uuid;
  ELSE
    SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      BEGIN v_room_id := p_room_id::uuid; EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'Room not found for ID: %', p_room_id; END;
    END IF;
  END IF;

  -- Get room level & check if caller is room owner from rooms table
  SELECT COALESCE(level, 1), (host_id = v_caller_id)
  INTO v_room_level, v_is_room_owner
  FROM public.rooms WHERE id = v_room_id;

  -- Fetch caller role from room_members
  SELECT role INTO v_caller_role FROM public.room_members 
  WHERE room_id = v_room_id AND user_id = v_caller_id;

  IF v_is_room_owner THEN
    v_caller_role := 'Owner';
  END IF;

  -- Validate promotion authority hierarchy
  IF v_caller_role = 'Owner' THEN
    IF p_new_role NOT IN ('Co-Owner', 'Co Owner', 'Admin', 'Host', 'Co-Host', 'Co Host') THEN
      RAISE EXCEPTION 'Invalid target role: %', p_new_role;
    END IF;
  ELSIF v_caller_role IN ('Co-Owner', 'Co Owner') THEN
    IF p_new_role NOT IN ('Admin', 'Host', 'Co-Host', 'Co Host') THEN
      RAISE EXCEPTION 'Co-Owners can only promote to Admin, Host, or Co-Host.';
    END IF;
  ELSE
    RAISE EXCEPTION 'Insufficient permissions to promote members.';
  END IF;

  -- Standardize role names
  IF p_new_role = 'Co Owner' THEN p_new_role := 'Co-Owner'; END IF;
  IF p_new_role = 'Co Host' THEN p_new_role := 'Co-Host'; END IF;

  -- Check capacity limits
  IF p_new_role = 'Co-Owner' THEN
    v_max_allowed := v_room_level;
    SELECT COUNT(*) INTO v_current_count FROM public.room_members 
    WHERE room_id = v_room_id AND role IN ('Co-Owner', 'Co Owner') AND user_id != p_target_user_id;
  ELSIF p_new_role = 'Admin' THEN
    v_max_allowed := 4 * v_room_level;
    SELECT COUNT(*) INTO v_current_count FROM public.room_members 
    WHERE room_id = v_room_id AND role = 'Admin' AND user_id != p_target_user_id;
  ELSIF p_new_role = 'Host' THEN
    v_max_allowed := 1;
    SELECT COUNT(*) INTO v_current_count FROM public.room_members 
    WHERE room_id = v_room_id AND role = 'Host' AND user_id != p_target_user_id;
  ELSIF p_new_role = 'Co-Host' THEN
    v_max_allowed := 2 * v_room_level;
    SELECT COUNT(*) INTO v_current_count FROM public.room_members 
    WHERE room_id = v_room_id AND role IN ('Co-Host', 'Co Host') AND user_id != p_target_user_id;
  END IF;

  IF v_max_allowed > 0 AND v_current_count >= v_max_allowed THEN
    RAISE EXCEPTION 'Maximum limit reached for role % (Limit: %).', p_new_role, v_max_allowed;
  END IF;

  -- Execute promotion in room_members table
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
    SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      BEGIN v_room_id := p_room_id::uuid; EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'Room not found for ID: %', p_room_id; END;
    END IF;
  END IF;

  SELECT (host_id = v_caller_id) INTO v_is_room_owner FROM public.rooms WHERE id = v_room_id;
  SELECT role INTO v_caller_role FROM public.room_members WHERE room_id = v_room_id AND user_id = v_caller_id;
  SELECT role INTO v_target_role FROM public.room_members WHERE room_id = v_room_id AND user_id = p_target_user_id;

  IF v_is_room_owner THEN v_caller_role := 'Owner'; END IF;

  -- Check hierarchy
  IF v_caller_role = 'Owner' THEN
    IF v_target_role = 'Owner' THEN
      RAISE EXCEPTION 'Cannot demote the room Owner.';
    END IF;
  ELSIF v_caller_role IN ('Co-Owner', 'Co Owner') THEN
    IF v_target_role IN ('Owner', 'Co-Owner', 'Co Owner') THEN
      RAISE EXCEPTION 'Co-Owners cannot demote Owner or other Co-Owners.';
    END IF;
  ELSE
    RAISE EXCEPTION 'Insufficient permissions to demote members.';
  END IF;

  UPDATE public.room_members 
  SET role = 'Member', assigned_by = v_caller_id, updated_at = now()
  WHERE room_id = v_room_id AND user_id = p_target_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'new_role', 'Member'
  );
END;
$$;

-- 5. RPC: Transfer room ownership
CREATE OR REPLACE FUNCTION public.transfer_room_ownership(
  p_room_id text,
  p_new_owner_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id uuid;
  v_old_owner_id uuid;
BEGIN
  -- Resolve room UUID
  IF p_room_id ~* '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    v_room_id := p_room_id::uuid;
  ELSE
    SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      BEGIN v_room_id := p_room_id::uuid; EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'Room not found for ID: %', p_room_id; END;
    END IF;
  END IF;

  SELECT host_id INTO v_old_owner_id FROM public.rooms WHERE id = v_room_id;

  IF v_caller_id IS NULL OR v_caller_id != v_old_owner_id THEN
    RAISE EXCEPTION 'Only the current room Owner can transfer ownership.';
  END IF;

  IF p_new_owner_id = v_old_owner_id THEN
    RAISE EXCEPTION 'User is already the room Owner.';
  END IF;

  -- Update rooms table
  UPDATE public.rooms SET host_id = p_new_owner_id, updated_at = now() WHERE id = v_room_id;

  -- Convert old Owner -> Member
  UPDATE public.room_members 
  SET role = 'Member', updated_at = now() 
  WHERE room_id = v_room_id AND user_id = v_old_owner_id;

  -- Convert new target -> Owner
  INSERT INTO public.room_members (room_id, user_id, role, assigned_by, assigned_at, updated_at)
  VALUES (v_room_id, p_new_owner_id, 'Owner', v_caller_id, now(), now())
  ON CONFLICT (room_id, user_id) DO UPDATE 
  SET role = 'Owner', assigned_by = v_caller_id, assigned_at = now(), updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'old_owner_id', v_old_owner_id,
    'new_owner_id', p_new_owner_id
  );
END;
$$;
