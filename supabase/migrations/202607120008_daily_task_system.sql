-- supabase/migrations/202607120008_daily_task_system.sql
-- Complete Backend-driven Daily Task & Level Progression System

-- 1. Create career_tasks
create table if not exists public.career_tasks (
  id uuid primary key default gen_random_uuid(),
  task_code text unique not null,
  title text not null,
  description text not null,
  icon text not null default 'school',
  category text not null default 'General',
  verification_type text not null,
  required_value integer not null default 1,
  career_xp integer not null default 50,
  silver_coin integer not null default 50,
  bonus_reward jsonb default '{}'::jsonb,
  minimum_level integer not null default 1,
  maximum_level integer not null default 60,
  task_order integer default 0,
  is_repeatable boolean default false,
  is_daily boolean default true,
  is_active boolean default true,
  start_time timestamp with time zone,
  end_time timestamp with time zone,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- 2. Create id_tasks
create table if not exists public.id_tasks (
  id uuid primary key default gen_random_uuid(),
  task_code text unique not null,
  title text not null,
  description text not null,
  icon text not null default 'thumb_up',
  category text not null default 'General',
  verification_type text not null,
  required_value integer not null default 1,
  id_xp integer not null default 50,
  silver_coin integer not null default 50,
  bonus_reward jsonb default '{}'::jsonb,
  minimum_level integer not null default 1,
  maximum_level integer not null default 60,
  task_order integer default 0,
  is_repeatable boolean default false,
  is_daily boolean default true,
  is_active boolean default true,
  start_time timestamp with time zone,
  end_time timestamp with time zone,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- 3. Create weekly_tasks
create table if not exists public.weekly_tasks (
  id uuid primary key default gen_random_uuid(),
  task_code text unique not null,
  title text not null,
  description text not null,
  icon text not null default 'date_range',
  category text not null default 'General',
  verification_type text not null,
  required_value integer not null default 1,
  xp integer not null default 100,
  silver_coin integer not null default 100,
  bonus_reward jsonb default '{}'::jsonb,
  minimum_level integer not null default 1,
  maximum_level integer not null default 60,
  task_order integer default 0,
  is_repeatable boolean default false,
  is_daily boolean default false,
  is_active boolean default true,
  start_time timestamp with time zone,
  end_time timestamp with time zone,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- 4. Create monthly_tasks
create table if not exists public.monthly_tasks (
  id uuid primary key default gen_random_uuid(),
  task_code text unique not null,
  title text not null,
  description text not null,
  icon text not null default 'calendar_today',
  category text not null default 'General',
  verification_type text not null,
  required_value integer not null default 1,
  xp integer not null default 300,
  silver_coin integer not null default 300,
  bonus_reward jsonb default '{}'::jsonb,
  minimum_level integer not null default 1,
  maximum_level integer not null default 60,
  task_order integer default 0,
  is_repeatable boolean default false,
  is_daily boolean default false,
  is_active boolean default true,
  start_time timestamp with time zone,
  end_time timestamp with time zone,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- 5. Create event_tasks
create table if not exists public.event_tasks (
  id uuid primary key default gen_random_uuid(),
  task_code text unique not null,
  title text not null,
  description text not null,
  icon text not null default 'star',
  category text not null default 'Event',
  verification_type text not null,
  required_value integer not null default 1,
  xp integer not null default 200,
  silver_coin integer not null default 200,
  bonus_reward jsonb default '{}'::jsonb,
  minimum_level integer not null default 1,
  maximum_level integer not null default 60,
  task_order integer default 0,
  is_repeatable boolean default false,
  is_daily boolean default false,
  is_active boolean default true,
  start_time timestamp with time zone,
  end_time timestamp with time zone,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- 6. Create user_daily_progress
create table if not exists public.user_daily_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  task_id uuid not null,
  task_type text not null,
  progress integer not null default 0,
  required_progress integer not null default 1,
  completed boolean not null default false,
  claimed boolean not null default false,
  completed_at timestamp with time zone,
  claimed_at timestamp with time zone,
  date date not null default current_date,
  unique (user_id, task_id, date)
);

-- 7. Create daily_rewards
create table if not exists public.daily_rewards (
  id uuid primary key default gen_random_uuid(),
  reward_type text not null,
  reward_value text not null,
  reward_name text not null,
  reward_icon text,
  reward_animation text,
  rarity text default 'common'
);

-- Enable RLS on all tables
alter table public.career_tasks enable row level security;
alter table public.id_tasks enable row level security;
alter table public.weekly_tasks enable row level security;
alter table public.monthly_tasks enable row level security;
alter table public.event_tasks enable row level security;
alter table public.user_daily_progress enable row level security;
alter table public.daily_rewards enable row level security;

-- Setup RLS Policies (read access to all authenticated, write to none except user_daily_progress)
create policy "Allow read on career_tasks" on public.career_tasks for select using (true);
create policy "Allow read on id_tasks" on public.id_tasks for select using (true);
create policy "Allow read on weekly_tasks" on public.weekly_tasks for select using (true);
create policy "Allow read on monthly_tasks" on public.monthly_tasks for select using (true);
create policy "Allow read on event_tasks" on public.event_tasks for select using (true);
create policy "Allow read on daily_rewards" on public.daily_rewards for select using (true);

create policy "Allow read own daily progress" on public.user_daily_progress for select using (auth.uid() = user_id);
create policy "Allow insert own daily progress" on public.user_daily_progress for insert with check (auth.uid() = user_id);
create policy "Allow update own daily progress" on public.user_daily_progress for update using (auth.uid() = user_id);

-- Helper calculation function for level progression
create or replace function public.calculate_level_from_xp(p_xp integer)
returns integer as $$
declare
  v_level integer := 1;
  v_cum_xp bigint;
begin
  for l in 2..60 loop
    v_cum_xp := 10 * (l - 1)^3 + 250 * (l - 1)^2 + 500 * (l - 1);
    if p_xp >= v_cum_xp then
      v_level := l;
    else
      exit;
    end if;
  end loop;
  return v_level;
end;
$$ language plpgsql immutable;

-- Dynamic daily tasks rotation RPC
create or replace function public.rotate_daily_tasks(p_user_id uuid)
returns table (
  id uuid,
  user_id uuid,
  task_id uuid,
  task_type text,
  progress integer,
  required_progress integer,
  completed boolean,
  claimed boolean,
  completed_at timestamp with time zone,
  claimed_at timestamp with time zone,
  date date,
  task_code text,
  title text,
  description text,
  icon text,
  category text,
  verification_type text,
  xp integer,
  silver_coin integer,
  bonus_reward jsonb
) as $$
declare
  v_career_level integer;
  v_id_level integer;
  v_has_tasks boolean;
begin
  -- Get user levels
  select coalesce(career_level, 1), coalesce(level, 1)
  into v_career_level, v_id_level
  from public.profiles
  where id = p_user_id;

  -- Check if user already has tasks rotated for current_date
  select exists (
    select 1 from public.user_daily_progress
    where user_id = p_user_id and date = current_date
  ) into v_has_tasks;

  if not v_has_tasks then
    -- Rotate Career Daily Tasks: Select 8 random tasks
    insert into public.user_daily_progress (user_id, task_id, task_type, progress, required_progress, date)
    select 
      p_user_id, 
      t.id, 
      'career', 
      0, 
      t.required_value, 
      current_date
    from public.career_tasks t
    where t.is_active = true 
      and t.is_daily = true
      and v_career_level >= t.minimum_level 
      and v_career_level <= t.maximum_level
    order by random()
    limit 8
    on conflict (user_id, task_id, date) do nothing;

    -- Rotate ID Daily Tasks: Select 10 random tasks
    insert into public.user_daily_progress (user_id, task_id, task_type, progress, required_progress, date)
    select 
      p_user_id, 
      t.id, 
      'id', 
      0, 
      t.required_value, 
      current_date
    from public.id_tasks t
    where t.is_active = true 
      and t.is_daily = true
      and v_id_level >= t.minimum_level 
      and v_id_level <= t.maximum_level
    order by random()
    limit 10
    on conflict (user_id, task_id, date) do nothing;
  end if;

  -- Return the combined tasks for today with metadata
  return query
  select 
    p.id,
    p.user_id,
    p.task_id,
    p.task_type,
    p.progress,
    p.required_progress,
    p.completed,
    p.claimed,
    p.completed_at,
    p.claimed_at,
    p.date,
    coalesce(ct.task_code, it.task_code) as task_code,
    coalesce(ct.title, it.title) as title,
    coalesce(ct.description, it.description) as description,
    coalesce(ct.icon, it.icon) as icon,
    coalesce(ct.category, it.category) as category,
    coalesce(ct.verification_type, it.verification_type) as verification_type,
    coalesce(ct.career_xp, it.id_xp) as xp,
    coalesce(ct.silver_coin, it.silver_coin) as silver_coin,
    coalesce(ct.bonus_reward, it.bonus_reward) as bonus_reward
  from public.user_daily_progress p
  left join public.career_tasks ct on p.task_id = ct.id and p.task_type = 'career'
  left join public.id_tasks it on p.task_id = it.id and p.task_type = 'id'
  where p.user_id = p_user_id and p.date = current_date;
end;
$$ language plpgsql security definer;

-- Increment task progress secure RPC
create or replace function public.increment_task_progress(p_task_code text, p_amount integer default 1)
returns boolean as $$
declare
  v_user_id uuid;
  v_task_id uuid;
  v_task_type text;
  v_verification_type text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthenticated user session';
  end if;

  -- Find task
  select id, 'career', verification_type into v_task_id, v_task_type, v_verification_type
  from public.career_tasks where task_code = p_task_code;

  if v_task_id is null then
    select id, 'id', verification_type into v_task_id, v_task_type, v_verification_type
    from public.id_tasks where task_code = p_task_code;
  end if;

  if v_task_id is null then
    raise exception 'Task not found';
  end if;

  -- Enforce backend bounds for specific tasks
  if v_verification_type = 'check_in' and p_amount > 1 then
    p_amount := 1;
  end if;

  -- Update progress record
  update public.user_daily_progress
  set progress = least(progress + p_amount, required_progress),
      completed = (progress + p_amount >= required_progress),
      completed_at = case when progress + p_amount >= required_progress then now() else completed_at end
  where user_id = v_user_id 
    and task_id = v_task_id
    and date = current_date;

  return true;
end;
$$ language plpgsql security definer;

-- Reward Claim RPC
create or replace function public.claim_task_reward(p_progress_id uuid)
returns jsonb as $$
declare
  v_user_id uuid;
  v_progress record;
  v_xp integer;
  v_coins integer;
  v_bonus jsonb;
  v_new_xp integer;
  v_new_level integer;
  v_new_coins numeric;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthenticated user session';
  end if;

  -- Select progress record
  select * into v_progress
  from public.user_daily_progress
  where id = p_progress_id and user_id = v_user_id;

  if v_progress is null then
    raise exception 'Task progress record not found';
  end if;

  if not v_progress.completed then
    raise exception 'Task is not completed yet';
  end if;

  if v_progress.claimed then
    raise exception 'Reward has already been claimed';
  end if;

  -- Fetch rewards
  if v_progress.task_type = 'career' then
    select career_xp, silver_coin, bonus_reward into v_xp, v_coins, v_bonus
    from public.career_tasks where id = v_progress.task_id;
  elsif v_progress.task_type = 'id' then
    select id_xp, silver_coin, bonus_reward into v_xp, v_coins, v_bonus
    from public.id_tasks where id = v_progress.task_id;
  else
    raise exception 'Unknown task type';
  end if;

  -- Mark task as claimed
  update public.user_daily_progress
  set claimed = true,
      claimed_at = now()
  where id = p_progress_id;

  -- Update profiles with XP
  if v_progress.task_type = 'career' then
    update public.profiles
    set career_xp = coalesce(career_xp, 0) + v_xp,
        career_level = public.calculate_level_from_xp(coalesce(career_xp, 0) + v_xp)
    where id = v_user_id
    returning career_xp, career_level into v_new_xp, v_new_level;
  else
    update public.profiles
    set experience = coalesce(experience, 0) + v_xp,
        level = public.calculate_level_from_xp(coalesce(experience, 0) + v_xp)
    where id = v_user_id
    returning experience, level into v_new_xp, v_new_level;
  end if;

  -- Update wallets with Coins
  update public.wallets
  set coins_balance = coalesce(coins_balance, 0) + v_coins,
      updated_at = now()
  where id = v_user_id
  returning coins_balance into v_new_coins;

  -- Add transaction ledger log
  insert into public.wallet_transactions (wallet_id, amount, category, description)
  values (v_user_id, v_coins, 'Reward', 'Daily task reward claimed: ' || v_progress.task_type);

  -- Return summary JSON
  return jsonb_build_object(
    'claimed', true,
    'xp_earned', v_xp,
    'coins_earned', v_coins,
    'new_xp', v_new_xp,
    'new_level', v_new_level,
    'new_coins', v_new_coins,
    'bonus_reward', v_bonus
  );
end;
$$ language plpgsql security definer;

-- Triggers for verified community actions (Like, Comment, Post)
create or replace function public.on_comment_added()
returns trigger as $$
begin
  update public.user_daily_progress
  set progress = least(progress + 1, required_progress),
      completed = (progress + 1 >= required_progress),
      completed_at = case when progress + 1 >= required_progress then now() else completed_at end
  where user_id = new.user_id 
    and date = current_date
    and task_id in (
      select id from public.id_tasks where verification_type = 'comment_post'
    );
  return new;
end;
$$ language plpgsql security definer;

create or replace function public.on_like_added()
returns trigger as $$
begin
  update public.user_daily_progress
  set progress = least(progress + 1, required_progress),
      completed = (progress + 1 >= required_progress),
      completed_at = case when progress + 1 >= required_progress then now() else completed_at end
  where user_id = new.user_id 
    and date = current_date
    and task_id in (
      select id from public.id_tasks where verification_type = 'like_post'
    );
  return new;
end;
$$ language plpgsql security definer;

create or replace function public.on_post_added()
returns trigger as $$
begin
  update public.user_daily_progress
  set progress = least(progress + 1, required_progress),
      completed = (progress + 1 >= required_progress),
      completed_at = case when progress + 1 >= required_progress then now() else completed_at end
  where user_id = new.user_id 
    and date = current_date
    and task_id in (
      select id from public.id_tasks where verification_type = 'create_post'
    );
  return new;
end;
$$ language plpgsql security definer;

-- Bind triggers to tables
drop trigger if exists trigger_on_comment_added on public.post_comments;
create trigger trigger_on_comment_added
after insert on public.post_comments
for each row execute function public.on_comment_added();

drop trigger if exists trigger_on_like_added on public.post_likes;
create trigger trigger_on_like_added
after insert on public.post_likes
for each row execute function public.on_like_added();

drop trigger if exists trigger_on_post_added on public.posts;
create trigger trigger_on_post_added
after insert on public.posts
for each row execute function public.on_post_added();

-- Seeding Default Seed Tasks to allow instant 5-Year scalability out of the box
insert into public.career_tasks (task_code, title, description, icon, category, verification_type, required_value, career_xp, silver_coin)
values
  ('watch_video', 'Watch Learning Video', 'Spend time watching dynamic video guides.', 'play_circle_fill', 'Study', 'video_watch', 1, 150, 100),
  ('complete_quiz', 'Complete Daily Quiz', 'Test your knowledge on daily topics.', 'quiz', 'Study', 'quiz_score', 1, 200, 150),
  ('read_article', 'Read Knowledge Article', 'Read an educational post or doc.', 'article', 'Study', 'article_read', 1, 100, 50),
  ('voice_join', 'Join Study Voice Room', 'Join a voice stream with fellow students.', 'mic', 'Study', 'voice_duration', 1, 150, 100),
  ('voice_speak', 'Speak in Study Voice Room', 'Participate actively in study streams.', 'volume_up', 'Study', 'voice_duration', 1, 200, 200),
  ('join_event', 'Join Community Study Event', 'Attend scheduled cohort classes.', 'event', 'Study', 'event_participate', 1, 250, 250),
  ('code_challenge', 'Solve Coding Challenge', 'Write clean code in our playground.', 'code', 'Study', 'code_score', 1, 250, 250),
  ('ask_question', 'Answer Educational Question', 'Help others learn by answering questions.', 'question_answer', 'Study', 'question_answer', 1, 150, 100)
on conflict (task_code) do nothing;

insert into public.id_tasks (task_code, title, description, icon, category, verification_type, required_value, id_xp, silver_coin)
values
  ('like_posts', 'Like 3 Posts', 'Show some appreciation to creator posts.', 'favorite', 'Social', 'like_post', 3, 100, 50),
  ('comment_post', 'Comment on 2 Posts', 'Write educational feedback on posts.', 'chat_bubble', 'Social', 'comment_post', 2, 120, 80),
  ('follow_creator', 'Follow 1 Creator', 'Follow a teacher or top peer.', 'person_add', 'Social', 'follow_creator', 1, 100, 50),
  ('voice_room', 'Join Voice Room', 'Hang out in any community voice room.', 'volume_up', 'Social', 'voice_join', 1, 100, 50),
  ('active_room', 'Stay Active (10m)', 'Remain engaged in public streams.', 'timer', 'Social', 'voice_duration', 1, 150, 100),
  ('create_post', 'Upload a Post', 'Share your notes or questions.', 'add_box', 'Social', 'create_post', 1, 150, 100),
  ('send_gift', 'Send a Gift', 'Gift virtual badges or frames.', 'card_giftcard', 'Social', 'gift_send', 1, 200, 150),
  ('invite_friend', 'Invite 1 Friend', 'Invite peers to join Creania.', 'group_add', 'Social', 'friend_invite', 1, 250, 250),
  ('watch_ads', 'Watch Reward Ads', 'Watch an ad sponsor video.', 'smart_display', 'Social', 'ads_watched', 1, 100, 50)
on conflict (task_code) do nothing;
