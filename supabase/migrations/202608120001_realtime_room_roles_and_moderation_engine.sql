-- ============================================================
-- 202608120001_realtime_room_roles_and_moderation_engine.sql
-- Realtime Room Roles Assignment, Permissions & Moderation RPC Engine
-- ============================================================

-- Ensure array_distinct helper function exists
create or replace function public.array_distinct(anyarray)
returns anyarray as $$
  select array_agg(distinct elem)
  from unnest($1) as elem
$$ language sql immutable;

-- 1. Ensure host_ids, co_owner_ids, admin_ids, block_list columns exist on rooms table
alter table public.rooms 
add column if not exists host_ids text[] default '{}',
add column if not exists co_owner_ids text[] default '{}',
add column if not exists admin_ids text[] default '{}',
add column if not exists block_list text[] default '{}';

-- 2. Promote / Assign Room Role RPC
create or replace function public.promote_room_member_role(
  p_room_id text,
  p_target_user_id uuid,
  p_new_role text
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_caller_role text := 'Audience';
  v_is_room_owner boolean := false;
  v_target_role text := p_new_role;
begin
  if v_caller_id is null then
    raise exception 'Authentication required.';
  end if;

  if exists (select 1 from public.rooms where id = p_room_id) then
    v_room_id := p_room_id;
  else
    select id into v_room_id from public.rooms where username = p_room_id limit 1;
    if v_room_id is null then
      raise exception 'Room not found for ID: %', p_room_id;
    end if;
  end if;

  -- Standardize Role String
  if v_target_role in ('Co Owner', 'co-owner', 'coowner') then v_target_role := 'Co-Owner'; end if;
  if v_target_role in ('admin', 'Moderator') then v_target_role := 'Admin'; end if;
  if v_target_role in ('host', 'Host Member') then v_target_role := 'Host'; end if;

  -- Determine Caller Authority
  select (host_id = v_caller_id or room_owner = v_caller_id) into v_is_room_owner from public.rooms where id = v_room_id;
  if v_is_room_owner then
    v_caller_role := 'Creator';
  else
    select role into v_caller_role from public.room_members where room_id = v_room_id and user_id = v_caller_id;
    if v_caller_role is null or v_caller_role = '' then
      select 
        case 
          when v_caller_id::text = any(coalesce(co_owner_ids, '{}')) then 'Co-Owner'
          when v_caller_id::text = any(coalesce(admin_ids, '{}')) then 'Admin'
          when v_caller_id::text = any(coalesce(host_ids, '{}')) then 'Host'
          else 'Audience'
        end into v_caller_role
      from public.rooms where id = v_room_id;
    end if;
  end if;

  -- Permission Hierarchy Checks:
  -- Owner (Creator): can assign Co-Owner, Admin, Host
  -- Co-Owner: can assign Admin, Host (CANNOT assign Co-Owner)
  -- Admin: can assign Host (CANNOT assign Co-Owner or Admin)
  if v_caller_role in ('Creator', 'Owner') then
    if v_target_role not in ('Co-Owner', 'Admin', 'Host', 'Star Member') then
      raise exception 'Invalid target role: %', v_target_role;
    end if;
  elsif v_caller_role in ('Co-Owner', 'Co Owner') then
    if v_target_role not in ('Admin', 'Host', 'Star Member') then
      raise exception 'Co-Owners can only assign Admin or Host roles.';
    end if;
  elsif v_caller_role in ('Admin', 'Moderator') then
    if v_target_role not in ('Host') then
      raise exception 'Admins can only assign Host role.';
    end if;
  else
    raise exception 'Insufficient permissions to assign room roles.';
  end if;

  -- Enable session config for role modification
  perform set_config('app.allow_role_modification', 'true', true);

  -- 1. Insert or Update in room_assigned_roles
  insert into public.room_assigned_roles (room_id, user_id, role, assigned_by, assigned_at)
  values (v_room_id, p_target_user_id, v_target_role, v_caller_id, now())
  on conflict (room_id, user_id) do update 
  set role = v_target_role, assigned_by = v_caller_id, assigned_at = now();

  -- 2. Update arrays on public.rooms table
  if v_target_role = 'Co-Owner' then
    update public.rooms 
    set co_owner_ids = array_distinct(array_append(co_owner_ids, p_target_user_id::text)),
        admin_ids = array_remove(admin_ids, p_target_user_id::text),
        host_ids = array_remove(host_ids, p_target_user_id::text)
    where id = v_room_id;
  elsif v_target_role = 'Admin' then
    update public.rooms 
    set admin_ids = array_distinct(array_append(admin_ids, p_target_user_id::text)),
        co_owner_ids = array_remove(co_owner_ids, p_target_user_id::text),
        host_ids = array_remove(host_ids, p_target_user_id::text)
    where id = v_room_id;
  elsif v_target_role = 'Host' then
    update public.rooms 
    set host_ids = array_distinct(array_append(host_ids, p_target_user_id::text)),
        co_owner_ids = array_remove(co_owner_ids, p_target_user_id::text),
        admin_ids = array_remove(admin_ids, p_target_user_id::text)
    where id = v_room_id;
  end if;

  -- 3. Update room_members table
  insert into public.room_members (room_id, user_id, role, assigned_by, assigned_at, updated_at)
  values (v_room_id, p_target_user_id, v_target_role, v_caller_id, now(), now())
  on conflict (room_id, user_id) do update 
  set role = v_target_role, assigned_by = v_caller_id, assigned_at = now(), updated_at = now();

  return jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'new_role', v_target_role
  );
