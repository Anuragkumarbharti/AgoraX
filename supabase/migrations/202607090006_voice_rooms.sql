-- 202607090006_voice_rooms.sql
-- Voice rooms tables, settings, members, moderators, seats, sync triggers, RLS, and realtime channels

create table public.rooms (
  id text primary key,
  name text not null,
  room_name text,
  username text unique not null constraint check_room_username check (username ~ '^@[a-z0-9_]{3,30}$'),
  description text,
  category text not null,
  language text not null default 'English',
  tags text[] default '{}'::text[] not null,
  rules text[] default '{}'::text[] not null,
  host_id uuid references public.profiles(id) on delete cascade not null,
  room_owner uuid references public.profiles(id),
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
  room_banner text,
  is_permanent boolean default false not null,
  room_cover_url text,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  co_host_can_edit_cover boolean default false not null,
  admin_can_edit_cover boolean default false not null,
  room_level integer default 1 not null,
  room_xp integer default 0 not null,
  today_room_xp integer default 0 not null,
  online_members integer default 0 not null,
  total_room_gifts integer default 0 not null,
  today_room_gifts integer default 0 not null,
  total_room_stars integer default 0 not null,
  today_room_stars integer default 0 not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.room_settings (
  room_id text primary key references public.rooms(id) on delete cascade not null,
  is_private boolean default false not null,
  password_protected boolean default false not null,
  room_password text,
  chat_enabled boolean default true not null,
  mic_for_all boolean default false not null,
  allow_request_speak boolean default true not null,
  bg_image text,
  theme_color text,
  welcome_message text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.room_members (
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  role text default 'Listener' check (role in ('Host', 'Co-Host', 'Moderator', 'Speaker', 'Listener', 'Guest')),
  is_muted boolean default false not null,
  has_raised_hand boolean default false not null,
  joined_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, user_id)
);

create table public.room_moderators (
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  assigned_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, user_id)
);

