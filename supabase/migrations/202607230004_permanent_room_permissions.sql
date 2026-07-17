-- 202607230004_permanent_room_permissions.sql
-- StarMaker style Permanent Room & Role Permission System updates

-- 1. Add settings & configuration columns to rooms if they do not exist
alter table public.rooms
  add column if not exists join_policy text default 'Everyone' check (join_policy in ('Everyone', 'Followers Only', 'VIP Members Only', 'Community Members Only', 'Owner Following Only', 'Invite Only', 'Password Protected')),
  add column if not exists seat_request_mode text default 'Everyone' check (seat_request_mode in ('Everyone', 'Followers Only', 'VIP Only', 'Community Members Only', 'Friends Only', 'Disabled')),
  add column if not exists chat_permission_mode text default 'Everyone' check (chat_permission_mode in ('Everyone', 'Followers Only', 'VIP Only', 'Community Members Only', 'Seat Members Only', 'Admins Only', 'Owner Only', 'Chat Disabled')),
  add column if not exists gift_permission_mode text default 'Everyone' check (gift_permission_mode in ('Everyone', 'Followers Only', 'VIP Only', 'Community Members Only')),
  add column if not exists invite_permission_mode text default 'Everyone' check (invite_permission_mode in ('Everyone', 'Admin and Above', 'Co Owner and Owner', 'Owner Only')),
  add column if not exists entry_notification_mode text default 'Everyone' check (entry_notification_mode in ('Everyone', 'VIP Only', 'Nobility Only', 'Hosts and Admins Only', 'Disabled'));

-- 2. Add is_locked and is_muted to room_seats if they do not exist
alter table public.room_seats
  add column if not exists is_locked boolean default false not null,
  add column if not exists is_muted boolean default false not null;

-- 3. Create persistent roles table
create table if not exists public.room_assigned_roles (
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  role text not null check (role in ('Co Owner', 'Admin')),
  assigned_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, user_id)
);

-- Enable RLS for room_assigned_roles
alter table public.room_assigned_roles enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'room_assigned_roles' and policyname = 'Allow select for all') then
    create policy "Allow select for all" on public.room_assigned_roles
      for select using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'room_assigned_roles' and policyname = 'Allow modification for owner') then
    create policy "Allow modification for owner" on public.room_assigned_roles
      for all using (
        exists (
          select 1 from public.rooms r
          where r.id = room_assigned_roles.room_id and r.host_id = auth.uid()
        )
      );
  end if;
end
$$;

-- Enable Realtime for room_assigned_roles
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_assigned_roles'
    ) then
      alter publication supabase_realtime add table public.room_assigned_roles;
    end if;
  end if;
end
$$;

-- 4. Create invites table
create table if not exists public.room_invites (
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  invited_by uuid references public.profiles(id) on delete cascade not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, user_id)
);

-- Enable RLS for room_invites
alter table public.room_invites enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'room_invites' and policyname = 'Allow select for invited user') then
    create policy "Allow select for invited user" on public.room_invites
      for select using (auth.uid() = user_id or auth.uid() = invited_by);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'room_invites' and policyname = 'Allow insert for hosts/admins') then
    create policy "Allow insert for hosts/admins" on public.room_invites
      for insert with check (
        exists (
          select 1 from public.room_members m
          where m.room_id = room_invites.room_id and m.user_id = auth.uid() and m.role in ('Owner', 'Co Owner', 'Admin')
        )
      );
  end if;
end
$$;

-- 5. Rewrite cleanup_expired_room_members to NEVER delete rooms or transfer ownership
create or replace function public.cleanup_expired_room_members()
returns void as $$
declare
  v_expired record;
  v_username text;
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
  end loop;
end;
$$ language plpgsql security definer set search_path = public;

-- 6. Rewrite leave_all_rooms to NEVER delete rooms or transfer ownership
create or replace function public.leave_all_rooms(
  p_user_id uuid,
  p_except_room_id text default null
)
returns void as $$
declare
  v_old_room record;
  v_username text;
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
  end loop;
end;
$$ language plpgsql security definer set search_path = public;

