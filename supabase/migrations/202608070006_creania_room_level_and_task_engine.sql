-- 202608070006_creania_room_level_and_task_engine.sql
-- Creania Room Level System (Levels 1-7), Daily/Gold/Team/Community Tasks, Treasure Box Rewards, and 04:00 AM Daily Reset RPCs

-- 1. Room Level Matrix Table & Configuration
create table if not exists public.room_level_matrix (
  level integer primary key,
  required_vp integer not null,
  max_co_owners integer not null,
  max_admins integer not null,
  max_host_seats integer not null,
  has_room_music boolean default true not null,
  has_showcase_badge boolean default false not null,
  has_permanent_chat_bubble boolean default false not null,
  title text not null,
  description text not null
);

-- Seed Level Matrix (Levels 1 to 7)
insert into public.room_level_matrix 
  (level, required_vp, max_co_owners, max_admins, max_host_seats, has_room_music, has_showcase_badge, has_permanent_chat_bubble, title, description)
values
  (1, 0, 1, 4, 4, true, false, false, 'Basic Arena', 'Basic background, basic announcement, normal daily tasks, arena music'),
  (2, 35500, 1, 7, 6, true, false, false, 'Premium Arena', 'Premium background, welcome banner, arena statistics, arena music'),
  (3, 59500, 2, 11, 8, true, true, false, 'Animated Arena', 'Animated arena frame, gift wall, showcase badge, arena music'),
  (4, 95000, 2, 14, 11, true, true, false, 'Dynamic Arena', 'Dynamic background, premium arena effects, event scheduler, arena music'),
  (5, 150000, 3, 16, 13, true, true, true, 'Official Arena', 'Official arena badge, permanent chat bubble, premium discovery, advanced analytics, arena music'),
  (6, 240000, 3, 18, 14, true, true, true, 'Luxury Arena', 'Luxury theme, animated entry, VIP arena features, arena music'),
  (7, 370000, 3, 20, 15, true, true, true, 'Legendary Arena', 'Legendary crown, exclusive backgrounds, highest discovery priority, official recommendation, arena music')
on conflict (level) do update set
  required_vp = excluded.required_vp,
  max_co_owners = excluded.max_co_owners,
  max_admins = excluded.max_admins,
  max_host_seats = excluded.max_host_seats,
  has_room_music = excluded.has_room_music,
  has_showcase_badge = excluded.has_showcase_badge,
  has_permanent_chat_bubble = excluded.has_permanent_chat_bubble,
  title = excluded.title,
  description = excluded.description;

-- 2. Daily & Team Tasks Schema
create table if not exists public.room_daily_task_catalog (
  task_key text primary key,
  category text not null check (category in ('normal', 'gold', 'team', 'community')),
  title text not null,
  description text not null,
  target_value integer not null default 1,
  min_active_members integer default 1 not null,
  vp_reward integer default 50 not null,
  coin_reward integer default 0 not null,
  silver_reward integer default 0 not null,
  treasure_box_tier text default 'normal' not null check (treasure_box_tier in ('normal', 'gold', 'room', 'legendary')),
  icon_name text default 'task' not null
);

-- Seed Task Catalog
insert into public.room_daily_task_catalog
  (task_key, category, title, description, target_value, min_active_members, vp_reward, coin_reward, silver_reward, treasure_box_tier, icon_name)
