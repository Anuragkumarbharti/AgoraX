-- ============================================================
-- 202608070025_permanent_room_roles_and_task_retention.sql
-- Permanent Room Roles, Tasks, & Progress Retention System
--
-- Rules:
-- 1. Permanent Assigned Roles: Co-Owner, Admin, Star Member roles are permanently saved on public.room_assigned_roles & public.rooms.
-- 2. No Role Stripping: Disconnecting, leaving, or app restarts NEVER strip assigned roles.
-- 3. Auto-Role Restoration: Rejoining a room automatically restores assigned Co-Owner/Admin/Star Member roles.
-- 4. Room Tasks & Progress Retention: Dual progress, daily tasks, AP/VP points, room XP, and room level are 100% bound to room_id.
-- ============================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Database Protection Trigger for room_assigned_roles
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.prevent_auto_room_assigned_role_deletion()
returns trigger as $$
begin
  if (TG_OP = 'DELETE') then
    if current_setting('app.allow_role_modification', true) is distinct from 'true' then
      raise exception 'UNAUTHORIZED_ROLE_DELETION: Assigned room roles can only be removed via demote_room_member_role() or transfer_room_ownership().';
    end if;
  end if;
  return old;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists trigger_prevent_auto_room_assigned_role_deletion on public.room_assigned_roles;
create trigger trigger_prevent_auto_room_assigned_role_deletion
  before delete on public.room_assigned_roles
  for each row
  execute function public.prevent_auto_room_assigned_role_deletion();

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Synchronized promote_room_member_role & demote_room_member_role RPCs
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.promote_room_member_role(
  p_room_id text,
  p_target_user_id uuid,
  p_new_role text
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_caller_role text := 'Visitor';
  v_is_room_owner boolean := false;
  v_limits record;
  v_current_count int := 0;
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

  select (host_id = v_caller_id or room_owner = v_caller_id) into v_is_room_owner from public.rooms where id = v_room_id;
  select role into v_caller_role from public.room_members where room_id = v_room_id and user_id = v_caller_id;

  if v_is_room_owner then v_caller_role := 'Creator'; end if;
  if p_new_role = 'Co Owner' then p_new_role := 'Co-Owner'; end if;

  -- Authority Validation
  if v_caller_role in ('Creator', 'Owner') then
    if p_new_role not in ('Co-Owner', 'Admin', 'Star Member') then
      raise exception 'Invalid target role promotion: %', p_new_role;
    end if;
  elsif v_caller_role in ('Co-Owner', 'Co Owner') then
    if p_new_role not in ('Admin', 'Star Member') then
      raise exception 'Co-Owners can only promote members to Admin or Star Member.';
    end if;
  else
    raise exception 'Insufficient permissions to promote members.';
  end if;

  -- Enable session config for role modification
  perform set_config('app.allow_role_modification', 'true', true);

  -- 1. Insert or Update in room_assigned_roles
  insert into public.room_assigned_roles (room_id, user_id, role, assigned_by, assigned_at)
  values (v_room_id, p_target_user_id, p_new_role, v_caller_id, now())
  on conflict (room_id, user_id) do update 
  set role = p_new_role, assigned_by = v_caller_id, assigned_at = now();

  -- 2. Update co_owner_ids, admin_ids, star_member_ids arrays on rooms table
  if p_new_role = 'Co-Owner' then
    update public.rooms 
    set co_owner_ids = array_distinct(array_append(co_owner_ids, p_target_user_id::text)),
        admin_ids = array_remove(admin_ids, p_target_user_id::text),
        star_member_ids = array_remove(star_member_ids, p_target_user_id::text)
    where id = v_room_id;
  elsif p_new_role = 'Admin' then
    update public.rooms 
    set admin_ids = array_distinct(array_append(admin_ids, p_target_user_id::text)),
        co_owner_ids = array_remove(co_owner_ids, p_target_user_id::text),
        star_member_ids = array_remove(star_member_ids, p_target_user_id::text)
    where id = v_room_id;
  elsif p_new_role = 'Star Member' then
    update public.rooms 
    set star_member_ids = array_distinct(array_append(star_member_ids, p_target_user_id::text)),
        co_owner_ids = array_remove(co_owner_ids, p_target_user_id::text),
        admin_ids = array_remove(admin_ids, p_target_user_id::text)
    where id = v_room_id;
  end if;

  -- 3. Update active room_members record if online
  insert into public.room_members (room_id, user_id, role, assigned_by, assigned_at, updated_at)
  values (v_room_id, p_target_user_id, p_new_role, v_caller_id, now(), now())
  on conflict (room_id, user_id) do update 
  set role = p_new_role, assigned_by = v_caller_id, assigned_at = now(), updated_at = now();

  return jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'new_role', p_new_role
  );
end;
$$;

