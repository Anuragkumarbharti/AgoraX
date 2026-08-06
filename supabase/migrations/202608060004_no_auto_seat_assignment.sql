-- Migration: Enforce Audience Default & No Automatic Seat Assignment
-- Date: 2026-08-06

CREATE OR REPLACE FUNCTION public.join_room(
  p_room_id text,
  p_password text default null
) RETURNS jsonb AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_user_profile public.profiles%rowtype;
  v_current_count integer;
  v_role text;
  v_is_follower boolean;
  v_is_following boolean;
  v_is_community_member boolean;
  v_is_invited boolean;
BEGIN
  -- 1. Enforce One Room Rule across other rooms
  PERFORM public.leave_all_rooms(v_user_id, p_room_id);

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_room FROM public.rooms WHERE id = p_room_id OR sid = p_room_id;
  IF v_room.id IS NULL THEN
    RAISE EXCEPTION 'Room not found';
  END IF;

  IF v_room.status = 'ended' THEN
    RAISE EXCEPTION 'Room has already ended';
  END IF;

  -- 2. Kick/Ban Check
  IF EXISTS (SELECT 1 FROM public.room_bans WHERE room_id = v_room.id AND user_id = v_user_id AND (expires_at IS NULL OR expires_at > now())) THEN
    RAISE EXCEPTION 'You are kicked/banned from this room';
  END IF;

  SELECT count(*) INTO v_current_count FROM public.room_members WHERE room_id = v_room.id;
  IF v_current_count >= 100 THEN
    RAISE EXCEPTION 'Room is full';
  END IF;

  SELECT * INTO v_user_profile FROM public.profiles WHERE id = v_user_id;
  IF v_user_profile.level < v_room.level_requirement THEN
    RAISE EXCEPTION 'Requires ID Level % or higher', v_room.level_requirement;
  END IF;

  -- Global Ban Check
  IF v_user_profile.is_banned = true THEN
    RAISE EXCEPTION 'Your account is banned';
  END IF;

  -- 3. Enforce Join Policies
  IF v_room.host_id <> v_user_id THEN
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
    ELSIF v_room.join_policy = 'Password Protected' THEN
      IF p_password IS NULL OR p_password <> (SELECT room_password FROM public.room_settings WHERE room_id = v_room.id LIMIT 1) THEN
        RAISE EXCEPTION 'Incorrect room password';
      END IF;
    END IF;
  END IF;

  -- Determine role
  IF v_room.host_id = v_user_id THEN
    v_role := 'Owner';
  ELSE
    SELECT role INTO v_role FROM public.room_assigned_roles WHERE room_id = v_room.id AND user_id = v_user_id;
    IF v_role IS NULL THEN
      v_role := 'Member';
    END IF;
  END IF;

  INSERT INTO public.room_members (room_id, user_id, role, last_heartbeat_at)
  VALUES (v_room.id, v_user_id, v_role, now())
  ON CONFLICT (room_id, user_id) DO UPDATE SET role = EXCLUDED.role, last_heartbeat_at = now();

  -- 4. CRITICAL RULE: Free any prior seat occupied by this user in target room upon entry.
  -- Every user MUST enter strictly as an Audience/Listener. No auto seat restoration.
  UPDATE public.room_seats
  SET user_id = NULL,
      mic_status = 'muted',
      is_speaking = false
  WHERE room_id = v_room.id AND user_id = v_user_id;

  -- Update profiles active room and presence status
  UPDATE public.profiles
  SET active_room_id = v_room.id, presence_state = 'In Room'
  WHERE id = v_user_id;

  INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
  VALUES (v_room.id, 'join', v_user_id, v_user_profile.username, v_user_profile.username || ' joined the room');

  RETURN jsonb_build_object(
    'success', true,
    'role', v_role,
    'livekit_room_name', v_room.livekit_room_name
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
