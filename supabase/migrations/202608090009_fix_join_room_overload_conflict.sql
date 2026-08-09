-- Migration: Fix PGRST203 Overload Conflict for public.join_room RPC
-- Date: 2026-08-09
-- Description: Explicitly drops all old overloaded signatures of public.join_room to eliminate PostgREST PGRST203 candidate ambiguity.

-- 1. Drop all overloaded signatures of join_room
DROP FUNCTION IF EXISTS public.join_room(text);
DROP FUNCTION IF EXISTS public.join_room(text, text);
DROP FUNCTION IF EXISTS public.join_room(text, text, text);

-- 2. Re-create single authoritative join_room RPC with defaulted parameters
CREATE OR REPLACE FUNCTION public.join_room(
  p_room_id text,
  p_password text DEFAULT NULL,
  p_session_id text DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_room public.rooms%ROWTYPE;
  v_user_profile public.profiles%ROWTYPE;
  v_current_count integer;
  v_role text;
  v_is_follower boolean;
  v_is_following boolean;
  v_is_community_member boolean;
  v_is_invited boolean;
  v_stored_password text;
BEGIN
  -- Run presence grace period & cleanup
  PERFORM public.process_presence_grace_period_and_cleanup();
  PERFORM public.leave_all_rooms(v_user_id, p_room_id);

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Resolve room by ID or Username
  SELECT * INTO v_room FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room.id IS NULL THEN
    RAISE EXCEPTION 'Room not found';
  END IF;

  IF v_room.status = 'ended' THEN
    RAISE EXCEPTION 'Room has already ended';
  END IF;

  -- Kick/Ban Check
  IF EXISTS (
    SELECT 1 FROM public.room_bans 
    WHERE room_id = v_room.id AND user_id = v_user_id AND (expires_at IS NULL OR expires_at > now())
  ) THEN
    RAISE EXCEPTION 'You are banned from this room';
  END IF;

  -- Room Capacity Check (Max 100)
  SELECT count(*) INTO v_current_count FROM public.room_members WHERE room_id = v_room.id;
  IF v_current_count >= 100 THEN
    RAISE EXCEPTION 'Room is full';
  END IF;

  -- Level & Global Ban Check
  SELECT * INTO v_user_profile FROM public.profiles WHERE id = v_user_id;
  IF v_user_profile.level < v_room.level_requirement THEN
    RAISE EXCEPTION 'Requires ID Level % or higher', v_room.level_requirement;
  END IF;

  IF v_user_profile.is_banned = true THEN
    RAISE EXCEPTION 'Your account is banned';
  END IF;

  -- Password & Policy Enforcement for non-host
  IF v_room.host_id <> v_user_id THEN
    -- Password check if room has password
    v_stored_password := COALESCE(v_room.room_password, (SELECT room_password FROM public.room_settings WHERE room_id = v_room.id LIMIT 1));
    IF v_stored_password IS NOT NULL AND length(trim(v_stored_password)) > 0 THEN
      IF p_password IS NULL OR trim(p_password) <> trim(v_stored_password) THEN
        RAISE EXCEPTION 'Incorrect room password';
      END IF;
    END IF;

    -- Join policy check
    IF v_room.join_policy = 'Followers Only' THEN
      SELECT EXISTS (SELECT 1 FROM public.connections WHERE follower_id = v_user_id AND following_id = v_room.host_id) INTO v_is_follower;
      IF NOT v_is_follower THEN
        RAISE EXCEPTION 'This room is Followers Only';
      END IF;
    ELSIF v_room.join_policy = 'VIP Members Only' THEN
      IF v_user_profile.vip_level = 0 THEN
        RAISE EXCEPTION 'This room is VIP Members Only';
      END IF;
    ELSIF v_room.join_policy = 'Community Members Only' THEN
      IF v_room.community_id IS NOT NULL THEN
        SELECT EXISTS (SELECT 1 FROM public.community_memberships WHERE community_id = v_room.community_id AND user_id = v_user_id) INTO v_is_community_member;
        IF NOT v_is_community_member THEN
          RAISE EXCEPTION 'This room is Community Members Only';
        END IF;
      END IF;
    ELSIF v_room.join_policy = 'Owner Following Only' THEN
      SELECT EXISTS (SELECT 1 FROM public.connections WHERE follower_id = v_room.host_id AND following_id = v_user_id) INTO v_is_following;
      IF NOT v_is_following THEN
        RAISE EXCEPTION 'This room is restricted to Owner Following only';
      END IF;
    ELSIF v_room.join_policy = 'Invite Only' THEN
      SELECT EXISTS (SELECT 1 FROM public.room_invites WHERE room_id = v_room.id AND user_id = v_user_id) INTO v_is_invited;
      IF NOT v_is_invited THEN
        RAISE EXCEPTION 'This room is Invite Only';
      END IF;
    END IF;
  END IF;

  -- Role Determination
  IF v_room.host_id = v_user_id THEN
    v_role := 'Host';
  ELSE
    SELECT role INTO v_role FROM public.room_assigned_roles WHERE room_id = v_room.id AND user_id = v_user_id;
    IF v_role IS NULL THEN
      v_role := 'Listener';
    END IF;
  END IF;

  -- Add to room members
  INSERT INTO public.room_members (room_id, user_id, role, last_heartbeat_at, session_id, is_reconnecting)
  VALUES (v_room.id, v_user_id, v_role, now(), p_session_id, false)
  ON CONFLICT (room_id, user_id) DO UPDATE 
  SET role = EXCLUDED.role, 
      last_heartbeat_at = now(), 
      session_id = EXCLUDED.session_id, 
      is_reconnecting = false;

  -- Clear any active seats so user enters as listener
  UPDATE public.room_seats
  SET user_id = NULL,
      mic_status = 'muted',
      is_speaking = false,
      is_reconnecting = false,
      session_id = NULL
  WHERE room_id = v_room.id AND user_id = v_user_id;

  -- Update active room ID in profiles
  UPDATE public.profiles
  SET active_room_id = v_room.id, presence_state = 'In Room'
  WHERE id = v_user_id;

  -- Activity event log
  INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
  VALUES (v_room.id, 'join', v_user_id, v_user_profile.username, COALESCE(v_user_profile.username, 'Someone') || ' joined the room');

  RETURN jsonb_build_object(
    'success', true,
    'role', v_role,
    'livekit_room_name', v_room.livekit_room_name
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
