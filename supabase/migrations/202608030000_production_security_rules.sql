-- 20 Production Level Session & Room Security Rules Migration
-- Enables single device login, session validation, atomic gifts/purchases, equip validation, and kick cooldowns.

-- 1. Ensure user_sessions schema is complete
alter table public.profiles
  add column if not exists active_session_id text,
  add column if not exists device_fingerprint text;

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

create index if not exists idx_user_sessions_user_id on public.user_sessions(user_id);
create index if not exists idx_user_sessions_status on public.user_sessions(user_id, online_status);

-- Enable RLS for user_sessions
alter table public.user_sessions enable row level security;

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

-- Realtime Publication for user_sessions and profiles
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

-- 2. Security Definer RPC: Register New Login Session (Authenticates new device & invalidates previous sessions)
create or replace function public.register_new_session(
  p_session_id text,
  p_device_id text,
  p_device_name text default null,
  p_os_version text default null,
  p_app_version text default null,
  p_platform text default null
) returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_prev_session_id text;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  -- 1. Fetch previous active session ID for logging
  select active_session_id into v_prev_session_id
  from public.profiles
  where id = v_user_id;

  -- 2. Invalidate all previous sessions for this user by marking them 'Offline'
  update public.user_sessions
  set online_status = 'Offline',
      last_seen = now()
  where user_id = v_user_id and session_id <> p_session_id;

  -- 3. Insert or update the new session record as 'Online'
  insert into public.user_sessions (
    session_id, user_id, device_id, device_name, os_version, app_version, platform, login_time, last_seen, online_status
  ) values (
    p_session_id, v_user_id, p_device_id, p_device_name, p_os_version, p_app_version, p_platform, now(), now(), 'Online'
  ) on conflict (session_id) do update set
    last_seen = now(),
    online_status = 'Online',
    device_id = EXCLUDED.device_id;

  -- 4. Update profile active_session_id to the NEW session ID (Single Source of Truth)
  update public.profiles
  set active_session_id = p_session_id,
      device_fingerprint = p_device_id,
      last_seen = to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
  where id = v_user_id;

  return jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'previous_session_id', v_prev_session_id,
    'new_session_id', p_session_id,
    'device_id', p_device_id,
    'login_time', now()
  );
end;
$$ language plpgsql security definer set search_path = public;

-- Trigger logic for compatibility on direct insert into user_sessions
create or replace function public.on_session_insert()
returns trigger as $$
begin
  update public.user_sessions
  set online_status = 'Offline',
      last_seen = now()
  where user_id = NEW.user_id and session_id <> NEW.session_id;

  update public.profiles
  set active_session_id = NEW.session_id,
      device_fingerprint = NEW.device_id,
      last_seen = to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
  where id = NEW.user_id;

  return NEW;
end;
$$ language plpgsql security definer set search_path = public;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'tr_session_insert') then
    create trigger tr_session_insert
      before insert on public.user_sessions
      for each row execute function public.on_session_insert();
  end if;
end
$$;

-- 3. RPC: Validate Active Session against latest backend session
create or replace function public.validate_active_session(
  p_user_id uuid,
  p_session_id text
) returns boolean as $$
declare
  v_current_active_session text;
  v_session_status text;
  v_is_banned boolean;
begin
  if p_user_id is null or p_session_id is null or p_session_id = '' then
    return false;
  end if;

  -- Check global account ban status
  select is_banned, active_session_id into v_is_banned, v_current_active_session
  from public.profiles where id = p_user_id;

  if v_is_banned = true then
    return false;
  end if;

  -- If profile active_session_id is not yet initialized, allow
  if v_current_active_session is null or v_current_active_session = '' then
    return true;
  end if;

  -- Strictly compare stored session ID against backend active_session_id
  if v_current_active_session <> p_session_id then
    return false;
  end if;

  -- Verify user_sessions table status
  select online_status into v_session_status
  from public.user_sessions
  where session_id = p_session_id and user_id = p_user_id;

  if v_session_status = 'Offline' then
    return false;
  end if;

  return true;