values
  -- Normal Tasks
  ('normal_login', 'normal', 'Login Today', 'Log into Creania app today', 1, 1, 50, 10, 50, 'normal', 'login'),
  ('normal_stay_15m', 'normal', 'Stay 15 Minutes', 'Stay inside any room for 15 minutes', 15, 1, 75, 15, 100, 'normal', 'timer'),
  ('normal_stay_30m', 'normal', 'Stay 30 Minutes', 'Stay inside any room for 30 minutes', 30, 1, 150, 30, 200, 'normal', 'timer_full'),
  ('normal_join_1', 'normal', 'Join 1 Room', 'Visit 1 voice room today', 1, 1, 30, 5, 30, 'normal', 'door'),
  ('normal_join_3', 'normal', 'Join 3 Rooms', 'Explore 3 different voice rooms today', 3, 1, 90, 15, 90, 'normal', 'explore'),
  ('normal_send_1_silver', 'normal', 'Send 1 Silver Gift', 'Send 1 silver coin gift', 1, 1, 20, 5, 20, 'normal', 'gift_silver'),
  ('normal_send_5_silver', 'normal', 'Send 5 Silver Gifts', 'Send 5 silver coin gifts', 5, 1, 100, 20, 100, 'normal', 'gift_silver_stack'),
  ('normal_send_1_gold', 'normal', 'Send 1 Gold Gift', 'Send 1 gold coin gift', 1, 1, 100, 50, 0, 'normal', 'gift_gold'),
  ('normal_receive_1_gift', 'normal', 'Receive 1 Gift', 'Receive any gift on mic', 1, 1, 60, 10, 50, 'normal', 'gift_received'),
  ('normal_chat_20', 'normal', 'Send 20 Chat Messages', 'Chat 20 times in voice room', 20, 1, 40, 10, 40, 'normal', 'chat'),
  ('normal_follow_user', 'normal', 'Follow 1 User', 'Follow a new friend in room', 1, 1, 30, 5, 30, 'normal', 'person_add'),
  ('normal_invite_friend', 'normal', 'Invite 1 Friend', 'Invite a friend into room', 1, 1, 50, 10, 50, 'normal', 'share'),
  ('normal_mic_10m', 'normal', 'Sit on Mic 10 Mins', 'Speak/sit on mic for 10 minutes', 10, 1, 120, 25, 100, 'normal', 'mic'),
  ('normal_music_20m', 'normal', 'Listen to Music 20 Mins', 'Enjoy room music for 20 minutes', 20, 1, 80, 15, 80, 'normal', 'music'),

  -- Gold Tasks
  ('gold_send_10', 'gold', 'Send 10 Gold', 'Send 10 Gold Coins in gifts', 10, 1, 300, 100, 0, 'gold', 'gold_stack'),
  ('gold_send_50', 'gold', 'Send 50 Gold', 'Send 50 Gold Coins in gifts', 50, 1, 1500, 500, 0, 'gold', 'gold_chest'),
  ('gold_send_100', 'gold', 'Send 100 Gold', 'Send 100 Gold Coins in gifts', 100, 1, 3500, 1200, 0, 'gold', 'gold_vault'),
  ('gold_premium_gift', 'gold', 'Send Premium Gift', 'Send any luxury premium gift', 1, 1, 1000, 300, 0, 'gold', 'diamond'),
  ('gold_support_3_hosts', 'gold', 'Support 3 Hosts', 'Send gold gifts to 3 different hosts', 3, 1, 800, 250, 0, 'gold', 'stars'),
  ('gold_spend_500', 'gold', 'Spend 500 Gold Today', 'Reach 500 gold spent in room', 500, 1, 15000, 5000, 0, 'gold', 'crown'),
  ('gold_lucky_box', 'gold', 'Win Gold Lucky Box', 'Open and win a gold lucky box', 1, 1, 2000, 600, 0, 'gold', 'treasure_chest'),
  ('gold_combo', 'gold', 'Complete Gold Combo', 'Trigger a 10x gift combo', 1, 1, 1200, 400, 0, 'gold', 'lightning'),

  -- Room Team Tasks (Dynamic Scaling)
  ('team_3_stay_20m', 'team', 'Stay Together 20 Mins', '3 active members stay together 20 mins', 20, 3, 500, 100, 500, 'room', 'users_3'),
  ('team_5_send_20_gifts', 'team', 'Send 20 Gifts', '5 active members send 20 gifts total', 20, 5, 1200, 250, 1000, 'room', 'users_5'),
  ('team_8_mic_30m', 'team', 'Active Mic 30 Mins', '8 active members occupy mic for 30 mins', 30, 8, 3000, 600, 2000, 'room', 'users_8'),
  ('team_10_recv_100_gifts', 'team', 'Room Receives 100 Gifts', '10 active members receive 100 gifts', 100, 10, 7000, 1500, 5000, 'room', 'users_10'),
  ('team_15_pk_victory', 'team', 'Complete PK Victory', '15 members participate & win room PK', 1, 15, 15000, 3000, 10000, 'legendary', 'swords'),
  ('team_20_stay_45m', 'team', 'Stay Active 45 Mins', '20 active members stay active for 45 mins', 45, 20, 35000, 8000, 25000, 'legendary', 'fire'),

  -- Community Tasks
  ('community_50_joins', 'community', '50 Unique Room Joins', '50 unique users join room today', 50, 1, 2500, 500, 2500, 'room', 'community_join'),
  ('community_10_followers', 'community', '10 New Room Followers', 'Gain 10 new followers for room today', 10, 1, 1500, 300, 1500, 'room', 'community_follow'),
  ('community_3h_active', 'community', 'Room Active 3 Hours', 'Keep room active for 3 hours today', 180, 1, 5000, 1000, 5000, 'room', 'community_time'),
  ('community_1000_gold_recv', 'community', 'Hosts Receive 1,000 Gold', 'Hosts collectively receive 1,000 Gold today', 1000, 1, 25000, 5000, 10000, 'legendary', 'community_gold')