create table public.room_messages (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  content text not null,
  message_type text default 'text' check (message_type in ('text', 'system', 'gift', 'banner')),
  metadata jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.room_seats (
  room_id text references public.rooms(id) on delete cascade not null,
  seat_index integer not null check (seat_index between 0 and 9),
  role text default 'Listener' check (role in ('Host', 'Co-Host', 'Speaker', 'Listener')),
  user_id uuid references public.profiles(id) on delete set null,
  seat_number integer,
  avatar text,
  avatar_frame text,
  username text,
  level integer,
  noble_level integer,
  vip_level integer,
  mic_status text default 'unmuted' not null,
  is_speaking boolean default false not null,
  seat_total_gifts integer default 0 not null,
  seat_total_stars integer default 0 not null,
  last_gift_time timestamp with time zone,
  primary key (room_id, seat_index)
);

create table public.room_seat_gifts (
  room_id text references public.rooms(id) on delete cascade not null,
  seat_index integer not null check (seat_index between 0 and 9),
  silver_gift_count integer default 0 not null check (silver_gift_count >= 0),
  primary key (room_id, seat_index)
);

create table public.room_seat_applications (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  applicant_id uuid references public.profiles(id) on delete cascade not null,
  status text default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (room_id, applicant_id)
);

create table public.room_activity_events (
  event_id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  event_type text not null,
  user_id uuid references public.profiles(id) on delete cascade,
  username text,
  seat_number integer,
  target_user_id uuid references public.profiles(id) on delete cascade,
  target_username text,
  message text not null,
  metadata jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.room_bans (
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  banned_by uuid references public.profiles(id) on delete set null,
  reason text,
  expires_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, user_id)
);

create table public.room_activity_logs (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade,
  action_type text not null,
  details text,
  moderator_id uuid references public.profiles(id) on delete set null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Triggers
create or replace function public.check_room_username()
returns trigger as $$
begin
  if exists (select 1 from public.profiles where username = new.username) then
    raise exception 'Username is already taken by a profile';
  end if;
  if exists (select 1 from public.rooms where username = new.username and id <> new.id) then
    raise exception 'Username is already taken by another voice room';
  end if;
  return new;
end;
$$ language plpgsql;

create trigger check_room_username_trigger
before insert or update of username on public.rooms
for each row execute function public.check_room_username();

create or replace function public.check_room_update_permission()
returns trigger as $$
declare
  v_actor_id uuid;
  v_role text;
begin
  v_actor_id := auth.uid();
  if v_actor_id is null then
    return new;
  end if;

  if not (
    (new.name is distinct from old.name) or
    (new.username is distinct from old.username) or
    (new.description is distinct from old.description) or
    (new.category is distinct from old.category) or
    (new.language is distinct from old.language) or
    (new.visibility is distinct from old.visibility) or
    (new.level_requirement is distinct from old.level_requirement) or
    (new.vip_requirement is distinct from old.vip_requirement) or
    (new.verification_requirement is distinct from old.verification_requirement) or
    (new.avatar is distinct from old.avatar) or
    (new.banner is distinct from old.banner) or
    (new.room_cover_url is distinct from old.room_cover_url) or
    (new.co_host_can_edit_cover is distinct from old.co_host_can_edit_cover) or
    (new.admin_can_edit_cover is distinct from old.admin_can_edit_cover) or
    (new.is_permanent is distinct from old.is_permanent) or
    (new.host_id is distinct from old.host_id)
  ) then
    return new;
  end if;

  select role into v_role 
  from public.room_members 
  where room_id = old.id and user_id = v_actor_id;

  if old.host_id = v_actor_id then
    return new;
  end if;

  if (v_role = 'Co-Host' and old.co_host_can_edit_cover = true) or
     (v_role = 'Moderator' and old.admin_can_edit_cover = true) then
    if (new.id is distinct from old.id) or
       (new.name is distinct from old.name) or
       (new.username is distinct from old.username) or
       (new.description is distinct from old.description) or
       (new.category is distinct from old.category) or
       (new.language is distinct from old.language) or
       (new.visibility is distinct from old.visibility) or
       (new.level_requirement is distinct from old.level_requirement) or
       (new.vip_requirement is distinct from old.vip_requirement) or
       (new.verification_requirement is distinct from old.verification_requirement) or
       (new.banner is distinct from old.banner) or
       (new.co_host_can_edit_cover is distinct from old.co_host_can_edit_cover) or
       (new.admin_can_edit_cover is distinct from old.admin_can_edit_cover) or
       (new.is_permanent is distinct from old.is_permanent) or
       (new.host_id is distinct from old.host_id)
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

create trigger check_room_update_permission_trigger
before update on public.rooms
for each row execute function public.check_room_update_permission();

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

create trigger tr_update_room_member_counts
after insert or delete or update of role on public.room_members
for each row execute function public.update_room_member_counts();

create or replace function public.sync_room_seats_user_profile()
returns trigger as $$
declare
  v_username text;
  v_avatar text;
  v_level integer;
  v_avatar_frame text;
  v_vip_level integer;
  v_noble_level integer;
begin
  new.seat_number := new.seat_index;
  
  if new.user_id is not null then
    select username, avatar_url, level, avatar_frame, vip_level, novel_level
    into v_username, v_avatar, v_level, v_avatar_frame, v_vip_level, v_noble_level
    from public.profiles where id = new.user_id;

    new.username := v_username;
    new.avatar := v_avatar;
    new.level := v_level;
    new.avatar_frame := v_avatar_frame;
    new.vip_level := v_vip_level;
    new.noble_level := v_noble_level;
  else
    new.username := null;
    new.avatar := null;
    new.level := null;
    new.avatar_frame := null;
    new.vip_level := null;
    new.noble_level := null;
    new.is_speaking := false;
  end if;

  return new;
end;
$$ language plpgsql;

create trigger tr_sync_room_seats_user_profile
before insert or update of user_id on public.room_seats
for each row execute function public.sync_room_seats_user_profile();

create or replace function public.sync_profile_updates_to_seats()
returns trigger as $$
begin
  update public.room_seats
  set 
    username = new.username,
    avatar = new.avatar_url,
    level = new.level,
    avatar_frame = new.avatar_frame,
    vip_level = new.vip_level,
    noble_level = new.novel_level
  where user_id = new.id;
  return new;
end;
$$ language plpgsql;

create trigger tr_sync_profile_updates_to_seats
after update of username, avatar_url, level, avatar_frame, vip_level, novel_level on public.profiles
for each row execute function public.sync_profile_updates_to_seats();

create or replace function public.on_rooms_core_update()
returns trigger as $$
begin
  new.room_name := new.name;
  new.room_banner := new.banner;
  new.room_owner := new.host_id;
  new.online_members := coalesce(new.total_members, 0);
  new.updated_at := now();
  return new;
end;
$$ language plpgsql;

create trigger tr_on_rooms_core_update
before insert or update of name, banner, host_id, total_members on public.rooms
for each row execute function public.on_rooms_core_update();

-- Row Level Security (RLS) Policies
alter table public.rooms enable row level security;
create policy "Anyone can view active rooms" on public.rooms for select using (status <> 'ended');
create policy "Host can all on own rooms" on public.rooms for all using (auth.uid() = host_id);
create policy "Update rooms" on public.rooms for update using (
  auth.uid() = host_id 
  or exists (
    select 1 from public.room_members 
    where room_members.room_id = rooms.id 
      and room_members.user_id = auth.uid() 
      and room_members.role in ('Co-Host', 'Moderator')
  )
);

alter table public.room_members enable row level security;
create policy "Members are viewable by everyone" on public.room_members for select using (true);
create policy "Insert members" on public.room_members for insert with check (
  auth.uid() = user_id 
  or exists (
    select 1 from public.rooms 
    where rooms.id = room_members.room_id and rooms.host_id = auth.uid()
  )
);
create policy "Update members" on public.room_members for update using (
  auth.uid() = user_id 
  or exists (
    select 1 from public.rooms 
    where rooms.id = room_members.room_id and rooms.host_id = auth.uid()
  )
);
create policy "Delete members" on public.room_members for delete using (
  auth.uid() = user_id 
  or exists (
    select 1 from public.rooms 
    where rooms.id = room_members.room_id and rooms.host_id = auth.uid()
  )
);

alter table public.room_seat_applications enable row level security;
create policy "Users can view applications for rooms they are in" on public.room_seat_applications for select using (true);
create policy "Users can insert their own application" on public.room_seat_applications for insert with check (auth.uid() = applicant_id);
create policy "Users can update/delete their own application or room managers can update/delete" on public.room_seat_applications for all using (
  auth.uid() = applicant_id or
  exists (
    select 1 from public.room_members
    where room_members.room_id = room_seat_applications.room_id
    and room_members.user_id = auth.uid()
    and room_members.role in ('Host', 'Co-Host')
  )
);

alter table public.room_activity_events enable row level security;
create policy "Select events allowed for all" on public.room_activity_events for select using (true);
create policy "Insert events allowed for all" on public.room_activity_events for insert with check (true);

-- Realtime registrations
do $$
begin
  alter publication supabase_realtime add table public.rooms;
exception when others then
  raise notice 'Table rooms already in supabase_realtime publication';
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.room_seats;
exception when others then
  raise notice 'Table room_seats already in supabase_realtime publication';
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.room_activity_events;
exception when others then
  raise notice 'Table room_activity_events already in supabase_realtime publication';
end;
$$;
