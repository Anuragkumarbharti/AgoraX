-- supabase/migrations/202607120010_voice_room_system.sql
-- Backend-driven Voice Room System for Creania with readable IDs, unique usernames, and visibility policies.

-- Clean up existing tables to ensure a clean state
drop table if exists public.room_bans cascade;
drop table if exists public.room_activity_logs cascade;
drop table if exists public.room_recordings cascade;
drop table if exists public.room_polls cascade;
drop table if exists public.room_requests cascade;
drop table if exists public.room_invites cascade;
drop table if exists public.room_reports cascade;
drop table if exists public.room_gifts cascade;
drop table if exists public.room_messages cascade;
drop table if exists public.room_chat cascade;
drop table if exists public.room_members cascade;
drop table if exists public.room_settings cascade;
drop table if exists public.room_permissions cascade;
drop table if exists public.room_roles cascade;
drop table if exists public.room_events cascade;
drop table if exists public.rooms cascade;

-- Ensure communities table has username column and check constraint
alter table public.communities add column if not exists username text unique;
alter table public.communities drop constraint if exists check_community_username;
alter table public.communities add constraint check_community_username check (username ~ '^@[a-z0-9_]{3,30}$');

-- ── UNIQUE ID GENERATORS ──

create or replace function public.generate_unique_room_id() returns text as $$
declare
  v_id text;
  v_exists boolean;
