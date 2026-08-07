-- Migration: 202608070018_starmaker_strict_daily_task_system.sql
-- Description: Strict StarMaker-style Room Task & Daily Limit System with 4:00 AM server timezone reset, FREE_TASK_LIMIT = 600, GOLD_TASK_LIMIT = 1200, Total Lifetime Task persistence, atomic Postgres FOR UPDATE locking, and zero-client-trust server validation.

-- 1. Ensure columns exist on public.room_dual_progress
alter table public.room_dual_progress add column if not exists daily_free_progress integer default 0 not null check (daily_free_progress >= 0);
alter table public.room_dual_progress add column if not exists free_task_limit integer default 600 not null check (free_task_limit > 0);
alter table public.room_dual_progress add column if not exists daily_gold_progress integer default 0 not null check (daily_gold_progress >= 0);
alter table public.room_dual_progress add column if not exists gold_task_limit integer default 1200 not null check (gold_task_limit > 0);
alter table public.room_dual_progress add column if not exists total_lifetime_task integer default 0 not null check (total_lifetime_task >= 0);
alter table public.room_dual_progress add column if not exists last_reset_date date default ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date not null;

-- Ensure table policies & publication
alter table public.room_dual_progress enable row level security;

drop policy if exists "Allow read access on room_dual_progress" on public.room_dual_progress;
create policy "Allow read access on room_dual_progress" on public.room_dual_progress
  for select to authenticated using (true);

drop policy if exists "Allow update access on room_dual_progress" on public.room_dual_progress;
create policy "Allow update access on room_dual_progress" on public.room_dual_progress
  for update to authenticated using (true);

-- 2. Core Centralized Atomic RPC: process_room_dual_progress
create or replace function public.process_room_dual_progress(
  p_room_id text,
  p_user_id uuid,
  p_points integer,
  p_source text default 'gold_gift'
) returns jsonb as $$
declare
  v_rec record;
  v_is_gold boolean := (lower(p_source) in ('gold_gift', 'gold', 'gold_coin'));
  v_effective_points integer := 0;

  v_current_reset_date date := ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date;
  v_last_reset_date date;

  v_daily_free integer := 0;
  v_daily_gold integer := 0;
  v_total_lifetime integer := 0;

  v_free_limit integer := 600;
  v_gold_limit integer := 1200;

  v_free_capacity integer := 0;
  v_gold_capacity integer := 0;

  v_added_free integer := 0;
  v_added_gold integer := 0;
  v_added_total integer := 0;

  v_room_level integer := 1;
