-- Migration: Clear PostgreSQL function overloads & enforce COMPLETE SEPARATION OF ROLE VS PRESENCE
-- Description: Establishes public.room_roles table for permanent role storage, drops legacy check constraints on room_assigned_roles,
--              decouples room_members (presence only), implements get_room_state_snapshot filtering by active presence threshold (30s),
--              standardizes HOST as the sole host/moderation role (removing separate Mod role tag),
--              and enforces strict ONE USER = ONE PRIMARY ROOM ROLE invariant:
--              - Supported Primary Roles: OWNER, CO_OWNER ('Co-Owner'), ADMIN ('Admin'), HOST ('Host').
--              - ROLE = Permanent (room_roles / rooms array columns).
--              - PRESENCE = Temporary session in room_members (last_heartbeat_at >= now() - 30 seconds).
--              - Role assignment to offline users ONLY updates room_roles (NO fake online presence, NO eyeCount change).
--              - Active online member list & eyeCount count ONLY users with valid active presence in this exact room.

-- 0. Ensure schema compatibility for room_members, rooms, and room_roles tables
ALTER TABLE public.room_members ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT timezone('utc'::text, now());
ALTER TABLE public.room_members ADD COLUMN IF NOT EXISTS is_online boolean DEFAULT true NOT NULL;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS star_member_ids text[] DEFAULT '{}';
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS co_owner_ids text[] DEFAULT '{}';
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS admin_ids text[] DEFAULT '{}';
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS host_ids text[] DEFAULT '{}';