on conflict (task_key) do update set
  category = excluded.category,
  title = excluded.title,
  description = excluded.description,
  target_value = excluded.target_value,
  min_active_members = excluded.min_active_members,
  vp_reward = excluded.vp_reward,
  coin_reward = excluded.coin_reward,
  silver_reward = excluded.silver_reward,
  treasure_box_tier = excluded.treasure_box_tier,
  icon_name = excluded.icon_name;

-- 3. User Daily Task Progress Table
create table if not exists public.user_daily_task_progress (
  user_id uuid references public.profiles(id) on delete cascade not null,
  task_key text references public.room_daily_task_catalog(task_key) on delete cascade not null,
  current_value integer default 0 not null,
  is_completed boolean default false not null,
  is_claimed boolean default false not null,
  task_date date default ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (user_id, task_key, task_date)
);

-- 4. Room Team & Community Task Progress Table
create table if not exists public.room_team_task_progress (
  room_id text references public.rooms(id) on delete cascade not null,
  task_key text references public.room_daily_task_catalog(task_key) on delete cascade not null,
  current_value integer default 0 not null,
  active_members_count integer default 0 not null,
  is_completed boolean default false not null,
  task_date date default ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, task_key, task_date)
);

-- 5. User Unlocked Perks Table (Avatar Frames, Showcase Badges, Chat Bubbles)
create table if not exists public.user_unlocked_perks (
  user_id uuid references public.profiles(id) on delete cascade not null,
  perk_type text not null check (perk_type in ('avatar_frame', 'showcase_badge', 'chat_bubble')),
  perk_id text not null,
  source_level integer default 1 not null,
  is_permanent boolean default true not null,
  unlocked_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (user_id, perk_type, perk_id)
);

-- 6. Core RPC Functions

-- A. Add Room VP Function (Calculates VP, handles level upgrades)
create or replace function public.add_room_vp(
  p_room_id text,
  p_vp integer,
  p_source text
)
returns jsonb as $$
declare
  v_old_xp integer := 0;
  v_new_xp integer := 0;
  v_old_level integer := 1;
  v_new_level integer := 1;
  v_did_upgrade boolean := false;
  v_owner_id uuid;
