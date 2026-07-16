-- 202607090007_voice_rooms_rpc.sql
-- Voice room RPC operations and user weighting helpers

create or replace function public.get_user_role_weight(
  p_user_id uuid,
  p_room_id text
)
returns integer as $$
declare
  v_role text;
  v_host_id uuid;
begin
  select host_id into v_host_id from public.rooms where id = p_room_id;
  if v_host_id = p_user_id then
    return 10;
  end if;

  select role into v_role from public.room_members where room_id = p_room_id and user_id = p_user_id;
  if v_role is null then
    return 1;
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

-- Create room RPC
create or replace function public.create_room(
  p_name text,
  p_username text,
  p_description text,
  p_category text,
  p_country text,
  p_language text,
  p_tags text[],
  p_rules text[],
  p_entry_permission text,
  p_avatar text,
  p_banner text,
  p_is_permanent boolean
) returns text as $$
declare
  v_user_id uuid := auth.uid();
  v_room_id text;
  v_room_name text;
  v_balance integer;
begin
  if v_user_id is null then
    raise exception 'Unauthenticated';
  end if;

  if p_username is not null and p_username <> '' then
    p_username := lower(trim(p_username));
    if left(p_username, 1) <> '@' then
      p_username := '@' || p_username;
    end if;
  end if;

  if p_is_permanent and exists (
    select 1 from public.rooms 
    where host_id = v_user_id 
      and is_permanent = true 
      and status in ('live', 'scheduled')
  ) then
    raise exception 'You can only own one active permanent voice room at a time';
  end if;

  if p_is_permanent then
    select coins_balance into v_balance from public.wallets where id = v_user_id;
    if coalesce(v_balance, 0) < 599 then
      raise exception 'Insufficient balance: permanent rooms cost 599 gold coins';
    end if;

    update public.wallets set coins_balance = coins_balance - 599 where id = v_user_id;
    insert into public.wallet_transactions (wallet_id, amount, transaction_type, details)
    values (v_user_id, -599, 'Purchase', 'Unlocked permanent voice room');
  end if;

  v_room_id := public.generate_unique_room_id();
  v_room_name := 'room_' || encode(gen_random_bytes(6), 'hex');

  insert into public.rooms (
    id, name, username, description, category, language, tags, rules, host_id, status,
    visibility, recording_status, level_requirement, vip_requirement,
    verification_requirement, livekit_room_name, avatar, banner, is_permanent
  ) values (
    v_room_id, p_name, p_username, p_description, p_category, p_language, p_tags, p_rules, v_user_id, 'live',
    p_entry_permission, 'inactive', 1, 0, false, v_room_name, p_avatar, p_banner, p_is_permanent
  );

  return v_room_id;
end;
$$ language plpgsql security definer;

-- Join room RPC
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

  insert into public.room_members (room_id, user_id, role)
  values (p_room_id, v_user_id, v_role)
  on conflict (room_id, user_id) do update set role = EXCLUDED.role;

  insert into public.room_activity_events (room_id, event_type, user_id, username, message)
  values (p_room_id, 'join', v_user_id, v_user_profile.username, v_user_profile.username || ' joined the room');

  return jsonb_build_object(
    'success', true,
    'role', v_role,
    'livekit_room_name', v_room.livekit_room_name
  );
end;
$$ language plpgsql security definer;

-- Leave room RPC
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
  set user_id = null
  where room_id = p_room_id and user_id = v_user_id;

  delete from public.room_members where room_id = p_room_id and user_id = v_user_id;

  insert into public.room_activity_events (room_id, event_type, user_id, username, message)
  values (p_room_id, 'leave', v_user_id, v_username, coalesce(v_username, 'Someone') || ' left the room');

  return true;
end;
$$ language plpgsql security definer;

-- Request speak RPC
create or replace function public.request_speak(
  p_room_id text,
  p_raise boolean
) returns boolean as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return false;
  end if;

  update public.room_members 
  set has_raised_hand = p_raise 
  where room_id = p_room_id and user_id = v_user_id;

  if p_raise then
    insert into public.room_requests (room_id, user_id, status)
    values (p_room_id, v_user_id, 'pending')
    on conflict (room_id, user_id) do update set status = 'pending';
  else
    delete from public.room_requests where room_id = p_room_id and user_id = v_user_id;
  end if;

  return true;
end;
$$ language plpgsql security definer;

-- Moderate speak request RPC
create or replace function public.moderate_request(
  p_room_id text,
  p_user_id uuid,
  p_accept boolean
) returns boolean as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null then
    return false;
  end if;

  if not public.check_room_permission(v_actor_id, p_room_id, 'can_manage_speakers') then
    raise exception 'Unauthorized to moderate speakers';
  end if;

  if p_accept then
    update public.room_requests set status = 'accepted' where room_id = p_room_id and user_id = p_user_id;
    update public.room_members set role = 'Speaker', has_raised_hand = false where room_id = p_room_id and user_id = p_user_id;
  else
    update public.room_requests set status = 'rejected' where room_id = p_room_id and user_id = p_user_id;
    update public.room_members set has_raised_hand = false where room_id = p_room_id and user_id = p_user_id;
  end if;

  return true;
end;
$$ language plpgsql security definer;