-- 7. Rewrite join_room to enforce Kick check and Join Permission policies
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
  v_is_follower boolean;
  v_is_following boolean;
  v_is_community_member boolean;
  v_is_invited boolean;
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

  -- A. Kick/Ban Check
  if exists (select 1 from public.room_bans where room_id = p_room_id and user_id = v_user_id and (expires_at is null or expires_at > now())) then
    raise exception 'You are kicked/banned from this room';
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

  -- B. Enforce Join Policies (StarMaker Style)
  if v_room.host_id <> v_user_id then
    if v_room.join_policy = 'Followers Only' then
      select exists (select 1 from public.connections where follower_id = v_user_id and following_id = v_room.host_id) into v_is_follower;
      if not v_is_follower then
        raise exception 'This room is Followers Only';
      end if;
    elsif v_room.join_policy = 'VIP Members Only' then
      if v_user_profile.vip_level = 0 then
        raise exception 'This room is VIP Members Only';
      end if;
    elsif v_room.join_policy = 'Community Members Only' then
      if v_room.community_id is not null then
        select exists (select 1 from public.community_memberships where community_id = v_room.community_id and user_id = v_user_id) into v_is_community_member;
        if not v_is_community_member then
          raise exception 'This room is Community Members Only';
        end if;
      end if;
    elsif v_room.join_policy = 'Owner Following Only' then
      select exists (select 1 from public.connections where follower_id = v_room.host_id and following_id = v_user_id) into v_is_following;
      if not v_is_following then
        raise exception 'This room is restricted to Owner Following only';
      end if;
    elsif v_room.join_policy = 'Invite Only' then
      select exists (select 1 from public.room_invites where room_id = p_room_id and user_id = v_user_id) into v_is_invited;
      if not v_is_invited then
        raise exception 'This room is Invite Only';
      end if;
    elsif v_room.join_policy = 'Password Protected' then
      if p_password is null or p_password <> (select room_password from public.room_settings where room_id = p_room_id limit 1) then
        raise exception 'Incorrect room password';
      end if;
    end if;
  end if;

  -- Determine role
  if v_room.host_id = v_user_id then
    v_role := 'Owner';
  else
    select role into v_role from public.room_assigned_roles where room_id = p_room_id and user_id = v_user_id;
    if v_role is null then
      v_role := 'Member';
    end if;
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

-- 8. Rewrite join_room_seat to enforce locks and reserved seats
create or replace function public.join_room_seat(
  p_room_id text,
  p_seat_index integer
)
returns void as $$
declare
  v_user_id uuid := auth.uid();
  v_role text;
  v_is_locked boolean;
  v_is_muted boolean;
  v_username text;
  v_avatar text;
  v_level integer;
begin
  if v_user_id is null then
    raise exception 'Unauthenticated';
  end if;

  select role into v_role from public.room_members where room_id = p_room_id and user_id = v_user_id;
  if v_role is null then
    raise exception 'You must join the room before sitting on a seat';
  end if;

  -- Seat 0: Owner only
  if p_seat_index = 0 then
    if v_role <> 'Owner' then
      raise exception 'Only Owner can sit on the Host seat';
    end if;
  -- Seat 1: Co-Owner only
  elsif p_seat_index = 1 then
    if v_role <> 'Co Owner' then
      raise exception 'Only Co-Owner can sit on the Co-Host seat';
    end if;
  end if;

  select is_locked, is_muted into v_is_locked, v_is_muted from public.room_seats where room_id = p_room_id and seat_index = p_seat_index;
  if v_is_locked = true then
    raise exception 'This seat is locked';
  end if;

  -- Vacate previous seat
  update public.room_seats
  set user_id = null
  where room_id = p_room_id and user_id = v_user_id;

  select username, avatar, level into v_username, v_avatar, v_level from public.profiles where id = v_user_id;

  -- Sit on the new seat
  update public.room_seats
  set user_id = v_user_id,
      username = v_username,
      avatar = v_avatar,
      level = v_level,
      mic_status = case when v_is_muted = true then 'muted' else 'unmuted' end,
      is_speaking = false
  where room_id = p_room_id and seat_index = p_seat_index;

  update public.room_seat_gifts
  set silver_gift_count = 0
  where room_id = p_room_id and seat_index = p_seat_index;
end;
$$ language plpgsql security definer set search_path = public;

-- 9. Helper RPC: assign_room_role (Promote / Demote Co Owner & Admin)
create or replace function public.assign_room_role(
  p_room_id text,
  p_target_user_id uuid,
  p_role text
)
returns void as $$
declare
  v_caller_id uuid := auth.uid();
  v_room_owner_id uuid;
begin
  select host_id into v_room_owner_id from public.rooms where id = p_room_id;
  
  if v_caller_id is null or v_caller_id <> v_room_owner_id then
    raise exception 'Only the Owner can assign roles';
  end if;

  if p_role is null or p_role = 'Member' then
    delete from public.room_assigned_roles where room_id = p_room_id and user_id = p_target_user_id;
    update public.room_seats set user_id = null, mic_status = 'muted', is_speaking = false
    where room_id = p_room_id and seat_index = 1 and user_id = p_target_user_id;
    update public.room_members set role = 'Member' where room_id = p_room_id and user_id = p_target_user_id;
  else
    if p_role <> 'Co Owner' and p_role <> 'Admin' then
      raise exception 'Invalid role. Must be Co Owner or Admin';
    end if;

    insert into public.room_assigned_roles (room_id, user_id, role)
    values (p_room_id, p_target_user_id, p_role)
    on conflict (room_id, user_id) do update set role = EXCLUDED.role;

    update public.room_members set role = p_role where room_id = p_room_id and user_id = p_target_user_id;
  end if;
end;
$$ language plpgsql security definer set search_path = public;

-- 10. Helper RPC: lock_room_seat (Locks / Unlocks seats)
create or replace function public.lock_room_seat(
  p_room_id text,
  p_seat_index integer,
  p_lock boolean
)
returns void as $$
declare
  v_caller_id uuid := auth.uid();
  v_caller_role text;
