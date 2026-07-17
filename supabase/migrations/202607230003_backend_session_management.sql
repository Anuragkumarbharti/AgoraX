-- Add active_room_id and presence_state to profiles if they do not exist
alter table public.profiles
  add column if not exists active_room_id text references public.rooms(id) on delete set null,
  add column if not exists presence_state text default 'Offline' check (presence_state in ('Online', 'In Room', 'Speaking', 'Idle', 'Background', 'Offline'));

-- Create user_sessions table
create table if not exists public.user_sessions (
  session_id text primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  device_id text not null,
  device_name text,
  os_version text,
  app_version text,
  platform text,
  ip text,
  login_time timestamp with time zone default timezone('utc'::text, now()) not null,
  last_seen timestamp with time zone default timezone('utc'::text, now()) not null,
  socket_id text,
  online_status text default 'Online' check (online_status in ('Online', 'In Room', 'Speaking', 'Idle', 'Background', 'Offline'))
);

-- Enable RLS for user_sessions
alter table public.user_sessions enable row level security;

-- Create policies for user_sessions
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'user_sessions' and policyname = 'Allow select for self') then
    create policy "Allow select for self" on public.user_sessions
      for select using (auth.uid() = user_id);
  end if;
  
  if not exists (select 1 from pg_policies where tablename = 'user_sessions' and policyname = 'Allow insert/update for self') then
    create policy "Allow insert/update for self" on public.user_sessions
      for all using (auth.uid() = user_id);
  end if;
end
$$;

-- Enable Realtime for user_sessions
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'user_sessions'
    ) then
      alter publication supabase_realtime add table public.user_sessions;
    end if;
  end if;
end
$$;

-- Function: leave_all_rooms
create or replace function public.leave_all_rooms(
  p_user_id uuid,
  p_except_room_id text default null
)
returns void as $$
declare
  v_old_room record;
  v_username text;
  v_has_members boolean;
  v_new_host_id uuid;
begin
  select username into v_username from public.profiles where id = p_user_id;

  for v_old_room in
    select room_id, role
    from public.room_members
    where user_id = p_user_id and (p_except_room_id is null or room_id <> p_except_room_id)
  loop
    -- 1. Free seat in room_seats
    update public.room_seats
    set user_id = null,
        mic_status = 'muted',
        is_speaking = false
    where room_id = v_old_room.room_id and user_id = p_user_id;

    -- 2. Remove raised-hand requests
    delete from public.room_requests
    where room_id = v_old_room.room_id and user_id = p_user_id;

    -- 3. Delete from room_members
    delete from public.room_members
    where room_id = v_old_room.room_id and user_id = p_user_id;

    -- 4. Delete heartbeats
    delete from public.room_member_heartbeats
    where room_id = v_old_room.room_id and user_id = p_user_id;

    -- 5. Broadcast leave event
    insert into public.room_activity_events (room_id, event_type, user_id, username, message)
    values (v_old_room.room_id, 'leave', p_user_id, v_username, coalesce(v_username, 'Someone') || ' left the room');

    -- 6. Handle host transfer if owner disconnected/joined another room
    if exists (select 1 from public.rooms where id = v_old_room.room_id and host_id = p_user_id) then
      select exists(select 1 from public.room_members where room_id = v_old_room.room_id) into v_has_members;
      
      if v_has_members then
        select user_id into v_new_host_id
        from public.room_members
        where room_id = v_old_room.room_id
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
          update public.rooms set host_id = v_new_host_id where id = v_old_room.room_id;
          update public.room_members set role = 'Host' where room_id = v_old_room.room_id and user_id = v_new_host_id;
          select username into v_username from public.profiles where id = v_new_host_id;

          insert into public.room_activity_events (room_id, event_type, user_id, username, message)
          values (v_old_room.room_id, 'system', v_new_host_id, v_username, 'Ownership transferred to ' || coalesce(v_username, 'new host') || ' because the owner joined another room.');
        end if;
      else
        -- If no members left and it's temporary room, destroy
        if not exists (select 1 from public.rooms where id = v_old_room.room_id and is_permanent = true) then
          delete from public.rooms where id = v_old_room.room_id;
        end if;
      end if;
    end if;
  end loop;
end;
$$ language plpgsql security definer set search_path = public;

-- Trigger logic for profiles(active_room_id) change
create or replace function public.on_profile_active_room_change()
returns trigger as $$
begin
  if (OLD.active_room_id is distinct from NEW.active_room_id) then
    if NEW.active_room_id is null then
      perform public.leave_all_rooms(NEW.id);
    else
      perform public.leave_all_rooms(NEW.id, NEW.active_room_id);
    end if;
  end if;
  return NEW;
end;
$$ language plpgsql security definer;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'tr_profile_active_room_change') then
    create trigger tr_profile_active_room_change
      after update of active_room_id on public.profiles
      for each row execute function public.on_profile_active_room_change();
  end if;
end
$$;

-- Trigger logic: Invalidate other user sessions on insert (Single Device Login)
create or replace function public.on_session_insert()
returns trigger as $$
begin
  -- Set all other active sessions for that user to 'Offline'
  update public.user_sessions
  set online_status = 'Offline'
  where user_id = NEW.user_id and session_id <> NEW.session_id;

  return NEW;
end;
$$ language plpgsql security definer;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'tr_session_insert') then
    create trigger tr_session_insert
      before insert on public.user_sessions
      for each row execute function public.on_session_insert();
  end if;
end
$$;

-- Update join_room function to call leave_all_rooms
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
  -- Enforce One Room Rule
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

  -- Ban Check
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

  -- Global Ban Check
  if v_user_profile.is_banned = true then
    raise exception 'Your account is banned';
  end if;

  if v_room.host_id = v_user_id then
    v_role := 'Host';
  else
    v_role := 'Listener';
  end if;

  insert into public.room_members (room_id, user_id, role, last_heartbeat_at)
  values (p_room_id, v_user_id, v_role, now())
  on conflict (room_id, user_id) do update set role = EXCLUDED.role, last_heartbeat_at = now();

  -- Update profiles active room and presence status
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

-- Update leave_room function to clear active_room_id
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
      is_speaking = false
  where room_id = p_room_id and user_id = v_user_id;

  delete from public.room_members where room_id = p_room_id and user_id = v_user_id;

  -- Clear profiles active_room_id and reset presence to Online
  update public.profiles
  set active_room_id = null, presence_state = 'Online'
  where id = v_user_id;

  insert into public.room_activity_events (room_id, event_type, user_id, username, message)
  values (p_room_id, 'leave', v_user_id, v_username, coalesce(v_username, 'Someone') || ' left the room');

  return true;
end;
$$ language plpgsql security definer set search_path = public;
