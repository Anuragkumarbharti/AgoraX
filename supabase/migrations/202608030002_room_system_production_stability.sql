-- Migration: 202608030002_room_system_production_stability.sql
-- Production stability, heartbeat cleanup (15s timeout), snapshot repair RPC, and room real-time sync enforcement

-- 1. Create or replace the presence cleanup function with strict 15-second timeout
create or replace function public.cleanup_expired_room_members()
returns void as $$
declare
  v_expired record;
  v_username text;
  v_new_host_id uuid;
  v_has_members boolean;
begin
  -- Find all room members who have missed their heartbeats (no heartbeat update in last 15 seconds)
  for v_expired in 
    select room_id, user_id, role 
    from public.room_members 
    where last_heartbeat_at < (now() - interval '15 seconds')
  loop
    -- Fetch username for activity event
    select username into v_username from public.profiles where id = v_expired.user_id;

    -- A. Free occupied seat in room_seats if any
    update public.room_seats
    set user_id = null,
        mic_status = 'muted',
        is_speaking = false
    where room_id = v_expired.room_id and user_id = v_expired.user_id;

    -- B. Remove pending hand-raise requests
    delete from public.room_requests
    where room_id = v_expired.room_id and user_id = v_expired.user_id;

    -- C. Delete from room_members
    delete from public.room_members 
    where room_id = v_expired.room_id and user_id = v_expired.user_id;

    -- D. Delete from room_member_heartbeats
    delete from public.room_member_heartbeats
    where room_id = v_expired.room_id and user_id = v_expired.user_id;

    -- E. Broadcast a leave event to all connected clients
    insert into public.room_activity_events (room_id, event_type, user_id, username, message, metadata)
    values (
      v_expired.room_id, 
      'leave', 
      v_expired.user_id, 
      v_username, 
      coalesce(v_username, 'Someone') || ' left the room (timeout)',
      jsonb_build_object('reason', 'timeout')
    );

    -- F. If timed-out user was room owner/host, handle ownership transfer or room closure
    if exists (select 1 from public.rooms where id = v_expired.room_id and host_id = v_expired.user_id) then
      select exists(select 1 from public.room_members where room_id = v_expired.room_id) into v_has_members;

      if v_has_members then
        select user_id into v_new_host_id
        from public.room_members
        where room_id = v_expired.room_id
        order by 
          case role
            when 'Co-Host' then 1
            when 'Moderator' then 2
            when 'Speaker' then 3
            when 'Listener' then 4
            else 5
          end,
          joined_at asc
        limit 1;

        if v_new_host_id is not null then
          update public.rooms set host_id = v_new_host_id where id = v_expired.room_id;
          update public.room_members set role = 'Host' where room_id = v_expired.room_id and user_id = v_new_host_id;

          select username into v_username from public.profiles where id = v_new_host_id;

          insert into public.room_activity_events (room_id, event_type, user_id, username, message)
          values (
            v_expired.room_id, 
            'system', 
            v_new_host_id, 
            v_username, 
            'Ownership transferred to ' || coalesce(v_username, 'new host') || ' due to host disconnect.'
          );
        end if;
      else
        if not exists (select 1 from public.rooms where id = v_expired.room_id and is_permanent = true) then
          update public.rooms set status = 'ended', end_time = now() where id = v_expired.room_id;
        end if;
      end if;
    end if;
  end loop;

  -- G. Update online_members count on rooms table
  update public.rooms r
  set online_members = (
    select count(*) from public.room_members m where m.room_id = r.id
  )
  where r.status = 'live';
end;
$$ language plpgsql security definer set search_path = public;

-- 2. Heartbeat RPC with immediate expiration processing
create or replace function public.heartbeat_room_member(
  p_room_id text,
  p_is_speaking boolean
)
returns void as $$
declare
  v_user_id uuid := auth.uid();
  v_last_seen timestamp with time zone;
  v_elapsed integer;
  v_stay_added integer := 0;
  v_comm_id text;
begin
  if v_user_id is null then
    raise exception 'Unauthenticated user';
  end if;

  -- Purge stale members first
  perform public.cleanup_expired_room_members();

  -- If user was purged or not in room_members, re-insert or update
  insert into public.room_members (room_id, user_id, role, last_heartbeat_at)
  values (p_room_id, v_user_id, 'Listener', now())
  on conflict (room_id, user_id) do update 
    set last_heartbeat_at = now();

  -- Update last_seen in room_member_heartbeats
  select last_seen_at into v_last_seen
  from public.room_member_heartbeats
  where room_id = p_room_id and user_id = v_user_id;

  if v_last_seen is not null then
    v_elapsed := extract(epoch from (now() - v_last_seen))::integer;
    if v_elapsed >= 2 and v_elapsed <= 30 then
      v_stay_added := v_elapsed;
    end if;
  end if;

  insert into public.room_member_heartbeats (room_id, user_id, last_seen_at)
  values (p_room_id, v_user_id, now())
  on conflict (room_id, user_id) do update set last_seen_at = EXCLUDED.last_seen_at;

  -- Update online_members count
  update public.rooms
  set online_members = (select count(*) from public.room_members where room_id = p_room_id)
  where id = p_room_id;
end;
$$ language plpgsql security definer set search_path = public;

-- 3. Atomic Server-Validated Snapshot Repair RPC
create or replace function public.get_room_state_snapshot(
  p_room_id text
) returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_room jsonb;
  v_seats jsonb;
  v_members jsonb;
  v_requests jsonb;
  v_settings jsonb;
  v_chat_history jsonb;
  v_eye_count integer;