end;
$$ language plpgsql security definer set search_path = public;

-- 4. Idempotency Transactions Table for Gifts & Purchases
create table if not exists public.processed_transactions (
  transaction_id text primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  action_type text not null,
  payload jsonb,
  result jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.processed_transactions enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'processed_transactions' and policyname = 'Allow select for self') then
    create policy "Allow select for self" on public.processed_transactions
      for select using (auth.uid() = user_id);
  end if;
end
$$;

-- 5. RPC: Atomic & Idempotent Gift Sending
create or replace function public.send_room_gift(
  p_room_id text,
  p_receiver_id uuid,
  p_gift_id text,
  p_gift_name text,
  p_coin_price integer,
  p_quantity integer default 1,
  p_session_id text default null,
  p_transaction_id text default null
) returns jsonb as $$
declare
  v_sender_id uuid := auth.uid();
  v_sender_coins integer;
  v_total_cost integer;
  v_tx_record public.processed_transactions%rowtype;
  v_res jsonb;
begin
  if v_sender_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Validate active session if session_id provided
  if p_session_id is not null and not public.validate_active_session(v_sender_id, p_session_id) then
    raise exception 'Invalid or expired session. Please log in again.';
  end if;

  -- Check idempotency
  if p_transaction_id is not null then
    select * into v_tx_record from public.processed_transactions where transaction_id = p_transaction_id;
    if v_tx_record.transaction_id is not null then
      return v_tx_record.result;
    end if;
  end if;

  if p_quantity <= 0 then
    raise exception 'Invalid gift quantity';
  end if;

  v_total_cost := p_coin_price * p_quantity;

  -- Lock sender row for update to prevent race conditions & double-spending
  select coins into v_sender_coins from public.profiles where id = v_sender_id for update;

  if v_sender_coins is null or v_sender_coins < v_total_cost then
    raise exception 'Insufficient coin balance';
  end if;

  -- Deduct coins from sender balance
  update public.profiles
  set coins = coins - v_total_cost
  where id = v_sender_id;

  -- Record coin transaction in wallet ledger if exists
  if exists (select 1 from information_schema.tables where table_name = 'wallet_transactions') then
    insert into public.wallet_transactions (user_id, amount, transaction_type, description)
    values (v_sender_id, -v_total_cost, 'Gift Sent', 'Sent gift ' || p_gift_name || ' x' || p_quantity || ' in room ' || p_room_id);
  end if;

  -- Record gift activity event in room
  insert into public.room_activity_events (room_id, event_type, user_id, username, message)
  select p_room_id, 'gift', v_sender_id, p.username,
         '🎁 ' || coalesce(p.username, 'Someone') || ' sent ' || p_gift_name || ' × ' || p_quantity || ' to receiver.'
  from public.profiles p where p.id = v_sender_id;

  v_res := jsonb_build_object(
    'success', true,
    'sender_id', v_sender_id,
    'receiver_id', p_receiver_id,
    'total_cost', v_total_cost,
    'remaining_coins', (v_sender_coins - v_total_cost)
  );

  -- Store idempotency result
  if p_transaction_id is not null then
    insert into public.processed_transactions (transaction_id, user_id, action_type, result)
    values (p_transaction_id, v_sender_id, 'gift', v_res);
  end if;

  return v_res;
end;
$$ language plpgsql security definer set search_path = public;

