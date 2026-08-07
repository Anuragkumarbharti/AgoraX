-- ============================================================
-- 202608070024_permanent_room_ownership_system.sql
-- Permanent Room Ownership System (StarMaker Model)
--
-- Rules:
-- 1. Permanent Owner: The creator of a room is permanently linked via host_id/room_owner.
-- 2. No Auto Transfer: Disconnecting, logging out, offline state, or app restarts NEVER auto-transfer ownership.
-- 3. One Account = One Room: User cannot create multiple active rooms. Returns existing room if attempted.
-- 4. Database Protection: Trigger prevents host_id updates unless app.allow_ownership_transfer is set.
-- 5. Manual Transfer Only: Ownership changes ONLY via explicit transfer_room_ownership() or Super Admin.
-- 6. Audit Logging: Record all transfers in room_ownership_logs.
-- ============================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. room_ownership_logs table
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.room_ownership_logs (
  id              uuid default gen_random_uuid() primary key,
  room_id         text references public.rooms(id) on delete cascade not null,
  old_owner_id    uuid references public.profiles(id) on delete set null,
  new_owner_id    uuid references public.profiles(id) on delete set null,
  transferred_by  uuid references public.profiles(id) on delete set null,
  reason          text default 'manual_transfer',
  created_at      timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.room_ownership_logs enable row level security;

create policy "Users can view logs of rooms they own or participate in"
  on public.room_ownership_logs for select
  using (
    exists (select 1 from public.rooms where id = room_id and (host_id = auth.uid() or room_owner = auth.uid()))
    or old_owner_id = auth.uid()
    or new_owner_id = auth.uid()
    or exists (select 1 from public.admins where id = auth.uid())
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Database Protection Trigger (Immutability of host_id & room_owner)
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.prevent_auto_room_ownership_change()
returns trigger as $$
begin
  if (old.host_id is distinct from new.host_id or old.room_owner is distinct from new.room_owner) then
    if current_setting('app.allow_ownership_transfer', true) is distinct from 'true' then
      raise exception 'UNAUTHORIZED_OWNERSHIP_CHANGE: Room ownership is permanent and can only be changed via manual transfer or Super Admin.';
    end if;
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists trigger_prevent_auto_room_ownership_change on public.rooms;
create trigger trigger_prevent_auto_room_ownership_change
  before update on public.rooms
  for each row
  execute function public.prevent_auto_room_ownership_change();

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Explicit Manual Ownership Transfer RPC (with session bypass flag)
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.transfer_room_ownership(
  p_room_id text,
  p_new_owner_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_old_owner_id uuid;
begin
  if p_room_id is null or p_new_owner_id is null then
    raise exception 'INVALID_PARAMETERS: Room ID and New Owner ID are required.';
  end if;

  -- Resolve room ID
  if exists (select 1 from public.rooms where id = p_room_id) then
    v_room_id := p_room_id;
  else
    select id into v_room_id from public.rooms where username = p_room_id limit 1;
    if v_room_id is null then
      raise exception 'Room not found for ID or username: %', p_room_id;
    end if;
  end if;

  select host_id into v_old_owner_id from public.rooms where id = v_room_id;

  -- Caller check: Current Owner or Super Admin
  if v_caller_id is null or v_caller_id != v_old_owner_id then
    if not exists (select 1 from public.admins where id = v_caller_id) then
      raise exception 'Only the current room Owner or Super Admin can transfer ownership.';
    end if;
  end if;

  if p_new_owner_id = v_old_owner_id then
    raise exception 'User is already the room Owner.';
  end if;

  -- Enable temporary session config to allow updating immutable ownership fields
  perform set_config('app.allow_ownership_transfer', 'true', true);

  -- Update rooms table (sync host_id & room_owner)
  update public.rooms 
  set host_id = p_new_owner_id,
      room_owner = p_new_owner_id,
      updated_at = now() 
  where id = v_room_id;

  -- Convert old Owner -> Member in room_members
  update public.room_members 
  set role = 'Member', updated_at = now() 
  where room_id = v_room_id and user_id = v_old_owner_id;

  -- Convert new target -> Owner in room_members
  insert into public.room_members (room_id, user_id, role, assigned_by, assigned_at, updated_at)
  values (v_room_id, p_new_owner_id, 'Owner', v_caller_id, now(), now())
  on conflict (room_id, user_id) do update 
  set role = 'Owner', assigned_by = v_caller_id, assigned_at = now(), updated_at = now();

  -- Audit Log
  insert into public.room_ownership_logs (room_id, old_owner_id, new_owner_id, transferred_by, reason)
  values (v_room_id, v_old_owner_id, p_new_owner_id, v_caller_id, 'manual_transfer');

  -- Broadcast system event
  insert into public.room_activity_events (room_id, event_type, user_id, username, message)
  values (
    v_room_id,
    'system',
    p_new_owner_id,
    (select username from public.profiles where id = p_new_owner_id),
    'Room ownership was manually transferred to new owner.'
  );

  return jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'old_owner_id', v_old_owner_id,
    'new_owner_id', p_new_owner_id
  );
end;
$$;

-- Backward compatibility alias: transfer_room_host
create or replace function public.transfer_room_host(
  p_room_id text,
  p_new_host_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  return public.transfer_room_ownership(p_room_id, p_new_host_id);
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Overwrite Heartbeat Cleanup to REMOVE Auto Ownership Transfer
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.cleanup_expired_room_members()
returns void language plpgsql security definer set search_path = public as $$
declare
  v_expired record;
  v_username text;
begin
  for v_expired in 
    select room_id, user_id, role 
    from public.room_members 
    where last_heartbeat_at < (now() - interval '15 seconds')
  loop
    select username into v_username from public.profiles where id = v_expired.user_id;

    -- A. Free seat
    update public.room_seats
    set user_id = null,
        mic_status = 'muted',
        is_speaking = false
    where room_id = v_expired.room_id and user_id = v_expired.user_id;

    -- B. Remove requests
    delete from public.room_requests
    where room_id = v_expired.room_id and user_id = v_expired.user_id;

    -- C. Delete from room_members
    delete from public.room_members 
    where room_id = v_expired.room_id and user_id = v_expired.user_id;

    -- D. Delete from room_member_heartbeats
    delete from public.room_member_heartbeats
    where room_id = v_expired.room_id and user_id = v_expired.user_id;

    -- E. Broadcast leave event
    insert into public.room_activity_events (room_id, event_type, user_id, username, message, metadata)
    values (
      v_expired.room_id, 
      'leave', 
      v_expired.user_id, 
      v_username, 
      coalesce(v_username, 'Someone') || ' left the room (timeout)',
      jsonb_build_object('reason', 'timeout')
    );

    -- F. NO AUTO TRANSFER OF OWNERSHIP.
    -- The original owner stays owner permanently regardless of offline duration.
  end loop;

  -- G. Update online_members count on rooms table
  update public.rooms r
  set online_members = (
    select count(*) from public.room_members m where m.room_id = r.id
  )
  where r.status = 'live';
end;
$$;

create or replace function public.clean_expired_presences()
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.cleanup_expired_room_members();
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Overwrite leave_user_active_room to REMOVE Auto Ownership Transfer
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.leave_user_active_room(p_user_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_old_room record;
  v_username text;
begin
  if p_user_id is null then return; end if;

  select username into v_username from public.profiles where id = p_user_id;

  for v_old_room in
    select room_id from public.room_members where user_id = p_user_id
  loop
    update public.room_seats
    set user_id = null, mic_status = 'muted', is_speaking = false
    where room_id = v_old_room.room_id and user_id = p_user_id;

    delete from public.room_members
    where room_id = v_old_room.room_id and user_id = p_user_id;

    insert into public.room_activity_events (room_id, event_type, user_id, username, message)
    values (v_old_room.room_id, 'leave', p_user_id, v_username, coalesce(v_username, 'Someone') || ' left the room');

    -- NO AUTO TRANSFER OF OWNERSHIP.
    -- Ownership remains with original creator permanently.
  end loop;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Update create_arena() for One ID = One Room Policy
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.create_arena(
  p_name             text,
  p_username         text,
  p_description      text,
  p_category         text,
  p_country          text,
  p_language         text,
  p_tags             text[],
  p_rules            text[],
  p_entry_permission text,
  p_avatar           text,
  p_banner           text,
  p_creation_method  text  -- 'ticket' | 'coins' | 'level'
) returns text language plpgsql security definer set search_path = public as $$
declare
  v_user_id          uuid := auth.uid();
  v_room_id          text;
  v_livekit_name     text;
  v_balance          integer;
  v_user_level       integer;
  v_ticket_id        uuid;
  v_coins_spent      integer := 0;
  v_existing_room_id text;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: You must be logged in to create an Arena.';
  end if;

  -- ── Check: User already owns an active room ──────────────────────────────
  select id into v_existing_room_id
  from public.rooms
  where host_id = v_user_id
    and status in ('live', 'scheduled')
  limit 1;

  if v_existing_room_id is not null then
    return 'ALREADY_OWNS_ROOM:' || v_existing_room_id;
  end if;

  if p_creation_method not in ('ticket', 'coins', 'level') then
    raise exception 'INVALID_METHOD: Creation method must be ticket, coins, or level.';
  end if;

  if p_username is not null and p_username <> '' then
    p_username := lower(trim(p_username));
    if left(p_username, 1) <> '@' then
      p_username := '@' || p_username;
    end if;
  end if;

  perform pg_advisory_xact_lock(('x' || substr(md5(v_user_id::text), 1, 15))::bit(60)::bigint);

  -- ── Method validation & deductions ───────────────────────────────────────
  if p_creation_method = 'ticket' then
    select id into v_ticket_id
    from public.arena_tickets
    where user_id = v_user_id and is_consumed = false
    order by granted_at asc limit 1 for update skip locked;

    if v_ticket_id is null then
      raise exception 'NO_TICKET: You do not have any Arena Tickets.';
    end if;

    update public.arena_tickets set is_consumed = true, consumed_at = now() where id = v_ticket_id;
    v_coins_spent := 0;

  elsif p_creation_method = 'coins' then
    select gold_coins into v_balance from public.profiles where id = v_user_id for update;
    if coalesce(v_balance, 0) < 499 then
      raise exception 'INSUFFICIENT_COINS: You need at least 499 Gold Coins.';
    end if;
    update public.profiles set gold_coins = gold_coins - 499 where id = v_user_id;
    v_coins_spent := 499;

  elsif p_creation_method = 'level' then
    select level into v_user_level from public.profiles where id = v_user_id;
    if coalesce(v_user_level, 1) < 15 then
      raise exception 'LEVEL_REQUIRED: Reaching ID Level 15 unlocks free Arena creation.';
    end if;
    v_coins_spent := 0;
  end if;

  v_room_id := 'CRN-RM-' || floor(100000 + random() * 900000)::text;
  v_livekit_name := 'creania_room_' || lower(replace(v_room_id, '-', '_'));

  insert into public.rooms (
    id, name, username, description, category, language, tags, rules,
    host_id, room_owner, status, is_permanent, entry_permission, livekit_room_name,
    avatar, banner, room_cover_url, created_at, updated_at
  ) values (
    v_room_id, p_name, coalesce(p_username, '@' || lower(v_room_id)), p_description,
    p_category, p_language, coalesce(p_tags, '{}'), coalesce(p_rules, '{}'),
    v_user_id, v_user_id, 'live', true, coalesce(p_entry_permission, 'everyone'),
    v_livekit_name, p_avatar, p_banner, p_banner, now(), now()
  );

  insert into public.room_settings (room_id, welcome_message)
  values (v_room_id, 'Welcome to ' || p_name || '!')
  on conflict (room_id) do nothing;

  insert into public.room_members (room_id, user_id, role, joined_at)
  values (v_room_id, v_user_id, 'Owner', now())
  on conflict (room_id, user_id) do update set role = 'Owner';

  insert into public.arena_creation_logs (arena_id, user_id, creation_method, ticket_id, coins_spent)
  values (v_room_id, v_user_id, p_creation_method, v_ticket_id, v_coins_spent);

  return v_room_id;
end;
$$;
