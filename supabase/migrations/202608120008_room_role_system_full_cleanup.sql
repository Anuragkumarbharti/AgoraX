-- ============================================================================
-- MIGRATION: 202608120008_room_role_system_full_cleanup.sql
-- DESCRIPTION: Enforce 4-role system (Owner, Co-Owner, Admin, Mod) across room RPCs and tables.
--              Remove Host and Co-Host roles and migrate existing records.
-- ============================================================================

-- 1. Drop old function signatures to prevent PGRST203 overloads
DROP FUNCTION IF EXISTS public.promote_room_member_role(text, uuid, text);
DROP FUNCTION IF EXISTS public.promote_room_member_role(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.promote_room_member_role_v2(text, uuid, text);
DROP FUNCTION IF EXISTS public.promote_room_member_role_v2(text, uuid, text, int, jsonb);

DROP FUNCTION IF EXISTS public.demote_room_member_role(text, uuid, text);
DROP FUNCTION IF EXISTS public.demote_room_member_role(text, uuid);
DROP FUNCTION IF EXISTS public.demote_room_member_role(uuid, uuid);
DROP FUNCTION IF EXISTS public.demote_room_member_role_v2(text, uuid);
DROP FUNCTION IF EXISTS public.demote_room_member_role_v2(text, uuid, boolean);

-- 2. Single Canonical promote_room_member_role RPC
CREATE OR REPLACE FUNCTION public.promote_room_member_role(
  p_room_id text,
  p_target_user_id uuid,
  p_new_role text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_canonical_owner uuid;
  v_caller_role text := 'Audience';
  v_target_name text;
  v_standard_role text;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Resolve Room ID
  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN
    v_room_id := p_room_id;
  END IF;

  -- Fetch Permanent Room Owner
  SELECT COALESCE(owner_user_id, room_owner, host_id) INTO v_canonical_owner 
  FROM public.rooms WHERE id = v_room_id;

  -- ABSOLUTE PROTECTION: Permanent Owner can NEVER be modified or target of role change
  IF p_target_user_id = v_canonical_owner THEN
    RAISE EXCEPTION 'OWNER_PROTECTED: Permanent Room Owner role cannot be modified.';
  END IF;

  -- Standardize Target Role to strict 4-role system: Co-Owner, Admin, Mod
  IF p_new_role IN ('Co-Owner', 'Co Owner', 'coowner', 'co-owner') THEN
    v_standard_role := 'Co-Owner';
  ELSIF p_new_role IN ('Admin', 'admin') THEN
    v_standard_role := 'Admin';
  ELSIF p_new_role IN ('Mod', 'mod', 'Moderator', 'moderator', 'Host', 'host', 'Host Member') THEN
    v_standard_role := 'Mod';
  ELSE
    RAISE EXCEPTION 'Invalid room role: %. Allowed roles are: Co-Owner, Admin, Mod.', p_new_role;
  END IF;

  -- Determine Caller Authority
  IF v_caller_id = v_canonical_owner THEN
    v_caller_role := 'Owner';
  ELSE
    SELECT role INTO v_caller_role FROM public.room_members WHERE room_id = v_room_id AND user_id = v_caller_id;
    IF v_caller_role IS NULL THEN
      v_caller_role := 'Audience';
    END IF;
  END IF;

  -- Permission Hierarchy Enforcement
  IF v_caller_role IN ('Owner', 'Creator', 'Founder') THEN
    -- Owner can assign Co-Owner, Admin, Mod
    NULL;
  ELSIF v_caller_role = 'Co-Owner' THEN
    IF v_standard_role NOT IN ('Admin', 'Mod') THEN
      RAISE EXCEPTION 'Co-Owners can only assign Admin or Mod roles.';
    END IF;
  ELSIF v_caller_role = 'Admin' THEN
    IF v_standard_role NOT IN ('Mod') THEN
      RAISE EXCEPTION 'Admins can only assign Mod role.';
    END IF;
  ELSE
    RAISE EXCEPTION 'Insufficient permissions to assign room roles.';
  END IF;

  -- Perform Role Update in room_members table
  UPDATE public.room_members
  SET role = v_standard_role, updated_at = NOW()
  WHERE room_id = v_room_id AND user_id = p_target_user_id;

  IF NOT FOUND THEN
    SELECT username INTO v_target_name FROM public.profiles WHERE id = p_target_user_id;
    INSERT INTO public.room_members (room_id, user_id, role, joined_at, updated_at)
    VALUES (v_room_id, p_target_user_id, v_standard_role, NOW(), NOW());
  ELSE
    SELECT username INTO v_target_name FROM public.profiles WHERE id = p_target_user_id;
  END IF;

  -- Update arrays on public.rooms table
  IF v_standard_role = 'Co-Owner' THEN
    UPDATE public.rooms 
    SET co_owner_ids = array_distinct(array_append(co_owner_ids, p_target_user_id::text)),
        admin_ids = array_remove(admin_ids, p_target_user_id::text),
        host_ids = array_remove(host_ids, p_target_user_id::text)
    WHERE id = v_room_id;
  ELSIF v_standard_role = 'Admin' THEN
    UPDATE public.rooms 
    SET admin_ids = array_distinct(array_append(admin_ids, p_target_user_id::text)),
        co_owner_ids = array_remove(co_owner_ids, p_target_user_id::text),
        host_ids = array_remove(host_ids, p_target_user_id::text)
    WHERE id = v_room_id;
  ELSIF v_standard_role = 'Mod' THEN
    UPDATE public.rooms 
    SET host_ids = array_distinct(array_append(host_ids, p_target_user_id::text)),
        co_owner_ids = array_remove(co_owner_ids, p_target_user_id::text),
        admin_ids = array_remove(admin_ids, p_target_user_id::text)
    WHERE id = v_room_id;
  END IF;

  -- Log Activity Event
  INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
  VALUES (v_room_id, 'system', p_target_user_id, COALESCE(v_target_name, 'Member'), COALESCE(v_target_name, 'Member') || ' promoted to ' || v_standard_role);

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'target_user_id', p_target_user_id,
    'new_role', v_standard_role
  );
END;
$$;

-- 3. Wrapper RPC promote_room_member_role_v2
CREATE OR REPLACE FUNCTION public.promote_room_member_role_v2(
  p_room_id text,
  p_target_user_id uuid,
  p_new_role text,
  p_expiry_hours int DEFAULT NULL,
  p_custom_permissions jsonb DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN public.promote_room_member_role(p_room_id, p_target_user_id, p_new_role);
END;
$$;

-- 4. Single Canonical demote_room_member_role RPC
CREATE OR REPLACE FUNCTION public.demote_room_member_role(
  p_room_id text,
  p_target_user_id uuid,
  p_role_to_remove text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_canonical_owner uuid;
  v_target_name text;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN
    v_room_id := p_room_id;
  END IF;

  SELECT COALESCE(owner_user_id, room_owner, host_id) INTO v_canonical_owner 
  FROM public.rooms WHERE id = v_room_id;

  IF p_target_user_id = v_canonical_owner THEN
    RAISE EXCEPTION 'OWNER_PROTECTED: Permanent Room Owner role cannot be demoted.';
  END IF;

  SELECT username INTO v_target_name FROM public.profiles WHERE id = p_target_user_id;

  -- Reset Role to Audience
  UPDATE public.room_members
  SET role = 'Audience', updated_at = NOW()
  WHERE room_id = v_room_id AND user_id = p_target_user_id;

  UPDATE public.rooms 
  SET co_owner_ids = array_remove(co_owner_ids, p_target_user_id::text),
      admin_ids = array_remove(admin_ids, p_target_user_id::text),
      host_ids = array_remove(host_ids, p_target_user_id::text)
  WHERE id = v_room_id;

  INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
  VALUES (v_room_id, 'system', p_target_user_id, COALESCE(v_target_name, 'Member'), COALESCE(v_target_name, 'Member') || ' demoted to Audience');

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'target_user_id', p_target_user_id,
    'new_role', 'Audience'
  );
END;
$$;

-- 5. Wrapper RPC demote_room_member_role_v2
CREATE OR REPLACE FUNCTION public.demote_room_member_role_v2(
  p_room_id text,
  p_target_user_id uuid,
  p_apply_cooldown boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN public.demote_room_member_role(p_room_id, p_target_user_id, NULL);
END;
$$;

-- 6. Migrate existing database rows to clean 4-role structure
UPDATE public.room_members 
SET role = 'Mod' 
WHERE role IN ('Host', 'Moderator', 'mod', 'Host Member', 'moderator');

UPDATE public.room_members 
SET role = 'Audience' 
WHERE role IN ('Co-Host', 'cohost', 'Speaker', 'Star Member', 'listener', 'Listener');

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'room_assigned_roles') THEN
    UPDATE public.room_assigned_roles 
    SET role = 'Mod' 
    WHERE role IN ('Host', 'Moderator', 'mod', 'Host Member', 'moderator');

    UPDATE public.room_assigned_roles 
    SET role = 'Audience' 
    WHERE role IN ('Co-Host', 'cohost', 'Speaker', 'Star Member', 'listener', 'Listener');
  END IF;
END $$;