create or replace function public.demote_room_member_role(
  p_room_id text,
  p_target_user_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_caller_role text := 'Visitor';
  v_target_role text := 'Visitor';
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

  select (host_id = v_caller_id or room_owner = v_caller_id) into v_is_room_owner from public.rooms where id = v_room_id;
  select role into v_caller_role from public.room_members where room_id = v_room_id and user_id = v_caller_id;

  if v_is_room_owner then v_caller_role := 'Creator'; end if;

  if p_target_user_id in (select host_id from public.rooms where id = v_room_id) then
    raise exception 'Room Creator cannot be demoted.';
  end if;

  select role into v_target_role from public.room_assigned_roles where room_id = v_room_id and user_id = p_target_user_id;

  if v_caller_role in ('Creator', 'Owner') then
    null;
  elsif v_caller_role in ('Co-Owner', 'Co Owner') then
    if v_target_role in ('Creator', 'Owner', 'Co-Owner', 'Co Owner') then
      raise exception 'Co-Owners can only demote Admins and Star Members.';
    end if;
  else
    raise exception 'Insufficient permissions to demote members.';
  end if;

  -- Enable session config to allow role deletion
  perform set_config('app.allow_role_modification', 'true', true);

  -- 1. Remove from room_assigned_roles
  delete from public.room_assigned_roles where room_id = v_room_id and user_id = p_target_user_id;

  -- 2. Remove from co_owner_ids, admin_ids, star_member_ids arrays on rooms table
  update public.rooms 
  set co_owner_ids = array_remove(co_owner_ids, p_target_user_id::text),
      admin_ids = array_remove(admin_ids, p_target_user_id::text),
      star_member_ids = array_remove(star_member_ids, p_target_user_id::text)
  where id = v_room_id;

  -- 3. Update room_members role to Listener
  update public.room_members 
  set role = 'Listener', assigned_by = v_caller_id, updated_at = now()
  where room_id = v_room_id and user_id = p_target_user_id;

  return jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'new_role', 'Listener'
  );
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Update ultra_fast_room_join_rpc to Auto-Restore Permanent Assigned Roles
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.ultra_fast_room_join_rpc(
  p_room_id text,
  p_user_id uuid default null,
  p_password text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_caller_id uuid := coalesce(p_user_id, auth.uid());
  v_room record;
  v_room_json jsonb;
  v_host_id uuid;
  v_room_owner_id uuid;
  v_host_profile record;
  v_caller_profile record;
  v_role text := 'Listener';
  v_is_owner boolean := false;
  v_is_co_owner boolean := false;
  v_is_admin boolean := false;
  v_assigned_role text;
  v_seats jsonb := '[]'::jsonb;
  v_stats jsonb := '{}'::jsonb;
  v_room_id text;
begin
  if v_caller_id is null then
    return jsonb_build_object('join_allowed', false, 'reason', 'UNAUTHENTICATED');
  end if;

  select * into v_room from public.rooms where id = p_room_id or username = p_room_id limit 1;
  if v_room is null then
    return jsonb_build_object('join_allowed', false, 'reason', 'ROOM_NOT_FOUND');
  end if;

  v_room_id := v_room.id;
  v_room_json := to_jsonb(v_room);

  begin v_host_id := (v_room_json->>'host_id')::uuid; exception when others then v_host_id := null; end;
  begin v_room_owner_id := (v_room_json->>'room_owner')::uuid; exception when others then v_room_owner_id := null; end;

  -- 1. Fetch Host & Caller Profiles
  if v_host_id is not null then
    select id, username, coalesce(avatar_url, profile_photo, '') as avatar, gender, level, vip_level 
    into v_host_profile from public.profiles where id = v_host_id;
  end if;

  select id, username, coalesce(avatar_url, profile_photo, '') as avatar, gender, level, vip_level 
  into v_caller_profile from public.profiles where id = v_caller_id;

  -- 2. Resolve User Role in Room (Check Owner -> Assigned Roles -> Arrays -> room_members)
  if (v_host_id is not null and v_host_id = v_caller_id) or (v_room_owner_id is not null and v_room_owner_id = v_caller_id) then
    v_role := 'Owner';
    v_is_owner := true;
  else
    -- Check permanent assigned roles table
    select role into v_assigned_role from public.room_assigned_roles where room_id = v_room_id and user_id = v_caller_id;

    if v_assigned_role is not null then
      v_role := v_assigned_role;
    elsif v_caller_id::text = any(coalesce(v_room.co_owner_ids, '{}')) then
      v_role := 'Co-Owner';
    elsif v_caller_id::text = any(coalesce(v_room.admin_ids, '{}')) then
      v_role := 'Admin';
    elsif v_caller_id::text = any(coalesce(v_room.star_member_ids, '{}')) then
      v_role := 'Star Member';
    else
      select role into v_assigned_role from public.room_members where room_id = v_room_id and user_id = v_caller_id;
      if v_assigned_role is not null then
        v_role := v_assigned_role;
      end if;
    end if;

    if v_role is null or v_role = 'Audience' then 
      v_role := 'Listener'; 
    end if;

    if v_role in ('Co-Owner', 'Co Owner') then v_is_co_owner := true; end if;
    if v_role = 'Admin' then v_is_admin := true; end if;
  end if;

  -- 3. Password Check
  if v_room.entry_permission = 'password' or v_room.visibility = 'password_required' then
    if not (v_is_owner or v_is_co_owner or v_is_admin) then
      if p_password is null or v_room.room_password is distinct from p_password then
        return jsonb_build_object(
          'join_allowed', false,
          'reason', 'PASSWORD_REQUIRED',
          'room_name', v_room.name
        );
      end if;
    end if;
  end if;

  -- 4. Upsert active member with resolved permanent role
  insert into public.room_members (room_id, user_id, role, joined_at, last_heartbeat_at)
  values (v_room_id, v_caller_id, v_role, now(), now())
  on conflict (room_id, user_id) do update 
  set role = v_role, last_heartbeat_at = now();

  -- 5. Fetch seats info
  select jsonb_agg(to_jsonb(s)) into v_seats
  from (
    select seat_index, user_id, mic_status, is_speaking, is_locked, seat_name
    from public.room_seats where room_id = v_room_id order by seat_index asc
  ) s;

  return jsonb_build_object(
    'join_allowed', true,
    'room_id', v_room_id,
    'role', v_role,
    'is_owner', v_is_owner,
    'is_co_owner', v_is_co_owner,
    'is_admin', v_is_admin,
    'host_profile', to_jsonb(v_host_profile),
    'caller_profile', to_jsonb(v_caller_profile),
    'seats', coalesce(v_seats, '[]'::jsonb),
    'room', v_room_json
  );
end;
$$;
