-- ============================================================================
-- MIGRATION: 202608120009_role_protection_and_moderation_lists.sql
-- DESCRIPTION: Enforce assigned role protection in moderate_kick_user and moderate_ban_user
--              so users holding Co-Owner, Admin, Host, Star Member, or Owner roles
--              CANNOT be kicked, banned, or removed until their role is demoted/removed.
-- ============================================================================

-- 1. Helper to check if target user holds ANY assigned role in a room
CREATE OR REPLACE FUNCTION public.has_assigned_room_role(
  p_room_id text,
  p_user_id uuid
) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_canonical_owner uuid;
  v_has_role boolean := false;
BEGIN
  IF p_user_id IS NULL THEN RETURN false; END IF;

  -- Fetch canonical owner
  SELECT COALESCE(owner_user_id, room_owner, host_id) INTO v_canonical_owner
  FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;

  IF p_user_id = v_canonical_owner THEN
    RETURN true;
  END IF;

  -- Check room array columns
  SELECT EXISTS (
    SELECT 1 FROM public.rooms 
    WHERE (id = p_room_id OR username = p_room_id)
      AND (
        p_user_id::text = ANY(COALESCE(co_owner_ids, '{}'::text[])) OR
        p_user_id::text = ANY(COALESCE(admin_ids, '{}'::text[])) OR
        p_user_id::text = ANY(COALESCE(host_ids, '{}'::text[])) OR
        p_user_id::text = ANY(COALESCE(star_member_ids, '{}'::text[]))
      )
  ) INTO v_has_role;

  IF v_has_role THEN
    RETURN true;
  END IF;

  -- Check room_members table
  SELECT EXISTS (
    SELECT 1 FROM public.room_members
    WHERE (room_id = p_room_id OR room_id = (SELECT id FROM public.rooms WHERE username = p_room_id LIMIT 1))
      AND user_id = p_user_id
      AND public.is_assigned_room_role(role)
  ) INTO v_has_role;

  RETURN v_has_role;
END;
$$;

-- 2. Enhanced moderate_kick_user RPC with Assigned Role Protection
CREATE OR REPLACE FUNCTION public.moderate_kick_user(
  p_room_id text,
  p_target_user_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_canonical_owner uuid;
  v_caller_role text := 'Audience';
  v_target_name text;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN
    v_room_id := p_room_id;
  END IF;

  -- Fetch Canonical Owner
  SELECT COALESCE(owner_user_id, room_owner, host_id) INTO v_canonical_owner FROM public.rooms WHERE id = v_room_id;

  -- ABSOLUTE PROTECTION: User holding ANY assigned role CANNOT be kicked
  IF public.has_assigned_room_role(v_room_id, p_target_user_id) THEN
    RAISE EXCEPTION 'ROLE_PROTECTED: User holds an assigned role (Co-Owner, Admin, Host, Star Member, Owner). You must demote/remove their role before kicking them.';
  END IF;

  -- Determine Caller Authority
  IF v_caller_id = v_canonical_owner THEN
    v_caller_role := 'Creator';
  ELSE
    SELECT 
      CASE 
        WHEN v_caller_id::text = ANY(COALESCE(co_owner_ids, '{}'::text[])) THEN 'Co-Owner'
        WHEN v_caller_id::text = ANY(COALESCE(admin_ids, '{}'::text[])) THEN 'Admin'
        WHEN v_caller_id::text = ANY(COALESCE(host_ids, '{}'::text[])) THEN 'Host'
        ELSE 'Audience'
      END INTO v_caller_role
    FROM public.rooms WHERE id = v_room_id;
  END IF;

  IF v_caller_role NOT IN ('Creator', 'Owner', 'Co-Owner', 'Co Owner', 'Admin', 'Moderator', 'Host') THEN
    RAISE EXCEPTION 'Insufficient permissions to kick members.';
  END IF;

  SELECT username INTO v_target_name FROM public.profiles WHERE id = p_target_user_id;

  -- Remove from room_members
  DELETE FROM public.room_members WHERE room_id = v_room_id AND user_id = p_target_user_id;

  -- Free any seat held by kicked user
  UPDATE public.room_seats
  SET user_id = NULL, mic_status = 'muted', is_speaking = FALSE
  WHERE room_id = v_room_id AND user_id = p_target_user_id;

  -- Log Activity Event
  INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
  VALUES (v_room_id, 'user_kicked', p_target_user_id, COALESCE(v_target_name, 'Member'), COALESCE(v_target_name, 'Member') || ' was kicked out of the room.');

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'action', 'KICKED'
  );
END;
$$;

-- 3. Enhanced moderate_ban_user RPC with Assigned Role Protection
CREATE OR REPLACE FUNCTION public.moderate_ban_user(
  p_room_id text,
  p_target_user_id uuid,
  p_reason text DEFAULT NULL,
  p_duration text DEFAULT '24_hours'
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_canonical_owner uuid;
  v_caller_role text := 'Audience';
  v_target_name text;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN
    v_room_id := p_room_id;
  END IF;

  -- Fetch Canonical Owner
  SELECT COALESCE(owner_user_id, room_owner, host_id) INTO v_canonical_owner FROM public.rooms WHERE id = v_room_id;

  -- ABSOLUTE PROTECTION: User holding ANY assigned role CANNOT be banned
  IF public.has_assigned_room_role(v_room_id, p_target_user_id) THEN
    RAISE EXCEPTION 'ROLE_PROTECTED: User holds an assigned role (Co-Owner, Admin, Host, Star Member, Owner). You must demote/remove their role before banning them.';
  END IF;

  -- Determine Caller Authority
  IF v_caller_id = v_canonical_owner THEN
    v_caller_role := 'Creator';
  ELSE
    SELECT 
      CASE 
        WHEN v_caller_id::text = ANY(COALESCE(co_owner_ids, '{}'::text[])) THEN 'Co-Owner'
        WHEN v_caller_id::text = ANY(COALESCE(admin_ids, '{}'::text[])) THEN 'Admin'
        WHEN v_caller_id::text = ANY(COALESCE(host_ids, '{}'::text[])) THEN 'Host'
        ELSE 'Audience'
      END INTO v_caller_role
    FROM public.rooms WHERE id = v_room_id;
  END IF;

  IF v_caller_role NOT IN ('Creator', 'Owner', 'Co-Owner', 'Co Owner', 'Admin', 'Moderator', 'Host') THEN
    RAISE EXCEPTION 'Insufficient permissions to ban members.';
  END IF;

  SELECT username INTO v_target_name FROM public.profiles WHERE id = p_target_user_id;

  -- Add to block_list array on public.rooms
  UPDATE public.rooms 
  SET block_list = ARRAY(SELECT DISTINCT unnest(COALESCE(block_list, '{}'::text[]) || ARRAY[p_target_user_id::text]))
  WHERE id = v_room_id;

  -- Remove from room_members
  DELETE FROM public.room_members WHERE room_id = v_room_id AND user_id = p_target_user_id;

  -- Free any seat held by banned user
  UPDATE public.room_seats
  SET user_id = NULL, mic_status = 'muted', is_speaking = FALSE
  WHERE room_id = v_room_id AND user_id = p_target_user_id;

  -- Log Activity Event
  INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
  VALUES (v_room_id, 'user_banned', p_target_user_id, COALESCE(v_target_name, 'Member'), COALESCE(v_target_name, 'Member') || ' was banned from the room.');

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'action', 'BANNED'
  );
END;
$$;