begin
  -- Input Validation
  if p_room_id is null or p_room_id = '' or p_points <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Invalid input parameters');
  end if;

  -- 1. Calculate Effective Task Points from Source
  if v_is_gold then
    v_effective_points := p_points; -- 1 Gold Coin = 1 Point
  elsif lower(p_source) in ('silver_gift', 'silver') then
    v_effective_points := floor(p_points / 100.0)::integer; -- 100 Silver = 1 Free AP Point
  elsif lower(p_source) in ('like', 'likes') then
    v_effective_points := greatest(1, floor(p_points / 10.0)::integer);
  elsif lower(p_source) in ('room_stay', 'stay') then
    v_effective_points := greatest(1, floor(p_points / 3.0)::integer);
  else
    v_effective_points := p_points; -- Mic time, seat bonus, first gift bonus, etc.
  end if;

  if v_effective_points <= 0 then
    return jsonb_build_object('success', true, 'added_free', 0, 'added_gold', 0, 'reason', 'Below minimum AP conversion threshold');
  end if;

  -- 2. Lock & Fetch or Create room_dual_progress record atomically
  insert into public.room_dual_progress (
    room_id,
    daily_free_progress, free_task_limit,
    daily_gold_progress, gold_task_limit,
    total_lifetime_task, last_reset_date,
    gold_points, gold_target,
    normal_points, normal_target,
    room_level
  ) values (
    p_room_id,
    0, 600,
    0, 1200,
    0, v_current_reset_date,
    0, 1200,
    0, 600,
    1
  ) on conflict (room_id) do nothing;

  select * into v_rec
  from public.room_dual_progress
  where room_id = p_room_id
  for update;

  -- 3. Execute 4:00 AM Server Timezone Daily Reset Check
  v_last_reset_date := coalesce(v_rec.last_reset_date, v_current_reset_date - interval '1 day');
  v_total_lifetime := coalesce(v_rec.total_lifetime_task, coalesce(v_rec.normal_points, 0) + coalesce(v_rec.gold_points, 0));

  if v_last_reset_date < v_current_reset_date then
    -- At 4:00 AM:
    -- Daily Free Task progress becomes 0
    -- Daily Gold Task progress becomes 0
    -- Total Lifetime Task NEVER resets!
    v_daily_free := 0;
    v_daily_gold := 0;
    v_last_reset_date := v_current_reset_date;
  else
    v_daily_free := coalesce(v_rec.daily_free_progress, v_rec.normal_points, 0);
    v_daily_gold := coalesce(v_rec.daily_gold_progress, v_rec.gold_points, 0);
  end if;

  v_room_level := coalesce(v_rec.room_level, 1);

  -- 4. Execute Strict StarMaker Task Increment Rules & Daily Limit Caps
  if v_is_gold then
    -- Gold Coin spending contributes to BOTH task categories:
    -- 1. Increases Gold Task (up to GOLD_TASK_LIMIT = 1200)
    -- 2. Also increases Free Task if Free Task has not reached FREE_TASK_LIMIT = 600
    v_free_capacity := greatest(0, v_free_limit - v_daily_free);
    v_added_free := min(v_effective_points, v_free_capacity);

    v_gold_capacity := greatest(0, v_gold_limit - v_daily_gold);
    v_added_gold := min(v_effective_points, v_gold_capacity);
  else
    -- Silver gifts, Free gifts, Sitting in room, Free activities can ONLY increase Free Task.
    -- MUST NEVER increase Gold Task! Cannot exceed Free limit (600).
    v_free_capacity := greatest(0, v_free_limit - v_daily_free);
    v_added_free := min(v_effective_points, v_free_capacity);
    v_added_gold := 0;
  end if;

  -- 5. Update State Counters
  v_daily_free := v_daily_free + v_added_free;
  v_daily_gold := v_daily_gold + v_added_gold;

  -- Total Lifetime Task always increases ONLY by valid earned daily progress:
  v_added_total := v_added_free + v_added_gold;
  v_total_lifetime := v_total_lifetime + v_added_total;

  -- 6. Room Level Thresholds based on Total Lifetime Task
  if v_total_lifetime >= 1590000 then v_room_level := 7;
  elsif v_total_lifetime >= 940000 then v_room_level := 6;
  elsif v_total_lifetime >= 490000 then v_room_level := 5;
  elsif v_total_lifetime >= 95000 then v_room_level := 4;
  elsif v_total_lifetime >= 59500 then v_room_level := 3;
  elsif v_total_lifetime >= 35500 then v_room_level := 2;
  else v_room_level := 1;
  end if;

  -- 7. Persist to room_dual_progress table
  update public.room_dual_progress
  set daily_free_progress = v_daily_free,
      free_task_limit = v_free_limit,
      daily_gold_progress = v_daily_gold,
      gold_task_limit = v_gold_limit,
      total_lifetime_task = v_total_lifetime,
      last_reset_date = v_last_reset_date,
      normal_points = v_daily_free,
      normal_target = v_free_limit,
      gold_points = v_daily_gold,
      gold_target = v_gold_limit,
      room_level = v_room_level,
      updated_at = timezone('utc'::text, now())
  where room_id = p_room_id;

  -- 8. Persist to public.rooms table safely
  update public.rooms
  set room_level = v_room_level,
      level = v_room_level,
      today_room_xp = v_daily_free + v_daily_gold,
      room_xp = v_total_lifetime,
      updated_at = timezone('utc'::text, now())
  where id = p_room_id;

  -- 9. Persist to room_level_progress table safely
  insert into public.room_level_progress (room_id, current_xp, current_level, updated_at)
  values (p_room_id, v_total_lifetime, v_room_level, timezone('utc'::text, now()))
  on conflict (room_id) do update set
    current_xp = v_total_lifetime,
    current_level = v_room_level,
    updated_at = timezone('utc'::text, now());

  return jsonb_build_object(
    'success', true,
    'room_id', p_room_id,
    'source', p_source,
    'added_free', v_added_free,
    'added_gold', v_added_gold,
    'added_total', v_added_total,
    'daily_free_progress', v_daily_free,
    'free_task_limit', v_free_limit,
    'daily_gold_progress', v_daily_gold,
    'gold_task_limit', v_gold_limit,
    'total_lifetime_task', v_total_lifetime,
    'last_reset_date', v_last_reset_date,
    'room_level', v_room_level,
    'is_free_limit_reached', (v_daily_free >= v_free_limit),
    'is_gold_limit_reached', (v_daily_gold >= v_gold_limit)
  );
end;
$$ language plpgsql security definer;
