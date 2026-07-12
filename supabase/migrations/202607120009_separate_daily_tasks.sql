-- supabase/migrations/202607120009_separate_daily_tasks.sql
-- Separate Daily Task System (Career Daily and ID Daily)

-- Alter profiles table to add career_level if not exists
alter table public.profiles
  add column if not exists career_level integer default 1;

-- 1. Create career_daily_tasks definition table
create table if not exists public.career_daily_tasks (
  id uuid primary key default gen_random_uuid(),
  task_code text unique not null,
  title text not null,
  description text not null,
  icon text not null default 'school',
  category text not null default 'Study',
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
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- 2. Create id_daily_tasks definition table
create table if not exists public.id_daily_tasks (
  id uuid primary key default gen_random_uuid(),
  task_code text unique not null,
  title text not null,
  description text not null,
  icon text not null default 'thumb_up',
  category text not null default 'Social',
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
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- 3. Create career_progress tracking table
create table if not exists public.career_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  task_id uuid not null references public.career_daily_tasks(id) on delete cascade,
  progress integer not null default 0,
  required_progress integer not null default 1,
  completed boolean not null default false,
  claimed boolean not null default false,
  completed_at timestamp with time zone,
  claimed_at timestamp with time zone,
  date date not null default current_date,
  unique (user_id, task_id, date)
);

-- 4. Create id_progress tracking table
create table if not exists public.id_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  task_id uuid not null references public.id_daily_tasks(id) on delete cascade,
  progress integer not null default 0,
  required_progress integer not null default 1,
  completed boolean not null default false,
  claimed boolean not null default false,
  completed_at timestamp with time zone,
  claimed_at timestamp with time zone,
  date date not null default current_date,
  unique (user_id, task_id, date)
);

-- 5. Create career_history table
create table if not exists public.career_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  task_code text not null,
  xp_earned integer not null,
  coins_earned integer not null,
  claimed_at timestamp with time zone default now()
);

-- 6. Create id_history table
create table if not exists public.id_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  task_code text not null,
  xp_earned integer not null,
  coins_earned integer not null,
  claimed_at timestamp with time zone default now()
);

-- 7. Create career_rewards table
create table if not exists public.career_rewards (
  id uuid primary key default gen_random_uuid(),
  reward_type text not null,
  reward_value text not null,
  reward_name text not null,
  reward_icon text,
  reward_animation text,
  rarity text default 'common'
);

-- 8. Create id_rewards table
create table if not exists public.id_rewards (
  id uuid primary key default gen_random_uuid(),
  reward_type text not null,
  reward_value text not null,
  reward_name text not null,
  reward_icon text,
  reward_animation text,
  rarity text default 'common'
);

-- Enable RLS on all new tables
alter table public.career_daily_tasks enable row level security;
alter table public.id_daily_tasks enable row level security;
alter table public.career_progress enable row level security;
alter table public.id_progress enable row level security;
alter table public.career_history enable row level security;
alter table public.id_history enable row level security;
alter table public.career_rewards enable row level security;
alter table public.id_rewards enable row level security;

-- Set up RLS Policies (read access to all authenticated, write only for own user rows)
create policy "Allow read on career_daily_tasks" on public.career_daily_tasks for select using (true);
create policy "Allow read on id_daily_tasks" on public.id_daily_tasks for select using (true);
create policy "Allow read on career_rewards" on public.career_rewards for select using (true);
create policy "Allow read on id_rewards" on public.id_rewards for select using (true);

create policy "Allow read own career progress" on public.career_progress for select using (auth.uid() = user_id);
create policy "Allow insert own career progress" on public.career_progress for insert with check (auth.uid() = user_id);
create policy "Allow update own career progress" on public.career_progress for update using (auth.uid() = user_id);

create policy "Allow read own id progress" on public.id_progress for select using (auth.uid() = user_id);
create policy "Allow insert own id progress" on public.id_progress for insert with check (auth.uid() = user_id);
create policy "Allow update own id progress" on public.id_progress for update using (auth.uid() = user_id);

create policy "Allow read own career history" on public.career_history for select using (auth.uid() = user_id);
create policy "Allow insert own career history" on public.career_history for insert with check (auth.uid() = user_id);

create policy "Allow read own id history" on public.id_history for select using (auth.uid() = user_id);
create policy "Allow insert own id history" on public.id_history for insert with check (auth.uid() = user_id);


-- 9. RPC Functions for Career Daily Tasks
create or replace function public.rotate_career_tasks(p_user_id uuid)
returns table (
  id uuid,
  user_id uuid,
  task_id uuid,
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
  career_xp integer,
  silver_coin integer,
  bonus_reward jsonb
) as $$
declare
  v_career_level integer;
  v_has_tasks boolean;
