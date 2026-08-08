-- Migration: 202608090001_fix_gift_task_and_weekend_limit.sql
-- Description: Fix Gift Task & Daily Task AP/Gem counting logic, sequential Gold Task filling, 100:1 Silver conversion, Volt AP/Gem sync, and Weekend 2x Daily Task limits.

-- 1. Core Centralized Atomic RPC: process_room_dual_progress
create or replace function public.process_room_dual_progress(
  p_room_id text,
  p_user_id uuid,
  p_points integer,
  p_source text default 'gold_gift'
) returns jsonb as $$
declare
  v_rec record;
  v_source_clean text := lower(coalesce(p_source, 'gold_gift'));
  v_is_gold boolean := (v_source_clean in ('gold_gift', 'gold', 'gold_coin'));
  v_is_silver boolean := (v_source_clean in ('silver_gift', 'silver', 'silver_coin'));
  v_is_volt boolean := (v_source_clean in ('volt_gift', 'volt', 'volt_coin'));
  v_effective_points integer := 0;

  v_current_reset_date date := ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date;
  v_last_reset_date date;

  v_is_weekend boolean := (extract(isodow from ((now() at time zone 'Asia/Kolkata') - interval '4 hours')) in (6, 7));

  v_daily_free integer := 0;
  v_daily_gold integer := 0;
  v_total_task integer := 0;
  v_total_lifetime integer := 0;

  -- Weekday: Free 700 + Gold 1000 = 1700 AP Limit
  -- Weekend: Free 1400 + Gold 2000 = 3400 AP Limit (2x Boost)
  v_free_limit integer := case when v_is_weekend then 1400 else 700 end;
  v_gold_limit integer := case when v_is_weekend then 2000 else 1000 end;

  v_free_capacity integer := 0;
  v_gold_capacity integer := 0;
  v_remaining_gold_points integer := 0;

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

  -- 1. Calculate Effective AP Task Points from Source
  if v_is_gold then
    v_effective_points := p_points; -- 1 Gold Coin = 1 AP = 1 Gem
  elsif v_is_silver then
    v_effective_points := floor(p_points / 100.0)::integer; -- 100 Silver Coins = 1 Free AP = 1 Gem
  elsif v_is_volt then
    v_effective_points := p_points; -- Volt AP = 1 Gem
  elsif v_source_clean in ('like', 'likes') then
    v_effective_points := greatest(1, floor(p_points / 10.0)::integer);
  elsif v_source_clean in ('room_stay', 'stay') then
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
    0, v_free_limit,
    0, v_gold_limit,
    0, 0, v_current_reset_date,
    0, v_gold_limit,
    0, v_free_limit,
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
    v_daily_free := 0;
    v_daily_gold := 0;
    v_last_reset_date := v_current_reset_date;
  else
    v_daily_free := coalesce(v_rec.daily_free_progress, v_rec.normal_points, 0);
    v_daily_gold := coalesce(v_rec.daily_gold_progress, v_rec.gold_points, 0);
  end if;

  v_room_level := coalesce(v_rec.room_level, 1);

  -- 4. Execute Daily Task Bucket Allocation Logic
  if v_is_gold then
    -- Gold Gifts FIRST fill GOLD TASK up to v_gold_limit
    v_gold_capacity := greatest(0, v_gold_limit - v_daily_gold);
    v_added_gold := least(v_effective_points, v_gold_capacity);

    -- Excess gold AP after Gold Task is complete spills over into NORMAL/FREE TASK
    v_remaining_gold_points := v_effective_points - v_added_gold;
    if v_remaining_gold_points > 0 then
      v_free_capacity := greatest(0, v_free_limit - v_daily_free);
      v_added_free := least(v_remaining_gold_points, v_free_capacity);
    else
      v_added_free := 0;
    end if;
  else
    -- Silver gifts, Volt gifts, Mic time, Seat bonus, Free activities ONLY increase Free Task!
    -- MUST NEVER increase Gold Task!
    v_free_capacity := greatest(0, v_free_limit - v_daily_free);
    v_added_free := least(v_effective_points, v_free_capacity);
    v_added_gold := 0;
  end if;

  -- 5. Update State Counters
  v_daily_free := v_daily_free + v_added_free;
  v_daily_gold := v_daily_gold + v_added_gold;

  -- Every valid Daily Task contribution is permanently added to Total Task and Total Lifetime Task
  v_added_total := v_added_free + v_added_gold;
  v_total_task := v_total_task + v_added_total;
  v_total_lifetime := v_total_lifetime + v_added_total;

  -- 6. Room Level Calculation (ONLY from Total Task reaching required_task_for_level)
  v_required_task := public.get_required_task_for_level(v_room_level);

  while v_room_level < 7 and v_total_task >= v_required_task loop
    v_room_level := v_room_level + 1;
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


-- 2. User Daily Task Catalog Updates on Gift
create or replace function public.update_user_daily_tasks_on_gift(
  p_user_id uuid,
  p_amount integer,
  p_currency text
) returns void as $$
declare
  v_today date := ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date;
  v_rec record;
  v_curr text := lower(coalesce(p_currency, 'gold'));
begin
  if p_amount <= 0 or p_user_id is null then
    return;
  end if;

  if v_curr = 'gold' then
    -- Update Gold category & Gold send daily tasks
    for v_rec in 
      select task_key, target_value from public.room_daily_task_catalog where category = 'gold' or task_key = 'normal_send_1_gold'
    loop
      insert into public.user_daily_task_progress (user_id, task_key, current_value, is_completed, task_date, updated_at)
      values (p_user_id, v_rec.task_key, p_amount, p_amount >= v_rec.target_value, v_today, now())
      on conflict (user_id, task_key, task_date) do update set
        current_value = user_daily_task_progress.current_value + p_amount,
        is_completed = (user_daily_task_progress.current_value + p_amount) >= v_rec.target_value,
        updated_at = now();
    end loop;
  elsif v_curr = 'silver' then
    -- Update Silver send daily tasks
    for v_rec in 
      select task_key, target_value from public.room_daily_task_catalog where task_key in ('normal_send_1_silver', 'normal_send_5_silver')
    loop
      insert into public.user_daily_task_progress (user_id, task_key, current_value, is_completed, task_date, updated_at)
      values (p_user_id, v_rec.task_key, p_amount, p_amount >= v_rec.target_value, v_today, now())
      on conflict (user_id, task_key, task_date) do update set
        current_value = user_daily_task_progress.current_value + p_amount,
        is_completed = (user_daily_task_progress.current_value + p_amount) >= v_rec.target_value,
        updated_at = now();
    end loop;
  else
    -- Volt or other currency tasks
    for v_rec in 
      select task_key, target_value from public.room_daily_task_catalog where task_key in ('normal_send_1_silver', 'normal_send_5_silver')
    loop
      insert into public.user_daily_task_progress (user_id, task_key, current_value, is_completed, task_date, updated_at)
      values (p_user_id, v_rec.task_key, p_amount, p_amount >= v_rec.target_value, v_today, now())
      on conflict (user_id, task_key, task_date) do update set
        current_value = user_daily_task_progress.current_value + p_amount,
        is_completed = (user_daily_task_progress.current_value + p_amount) >= v_rec.target_value,
        updated_at = now();
    end loop;
  end if;
end;
$$ language plpgsql security definer;
