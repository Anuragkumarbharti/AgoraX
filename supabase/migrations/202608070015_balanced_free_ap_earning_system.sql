-- Migration: 202608070015_balanced_free_ap_earning_system.sql
-- Description: Balanced Free AP Earning System (Unique Seat Join Bonus +20 AP, First Gift Bonus +5 AP, Active Seat Time Reward 4 AP/min/seat, anti-abuse guards, and Realtime sync).

-- 0. Ensure Room Dual Progress Table exists
create table if not exists public.room_dual_progress (
  room_id text primary key references public.rooms(id) on delete cascade,
  gold_points integer default 0 not null check (gold_points >= 0),
  gold_target integer default 1000 not null check (gold_target > 0),
  normal_points integer default 0 not null check (normal_points >= 0),
  normal_target integer default 700 not null check (normal_target > 0),
  overflow_points integer default 0 not null check (overflow_points >= 0),
  room_level integer default 1 not null check (room_level >= 1),
  created_at timestamptz default timezone('utc'::text, now()) not null,
  updated_at timestamptz default timezone('utc'::text, now()) not null
);

-- Enable RLS and Realtime for room_dual_progress
alter table public.room_dual_progress enable row level security;

drop policy if exists "Allow read access on room_dual_progress" on public.room_dual_progress;
create policy "Allow read access on room_dual_progress" on public.room_dual_progress
  for select to authenticated using (true);

drop policy if exists "Allow update access on room_dual_progress" on public.room_dual_progress;
create policy "Allow update access on room_dual_progress" on public.room_dual_progress
  for update to authenticated using (true);

do $$
begin
  alter publication supabase_realtime add table public.room_dual_progress;
exception when others then
  raise notice 'Table room_dual_progress already in supabase_realtime publication';
end;
$$;

-- 1. Create Room Daily User Bonuses Table (Tracks 1-time daily claims per user per room)
create table if not exists public.room_daily_user_bonuses (
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  task_date date default ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date not null,
  has_claimed_seat_bonus boolean default false not null,
  has_claimed_gift_bonus boolean default false not null,
  created_at timestamptz default timezone('utc'::text, now()) not null,
  primary key (room_id, user_id, task_date)
);

-- 2. Add tracking columns to public.room_dual_progress
alter table public.room_dual_progress add column if not exists unique_join_count integer default 0 not null check (unique_join_count >= 0);
alter table public.room_dual_progress add column if not exists first_gift_bonus_count integer default 0 not null check (first_gift_bonus_count >= 0);
alter table public.room_dual_progress add column if not exists active_seat_minutes integer default 0 not null check (active_seat_minutes >= 0);

-- Enable RLS and policies on room_daily_user_bonuses
alter table public.room_daily_user_bonuses enable row level security;

drop policy if exists "Allow read access on room_daily_user_bonuses" on public.room_daily_user_bonuses;
create policy "Allow read access on room_daily_user_bonuses" on public.room_daily_user_bonuses
  for select to authenticated using (true);

drop policy if exists "Allow insert/update access on room_daily_user_bonuses" on public.room_daily_user_bonuses;
create policy "Allow insert/update access on room_daily_user_bonuses" on public.room_daily_user_bonuses
  for all to authenticated using (true);

-- 3. Atomic RPC 1: claim_unique_seat_bonus (+20 Normal AP for 1st seat occupancy today, max 5 users/day)
create or replace function public.claim_unique_seat_bonus(
  p_room_id text,
  p_user_id uuid
) returns jsonb as $$
declare
  v_today date := ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date;
  v_claimed boolean := false;
  v_unique_count integer := 0;
  v_dual_res jsonb;
begin
  if p_room_id is null or p_room_id = '' or p_user_id is null then
    return jsonb_build_object('success', false, 'reason', 'Invalid parameters');
  end if;

  -- Check if user already claimed seat bonus today in this room
  select has_claimed_seat_bonus into v_claimed
  from public.room_daily_user_bonuses
  where room_id = p_room_id and user_id = p_user_id and task_date = v_today;

  if v_claimed is true then
    return jsonb_build_object('success', false, 'reason', 'Already claimed seat bonus today in this room', 'added_ap', 0);
  end if;

  -- Lock room_dual_progress FOR UPDATE and check unique_join_count cap (Max 5 users)
  insert into public.room_dual_progress (room_id, gold_points, gold_target, normal_points, normal_target, overflow_points, room_level)
  values (p_room_id, 0, 1000, 0, 700, 0, 1)
  on conflict (room_id) do nothing;

  select unique_join_count into v_unique_count
  from public.room_dual_progress
  where room_id = p_room_id
  for update;

  if coalesce(v_unique_count, 0) >= 5 then
    return jsonb_build_object('success', false, 'reason', 'Maximum 5 unique user join bonuses reached today for this room', 'added_ap', 0);
  end if;

  -- Record claim in tracking table
  insert into public.room_daily_user_bonuses (room_id, user_id, task_date, has_claimed_seat_bonus)
  values (p_room_id, p_user_id, v_today, true)
  on conflict (room_id, user_id, task_date) do update set
    has_claimed_seat_bonus = true;

  -- Update count
  update public.room_dual_progress
  set unique_join_count = unique_join_count + 1
  where room_id = p_room_id;

  -- Award +20 Normal AP atomically (Normal Progress ONLY, NEVER Gold Progress)
  v_dual_res := public.process_room_dual_progress(p_room_id, p_user_id, 20, 'seat_join_bonus');

  return jsonb_build_object(
    'success', true,
    'added_ap', 20,
    'unique_join_count', v_unique_count + 1,
    'max_unique_joins', 5,
    'dual_result', v_dual_res
  );
