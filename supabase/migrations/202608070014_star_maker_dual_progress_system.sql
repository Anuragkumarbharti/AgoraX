-- Migration: 202608070014_star_maker_dual_progress_system.sql
-- Description: Production StarMaker Dual Progress System with exact Silver Coin conversion (100 Silver = 1 Normal AP), Gold XP overflow, column aliases (gold_xp, normal_ap), atomic Postgres RPC, real-time sync, and anti-abuse.

-- 1. Create Room Dual Progress Table
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

-- Ensure column compatibility / aliases
alter table public.room_dual_progress add column if not exists gold_xp integer generated always as (gold_points) stored;
alter table public.room_dual_progress add column if not exists normal_ap integer generated always as (normal_points) stored;

-- 2. Enable RLS and Grant Access
alter table public.room_dual_progress enable row level security;

drop policy if exists "Allow read access on room_dual_progress" on public.room_dual_progress;
create policy "Allow read access on room_dual_progress" on public.room_dual_progress
  for select to authenticated using (true);

drop policy if exists "Allow update access on room_dual_progress" on public.room_dual_progress;
create policy "Allow update access on room_dual_progress" on public.room_dual_progress
  for update to authenticated using (true);

-- 3. Add to Supabase Realtime Publication
do $$
begin
  alter publication supabase_realtime add table public.room_dual_progress;
exception when others then
  raise notice 'Table room_dual_progress already in supabase_realtime publication';
end;
$$;

-- 4. Centralized Atomic RPC: process_room_dual_progress
create or replace function public.process_room_dual_progress(
  p_room_id text,
  p_user_id uuid,
  p_points integer,
  p_source text
) returns jsonb as $$
declare
  v_record public.room_dual_progress%rowtype;
  v_effective_ap integer := 0;
  v_gold_points integer := 0;
  v_gold_target integer := 1000;
  v_normal_points integer := 0;
  v_normal_target integer := 700;
  v_overflow_points integer := 0;
  v_room_level integer := 1;

  v_gold_space integer := 0;
  v_gold_added integer := 0;
  v_overflow_added integer := 0;
  v_rem_overflow integer := 0;

  v_normal_space integer := 0;
  v_normal_added integer := 0;
  v_rem_free integer := 0;

  v_did_level_up boolean := false;
  v_is_gold_gift boolean := (lower(p_source) = 'gold_gift' or lower(p_source) = 'gold');
  v_is_silver_gift boolean := (lower(p_source) = 'silver_gift' or lower(p_source) = 'silver');