begin
  if p_vp <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Invalid VP amount');
  end if;

  select host_id into v_owner_id from public.rooms where id = p_room_id;
  
  -- Ensure level progress entry exists
  insert into public.room_level_progress (room_id, current_level, current_xp)
  values (p_room_id, 1, 0)
  on conflict (room_id) do nothing;

  select current_xp, current_level into v_old_xp, v_old_level
  from public.room_level_progress
  where room_id = p_room_id;

  v_new_xp := v_old_xp + p_vp;

  -- Determine level based on room_level_matrix
  select level into v_new_level
  from public.room_level_matrix
  where required_vp <= v_new_xp
  order by level desc
  limit 1;

  if v_new_level is null then
    v_new_level := 1;
  end if;

  if v_new_level > v_old_level then
    v_did_upgrade := true;
  end if;

  update public.room_level_progress
  set current_xp = v_new_xp,
      current_level = v_new_level
  where room_id = p_room_id;

  update public.rooms
  set room_xp = v_new_xp,
      level = v_new_level,
      today_room_xp = today_room_xp + p_vp
  where id = p_room_id;

  -- Unlock Perks if owner exists
  if v_owner_id is not null then
    -- Frame for current level
    insert into public.user_unlocked_perks (user_id, perk_type, perk_id, source_level, is_permanent)
    values (v_owner_id, 'avatar_frame', 'room_level_frame_' || v_new_level, v_new_level, true)
    on conflict (user_id, perk_type, perk_id) do nothing;

    -- Showcase badge if Level >= 3
    if v_new_level >= 3 then
      insert into public.user_unlocked_perks (user_id, perk_type, perk_id, source_level, is_permanent)
      values (v_owner_id, 'showcase_badge', 'room_showcase_level_' || v_new_level, v_new_level, true)
      on conflict (user_id, perk_type, perk_id) do nothing;
    end if;

    -- Permanent Chat Bubble if Level >= 5
    if v_new_level >= 5 then
      insert into public.user_unlocked_perks (user_id, perk_type, perk_id, source_level, is_permanent)
      values (v_owner_id, 'chat_bubble', 'room_bubble_level_' || v_new_level, v_new_level, true)
      on conflict (user_id, perk_type, perk_id) do nothing;
    end if;
  end if;

  return jsonb_build_object(
    'success', true,
    'room_id', p_room_id,
    'added_vp', p_vp,
    'new_total_vp', v_new_xp,
    'old_level', v_old_level,
    'new_level', v_new_level,
    'did_upgrade', v_did_upgrade
  );
end;
$$ language plpgsql security definer;

-- B. Claim Treasure Box Reward RPC
create or replace function public.claim_treasure_box_reward(
  p_box_tier text
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_coins integer := 0;
  v_vp integer := 0;
  v_silver integer := 0;
  v_keys integer := 0;
begin
  if v_user_id is null then
    raise exception 'Unauthenticated user';
  end if;

  case p_box_tier
    when 'normal' then
      v_coins := 50 + (floor(random() * 50))::integer;
      v_silver := 200 + (floor(random() * 200))::integer;
      v_vp := 100 + (floor(random() * 100))::integer;
      v_keys := 1;
    when 'gold' then
      v_coins := 300 + (floor(random() * 300))::integer;
      v_silver := 1000 + (floor(random() * 500))::integer;
      v_vp := 500 + (floor(random() * 500))::integer;
      v_keys := 3;
    when 'room' then
      v_coins := 1000 + (floor(random() * 1000))::integer;
      v_silver := 3000 + (floor(random() * 2000))::integer;
      v_vp := 2000 + (floor(random() * 1000))::integer;
      v_keys := 5;
    when 'legendary' then
      v_coins := 5000 + (floor(random() * 5000))::integer;
      v_silver := 10000 + (floor(random() * 5000))::integer;
      v_vp := 10000 + (floor(random() * 5000))::integer;
      v_keys := 10;
    else
      raise exception 'Invalid chest tier';
  end case;

  update public.profiles
  set gold_coins = gold_coins + v_coins,
      silver_coins = silver_coins + v_silver
  where id = v_user_id;

  return jsonb_build_object(
    'success', true,
    'box_tier', p_box_tier,
    'coins_earned', v_coins,
    'silver_earned', v_silver,
    'vp_earned', v_vp,
    'lucky_keys_earned', v_keys
  );
end;
$$ language plpgsql security definer;

-- C. Daily Reset Function at 04:00 AM Local Time
create or replace function public.reset_room_daily_tasks()
returns void as $$
begin
  -- Reset daily room statistics (today_room_xp, today_visitors, etc.)
  update public.rooms
  set today_room_xp = 0;

  update public.room_statistics
  set today_visitors = 0,
      today_silver_coins = 0,
      today_gold_coins = 0,
      today_task_points = 0,
      today_extra_xp_points = 0,
      updated_at = now();
end;
$$ language plpgsql security definer;

-- Realtime Publications
do $$
begin
  alter publication supabase_realtime add table public.user_daily_task_progress;
exception when others then
  raise notice 'Table user_daily_task_progress already in supabase_realtime publication';
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.user_unlocked_perks;
exception when others then
  raise notice 'Table user_unlocked_perks already in supabase_realtime publication';
end;
$$;