begin
  select role into v_caller_role from public.room_members where room_id = p_room_id and user_id = v_caller_id;
  
  if v_caller_role is null or (v_caller_role <> 'Owner' and v_caller_role <> 'Co Owner') then
    raise exception 'Only Owner and Co-Owner can lock/unlock seats';
  end if;

  update public.room_seats
  set is_locked = p_lock
  where room_id = p_room_id and seat_index = p_seat_index;

  if p_lock = true then
    update public.room_seats
    set user_id = null,
        mic_status = 'muted',
        is_speaking = false
    where room_id = p_room_id and seat_index = p_seat_index;
  end if;
end;
$$ language plpgsql security definer set search_path = public;

-- 11. Helper RPC: mute_room_seat (Mutes / Unmutes seats)
create or replace function public.mute_room_seat(
  p_room_id text,
  p_seat_index integer,
  p_mute boolean
)
returns void as $$
declare
  v_caller_id uuid := auth.uid();
  v_caller_role text;
begin
  select role into v_caller_role from public.room_members where room_id = p_room_id and user_id = v_caller_id;
  
  if v_caller_role is null or (v_caller_role <> 'Owner' and v_caller_role <> 'Co Owner' and v_caller_role <> 'Admin') then
    raise exception 'Only Owner, Co-Owner, and Admin can mute/unmute seats';
  end if;

  update public.room_seats
  set is_muted = p_mute
  where room_id = p_room_id and seat_index = p_seat_index;

  if p_mute = true then
    update public.room_seats
    set mic_status = 'muted',
        is_speaking = false
    where room_id = p_room_id and seat_index = p_seat_index;
  end if;
end;
$$ language plpgsql security definer set search_path = public;

-- 12. Helper RPC: kick_room_user (Supports 1, 3, 7, 15, 30 days & permanent kick durations)
create or replace function public.kick_room_user(
  p_room_id text,
  p_target_user_id uuid,
  p_duration_days integer,
  p_reason text default null
)
returns void as $$
declare
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_target_role text;
  v_expires_at timestamp with time zone;
begin
  select role into v_caller_role from public.room_members where room_id = p_room_id and user_id = v_caller_id;
  select role into v_target_role from public.room_members where room_id = p_room_id and user_id = p_target_user_id;

  if v_caller_role is null then
    raise exception 'Unauthorized';
  end if;

  if v_caller_role = 'Admin' then
    if v_target_role is not null and v_target_role <> 'Member' then
      raise exception 'Admin can only kick normal Members';
    end if;
  elsif v_caller_role <> 'Owner' and v_caller_role <> 'Co Owner' then
    raise exception 'Unauthorized to kick users';
  end if;

  if v_target_role = 'Owner' then
    raise exception 'The Owner cannot be kicked';
  end if;

  if p_duration_days > 0 then
    v_expires_at := now() + (p_duration_days * interval '1 day');
  else
    v_expires_at := null; -- Permanent ban
  end if;

  insert into public.room_bans (room_id, user_id, banned_by, reason, expires_at)
  values (p_room_id, p_target_user_id, v_caller_id, p_reason, v_expires_at)
  on conflict (room_id, user_id) do update 
  set banned_by = EXCLUDED.banned_by, reason = EXCLUDED.reason, expires_at = EXCLUDED.expires_at;

  -- Clear seat
  update public.room_seats
  set user_id = null,
      mic_status = 'muted',
      is_speaking = false
  where room_id = p_room_id and user_id = p_target_user_id;

  -- Remove from membership
  delete from public.room_members where room_id = p_room_id and user_id = p_target_user_id;

  -- Broadcast leave
  insert into public.room_activity_events (room_id, event_type, user_id, message)
  values (p_room_id, 'leave', p_target_user_id, 'Kicked from room');
end;
$$ language plpgsql security definer set search_path = public;

-- 13. Helper RPC: invite_room_user (Enforces invite policies)
create or replace function public.invite_room_user(
  p_room_id text,
  p_target_user_id uuid
)
returns void as $$
declare
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_room public.rooms%rowtype;
  v_allowed boolean := false;
begin
  select * into v_room from public.rooms where id = p_room_id;
  if v_room.id is null then
    raise exception 'Room not found';
  end if;

  select role into v_caller_role from public.room_members where room_id = p_room_id and user_id = v_caller_id;

  if v_caller_id = v_room.host_id then
    v_allowed := true;
  elsif v_room.invite_permission_mode = 'Everyone' then
    v_allowed := true;
  elsif v_room.invite_permission_mode = 'Admin and Above' and v_caller_role in ('Owner', 'Co Owner', 'Admin') then
    v_allowed := true;
  elsif v_room.invite_permission_mode = 'Co Owner and Owner' and v_caller_role in ('Owner', 'Co Owner') then
    v_allowed := true;
  end if;

  if not v_allowed then
    raise exception 'You do not have permission to invite users to this room';
  end if;

  insert into public.room_invites (room_id, user_id, invited_by)
  values (p_room_id, p_target_user_id, v_caller_id)
  on conflict (room_id, user_id) do nothing;
end;
$$ language plpgsql security definer set search_path = public;
