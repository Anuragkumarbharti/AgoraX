-- Create room_requests table if it doesn't exist
create table if not exists public.room_requests (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  status text default 'pending' check (status in ('pending', 'accepted', 'rejected', 'demoted')),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (room_id, user_id)
);

-- Enable RLS
alter table public.room_requests enable row level security;

-- Create policies if they don't exist
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'room_requests' and policyname = 'Allow select for room requests') then
    create policy "Allow select for room requests" on public.room_requests
      for select using (true);
  end if;
  
  if not exists (select 1 from pg_policies where tablename = 'room_requests' and policyname = 'Allow insert for authenticated users') then
    create policy "Allow insert for authenticated users" on public.room_requests
      for insert with check (auth.uid() = user_id);
  end if;

  if not exists (select 1 from pg_policies where tablename = 'room_requests' and policyname = 'Allow update/delete for room owners/moderators') then
    create policy "Allow update/delete for room owners/moderators" on public.room_requests
      for all using (
        exists (
          select 1 from public.rooms r
          where r.id = room_requests.room_id and r.host_id = auth.uid()
        ) or 
        exists (
          select 1 from public.room_members m
          where m.room_id = room_requests.room_id and m.user_id = auth.uid() and m.role in ('Co-Host', 'Moderator')
        ) or
        auth.uid() = user_id
      );
  end if;
end
$$;

-- Enable Realtime for room_requests if not already enabled
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_requests'
    ) then
      alter publication supabase_realtime add table public.room_requests;
    end if;
  end if;
end
$$;

-- 1. Add last_heartbeat_at column to room_members if it doesn't exist
alter table public.room_members 
  add column if not exists last_heartbeat_at timestamp with time zone default timezone('utc'::text, now()) not null;

-- 2. Create the presence cleanup function
create or replace function public.cleanup_expired_room_members()
returns void as $$
declare
  v_expired record;
  v_username text;
  v_new_host_id uuid;
  v_has_members boolean;
begin
  -- Find all room members who have missed their heartbeats (no update in last 25 seconds)
  for v_expired in 
    select room_id, user_id, role 
    from public.room_members 
    where last_heartbeat_at < (now() - interval '25 seconds')
  loop
    -- Fetch username for activity event
    select username into v_username from public.profiles where id = v_expired.user_id;

    -- A. Free their occupied seat in room_seats if any
    update public.room_seats
    set user_id = null,
        mic_status = 'muted',
        is_speaking = false
    where room_id = v_expired.room_id and user_id = v_expired.user_id;

    -- B. Remove any pending raised-hand requests or speak requests
    delete from public.room_requests
    where room_id = v_expired.room_id and user_id = v_expired.user_id;

    -- C. Delete from room_members
    delete from public.room_members 
    where room_id = v_expired.room_id and user_id = v_expired.user_id;

    -- D. Delete from room_member_heartbeats
    delete from public.room_member_heartbeats
    where room_id = v_expired.room_id and user_id = v_expired.user_id;

    -- E. Broadcast a leave event to all connected clients
    insert into public.room_activity_events (room_id, event_type, user_id, username, message)
    values (v_expired.room_id, 'leave', v_expired.user_id, v_username, coalesce(v_username, 'Someone') || ' left the room (timeout)');

    -- F. If the timed-out user was the room owner/host, handle ownership transfer or closure
    if exists (select 1 from public.rooms where id = v_expired.room_id and host_id = v_expired.user_id) then
      -- Check if there are other members left in the room
      select exists(select 1 from public.room_members where room_id = v_expired.room_id) into v_has_members;

      if v_has_members then
        -- Find the next Host candidate currently inside the room (preferring Co-Host, Moderator, Speaker, then Listener)
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
          -- Transfer ownership
          update public.rooms
          set host_id = v_new_host_id
          where id = v_expired.room_id;

          -- Elevate candidate's role to Host
          update public.room_members
          set role = 'Host'
          where room_id = v_expired.room_id and user_id = v_new_host_id;

          -- Fetch new host username
          select username into v_username from public.profiles where id = v_new_host_id;

          -- Broadcast ownership transfer event
          insert into public.room_activity_events (room_id, event_type, user_id, username, message)
          values (v_expired.room_id, 'system', v_new_host_id, v_username, 'Ownership transferred to ' || coalesce(v_username, 'new host') || ' because the owner disconnected.');
        end if;
      else
        -- If no members left and it's not a permanent room, delete it
        if not exists (select 1 from public.rooms where id = v_expired.room_id and is_permanent = true) then
          delete from public.rooms where id = v_expired.room_id;
        end if;
      end if;
    end if;
  end loop;
