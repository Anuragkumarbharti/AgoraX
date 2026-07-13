-- Add new columns to public.rooms
alter table public.rooms add column if not exists room_cover_url text;
alter table public.rooms add column if not exists updated_by uuid references public.profiles(id) on delete set null;
alter table public.rooms add column if not exists updated_at timestamp with time zone;
alter table public.rooms add column if not exists co_host_can_edit_cover boolean default false not null;
alter table public.rooms add column if not exists admin_can_edit_cover boolean default false not null;

-- Helper to get user's role weight in a room
create or replace function public.get_user_role_weight(p_user_id uuid, p_room_id text)
returns integer as $$
declare
  v_role text;
  v_host_id uuid;
begin
  select host_id into v_host_id from public.rooms where id = p_room_id;
  if v_host_id = p_user_id then
    return 10; -- Host weight is 10
  end if;

  select role into v_role from public.room_members where room_id = p_room_id and user_id = p_user_id;
  if v_role is null then
    return 1; -- Default weight for Guest/Listener
  end if;

  case v_role
    when 'Host' then return 10;
    when 'Co-Host' then return 8;
    when 'Moderator' then return 6;
    when 'Speaker' then return 4;
    when 'Listener' then return 2;
    when 'Guest' then return 1;
    else return 1;
  end case;
end;
$$ language plpgsql stable;

-- Re-implement moderate_user_mute with role weight validation
create or replace function public.moderate_user_mute(
  p_room_id text,
  p_user_id uuid,
  p_mute boolean
) returns boolean as $$
declare
  v_actor_id uuid;
begin
  v_actor_id := auth.uid();
  if v_actor_id is null then
    return false;
  end if;

  -- Check permission
  if not public.check_room_permission(v_actor_id, p_room_id, 'can_manage_speakers') then
    raise exception 'Unauthorized to mute speakers';
  end if;

  -- Verify role hierarchy: actor weight must be strictly higher than target weight
  if public.get_user_role_weight(v_actor_id, p_room_id) <= public.get_user_role_weight(p_user_id, p_room_id) then
    raise exception 'Unauthorized: Target has equal or higher privilege';
  end if;

  update public.room_members set is_muted = p_mute where room_id = p_room_id and user_id = p_user_id;

  insert into public.room_activity_logs (room_id, user_id, action_type, details, moderator_id)
  values (p_room_id, p_user_id, case when p_mute then 'mute' else 'unmute' end, 'User muted/unmuted state updated', v_actor_id);

  return true;
end;
$$ language plpgsql security definer;

-- Re-implement moderate_user_kick with role weight validation
create or replace function public.moderate_user_kick(
  p_room_id text,
  p_user_id uuid
) returns boolean as $$
declare
  v_actor_id uuid;
begin
  v_actor_id := auth.uid();
  if v_actor_id is null then
    return false;
  end if;

  -- Check permission
  if not public.check_room_permission(v_actor_id, p_room_id, 'can_manage_listeners') then
    raise exception 'Unauthorized to kick users';
  end if;

  -- Verify role hierarchy
  if public.get_user_role_weight(v_actor_id, p_room_id) <= public.get_user_role_weight(p_user_id, p_room_id) then
    raise exception 'Unauthorized: Target has equal or higher privilege';
  end if;

  delete from public.room_members where room_id = p_room_id and user_id = p_user_id;

  insert into public.room_activity_logs (room_id, user_id, action_type, details, moderator_id)
  values (p_room_id, p_user_id, 'kick', 'Kicked from room', v_actor_id);

  return true;
end;
$$ language plpgsql security definer;

-- Re-implement moderate_user_ban with role weight validation
create or replace function public.moderate_user_ban(
  p_room_id text,
  p_user_id uuid,
  p_reason text,
  p_duration interval default null
) returns boolean as $$
declare
  v_actor_id uuid;
  v_expiry timestamp with time zone;
begin
  v_actor_id := auth.uid();
  if v_actor_id is null then
    return false;
  end if;

  -- Check permission
  if not public.check_room_permission(v_actor_id, p_room_id, 'can_manage_listeners') then
    raise exception 'Unauthorized to ban users';
  end if;

  -- Verify role hierarchy
  if public.get_user_role_weight(v_actor_id, p_room_id) <= public.get_user_role_weight(p_user_id, p_room_id) then
    raise exception 'Unauthorized: Target has equal or higher privilege';
  end if;

  if p_duration is not null then
    v_expiry := now() + p_duration;
  end if;

  insert into public.room_bans (room_id, user_id, banned_by, reason, expires_at)
  values (p_room_id, p_user_id, v_actor_id, p_reason, v_expiry)
  on conflict (room_id, user_id) do update set reason = EXCLUDED.reason, expires_at = EXCLUDED.expires_at;

  delete from public.room_members where room_id = p_room_id and user_id = p_user_id;

  insert into public.room_activity_logs (room_id, user_id, action_type, details, moderator_id)
  values (p_room_id, p_user_id, 'ban', 'Banned from room. Reason: ' || coalesce(p_reason, 'None'), v_actor_id);

  return true;
