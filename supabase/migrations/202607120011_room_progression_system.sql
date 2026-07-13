-- Migration: Room Progression System
-- Created At: 2026-07-12T21:30:50Z

-- 1. Create room_levels table
create table public.room_levels (
  level integer primary key,
  name text not null,
  xp_required bigint not null,
  badge_url text
);

-- Prepopulate levels 1 to 7
insert into public.room_levels (level, name, xp_required) values
(1, 'New Room', 0),
(2, 'Growing Room', 12000),      -- 30 days of 400 XP average
(3, 'Active Room', 48000),       -- 120 days
(4, 'Popular Room', 120000),     -- 300 days
(5, 'Elite Room', 264000),       -- 660 days
(6, 'Legendary Room', 624000),   -- 1560 days
(7, 'Hall of Fame Room', 1200000); -- 3000 days

-- 2. Create room_level_progress table
create table public.room_level_progress (
  room_id text primary key references public.rooms(id) on delete cascade not null,
  current_level integer not null default 1 references public.room_levels(level),
  current_xp bigint not null default 0,
  consecutive_days_completed integer not null default 0,
  last_completed_date date,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. Create room_xp table for XP logging
create table public.room_xp (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  amount integer not null,
  source text not null, -- 'task', 'gift'
  details text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 4. Create room_daily_tasks table
create table public.room_daily_tasks (
  task_key text primary key,
  description text not null,
  target_value integer not null,
  task_points integer not null,
  xp_reward integer not null,
  silver_reward integer not null,
  gold_reward integer not null default 0
);

-- Prepopulate room daily tasks
insert into public.room_daily_tasks (task_key, description, target_value, task_points, xp_reward, silver_reward, gold_reward) values
('speak_5m', 'Speak 5 minutes in room', 300, 20, 10, 20, 0), -- target values in seconds/counts
('speak_20m', 'Speak 20 minutes in room', 1200, 50, 25, 40, 0),
('stay_10m', 'Stay in room for 10 minutes', 600, 25, 15, 20, 0),
('stay_30m', 'Stay in room for 30 minutes', 1800, 60, 35, 40, 0),
('active_members_4', 'Keep 4 active members for 10 minutes', 600, 100, 50, 75, 0),
('new_user_10m', 'New user joins and stays 10 minutes', 600, 40, 20, 30, 0),
('chat_100', 'Receive 100 chat messages', 100, 50, 30, 40, 0),
('reactions_200', 'Receive 200 reactions', 200, 40, 25, 30, 0),
('share', 'Share room with others', 1, 40, 20, 20, 0),
('receive_silver_2500', 'Receive 2500 Silver Coin gifts on seats', 2500, 150, 60, 0, 2),
('receive_silver_5000', 'Receive 5000 Silver Coin gifts', 5000, 250, 100, 0, 5),
('receive_gold_15000', 'Receive 15000 Gold Coin gifts', 15000, 300, 150, 0, 20),
('send_silver_20000', 'Send 20000 Silver Coin gifts', 20000, 120, 50, 0, 2),
('send_gold_50', 'Send 50 Gold Coin gifts', 50, 180, 80, 0, 5),
('complete_all', 'Complete all daily room tasks', 1, 275, 200, 250, 0);

-- 5. Create room_daily_task_progress table
create table public.room_daily_task_progress (
  room_id text references public.rooms(id) on delete cascade not null,
  task_key text references public.room_daily_tasks(task_key) on delete cascade not null,
  current_value integer not null default 0,
  is_completed boolean not null default false,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, task_key)
);

-- 6. Create room_rewards table
create table public.room_rewards (
  id text primary key,
  name text not null,
  description text,
  reward_type text not null, -- 'silver_coins', 'gold_coins', 'chest'
  value integer not null
);

-- 7. Create room_reward_history table
create table public.room_reward_history (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  reward_type text not null,
  amount integer not null,
  details text,
  claimed_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 8. Create room_seats table
create table public.room_seats (
  room_id text references public.rooms(id) on delete cascade not null,
  seat_index integer not null check (seat_index >= 0 and seat_index < 10),
  user_id uuid references public.profiles(id) on delete set null,
  is_locked boolean not null default false,
  role text not null default 'Listener',
  primary key (room_id, seat_index)
);

-- 9. Create room_seat_gifts table
create table public.room_seat_gifts (
  room_id text references public.rooms(id) on delete cascade not null,
  seat_index integer not null check (seat_index >= 0 and seat_index < 10),
  silver_gift_count integer not null default 0,
  primary key (room_id, seat_index)
);

-- 10. Create room_member_heartbeats table for secure duration tracking
create table public.room_member_heartbeats (
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  last_seen_at timestamp with time zone default timezone('utc'::text, now()) not null,
  is_speaking boolean not null default false,
  accumulated_stay_today integer not null default 0, -- in seconds
  accumulated_speak_today integer not null default 0, -- in seconds
  primary key (room_id, user_id)
);

-- 11. Create room_statistics table
create table public.room_statistics (
  room_id text primary key references public.rooms(id) on delete cascade not null,
  total_visitors bigint not null default 0,
  today_visitors integer not null default 0,
  today_silver_coins integer not null default 0,
  today_gold_coins integer not null default 0,
  today_task_points integer not null default 0,
  today_extra_xp_points integer not null default 0, -- from gold coin extra tasks
  last_heartbeat_at timestamp with time zone,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 12. Create room_reputation table
create table public.room_reputation (
  room_id text primary key references public.rooms(id) on delete cascade not null,
  reputation_score integer not null default 0,
  likes integer not null default 0,
  shares integer not null default 0
);

-- 13. Create room_followers table
create table public.room_followers (
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, user_id)
);

-- 14. Create room_entry_effects table
create table public.room_entry_effects (
  id text primary key,
  name text not null,
  effect_type text not null,
  asset_url text
);

-- 15. Create room_voice_effects table
create table public.room_voice_effects (
  id text primary key,
  name text not null,
  effect_type text not null,
  asset_url text
);

-- 16. Create room_gift_statistics table
create table public.room_gift_statistics (
  room_id text primary key references public.rooms(id) on delete cascade not null,
  total_silver_received bigint not null default 0,
  total_gold_received bigint not null default 0,
  total_silver_sent bigint not null default 0,
  total_gold_sent bigint not null default 0
);


-- RLS Policies Enabling
alter table public.room_levels enable row level security;
alter table public.room_level_progress enable row level security;
alter table public.room_xp enable row level security;
alter table public.room_daily_tasks enable row level security;
alter table public.room_daily_task_progress enable row level security;
alter table public.room_rewards enable row level security;
alter table public.room_reward_history enable row level security;
alter table public.room_seats enable row level security;
alter table public.room_seat_gifts enable row level security;
alter table public.room_member_heartbeats enable row level security;
alter table public.room_statistics enable row level security;
alter table public.room_reputation enable row level security;
alter table public.room_followers enable row level security;
alter table public.room_entry_effects enable row level security;
alter table public.room_voice_effects enable row level security;
alter table public.room_gift_statistics enable row level security;

-- Read policies for everyone
create policy "Allow read access to room levels for everyone" on public.room_levels for select using (true);
create policy "Allow read access to room level progress for everyone" on public.room_level_progress for select using (true);
create policy "Allow read access to room xp for everyone" on public.room_xp for select using (true);
create policy "Allow read access to room daily tasks for everyone" on public.room_daily_tasks for select using (true);
create policy "Allow read access to room daily task progress for everyone" on public.room_daily_task_progress for select using (true);
create policy "Allow read access to room rewards for everyone" on public.room_rewards for select using (true);
create policy "Allow read access to room reward history for everyone" on public.room_reward_history for select using (true);
create policy "Allow read access to room seats for everyone" on public.room_seats for select using (true);
create policy "Allow read access to room seat gifts for everyone" on public.room_seat_gifts for select using (true);
create policy "Allow read access to room statistics for everyone" on public.room_statistics for select using (true);
create policy "Allow read access to room reputation for everyone" on public.room_reputation for select using (true);
create policy "Allow read access to room followers for everyone" on public.room_followers for select using (true);
create policy "Allow read access to room entry effects for everyone" on public.room_entry_effects for select using (true);
create policy "Allow read access to room voice effects for everyone" on public.room_voice_effects for select using (true);
create policy "Allow read access to room gift statistics for everyone" on public.room_gift_statistics for select using (true);

-- Insert policies for authenticated users
create policy "Allow auth follow room" on public.room_followers for insert with check (auth.uid() = user_id);
create policy "Allow auth unfollow room" on public.room_followers for delete using (auth.uid() = user_id);


-- 17. TRIGGER: Initialize new room data
create or replace function public.handle_new_room_progression()
returns trigger as $$
begin
  -- Initialize level progress
  insert into public.room_level_progress (room_id, current_level, current_xp)
  values (new.id, 1, 0);

  -- Initialize statistics
  insert into public.room_statistics (room_id)
  values (new.id);

  -- Initialize reputation
  insert into public.room_reputation (room_id)
  values (new.id);

  -- Initialize gift statistics
  insert into public.room_gift_statistics (room_id)
  values (new.id);

  -- Initialize 10 empty seats
  for i in 0..9 loop
    insert into public.room_seats (room_id, seat_index, role)
    values (new.id, i, case when i = 0 then 'Host' else 'Listener' end);
    
    insert into public.room_seat_gifts (room_id, seat_index, silver_gift_count)
    values (new.id, i, 0);
  end loop;

  return new;
end;
$$ language plpgsql security definer;

create trigger on_room_created_progression
  after insert on public.rooms
  for each row execute procedure public.handle_new_room_progression();


-- 18. RPC FUNCTION: heartbeat_room_member
create or replace function public.heartbeat_room_member(
  p_room_id text,
  p_is_speaking boolean
)
returns void as $$
declare
  v_user_id uuid := auth.uid();
  v_last_seen timestamp with time zone;
  v_elapsed integer;
  v_stay_added integer := 0;
  v_speak_added integer := 0;
  v_active_member_seconds integer := 0;
  v_active_count integer;
begin
  if v_user_id is null then
    raise exception 'Unauthenticated user';
  end if;

  -- 1. Check if user is a member of the room
  if not exists (select 1 from public.room_members where room_id = p_room_id and user_id = v_user_id) then
    return;
  end if;

  -- 2. Fetch last seen time
  select last_seen_at into v_last_seen
  from public.room_member_heartbeats
  where room_id = p_room_id and user_id = v_user_id;

  if v_last_seen is not null then
    -- Calculate elapsed seconds
    v_elapsed := extract(epoch from (now() - v_last_seen))::integer;
    -- Cap elapsed to prevent fake spoof intervals (between 2 and 45 seconds)
    if v_elapsed >= 2 and v_elapsed <= 45 then
      v_stay_added := v_elapsed;
      if p_is_speaking then
        v_speak_added := v_elapsed;
      end if;
    end if;
  end if;

  -- 3. Upsert heartbeat log
  insert into public.room_member_heartbeats (room_id, user_id, last_seen_at, is_speaking, accumulated_stay_today, accumulated_speak_today)
  values (p_room_id, v_user_id, now(), p_is_speaking, coalesce(v_stay_added, 0), coalesce(v_speak_added, 0))
  on conflict (room_id, user_id) do update set
    last_seen_at = excluded.last_seen_at,
    is_speaking = excluded.is_speaking,
    accumulated_stay_today = case when (now()::date > room_member_heartbeats.last_seen_at::date) then 0 else room_member_heartbeats.accumulated_stay_today + coalesce(v_stay_added, 0) end,
    accumulated_speak_today = case when (now()::date > room_member_heartbeats.last_seen_at::date) then 0 else room_member_heartbeats.accumulated_speak_today + coalesce(v_speak_added, 0) end;

  -- Update global statistics heartbeat timer
  update public.room_statistics
  set last_heartbeat_at = now()
  where room_id = p_room_id;

  -- 4. Dynamic stay/speaking progressions triggers
  if v_stay_added > 0 then
    -- Stay tasks progress update
    perform public.increment_room_task_progress(p_room_id, 'stay_10m', v_stay_added);
    perform public.increment_room_task_progress(p_room_id, 'stay_30m', v_stay_added);

    -- Calculate active member durations (>= 4 active users in past 45 seconds)
    select count(distinct user_id) into v_active_count
    from public.room_member_heartbeats
    where room_id = p_room_id and last_seen_at >= (now() - interval '45 seconds');

    if v_active_count >= 4 then
      perform public.increment_room_task_progress(p_room_id, 'active_members_4', v_stay_added);
    end if;
  end if;

  if v_speak_added > 0 then
    -- Speak tasks progress update
    perform public.increment_room_task_progress(p_room_id, 'speak_5m', v_speak_added);
    perform public.increment_room_task_progress(p_room_id, 'speak_20m', v_speak_added);
  end if;
end;
$$ language plpgsql security definer;


-- 19. RPC FUNCTION: increment_room_task_progress
create or replace function public.increment_room_task_progress(
  p_room_id text,
  p_task_key text,
  p_increment integer
)
returns void as $$
declare
  v_target integer;
  v_task_points integer;
  v_xp_reward integer;
  v_silver_reward integer;
  v_gold_reward integer;
  
  v_current_val integer;
  v_is_completed boolean;
  
  v_today_points integer;
  v_today_silver integer;
  v_allowed_points integer;
  v_allowed_silver integer;
  
  v_chest_reward boolean := false;
begin
  -- Fetch task configurations
  select target_value, task_points, xp_reward, silver_reward, gold_reward
  into v_target, v_task_points, v_xp_reward, v_silver_reward, v_gold_reward
  from public.room_daily_tasks
  where task_key = p_task_key;

  if v_target is null then
    return;
  end if;

  -- Get current room stats limits
  select today_task_points, today_silver_coins
  into v_today_points, v_today_silver
  from public.room_statistics
  where room_id = p_room_id;

  if v_today_points is null then
    v_today_points := 0;
    v_today_silver := 0;
  end if;

  -- Check if already completed
  select current_value, is_completed into v_current_val, v_is_completed
  from public.room_daily_task_progress
  where room_id = p_room_id and task_key = p_task_key;

  if v_current_val is null then
    v_current_val := 0;
    v_is_completed := false;
    insert into public.room_daily_task_progress(room_id, task_key, current_value, is_completed)
    values (p_room_id, p_task_key, 0, false);
  end if;

  if v_is_completed then
    return; -- No updates for completed tasks
  end if;

  -- Increment current value
  v_current_val := v_current_val + p_increment;
  if v_current_val >= v_target then
    v_current_val := v_target;
    v_is_completed := true;
  end if;

  -- Update task progress
  update public.room_daily_task_progress
  set current_value = v_current_val,
      is_completed = v_is_completed,
      updated_at = now()
  where room_id = p_room_id and task_key = p_task_key;

  -- If completed, reward point computations
  if v_is_completed then
    -- Check caps (max 1200 points per day)
    v_allowed_points := least(v_task_points, 1200 - v_today_points);
    v_allowed_silver := least(v_silver_reward, 1200 - v_today_silver);

    if v_allowed_points > 0 then
      -- Add points and stats
      update public.room_statistics
      set today_task_points = today_task_points + v_allowed_points,
          today_silver_coins = today_silver_coins + v_allowed_silver,
          today_gold_coins = today_gold_coins + v_gold_reward,
          updated_at = now()
      where room_id = p_room_id;

      -- Add XP to room
      perform public.add_room_xp(p_room_id, v_xp_reward, 'task', 'Completed task: ' || p_task_key);

      -- Award coins to the room owner (host)
      if v_allowed_silver > 0 or v_gold_reward > 0 then
        update public.wallets
        set coins_balance = coins_balance + v_allowed_silver
        where id = (select host_id from public.rooms where id = p_room_id);
      end if;
    end if;

    -- Check if all 14 standard tasks are completed to award "complete_all"
    if p_task_key != 'complete_all' then
      if not exists (
        select 1 from public.room_daily_tasks t
        where t.task_key != 'complete_all'
        and not exists (
          select 1 from public.room_daily_task_progress p
          where p.room_id = p_room_id and p.task_key = t.task_key and p.is_completed = true
        )
      ) then
        -- Automatically complete the complete_all milestone!
        perform public.increment_room_task_progress(p_room_id, 'complete_all', 1);
      end if;
    end if;
  end if;
end;
$$ language plpgsql security definer;


-- 20. RPC FUNCTION: add_room_xp
create or replace function public.add_room_xp(
  p_room_id text,
  p_amount integer,
  p_source text,
  p_details text
)
returns void as $$
declare
  v_current_xp bigint;
  v_current_level integer;
  v_next_xp bigint;
begin
  -- 1. Insert into room_xp ledger log
  insert into public.room_xp (room_id, amount, source, details)
  values (p_room_id, p_amount, p_source, p_details);

  -- 2. Fetch current level details
  select current_level, current_xp
  into v_current_level, v_current_xp
  from public.room_level_progress
  where room_id = p_room_id;

  if v_current_xp is null then
    v_current_xp := 0;
    v_current_level := 1;
  end if;

  v_current_xp := v_current_xp + p_amount;

  -- 3. Check level ups
  while v_current_level < 7 loop
    select xp_required into v_next_xp
    from public.room_levels
    where level = v_current_level + 1;

    if v_current_xp >= v_next_xp then
      v_current_level := v_current_level + 1;
      -- Log level up event
      insert into public.room_activity_logs (room_id, user_id, action_type, details)
      values (p_room_id, (select host_id from public.rooms where id = p_room_id), 'level_up', 'Room leveled up to Level ' || v_current_level);
    else
      exit;
    end if;
  end loop;

  -- 4. Update level progress
  update public.room_level_progress
  set current_level = v_current_level,
      current_xp = v_current_xp,
      updated_at = now()
  where room_id = p_room_id;
end;
$$ language plpgsql security definer;


-- 21. RPC FUNCTION: send_room_gift
create or replace function public.send_room_gift(
  p_room_id text,
  p_seat_index integer,
  p_amount integer,
  p_is_gold boolean
)
returns void as $$
declare
  v_sender_id uuid := auth.uid();
  v_host_id uuid;
  v_receiver_id uuid;
  
  v_allowed_extra_xp integer;
  v_today_extra_xp integer;
  v_today_points integer;
begin
  if v_sender_id is null then
    raise exception 'Unauthenticated';
  end if;

  -- Fetch room host
  select host_id into v_host_id from public.rooms where id = p_room_id;

  -- Fetch occupant user of seat
  select user_id into v_receiver_id
  from public.room_seats
  where room_id = p_room_id and seat_index = p_seat_index;

  -- 1. Deduct coins from sender wallet
  if p_is_gold then
    update public.wallets
    set coins_balance = coins_balance - p_amount
    where id = v_sender_id;
  else
    update public.wallets
    set coins_balance = coins_balance - p_amount
    where id = v_sender_id;
  end if;

  -- 2. Increment seat silver counter (if silver)
  if not p_is_gold then
    update public.room_seat_gifts
    set silver_gift_count = silver_gift_count + p_amount
    where room_id = p_room_id and seat_index = p_seat_index;
  end if;

  -- 3. Update gift statistics
  update public.room_gift_statistics
  set total_silver_received = total_silver_received + (case when p_is_gold then 0 else p_amount end),
      total_gold_received = total_gold_received + (case when p_is_gold then p_amount else 0 end),
      total_silver_sent = total_silver_sent + (case when v_sender_id = v_host_id and not p_is_gold then p_amount else 0 end) -- Tracks sender stats
  where room_id = p_room_id;

  -- 4. Update task progressions
  if p_is_gold then
    -- Send gold tasks
    if v_sender_id = v_host_id then
      perform public.increment_room_task_progress(p_room_id, 'send_gold_50', p_amount);
    end if;
    -- Receive gold tasks
    perform public.increment_room_task_progress(p_room_id, 'receive_gold_15000', p_amount);

    -- EXTRA TASK SYSTEM: 1 Gold Coin = 1 extra Task Point & 1 extra XP (up to 1200 extra points per day)
    select today_extra_xp_points, today_task_points into v_today_extra_xp, v_today_points
    from public.room_statistics
    where room_id = p_room_id;

    if v_today_points >= 1200 then
      v_allowed_extra_xp := least(p_amount, 1200 - v_today_extra_xp);
      if v_allowed_extra_xp > 0 then
        update public.room_statistics
        set today_extra_xp_points = today_extra_xp_points + v_allowed_extra_xp,
            today_task_points = today_task_points + v_allowed_extra_xp,
            updated_at = now()
        where room_id = p_room_id;

        perform public.add_room_xp(p_room_id, v_allowed_extra_xp, 'gold_gift_extra', 'Extra gold coin boost');
      end if;
    end if;
  else
    -- Silver gifting tasks
    if v_sender_id = v_host_id then
      perform public.increment_room_task_progress(p_room_id, 'send_silver_20000', p_amount);
    end if;
    
    perform public.increment_room_task_progress(p_room_id, 'receive_silver_2500', p_amount);
    perform public.increment_room_task_progress(p_room_id, 'receive_silver_5000', p_amount);
  end if;
end;
$$ language plpgsql security definer;


-- 22. RPC FUNCTION: join_room_seat
create or replace function public.join_room_seat(
  p_room_id text,
  p_seat_index integer
)
returns void as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Unauthenticated';
  end if;

  -- Reset occupant on other seats if they occupied one
  update public.room_seats
  set user_id = null
  where room_id = p_room_id and user_id = v_user_id;

  -- Occupy new seat
  update public.room_seats
  set user_id = v_user_id
  where room_id = p_room_id and seat_index = p_seat_index;

  -- Reset seat counter to 0
  update public.room_seat_gifts
  set silver_gift_count = 0
  where room_id = p_room_id and seat_index = p_seat_index;
end;
$$ language plpgsql security definer;


-- 23. RPC FUNCTION: leave_room_seat
create or replace function public.leave_room_seat(
  p_room_id text,
  p_seat_index integer
)
returns void as $$
begin
  update public.room_seats
  set user_id = null
  where room_id = p_room_id and seat_index = p_seat_index;

  -- Reset counter immediately to 0
  update public.room_seat_gifts
  set silver_gift_count = 0
  where room_id = p_room_id and seat_index = p_seat_index;
end;
$$ language plpgsql security definer;


-- 24. CRON-SIMULATED FUNCTION: reset_room_daily_progress
create or replace function public.reset_room_daily_progress()
returns void as $$
begin
  -- Update streaks for rooms completing tasks
  update public.room_level_progress p
  set consecutive_days_completed = case 
        when (select today_task_points from public.room_statistics s where s.room_id = p.room_id) >= 1200 then consecutive_days_completed + 1
        else 0
      end,
      last_completed_date = case 
        when (select today_task_points from public.room_statistics s where s.room_id = p.room_id) >= 1200 then now()::date
        else last_completed_date
      end;

  -- Reset statistics counters
  update public.room_statistics
  set today_visitors = 0,
      today_silver_coins = 0,
      today_gold_coins = 0,
      today_task_points = 0,
      today_extra_xp_points = 0,
      updated_at = now();

  -- Reset tasks values
  update public.room_daily_task_progress
  set current_value = 0,
      is_completed = false,
      updated_at = now();
end;
$$ language plpgsql security definer;


-- Enable Realtime for progression sync
alter publication supabase_realtime add table public.room_level_progress;
alter publication supabase_realtime add table public.room_daily_task_progress;
alter publication supabase_realtime add table public.room_seats;
alter publication supabase_realtime add table public.room_seat_gifts;
alter publication supabase_realtime add table public.room_statistics;