begin
  -- Get user career level
  select coalesce(career_level, 1)
  into v_career_level
  from public.profiles
  where id = p_user_id;

  -- Check if user already has career tasks rotated for current_date
  select exists (
    select 1 from public.career_progress
    where user_id = p_user_id and date = current_date
  ) into v_has_tasks;

  if not v_has_tasks then
    -- Rotate Career Daily Tasks: Select 8 random active tasks
    insert into public.career_progress (user_id, task_id, progress, required_progress, date)
    select 
      p_user_id, 
      t.id, 
      0, 
      t.required_value, 
      current_date
    from public.career_daily_tasks t
    where t.is_active = true 
      and t.is_daily = true
      and v_career_level >= t.minimum_level 
      and v_career_level <= t.maximum_level
    order by random()
    limit 8
    on conflict (user_id, task_id, date) do nothing;
  end if;

  -- Return the career tasks for today
  return query
  select 
    p.id,
    p.user_id,
    p.task_id,
    p.progress,
    p.required_progress,
    p.completed,
    p.claimed,
    p.completed_at,
    p.claimed_at,
    p.date,
    t.task_code,
    t.title,
    t.description,
    t.icon,
    t.category,
    t.verification_type,
    t.career_xp,
    t.silver_coin,
    t.bonus_reward
  from public.career_progress p
  inner join public.career_daily_tasks t on p.task_id = t.id
  where p.user_id = p_user_id and p.date = current_date;
end;
$$ language plpgsql security definer;


create or replace function public.increment_career_task_progress(p_task_code text, p_amount integer default 1)
returns boolean as $$
declare
  v_user_id uuid;
  v_task_id uuid;
  v_verification_type text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthenticated user session';
  end if;

  -- Find task
  select id, verification_type into v_task_id, v_verification_type
  from public.career_daily_tasks where task_code = p_task_code;

  if v_task_id is null then
    raise exception 'Career task not found';
  end if;

  -- Update progress
  update public.career_progress
  set progress = least(progress + p_amount, required_progress),
      completed = (progress + p_amount >= required_progress),
      completed_at = case when progress + p_amount >= required_progress then now() else completed_at end
  where user_id = v_user_id 
    and task_id = v_task_id
    and date = current_date;

  return true;
end;
$$ language plpgsql security definer;


create or replace function public.claim_career_task_reward(p_progress_id uuid)
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

  select * into v_progress
  from public.career_progress
  where id = p_progress_id and user_id = v_user_id;

  if v_progress is null then
    raise exception 'Career task progress record not found';
  end if;

  if not v_progress.completed then
    raise exception 'Task is not completed yet';
  end if;

  if v_progress.claimed then
    raise exception 'Reward has already been claimed';
  end if;

  -- Fetch reward definitions
  select career_xp, silver_coin, bonus_reward into v_xp, v_coins, v_bonus
  from public.career_daily_tasks where id = v_progress.task_id;

  -- Mark progress as claimed
  update public.career_progress
  set claimed = true,
      claimed_at = now()
  where id = p_progress_id;

  -- Update career profiles
  update public.profiles
  set career_xp = coalesce(career_xp, 0) + v_xp,
      career_level = public.calculate_level_from_xp(coalesce(career_xp, 0) + v_xp)
  where id = v_user_id
  returning career_xp, career_level into v_new_xp, v_new_level;

  -- Update wallets
  update public.wallets
  set coins_balance = coalesce(coins_balance, 0) + v_coins,
      updated_at = now()
  where id = v_user_id
  returning coins_balance into v_new_coins;

  -- Record career claim history
  insert into public.career_history (user_id, task_code, xp_earned, coins_earned)
  select v_user_id, t.task_code, v_xp, v_coins
  from public.career_daily_tasks t where t.id = v_progress.task_id;

  -- Log transaction ledger
  insert into public.wallet_transactions (wallet_id, amount, category, description)
  values (v_user_id, v_coins, 'Reward', 'Career daily task reward claimed');

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


-- 10. RPC Functions for ID Daily Tasks
create or replace function public.rotate_id_tasks(p_user_id uuid)
returns table (
  id uuid,
  user_id uuid,
  task_id uuid,
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
  id_xp integer,
  silver_coin integer,
  bonus_reward jsonb
) as $$
declare
  v_id_level integer;
  v_has_tasks boolean;
begin
  -- Get user ID level
  select coalesce(level, 1)
  into v_id_level
  from public.profiles
  where id = p_user_id;

  -- Check if user already has ID tasks rotated for current_date
  select exists (
    select 1 from public.id_progress
    where user_id = p_user_id and date = current_date
  ) into v_has_tasks;

  if not v_has_tasks then
    -- Rotate ID Daily Tasks: Select 10 random active tasks
    insert into public.id_progress (user_id, task_id, progress, required_progress, date)
    select 
      p_user_id, 
      t.id, 
      0, 
      t.required_value, 
      current_date
    from public.id_daily_tasks t
    where t.is_active = true 
      and t.is_daily = true
      and v_id_level >= t.minimum_level 
      and v_id_level <= t.maximum_level
    order by random()
    limit 10
    on conflict (user_id, task_id, date) do nothing;
  end if;

  -- Return the ID tasks for today
  return query
  select 
    p.id,
    p.user_id,
    p.task_id,
    p.progress,
    p.required_progress,
    p.completed,
    p.claimed,
    p.completed_at,
    p.claimed_at,
    p.date,
    t.task_code,
    t.title,
    t.description,
    t.icon,
    t.category,
    t.verification_type,
    t.id_xp,
    t.silver_coin,
    t.bonus_reward
  from public.id_progress p
  inner join public.id_daily_tasks t on p.task_id = t.id
  where p.user_id = p_user_id and p.date = current_date;