end;
$$ language plpgsql security definer;

-- Re-implement moderate_user_request with role weight validation
create or replace function public.moderate_user_request(
  p_room_id text,
  p_user_id uuid,
  p_action text
) returns boolean as $$
declare
  v_actor_id uuid;
begin
  v_actor_id := auth.uid();
  if v_actor_id is null then
    return false;
  end if;

  -- Check permission
  if not public.check_room_permission(v_actor_id, p_room_id, 'can_manage_speakers') then
    raise exception 'Unauthorized to manage speakers';
  end if;

  -- Verify role hierarchy for actions (can't demote/remove someone of equal or higher weight)
  if p_action in ('remove', 'demote') then
    if public.get_user_role_weight(v_actor_id, p_room_id) <= public.get_user_role_weight(p_user_id, p_room_id) then
      raise exception 'Unauthorized: Target has equal or higher privilege';
    end if;
  end if;

  if p_action = 'accept' then
    update public.room_requests set status = 'accepted' where room_id = p_room_id and user_id = p_user_id;
    update public.room_members set role = 'Speaker', has_raised_hand = false where room_id = p_room_id and user_id = p_user_id;
    
    insert into public.room_activity_logs (room_id, user_id, action_type, details, moderator_id)
    values (p_room_id, p_user_id, 'promote_speaker', 'Speaker request accepted', v_actor_id);
    
  elsif p_action = 'reject' then
    update public.room_requests set status = 'rejected' where room_id = p_room_id and user_id = p_user_id;
    update public.room_members set has_raised_hand = false where room_id = p_room_id and user_id = p_user_id;
    
    insert into public.room_activity_logs (room_id, user_id, action_type, details, moderator_id)
    values (p_room_id, p_user_id, 'reject_speaker_request', 'Speaker request rejected', v_actor_id);

  elsif p_action = 'remove' or p_action = 'demote' then
    update public.room_requests set status = 'demoted' where room_id = p_room_id and user_id = p_user_id;
    update public.room_members set role = 'Listener', has_raised_hand = false where room_id = p_room_id and user_id = p_user_id;
    
    insert into public.room_activity_logs (room_id, user_id, action_type, details, moderator_id)
    values (p_room_id, p_user_id, 'demote_listener', 'Demoted to listener', v_actor_id);
  else
    raise exception 'Invalid action: %', p_action;
  end if;

  return true;
end;
$$ language plpgsql security definer;

-- Trigger to validate cover edit permissions and set updated_by / updated_at
create or replace function public.check_room_update_permission()
returns trigger as $$
declare
  v_actor_id uuid;
  v_role text;
begin
  v_actor_id := auth.uid();
  if v_actor_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Host can update everything
  if old.host_id = v_actor_id then
    return new;
  end if;

  -- Otherwise, verify role permission
  select role into v_role from public.room_members where room_id = old.id and user_id = v_actor_id;
  if v_role is null then
    raise exception 'Not a room member';
  end if;

  if (v_role = 'Co-Host' and old.co_host_can_edit_cover = true) or
     (v_role = 'Moderator' and old.admin_can_edit_cover = true) then
    -- Verify they ONLY changed allowed columns: avatar (cover), room_cover_url, updated_by, updated_at
    if (new.id is distinct from old.id) or
       (new.name is distinct from old.name) or
       (new.username is distinct from old.username) or
       (new.description is distinct from old.description) or
       (new.host_id is distinct from old.host_id) or
       (new.co_host_can_edit_cover is distinct from old.co_host_can_edit_cover) or
       (new.admin_can_edit_cover is distinct from old.admin_can_edit_cover) or
       (new.is_permanent is distinct from old.is_permanent)
    then
      raise exception 'Unauthorized to modify these settings';
    end if;
    
    new.updated_by := v_actor_id;
    new.updated_at := now();
    return new;
  end if;

  raise exception 'Unauthorized to edit this room';
end;
$$ language plpgsql security definer;

-- Attach trigger
drop trigger if exists check_room_update_permission_trigger on public.rooms;
create trigger check_room_update_permission_trigger
before update on public.rooms
for each row execute function public.check_room_update_permission();

-- Update policy to allow updates from Co-Host/Moderator
drop policy if exists "Update rooms" on public.rooms;
create policy "Update rooms" on public.rooms for update using (
  auth.uid() = host_id 
  or exists (
    select 1 from public.room_members 
    where room_members.room_id = rooms.id 
      and room_members.user_id = auth.uid() 
      and room_members.role in ('Co-Host', 'Moderator')
  )
);