begin
  loop
    v_id := 'CRN-RM-' || array_to_string(array(select substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', trunc(random()*36+1)::integer, 1) from generate_series(1,6)), '');
    select exists(select 1 from public.rooms where id = v_id) into v_exists;
    if not v_exists then
      return v_id;
    end if;
  end loop;
end;
$$ language plpgsql;

create or replace function public.generate_unique_community_id() returns text as $$
declare
  v_id text;
  v_exists boolean;
begin
  loop
    v_id := 'CRN-CM-' || array_to_string(array(select substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', trunc(random()*36+1)::integer, 1) from generate_series(1,6)), '');
    select exists(select 1 from public.communities where id = v_id) into v_exists;
    if not v_exists then
      return v_id;
    end if;
  end loop;
end;
$$ language plpgsql;

-- 1. Create room_roles table
create table public.room_roles (
  id serial primary key,
  name text unique not null,
  weight integer unique not null
);

-- 2. Create room_permissions table
create table public.room_permissions (
  role_id integer references public.room_roles(id) on delete cascade not null,
  permission_name text not null,
  is_allowed boolean default false not null,
  primary key (role_id, permission_name)
);

-- 3. Create rooms table using text primary key (Room ID)
create table public.rooms (
  id text primary key,
  name text not null,
  username text unique not null constraint check_room_username check (username ~ '^@[a-z0-9_]{3,30}$'),
  description text,
  category text not null,
  language text not null default 'English',
  tags text[] default '{}'::text[] not null,
  rules text[] default '{}'::text[] not null,
  host_id uuid references public.profiles(id) on delete cascade not null,
  status text default 'live' check (status in ('live', 'scheduled', 'ended')),
  start_time timestamp with time zone default timezone('utc'::text, now()) not null,
  end_time timestamp with time zone,
  total_members integer default 0 check (total_members >= 0),
  total_speakers integer default 0 check (total_speakers >= 0),
  total_listeners integer default 0 check (total_listeners >= 0),
  peak_members integer default 0 check (peak_members >= 0),
  visibility text default 'public' check (visibility in ('everyone', 'followers_only', 'paid_members', 'vip_only', 'password_required', 'password', 'public', 'private', 'community', 'study', 'gaming', 'music', 'podcast', 'event')),
  community_id text references public.communities(id) on delete cascade,
  recording_status text default 'inactive' check (recording_status in ('inactive', 'recording', 'paused', 'ready')),
  level_requirement integer default 1 check (level_requirement >= 1),
  vip_requirement integer default 0 check (vip_requirement >= 0),
  verification_requirement boolean default false not null,
  livekit_room_name text unique not null,
  avatar text,
  banner text,
  is_permanent boolean default false not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 4. Create room_settings table
create table public.room_settings (
  room_id text primary key references public.rooms(id) on delete cascade not null,
  is_private boolean default false not null,
  password_protected boolean default false not null,
  room_password text,
  invite_only boolean default false not null,
  max_members integer default 50 not null check (max_members > 0),
  max_speakers integer default 12 not null check (max_speakers > 0),
  allow_chat boolean default true not null,
  allow_gifts boolean default true not null,
  allow_screen_share boolean default true not null,
  allow_camera boolean default true not null,
  allow_polls boolean default true not null,
  slow_mode integer default 0 not null check (slow_mode >= 0)
);

-- 5. Create room_members table
create table public.room_members (
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  role text not null check (role in ('Host', 'Co-Host', 'Moderator', 'Speaker', 'Listener', 'Guest')) default 'Listener',
  joined_at timestamp with time zone default timezone('utc'::text, now()) not null,
  is_muted boolean default false not null,
  has_raised_hand boolean default false not null,
  primary key (room_id, user_id)
);

-- 6. Create room_chat table
create table public.room_chat (
  id uuid default gen_random_uuid() primary key,
  room_id text unique references public.rooms(id) on delete cascade not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 7. Create room_messages table
create table public.room_messages (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  content text not null,
  message_type text default 'chat' check (message_type in ('chat', 'system', 'gift', 'poll')),
  metadata jsonb default '{}'::jsonb not null,
  is_pinned boolean default false not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 8. Create room_gifts table
create table public.room_gifts (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  receiver_id uuid references public.profiles(id) on delete cascade not null,
  gift_name text not null,
  coins_value integer not null check (coins_value >= 0),
  quantity integer default 1 not null check (quantity >= 1),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 9. Create room_reports table
create table public.room_reports (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  reporter_id uuid references public.profiles(id) on delete cascade not null,
  reason text not null,
  details text,
  status text default 'pending' check (status in ('pending', 'resolved', 'dismissed')),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 10. Create room_invites table
create table public.room_invites (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  inviter_id uuid references public.profiles(id) on delete cascade not null,
  invitee_id uuid references public.profiles(id) on delete cascade not null,
  status text default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 11. Create room_requests table
create table public.room_requests (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  status text default 'pending' check (status in ('pending', 'accepted', 'rejected', 'demoted')),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 12. Create room_polls table
create table public.room_polls (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  question text not null,
  options text[] not null,
  votes jsonb default '{}'::jsonb not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 13. Create room_recordings table
create table public.room_recordings (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  recorder_id uuid references public.profiles(id) on delete cascade not null,
  recording_url text,
  duration integer check (duration >= 0),
  status text default 'recording' check (status in ('recording', 'completed', 'failed')),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 14. Create room_activity_logs table
create table public.room_activity_logs (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  action_type text not null,
  details text,
  moderator_id uuid references public.profiles(id) on delete set null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 15. Create room_bans table
create table public.room_bans (
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  banned_by uuid references public.profiles(id) on delete set null,
  reason text,
  expires_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, user_id)
);

-- 16. Create room_events table for WebRTC signaling
create table public.room_events (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  event_type text not null,
  payload jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS on all tables
alter table public.room_roles enable row level security;
alter table public.room_permissions enable row level security;
alter table public.rooms enable row level security;
alter table public.room_settings enable row level security;
alter table public.room_members enable row level security;
alter table public.room_chat enable row level security;
alter table public.room_messages enable row level security;
alter table public.room_gifts enable row level security;
alter table public.room_reports enable row level security;
alter table public.room_invites enable row level security;
alter table public.room_requests enable row level security;
alter table public.room_polls enable row level security;
alter table public.room_recordings enable row level security;
alter table public.room_activity_logs enable row level security;
alter table public.room_bans enable row level security;
alter table public.room_events enable row level security;

-- Seed room_roles
insert into public.room_roles (name, weight) values
('Host', 10),
('Co-Host', 8),
('Moderator', 6),
('Speaker', 4),
('Listener', 2),
('Guest', 1)
on conflict do nothing;

-- Seed room_permissions
-- Host permissions (All)
insert into public.room_permissions (role_id, permission_name, is_allowed)
select id, p, true from public.room_roles, unnest(array[
  'can_edit_room', 'can_delete_room', 'can_invite_users', 'can_manage_speakers', 
  'can_manage_listeners', 'can_manage_chat', 'can_manage_gifts', 'can_manage_polls', 
  'can_record_room', 'can_transfer_host', 'can_lock_room', 'can_change_settings'
]) p where name = 'Host';

-- Co-Host permissions
insert into public.room_permissions (role_id, permission_name, is_allowed)
select id, p, true from public.room_roles, unnest(array[
  'can_invite_users', 'can_manage_speakers', 'can_manage_listeners', 
  'can_manage_chat', 'can_manage_gifts', 'can_manage_polls'
]) p where name = 'Co-Host';

-- Moderator permissions
insert into public.room_permissions (role_id, permission_name, is_allowed)
select id, p, true from public.room_roles, unnest(array[
  'can_invite_users', 'can_manage_speakers', 'can_manage_listeners', 'can_manage_chat'
]) p where name = 'Moderator';

-- Speaker permissions
insert into public.room_permissions (role_id, permission_name, is_allowed)
select id, p, true from public.room_roles, unnest(array['can_invite_users']) p where name = 'Speaker';

-- Define the check_room_permission function first so we can use it in policies
create or replace function public.check_room_permission(
  p_user_id uuid,
  p_room_id text,
  p_permission text
) returns boolean as $$
declare
  v_role text;
  v_allowed boolean;
begin
  -- If user is the host of the room, they have all permissions
  if exists (select 1 from public.rooms where id = p_room_id and host_id = p_user_id) then
    return true;
  end if;

  -- Get member role
  select role into v_role from public.room_members where room_id = p_room_id and user_id = p_user_id;

  -- Default to Guest if not a member
  if v_role is null then
    v_role := 'Guest';
  end if;

  -- Get permission
  select rp.is_allowed into v_allowed
  from public.room_permissions rp
  join public.room_roles rr on rp.role_id = rr.id
  where rr.name = v_role and rp.permission_name = p_permission;

  return coalesce(v_allowed, false);
end;
$$ language plpgsql security definer;

-- ── USERNAME CROSS-TABLE UNIQUENESS TRIGGER ──

create or replace function public.check_username_global_uniqueness()
returns trigger as $$
begin
  -- If trigger is on rooms
  if tg_table_name = 'rooms' then
    if new.username is not null and exists (
      select 1 from public.communities where username = new.username
    ) then
      raise exception 'Username % is already taken by a Community', new.username;
    end if;
  -- If trigger is on communities
  elsif tg_table_name = 'communities' then
    if new.username is not null and exists (
      select 1 from public.rooms where username = new.username
    ) then
      raise exception 'Username % is already taken by a Room', new.username;
    end if;
  end if;
  return new;
end;
$$ language plpgsql;

create trigger check_rooms_username_global_uniqueness
  before insert or update on public.rooms
  for each row execute procedure public.check_username_global_uniqueness();

create trigger check_communities_username_global_uniqueness
  before insert or update on public.communities
  for each row execute procedure public.check_username_global_uniqueness();

-- ── COMMUNITY INSERT AUTO-ID TRIGGER ──

create or replace function public.before_community_insert()
returns trigger as $$
begin
  -- Generate unique community ID (e.g. CRN-CM-7H9P1L)
  if new.id is null or new.id = '' or new.id like 'comm_%' then
    new.id := public.generate_unique_community_id();
  end if;

  -- Generate default username if not provided
  if new.username is null or new.username = '' then
    new.username := '@cm_' || lower(substring(new.id from 8));
  end if;
  return new;
end;
$$ language plpgsql;

create trigger on_community_insert_generate_id
  before insert on public.communities
  for each row execute procedure public.before_community_insert();

-- ── RLS POLICIES ──

-- Roles policies
create policy "Select room_roles" on public.room_roles for select using (true);
create policy "Modify room_roles" on public.room_roles for all using (exists (select 1 from public.admins where id = auth.uid()));

-- Permissions policies
create policy "Select room_permissions" on public.room_permissions for select using (true);
create policy "Modify room_permissions" on public.room_permissions for all using (exists (select 1 from public.admins where id = auth.uid()));

-- Rooms policies (Public rooms visible to all, Private rooms only to hosts/members/invitees)
create policy "Select rooms" on public.rooms for select using (
  visibility <> 'private'
  or host_id = auth.uid()
  or exists (
    select 1 from public.room_members 
    where room_members.room_id = rooms.id and room_members.user_id = auth.uid()
  )
  or exists (
    select 1 from public.room_invites 
    where room_invites.room_id = rooms.id and room_invites.invitee_id = auth.uid() and room_invites.status = 'pending'
  )
);
create policy "Insert rooms" on public.rooms for insert with check (auth.uid() = host_id);
create policy "Update rooms" on public.rooms for update using (auth.uid() = host_id);
create policy "Delete rooms" on public.rooms for delete using (auth.uid() = host_id);

-- Room settings policies
create policy "Select settings" on public.room_settings for select using (true);
create policy "Modify settings" on public.room_settings for all using (exists (select 1 from public.rooms where rooms.id = room_settings.room_id and rooms.host_id = auth.uid()));

-- Room members policies
create policy "Select members" on public.room_members for select using (true);
create policy "Insert members" on public.room_members for insert with check (auth.uid() = user_id or exists (select 1 from public.rooms where rooms.id = room_members.room_id and rooms.host_id = auth.uid()));
create policy "Update members" on public.room_members for update using (auth.uid() = user_id or exists (select 1 from public.rooms where rooms.id = room_members.room_id and rooms.host_id = auth.uid()));
create policy "Delete members" on public.room_members for delete using (auth.uid() = user_id or exists (select 1 from public.rooms where rooms.id = room_members.room_id and rooms.host_id = auth.uid()));

-- Room chat policies
create policy "Select chat" on public.room_chat for select using (true);
create policy "Modify chat" on public.room_chat for all using (exists (select 1 from public.rooms where rooms.id = room_chat.room_id and rooms.host_id = auth.uid()));

-- Room messages policies
create policy "Select messages" on public.room_messages for select using (true);
create policy "Insert messages" on public.room_messages for insert with check (auth.uid() = sender_id);
create policy "Modify messages" on public.room_messages for update using (auth.uid() = sender_id or exists (select 1 from public.rooms where rooms.id = room_messages.room_id and rooms.host_id = auth.uid()));
create policy "Delete messages" on public.room_messages for delete using (auth.uid() = sender_id or exists (select 1 from public.rooms where rooms.id = room_messages.room_id and rooms.host_id = auth.uid()));

-- Room gifts policies
create policy "Select gifts" on public.room_gifts for select using (true);
create policy "Insert gifts" on public.room_gifts for insert with check (auth.uid() = sender_id);

-- Room reports policies
create policy "Select reports" on public.room_reports for select using (auth.uid() = reporter_id or exists (select 1 from public.admins where id = auth.uid()));
create policy "Insert reports" on public.room_reports for insert with check (auth.uid() = reporter_id);

-- Room invites policies
create policy "Select invites" on public.room_invites for select using (auth.uid() = inviter_id or auth.uid() = invitee_id);
create policy "Insert invites" on public.room_invites for insert with check (auth.uid() = inviter_id);
create policy "Modify invites" on public.room_invites for update using (auth.uid() = invitee_id or auth.uid() = inviter_id);

-- Room requests policies
create policy "Select requests" on public.room_requests for select using (true);
create policy "Insert requests" on public.room_requests for insert with check (auth.uid() = user_id);
create policy "Modify requests" on public.room_requests for all using (auth.uid() = user_id or public.check_room_permission(auth.uid(), room_id, 'can_manage_speakers'));

-- Room polls policies
create policy "Select polls" on public.room_polls for select using (true);
create policy "Insert polls" on public.room_polls for insert with check (public.check_room_permission(auth.uid(), room_id, 'can_manage_polls'));
create policy "Update polls" on public.room_polls for update using (true);
create policy "Delete polls" on public.room_polls for delete using (public.check_room_permission(auth.uid(), room_id, 'can_manage_polls'));

-- Room recordings policies
create policy "Select recordings" on public.room_recordings for select using (true);
create policy "Insert recordings" on public.room_recordings for insert with check (public.check_room_permission(auth.uid(), room_id, 'can_record_room'));
create policy "Modify recordings" on public.room_recordings for all using (public.check_room_permission(auth.uid(), room_id, 'can_record_room'));

-- Room activity logs policies
create policy "Select activity_logs" on public.room_activity_logs for select using (true);

-- Room bans policies
create policy "Select bans" on public.room_bans for select using (true);

-- Room events policies
create policy "Select events" on public.room_events for select using (true);
create policy "Insert events" on public.room_events for insert with check (auth.uid() = user_id);
create policy "Modify events" on public.room_events for all using (auth.uid() = user_id);

-- Re-apply policy to communities to restrict private community selection
drop policy if exists "Allow read access to all communities" on public.communities;
create policy "Select communities" on public.communities for select using (
  type = 'public' 
  or owner::text = auth.uid()::text
  or (co_owner_ids @> array[auth.uid()::text]) 
  or (admins @> array[auth.uid()::text]) 
  or (members @> array[auth.uid()::text])
);

-- ── TRIGGERS ──

-- Auto-handle new room creation (members, settings, chat, logs)
create or replace function public.handle_new_room()
returns trigger as $$
begin
  -- 1. Insert Host into members
  insert into public.room_members (room_id, user_id, role, joined_at)
  values (new.id, new.host_id, 'Host', now())
  on conflict (room_id, user_id) do update set role = 'Host';

  -- 2. Create room settings
  insert into public.room_settings (
    room_id, is_private, password_protected, room_password, invite_only, 
    max_members, max_speakers, allow_chat, allow_gifts, allow_screen_share, 
    allow_camera, allow_polls, slow_mode
  ) values (
    new.id, false, false, null, false, 50, 12, true, true, true, true, true, 0
  );

  -- 3. Create room chat
  insert into public.room_chat (room_id)
  values (new.id);

  -- 4. Log activity
  insert into public.room_activity_logs (room_id, user_id, action_type, details)
  values (new.id, new.host_id, 'create', 'Room created');

  return new;
end;
$$ language plpgsql security definer;

create trigger on_room_created
  after insert on public.rooms
  for each row execute procedure public.handle_new_room();

-- Auto-update member counts
create or replace function public.update_room_member_counts()
returns trigger as $$
declare
  v_room_id text;
  v_count integer;
begin
  if tg_op = 'INSERT' or tg_op = 'UPDATE' then
    v_room_id := new.room_id;
  else
    v_room_id := old.room_id;
  end if;

  v_count := (select count(*) from public.room_members where room_id = v_room_id);

  -- If it's a temporary room and member count is 0, delete it
  if v_count = 0 and exists (select 1 from public.rooms where id = v_room_id and is_permanent = false) then
    delete from public.rooms where id = v_room_id;
  else
    update public.rooms
    set 
      total_members = v_count,
      total_speakers = (select count(*) from public.room_members where room_id = v_room_id and role in ('Host', 'Co-Host', 'Speaker')),
      total_listeners = (select count(*) from public.room_members where room_id = v_room_id and role in ('Moderator', 'Listener', 'Guest')),
      peak_members = greatest(peak_members, v_count)
    where id = v_room_id;
  end if;

  return null;
end;
$$ language plpgsql security definer;

create trigger on_room_member_changed
  after insert or update or delete on public.room_members
  for each row execute procedure public.update_room_member_counts();

-- Prevent Host ownership transfer except by current Host
create or replace function public.check_host_transfer()
returns trigger as $$
begin
  if old.host_id is distinct from new.host_id then
    if auth.uid() <> old.host_id then
      raise exception 'Only the current Host can transfer room ownership';
    end if;
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger on_host_transfer
  before update on public.rooms
  for each row execute procedure public.check_host_transfer();

-- ── RPC BUSINESS LOGIC & SEARCH FUNCTIONS ──

-- Create room secure RPC (deducts 599 coins if permanent)
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
  v_user_id uuid;
  v_balance integer;
  v_room_id text;
  v_room_name text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Prepend '@' to p_username if not present and lowercase it
  if p_username is not null and p_username <> '' then
    p_username := lower(trim(p_username));
    if left(p_username, 1) <> '@' then
      p_username := '@' || p_username;
    end if;
  end if;

  -- Ensure wallet exists
  insert into public.wallets (id, coins_balance, inr_balance, withdrawable_balance)
  values (v_user_id, 0, 0.00, 0.00)
  on conflict (id) do nothing;

  -- Limit to 1 active permanent room owned by a user
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

    -- Deduct balance
    update public.wallets set coins_balance = coins_balance - 599 where id = v_user_id;

    -- Transaction log
    insert into public.wallet_transactions (wallet_id, amount, transaction_type, details)
    values (v_user_id, -599, 'Purchase', 'Unlocked permanent voice room');
  end if;

  -- Generate readable ID (e.g. CRN-RM-8F4K2X)
  v_room_id := public.generate_unique_room_id();

  -- Unique name for LiveKit signaling
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

-- Join room secure RPC (validates password, requirements, bans, capacity)
create or replace function public.join_room(
  p_room_id text,
  p_password text default null
) returns jsonb as $$
declare
  v_user_id uuid;
  v_room public.rooms%rowtype;
  v_settings public.room_settings%rowtype;
  v_user_profile public.profiles%rowtype;
  v_current_count integer;
  v_role text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  -- 1. Fetch room & settings
  select * into v_room from public.rooms where id = p_room_id;
  if v_room.id is null then
    raise exception 'Room not found';
  end if;
  if v_room.status = 'ended' then
    raise exception 'This room has ended';
  end if;

  select * into v_settings from public.room_settings where room_id = p_room_id;

  -- 2. Check bans
  if exists (select 1 from public.room_bans where room_id = p_room_id and user_id = v_user_id and (expires_at is null or expires_at > now())) then
    raise exception 'You are banned from this room';
  end if;

  -- 3. Check password
  if v_settings.password_protected then
    if p_password is null or v_settings.room_password <> p_password then
      raise exception 'Incorrect password';
    end if;
  end if;

  -- 4. Check profile requirements (VIP, Level, Verification)
  select * into v_user_profile from public.profiles where id = v_user_id;
  if v_user_profile.id is null then
    raise exception 'User profile not found';
  end if;

  if v_user_profile.level < v_room.level_requirement then
    raise exception 'Level requirement not met (Requires Level %)', v_room.level_requirement;
  end if;

  if v_user_profile.vip_level < v_room.vip_requirement then
    raise exception 'VIP requirement not met (Requires VIP %)', v_room.vip_requirement;
  end if;

  if v_room.verification_requirement and not coalesce(v_user_profile.verified, false) then
    raise exception 'Verification requirement not met (Requires Verified Profile)';
  end if;

  -- 5. Capacity Check (only if not Host)
  if v_room.host_id <> v_user_id then
    select count(*) into v_current_count from public.room_members where room_id = p_room_id;
    if v_current_count >= v_settings.max_members then
      raise exception 'Room has reached maximum participant capacity';
    end if;
  end if;

  -- 6. Role assignment
  if v_room.host_id = v_user_id then
    v_role := 'Host';
  else
    v_role := 'Listener';
  end if;

  -- Insert/update member
  insert into public.room_members (room_id, user_id, role, joined_at)
  values (p_room_id, v_user_id, v_role, now())
  on conflict (room_id, user_id) do update set role = EXCLUDED.role;

  -- Log Activity
  insert into public.room_activity_logs (room_id, user_id, action_type, details)
  values (p_room_id, v_user_id, 'join', 'Joined the room');

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
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return false;
  end if;

  delete from public.room_members where room_id = p_room_id and user_id = v_user_id;

  insert into public.room_activity_logs (room_id, user_id, action_type, details)
  values (p_room_id, v_user_id, 'leave', 'Left the room');

  return true;
end;
$$ language plpgsql security definer;

-- Request to speak (Raise Hand) RPC
create or replace function public.request_speak(
  p_room_id text
) returns boolean as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return false;
  end if;

  if not exists (select 1 from public.room_members where room_id = p_room_id and user_id = v_user_id) then
    raise exception 'You must be in the room to raise your hand';
  end if;

  -- Update member hand raise status
  update public.room_members set has_raised_hand = true where room_id = p_room_id and user_id = v_user_id;

  -- Insert speaker request
  insert into public.room_requests (room_id, user_id, status, created_at)
  values (p_room_id, v_user_id, 'pending', now())
  on conflict do nothing;

  -- Log Activity
  insert into public.room_activity_logs (room_id, user_id, action_type, details)
  values (p_room_id, v_user_id, 'raise_hand', 'Raised hand to speak');

  return true;
end;
$$ language plpgsql security definer;

-- Moderate speaker request (accept, reject, remove, demote) RPC
create or replace function public.moderate_request(
  p_room_id text,
  p_user_id uuid,
  p_action text
) returns boolean as $$
declare
  v_actor_id uuid;
  v_role text;
begin
  v_actor_id := auth.uid();
  if v_actor_id is null then
    return false;
  end if;

  -- Check permission
  if not public.check_room_permission(v_actor_id, p_room_id, 'can_manage_speakers') then
    raise exception 'Unauthorized to manage speakers';
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

-- Moderate user mute RPC
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

  if p_duration is not null then
    v_expiry := now() + p_duration;
  end if;

  -- Insert ban record
  insert into public.room_bans (room_id, user_id, banned_by, reason, expires_at)
  values (p_room_id, p_user_id, v_actor_id, p_reason, v_expiry)
  on conflict (room_id, user_id) do update set reason = EXCLUDED.reason, expires_at = EXCLUDED.expires_at;

  -- Kick user from members
  delete from public.room_members where room_id = p_room_id and user_id = p_user_id;

  insert into public.room_activity_logs (room_id, user_id, action_type, details, moderator_id)
  values (p_room_id, p_user_id, 'ban', 'Banned from room. Reason: ' || coalesce(p_reason, 'None'), v_actor_id);

  return true;
end;
$$ language plpgsql security definer;

-- End room RPC (Host only or admin)
create or replace function public.end_room(
  p_room_id text
) returns boolean as $$
declare
  v_actor_id uuid;
begin
  v_actor_id := auth.uid();
  if v_actor_id is null then
    return false;
  end if;

  if not exists (select 1 from public.rooms where id = p_room_id and host_id = v_actor_id) then
    if not exists (select 1 from public.admins where id = v_actor_id) then
      raise exception 'Only the Host or an administrator can end the room';
    end if;
  end if;

  -- Update room status
  update public.rooms
  set status = 'ended', end_time = now()
  where id = p_room_id;

  -- Delete members
  delete from public.room_members where room_id = p_room_id;

  -- Log Activity
  insert into public.room_activity_logs (room_id, user_id, action_type, details)
  values (p_room_id, v_actor_id, 'end_room', 'Room ended');

  return true;
end;
$$ language plpgsql security definer;

-- Send room gift secure RPC (deducts gold coins from sender and credits receiver)
create or replace function public.send_room_gift(
  p_room_id text,
  p_receiver_id uuid,
  p_gift_name text,
  p_coins_value integer,
  p_quantity integer default 1
) returns jsonb as $$
declare
  v_sender_id uuid;
  v_sender_balance integer;
  v_total_cost integer;
  v_gift_id uuid;
begin
  v_sender_id := auth.uid();
  if v_sender_id is null then
    raise exception 'Not authenticated';
  end if;

  v_total_cost := p_coins_value * p_quantity;

  -- Fetch sender balance
  select coins_balance into v_sender_balance from public.wallets where id = v_sender_id;
  if coalesce(v_sender_balance, 0) < v_total_cost then
    raise exception 'Insufficient Gold Coins (Requires % coins)', v_total_cost;
  end if;

  -- Deduct from sender
  update public.wallets set coins_balance = coins_balance - v_total_cost where id = v_sender_id;
  insert into public.wallet_transactions (wallet_id, amount, transaction_type, details)
  values (v_sender_id, -v_total_cost, 'Purchase', 'Sent ' || p_gift_name || ' gift in voice room');

  -- Add to receiver (Host or creator)
  update public.wallets set coins_balance = coins_balance + v_total_cost where id = p_receiver_id;
  insert into public.wallet_transactions (wallet_id, amount, transaction_type, details)
  values (p_receiver_id, v_total_cost, 'Reward', 'Received ' || p_gift_name || ' gift in voice room');

  -- Record Gift
  insert into public.room_gifts (room_id, sender_id, receiver_id, gift_name, coins_value, quantity, created_at)
  values (p_room_id, v_sender_id, p_receiver_id, p_gift_name, p_coins_value, p_quantity)
  returning id into v_gift_id;

  -- Insert a system/gift message to room chat
  insert into public.room_messages (
    room_id, sender_id, content, message_type, metadata
  ) values (
    p_room_id, v_sender_id, 'gifted ' || p_gift_name || ' to ' || (select username from public.profiles where id = p_receiver_id), 'gift',
    jsonb_build_object('gift_name', p_gift_name, 'coins_value', p_coins_value, 'quantity', p_quantity, 'receiver_id', p_receiver_id)
  );

  return jsonb_build_object(
    'success', true,
    'gift_id', v_gift_id,
    'remaining_balance', v_sender_balance - v_total_cost
  );
end;
$$ language plpgsql security definer;

-- Change member role (Host only) RPC
create or replace function public.change_member_role(
  p_room_id text,
  p_user_id uuid,
  p_new_role text
) returns boolean as $$
declare
  v_actor_id uuid;
begin
  v_actor_id := auth.uid();
  if v_actor_id is null then
    return false;
  end if;

  -- Only Room Host can promote/demote members to roles like Co-Host/Moderator
  if not exists (select 1 from public.rooms where id = p_room_id and host_id = v_actor_id) then
    raise exception 'Only the Room Host can modify user roles';
  end if;

  if p_new_role not in ('Host', 'Co-Host', 'Moderator', 'Speaker', 'Listener', 'Guest') then
    raise exception 'Invalid role: %', p_new_role;
  end if;

  update public.room_members set role = p_new_role where room_id = p_room_id and user_id = p_user_id;

  insert into public.room_activity_logs (room_id, user_id, action_type, details, moderator_id)
  values (p_room_id, p_user_id, 'role_change', 'Role changed to ' || p_new_role, v_actor_id);

  return true;
end;
$$ language plpgsql security definer;

-- Get room permissions for a user in a room RPC
create or replace function public.get_room_permissions(
  p_room_id text
) returns jsonb as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return '{}'::jsonb;
  end if;

  return jsonb_build_object(
    'can_edit_room', public.check_room_permission(v_user_id, p_room_id, 'can_edit_room'),
    'can_delete_room', public.check_room_permission(v_user_id, p_room_id, 'can_delete_room'),
    'can_invite_users', public.check_room_permission(v_user_id, p_room_id, 'can_invite_users'),
    'can_manage_speakers', public.check_room_permission(v_user_id, p_room_id, 'can_manage_speakers'),
    'can_manage_listeners', public.check_room_permission(v_user_id, p_room_id, 'can_manage_listeners'),
    'can_manage_chat', public.check_room_permission(v_user_id, p_room_id, 'can_manage_chat'),
    'can_manage_gifts', public.check_room_permission(v_user_id, p_room_id, 'can_manage_gifts'),
    'can_manage_polls', public.check_room_permission(v_user_id, p_room_id, 'can_manage_polls'),
    'can_record_room', public.check_room_permission(v_user_id, p_room_id, 'can_record_room'),
    'can_transfer_host', public.check_room_permission(v_user_id, p_room_id, 'can_transfer_host'),
    'can_lock_room', public.check_room_permission(v_user_id, p_room_id, 'can_lock_room'),
    'can_change_settings', public.check_room_permission(v_user_id, p_room_id, 'can_change_settings')
  );
end;
$$ language plpgsql security definer;

-- ── SEARCH FUNCTIONS (RLS RESPECTED BY SECURITY INVOKER) ──

create or replace function public.search_rooms(p_query text)
returns setof public.rooms as $$
begin
  return query
  select * from public.rooms
  where (
    name ilike '%' || p_query || '%'
    or username ilike '%' || p_query || '%'
    or id::text = p_query
  )
  order by name;
end;
$$ language plpgsql security invoker;

create or replace function public.search_communities(p_query text)
returns setof public.communities as $$
begin
  return query
  select * from public.communities
  where (
    name ilike '%' || p_query || '%'
    or username ilike '%' || p_query || '%'
    or id::text = p_query
  )
  order by name;
end;
$$ language plpgsql security invoker;