end;
$$;

-- 3. Demote / Remove Room Role RPC
create or replace function public.demote_room_member_role(
  p_room_id text,
  p_target_user_id uuid,
  p_role_to_remove text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_caller_role text := 'Audience';
  v_is_room_owner boolean := false;
  v_target_role text := p_role_to_remove;
begin
  if v_caller_id is null then
    raise exception 'Authentication required.';
  end if;

  if exists (select 1 from public.rooms where id = p_room_id) then
    v_room_id := p_room_id;
  else
    select id into v_room_id from public.rooms where username = p_room_id limit 1;
    if v_room_id is null then
      raise exception 'Room not found for ID: %', p_room_id;
    end if;
  end if;

  -- Protect Room Owner / Creator from role removal
  if p_target_user_id in (select host_id from public.rooms where id = v_room_id) or
     p_target_user_id in (select room_owner from public.rooms where id = v_room_id) then
    raise exception 'Room Owner role is protected and cannot be removed.';
  end if;

  -- Determine Caller Authority
  select (host_id = v_caller_id or room_owner = v_caller_id) into v_is_room_owner from public.rooms where id = v_room_id;
  if v_is_room_owner then
    v_caller_role := 'Creator';
  else
    select 
      case 
        when v_caller_id::text = any(coalesce(co_owner_ids, '{}')) then 'Co-Owner'
        when v_caller_id::text = any(coalesce(admin_ids, '{}')) then 'Admin'
        else 'Audience'
      end into v_caller_role
    from public.rooms where id = v_room_id;
  end if;

  -- If role_to_remove is specified, validate permission to remove it
  if v_target_role is null or v_target_role = '' then
    select role into v_target_role from public.room_assigned_roles where room_id = v_room_id and user_id = p_target_user_id;
  end if;

  if v_target_role in ('Co Owner', 'co-owner', 'coowner') then v_target_role := 'Co-Owner'; end if;
  if v_target_role in ('admin', 'Moderator') then v_target_role := 'Admin'; end if;
  if v_target_role in ('host', 'Host Member') then v_target_role := 'Host'; end if;

  -- Permission Hierarchy Checks:
  -- Owner: can remove Co-Owner, Admin, Host
  -- Co-Owner: can remove Admin, Host (CANNOT remove Co-Owner)
  -- Admin: can remove Host (CANNOT remove Admin or Co-Owner)
  if v_caller_role in ('Creator', 'Owner') then
    null;
  elsif v_caller_role in ('Co-Owner', 'Co Owner') then
    if v_target_role in ('Creator', 'Owner', 'Co-Owner', 'Co Owner') then
      raise exception 'Co-Owners cannot remove Co-Owner or Owner roles.';
    end if;
  elsif v_caller_role in ('Admin', 'Moderator') then
    if v_target_role in ('Creator', 'Owner', 'Co-Owner', 'Co Owner', 'Admin', 'Moderator') then
      raise exception 'Admins can only remove Host role.';
    end if;
  else
    raise exception 'Insufficient permissions to remove room roles.';
  end if;

  -- Enable session config to allow role deletion
  perform set_config('app.allow_role_modification', 'true', true);

  -- 1. Remove from room_assigned_roles
  delete from public.room_assigned_roles where room_id = v_room_id and user_id = p_target_user_id;

  -- 2. Remove from co_owner_ids, admin_ids, host_ids arrays on rooms table
  if v_target_role = 'Co-Owner' then
    update public.rooms set co_owner_ids = array_remove(co_owner_ids, p_target_user_id::text) where id = v_room_id;
  elsif v_target_role = 'Admin' then
    update public.rooms set admin_ids = array_remove(admin_ids, p_target_user_id::text) where id = v_room_id;
  elsif v_target_role = 'Host' then
    update public.rooms set host_ids = array_remove(host_ids, p_target_user_id::text) where id = v_room_id;
  else
    update public.rooms 
    set co_owner_ids = array_remove(co_owner_ids, p_target_user_id::text),
        admin_ids = array_remove(admin_ids, p_target_user_id::text),
        host_ids = array_remove(host_ids, p_target_user_id::text)
    where id = v_room_id;
  end if;

  -- 3. Update room_members role to Listener
  update public.room_members 
  set role = 'Audience', assigned_by = v_caller_id, updated_at = now()
  where room_id = v_room_id and user_id = p_target_user_id;

  return jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'removed_role', coalesce(v_target_role, 'All')
  );