end;
$$ language plpgsql security definer set search_path = public;

-- 3. Update heartbeat_room_member to do cleanup and record room_members heartbeat
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
  v_speak_added integer := 0;
  v_comm_id text;
begin
  if v_user_id is null then
    raise exception 'Unauthenticated user';
  end if;

  -- Ensure the user is actually a member of the room
  if not exists (select 1 from public.room_members where room_id = p_room_id and user_id = v_user_id) then
    return;
  end if;

  -- Run expired members cleanup first to purge inactive users
  perform public.cleanup_expired_room_members();

  -- Update last_heartbeat_at in room_members
  update public.room_members
  set last_heartbeat_at = now()
  where room_id = p_room_id and user_id = v_user_id;

  -- Keep existing reputation/community EXP code intact
  select last_seen_at into v_last_seen
  from public.room_member_heartbeats
  where room_id = p_room_id and user_id = v_user_id;

  if v_last_seen is not null then
    v_elapsed := extract(epoch from (now() - v_last_seen))::integer;
    if v_elapsed >= 2 and v_elapsed <= 45 then
      v_stay_added := v_elapsed;
      if p_is_speaking then
        v_speak_added := v_elapsed;
      end if;
    end if;
  end if;

  insert into public.room_member_heartbeats (room_id, user_id, last_seen_at)
  values (p_room_id, v_user_id, now())
  on conflict (room_id, user_id) do update set last_seen_at = EXCLUDED.last_seen_at;

  -- Add voice room reputation to room
  if v_stay_added > 0 then
    perform public.add_room_xp(p_room_id, greatest(1, v_stay_added / 5));
  end if;

  -- Add normal daily EXP to the user's community
  select community_id into v_comm_id from public.community_memberships where user_id = v_user_id limit 1;
  if v_comm_id is not null and v_stay_added > 0 then
    perform public.add_community_exp_rpc(v_comm_id, v_user_id, 'normal', greatest(1, v_stay_added / 10), 'voice_stay_' || p_room_id);
  end if;
end;
$$ language plpgsql security definer set search_path = public;

-- 4. Inject cleanup call into room entry functions (so newly entering user gets immediately synchronized list)
create or replace function public.join_room(
  p_room_id text,
  p_password text default null
) returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_user_profile public.profiles%rowtype;
  v_current_count integer;
  v_role text;
begin
  -- Run expired members cleanup first
  perform public.cleanup_expired_room_members();

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

  if v_room.host_id = v_user_id then
    v_role := 'Host';
  else
    v_role := 'Listener';
  end if;

  insert into public.room_members (room_id, user_id, role, last_heartbeat_at)
  values (p_room_id, v_user_id, v_role, now())
  on conflict (room_id, user_id) do update set role = EXCLUDED.role, last_heartbeat_at = now();

  insert into public.room_activity_events (room_id, event_type, user_id, username, message)
  values (p_room_id, 'join', v_user_id, v_user_profile.username, v_user_profile.username || ' joined the room');

  return jsonb_build_object(
    'success', true,
    'role', v_role,
    'livekit_room_name', v_room.livekit_room_name
  );
end;
$$ language plpgsql security definer set search_path = public;
