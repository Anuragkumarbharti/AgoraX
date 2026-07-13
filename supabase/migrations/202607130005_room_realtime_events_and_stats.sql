-- supabase/migrations/202607130005_room_realtime_events_and_stats.sql

-- 1. Add fields to public.rooms table
alter table public.rooms add column if not exists room_name text;
alter table public.rooms add column if not exists room_banner text;
alter table public.rooms add column if not exists room_owner uuid references public.profiles(id);
alter table public.rooms add column if not exists room_level integer default 1 not null;
alter table public.rooms add column if not exists room_xp integer default 0 not null;
alter table public.rooms add column if not exists today_room_xp integer default 0 not null;
alter table public.rooms add column if not exists online_members integer default 0 not null;
alter table public.rooms add column if not exists total_room_gifts integer default 0 not null;
alter table public.rooms add column if not exists today_room_gifts integer default 0 not null;
alter table public.rooms add column if not exists total_room_stars integer default 0 not null;
alter table public.rooms add column if not exists today_room_stars integer default 0 not null;
alter table public.rooms add column if not exists updated_at timestamp with time zone default timezone('utc'::text, now()) not null;

-- Sync existing room columns
update public.rooms r
set 
  room_name = name,
  room_banner = banner,
  room_owner = host_id,
  online_members = coalesce(total_members, 0),
  room_level = coalesce((select current_level from public.room_level_progress where room_id = r.id), 1),
  room_xp = coalesce((select current_xp from public.room_level_progress where room_id = r.id), 0);

-- Trigger to auto-sync core columns in rooms
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

drop trigger if exists tr_on_rooms_core_update on public.rooms;
create trigger tr_on_rooms_core_update
before insert or update of name, banner, host_id, total_members on public.rooms
for each row execute function public.on_rooms_core_update();


-- 2. Add fields to public.room_seats table
alter table public.room_seats add column if not exists seat_number integer;
alter table public.room_seats add column if not exists avatar text;
alter table public.room_seats add column if not exists avatar_frame text;
alter table public.room_seats add column if not exists username text;
alter table public.room_seats add column if not exists level integer;
alter table public.room_seats add column if not exists noble_level integer;
alter table public.room_seats add column if not exists vip_level integer;
alter table public.room_seats add column if not exists mic_status text default 'unmuted' not null;
alter table public.room_seats add column if not exists is_speaking boolean default false not null;
alter table public.room_seats add column if not exists seat_total_gifts integer default 0 not null;
alter table public.room_seats add column if not exists seat_total_stars integer default 0 not null;
alter table public.room_seats add column if not exists last_gift_time timestamp with time zone;

-- Sync existing seat seat_number
update public.room_seats set seat_number = seat_index;

-- 3. Create room_activity_events table
create table if not exists public.room_activity_events (
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

-- RLS for room_activity_events
alter table public.room_activity_events enable row level security;
drop policy if exists "Select events allowed for all" on public.room_activity_events;
drop policy if exists "Insert events allowed for all" on public.room_activity_events;
create policy "Select events allowed for all" on public.room_activity_events for select using (true);
create policy "Insert events allowed for all" on public.room_activity_events for insert with check (true);


-- 4. Triggers to synchronize user profile information on seats in real-time
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

drop trigger if exists tr_sync_room_seats_user_profile on public.room_seats;
create trigger tr_sync_room_seats_user_profile
before insert or update of user_id on public.room_seats
for each row execute function public.sync_room_seats_user_profile();


-- Trigger to sync updates from profile table to seats in real-time
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

drop trigger if exists tr_sync_profile_updates_to_seats on public.profiles;
create trigger tr_sync_profile_updates_to_seats
after update of username, avatar_url, level, avatar_frame, vip_level, novel_level on public.profiles
for each row execute function public.sync_profile_updates_to_seats();


-- 5. Enable Realtime Publications using DO blocks
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