-- Change member role RPC
create or replace function public.change_member_role(
  p_room_id text,
  p_user_id uuid,
  p_new_role text
) returns boolean as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null then
    return false;
  end if;

  if public.get_user_role_weight(v_actor_id, p_room_id) <= public.get_user_role_weight(p_user_id, p_room_id) then
    raise exception 'Unauthorized: Target has equal or higher privilege';
  end if;

  update public.room_members set role = p_new_role where room_id = p_room_id and user_id = p_user_id;
  return true;
end;
$$ language plpgsql security definer;

-- End room RPC
create or replace function public.end_room(
  p_room_id text
) returns boolean as $$
declare
  v_actor_id uuid := auth.uid();
  v_host_id uuid;
begin
  select host_id into v_host_id from public.rooms where id = p_room_id;
  if v_actor_id <> v_host_id then
    raise exception 'Only the Host can end the room session';
  end if;

  update public.rooms
  set status = 'ended',
      end_time = now()
  where id = p_room_id;

  update public.room_seats set user_id = null where room_id = p_room_id;

  insert into public.room_activity_events (room_id, event_type, message)
  values (p_room_id, 'end_room', 'The host has ended the room session');

  return true;
end;
$$ language plpgsql security definer;

-- Moderate user mute RPC
create or replace function public.moderate_user_mute(
  p_room_id text,
  p_user_id uuid,
  p_mute boolean
) returns boolean as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null then
    return false;
  end if;

  if not public.check_room_permission(v_actor_id, p_room_id, 'can_manage_speakers') then
    raise exception 'Unauthorized to mute speakers';
  end if;

  if public.get_user_role_weight(v_actor_id, p_room_id) <= public.get_user_role_weight(p_user_id, p_room_id) then
    raise exception 'Unauthorized: Target has equal or higher privilege';
  end if;

  update public.room_members set is_muted = p_mute where room_id = p_room_id and user_id = p_user_id;

  insert into public.room_activity_logs (room_id, user_id, action_type, details, moderator_id)
  values (p_room_id, p_user_id, case when p_mute then 'mute' else 'unmute' end, 'User muted/unmuted state updated', v_actor_id);

  return true;
end;
$$ language plpgsql security definer;

-- Moderate user kick RPC
create or replace function public.moderate_user_kick(
  p_room_id text,
  p_user_id uuid
) returns boolean as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null then
    return false;
  end if;

  if not public.check_room_permission(v_actor_id, p_room_id, 'can_manage_listeners') then
    raise exception 'Unauthorized to kick users';
  end if;

  if public.get_user_role_weight(v_actor_id, p_room_id) <= public.get_user_role_weight(p_user_id, p_room_id) then
    raise exception 'Unauthorized: Target has equal or higher privilege';
  end if;

  delete from public.room_members where room_id = p_room_id and user_id = p_user_id;

  insert into public.room_activity_logs (room_id, user_id, action_type, details, moderator_id)
  values (p_room_id, p_user_id, 'kick', 'Kicked from room', v_actor_id);

  return true;
end;
$$ language plpgsql security definer;

-- Moderate user ban RPC
create or replace function public.moderate_user_ban(
  p_room_id text,
  p_user_id uuid,
  p_reason text,
  p_duration interval default null
) returns boolean as $$
declare
  v_actor_id uuid := auth.uid();
  v_expiry timestamp with time zone;
begin
  if v_actor_id is null then
    return false;
  end if;

  if not public.check_room_permission(v_actor_id, p_room_id, 'can_manage_listeners') then
    raise exception 'Unauthorized to ban users';
  end if;

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

-- Moderate user speak application RPC
create or replace function public.moderate_user_request(
  p_room_id text,
  p_user_id uuid,
  p_action text
) returns boolean as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null then
    return false;
  end if;

  if not public.check_room_permission(v_actor_id, p_room_id, 'can_manage_speakers') then
    raise exception 'Unauthorized to manage speakers';
  end if;

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

-- Join room seat RPC
create or replace function public.join_room_seat(
  p_room_id text,
  p_seat_index integer
)
returns void as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Unauthenticated';
  end if;

  update public.room_seats
  set user_id = null
  where room_id = p_room_id and user_id = v_user_id;

  update public.room_seats
  set user_id = v_user_id
  where room_id = p_room_id and seat_index = p_seat_index;

  update public.room_seat_gifts
  set silver_gift_count = 0
  where room_id = p_room_id and seat_index = p_seat_index;
end;
$$ language plpgsql security definer;

-- Leave room seat RPC
create or replace function public.leave_room_seat(
  p_room_id text,
  p_seat_index integer
)
returns void as $$
begin
  update public.room_seats
  set user_id = null
  where room_id = p_room_id and seat_index = p_seat_index;

  update public.room_seat_gifts
  set silver_gift_count = 0
  where room_id = p_room_id and seat_index = p_seat_index;
end;
$$ language plpgsql security definer;

-- Room searching RPC
create or replace function public.search_rooms(p_query text)
returns setof public.rooms as $$
begin
  return query
  select * from public.rooms
  where name ilike '%' || p_query || '%'
     or username ilike '%' || p_query || '%'
     or description ilike '%' || p_query || '%'
  order by total_members desc;
end;
$$ language plpgsql stable;

-- Community searching RPC
create or replace function public.search_communities(p_query text)
returns setof public.communities as $$
begin
  return query
  select * from public.communities
  where name ilike '%' || p_query || '%'
     or description ilike '%' || p_query || '%'
  order by member_count desc;
end;
$$ language plpgsql stable;
