-- Migration: Ultra Fast Room Join System (Target: 100ms - 200ms Latency Engine)
-- Date: 2026-08-07

-- Single Consolidated Atomic RPC for Room Entry
CREATE OR REPLACE FUNCTION public.join_room_fast_v2(
  p_room_id text,
  p_provided_password text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_room RECORD;
  v_host_profile RECORD;
  v_caller_profile RECORD;
  v_is_banned boolean := false;
  v_kick_active boolean := false;
  v_role text := 'Audience';
  v_is_owner boolean := false;
  v_is_co_owner boolean := false;
  v_is_admin boolean := false;
  v_seats jsonb;
  v_custom_perms jsonb;
  v_who_can_join text;
  v_member_count int := 0;
BEGIN
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

  -- 2. Fetch Host & Caller Profiles
  SELECT id, username, COALESCE(avatar_url, profile_photo, '') as avatar, gender, level, vip_level INTO v_host_profile 
  FROM public.profiles WHERE id = v_room.host_id;

  SELECT id, username, COALESCE(avatar_url, profile_photo, '') as avatar, gender, level, vip_level INTO v_caller_profile 
  FROM public.profiles WHERE id = v_caller_id;

  -- 3. Resolve User Role in Room
  IF v_room.host_id = v_caller_id OR (v_room.room_owner IS NOT NULL AND v_room.room_owner = v_caller_id) THEN
    v_role := 'Owner';
    v_is_owner := true;
  ELSE
    SELECT role INTO v_role 
    FROM public.room_members WHERE room_id = v_room_id AND user_id = v_caller_id;
    
    IF v_role IS NULL THEN v_role := 'Audience'; END IF;

    IF v_role IN ('Co-Owner', 'Co Owner') THEN v_is_co_owner := true; END IF;
    IF v_role = 'Admin' THEN v_is_admin := true; END IF;
  END IF;

  -- 4. Check Ban Status (Permanent Ban Check)
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

  -- 5. Check Active Kick Status (Temporary Kick)
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

  -- 6. Evaluate Room Entry Permissions (Password, Followers Only, VIP Level, User Level, Community)
  v_who_can_join := LOWER(COALESCE(v_room.entry_permission, v_room.visibility, 'everyone'));
  
  IF NOT v_is_owner AND NOT v_is_co_owner AND NOT v_is_admin THEN
    -- A. Password Protection
    IF v_who_can_join LIKE '%password%' OR v_room.room_password IS NOT NULL THEN
      IF p_provided_password IS NULL OR length(trim(p_provided_password)) = 0 THEN
        RETURN jsonb_build_object(
          'join_allowed', false,
          'reason', 'PASSWORD_REQUIRED',
          'password_required', true
        );
      ELSIF trim(p_provided_password) != trim(COALESCE(v_room.room_password, v_room.rules[1], '1234')) THEN
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
        IF NOT EXISTS (
          SELECT 1 FROM public.connections 
          WHERE follower_id = v_caller_id AND following_id = v_room.host_id
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
        IF NOT EXISTS (
          SELECT 1 FROM public.connections 
          WHERE follower_id = v_room.host_id AND following_id = v_caller_id
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
    IF v_who_can_join LIKE '%vip%' AND COALESCE(v_caller_profile.vip_level, 1) < COALESCE(v_room.vip_requirement, 0) THEN
      RETURN jsonb_build_object(
        'join_allowed', false,
        'reason', format('VIP Level %s required to enter this arena.', COALESCE(v_room.vip_requirement, 0)),
        'vip_required', true
      );
    END IF;

    -- D. User Level Requirement
    IF v_who_can_join LIKE '%level%' AND COALESCE(v_caller_profile.level, 1) < COALESCE(v_room.level_requirement, 1) THEN
      RETURN jsonb_build_object(
        'join_allowed', false,
        'reason', format('User Level %s required to enter this arena.', COALESCE(v_room.level_requirement, 1)),
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
  ON CONFLICT (room_id, user_id) DO NOTHING;

  -- 10. Construct Single Consolidated Response
  RETURN jsonb_build_object(
    'join_allowed', true,
    'reason', 'Allowed',
    'room_info', jsonb_build_object(
      'id', v_room.id,
      'name', v_room.name,
      'username', v_room.username,
      'category', v_room.category,
      'language', v_room.language,
      'host_id', v_room.host_id,
      'room_owner', v_room.room_owner,
      'avatar', v_room.avatar,
      'banner', v_room.banner,
      'room_cover_url', v_room.room_cover_url,
      'room_level', COALESCE(v_room.room_level, 1),
      'is_emergency_mode', COALESCE(v_room.is_emergency_mode, false),
      'security_score', COALESCE(v_room.security_score, 5.00),
      'health_score', COALESCE(v_room.health_score, 100),
      'governance_level', COALESCE(v_room.governance_level, 1)
    ),
    'host_profile', jsonb_build_object(
      'id', v_host_profile.id,
      'username', v_host_profile.username,
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