end;
$$;

-- 4. Moderate Kick User RPC ("Remove From Room")
create or replace function public.moderate_kick_user(
  p_room_id text,
  p_target_user_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_caller_role text := 'Audience';
  v_is_room_owner boolean := false;
begin
  if v_caller_id is null then
    raise exception 'Authentication required.';
  end if;

  if exists (select 1 from public.rooms where id = p_room_id) then
    v_room_id := p_room_id;
  else
    select id into v_room_id from public.rooms where username = p_room_id limit 1;
    if v_room_id is null then
      raise exception 'Room not found for ID: %', p_room_id;
    end if;
  end if;

  -- Cannot kick Room Owner
  if p_target_user_id in (select host_id from public.rooms where id = v_room_id) or
     p_target_user_id in (select room_owner from public.rooms where id = v_room_id) then
    raise exception 'Room Owner cannot be kicked.';
  end if;

  -- Determine Caller Authority
  select (host_id = v_caller_id or room_owner = v_caller_id) into v_is_room_owner from public.rooms where id = v_room_id;
  if v_is_room_owner then
    v_caller_role := 'Creator';
  else
    select 
      case 
        when v_caller_id::text = any(coalesce(co_owner_ids, '{}')) then 'Co-Owner'
        when v_caller_id::text = any(coalesce(admin_ids, '{}')) then 'Admin'
        when v_caller_id::text = any(coalesce(host_ids, '{}')) then 'Host'
        else 'Audience'
      end into v_caller_role
    from public.rooms where id = v_room_id;
  end if;

  if v_caller_role not in ('Creator', 'Owner', 'Co-Owner', 'Co Owner', 'Admin', 'Moderator', 'Host') then
    raise exception 'Insufficient permissions to kick members.';
  end if;

  -- Remove from room_members
  delete from public.room_members where room_id = v_room_id and user_id = p_target_user_id;

  return jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'action', 'KICKED'
  );
end;
$$;

-- 5. Moderate Ban User RPC ("Ban From Room")
create or replace function public.moderate_ban_user(
  p_room_id text,
  p_target_user_id uuid,
  p_reason text default null,
  p_duration text default '24_hours'
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_caller_role text := 'Audience';
  v_is_room_owner boolean := false;
begin
  if v_caller_id is null then
    raise exception 'Authentication required.';
  end if;

  if exists (select 1 from public.rooms where id = p_room_id) then
    v_room_id := p_room_id;
  else
    select id into v_room_id from public.rooms where username = p_room_id limit 1;
    if v_room_id is null then
      raise exception 'Room not found for ID: %', p_room_id;
    end if;
  end if;

  -- Cannot ban Room Owner
  if p_target_user_id in (select host_id from public.rooms where id = v_room_id) or
     p_target_user_id in (select room_owner from public.rooms where id = v_room_id) then
    raise exception 'Room Owner cannot be banned.';
  end if;

  -- Determine Caller Authority
  select (host_id = v_caller_id or room_owner = v_caller_id) into v_is_room_owner from public.rooms where id = v_room_id;
  if v_is_room_owner then
    v_caller_role := 'Creator';
  else
    select 
      case 
        when v_caller_id::text = any(coalesce(co_owner_ids, '{}')) then 'Co-Owner'
        when v_caller_id::text = any(coalesce(admin_ids, '{}')) then 'Admin'
        when v_caller_id::text = any(coalesce(host_ids, '{}')) then 'Host'
        else 'Audience'
      end into v_caller_role
    from public.rooms where id = v_room_id;
  end if;

  if v_caller_role not in ('Creator', 'Owner', 'Co-Owner', 'Co Owner', 'Admin', 'Moderator', 'Host') then
    raise exception 'Insufficient permissions to ban members.';
  end if;

  -- Add to block_list array on public.rooms
  update public.rooms 
  set block_list = array_distinct(array_append(block_list, p_target_user_id::text))
  where id = v_room_id;

  -- Remove from room_members
  delete from public.room_members where room_id = v_room_id and user_id = p_target_user_id;

  return jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'action', 'BANNED'
  );
end;
$$;

-- 6. Moderate Unban User RPC
create or replace function public.moderate_unban_user(
  p_room_id text,
  p_target_user_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_room_id text;
begin
  if exists (select 1 from public.rooms where id = p_room_id) then
    v_room_id := p_room_id;
  else
    select id into v_room_id from public.rooms where username = p_room_id limit 1;
  end if;

  if v_room_id is not null then
    update public.rooms 
    set block_list = array_remove(block_list, p_target_user_id::text)
    where id = v_room_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'action', 'UNBANNED'
  );
end;
$$;