begin
  if p_points <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Invalid points amount');
  end if;

  if p_room_id is null or p_room_id = '' then
    return jsonb_build_object('success', false, 'reason', 'Invalid room ID');
  end if;

  -- ── Convert Inputs into Effective AP / XP ──
  -- Rule 1: Gold Gifts: 1 Gold Coin = 1 Gold XP
  -- Rule 2: Silver Gifts: 100 Silver Coins = 1 Normal AP (e.g., 100 Silver = 1 AP, 500 = 5 AP, 10,000 = 100 AP)
  -- Rule 3: Likes: 10 Likes = 1 Normal AP
  -- Rule 4: Room Stay: 3 Mins Stay = 1 Normal AP
  if v_is_gold_gift then
    v_effective_ap := p_points;
  elsif v_is_silver_gift then
    v_effective_ap := floor(p_points / 100.0)::integer;
    if v_effective_ap <= 0 and p_points >= 100 then
      v_effective_ap := 1;
    end if;
  elsif lower(p_source) = 'like' or lower(p_source) = 'likes' then
    v_effective_ap := greatest(1, floor(p_points / 10.0)::integer);
  elsif lower(p_source) = 'room_stay' or lower(p_source) = 'stay' then
    v_effective_ap := greatest(1, floor(p_points / 3.0)::integer);
  else
    v_effective_ap := p_points;
  end if;

  if v_effective_ap <= 0 then
    return jsonb_build_object('success', true, 'message', 'Amount below minimum AP threshold (e.g. requires min 100 silver coins)', 'added_ap', 0);
  end if;

  -- Ensure record exists for room
  insert into public.room_dual_progress (room_id, gold_points, gold_target, normal_points, normal_target, overflow_points, room_level)
  values (p_room_id, 0, 1000, 0, 700, 0, 1)
  on conflict (room_id) do nothing;

  -- Lock row FOR UPDATE to guarantee atomic state changes
  select * into v_record
  from public.room_dual_progress
  where room_id = p_room_id
  for update;

  v_gold_points := v_record.gold_points;
  v_gold_target := v_record.gold_target;
  v_normal_points := v_record.normal_points;
  v_normal_target := v_record.normal_target;
  v_overflow_points := v_record.overflow_points;
  v_room_level := v_record.room_level;

  if v_is_gold_gift then
    -- Rule 1 & 6: Gold Progress fills first, excess overflows into Normal Progress
    v_gold_space := greatest(0, v_gold_target - v_gold_points);
    if v_effective_ap <= v_gold_space then
      v_gold_points := v_gold_points + v_effective_ap;
      v_gold_added := v_effective_ap;
      v_overflow_added := 0;
    else
      v_gold_added := v_gold_space;
      v_gold_points := v_gold_target;
      v_overflow_added := v_effective_ap - v_gold_space;
    end if;

    if v_overflow_added > 0 then
      v_rem_overflow := v_overflow_added;
      v_overflow_points := v_overflow_points + v_overflow_added;

      v_normal_space := greatest(0, v_normal_target - v_normal_points);
      if v_rem_overflow <= v_normal_space then
        v_normal_points := v_normal_points + v_rem_overflow;
        v_normal_added := v_rem_overflow;
        v_rem_overflow := 0;
      else
        v_normal_added := v_normal_space;
        v_normal_points := v_normal_target;
        v_rem_overflow := v_rem_overflow - v_normal_space;

        -- Level upgrade loop when Normal Progress is full
        while v_rem_overflow > 0 loop
          v_did_level_up := true;
          v_room_level := v_room_level + 1;

          -- Dynamic Level Targets Matrix
          v_gold_target := case v_room_level
            when 1 then 1000
            when 2 then 2000
            when 3 then 3500
            when 4 then 5000
            when 5 then 10000
            else v_room_level * 2500
          end;

          v_normal_target := case v_room_level
            when 1 then 700
            when 2 then 1400
            when 3 then 2500
            when 4 then 4000
            when 5 then 7500
            else v_room_level * 2000
          end;

          v_gold_points := 0;
          v_normal_points := 0;

          -- Remaining gold overflow fills NEW level's Gold Bar first
          v_gold_space := v_gold_target;
          if v_rem_overflow <= v_gold_space then
            v_gold_points := v_rem_overflow;
            v_rem_overflow := 0;
          else
            v_gold_points := v_gold_target;
            v_rem_overflow := v_rem_overflow - v_gold_space;

            v_normal_space := v_normal_target;
            if v_rem_overflow <= v_normal_space then
              v_normal_points := v_rem_overflow;
              v_rem_overflow := 0;
            else
              v_normal_points := v_normal_target;
              v_rem_overflow := v_rem_overflow - v_normal_space;
            end if;
          end if;
        end loop;
      end if;
    end if;

  else
    -- Rule 2 & 5: Anti-Abuse (Silver Gifts, Likes, Room Stay CAN NEVER increase Gold Progress!)
    v_gold_added := 0;
    v_overflow_added := 0;

    v_normal_space := greatest(0, v_normal_target - v_normal_points);
    if v_effective_ap <= v_normal_space then
      v_normal_points := v_normal_points + v_effective_ap;
      v_normal_added := v_effective_ap;
    else
      v_normal_added := v_normal_space;
      v_normal_points := v_normal_target;
      v_rem_free := v_effective_ap - v_normal_space;

      while v_rem_free > 0 loop
        v_did_level_up := true;
        v_room_level := v_room_level + 1;

        v_gold_target := case v_room_level
          when 1 then 1000
          when 2 then 2000
          when 3 then 3500
          when 4 then 5000
          when 5 then 10000
          else v_room_level * 2500
        end;

        v_normal_target := case v_room_level
          when 1 then 700
          when 2 then 1400
          when 3 then 2500
          when 4 then 4000
          when 5 then 7500
          else v_room_level * 2000
        end;

        v_gold_points := 0;
        v_normal_points := 0;

        v_normal_space := v_normal_target;
        if v_rem_free <= v_normal_space then
          v_normal_points := v_rem_free;
          v_rem_free := 0;
        else
          v_normal_points := v_normal_target;
          v_rem_free := v_rem_free - v_normal_space;
        end if;
      end loop;
    end if;
  end if;

  -- 5. Save Atomic State Update
  update public.room_dual_progress
  set gold_points = v_gold_points,
      gold_target = v_gold_target,
      normal_points = v_normal_points,
      normal_target = v_normal_target,
      overflow_points = v_overflow_points,
      room_level = v_room_level,
      updated_at = timezone('utc'::text, now())
  where room_id = p_room_id;

  -- 6. Synchronize with Rooms Master Table
  update public.rooms
  set level = greatest(coalesce(level, 1), v_room_level),
      today_room_xp = coalesce(today_room_xp, 0) + v_effective_ap,
      room_xp = coalesce(room_xp, 0) + v_effective_ap,
      updated_at = timezone('utc'::text, now())
  where id = p_room_id;

  return jsonb_build_object(
    'success', true,
    'room_id', p_room_id,
    'gold_points', v_gold_points,
    'gold_xp', v_gold_points,
    'gold_target', v_gold_target,
    'normal_points', v_normal_points,
    'normal_ap', v_normal_points,
    'normal_target', v_normal_target,
    'overflow_points', v_overflow_points,
    'room_level', v_room_level,
    'did_level_up', v_did_level_up,
    'effective_ap_added', v_effective_ap,
    'gold_added', v_gold_added,
    'gold_overflow_added', v_overflow_added,
    'normal_added', v_normal_added,
    'source', p_source
  );
end;
$$ language plpgsql security definer;

-- 5. Update send_star_gift to integrate Dual Progress System
create or replace function public.send_star_gift_dual_wrapper(
  p_room_id text,
  p_user_id uuid,
  p_points integer,
  p_currency text
) returns jsonb as $$
begin
  return public.process_room_dual_progress(
    p_room_id,
    p_user_id,
    p_points,
    case when lower(p_currency) = 'gold' then 'gold_gift' else 'silver_gift' end
  );
end;
$$ language plpgsql security definer;
