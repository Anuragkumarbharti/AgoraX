-- Migration: 202608070017_fix_gifting_error_room_level_column.sql
-- Description: Fix "column level does not exist" and "column updated_at of relation room_level_progress does not exist" errors during gifting.

-- 1. Ensure public.rooms has both room_level and level columns
alter table public.rooms add column if not exists level integer default 1 check (level >= 1);
alter table public.rooms add column if not exists room_level integer default 1 check (room_level >= 1);

-- 2. Ensure public.room_level_progress has updated_at column
alter table public.room_level_progress add column if not exists updated_at timestamptz default timezone('utc'::text, now());

-- Backfill missing values
update public.rooms set level = coalesce(room_level, level, 1) where level is null;
update public.rooms set room_level = coalesce(level, room_level, 1) where room_level is null;

-- 3. Create column sync trigger for public.rooms (Keeps room_level and level in sync)
create or replace function public.sync_room_level_columns()
returns trigger as $$
begin
  if new.room_level is distinct from old.room_level then
    new.level := new.room_level;
  elsif new.level is distinct from old.level then
    new.room_level := new.level;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trigger_sync_room_level_columns on public.rooms;
create trigger trigger_sync_room_level_columns
  before insert or update on public.rooms
  for each row execute function public.sync_room_level_columns();

-- 4. Update process_room_dual_progress with safe column targets
create or replace function public.process_room_dual_progress(
  p_room_id text,
  p_user_id uuid,
  p_points integer,
  p_source text default 'gold_gift'
) returns jsonb as $$
declare
  v_rec record;
  v_is_gold boolean := (p_source = 'gold_gift');
  v_effective_ap integer := 0;
  
  v_gold_points integer := 0;
  v_gold_target integer := 1000;
  v_normal_points integer := 0;
  v_normal_target integer := 700;
  v_overflow_points integer := 0;
  v_room_level integer := 1;
  
  v_gold_capacity integer := 0;
  v_gold_added integer := 0;
  v_gold_overflow integer := 0;
  v_normal_capacity integer := 0;
  v_normal_added integer := 0;
  
  v_is_level_up boolean := false;
  v_excess_after_levelup integer := 0;