-- 6. RPC: Atomic Store Purchase with Idempotency
create or replace function public.buy_store_item(
  p_item_id text,
  p_item_name text,
  p_category text,
  p_coin_price integer,
  p_session_id text default null,
  p_transaction_id text default null
) returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_user_coins integer;
  v_tx_record public.processed_transactions%rowtype;
  v_res jsonb;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if p_session_id is not null and not public.validate_active_session(v_user_id, p_session_id) then
    raise exception 'Invalid or expired session. Please log in again.';
  end if;

  if p_transaction_id is not null then
    select * into v_tx_record from public.processed_transactions where transaction_id = p_transaction_id;
    if v_tx_record.transaction_id is not null then
      return v_tx_record.result;
    end if;
  end if;

  select coins into v_user_coins from public.profiles where id = v_user_id for update;

  if v_user_coins is null or v_user_coins < p_coin_price then
    raise exception 'Insufficient coin balance';
  end if;

  -- Deduct coins
  update public.profiles set coins = coins - p_coin_price where id = v_user_id;

  -- Insert into user_inventory table
  if exists (select 1 from information_schema.tables where table_name = 'user_inventory') then
    insert into public.user_inventory (user_id, item_id, item_name, category, acquired_at)
    values (v_user_id, p_item_id, p_item_name, p_category, now())
    on conflict do nothing;
  end if;

  v_res := jsonb_build_object(
    'success', true,
    'item_id', p_item_id,
    'item_name', p_item_name,
    'remaining_coins', (v_user_coins - p_coin_price)
  );

  if p_transaction_id is not null then
    insert into public.processed_transactions (transaction_id, user_id, action_type, result)
    values (p_transaction_id, v_user_id, 'store_purchase', v_res);
  end if;

  return v_res;
end;
$$ language plpgsql security definer set search_path = public;

-- 7. RPC: Backend Verification Before Equipping Inventory Items
create or replace function public.equip_user_item(
  p_item_name text,
  p_category text
) returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_owns boolean := false;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if p_item_name is null or p_item_name = 'Normal' or p_item_name = 'None' or p_item_name = 'Classic Bubble' then
    v_owns := true;
  else
    if exists (select 1 from information_schema.tables where table_name = 'user_inventory') then
      select exists(
        select 1 from public.user_inventory
        where user_id = v_user_id and (item_name = p_item_name or item_id = p_item_name)
      ) into v_owns;
    else
      v_owns := true; -- Fallback if inventory table not created yet
    end if;
  end if;

  if not v_owns then
    raise exception 'You do not own this item on the server.';
  end if;

  -- Update profiles cosmetic selection depending on category
  if p_category = 'Avatar Frame' then
    update public.profiles set active_frame = p_item_name where id = v_user_id;
  elsif p_category = 'Chat Bubble' then
    update public.profiles set active_bubble = p_item_name where id = v_user_id;
  elsif p_category = 'Entry Effect' then
    update public.profiles set active_entry_effect = p_item_name where id = v_user_id;
  end if;

  return jsonb_build_object('success', true, 'equipped_item', p_item_name, 'category', p_category);
end;
$$ language plpgsql security definer set search_path = public;

-- 8. RPC: Kick Room Member with Configurable Cooldown
create or replace function public.kick_room_member(
  p_room_id text,
  p_target_user_id uuid,
  p_cooldown_seconds integer default 60
) returns jsonb as $$
declare
  v_caller_id uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_caller_role text;
  v_target_username text;
begin
  if v_caller_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_room from public.rooms where id = p_room_id;
  if v_room.id is null then
    raise exception 'Room not found';
  end if;

  -- Check caller permissions: Must be Host, Co-Host, or Moderator
  if v_room.host_id <> v_caller_id then
    select role into v_caller_role from public.room_members where room_id = p_room_id and user_id = v_caller_id;
    if v_caller_role is null or v_caller_role not in ('Host', 'Co-Host', 'Moderator') then
      raise exception 'Permission denied: Only host or moderators can kick members';
    end if;
  end if;

  select username into v_target_username from public.profiles where id = p_target_user_id;

  -- Clear seat
  update public.room_seats
  set user_id = null, mic_status = 'muted', is_speaking = false
  where room_id = p_room_id and user_id = p_target_user_id;

  -- Remove from room_members
  delete from public.room_members where room_id = p_room_id and user_id = p_target_user_id;

  -- Clear profiles active_room_id if target user's active room matches
  update public.profiles
  set active_room_id = null, presence_state = 'Online'
  where id = p_target_user_id and active_room_id = p_room_id;

  -- Insert temporary ban cooldown entry into room_bans
  insert into public.room_bans (room_id, user_id, banned_by, reason, expires_at)
  values (
    p_room_id,
    p_target_user_id,
    v_caller_id,
    'Kicked by moderator',
    now() + (p_cooldown_seconds || ' seconds')::interval
  )
  on conflict (room_id, user_id) do update
  set expires_at = EXCLUDED.expires_at, banned_by = EXCLUDED.banned_by;

  -- Broadcast kick event
  insert into public.room_activity_events (room_id, event_type, user_id, username, message)
  values (p_room_id, 'kick', p_target_user_id, v_target_username, coalesce(v_target_username, 'Member') || ' was kicked from the room.');

  return jsonb_build_object('success', true, 'kicked_user_id', p_target_user_id, 'cooldown_seconds', p_cooldown_seconds);