end;
$$ language plpgsql security definer;


create or replace function public.increment_id_task_progress(p_task_code text, p_amount integer default 1)
returns boolean as $$
declare
  v_user_id uuid;
  v_task_id uuid;
  v_verification_type text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthenticated user session';
  end if;

  -- Find task
  select id, verification_type into v_task_id, v_verification_type
  from public.id_daily_tasks where task_code = p_task_code;

  if v_task_id is null then
    raise exception 'ID task not found';
  end if;

  -- Update progress
  update public.id_progress
  set progress = least(progress + p_amount, required_progress),
      completed = (progress + p_amount >= required_progress),
      completed_at = case when progress + p_amount >= required_progress then now() else completed_at end
  where user_id = v_user_id 
    and task_id = v_task_id
    and date = current_date;

  return true;
end;
$$ language plpgsql security definer;


create or replace function public.claim_id_task_reward(p_progress_id uuid)
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

  select * into v_progress
  from public.id_progress
  where id = p_progress_id and user_id = v_user_id;

  if v_progress is null then
    raise exception 'ID task progress record not found';
  end if;

  if not v_progress.completed then
    raise exception 'Task is not completed yet';
  end if;

  if v_progress.claimed then
    raise exception 'Reward has already been claimed';
  end if;

  -- Fetch reward definitions
  select id_xp, silver_coin, bonus_reward into v_xp, v_coins, v_bonus
  from public.id_daily_tasks where id = v_progress.task_id;

  -- Mark progress as claimed
  update public.id_progress
  set claimed = true,
      claimed_at = now()
  where id = p_progress_id;

  -- Update ID profiles
  update public.profiles
  set experience = coalesce(experience, 0) + v_xp,
      level = public.calculate_level_from_xp(coalesce(experience, 0) + v_xp)
  where id = v_user_id
  returning experience, level into v_new_xp, v_new_level;

  -- Update wallets
  update public.wallets
  set coins_balance = coalesce(coins_balance, 0) + v_coins,
      updated_at = now()
  where id = v_user_id
  returning coins_balance into v_new_coins;

  -- Record ID claim history
  insert into public.id_history (user_id, task_code, xp_earned, coins_earned)
  select v_user_id, t.task_code, v_xp, v_coins
  from public.id_daily_tasks t where t.id = v_progress.task_id;

  -- Log transaction ledger
  insert into public.wallet_transactions (wallet_id, amount, category, description)
  values (v_user_id, v_coins, 'Reward', 'ID daily task reward claimed');

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


-- 11. Remap the social action triggers to id_progress
create or replace function public.on_comment_added()
returns trigger as $$
begin
  update public.id_progress
  set progress = least(progress + 1, required_progress),
      completed = (progress + 1 >= required_progress),
      completed_at = case when progress + 1 >= required_progress then now() else completed_at end
  where user_id = new.user_id 
    and date = current_date
    and task_id in (
      select id from public.id_daily_tasks where verification_type = 'comment_post'
    );
  return new;
end;
$$ language plpgsql security definer;

create or replace function public.on_like_added()
returns trigger as $$
begin
  update public.id_progress
  set progress = least(progress + 1, required_progress),
      completed = (progress + 1 >= required_progress),
      completed_at = case when progress + 1 >= required_progress then now() else completed_at end
  where user_id = new.user_id 
    and date = current_date
    and task_id in (
      select id from public.id_daily_tasks where verification_type = 'like_post'
    );
  return new;
end;
$$ language plpgsql security definer;

create or replace function public.on_post_added()
returns trigger as $$
begin
  update public.id_progress
  set progress = least(progress + 1, required_progress),
      completed = (progress + 1 >= required_progress),
      completed_at = case when progress + 1 >= required_progress then now() else completed_at end
  where user_id = new.user_id 
    and date = current_date
    and task_id in (
      select id from public.id_daily_tasks where verification_type = 'create_post'
    );
  return new;
end;
$$ language plpgsql security definer;


-- 12. Seed separate tables with default tasks
insert into public.career_daily_tasks (task_code, title, description, icon, category, verification_type, required_value, career_xp, silver_coin)
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

insert into public.id_daily_tasks (task_code, title, description, icon, category, verification_type, required_value, id_xp, silver_coin)
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