begin
  if p_room_id is null or p_room_id = '' or p_points <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Invalid input');
  end if;

  -- 1. Calculate effective AP points based on source
  if v_is_gold then
    v_effective_ap := p_points; -- 1 Gold Coin = 1 Gold XP
  elsif p_source = 'silver_gift' then
    v_effective_ap := floor(p_points / 100.0)::integer; -- 100 Silver = 1 Normal AP
  elsif p_source = 'like' then
    v_effective_ap := floor(p_points / 10.0)::integer; -- 10 Likes = 1 Normal AP
  elsif p_source = 'room_stay' then
    v_effective_ap := floor(p_points / 3.0)::integer; -- 3 Mins Stay = 1 Normal AP
  else
    v_effective_ap := p_points; -- Seat join bonus, first gift bonus, active seat time
  end if;

  if v_effective_ap <= 0 then
    return jsonb_build_object('success', true, 'added_ap', 0, 'reason', 'Converted AP below minimum 1 AP threshold');
  end if;

  -- 2. Lock & Fetch or Create room_dual_progress record
  insert into public.room_dual_progress (room_id, gold_points, gold_target, normal_points, normal_target, overflow_points, room_level)
  values (p_room_id, 0, 1000, 0, 700, 0, 1)
  on conflict (room_id) do nothing;

  select * into v_rec
  from public.room_dual_progress
  where room_id = p_room_id
  for update;

  v_gold_points := coalesce(v_rec.gold_points, 0);
  v_gold_target := coalesce(v_rec.gold_target, 1000);
  v_normal_points := coalesce(v_rec.normal_points, 0);
  v_normal_target := coalesce(v_rec.normal_target, 700);
  v_overflow_points := coalesce(v_rec.overflow_points, 0);
  v_room_level := coalesce(v_rec.room_level, 1);

  -- 3. Execute Dual Progress Routing Rules
  if v_is_gold then
    -- Gold Gift fills Gold Progress first
    v_gold_capacity := greatest(0, v_gold_target - v_gold_points);
    if v_effective_ap <= v_gold_capacity then
      v_gold_points := v_gold_points + v_effective_ap;
      v_gold_added := v_effective_ap;
      v_gold_overflow := 0;
    else
      v_gold_added := v_gold_capacity;
      v_gold_points := v_gold_target;
      v_gold_overflow := v_effective_ap - v_gold_capacity;
    end if;

    -- Gold Overflow automatically fills Normal Progress
    if v_gold_overflow > 0 then
      v_normal_capacity := greatest(0, v_normal_target - v_normal_points);
      if v_gold_overflow <= v_normal_capacity then
        v_normal_points := v_normal_points + v_gold_overflow;
        v_overflow_points := v_overflow_points + v_gold_overflow;
      else
        v_overflow_points := v_overflow_points + v_gold_overflow;
        v_excess_after_levelup := (v_normal_points + v_gold_overflow) - v_normal_target;
        v_normal_points := v_normal_target;
        v_is_level_up := true;
      end if;
    end if;
  else
    -- Non-Gold sources (Silver, Likes, Stay, Bonuses) ONLY fill Normal Progress
    v_normal_capacity := greatest(0, v_normal_target - v_normal_points);
    if v_effective_ap <= v_normal_capacity then
      v_normal_points := v_normal_points + v_effective_ap;
      v_normal_added := v_effective_ap;
    else
      v_normal_added := v_normal_capacity;
      v_excess_after_levelup := (v_normal_points + v_effective_ap) - v_normal_target;
      v_normal_points := v_normal_target;
      v_is_level_up := true;
    end if;
  end if;

  -- 4. Process Level Up if Normal Progress reaches 100%
  if v_is_level_up or (v_gold_points >= v_gold_target and v_normal_points >= v_normal_target) then
    v_room_level := v_room_level + 1;
    v_gold_points := 0; -- Reset gold bar for new level
    v_normal_points := least(v_excess_after_levelup, 700); -- Carry forward excess points
    v_overflow_points := 0;
  end if;

  -- 5. Update room_dual_progress table
  update public.room_dual_progress
  set gold_points = v_gold_points,
      gold_target = v_gold_target,
      normal_points = v_normal_points,
      normal_target = v_normal_target,
      overflow_points = v_overflow_points,
      room_level = v_room_level,
      updated_at = timezone('utc'::text, now())
  where room_id = p_room_id;

  -- 6. Update rooms table (Update both level and room_level safely)
  update public.rooms
  set room_level = v_room_level,
      level = v_room_level,
      today_room_xp = coalesce(today_room_xp, 0) + v_effective_ap,
      room_xp = coalesce(room_xp, 0) + v_effective_ap,
      updated_at = timezone('utc'::text, now())
  where id = p_room_id;

  -- 7. Update room_level_progress table safely
  insert into public.room_level_progress (room_id, current_xp, current_level, updated_at)
  values (p_room_id, v_effective_ap, v_room_level, timezone('utc'::text, now()))
  on conflict (room_id) do update set
    current_xp = room_level_progress.current_xp + v_effective_ap,
    current_level = v_room_level,
    updated_at = timezone('utc'::text, now());

  return jsonb_build_object(
    'success', true,
    'room_id', p_room_id,
    'source', p_source,
    'effective_ap', v_effective_ap,
    'gold_points', v_gold_points,
    'gold_target', v_gold_target,
    'normal_points', v_normal_points,
    'normal_target', v_normal_target,
    'overflow_points', v_overflow_points,
    'room_level', v_room_level,
    'is_level_up', v_is_level_up,
    'gold_ratio', round((v_gold_points::numeric / v_gold_target::numeric), 4),
    'normal_ratio', round((v_normal_points::numeric / v_normal_target::numeric), 4)
  );
end;
$$ language plpgsql security definer;
