-- Migration: Ultra Fast Room Join System (Target: 100ms - 200ms Latency Engine)
-- Date: 2026-08-07

-- 0. Ensure all missing columns exist on public.rooms
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS entry_permission text DEFAULT 'everyone';
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS room_password text DEFAULT NULL;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS vip_requirement int DEFAULT 0;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS level_requirement int DEFAULT 1;

-- 1. Update room_members role check constraint to support all role names
ALTER TABLE public.room_members DROP CONSTRAINT IF EXISTS room_members_role_check;
ALTER TABLE public.room_members ADD CONSTRAINT room_members_role_check 
  CHECK (role IN ('Host', 'Co-Host', 'Moderator', 'Speaker', 'Listener', 'Guest', 'Owner', 'Co Owner', 'Co-Owner', 'Admin', 'Member', 'Audience', 'Creator'));

-- Single Consolidated Atomic RPC for Room Entry
CREATE OR REPLACE FUNCTION public.join_room_fast_v2(
  p_room_id text,
  p_provided_password text DEFAULT NULL,
  p_user_id text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid;
  v_room_id text;
  v_room RECORD;
  v_room_json jsonb;
  v_host_id uuid;
  v_room_owner_id uuid;
  v_host_profile RECORD;
  v_caller_profile RECORD;
  v_is_banned boolean := false;
  v_kick_active boolean := false;
  v_role text := 'Listener';
  v_is_owner boolean := false;
  v_is_co_owner boolean := false;
  v_is_admin boolean := false;
  v_seats jsonb;
  v_custom_perms jsonb;
  v_who_can_join text;
  v_room_pass text;
  v_member_count int := 0;
BEGIN
  -- Resolve Caller UUID (supports auth.uid() or explicit p_user_id fallback)
  IF p_user_id IS NOT NULL AND length(trim(p_user_id)) > 0 THEN
    BEGIN
      v_caller_id := p_user_id::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_caller_id := auth.uid();
    END;
  ELSE
    v_caller_id := auth.uid();
  END IF;

  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- 1. Atomic Room Resolution & Room Details Fetch
  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN
    v_room_id := p_room_id;
  END IF;

  SELECT * INTO v_room FROM public.rooms WHERE id = v_room_id;
  IF v_room.id IS NULL THEN
    RETURN jsonb_build_object(
      'join_allowed', false,
      'reason', 'Room not found.'
    );
  END IF;

  -- Convert room record to jsonb to prevent runtime "record has no field" errors
  v_room_json := to_jsonb(v_room);
  
  BEGIN
    v_host_id := (v_room_json->>'host_id')::uuid;
  EXCEPTION WHEN OTHERS THEN
    v_host_id := NULL;
  END;

  BEGIN
    v_room_owner_id := (v_room_json->>'room_owner')::uuid;
  EXCEPTION WHEN OTHERS THEN
    v_room_owner_id := NULL;
  END;

  -- 2. Fetch Host & Caller Profiles
  IF v_host_id IS NOT NULL THEN
    BEGIN
      SELECT id, username, COALESCE(avatar_url, profile_photo, '') as avatar, gender, level, vip_level INTO v_host_profile 
      FROM public.profiles WHERE id = v_host_id;
    EXCEPTION WHEN OTHERS THEN
      v_host_profile := NULL;
    END;
  END IF;

  BEGIN
    SELECT id, username, COALESCE(avatar_url, profile_photo, '') as avatar, gender, level, vip_level INTO v_caller_profile 
    FROM public.profiles WHERE id = v_caller_id;
  EXCEPTION WHEN OTHERS THEN
    v_caller_profile := NULL;
  END;

  -- 3. Resolve User Role in Room
  IF (v_host_id IS NOT NULL AND v_host_id = v_caller_id) OR (v_room_owner_id IS NOT NULL AND v_room_owner_id = v_caller_id) THEN
    v_role := 'Owner';
    v_is_owner := true;
  ELSE
    SELECT role INTO v_role 
    FROM public.room_members WHERE room_id = v_room_id AND user_id = v_caller_id;
    
    IF v_role IS NULL OR v_role = 'Audience' THEN 
      v_role := 'Listener'; 
    END IF;

    IF v_role IN ('Co-Owner', 'Co Owner') THEN v_is_co_owner := true; END IF;
    IF v_role = 'Admin' THEN v_is_admin := true; END IF;
  END IF;

  -- 4. Check Ban Status (Permanent Ban Check)
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'room_admin_activity_logs' AND table_schema = 'public'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM public.room_admin_activity_logs 
      WHERE room_id = v_room_id AND target_user_id = v_caller_id AND action_type = 'BAN'
    ) THEN
      IF NOT v_is_owner THEN
        RETURN jsonb_build_object(
          'join_allowed', false,
          'reason', 'Permanently banned from this room.'
        );
      END IF;
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'room_bans' AND table_schema = 'public'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM public.room_bans 
      WHERE room_id = v_room_id AND user_id = v_caller_id AND (expires_at IS NULL OR expires_at > now())
    ) THEN
      IF NOT v_is_owner THEN
        RETURN jsonb_build_object(
          'join_allowed', false,
          'reason', 'Banned from this room.'
        );
      END IF;
    END IF;
  END IF;

  -- 5. Check Active Kick Status (Temporary Kick)
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'room_admin_activity_logs' AND table_schema = 'public'
  ) THEN
    SELECT EXISTS (
      SELECT 1 FROM public.room_admin_activity_logs 
      WHERE room_id = v_room_id AND target_user_id = v_caller_id AND action_type = 'KICK'
        AND created_at > (now() - interval '10 minutes')
    ) INTO v_kick_active;

    IF v_kick_active AND NOT v_is_owner AND NOT v_is_co_owner THEN
      RETURN jsonb_build_object(
        'join_allowed', false,
        'reason', 'You were recently removed from this room. Please wait a few minutes.'
      );
    END IF;
  END IF;

  -- 6. Evaluate Room Entry Permissions (Password, Followers Only, VIP Level, User Level, Community)
  v_who_can_join := LOWER(COALESCE(v_room_json->>'entry_permission', v_room_json->>'visibility', 'everyone'));
  v_room_pass := v_room_json->>'room_password';
  
  IF NOT v_is_owner AND NOT v_is_co_owner AND NOT v_is_admin THEN
    -- A. Password Protection
    IF v_who_can_join LIKE '%password%' OR (v_room_pass IS NOT NULL AND length(trim(v_room_pass)) > 0) THEN
      IF p_provided_password IS NULL OR length(trim(p_provided_password)) = 0 THEN
        RETURN jsonb_build_object(
          'join_allowed', false,
          'reason', 'PASSWORD_REQUIRED',
          'password_required', true
        );
      ELSIF trim(p_provided_password) != trim(COALESCE(v_room_pass, '1234')) THEN
        RETURN jsonb_build_object(
          'join_allowed', false,
          'reason', 'Incorrect room password. Access denied.',
          'invalid_password', true
        );
      END IF;
    END IF;

    -- B1. Followers Only Mode (Caller must follow Room Host/Owner)
    IF (v_who_can_join LIKE '%followers_only%' OR v_who_can_join LIKE '%followers only%' OR v_who_can_join LIKE '%owner followers%') THEN
      IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'connections' AND table_schema = 'public'
      ) THEN
        IF v_host_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM public.connections 
          WHERE follower_id = v_caller_id AND following_id = v_host_id
        ) THEN
          RETURN jsonb_build_object(
            'join_allowed', false,
            'reason', 'This arena is restricted to Owner Followers only.',
            'follower_required', true
          );
        END IF;
      END IF;
    END IF;

    -- B2. Owner Following Mode (Room Owner must follow Caller)
    IF (v_who_can_join LIKE '%following_only%' OR v_who_can_join LIKE '%following only%' OR v_who_can_join LIKE '%owner following%') THEN
      IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'connections' AND table_schema = 'public'
      ) THEN
        IF v_host_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM public.connections 
          WHERE follower_id = v_host_id AND following_id = v_caller_id
        ) THEN
          RETURN jsonb_build_object(
            'join_allowed', false,
            'reason', 'This arena is restricted to users followed by the Room Owner.',
            'following_required', true
          );
        END IF;
      END IF;
    END IF;

    -- C. VIP Level Requirement
    IF v_who_can_join LIKE '%vip%' AND COALESCE(v_caller_profile.vip_level, 1) < COALESCE((v_room_json->>'vip_requirement')::int, 0) THEN
      RETURN jsonb_build_object(
        'join_allowed', false,
        'reason', format('VIP Level %s required to enter this arena.', COALESCE((v_room_json->>'vip_requirement')::int, 0)),
        'vip_required', true
      );
    END IF;

    -- D. User Level Requirement
    IF v_who_can_join LIKE '%level%' AND COALESCE(v_caller_profile.level, 1) < COALESCE((v_room_json->>'level_requirement')::int, 1) THEN
      RETURN jsonb_build_object(
        'join_allowed', false,
        'reason', format('User Level %s required to enter this arena.', COALESCE((v_room_json->>'level_requirement')::int, 1)),
        'level_required', true
      );
    END IF;
  END IF;

  -- 7. Fetch Active Seat Map Layout & Occupants
  SELECT jsonb_agg(s) INTO v_seats FROM (
    SELECT 
      m.user_id,
      m.role,
      m.is_muted,
      p.username,
      COALESCE(p.avatar_url, p.profile_photo, '') as avatar,
      p.username as display_name
    FROM public.room_members m
    LEFT JOIN public.profiles p ON p.id = m.user_id
    WHERE m.room_id = v_room_id
    LIMIT 10
  ) s;

  -- 8. Get Realtime Audience Count
  SELECT COUNT(*) INTO v_member_count FROM public.room_members WHERE room_id = v_room_id;
  IF v_member_count = 0 THEN v_member_count := 1; END IF;

  -- 9. Upsert Member Join Session
  INSERT INTO public.room_members (room_id, user_id, role, joined_at)
  VALUES (v_room_id, v_caller_id, v_role, now())
  ON CONFLICT (room_id, user_id) DO UPDATE 
  SET role = EXCLUDED.role, joined_at = now();

  -- 10. Construct Single Consolidated Response
  RETURN jsonb_build_object(
    'join_allowed', true,
    'reason', 'Allowed',
    'room_info', jsonb_build_object(
      'id', v_room_json->>'id',
      'name', COALESCE(v_room_json->>'name', 'Arena'),
      'username', COALESCE(v_room_json->>'username', ''),
      'category', COALESCE(v_room_json->>'category', 'General'),
      'language', COALESCE(v_room_json->>'language', 'English'),
      'host_id', v_host_id,
      'room_owner', v_room_owner_id,
      'avatar', COALESCE(v_room_json->>'avatar', ''),
      'banner', COALESCE(v_room_json->>'banner', ''),
      'room_cover_url', COALESCE(v_room_json->>'room_cover_url', ''),
      'room_level', COALESCE((v_room_json->>'room_level')::int, 1),
      'is_emergency_mode', COALESCE((v_room_json->>'is_emergency_mode')::boolean, false),
      'security_score', COALESCE((v_room_json->>'security_score')::numeric, 5.00),
      'health_score', COALESCE((v_room_json->>'health_score')::int, 100),
      'governance_level', COALESCE((v_room_json->>'governance_level')::int, 1)
    ),
    'host_profile', jsonb_build_object(
      'id', COALESCE(v_host_profile.id, v_host_id),
      'username', COALESCE(v_host_profile.username, 'Creania Host'),
      'display_name', COALESCE(v_host_profile.username, 'Creania Host'),
      'avatar', COALESCE(v_host_profile.avatar, ''),
      'gender', COALESCE(v_host_profile.gender, 'other'),
      'level', COALESCE(v_host_profile.level, 1),
      'vip_level', COALESCE(v_host_profile.vip_level, 0)
    ),
    'caller_permissions', jsonb_build_object(
      'role', v_role,
      'is_owner', v_is_owner,
      'is_co_owner', v_is_co_owner,
      'is_admin', v_is_admin,
      'custom_permissions', COALESCE(v_custom_perms, '{}'::jsonb)
    ),
    'seat_map', COALESCE(v_seats, '[]'::jsonb),
    'member_count', v_member_count,
    'server_timestamp', now()
  );
END;
$$;
