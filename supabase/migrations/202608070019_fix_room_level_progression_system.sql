-- Migration: 202608070019_fix_room_level_progression_system.sql
-- Description: Fix Room Level Progression System so Room Level depends EXCLUSIVELY on Total Task progress towards level requirements and NEVER directly on Daily Task completion. Daily Task resets every day at 4:00 AM, while Total Task resets ONLY upon successful Room Level Up.

-- 1. Ensure public.room_dual_progress table has total_task and total_lifetime_task columns
alter table public.room_dual_progress add column if not exists total_task integer default 0 not null check (total_task >= 0);
alter table public.room_dual_progress add column if not exists total_lifetime_task integer default 0 not null check (total_lifetime_task >= 0);
alter table public.room_dual_progress add column if not exists daily_free_progress integer default 0 not null check (daily_free_progress >= 0);
alter table public.room_dual_progress add column if not exists free_task_limit integer default 600 not null check (free_task_limit > 0);
alter table public.room_dual_progress add column if not exists daily_gold_progress integer default 0 not null check (daily_gold_progress >= 0);
alter table public.room_dual_progress add column if not exists gold_task_limit integer default 1200 not null check (gold_task_limit > 0);
alter table public.room_dual_progress add column if not exists last_reset_date date default ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date not null;

-- 2. Helper function to return required Total Task for next level
create or replace function public.get_required_task_for_level(p_level integer)
returns integer as $$
begin
  if p_level = 1 then return 35500;
  elsif p_level = 2 then return 59500;
  elsif p_level = 3 then return 95000;
  elsif p_level = 4 then return 490000;
  elsif p_level = 5 then return 940000;
  elsif p_level = 6 then return 1590000;
  else return 1590000;
  end if;
end;
$$ language plpgsql immutable;

-- 3. Core Centralized Atomic RPC: process_room_dual_progress
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
  v_total_task integer := 0;
  v_total_lifetime integer := 0;

  v_free_limit integer := 600;
  v_gold_limit integer := 1200;

  v_free_capacity integer := 0;
  v_gold_capacity integer := 0;

  v_added_free integer := 0;
  v_added_gold integer := 0;
  v_added_total integer := 0;

  v_room_level integer := 1;
  v_required_task integer := 35500;
  v_did_level_up boolean := false;
begin
  -- Validate Inputs
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
    total_task, total_lifetime_task, last_reset_date,
    gold_points, gold_target,
    normal_points, normal_target,
    room_level
  ) values (
    p_room_id,
    0, 600,
    0, 1200,
    0, 0, v_current_reset_date,
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
  v_total_task := coalesce(v_rec.total_task, 0);
  v_total_lifetime := coalesce(v_rec.total_lifetime_task, 0);

  if v_last_reset_date < v_current_reset_date then
    -- At 4:00 AM:
    -- Daily Free Task progress becomes 0
    -- Daily Gold Task progress becomes 0
    -- Total Task & Total Lifetime Task NEVER reset at 4:00 AM!
    v_daily_free := 0;
    v_daily_gold := 0;
    v_last_reset_date := v_current_reset_date;
  else
    v_daily_free := coalesce(v_rec.daily_free_progress, v_rec.normal_points, 0);
    v_daily_gold := coalesce(v_rec.daily_gold_progress, v_rec.gold_points, 0);
  end if;

  v_room_level := coalesce(v_rec.room_level, 1);

  -- 4. Execute Daily Task Increment Rules & Daily Limit Caps (Using LEAST for PostgreSQL)
  if v_is_gold then
    -- Gold Coin spending contributes to BOTH task categories:
    -- 1. Increases Gold Task (up to 1200)
    -- 2. Also increases Free Task if Free Task has not reached 600
    v_free_capacity := greatest(0, v_free_limit - v_daily_free);
    v_added_free := least(v_effective_points, v_free_capacity);

    v_gold_capacity := greatest(0, v_gold_limit - v_daily_gold);
    v_added_gold := least(v_effective_points, v_gold_capacity);
  else
    -- Silver gifts, Free gifts, Sitting in room, Free activities can ONLY increase Free Task.
    -- MUST NEVER increase Gold Task! Cannot exceed Free limit (600).
    v_free_capacity := greatest(0, v_free_limit - v_daily_free);
    v_added_free := least(v_effective_points, v_free_capacity);
    v_added_gold := 0;
  end if;

  -- 5. Update State Counters
  v_daily_free := v_daily_free + v_added_free;
  v_daily_gold := v_daily_gold + v_added_gold;

  -- Every valid Daily Task contribution is permanently added to Total Task and Total Lifetime Task:
  v_added_total := v_added_free + v_added_gold;
  v_total_task := v_total_task + v_added_total;
  v_total_lifetime := v_total_lifetime + v_added_total;

  -- 6. Room Level Calculation (ONLY from Total Task reaching required_task_for_level!)
  -- Daily Task completion NEVER triggers a level up directly!
  v_required_task := public.get_required_task_for_level(v_room_level);

  while v_room_level < 7 and v_total_task >= v_required_task loop
    -- Increase Room Level
    v_room_level := v_room_level + 1;
    -- Reset ONLY the Total Task progress for current level, carry forward excess
    v_total_task := v_total_task - v_required_task;
    v_did_level_up := true;
    v_required_task := public.get_required_task_for_level(v_room_level);
  end loop;

  -- 7. Persist to room_dual_progress table
  update public.room_dual_progress
  set daily_free_progress = v_daily_free,
      free_task_limit = v_free_limit,
      daily_gold_progress = v_daily_gold,
      gold_task_limit = v_gold_limit,
      total_task = v_total_task,
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
  values (p_room_id, v_total_task, v_room_level, timezone('utc'::text, now()))
  on conflict (room_id) do update set
    current_xp = v_total_task,
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
    'total_task', v_total_task,
    'total_task_target', v_required_task,
    'total_lifetime_task', v_total_lifetime,
    'last_reset_date', v_last_reset_date,
    'room_level', v_room_level,
    'did_level_up', v_did_level_up,
    'is_free_limit_reached', (v_daily_free >= v_free_limit),
    'is_gold_limit_reached', (v_daily_gold >= v_gold_limit)
  );
end;
$$ language plpgsql security definer;
