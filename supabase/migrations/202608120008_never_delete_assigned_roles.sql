-- ============================================================================
-- MIGRATION: 202608120008_never_delete_assigned_roles.sql
-- DESCRIPTION: Ensure assigned room roles (Co-Owner, Admin, Moderator, Host, Star Member)
--              are PERMANENT in the database and NEVER automatically deleted or expired
--              on heartbeat timeout, room exit, or presence grace period cleanup.
-- ============================================================================

-- 1. Helper Function to Check if Role is an Assigned Role
CREATE OR REPLACE FUNCTION public.is_assigned_room_role(p_role text)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  v_norm text;
BEGIN
  IF p_role IS NULL THEN RETURN false; END IF;
  v_norm := LOWER(TRIM(REPLACE(REPLACE(p_role, '-', ''), ' ', '')));
  RETURN v_norm IN ('owner', 'creator', 'founder', 'coowner', 'cohost', 'admin', 'moderator', 'host', 'starmember');
END;
$$;

-- 2. Enhanced promote_room_member_role RPC (Updates room_members AND rooms array columns)
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

  -- Permanent Owner Protection
  IF p_target_user_id = v_canonical_owner THEN
    RAISE EXCEPTION 'OWNER_PROTECTED: Permanent Room Owner role cannot be modified.';
  END IF;

  -- Normalize Role Names
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

  IF NOT FOUND THEN
    SELECT username INTO v_target_name FROM public.profiles WHERE id = p_target_user_id;
    INSERT INTO public.room_members (room_id, user_id, role, joined_at)
    VALUES (v_room_id, p_target_user_id, p_new_role, NOW());
  ELSE
    SELECT username INTO v_target_name FROM public.profiles WHERE id = p_target_user_id;
  END IF;

  -- Update rooms array columns for permanent persistence (type-safe text[])
  IF p_new_role = 'Co-Owner' THEN
    UPDATE public.rooms 
    SET co_owner_ids = array_append(COALESCE(co_owner_ids, '{}'::text[]), p_target_user_id::text)
    WHERE id = v_room_id AND NOT (COALESCE(co_owner_ids, '{}'::text[]) @> ARRAY[p_target_user_id::text]);
  ELSIF p_new_role = 'Admin' THEN
    UPDATE public.rooms 
    SET admin_ids = array_append(COALESCE(admin_ids, '{}'::text[]), p_target_user_id::text)
    WHERE id = v_room_id AND NOT (COALESCE(admin_ids, '{}'::text[]) @> ARRAY[p_target_user_id::text]);
  ELSIF p_new_role = 'Host' THEN
    UPDATE public.rooms 
    SET host_ids = array_append(COALESCE(host_ids, '{}'::text[]), p_target_user_id::text)
    WHERE id = v_room_id AND NOT (COALESCE(host_ids, '{}'::text[]) @> ARRAY[p_target_user_id::text]);
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

-- 3. Enhanced demote_room_member_role RPC (Updates room_members AND removes from rooms array columns)
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

  -- Reset Role to Audience in room_members
  UPDATE public.room_members
  SET role = 'Audience'
  WHERE room_id = v_room_id AND user_id = p_target_user_id;

  -- Remove from rooms array columns (type-safe text[])
  UPDATE public.rooms
  SET co_owner_ids = array_remove(COALESCE(co_owner_ids, '{}'::text[]), p_target_user_id::text),
      admin_ids = array_remove(COALESCE(admin_ids, '{}'::text[]), p_target_user_id::text),
      host_ids = array_remove(COALESCE(host_ids, '{}'::text[]), p_target_user_id::text),
      star_member_ids = array_remove(COALESCE(star_member_ids, '{}'::text[]), p_target_user_id::text)
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

-- 4. Protected Heartbeat Cleanup Function (NEVER Deletes Assigned Roles)
CREATE OR REPLACE FUNCTION public.cleanup_expired_room_members()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_expired record;
  v_username text;
BEGIN
  FOR v_expired IN 
    SELECT room_id, user_id, role 
    FROM public.room_members 
    WHERE last_heartbeat_at < (now() - interval '2 minutes')
  LOOP
    SELECT username INTO v_username FROM public.profiles WHERE id = v_expired.user_id;

    -- A. Free seat in room_seats
    UPDATE public.room_seats
    SET user_id = NULL,
        mic_status = 'muted',
        is_speaking = FALSE
    WHERE room_id = v_expired.room_id AND user_id = v_expired.user_id;

    -- B. Remove requests
    DELETE FROM public.room_requests
    WHERE room_id = v_expired.room_id AND user_id = v_expired.user_id;

    -- C. Delete from room_members ONLY if user does NOT have an assigned role!
    IF NOT public.is_assigned_room_role(v_expired.role) THEN
      DELETE FROM public.room_members 
      WHERE room_id = v_expired.room_id AND user_id = v_expired.user_id;

      DELETE FROM public.room_member_heartbeats
      WHERE room_id = v_expired.room_id AND user_id = v_expired.user_id;
    END IF;
  END LOOP;
END;
$$;

-- 5. Protected Presence Grace Period Cleanup (NEVER Deletes Assigned Roles)
CREATE OR REPLACE FUNCTION public.process_presence_grace_period_and_cleanup()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rec record;
  v_username text;
BEGIN
  FOR v_rec IN 
    SELECT room_id, user_id, role 
    FROM public.room_members 
    WHERE is_reconnecting = TRUE 
      AND last_heartbeat_at < (now() - interval '60 seconds')
  LOOP
    SELECT username INTO v_username FROM public.profiles WHERE id = v_rec.user_id;

    -- A. Free seat
    UPDATE public.room_seats
    SET user_id = NULL,
        mic_status = 'muted',
        is_speaking = FALSE,
        is_reconnecting = FALSE,
        session_id = NULL
    WHERE room_id = v_rec.room_id AND user_id = v_rec.user_id;

    -- B. Delete requests
    DELETE FROM public.room_requests
    WHERE room_id = v_rec.room_id AND user_id = v_rec.user_id;

    -- C. Delete from room_members ONLY if user does NOT have an assigned role!
    IF NOT public.is_assigned_room_role(v_rec.role) THEN
      DELETE FROM public.room_members 
      WHERE room_id = v_rec.room_id AND user_id = v_rec.user_id;

      DELETE FROM public.room_member_heartbeats
      WHERE room_id = v_rec.room_id AND user_id = v_rec.user_id;
    END IF;
  END LOOP;
END;
$$;