-- 1. Create persistent room_roles table for permanent role storage (Separate from Presence)
CREATE TABLE IF NOT EXISTS public.room_roles (
  room_id text REFERENCES public.rooms(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  role text NOT NULL,
  assigned_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  assigned_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  PRIMARY KEY (room_id, user_id)
);

ALTER TABLE public.room_roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow select room_roles for all" ON public.room_roles;
CREATE POLICY "Allow select room_roles for all" ON public.room_roles FOR SELECT USING (true);

-- Ensure legacy room_assigned_roles table exists and drop any restricting legacy check constraints
CREATE TABLE IF NOT EXISTS public.room_assigned_roles (
  room_id text REFERENCES public.rooms(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  role text NOT NULL,
  assigned_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  PRIMARY KEY (room_id, user_id)
);
ALTER TABLE public.room_assigned_roles DROP CONSTRAINT IF EXISTS room_assigned_roles_role_check;
ALTER TABLE public.room_assigned_roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow select for all assigned roles" ON public.room_assigned_roles;
CREATE POLICY "Allow select for all assigned roles" ON public.room_assigned_roles FOR SELECT USING (true);

-- Helper function to check assigned roles
CREATE OR REPLACE FUNCTION public.is_assigned_room_role(p_role text)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path = public AS $$
BEGIN
  IF p_role IS NULL THEN RETURN false; END IF;
  p_role := lower(trim(p_role));
  RETURN p_role IN (
    'owner', 'creator', 'founder',
    'co-owner', 'coowner', 'co owner',
    'admin',
    'host', 'mod', 'moderator',
    'star member', 'starmember'
  );
END;
$$;

-- Helper function to compute level-based role limits (always available)
CREATE OR REPLACE FUNCTION public.get_room_role_limits(p_room_id text)
RETURNS TABLE (
  max_owners int,
  max_co_owners int,
  max_admins int
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_room_id text;
  v_level int := 1;
  v_co_owners int := 1;
  v_admins int := 4;
BEGIN
  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN v_room_id := p_room_id; END IF;

  SELECT COALESCE(level, room_level, 1) INTO v_level FROM public.rooms WHERE id = v_room_id;
  IF v_level IS NULL OR v_level < 1 THEN v_level := 1; END IF;

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

-- Presence Heartbeat Cleanup Function (Clears temporary presence, NEVER deletes room_roles)
CREATE OR REPLACE FUNCTION public.cleanup_expired_room_members()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_expired record;
  v_username text;
BEGIN
  FOR v_expired IN 
    SELECT room_id, user_id, role 
    FROM public.room_members 
    WHERE last_heartbeat_at < (now() - interval '30 seconds')
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

    -- C. Delete temporary presence record from room_members
    DELETE FROM public.room_members 
    WHERE room_id = v_expired.room_id AND user_id = v_expired.user_id;

    DELETE FROM public.room_member_heartbeats
    WHERE room_id = v_expired.room_id AND user_id = v_expired.user_id;
  END LOOP;
END;
$$;

-- Presence Grace Period Cleanup Function
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
      AND last_heartbeat_at < (now() - interval '30 seconds')
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

    -- C. Delete temporary presence record
    DELETE FROM public.room_members 
    WHERE room_id = v_rec.room_id AND user_id = v_rec.user_id;

    DELETE FROM public.room_member_heartbeats
    WHERE room_id = v_rec.room_id AND user_id = v_rec.user_id;

    -- D. Broadcast leave event
    INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
    VALUES (v_rec.room_id, 'leave', v_rec.user_id, v_username, COALESCE(v_username, 'Someone') || ' left the room');
  END LOOP;
END;
$$;

-- Accurate State Snapshot RPC (STRICT PRESENCE SEPARATION: Only returns users with active room presence)
CREATE OR REPLACE FUNCTION public.get_room_state_snapshot(
  p_room_id text
) RETURNS jsonb AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_room jsonb;
  v_seats jsonb;
  v_members jsonb;
  v_eye_count integer;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated';
  END IF;

  PERFORM public.cleanup_expired_room_members();

  -- Room metadata
  SELECT jsonb_build_object(
    'id', r.id,
    'name', r.name,
    'username', r.username,
    'description', r.description,
    'category', r.category,
    'language', r.language,
    'host_id', r.host_id,
    'status', r.status,
    'visibility', r.visibility,
    'online_members', r.online_members,
    'livekit_room_name', r.livekit_room_name,
    'avatar', r.avatar,
    'banner', r.banner,
    'is_permanent', r.is_permanent,
    'room_level', r.room_level,
    'room_xp', r.room_xp,
    'total_room_gems', COALESCE(r.total_room_gems, r.total_room_stars, 0),
    'today_room_gems', COALESCE(r.today_room_gems, r.today_room_stars, 0),
    'total_room_stars', COALESCE(r.total_room_stars, 0),
    'today_room_stars', COALESCE(r.today_room_stars, 0)
  ) INTO v_room
  FROM public.rooms r
  WHERE r.id = p_room_id;

  IF v_room IS NULL THEN
    RAISE EXCEPTION 'Room not found';
  END IF;

  -- Active Online Eye Count (STRICT PRESENCE ONLY)
  SELECT count(*) INTO v_eye_count
  FROM public.room_members
  WHERE room_id = p_room_id
    AND COALESCE(is_online, true) = true
    AND last_heartbeat_at >= (now() - interval '30 seconds');

  -- Room Seats
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'seatIndex', s.seat_index,
      'role', s.role,
      'userId', s.user_id,
      'seatSessionId', s.seat_session_id,
      'seatSessionGems', COALESCE(s.seat_session_gems, s.seat_total_gems, s.seat_total_stars, 0),
      'seatTotalGems', COALESCE(s.seat_total_gems, s.seat_total_stars, 0),
      'seatTotalStars', COALESCE(s.seat_total_stars, 0),
      'username', COALESCE(s.username, p.username, 'Seat ' || (s.seat_index + 1)),
      'avatar', COALESCE(s.avatar, p.avatar),
      'avatarFrame', s.avatar_frame,
      'level', COALESCE(s.level, p.level, 1),
      'vipLevel', COALESCE(s.vip_level, p.vip_level, 0),
      'nobleLevel', COALESCE(s.noble_level, p.novel_level, 0),
      'micStatus', s.mic_status,
      'isSpeaking', s.is_speaking,
      'silverGiftCount', COALESCE(g.silver_gift_count, 0)
    ) ORDER BY s.seat_index
  ), '[]'::jsonb) INTO v_seats
  FROM public.room_seats s
  LEFT JOIN public.profiles p ON p.id = s.user_id
  LEFT JOIN public.room_seat_gifts g ON g.room_id = s.room_id AND g.seat_index = s.seat_index
  WHERE s.room_id = p_room_id;

  -- Active Room Members (STRICT PRESENCE ONLY: only return users with valid active presence in this room)
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'userId', m.user_id,
      'username', p.username,
      'avatar', p.avatar,
      'role', CASE WHEN m.role IN ('Mod', 'Moderator') THEN 'Host' ELSE m.role END,
      'isMuted', m.is_muted,
      'hasRaisedHand', m.has_raised_hand,
      'joinedAt', m.joined_at,
      'level', p.level,
      'vipLevel', p.vip_level,
      'nobleLevel', p.novel_level
    ) ORDER BY m.joined_at ASC
  ), '[]'::jsonb) INTO v_members
  FROM public.room_members m
  LEFT JOIN public.profiles p ON p.id = m.user_id
  WHERE m.room_id = p_room_id
    AND COALESCE(m.is_online, true) = true
    AND m.last_heartbeat_at >= (now() - interval '30 seconds');

  RETURN jsonb_build_object(
    'room', v_room,
    'seats', v_seats,
    'members', v_members,
    'eyeCount', v_eye_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 2. Explicitly drop ALL overloaded signatures of promote_room_member_role & promote_room_member_role_v2
DROP FUNCTION IF EXISTS public.promote_room_member_role(text, uuid, text);
DROP FUNCTION IF EXISTS public.promote_room_member_role(text, text, text);
DROP FUNCTION IF EXISTS public.promote_room_member_role(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.promote_room_member_role(text, uuid, text, int, jsonb);
DROP FUNCTION IF EXISTS public.promote_room_member_role(text, text, text, int, jsonb);

DROP FUNCTION IF EXISTS public.promote_room_member_role_v2(text, uuid, text);
DROP FUNCTION IF EXISTS public.promote_room_member_role_v2(text, text, text);
DROP FUNCTION IF EXISTS public.promote_room_member_role_v2(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.promote_room_member_role_v2(text, uuid, text, int, jsonb);
DROP FUNCTION IF EXISTS public.promote_room_member_role_v2(text, text, text, int, jsonb);
DROP FUNCTION IF EXISTS public.promote_room_member_role_v2(text, uuid, boolean);
DROP FUNCTION IF EXISTS public.promote_room_member_role_v2(text, text, boolean);

-- 3. Explicitly drop ALL overloaded signatures of demote_room_member_role & demote_room_member_role_v2
DROP FUNCTION IF EXISTS public.demote_room_member_role(text, uuid);
DROP FUNCTION IF EXISTS public.demote_room_member_role(text, text);
DROP FUNCTION IF EXISTS public.demote_room_member_role(uuid, uuid);
DROP FUNCTION IF EXISTS public.demote_room_member_role(text, uuid, text);
DROP FUNCTION IF EXISTS public.demote_room_member_role(text, text, text);

DROP FUNCTION IF EXISTS public.demote_room_member_role_v2(text, uuid);
DROP FUNCTION IF EXISTS public.demote_room_member_role_v2(text, text);
DROP FUNCTION IF EXISTS public.demote_room_member_role_v2(uuid, uuid);
DROP FUNCTION IF EXISTS public.demote_room_member_role_v2(text, uuid, boolean);
DROP FUNCTION IF EXISTS public.demote_room_member_role_v2(text, text, boolean);

-- 4. Create SINGLE canonical promote_room_member_role RPC with Role-Presence Separation
CREATE OR REPLACE FUNCTION public.promote_room_member_role(
  p_room_id text,
  p_target_user_id text,
  p_new_role text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_target_user_uuid uuid;
  v_room_id text;
  v_canonical_owner uuid;
  v_caller_role_raw text;
  v_caller_role text := 'Audience';
  v_old_role text := 'Audience';
  v_standard_role text;
  v_target_name text;
  v_room_level int := 1;
  v_max_co_owners int := 1;
  v_max_admins int := 4;
  v_current_count int := 0;
  v_is_target_online boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  BEGIN
    v_target_user_uuid := p_target_user_id::uuid;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Invalid user ID format: %', p_target_user_id;
  END;

  -- Resolve Room ID (UUID or username)
  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN
    v_room_id := p_room_id;
  END IF;

  -- Fetch Canonical Permanent Room Owner
  SELECT COALESCE(owner_user_id, room_owner, host_id) INTO v_canonical_owner 
  FROM public.rooms WHERE id = v_room_id;

  -- STRICT PROTECTION: Permanent Owner role CANNOT be modified or assigned
  IF v_target_user_uuid = v_canonical_owner THEN
    RAISE EXCEPTION 'OWNER_PROTECTED: Permanent Room Owner role cannot be modified.';
  END IF;

  IF p_new_role IN ('Owner', 'owner', 'Creator', 'creator', 'Founder', 'founder') THEN
    RAISE EXCEPTION 'OWNER_IMMUTABLE: Room ownership is permanent and cannot be assigned to another user.';
  END IF;

  -- Standardize Target Role (Host is sole host/moderation role)
  IF p_new_role IN ('Co-Owner', 'Co Owner', 'coowner', 'co-owner', 'CoOwner') THEN
    v_standard_role := 'Co-Owner';
  ELSIF p_new_role IN ('Admin', 'admin') THEN
    v_standard_role := 'Admin';
  ELSIF p_new_role IN ('Host', 'host', 'Co-Host', 'co-host', 'Mod', 'mod', 'Moderator', 'moderator') THEN
    v_standard_role := 'Host';
  ELSIF p_new_role IN ('Star Member', 'StarMember', 'star_member') THEN
    v_standard_role := 'Star Member';
  ELSE
    v_standard_role := p_new_role;
  END IF;

  -- Determine Caller Role for Backend Permission Checking
  IF v_caller_id = v_canonical_owner THEN
    v_caller_role := 'Owner';
  ELSE
    SELECT role INTO v_caller_role_raw FROM public.room_roles WHERE room_id = v_room_id AND user_id = v_caller_id;
    IF v_caller_role_raw IS NULL THEN
      SELECT role INTO v_caller_role_raw FROM public.room_members WHERE room_id = v_room_id AND user_id = v_caller_id;
    END IF;
    IF v_caller_role_raw IN ('Co-Owner', 'Co Owner', 'CoOwner', 'co-owner') THEN
      v_caller_role := 'Co-Owner';
    ELSIF v_caller_role_raw IN ('Admin', 'admin') THEN
      v_caller_role := 'Admin';
    ELSIF v_caller_role_raw IN ('Host', 'host', 'Mod', 'mod', 'Moderator', 'moderator') THEN
      v_caller_role := 'Host';
    ELSE
      v_caller_role := 'Audience';
    END IF;
  END IF;

  -- ENFORCE STRICT BACKEND HIERARCHY RULES
  IF v_caller_role = 'Owner' THEN
    -- Owner can assign Co-Owner, Admin, Host
    NULL;
  ELSIF v_caller_role = 'Co-Owner' THEN
    -- Co-Owner can assign Admin, Host (CANNOT assign Co-Owner or Owner)
    IF v_standard_role IN ('Co-Owner', 'Owner') THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: Co-Owners cannot assign Co-Owner role.';
    END IF;
  ELSIF v_caller_role = 'Admin' THEN
    -- Admin can assign Host (CANNOT assign Admin, Co-Owner, or Owner)
    IF v_standard_role IN ('Co-Owner', 'Admin', 'Owner') THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: Admins cannot assign Admin or Co-Owner role.';
    END IF;
  ELSE
    RAISE EXCEPTION 'PERMISSION_DENIED: You do not have permission to assign room roles.';
  END IF;

  -- Fetch Target's Current Role for Transition Tracking
  SELECT role INTO v_old_role FROM public.room_roles WHERE room_id = v_room_id AND user_id = v_target_user_uuid;
  IF v_old_role IS NULL THEN
    SELECT role INTO v_old_role FROM public.room_members WHERE room_id = v_room_id AND user_id = v_target_user_uuid;
  END IF;

  -- Compute Level Capacities Inlined
  SELECT COALESCE(level, room_level, 1) INTO v_room_level FROM public.rooms WHERE id = v_room_id;
  IF v_room_level IS NULL OR v_room_level < 1 THEN v_room_level := 1; END IF;

  IF v_room_level = 1 THEN
    v_max_co_owners := 1; v_max_admins := 4;
  ELSIF v_room_level = 2 THEN
    v_max_co_owners := 1; v_max_admins := 10;
  ELSIF v_room_level = 3 THEN
    v_max_co_owners := 2; v_max_admins := 15;
  ELSIF v_room_level = 4 THEN
    v_max_co_owners := 2; v_max_admins := 20;
  ELSIF v_room_level = 5 THEN
    v_max_co_owners := 3; v_max_admins := 25;
  ELSIF v_room_level = 6 THEN
    v_max_co_owners := 4; v_max_admins := 35;
  ELSE
    v_max_co_owners := 5; v_max_admins := 50;
  END IF;

  -- SLOT CAPACITY VERIFICATION BEFORE MUTATION
  IF v_standard_role = 'Co-Owner' AND v_old_role IS DISTINCT FROM 'Co-Owner' THEN
    SELECT COUNT(*) INTO v_current_count FROM public.room_roles WHERE room_id = v_room_id AND role = 'Co-Owner' AND user_id != v_target_user_uuid;
    IF v_current_count >= v_max_co_owners THEN
      RAISE EXCEPTION 'ROLE_LIMIT_EXCEEDED: Maximum Co-Owner slots reached for this room level (Limit: %).', v_max_co_owners;
    END IF;
  ELSIF v_standard_role = 'Admin' AND v_old_role IS DISTINCT FROM 'Admin' THEN
    SELECT COUNT(*) INTO v_current_count FROM public.room_roles WHERE room_id = v_room_id AND role = 'Admin' AND user_id != v_target_user_uuid;
    IF v_current_count >= v_max_admins THEN
      RAISE EXCEPTION 'ROLE_LIMIT_EXCEEDED: Maximum Admin slots reached for this room level (Limit: %).', v_max_admins;
    END IF;
  END IF;

  SELECT username INTO v_target_name FROM public.profiles WHERE id = v_target_user_uuid;

  -- ATOMIC OPERATION: STEP A — Strip target user from ALL previous role arrays on rooms table
  UPDATE public.rooms
  SET co_owner_ids = array_remove(COALESCE(co_owner_ids, '{}'::text[]), v_target_user_uuid::text),
      admin_ids = array_remove(COALESCE(admin_ids, '{}'::text[]), v_target_user_uuid::text),
      host_ids = array_remove(COALESCE(host_ids, '{}'::text[]), v_target_user_uuid::text),
      star_member_ids = array_remove(COALESCE(star_member_ids, '{}'::text[]), v_target_user_uuid::text)
  WHERE id = v_room_id;

  -- ATOMIC OPERATION: STEP B — Update permanent role record in room_roles & room_assigned_roles (ROLE ONLY, NO FAKE PRESENCE!)
  INSERT INTO public.room_roles (room_id, user_id, role, assigned_at, assigned_by)
  VALUES (v_room_id, v_target_user_uuid, v_standard_role, now(), v_caller_id)
  ON CONFLICT (room_id, user_id) DO UPDATE
  SET role = v_standard_role, assigned_at = now(), assigned_by = v_caller_id;

  BEGIN
    INSERT INTO public.room_assigned_roles (room_id, user_id, role, assigned_at)
    VALUES (v_room_id, v_target_user_uuid, v_standard_role, now())
    ON CONFLICT (room_id, user_id) DO UPDATE
    SET role = v_standard_role, assigned_at = now();
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  -- ATOMIC OPERATION: STEP C — Add target user ONLY to the new primary role array on rooms table
  IF v_standard_role = 'Co-Owner' THEN
    UPDATE public.rooms 
    SET co_owner_ids = array_append(COALESCE(co_owner_ids, '{}'::text[]), v_target_user_uuid::text)
    WHERE id = v_room_id AND NOT (COALESCE(co_owner_ids, '{}'::text[]) @> ARRAY[v_target_user_uuid::text]);
  ELSIF v_standard_role = 'Admin' THEN
    UPDATE public.rooms 
    SET admin_ids = array_append(COALESCE(admin_ids, '{}'::text[]), v_target_user_uuid::text)
    WHERE id = v_room_id AND NOT (COALESCE(admin_ids, '{}'::text[]) @> ARRAY[v_target_user_uuid::text]);
  ELSIF v_standard_role = 'Host' THEN
    UPDATE public.rooms 
    SET host_ids = array_append(COALESCE(host_ids, '{}'::text[]), v_target_user_uuid::text)
    WHERE id = v_room_id AND NOT (COALESCE(host_ids, '{}'::text[]) @> ARRAY[v_target_user_uuid::text]);
  ELSIF v_standard_role = 'Star Member' THEN
    UPDATE public.rooms 
    SET star_member_ids = array_append(COALESCE(star_member_ids, '{}'::text[]), v_target_user_uuid::text)
    WHERE id = v_room_id AND NOT (COALESCE(star_member_ids, '{}'::text[]) @> ARRAY[v_target_user_uuid::text]);
  END IF;

  -- ATOMIC OPERATION: STEP D — Check if target user is currently present inside room_members
  SELECT EXISTS(
    SELECT 1 FROM public.room_members 
    WHERE room_id = v_room_id 
      AND user_id = v_target_user_uuid 
      AND COALESCE(is_online, true) = true 
      AND last_heartbeat_at >= (now() - interval '30 seconds')
  ) INTO v_is_target_online;

  -- If target user is ALREADY inside the room, update their presence role tag
  IF v_is_target_online THEN
    UPDATE public.room_members
    SET role = v_standard_role, updated_at = now()
    WHERE room_id = v_room_id AND user_id = v_target_user_uuid;
  END IF;
  -- DO NOT CREATE A ROOM_MEMBERS ROW IF USER IS NOT IN THE ROOM!

  -- Log Activity Event
  INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
  VALUES (v_room_id, 'system', v_target_user_uuid, COALESCE(v_target_name, 'Member'), COALESCE(v_target_name, 'Member') || ' role updated to ' || v_standard_role);

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'target_user_id', v_target_user_uuid,
    'old_role', COALESCE(v_old_role, 'Audience'),
    'new_role', v_standard_role,
    'is_target_online', v_is_target_online
  );
END;
$$;

-- 5. Create SINGLE canonical promote_room_member_role_v2 RPC
CREATE OR REPLACE FUNCTION public.promote_room_member_role_v2(
  p_room_id text,
  p_target_user_id text,
  p_new_role text,
  p_expiry_hours int DEFAULT NULL,
  p_custom_permissions jsonb DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN public.promote_room_member_role(p_room_id, p_target_user_id, p_new_role);
END;
$$;

-- 6. Create SINGLE canonical demote_room_member_role RPC with Backend Hierarchy Enforcement
CREATE OR REPLACE FUNCTION public.demote_room_member_role(
  p_room_id text,
  p_target_user_id text,
  p_role_to_remove text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_target_user_uuid uuid;
  v_room_id text;
  v_canonical_owner uuid;
  v_caller_role_raw text;
  v_caller_role text := 'Audience';
  v_target_role_raw text;
  v_target_role text := 'Audience';
  v_target_name text;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  BEGIN
    v_target_user_uuid := p_target_user_id::uuid;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Invalid user ID format: %', p_target_user_id;
  END;

  -- Resolve Room ID
  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN
    v_room_id := p_room_id;
  END IF;

  -- Fetch Canonical Permanent Room Owner
  SELECT COALESCE(owner_user_id, room_owner, host_id) INTO v_canonical_owner 
  FROM public.rooms WHERE id = v_room_id;

  -- STRICT PROTECTION: Permanent Owner role CANNOT be demoted
  IF v_target_user_uuid = v_canonical_owner THEN
    RAISE EXCEPTION 'OWNER_PROTECTED: Permanent Room Owner role cannot be demoted or removed.';
  END IF;

  -- Determine Caller Role
  IF v_caller_id = v_canonical_owner THEN
    v_caller_role := 'Owner';
  ELSE
    SELECT role INTO v_caller_role_raw FROM public.room_roles WHERE room_id = v_room_id AND user_id = v_caller_id;
    IF v_caller_role_raw IS NULL THEN
      SELECT role INTO v_caller_role_raw FROM public.room_members WHERE room_id = v_room_id AND user_id = v_caller_id;
    END IF;
    IF v_caller_role_raw IN ('Co-Owner', 'Co Owner', 'CoOwner', 'co-owner') THEN
      v_caller_role := 'Co-Owner';
    ELSIF v_caller_role_raw IN ('Admin', 'admin') THEN
      v_caller_role := 'Admin';
    ELSIF v_caller_role_raw IN ('Host', 'host', 'Mod', 'mod', 'Moderator', 'moderator') THEN
      v_caller_role := 'Host';
    ELSE
      v_caller_role := 'Audience';
    END IF;
  END IF;

  -- Determine Target Role
  SELECT role INTO v_target_role_raw FROM public.room_roles WHERE room_id = v_room_id AND user_id = v_target_user_uuid;
  IF v_target_role_raw IS NULL THEN
    SELECT role INTO v_target_role_raw FROM public.room_members WHERE room_id = v_room_id AND user_id = v_target_user_uuid;
  END IF;
  IF v_target_role_raw IN ('Co-Owner', 'Co Owner', 'CoOwner', 'co-owner') THEN
    v_target_role := 'Co-Owner';
  ELSIF v_target_role_raw IN ('Admin', 'admin') THEN
    v_target_role := 'Admin';
  ELSIF v_target_role_raw IN ('Host', 'host', 'Mod', 'mod', 'Moderator', 'moderator') THEN
    v_target_role := 'Host';
  ELSE
    v_target_role := 'Audience';
  END IF;

  -- ENFORCE STRICT BACKEND HIERARCHY RULES FOR DEMOTION / REMOVAL
  IF v_caller_role = 'Owner' THEN
    -- Owner can demote Co-Owner, Admin, Host
    NULL;
  ELSIF v_caller_role = 'Co-Owner' THEN
    -- Co-Owner can remove Admin, Host (CANNOT remove Co-Owner or Owner)
    IF v_target_role IN ('Co-Owner', 'Owner') THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: Co-Owners cannot remove Co-Owner role.';
    END IF;
  ELSIF v_caller_role = 'Admin' THEN
    -- Admin can remove Host (CANNOT remove Admin, Co-Owner, or Owner)
    IF v_target_role IN ('Co-Owner', 'Admin', 'Owner') THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: Admins cannot remove Admin or Co-Owner role.';
    END IF;
  ELSE
    RAISE EXCEPTION 'PERMISSION_DENIED: You do not have permission to remove room roles.';
  END IF;

  SELECT username INTO v_target_name FROM public.profiles WHERE id = v_target_user_uuid;

  -- Delete role from room_roles & room_assigned_roles
  DELETE FROM public.room_roles WHERE room_id = v_room_id AND user_id = v_target_user_uuid;
  BEGIN
    DELETE FROM public.room_assigned_roles WHERE room_id = v_room_id AND user_id = v_target_user_uuid;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  -- Remove from rooms array columns
  UPDATE public.rooms
  SET co_owner_ids = array_remove(COALESCE(co_owner_ids, '{}'::text[]), v_target_user_uuid::text),
      admin_ids = array_remove(COALESCE(admin_ids, '{}'::text[]), v_target_user_uuid::text),
      host_ids = array_remove(COALESCE(host_ids, '{}'::text[]), v_target_user_uuid::text),
      star_member_ids = array_remove(COALESCE(star_member_ids, '{}'::text[]), v_target_user_uuid::text)
  WHERE id = v_room_id;

  -- Update active room presence role to Audience if present (User remains online if currently in room!)
  UPDATE public.room_members
  SET role = 'Audience',
      updated_at = now()
  WHERE room_id = v_room_id AND user_id = v_target_user_uuid;

  -- Log Activity Event
  INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
  VALUES (v_room_id, 'system', v_target_user_uuid, COALESCE(v_target_name, 'Member'), COALESCE(v_target_name, 'Member') || ' demoted to Audience');

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'target_user_id', v_target_user_uuid,
    'old_role', v_target_role,
    'new_role', 'Audience'
  );
END;
$$;

-- 7. Create SINGLE canonical demote_room_member_role_v2 RPC
CREATE OR REPLACE FUNCTION public.demote_room_member_role_v2(
  p_room_id text,
  p_target_user_id text,
  p_apply_cooldown boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN public.demote_room_member_role(p_room_id, p_target_user_id);
END;
$$;
