-- ============================================================================
-- MIGRATION: 202608080004_smart_presence_and_room_cleanup_system.sql
-- DESCRIPTION: Production Level Smart Presence, 20s Heartbeat, 60s Grace Period,
--              Single Session Enforcement, and O(expired) Background Cleanup.
-- ============================================================================

-- 1. Add session_id and is_reconnecting columns to room_members & room_seats
alter table public.room_members 
  add column if not exists session_id text,
  add column if not exists is_reconnecting boolean default false not null;

alter table public.room_seats
  add column if not exists session_id text,
  add column if not exists is_reconnecting boolean default false not null;

-- Add indexes for high-performance O(expired) grace period queries
create index if not exists idx_room_members_heartbeat_reconnecting 
  on public.room_members(is_reconnecting, last_heartbeat_at);

create index if not exists idx_room_members_user_session 
  on public.room_members(user_id, session_id);

create index if not exists idx_room_seats_user_session 
  on public.room_seats(room_id, user_id);

-- 2. Register User Session RPC (Single Active Session Enforcement)
create or replace function public.register_user_session_rpc(
  p_session_id text,
  p_device_id text default 'unknown',
  p_device_name text default 'Mobile Device',
  p_os_version text default 'Android/iOS',
  p_app_version text default '1.0.0',
  p_platform text default 'Flutter'
) returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_old_session text;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Check if user has another active session
  select session_id into v_old_session
  from public.user_sessions
  where user_id = v_user_id and session_id <> p_session_id and online_status <> 'Offline'
  limit 1;

  if v_old_session is not null then
    -- Invalidate old session status
    update public.user_sessions
    set online_status = 'Offline'
    where user_id = v_user_id and session_id = v_old_session;
    
    -- Free old session seats
    update public.room_seats
    set user_id = null, mic_status = 'muted', is_speaking = false, is_reconnecting = false, session_id = null
    where user_id = v_user_id and session_id = v_old_session;

    -- Remove from room members of old session
    delete from public.room_members
    where user_id = v_user_id and session_id = v_old_session;
  end if;

  -- Upsert current active session
  insert into public.user_sessions (
    session_id, user_id, device_id, device_name, os_version, app_version, platform, online_status, last_seen
  ) values (
    p_session_id, v_user_id, p_device_id, p_device_name, p_os_version, p_app_version, p_platform, 'Online', now()
  )
  on conflict (session_id) do update set
    device_id = EXCLUDED.device_id,
    device_name = EXCLUDED.device_name,
    os_version = EXCLUDED.os_version,
    app_version = EXCLUDED.app_version,
    platform = EXCLUDED.platform,
    online_status = 'Online',
    last_seen = now();

  return jsonb_build_object(
    'success', true,
    'session_id', p_session_id,
    'old_session_invalidated', v_old_session is not null
  );
end;
$$ language plpgsql security definer set search_path = public;

-- 3. Production Smart Presence Cleanup Function
-- Phase 1: Heartbeat missing > 20s -> Mark as is_reconnecting = true (Grace Period)
-- Phase 2: Heartbeat missing > 60s & is_reconnecting = true -> Expire & Remove User
create or replace function public.process_presence_grace_period_and_cleanup()
returns void as $$
declare
  v_rec record;
  v_username text;
  v_has_members boolean;
  v_new_host_id uuid;
begin
  -- Phase 1: Transition users who missed 20s heartbeat into Grace Period (is_reconnecting = true)
  update public.room_members
  set is_reconnecting = true
  where last_heartbeat_at < (now() - interval '20 seconds')
    and is_reconnecting = false;

  -- Also update corresponding seats to muted and non-speaking during grace period
  update public.room_seats s
  set is_speaking = false,
      mic_status = 'muted',
      is_reconnecting = true
  from public.room_members m
  where s.room_id = m.room_id 
    and s.user_id = m.user_id 
    and m.is_reconnecting = true
    and s.is_reconnecting = false;

  -- Phase 2: Permanently remove users whose grace period has expired (> 60 seconds timeout)
  for v_rec in 
    select room_id, user_id, role, session_id 
    from public.room_members 
    where is_reconnecting = true 
      and last_heartbeat_at < (now() - interval '60 seconds')
  loop
    select username into v_username from public.profiles where id = v_rec.user_id;

    -- A. Free seat
    update public.room_seats
    set user_id = null,
        mic_status = 'muted',
        is_speaking = false,
        is_reconnecting = false,
        session_id = null
    where room_id = v_rec.room_id and user_id = v_rec.user_id;

    -- B. Delete requests
    delete from public.room_requests
    where room_id = v_rec.room_id and user_id = v_rec.user_id;

    -- C. Delete from room_members
    delete from public.room_members 
    where room_id = v_rec.room_id and user_id = v_rec.user_id;

    -- D. Delete heartbeats
    delete from public.room_member_heartbeats
    where room_id = v_rec.room_id and user_id = v_rec.user_id;

    -- E. Broadcast leave event (USER_LEFT)
    insert into public.room_activity_events (room_id, event_type, user_id, username, message)
    values (v_rec.room_id, 'leave', v_rec.user_id, v_username, coalesce(v_username, 'Someone') || ' left the room (grace period expired)');

    -- F. Host transfer check
    if exists (select 1 from public.rooms where id = v_rec.room_id and host_id = v_rec.user_id) then
      select exists(select 1 from public.room_members where room_id = v_rec.room_id) into v_has_members;

      if v_has_members then
        select user_id into v_new_host_id
        from public.room_members
        where room_id = v_rec.room_id
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
          update public.rooms set host_id = v_new_host_id where id = v_rec.room_id;
          update public.room_members set role = 'Host' where room_id = v_rec.room_id and user_id = v_new_host_id;
          select username into v_username from public.profiles where id = v_new_host_id;

          insert into public.room_activity_events (room_id, event_type, user_id, username, message)
          values (v_rec.room_id, 'system', v_new_host_id, v_username, 'Ownership transferred to ' || coalesce(v_username, 'new host') || ' because owner disconnected.');
        end if;
      else
        if not exists (select 1 from public.rooms where id = v_rec.room_id and is_permanent = true) then
          delete from public.rooms where id = v_rec.room_id;
        end if;
      end if;
    end if;
  end loop;