end;
$$ language plpgsql security definer set search_path = public;

-- 9. Fix type coercion in get_user_full_inventory_and_entitlements_rpc
create or replace function public.get_user_full_inventory_and_entitlements_rpc(
  p_user_id uuid
) returns jsonb as $$
declare
  v_vip_sub      record;
  v_novel_sub    record;
  v_profile      record;
  v_inventory    jsonb;
  v_equipped     jsonb;
  v_frame_name   text;
begin
  if p_user_id is null then
    raise exception 'get_user_full_inventory_and_entitlements_rpc: missing p_user_id';
  end if;

  select vip_level, vip_expiry, novel_level, novel_expiry, avatar_frame, showcased_badges, tag_system
  into v_profile from public.profiles where id = p_user_id;

  select level, expiry_date, status into v_vip_sub
  from public.subscriptions
  where user_id = p_user_id and membership_type = 'VIP' and status = 'Active' and expiry_date > now()
  order by level desc limit 1;

  select level, expiry_date, status into v_novel_sub
  from public.subscriptions
  where user_id = p_user_id and membership_type = 'Novel' and status = 'Active' and expiry_date > now()
  order by level desc limit 1;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', coalesce(asset_id::text, name), 'name', name, 'type', type,
    'is_equipped', is_equipped, 'asset_id', asset_id, 'created_at', created_at
  )), '[]'::jsonb) into v_inventory
  from public.user_customizations where user_id = p_user_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'type', type, 'name', name, 'asset_id', asset_id, 'path', path
  )), '[]'::jsonb) into v_equipped
  from public.user_customizations where user_id = p_user_id and is_equipped = true;

  -- Resolve active frame cleanly
  select name into v_frame_name
  from public.user_customizations
  where user_id = p_user_id and type in ('Avatar Frame', 'avatar_frame', 'profile_frame') and is_equipped = true
  limit 1;

  if v_frame_name is null or v_frame_name = '' then
    v_frame_name := coalesce(v_profile.avatar_frame, 'Normal');
  end if;

  return jsonb_build_object(
    'user_id', p_user_id,
    'vip', jsonb_build_object(
      'level',       coalesce(v_vip_sub.level, v_profile.vip_level, 0),
      'expiry_date', coalesce(v_vip_sub.expiry_date, v_profile.vip_expiry),
      'is_active',   (coalesce(v_vip_sub.level, v_profile.vip_level, 0) > 0 and coalesce(v_vip_sub.expiry_date, v_profile.vip_expiry, now()) > now())
    ),
    'novel', jsonb_build_object(
      'level',       coalesce(v_novel_sub.level, v_profile.novel_level, 0),
      'expiry_date', coalesce(v_novel_sub.expiry_date, v_profile.novel_expiry),
      'is_active',   (coalesce(v_novel_sub.level, v_profile.novel_level, 0) > 0 and coalesce(v_novel_sub.expiry_date, v_profile.novel_expiry, now()) > now())
    ),
    'profile_frame',   v_frame_name,
    'showcased_badges',coalesce(to_jsonb(v_profile.showcased_badges), '[]'::jsonb),
    'tag_system',      coalesce(v_profile.tag_system, '{}'::jsonb),
    'inventory',       v_inventory,
    'equipped',        v_equipped
  );
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function public.get_user_full_inventory_and_entitlements_rpc(uuid) to authenticated, service_role;

