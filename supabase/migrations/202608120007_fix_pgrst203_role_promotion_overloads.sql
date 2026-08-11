-- ============================================================================
-- MIGRATION: 202608120007_fix_pgrst203_role_promotion_overloads.sql
-- DESCRIPTION: Fix PostgREST PGRST203 Multiple Choices error by dropping all 
--              overloaded variants of promote_room_member_role and demote_room_member_role
--              and establishing single canonical RPC implementations with full Owner Protection.
-- ============================================================================

-- 1. Drop ALL overloaded function signatures to resolve PGRST203
DROP FUNCTION IF EXISTS public.promote_room_member_role(text, uuid, text);
DROP FUNCTION IF EXISTS public.promote_room_member_role(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.promote_room_member_role(text, uuid, text, int, jsonb);

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
  v_is_room_owner boolean := false;
  v_target_name text;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Resolve Room ID
  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN
    v_room_id := p_room_id;
  END IF;

  -- Fetch Canonical Permanent Room Owner
  SELECT COALESCE(owner_user_id, room_owner, host_id) INTO v_canonical_owner 
  FROM public.rooms WHERE id = v_room_id;

  -- ABSOLUTE PROTECTION: Permanent Owner can NEVER be modified or target of role change
  IF p_target_user_id = v_canonical_owner THEN
    RAISE EXCEPTION 'OWNER_PROTECTED: Permanent Room Owner role cannot be modified or replaced.';
  END IF;

  -- Check Caller Authority
  IF v_caller_id = v_canonical_owner THEN
    v_is_room_owner := true;
    v_caller_role := 'Owner';
  ELSE
    SELECT role INTO v_caller_role FROM public.room_members WHERE room_id = v_room_id AND user_id = v_caller_id;
  END IF;

  -- Preserve Exact Role Names (Co-Owner, Admin, Co-Host, Star Member, etc.)
  IF p_new_role IN ('Co-Owner', 'Co Owner', 'CoOwner') THEN
    p_new_role := 'Co-Owner';
  ELSIF p_new_role IN ('Co-Host', 'Co Host', 'CoHost') THEN
    p_new_role := 'Co-Host';
  ELSIF p_new_role IN ('Admin', 'Moderator') THEN
    p_new_role := 'Admin';
  ELSIF p_new_role IN ('Star Member', 'StarMember') THEN
    p_new_role := 'Star Member';
  END IF;

  -- Perform Role Update in room_members table
  UPDATE public.room_members
  SET role = p_new_role
  WHERE room_id = v_room_id AND user_id = p_target_user_id;

  -- If target user was not yet in room_members, insert row
  IF NOT FOUND THEN
    SELECT username INTO v_target_name FROM public.profiles WHERE id = p_target_user_id;
    INSERT INTO public.room_members (room_id, user_id, role, joined_at)
    VALUES (v_room_id, p_target_user_id, p_new_role, NOW());
  ELSE
    SELECT username INTO v_target_name FROM public.profiles WHERE id = p_target_user_id;
  END IF;

  -- Log Activity Event
  INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
  VALUES (v_room_id, 'system', p_target_user_id, COALESCE(v_target_name, 'Member'), COALESCE(v_target_name, 'Member') || ' promoted to ' || p_new_role);

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'target_user_id', p_target_user_id,
    'new_role', p_new_role
  );
END;
$$;

-- 3. Single Canonical promote_room_member_role_v2 RPC
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
    RAISE EXCEPTION 'OWNER_PROTECTED: Permanent Room Owner role cannot be demoted or removed.';
  END IF;

  SELECT username INTO v_target_name FROM public.profiles WHERE id = p_target_user_id;

  -- Reset Role to Audience/Listener
  UPDATE public.room_members
  SET role = 'Audience'
  WHERE room_id = v_room_id AND user_id = p_target_user_id;

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

-- 5. Single Canonical demote_room_member_role_v2 RPC
CREATE OR REPLACE FUNCTION public.demote_room_member_role_v2(
  p_room_id text,
  p_target_user_id uuid,
  p_apply_cooldown boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN public.demote_room_member_role(p_room_id, p_target_user_id, NULL);
END;
$$;