end;
$$ language plpgsql security definer;

-- 4. Atomic RPC 2: process_first_gift_bonus (+5 Normal AP bonus on 1st gift sent today, max 20 users/day)
create or replace function public.process_first_gift_bonus(
  p_room_id text,
  p_user_id uuid
) returns jsonb as $$
declare
  v_today date := ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date;
  v_claimed boolean := false;
  v_gift_count integer := 0;
  v_dual_res jsonb;
begin
  if p_room_id is null or p_room_id = '' or p_user_id is null then
    return jsonb_build_object('success', false, 'reason', 'Invalid parameters');
  end if;

  select has_claimed_gift_bonus into v_claimed
  from public.room_daily_user_bonuses
  where room_id = p_room_id and user_id = p_user_id and task_date = v_today;

  if v_claimed is true then
    return jsonb_build_object('success', false, 'reason', 'First gift bonus already claimed today in this room', 'added_ap', 0);
  end if;

  insert into public.room_dual_progress (room_id, gold_points, gold_target, normal_points, normal_target, overflow_points, room_level)
  values (p_room_id, 0, 1000, 0, 700, 0, 1)
  on conflict (room_id) do nothing;

  select first_gift_bonus_count into v_gift_count
  from public.room_dual_progress
  where room_id = p_room_id
  for update;

  if coalesce(v_gift_count, 0) >= 20 then
    return jsonb_build_object('success', false, 'reason', 'Maximum 20 unique user first gift bonuses reached today for this room', 'added_ap', 0);
  end if;

  insert into public.room_daily_user_bonuses (room_id, user_id, task_date, has_claimed_gift_bonus)
  values (p_room_id, p_user_id, v_today, true)
  on conflict (room_id, user_id, task_date) do update set
    has_claimed_gift_bonus = true;

  update public.room_dual_progress
  set first_gift_bonus_count = first_gift_bonus_count + 1
  where room_id = p_room_id;

  -- Award +5 Normal AP bonus atomically (Normal Progress ONLY)
  v_dual_res := public.process_room_dual_progress(p_room_id, p_user_id, 5, 'first_gift_bonus');

  return jsonb_build_object(
    'success', true,
    'added_ap', 5,
    'first_gift_bonus_count', v_gift_count + 1,
    'max_gift_bonuses', 20,
    'dual_result', v_dual_res
  );
end;
$$ language plpgsql security definer;

-- 5. Atomic RPC 3: process_active_seat_time_ap (4 Normal AP / min per active seated user)
create or replace function public.process_active_seat_time_ap(
  p_room_id text,
  p_active_seat_count integer
) returns jsonb as $$
declare
  v_total_ap integer := 0;
  v_dual_res jsonb;
begin
  if p_room_id is null or p_room_id = '' or p_active_seat_count is null or p_active_seat_count <= 0 then
    return jsonb_build_object('success', false, 'reason', 'No active seated users on mic', 'added_ap', 0);
  end if;

  -- Calculate: 4 AP per minute per active seated user (e.g., 1 user = 4 AP, 5 users = 20 AP, 10 users = 40 AP)
  v_total_ap := p_active_seat_count * 4;

  insert into public.room_dual_progress (room_id, gold_points, gold_target, normal_points, normal_target, overflow_points, room_level)
  values (p_room_id, 0, 1000, 0, 700, 0, 1)
  on conflict (room_id) do nothing;

  update public.room_dual_progress
  set active_seat_minutes = active_seat_minutes + 1
  where room_id = p_room_id;

  -- Award v_total_ap Normal AP atomically (Normal Progress ONLY, NEVER Gold Progress)
  v_dual_res := public.process_room_dual_progress(p_room_id, null, v_total_ap, 'active_seat_time');

  return jsonb_build_object(
    'success', true,
    'added_ap', v_total_ap,
    'active_seat_count', p_active_seat_count,
    'dual_result', v_dual_res
  );
end;
$$ language plpgsql security definer;