begin
  if v_user_id is null then
    raise exception 'Unauthenticated';
  end if;

  -- Run cleanup first to ensure snapshot is clean
  perform public.cleanup_expired_room_members();

  -- Room metadata
  select jsonb_build_object(
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
    'room_xp', r.room_xp
  ) into v_room
  from public.rooms r
  where r.id = p_room_id;

  if v_room is null then
    raise exception 'Room not found';
  end if;

  -- Eye count (active online members)
  select count(*) into v_eye_count
  from public.room_members
  where room_id = p_room_id;

  -- Room seats (10 seats 0..9)
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'seatIndex', s.seat_index,
      'role', s.role,
      'userId', s.user_id,
      'username', coalesce(s.username, p.username, 'Seat ' || (s.seat_index + 1)),
      'avatar', coalesce(s.avatar, p.avatar),
      'avatarFrame', s.avatar_frame,
      'level', coalesce(s.level, p.level, 1),
      'vipLevel', coalesce(s.vip_level, p.vip_level, 0),
      'nobleLevel', coalesce(s.noble_level, p.novel_level, 0),
      'micStatus', s.mic_status,
      'isSpeaking', s.is_speaking,
      'silverGiftCount', coalesce(g.silver_gift_count, 0)
    ) order by s.seat_index
  ), '[]'::jsonb) into v_seats
  from public.room_seats s
  left join public.profiles p on p.id = s.user_id
  left join public.room_seat_gifts g on g.room_id = s.room_id and g.seat_index = s.seat_index
  where s.room_id = p_room_id;

  -- Room members
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'userId', m.user_id,
      'username', p.username,
      'avatar', p.avatar,
      'role', m.role,
      'isMuted', m.is_muted,
      'hasRaisedHand', m.has_raised_hand,
      'joinedAt', m.joined_at,
      'level', p.level,
      'vipLevel', p.vip_level,
      'nobleLevel', p.novel_level
    ) order by m.joined_at asc
  ), '[]'::jsonb) into v_members
  from public.room_members m
  join public.profiles p on p.id = m.user_id
  where m.room_id = p_room_id;

  -- Room requests (hand raises)
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', req.id,
      'userId', req.user_id,
      'username', p.username,
      'avatar', p.avatar,
      'status', req.status,
      'createdAt', req.created_at
    )
  ), '[]'::jsonb) into v_requests
  from public.room_requests req
  join public.profiles p on p.id = req.user_id
  where req.room_id = p_room_id and req.status = 'pending';

  -- Room settings
  select jsonb_build_object(
    'isPrivate', st.is_private,
    'chatEnabled', st.chat_enabled,
    'micForAll', st.mic_for_all,
    'allowRequestSpeak', st.allow_request_speak,
    'welcomeMessage', st.welcome_message,
    'themeColor', st.theme_color
  ) into v_settings
  from public.room_settings st
  where st.room_id = p_room_id;

  -- Recent room chat messages (last 50)
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', msg.id,
      'senderId', msg.sender_id,
      'senderName', p.username,
      'senderAvatar', p.avatar,
      'content', msg.content,
      'messageType', msg.message_type,
      'metadata', msg.metadata,
      'createdAt', msg.created_at
    ) order by msg.created_at asc
  ), '[]'::jsonb) into v_chat_history
  from (
    select * from public.room_messages 
    where room_id = p_room_id 
    order by created_at desc 
    limit 50
  ) msg
  join public.profiles p on p.id = msg.sender_id;

  return jsonb_build_object(
    'room', v_room,
    'eye_count', v_eye_count,
    'seats', v_seats,
    'members', v_members,
    'requests', v_requests,
    'settings', v_settings,
    'chat_history', v_chat_history
  );
end;
$$ language plpgsql security definer set search_path = public;

-- 4. Server-Validated Send Room Chat Message RPC
create or replace function public.send_room_chat_message(
  p_room_id text,
  p_content text,
  p_message_type text default 'text',
  p_metadata jsonb default '{}'::jsonb
) returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_msg_id uuid;
  v_is_muted boolean;
begin
  if v_user_id is null then
    raise exception 'Unauthenticated';
  end if;

  -- Verify user is in room
  if not exists (select 1 from public.room_members where room_id = p_room_id and user_id = v_user_id) then
    raise exception 'User is not a member of this room';
  end if;

  -- Verify user is not chat muted or banned
  select is_muted into v_is_muted from public.room_members where room_id = p_room_id and user_id = v_user_id;
  if v_is_muted then
    raise exception 'You are muted in this room';
  end if;

  if exists (select 1 from public.room_bans where room_id = p_room_id and user_id = v_user_id and (expires_at is null or expires_at > now())) then
    raise exception 'You are banned from this room';
  end if;

  select * into v_profile from public.profiles where id = v_user_id;

  insert into public.room_messages (room_id, sender_id, content, message_type, metadata)
  values (p_room_id, v_user_id, p_content, p_message_type, p_metadata)
  returning id into v_msg_id;

  return jsonb_build_object(
    'id', v_msg_id,
    'sender_id', v_user_id,
    'sender_name', v_profile.username,
    'sender_avatar', v_profile.avatar,
    'content', p_content,
    'message_type', p_message_type,
    'metadata', p_metadata,
    'created_at', now()
  );
end;
$$ language plpgsql security definer set search_path = public;