end;
$$ language plpgsql security definer set search_path = public;

-- 4. Minimal Lightweight 20s Heartbeat RPC
create or replace function public.heartbeat_room_member(
  p_room_id text,
  p_session_id text default null,
  p_is_speaking boolean default false
) returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_was_reconnecting boolean := false;
begin
  if v_user_id is null then
    raise exception 'Unauthenticated user';
  end if;

  -- Execute background grace period check
  perform public.process_presence_grace_period_and_cleanup();

  -- Verify membership
  select is_reconnecting into v_was_reconnecting
  from public.room_members
  where room_id = p_room_id and user_id = v_user_id;

  if v_was_reconnecting is null then
    return jsonb_build_object('success', false, 'reason', 'Not a member of this room');
  end if;

  -- Refresh heartbeat timestamp and restore online reconnecting state
  update public.room_members
  set last_heartbeat_at = now(),
      is_reconnecting = false,
      session_id = coalesce(p_session_id, session_id)
  where room_id = p_room_id and user_id = v_user_id;

  -- Restore seat reconnecting status if user is seated
  update public.room_seats
  set is_reconnecting = false,
      is_speaking = p_is_speaking,
      session_id = coalesce(p_session_id, session_id)
  where room_id = p_room_id and user_id = v_user_id;

  -- Update session last_seen in user_sessions
  if p_session_id is not null then
    update public.user_sessions
    set last_seen = now(), online_status = 'In Room'
    where session_id = p_session_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'restored_from_grace_period', v_was_reconnecting
  );
end;
$$ language plpgsql security definer set search_path = public;

-- 5. Updated join_room RPC with session_id support
create or replace function public.join_room(
  p_room_id text,
  p_password text default null,
  p_session_id text default null
) returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_user_profile public.profiles%rowtype;
  v_current_count integer;
  v_role text;
begin
  perform public.process_presence_grace_period_and_cleanup();
  perform public.leave_all_rooms(v_user_id, p_room_id);

  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_room from public.rooms where id = p_room_id;
  if v_room.id is null then
    raise exception 'Room not found';
  end if;

  if v_room.status = 'ended' then
    raise exception 'Room has already ended';
  end if;

  if exists (select 1 from public.room_bans where room_id = p_room_id and user_id = v_user_id and (expires_at is null or expires_at > now())) then
    raise exception 'You are banned from this room';
  end if;

  select count(*) into v_current_count from public.room_members where room_id = p_room_id;
  if v_current_count >= 100 then
    raise exception 'Room is full';
  end if;

  select * into v_user_profile from public.profiles where id = v_user_id;
  if v_user_profile.level < v_room.level_requirement then
    raise exception 'Requires ID Level % or higher', v_room.level_requirement;
  end if;

  if v_user_profile.is_banned = true then
    raise exception 'Your account is banned';
  end if;

  if v_room.host_id = v_user_id then
    v_role := 'Host';
  else
    v_role := 'Listener';
  end if;

  insert into public.room_members (room_id, user_id, role, last_heartbeat_at, session_id, is_reconnecting)
  values (p_room_id, v_user_id, v_role, now(), p_session_id, false)
  on conflict (room_id, user_id) do update set role = EXCLUDED.role, last_heartbeat_at = now(), session_id = EXCLUDED.session_id, is_reconnecting = false;

  update public.profiles
  set active_room_id = p_room_id, presence_state = 'In Room'
  where id = v_user_id;

  insert into public.room_activity_events (room_id, event_type, user_id, username, message)
  values (p_room_id, 'join', v_user_id, v_user_profile.username, v_user_profile.username || ' joined the room');

  return jsonb_build_object(
    'success', true,
    'role', v_role,
    'livekit_room_name', v_room.livekit_room_name
  );
end;
$$ language plpgsql security definer set search_path = public;

-- 6. Instant Normal Disconnect leave_room RPC
create or replace function public.leave_room(
  p_room_id text
) returns boolean as $$
declare
  v_user_id uuid := auth.uid();
  v_username text;
begin
  if v_user_id is null then
    return false;
  end if;

  select username into v_username from public.profiles where id = v_user_id;

  update public.room_seats
  set user_id = null,
      mic_status = 'muted',
      is_speaking = false,
      is_reconnecting = false,
      session_id = null
  where room_id = p_room_id and user_id = v_user_id;

  delete from public.room_members where room_id = p_room_id and user_id = v_user_id;
  delete from public.room_requests where room_id = p_room_id and user_id = v_user_id;

  update public.profiles
  set active_room_id = null, presence_state = 'Online'
  where id = v_user_id;

  insert into public.room_activity_events (room_id, event_type, user_id, username, message)
  values (p_room_id, 'leave', v_user_id, v_username, coalesce(v_username, 'Someone') || ' left the room');

  return true;
end;
$$ language plpgsql security definer set search_path = public;
