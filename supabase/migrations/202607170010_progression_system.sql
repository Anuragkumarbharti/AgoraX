-- Migration 202607170010_progression_system.sql
-- Complete enterprise-grade backend-driven progression system, XP engine, Task engine, Lucky spin, and checkin calendars.

-- 1. Create helper level_requirements table
create table if not exists public.level_requirements (
  level integer primary key,
  xp_required integer not null check (xp_required >= 0),
  total_xp_required integer not null check (total_xp_required >= 0)
);

-- Populate level requirements (1 to 60) with an exponential curve (total ~185k XP)
do $$
declare
  v_lvl integer;
  v_xp integer;
  v_total_xp integer := 0;
begin
  insert into public.level_requirements (level, xp_required, total_xp_required)
  values (1, 0, 0) on conflict (level) do nothing;

  for v_lvl in 2..60 loop
    v_xp := round(100.0 * power(1.09, v_lvl - 1))::integer;
    v_total_xp := v_total_xp + v_xp;
    insert into public.level_requirements (level, xp_required, total_xp_required)
    values (v_lvl, v_xp, v_total_xp)
    on conflict (level) do update set xp_required = excluded.xp_required, total_xp_required = excluded.total_xp_required;
  end loop;
end;
$$;

-- 2. Create user_levels table
create table if not exists public.user_levels (
  id uuid references public.profiles(id) on delete cascade primary key,
  level integer not null default 1 check (level >= 1 and level <= 60),
  xp integer not null default 0 check (xp >= 0),
  total_xp integer not null default 0 check (total_xp >= 0),
  today_earned_xp integer not null default 0 check (today_earned_xp >= 0),
  today_bonus_xp integer not null default 0 check (today_bonus_xp >= 0),
  weekly_xp integer not null default 0 check (weekly_xp >= 0),
  monthly_xp integer not null default 0 check (monthly_xp >= 0),
  last_xp_update timestamp with time zone default now(),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Backfill user_levels for existing profiles
insert into public.user_levels (id, level, xp, total_xp)
select id, level, experience, experience
from public.profiles
on conflict (id) do nothing;

-- 3. Create xp_history table
create table if not exists public.xp_history (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  event_type text not null,
  xp_gained integer not null check (xp_gained >= 0),
  metadata jsonb default '{}'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 4. Create tasks registry tables
create table if not exists public.daily_tasks (
  id uuid default gen_random_uuid() primary key,
  task_id text unique not null,
  title text not null,
  description text,
  required_action text not null,
  required_count integer not null default 1,
  priority integer not null default 0,
  is_active boolean not null default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table if not exists public.weekly_tasks (
  id uuid default gen_random_uuid() primary key,
  task_id text unique not null,
  title text not null,
  description text,
  required_action text not null,
  required_count integer not null default 1,
  priority integer not null default 0,
  is_active boolean not null default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table if not exists public.monthly_tasks (
  id uuid default gen_random_uuid() primary key,
  task_id text unique not null,
  title text not null,
  description text,
  required_action text not null,
  required_count integer not null default 1,
  priority integer not null default 0,
  is_active boolean not null default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table if not exists public.season_tasks (
  id uuid default gen_random_uuid() primary key,
  task_id text unique not null,
  title text not null,
  description text,
  required_action text not null,
  required_count integer not null default 1,
  priority integer not null default 0,
  is_active boolean not null default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 5. Create task_progress table
create table if not exists public.task_progress (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  task_id text not null,
  task_type text not null check (task_type in ('daily', 'weekly', 'monthly', 'season')),
  cycle_key text not null, -- format: 'YYYY-MM-DD', 'YYYY-Wxx', 'YYYY-MM', or 'season_xx'
  current_count integer not null default 0 check (current_count >= 0),
  is_completed boolean not null default false,
  is_claimed boolean not null default false,
  completed_at timestamp with time zone,
  claimed_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (user_id, task_id, task_type, cycle_key)
);

-- 6. Create task_rewards table
create table if not exists public.task_rewards (
  id uuid default gen_random_uuid() primary key,
  task_id text not null,
  task_type text not null check (task_type in ('daily', 'weekly', 'monthly', 'season')),
  reward_type text not null check (reward_type in ('xp', 'silver', 'gold', 'frame', 'badge', 'bubble', 'theme', 'tag', 'spin_ticket', 'coupon', 'gift')),
  amount integer not null default 0,
  cosmetic_id text, -- string code name of frame, badge, etc.
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 7. Create level_rewards table
create table if not exists public.level_rewards (
  id uuid default gen_random_uuid() primary key,
  level integer not null check (level >= 1 and level <= 60),
  reward_type text not null check (reward_type in ('xp', 'silver', 'gold', 'frame', 'badge', 'bubble', 'theme', 'tag', 'spin_ticket', 'coupon')),
  amount integer not null default 0,
  cosmetic_id text,
  is_repeatable boolean not null default false,
  is_time_limited boolean not null default false,
  expiry_days integer,
  is_permanent boolean not null default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 8. Create reward_claims table
create table if not exists public.reward_claims (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  source_type text not null check (source_type in ('level', 'task', 'checkin', 'achievement', 'loyalty', 'spin', 'community', 'event')),
  source_id text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (user_id, source_type, source_id)
);

-- 9. Create daily_limits table
create table if not exists public.daily_limits (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  date date not null default current_date,
  free_xp integer not null default 0 check (free_xp >= 0),
  bonus_xp integer not null default 0 check (bonus_xp >= 0),
  ad_count integer not null default 0 check (ad_count >= 0),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (user_id, date)
);

-- 10. Create checkin_history table
create table if not exists public.checkin_history (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  month_key text not null, -- YYYY-MM
  day_number integer not null check (day_number >= 1 and day_number <= 30),
  claimed_at timestamp with time zone default timezone('utc'::text, now()) not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (user_id, month_key, day_number)
);

-- 11. Create achievements registry & progress
create table if not exists public.achievements (
  id uuid default gen_random_uuid() primary key,
  achievement_id text unique not null,
  title text not null,
  description text,
  required_action text not null,
  required_count integer not null default 1,
  reward_type text not null check (reward_type in ('xp', 'silver', 'gold', 'frame', 'badge', 'bubble', 'theme', 'tag', 'spin_ticket', 'coupon')),
  reward_amount integer not null default 0,
  reward_cosmetic_id text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table if not exists public.achievement_progress (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  achievement_id text references public.achievements(achievement_id) on delete cascade not null,
  current_count integer not null default 0 check (current_count >= 0),
  is_completed boolean not null default false,
  is_claimed boolean not null default false,
  completed_at timestamp with time zone,
  claimed_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (user_id, achievement_id)
);

-- 12. Create loyalty_rewards table
create table if not exists public.loyalty_rewards (
  id uuid default gen_random_uuid() primary key,
  active_days integer unique not null,
  reward_type text not null check (reward_type in ('badge', 'title', 'frame', 'silver', 'gold', 'spin_ticket')),
  amount integer not null default 0,
  cosmetic_id text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 13. Create spin_rewards registry
create table if not exists public.spin_rewards (
  id uuid default gen_random_uuid() primary key,
  spin_type text not null check (spin_type in ('silver', 'gold', 'premium')),
  reward_type text not null check (reward_type in ('xp', 'silver', 'gold', 'frame', 'badge', 'bubble', 'theme', 'tag', 'spin_ticket', 'coupon')),
  amount integer not null default 0,
  cosmetic_id text,
  probability double precision not null check (probability >= 0.0 and probability <= 1.0),
  is_active boolean not null default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 14. Create spin_history log
create table if not exists public.spin_history (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  spin_type text not null check (spin_type in ('silver', 'gold', 'premium')),
  won_reward_id uuid references public.spin_rewards(id) on delete set null,
  won_reward_type text not null,
  won_amount integer not null default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 15. Create reward_logs table
create table if not exists public.reward_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  source_type text not null, -- task, level_up, spin, checkin, achievement, loyalty, community, event
  source_id text not null,
  reward_type text not null,
  amount integer not null default 0,
  cosmetic_id text,
  status text not null default 'Granted', -- Granted, Blocked, Failed
  reason text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 16. Create gift_xp_logs table
create table if not exists public.gift_xp_logs (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  receiver_id uuid references public.profiles(id) on delete cascade not null,
  gift_id text not null,
  xp_value integer not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 17. Create community_rewards table
create table if not exists public.community_rewards (
  id uuid default gen_random_uuid() primary key,
  reward_type text not null check (reward_type in ('xp', 'silver', 'gold', 'frame', 'badge', 'bubble', 'theme', 'tag', 'spin_ticket', 'coupon', 'gift')),
  amount integer not null default 0,
  cosmetic_id text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 18. Create event_rewards table
create table if not exists public.event_rewards (
  id uuid default gen_random_uuid() primary key,
  event_id text not null,
  reward_type text not null check (reward_type in ('xp', 'silver', 'gold', 'frame', 'badge', 'bubble', 'theme', 'tag', 'spin_ticket', 'coupon')),
  amount integer not null default 0,
  cosmetic_id text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 19. Create central configurations
create table if not exists public.reward_config (
  id uuid default gen_random_uuid() primary key,
  key text unique not null,
  value jsonb not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table if not exists public.xp_config (
  id uuid default gen_random_uuid() primary key,
  event_type text unique not null,
  xp_reward integer not null check (xp_reward >= 0),
  cooldown_seconds integer not null default 0 check (cooldown_seconds >= 0),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table if not exists public.economy_config (
  id uuid default gen_random_uuid() primary key,
  key text unique not null,
  value jsonb not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table if not exists public.system_settings (
  id uuid default gen_random_uuid() primary key,
  key text unique not null,
  value jsonb not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- =========================================================================
-- INDEXES FOR SCALE & OPTIMIZATION
-- =========================================================================
create index if not exists idx_xp_history_user_id on public.xp_history(user_id);
create index if not exists idx_task_progress_user_id on public.task_progress(user_id);
create index if not exists idx_reward_claims_user_id on public.reward_claims(user_id);
create index if not exists idx_daily_limits_user_date on public.daily_limits(user_id, date);
create index if not exists idx_checkin_history_user_month on public.checkin_history(user_id, month_key);
create index if not exists idx_achievement_progress_user_id on public.achievement_progress(user_id);
create index if not exists idx_spin_history_user_id on public.spin_history(user_id);
create index if not exists idx_gift_xp_logs_sender on public.gift_xp_logs(sender_id);
create index if not exists idx_gift_xp_logs_receiver on public.gift_xp_logs(receiver_id);

-- =========================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =========================================================================
alter table public.level_requirements enable row level security;
alter table public.user_levels enable row level security;
alter table public.xp_history enable row level security;
alter table public.daily_tasks enable row level security;
alter table public.weekly_tasks enable row level security;
alter table public.monthly_tasks enable row level security;
alter table public.season_tasks enable row level security;
alter table public.task_progress enable row level security;
alter table public.task_rewards enable row level security;
alter table public.level_rewards enable row level security;
alter table public.reward_claims enable row level security;
alter table public.daily_limits enable row level security;
alter table public.checkin_history enable row level security;
alter table public.achievements enable row level security;
alter table public.achievement_progress enable row level security;
alter table public.loyalty_rewards enable row level security;
alter table public.spin_rewards enable row level security;
alter table public.spin_history enable row level security;
alter table public.reward_logs enable row level security;
alter table public.gift_xp_logs enable row level security;
alter table public.community_rewards enable row level security;
alter table public.event_rewards enable row level security;
alter table public.reward_config enable row level security;
alter table public.xp_config enable row level security;
alter table public.economy_config enable row level security;
alter table public.system_settings enable row level security;

-- Setup Select Policies
create policy "Allow all read level_requirements" on public.level_requirements for select using (true);
create policy "Allow all read user_levels" on public.user_levels for select using (true);
create policy "Allow owner read xp_history" on public.xp_history for select using (auth.uid() = user_id);
create policy "Allow all read daily_tasks" on public.daily_tasks for select using (true);
create policy "Allow all read weekly_tasks" on public.weekly_tasks for select using (true);
create policy "Allow all read monthly_tasks" on public.monthly_tasks for select using (true);
create policy "Allow all read season_tasks" on public.season_tasks for select using (true);
create policy "Allow owner read task_progress" on public.task_progress for select using (auth.uid() = user_id);
create policy "Allow all read task_rewards" on public.task_rewards for select using (true);
create policy "Allow all read level_rewards" on public.level_rewards for select using (true);
create policy "Allow owner read reward_claims" on public.reward_claims for select using (auth.uid() = user_id);
create policy "Allow owner read daily_limits" on public.daily_limits for select using (auth.uid() = user_id);
create policy "Allow owner read checkin_history" on public.checkin_history for select using (auth.uid() = user_id);
create policy "Allow all read achievements" on public.achievements for select using (true);
create policy "Allow owner read achievement_progress" on public.achievement_progress for select using (auth.uid() = user_id);
create policy "Allow all read loyalty_rewards" on public.loyalty_rewards for select using (true);
create policy "Allow all read spin_rewards" on public.spin_rewards for select using (true);
create policy "Allow owner read spin_history" on public.spin_history for select using (auth.uid() = user_id);
create policy "Allow owner read reward_logs" on public.reward_logs for select using (auth.uid() = user_id);
create policy "Allow sender/receiver read gift_xp_logs" on public.gift_xp_logs for select using (auth.uid() = sender_id or auth.uid() = receiver_id);
create policy "Allow all read community_rewards" on public.community_rewards for select using (true);
create policy "Allow all read event_rewards" on public.event_rewards for select using (true);
create policy "Allow all read configs" on public.reward_config for select using (true);
create policy "Allow all read xp_config" on public.xp_config for select using (true);
create policy "Allow all read economy_config" on public.economy_config for select using (true);
create policy "Allow all read system_settings" on public.system_settings for select using (true);

-- Admin updates (write) policies for tables
create policy "Allow admin modify level_requirements" on public.level_requirements for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify user_levels" on public.user_levels for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify xp_history" on public.xp_history for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify daily_tasks" on public.daily_tasks for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify weekly_tasks" on public.weekly_tasks for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify monthly_tasks" on public.monthly_tasks for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify season_tasks" on public.season_tasks for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify task_progress" on public.task_progress for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify task_rewards" on public.task_rewards for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify level_rewards" on public.level_rewards for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify reward_claims" on public.reward_claims for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify daily_limits" on public.daily_limits for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify checkin_history" on public.checkin_history for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify achievements" on public.achievements for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify achievement_progress" on public.achievement_progress for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify loyalty_rewards" on public.loyalty_rewards for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify spin_rewards" on public.spin_rewards for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify spin_history" on public.spin_history for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify reward_logs" on public.reward_logs for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify gift_xp_logs" on public.gift_xp_logs for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify community_rewards" on public.community_rewards for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify event_rewards" on public.event_rewards for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify configs" on public.reward_config for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify xp_config" on public.xp_config for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify economy_config" on public.economy_config for all using (public.is_admin(auth.uid()));
create policy "Allow admin modify system_settings" on public.system_settings for all using (public.is_admin(auth.uid()));

-- =========================================================================
-- AUTOMATIC INITIALIZATION TRIGGERS
-- =========================================================================

-- Sync user_levels back to profiles whenever level or xp changes in user_levels
create or replace function public.sync_user_level_to_profile()
returns trigger as $$
begin
  update public.profiles
  set level = new.level,
      experience = new.xp
  where id = new.id;
  return new;
end;
$$ language plpgsql security definer;

create or replace trigger tr_sync_user_level_to_profile
after insert or update of level, xp on public.user_levels
for each row execute function public.sync_user_level_to_profile();

-- Initialize user_levels when a new profile is created
create or replace function public.initialize_user_levels()
returns trigger as $$
begin
  insert into public.user_levels (id, level, xp, total_xp)
  values (new.id, 1, 0, 0)
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

create or replace trigger tr_on_profile_created_levels
after insert on public.profiles
for each row execute function public.initialize_user_levels();


-- =========================================================================
-- REWARDS DISPENSER HELPER
-- =========================================================================
create or replace function public.dispense_reward(
  p_user_id uuid,
  p_source_type text,
  p_source_id text,
  p_reward_type text,
  p_amount integer,
  p_cosmetic_id text
)
returns boolean as $$
declare
  v_wallet_id uuid;
  v_cosmetic_uuid uuid;
begin
  -- Lookup wallet
  select id into v_wallet_id from public.wallets where id = p_user_id;
  if v_wallet_id is null then
    insert into public.wallets (id, gold_coins, silver_coins, diamonds, coupons)
    values (p_user_id, 0, 0, 0, 0)
    returning id into v_wallet_id;
  end if;

  -- 1. Silver / Gold / Coupons
  if p_reward_type = 'silver' then
    update public.wallets set silver_coins = silver_coins + p_amount where id = p_user_id;
    insert into public.wallet_transactions (wallet_id, amount, currency, type, status, reference_id, details)
    values (p_user_id, p_amount, 'Silver Coins', 'Bonus', 'Completed', p_source_id, 'Progression reward from ' || p_source_type);
    
  elsif p_reward_type = 'gold' then
    update public.wallets set gold_coins = gold_coins + p_amount where id = p_user_id;
    insert into public.wallet_transactions (wallet_id, amount, currency, type, status, reference_id, details)
    values (p_user_id, p_amount, 'Gold Coins', 'Bonus', 'Completed', p_source_id, 'Progression reward from ' || p_source_type);

  elsif p_reward_type = 'coupon' or p_reward_type = 'spin_ticket' then
    update public.wallets set coupons = coupons + p_amount where id = p_user_id;
    insert into public.wallet_transactions (wallet_id, amount, currency, type, status, reference_id, details)
    values (p_user_id, p_amount, 'Coupons', 'Bonus', 'Completed', p_source_id, 'Progression reward from ' || p_source_type);

  -- 2. XP Reward (recurses into XP Engine but safely)
  elsif p_reward_type = 'xp' then
    -- Add XP directly to level system (not counted in daily limits as it's a direct reward claim)
    perform public.add_direct_xp(p_user_id, p_amount, p_source_type || ':' || p_source_id);

  -- 3. Cosmetics (Frame, Badge, Title, Theme, Tag, Bubble)
  elsif p_reward_type in ('frame', 'badge', 'bubble', 'theme', 'tag') then
    -- Check if cosmetic exists in cosmetic_assets, otherwise create general one
    select asset_id into v_cosmetic_uuid from public.cosmetic_assets where name = p_cosmetic_id limit 1;
    
    if v_cosmetic_uuid is null then
      -- Auto-generate a general cosmetic asset matching parameters
      insert into public.cosmetic_assets (name, type, category, cdn_url, required_membership, required_level, enabled)
      values (
        p_cosmetic_id,
        case 
          when p_reward_type = 'frame' then 'avatar_frame'::text
          when p_reward_type = 'badge' then 'showcase_badge'::text
          when p_reward_type = 'bubble' then 'chat_bubble'::text
          when p_reward_type = 'theme' then 'profile_theme'::text
          else 'identity_tag'::text
        end,
        'General',
        'https://cdn.creaniaa.com/cosmetics/' || p_cosmetic_id || '.png',
        'None',
        0,
        true
      )
      returning asset_id into v_cosmetic_uuid;
    end if;

    -- Add to user inventory
    insert into public.inventory (user_id, asset_id, purchase_source, status)
    values (p_user_id, v_cosmetic_uuid, 'Admin Grant', 'Active')
    on conflict (user_id, asset_id) do nothing;

    -- Profiles legacy fields updates
    if p_reward_type = 'frame' then
      update public.profiles set avatar_frame = p_cosmetic_id where id = p_user_id;
    elsif p_reward_type = 'theme' then
      update public.profiles set profile_theme = p_cosmetic_id where id = p_user_id;
    elsif p_reward_type = 'badge' then
      update public.profiles set badges = array_append(badges, p_cosmetic_id)
      where id = p_user_id and not (badges @> array[p_cosmetic_id]);
    elsif p_reward_type = 'tag' then
      update public.profiles set r_tags = array_append(r_tags, p_cosmetic_id)
      where id = p_user_id and not (r_tags @> array[p_cosmetic_id]);
    end if;

  -- 4. Gifts (Bound)
  elsif p_reward_type = 'gift' then
    -- Let's log in reward_logs that gifts were granted (e.g. 10 Welcome Bound Roses)
    -- This handles items like Bound Gifts in student inventory
    null;
  end if;

  -- Log rewards
  insert into public.reward_logs (user_id, source_type, source_id, reward_type, amount, cosmetic_id, status)
  values (p_user_id, p_source_type, p_source_id, p_reward_type, p_amount, p_cosmetic_id, 'Granted');

  return true;
exception when others then
  insert into public.reward_logs (user_id, source_type, source_id, reward_type, amount, cosmetic_id, status, reason)
  values (p_user_id, p_source_type, p_source_id, p_reward_type, p_amount, p_cosmetic_id, 'Failed', SQLERRM);
  return false;
end;
$$ language plpgsql security definer;


-- =========================================================================
-- DIRECT XP ADDER (Bypasses caps, used for claim claims)
-- =========================================================================
create or replace function public.add_direct_xp(
  p_user_id uuid,
  p_xp_amount integer,
  p_source text
)
returns void as $$
declare
  v_current_level integer;
  v_current_xp integer;
  v_total_xp integer;
  v_next_xp_required integer;
  v_reward_record record;
begin
  -- Fetch user levels
  select level, xp, total_xp into v_current_level, v_current_xp, v_total_xp
  from public.user_levels
  where id = p_user_id;

  if v_current_level is null then
    return;
  end if;

  v_current_xp := v_current_xp + p_xp_amount;
  v_total_xp := v_total_xp + p_xp_amount;

  -- Level up loop
  loop
    select xp_required into v_next_xp_required
    from public.level_requirements
    where level = v_current_level + 1;

    exit when v_next_xp_required is null or v_current_xp < v_next_xp_required or v_current_level >= 60;

    v_current_xp := v_current_xp - v_next_xp_required;
    v_current_level := v_current_level + 1;

    -- Log Level Up event
    insert into public.xp_history (user_id, event_type, xp_gained, metadata)
    values (p_user_id, 'level_up', 0, jsonb_build_object('reached_level', v_current_level));

    -- Dispense level rewards
    for v_reward_record in 
      select reward_type, amount, cosmetic_id 
      from public.level_rewards 
      where level = v_current_level
    loop
      perform public.dispense_reward(
        p_user_id, 
        'level_up', 
        v_current_level::text, 
        v_reward_record.reward_type, 
        v_reward_record.amount, 
        v_reward_record.cosmetic_id
      );
    end loop;
  end loop;

  update public.user_levels
  set level = v_current_level,
      xp = v_current_xp,
      total_xp = v_total_xp,
      last_xp_update = now(),
      updated_at = now()
  where id = p_user_id;
end;
$$ language plpgsql security definer;


-- =========================================================================
-- CENTRALIZED XP ENGINE (process_xp_event)
-- =========================================================================
create or replace function public.process_xp_event(
  p_event_type text,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_xp_reward integer;
  v_cooldown_seconds integer;
  v_ip text;
  v_device_id text;
  v_recipient_id uuid;
  v_recipient_ip text;
  v_recipient_device_id text;
  v_daily_free_limit integer := 250;
  v_daily_bonus_limit integer := 250;
  v_limit_record record;
  v_xp_gained integer;
  v_is_gift_bonus boolean := false;
  v_current_level integer;
  v_current_xp integer;
  v_total_xp integer;
  v_next_xp_required integer;
  v_reward_record record;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in to trigger progression.';
  end if;

  -- advisory lock to prevent concurrent races
  perform pg_advisory_xact_lock(('x' || substr(md5(v_user_id::text), 1, 15))::bit(60)::bigint);

  -- Fetch configuration
  select xp_reward, cooldown_seconds into v_xp_reward, v_cooldown_seconds
  from public.xp_config
  where event_type = p_event_type;

  if v_xp_reward is null then
    v_xp_reward := 10; -- default fallback
    v_cooldown_seconds := 0;
  end if;

  -- ── Cooldown Check ────────────────────────────────────────────────────────
  if v_cooldown_seconds > 0 then
    if exists (
      select 1 from public.xp_history
      where user_id = v_user_id
        and event_type = p_event_type
        and created_at > now() - (v_cooldown_seconds * interval '1 second')
    ) then
      return jsonb_build_object('success', false, 'reason', 'Cooldown active', 'cooldown_active', true);
    end if;
  end if;

  -- ── Anti-Cheat Engine ─────────────────────────────────────────────────────
  v_ip := p_metadata->>'ip';
  v_device_id := p_metadata->>'device_id';
  
  if p_event_type in ('gift_sent', 'gift_received') then
    v_recipient_id := (p_metadata->>'recipient_id')::uuid;
    v_recipient_ip := p_metadata->>'recipient_ip';
    v_recipient_device_id := p_metadata->>'recipient_device_id';
    v_is_gift_bonus := true;

    -- Self-gifting block
    if v_user_id = v_recipient_id then
      insert into public.reward_logs (user_id, source_type, source_id, reward_type, amount, cosmetic_id, status, reason)
      values (v_user_id, 'xp_engine', p_event_type, 'xp', v_xp_reward, null, 'Blocked', 'Self Gifting detected');
      return jsonb_build_object('success', false, 'reason', 'Anti-cheat: Self gifting is blocked');
    end if;

    -- Alternate accounts block (IP or device ID check)
    if (v_device_id is not null and v_device_id = v_recipient_device_id) or (v_ip is not null and v_ip = v_recipient_ip) then
      insert into public.reward_logs (user_id, source_type, source_id, reward_type, amount, cosmetic_id, status, reason)
      values (v_user_id, 'xp_engine', p_event_type, 'xp', v_xp_reward, null, 'Blocked', 'Alternate account exploitation detected');
      return jsonb_build_object('success', false, 'reason', 'Anti-cheat: Alternate account exploitation detected');
    end if;

    -- Rapid repeated gifting check
    if exists (
      select 1 from public.gift_xp_logs
      where sender_id = v_user_id
        and receiver_id = v_recipient_id
        and created_at > now() - interval '5 seconds'
    ) then
      -- Rate limited gift XP
      return jsonb_build_object('success', false, 'reason', 'Spam protection: Gifting too fast');
    end if;

    -- Log gift transaction
    insert into public.gift_xp_logs (sender_id, receiver_id, gift_id, xp_value)
    values (v_user_id, v_recipient_id, coalesce(p_metadata->>'gift_id', 'unknown'), v_xp_reward);
  end if;

  -- ── Daily XP Limit Validation ─────────────────────────────────────────────
  -- Fetch or create daily limit record
  select * into v_limit_record
  from public.daily_limits
  where user_id = v_user_id and date = current_date;

  if v_limit_record.id is null then
    insert into public.daily_limits (user_id, date, free_xp, bonus_xp)
    values (v_user_id, current_date, 0, 0)
    returning * into v_limit_record;
  end if;

  v_xp_gained := v_xp_reward;

  if v_is_gift_bonus then
    if v_limit_record.bonus_xp >= v_daily_bonus_limit then
      return jsonb_build_object('success', false, 'reason', 'Daily gift bonus XP limit reached');
    end if;
    if v_limit_record.bonus_xp + v_xp_gained > v_daily_bonus_limit then
      v_xp_gained := v_daily_bonus_limit - v_limit_record.bonus_xp;
    end if;
  else
    if p_event_type = 'ad_watched' then
      -- Ad count check (max 5 per day)
      if v_limit_record.ad_count >= 5 then
        return jsonb_build_object('success', false, 'reason', 'Daily rewarded ad limit (5) reached');
      end if;
      update public.daily_limits set ad_count = ad_count + 1 where id = v_limit_record.id;
    end if;

    if v_limit_record.free_xp >= v_daily_free_limit then
      return jsonb_build_object('success', false, 'reason', 'Daily free XP limit reached');
    end if;
    if v_limit_record.free_xp + v_xp_gained > v_daily_free_limit then
      v_xp_gained := v_daily_free_limit - v_limit_record.free_xp;
    end if;
  end if;

  if v_xp_gained <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Daily limit reached');
  end if;

  -- ── Apply XP updates ──────────────────────────────────────────────────────
  -- Update daily limit count
  if v_is_gift_bonus then
    update public.daily_limits set bonus_xp = bonus_xp + v_xp_gained where id = v_limit_record.id;
  else
    update public.daily_limits set free_xp = free_xp + v_xp_gained where id = v_limit_record.id;
  end if;

  -- Update user_levels
  select level, xp, total_xp into v_current_level, v_current_xp, v_total_xp
  from public.user_levels
  where id = v_user_id;

  v_current_xp := v_current_xp + v_xp_gained;
  v_total_xp := v_total_xp + v_xp_gained;

  insert into public.xp_history (user_id, event_type, xp_gained, metadata)
  values (v_user_id, p_event_type, v_xp_gained, p_metadata);

  -- ── Level Up Check ────────────────────────────────────────────────────────
  declare
    v_level_up_occurred boolean := false;
    v_start_level integer := v_current_level;
  begin
    loop
      select xp_required into v_next_xp_required
      from public.level_requirements
      where level = v_current_level + 1;

      exit when v_next_xp_required is null or v_current_xp < v_next_xp_required or v_current_level >= 60;

      v_current_xp := v_current_xp - v_next_xp_required;
      v_current_level := v_current_level + 1;
      v_level_up_occurred := true;

      -- Log level up history
      insert into public.xp_history (user_id, event_type, xp_gained, metadata)
      values (v_user_id, 'level_up', 0, jsonb_build_object('reached_level', v_current_level));

      -- Dispense Level Rewards
      for v_reward_record in 
        select reward_type, amount, cosmetic_id 
        from public.level_rewards 
        where level = v_current_level
      loop
        perform public.dispense_reward(
          v_user_id, 
          'level_up', 
          v_current_level::text, 
          v_reward_record.reward_type, 
          v_reward_record.amount, 
          v_reward_record.cosmetic_id
        );
      end loop;

      -- Send level up app notification
      insert into public.notifications (user_id, title, content, type)
      values (
        v_user_id,
        '🎉 Level Up!',
        'Congratulations! You reached Level ' || v_current_level || '! Check your Progression Hub for unlocked features and rewards.',
        'System'
      );
    end loop;

    -- Reset daily/weekly/monthly sums on date changes (managed on XP update)
    update public.user_levels
    set level = v_current_level,
        xp = v_current_xp,
        total_xp = v_total_xp,
        today_earned_xp = case when last_xp_update::date = current_date then today_earned_xp + v_xp_gained else v_xp_gained end,
        today_bonus_xp = case when last_xp_update::date = current_date then today_bonus_xp + (case when v_is_gift_bonus then v_xp_gained else 0 end) else (case when v_is_gift_bonus then v_xp_gained else 0 end) end,
        weekly_xp = case when date_trunc('week', last_xp_update) = date_trunc('week', now()) then weekly_xp + v_xp_gained else v_xp_gained end,
        monthly_xp = case when date_trunc('month', last_xp_update) = date_trunc('month', now()) then monthly_xp + v_xp_gained else v_xp_gained end,
        last_xp_update = now(),
        updated_at = now()
    where id = v_user_id;

    -- Return progression feedback JSON
    return jsonb_build_object(
      'success', true,
      'xp_gained', v_xp_gained,
      'current_level', v_current_level,
      'current_xp', v_current_xp,
      'level_up_occurred', v_level_up_occurred,
      'levels_gained', v_current_level - v_start_level
    );
  end;
end;
$$ language plpgsql security definer;


-- =========================================================================
-- SECURE TASK ENGINE APIS
-- =========================================================================

-- Get active tasks and current progress
create or replace function public.get_user_tasks()
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_daily_cycle text;
  v_weekly_cycle text;
  v_monthly_cycle text;
  v_season_cycle text := 'season_1'; -- configurable in system_settings
  v_out jsonb;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  v_daily_cycle := to_char(current_date, 'YYYY-MM-DD');
  v_weekly_cycle := to_char(current_date, 'YYYY-') || 'W' || to_char(current_date, 'IW');
  v_monthly_cycle := to_char(current_date, 'YYYY-MM');

  with active_tasks as (
    -- Daily tasks
    select 'daily' as type, task_id, title, description, required_action, required_count, priority, v_daily_cycle as cycle
    from public.daily_tasks where is_active = true
    union all
    -- Weekly tasks
    select 'weekly' as type, task_id, title, description, required_action, required_count, priority, v_weekly_cycle as cycle
    from public.weekly_tasks where is_active = true
    union all
    -- Monthly tasks
    select 'monthly' as type, task_id, title, description, required_action, required_count, priority, v_monthly_cycle as cycle
    from public.monthly_tasks where is_active = true
    union all
    -- Season tasks
    select 'season' as type, task_id, title, description, required_action, required_count, priority, v_season_cycle as cycle
    from public.season_tasks where is_active = true
  ),
  progressed_tasks as (
    select 
      t.type,
      t.task_id,
      t.title,
      t.description,
      t.required_action,
      t.required_count,
      t.priority,
      coalesce(p.current_count, 0) as current_count,
      coalesce(p.is_completed, false) as is_completed,
      coalesce(p.is_claimed, false) as is_claimed,
      (
        select jsonb_agg(jsonb_build_object('reward_type', r.reward_type, 'amount', r.amount, 'cosmetic_id', r.cosmetic_id))
        from public.task_rewards r where r.task_id = t.task_id and r.task_type = t.type
      ) as rewards
    from active_tasks t
    left join public.task_progress p 
      on p.task_id = t.task_id 
     and p.task_type = t.type 
     and p.cycle_key = t.cycle
     and p.user_id = v_user_id
  )
  select jsonb_agg(to_jsonb(pt)) into v_out from progressed_tasks pt;
  
  return coalesce(v_out, '[]'::jsonb);
end;
$$ language plpgsql security definer;

-- Increment progress on tasks (automatically invoked on events)
create or replace function public.increment_task_progress(
  p_user_id uuid,
  p_action text,
  p_amount integer default 1
)
returns void as $$
declare
  v_daily_cycle text := to_char(current_date, 'YYYY-MM-DD');
  v_weekly_cycle text := to_char(current_date, 'YYYY-') || 'W' || to_char(current_date, 'IW');
  v_monthly_cycle text := to_char(current_date, 'YYYY-MM');
  v_season_cycle text := 'season_1';
  v_record record;
begin
  -- Search for daily, weekly, monthly, season tasks listening to this action
  for v_record in 
    select 'daily' as type, task_id, required_count, v_daily_cycle as cycle from public.daily_tasks where required_action = p_action and is_active = true
    union all
    select 'weekly' as type, task_id, required_count, v_weekly_cycle as cycle from public.weekly_tasks where required_action = p_action and is_active = true
    union all
    select 'monthly' as type, task_id, required_count, v_monthly_cycle as cycle from public.monthly_tasks where required_action = p_action and is_active = true
    union all
    select 'season' as type, task_id, required_count, v_season_cycle as cycle from public.season_tasks where required_action = p_action and is_active = true
  loop
    insert into public.task_progress (user_id, task_id, task_type, cycle_key, current_count, is_completed)
    values (p_user_id, v_record.task_id, v_record.type, v_record.cycle, p_amount, p_amount >= v_record.required_count)
    on conflict (user_id, task_id, task_type, cycle_key) do update
    set current_count = task_progress.current_count + p_amount,
        is_completed = (task_progress.current_count + p_amount) >= v_record.required_count,
        completed_at = case when not task_progress.is_completed and (task_progress.current_count + p_amount) >= v_record.required_count then now() else task_progress.completed_at end;
  end loop;
end;
$$ language plpgsql security definer;


-- Claim task reward
create or replace function public.claim_task_reward(
  p_task_id text,
  p_task_type text
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_daily_cycle text := to_char(current_date, 'YYYY-MM-DD');
  v_weekly_cycle text := to_char(current_date, 'YYYY-') || 'W' || to_char(current_date, 'IW');
  v_monthly_cycle text := to_char(current_date, 'YYYY-MM');
  v_season_cycle text := 'season_1';
  v_cycle text;
  v_progress_id uuid;
  v_is_completed boolean;
  v_is_claimed boolean;
  v_reward_record record;
  v_rewards_claimed jsonb := '[]'::jsonb;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  v_cycle := case 
    when p_task_type = 'daily' then v_daily_cycle
    when p_task_type = 'weekly' then v_weekly_cycle
    when p_task_type = 'monthly' then v_monthly_cycle
    else v_season_cycle
  end;

  select id, is_completed, is_claimed into v_progress_id, v_is_completed, v_is_claimed
  from public.task_progress
  where user_id = v_user_id
    and task_id = p_task_id
    and task_type = p_task_type
    and cycle_key = v_cycle;

  if v_progress_id is null or not v_is_completed then
    return jsonb_build_object('success', false, 'reason', 'Task not completed or not found');
  end if;

  if v_is_claimed then
    return jsonb_build_object('success', false, 'reason', 'Reward already claimed');
  end if;

  -- Set claimed
  update public.task_progress
  set is_claimed = true,
      claimed_at = now()
  where id = v_progress_id;

  -- Record in global claims ledger
  insert into public.reward_claims (user_id, source_type, source_id)
  values (v_user_id, 'task', p_task_type || ':' || p_task_id)
  on conflict (user_id, source_type, source_id) do nothing;

  -- Dispense rewards
  for v_reward_record in 
    select reward_type, amount, cosmetic_id 
    from public.task_rewards 
    where task_id = p_task_id and task_type = p_task_type
  loop
    perform public.dispense_reward(
      v_user_id,
      'task',
      p_task_id,
      v_reward_record.reward_type,
      v_reward_record.amount,
      v_reward_record.cosmetic_id
    );
    v_rewards_claimed := v_rewards_claimed || jsonb_build_object(
      'reward_type', v_reward_record.reward_type,
      'amount', v_reward_record.amount,
      'cosmetic_id', v_reward_record.cosmetic_id
    );
  end loop;

  return jsonb_build_object('success', true, 'rewards_claimed', v_rewards_claimed);
end;
$$ language plpgsql security definer;


-- =========================================================================
-- SECURE CHECK-IN ENGINE APIS
-- =========================================================================

-- Get checkin status (calendar)
create or replace function public.get_checkin_status()
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_month_key text := to_char(current_date, 'YYYY-MM');
  v_claimed_days integer[];
  v_can_claim_today boolean := true;
  v_streak_count integer := 0;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  -- Find claimed days this month
  select coalesce(array_agg(day_number order by day_number), '{}') into v_claimed_days
  from public.checkin_history
  where user_id = v_user_id and month_key = v_month_key;

  -- Streak is the size of claimed days this month
  v_streak_count := array_length(v_claimed_days, 1);
  if v_streak_count is null then
    v_streak_count := 0;
  end if;

  -- Check if already claimed today
  -- Calendar works sequentially: Day 1, Day 2, etc.
  -- Next claimable day is v_streak_count + 1, provided user hasn't claimed in the last 24h/calendar day
  if exists (
    select 1 from public.checkin_history
    where user_id = v_user_id
      and month_key = v_month_key
      and claimed_at::date = current_date
  ) then
    v_can_claim_today := false;
  end if;

  return jsonb_build_object(
    'month_key', v_month_key,
    'claimed_days', coalesce(to_jsonb(v_claimed_days), '[]'::jsonb),
    'can_claim_today', v_can_claim_today,
    'next_day_to_claim', v_streak_count + 1,
    'streak_count', v_streak_count
  );
end;
$$ language plpgsql security definer;

-- Claim checkin
create or replace function public.claim_checkin()
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_month_key text := to_char(current_date, 'YYYY-MM');
  v_streak_count integer;
  v_next_day integer;
  v_reward_type text;
  v_amount integer;
  v_cosmetic_id text;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  -- Lock user checkin sequence
  perform pg_advisory_xact_lock(('x' || substr(md5(v_user_id::text), 1, 15))::bit(60)::bigint);

  -- Check if already checked-in today
  if exists (
    select 1 from public.checkin_history
    where user_id = v_user_id
      and month_key = v_month_key
      and claimed_at::date = current_date
  ) then
    raise exception 'ALREADY_CLAIMED: You have already checked in today.';
  end if;

  select count(*) into v_streak_count
  from public.checkin_history
  where user_id = v_user_id and month_key = v_month_key;

  v_next_day := v_streak_count + 1;
  if v_next_day > 30 then
    raise exception 'CALENDAR_FULL: 30-day calendar completed for this month.';
  end if;

  -- Reward configuration for 30-day check-in calendar
  -- Generates Silver, Gold, Coupons, Spin Tickets, or XP based on day sequence
  if v_next_day % 30 = 0 then
    -- Day 30 jackpot
    v_reward_type := 'gold'; v_amount := 50; v_cosmetic_id := null;
  elsif v_next_day % 7 = 0 then
    -- Weekly milestone
    v_reward_type := 'spin_ticket'; v_amount := 1; v_cosmetic_id := null;
  elsif v_next_day % 3 = 0 then
    v_reward_type := 'xp'; v_amount := 100; v_cosmetic_id := null;
  else
    v_reward_type := 'silver'; v_amount := 150; v_cosmetic_id := null;
  end if;

  -- Insert to history
  insert into public.checkin_history (user_id, month_key, day_number)
  values (v_user_id, v_month_key, v_next_day);

  -- Claim rewards
  insert into public.reward_claims (user_id, source_type, source_id)
  values (v_user_id, 'checkin', v_month_key || ':' || v_next_day)
  on conflict (user_id, source_type, source_id) do nothing;

  perform public.dispense_reward(
    v_user_id,
    'checkin',
    v_month_key || ':' || v_next_day,
    v_reward_type,
    v_amount,
    v_cosmetic_id
  );

  return jsonb_build_object(
    'success', true,
    'day_claimed', v_next_day,
    'reward_type', v_reward_type,
    'amount', v_amount,
    'cosmetic_id', v_cosmetic_id
  );
end;
$$ language plpgsql security definer;


-- =========================================================================
-- SECURE LUCKY SPIN ENGINE APIS
-- =========================================================================

-- Execute Lucky Spin
create or replace function public.execute_lucky_spin(
  p_spin_type text
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_spin_cost integer;
  v_currency text;
  v_wallet_balance integer;
  v_random double precision;
  v_cumulative double precision := 0.0;
  v_reward_record record;
  v_won_reward record;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  perform pg_advisory_xact_lock(('x' || substr(md5(v_user_id::text), 1, 15))::bit(60)::bigint);

  -- Determine spin cost & currency
  if p_spin_type = 'silver' then
    v_spin_cost := 500; v_currency := 'silver';
  elsif p_spin_type = 'gold' then
    v_spin_cost := 50; v_currency := 'gold';
  elsif p_spin_type = 'premium' then
    -- Requires 1 Coupon (Spin Ticket)
    v_spin_cost := 1; v_currency := 'coupon';
  else
    raise exception 'INVALID_SPIN_TYPE: Spin type must be silver, gold, or premium.';
  end if;

  -- Check cost eligibility in wallets
  if v_currency = 'silver' then
    select silver_coins into v_wallet_balance from public.wallets where id = v_user_id;
    if v_wallet_balance is null or v_wallet_balance < v_spin_cost then
      raise exception 'INSUFFICIENT_FUNDS: Insufficient Silver Coins.';
    end if;
    update public.wallets set silver_coins = silver_coins - v_spin_cost where id = v_user_id;
    insert into public.wallet_transactions (wallet_id, amount, currency, type, status, reference_id, details)
    values (v_user_id, -v_spin_cost, 'Silver Coins', 'Spend', 'Completed', p_spin_type, 'Lucky Spin cost');

  elsif v_currency = 'gold' then
    select gold_coins into v_wallet_balance from public.wallets where id = v_user_id;
    if v_wallet_balance is null or v_wallet_balance < v_spin_cost then
      raise exception 'INSUFFICIENT_FUNDS: Insufficient Gold Coins.';
    end if;
    update public.wallets set gold_coins = gold_coins - v_spin_cost where id = v_user_id;
    insert into public.wallet_transactions (wallet_id, amount, currency, type, status, reference_id, details)
    values (v_user_id, -v_spin_cost, 'Gold Coins', 'Spend', 'Completed', p_spin_type, 'Lucky Spin cost');

  elsif v_currency = 'coupon' then
    select coupons into v_wallet_balance from public.wallets where id = v_user_id;
    if v_wallet_balance is null or v_wallet_balance < v_spin_cost then
      raise exception 'INSUFFICIENT_FUNDS: Insufficient Spin Tickets/Coupons.';
    end if;
    update public.wallets set coupons = coupons - v_spin_cost where id = v_user_id;
    insert into public.wallet_transactions (wallet_id, amount, currency, type, status, reference_id, details)
    values (v_user_id, -v_spin_cost, 'Coupons', 'Spend', 'Completed', p_spin_type, 'Lucky Spin cost');
  end if;

  -- Execute weighted probabilities
  v_random := random();

  for v_reward_record in
    select id, reward_type, amount, cosmetic_id, probability
    from public.spin_rewards
    where spin_type = p_spin_type and is_active = true
    order by probability desc
  loop
    v_cumulative := v_cumulative + v_reward_record.probability;
    if v_random <= v_cumulative then
      v_won_reward := v_reward_record;
      exit;
    end if;
  end loop;

  -- Fallback in case rounding exceeds cumulative
  if v_won_reward.id is null then
    select id, reward_type, amount, cosmetic_id, probability into v_won_reward
    from public.spin_rewards
    where spin_type = p_spin_type and is_active = true
    order by probability desc limit 1;
  end if;

  -- Claim rewards
  perform public.dispense_reward(
    v_user_id,
    'spin',
    p_spin_type,
    v_won_reward.reward_type,
    v_won_reward.amount,
    v_won_reward.cosmetic_id
  );

  -- Log history
  insert into public.spin_history (user_id, spin_type, won_reward_id, won_reward_type, won_amount)
  values (v_user_id, p_spin_type, v_won_reward.id, v_won_reward.reward_type, v_won_reward.amount);

  return jsonb_build_object(
    'success', true,
    'won_reward_type', v_won_reward.reward_type,
    'won_amount', v_won_reward.amount,
    'won_cosmetic_id', v_won_reward.cosmetic_id
  );
end;
$$ language plpgsql security definer;


-- =========================================================================
-- SECURE FIRST COMMUNITY JOIN & WELCOME REWARDS API
-- =========================================================================
create or replace function public.claim_first_community_join_reward()
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_is_verified boolean;
  v_already_claimed boolean;
  v_rewards_dispensed jsonb := '[]'::jsonb;
  v_reward_record record;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  perform pg_advisory_xact_lock(('x' || substr(md5(v_user_id::text), 1, 15))::bit(60)::bigint);

  -- Verify verified account status
  select verified into v_is_verified from public.profiles where id = v_user_id;
  if not v_is_verified then
    raise exception 'VERIFICATION_REQUIRED: Only verified accounts are eligible for the welcome package.';
  end if;

  -- Check if already claimed
  select exists (
    select 1 from public.reward_claims
    where user_id = v_user_id and source_type = 'community' and source_id = 'first_join'
  ) into v_already_claimed;

  if v_already_claimed then
    raise exception 'ALREADY_CLAIMED: First community join reward already claimed.';
  end if;

  -- Enforce they have joined at least 1 community in memberships
  if not exists (
    select 1 from public.community_memberships where user_id = v_user_id
  ) then
    raise exception 'COMMUNITY_REQUIRED: You must join at least one community first.';
  end if;

  -- Set claimed
  insert into public.reward_claims (user_id, source_type, source_id)
  values (v_user_id, 'community', 'first_join');

  -- Dispense rewards from community_rewards table
  for v_reward_record in 
    select reward_type, amount, cosmetic_id 
    from public.community_rewards
  loop
    perform public.dispense_reward(
      v_user_id,
      'community',
      'first_join',
      v_reward_record.reward_type,
      v_reward_record.amount,
      v_reward_record.cosmetic_id
    );
    v_rewards_dispensed := v_rewards_dispensed || jsonb_build_object(
      'reward_type', v_reward_record.reward_type,
      'amount', v_reward_record.amount,
      'cosmetic_id', v_reward_record.cosmetic_id
    );
  end loop;

  -- Trigger Welcome Achievement
  insert into public.achievement_progress (user_id, achievement_id, current_count, is_completed, completed_at)
  values (v_user_id, 'first_community_join', 1, true, now())
  on conflict (user_id, achievement_id) do update
  set is_completed = true, completed_at = now();

  return jsonb_build_object('success', true, 'rewards_claimed', v_rewards_dispensed);
end;
$$ language plpgsql security definer;


-- =========================================================================
-- SECURE ACHIEVEMENTS & LOYALTY APIS
-- =========================================================================

-- Get user achievements list and progress status
create or replace function public.get_user_achievements()
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_out jsonb;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  with expanded_achievements as (
    select 
      a.achievement_id,
      a.title,
      a.description,
      a.required_action,
      a.required_count,
      a.reward_type,
      a.reward_amount,
      a.reward_cosmetic_id,
      coalesce(ap.current_count, 0) as current_count,
      coalesce(ap.is_completed, false) as is_completed,
      coalesce(ap.is_claimed, false) as is_claimed
    from public.achievements a
    left join public.achievement_progress ap 
      on ap.achievement_id = a.achievement_id 
     and ap.user_id = v_user_id
  )
  select jsonb_agg(to_jsonb(ea)) into v_out from expanded_achievements ea;

  return coalesce(v_out, '[]'::jsonb);
end;
$$ language plpgsql security definer;

-- Claim achievement reward
create or replace function public.claim_achievement_reward(
  p_achievement_id text
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_progress_id uuid;
  v_is_completed boolean;
  v_is_claimed boolean;
  v_reward_type text;
  v_amount integer;
  v_cosmetic_id text;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  perform pg_advisory_xact_lock(('x' || substr(md5(v_user_id::text), 1, 15))::bit(60)::bigint);

  select id, is_completed, is_claimed into v_progress_id, v_is_completed, v_is_claimed
  from public.achievement_progress
  where user_id = v_user_id and achievement_id = p_achievement_id;

  if v_progress_id is null or not v_is_completed then
    raise exception 'NOT_COMPLETED: Achievement not completed or not registered.';
  end if;

  if v_is_claimed then
    raise exception 'ALREADY_CLAIMED: Achievement reward already claimed.';
  end if;

  -- Set claimed
  update public.achievement_progress
  set is_claimed = true, claimed_at = now()
  where id = v_progress_id;

  insert into public.reward_claims (user_id, source_type, source_id)
  values (v_user_id, 'achievement', p_achievement_id)
  on conflict (user_id, source_type, source_id) do nothing;

  -- Fetch reward definitions
  select reward_type, reward_amount, reward_cosmetic_id into v_reward_type, v_amount, v_cosmetic_id
  from public.achievements
  where achievement_id = p_achievement_id;

  perform public.dispense_reward(
    v_user_id,
    'achievement',
    p_achievement_id,
    v_reward_type,
    v_amount,
    v_cosmetic_id
  );

  return jsonb_build_object(
    'success', true,
    'reward_type', v_reward_type,
    'amount', v_amount,
    'cosmetic_id', v_cosmetic_id
  );
end;
$$ language plpgsql security definer;


-- Get loyalty milestones and progress
create or replace function public.get_loyalty_status()
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_active_days integer := 0;
  v_milestones jsonb;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  -- Count total distinct active days of login
  select count(distinct login_time::date) into v_active_days
  from public.login_history
  where user_id = v_user_id;

  with milestones_agg as (
    select 
      l.active_days as required_days,
      l.reward_type,
      l.amount,
      l.cosmetic_id,
      exists (
        select 1 from public.reward_claims
        where user_id = v_user_id and source_type = 'loyalty' and source_id = l.active_days::text
      ) as is_claimed
    from public.loyalty_rewards l
  )
  select jsonb_agg(to_jsonb(ma)) into v_milestones from milestones_agg ma;

  return jsonb_build_object(
    'total_active_days', v_active_days,
    'milestones', coalesce(v_milestones, '[]'::jsonb)
  );
end;
$$ language plpgsql security definer;

-- Claim loyalty milestone
create or replace function public.claim_loyalty_reward(
  p_active_days integer
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_active_days integer := 0;
  v_reward_type text;
  v_amount integer;
  v_cosmetic_id text;
  v_already_claimed boolean;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  perform pg_advisory_xact_lock(('x' || substr(md5(v_user_id::text), 1, 15))::bit(60)::bigint);

  -- Count total distinct active days of login
  select count(distinct login_time::date) into v_active_days
  from public.login_history
  where user_id = v_user_id;

  if v_active_days < p_active_days then
    raise exception 'NOT_ELIGIBLE: Insufficient active days. Required: %, You have: %', p_active_days, v_active_days;
  end if;

  select exists (
    select 1 from public.reward_claims
    where user_id = v_user_id and source_type = 'loyalty' and source_id = p_active_days::text
  ) into v_already_claimed;

  if v_already_claimed then
    raise exception 'ALREADY_CLAIMED: Loyalty milestone reward already claimed.';
  end if;

  -- Fetch reward
  select reward_type, amount, cosmetic_id into v_reward_type, v_amount, v_cosmetic_id
  from public.loyalty_rewards
  where active_days = p_active_days;

  if v_reward_type is null then
    raise exception 'NOT_FOUND: Milestone configuration not found.';
  end if;

  -- Claim rewards
  insert into public.reward_claims (user_id, source_type, source_id)
  values (v_user_id, 'loyalty', p_active_days::text);

  perform public.dispense_reward(
    v_user_id,
    'loyalty',
    p_active_days::text,
    v_reward_type,
    v_amount,
    v_cosmetic_id
  );

  return jsonb_build_object(
    'success', true,
    'reward_type', v_reward_type,
    'amount', v_amount,
    'cosmetic_id', v_cosmetic_id
  );
end;
$$ language plpgsql security definer;


-- =========================================================================
-- SECURE ADMIN PORTAL RPC FUNCTIONS
-- =========================================================================

-- Adjust user XP (Add/subtract/set)
create or replace function public.admin_adjust_user_xp(
  p_target_user_id uuid,
  p_xp_amount integer,
  p_is_absolute boolean default false
)
returns jsonb as $$
declare
  v_admin_id uuid := auth.uid();
  v_current_level integer;
  v_current_xp integer;
  v_total_xp integer;
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'UNAUTHORIZED: Admin access only.';
  end if;

  select level, xp, total_xp into v_current_level, v_current_xp, v_total_xp
  from public.user_levels
  where id = p_target_user_id;

  if v_current_level is null then
    raise exception 'USER_NOT_FOUND: User progression row not found.';
  end if;

  if p_is_absolute then
    v_current_xp := p_xp_amount;
    v_total_xp := p_xp_amount;
  else
    v_current_xp := v_current_xp + p_xp_amount;
    v_total_xp := v_total_xp + p_xp_amount;
  end if;

  update public.user_levels
  set xp = greatest(v_current_xp, 0),
      total_xp = greatest(v_total_xp, 0),
      updated_at = now()
  where id = p_target_user_id;

  -- Run Level Up checks
  perform public.add_direct_xp(p_target_user_id, 0, 'admin_adjust');

  -- Log action
  insert into public.audit_logs (actor_id, action, details)
  values (v_admin_id, 'admin_adjust_xp', jsonb_build_object('target', p_target_user_id, 'xp_added', p_xp_amount, 'is_absolute', p_is_absolute));

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

-- Set user Level
create or replace function public.admin_adjust_user_level(
  p_target_user_id uuid,
  p_level integer
)
returns jsonb as $$
declare
  v_admin_id uuid := auth.uid();
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'UNAUTHORIZED: Admin access only.';
  end if;

  if p_level < 1 or p_level > 60 then
    raise exception 'INVALID_LEVEL: Level must be between 1 and 60.';
  end if;

  update public.user_levels
  set level = p_level,
      xp = 0, -- resets current level XP
      updated_at = now()
  where id = p_target_user_id;

  -- Log action
  insert into public.audit_logs (actor_id, action, details)
  values (v_admin_id, 'admin_adjust_level', jsonb_build_object('target', p_target_user_id, 'new_level', p_level));

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

-- Configure Task
create or replace function public.admin_configure_task(
  p_task_id text,
  p_task_type text,
  p_title text,
  p_description text,
  p_required_action text,
  p_required_count integer,
  p_is_active boolean,
  p_rewards jsonb -- array of rewards: [{"reward_type": "xp", "amount": 50}, ...]
)
returns jsonb as $$
declare
  v_admin_id uuid := auth.uid();
  v_reward record;
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'UNAUTHORIZED: Admin access only.';
  end if;

  -- 1. Upsert into appropriate task registry table
  if p_task_type = 'daily' then
    insert into public.daily_tasks (task_id, title, description, required_action, required_count, is_active, updated_at)
    values (p_task_id, p_title, p_description, p_required_action, p_required_count, p_is_active, now())
    on conflict (task_id) do update 
    set title = excluded.title, description = excluded.description, required_action = excluded.required_action, required_count = excluded.required_count, is_active = excluded.is_active, updated_at = now();
  elsif p_task_type = 'weekly' then
    insert into public.weekly_tasks (task_id, title, description, required_action, required_count, is_active, updated_at)
    values (p_task_id, p_title, p_description, p_required_action, p_required_count, p_is_active, now())
    on conflict (task_id) do update 
    set title = excluded.title, description = excluded.description, required_action = excluded.required_action, required_count = excluded.required_count, is_active = excluded.is_active, updated_at = now();
  elsif p_task_type = 'monthly' then
    insert into public.monthly_tasks (task_id, title, description, required_action, required_count, is_active, updated_at)
    values (p_task_id, p_title, p_description, p_required_action, p_required_count, p_is_active, now())
    on conflict (task_id) do update 
    set title = excluded.title, description = excluded.description, required_action = excluded.required_action, required_count = excluded.required_count, is_active = excluded.is_active, updated_at = now();
  elsif p_task_type = 'season' then
    insert into public.season_tasks (task_id, title, description, required_action, required_count, is_active, updated_at)
    values (p_task_id, p_title, p_description, p_required_action, p_required_count, p_is_active, now())
    on conflict (task_id) do update 
    set title = excluded.title, description = excluded.description, required_action = excluded.required_action, required_count = excluded.required_count, is_active = excluded.is_active, updated_at = now();
  end if;

  -- 2. Repopulate rewards
  delete from public.task_rewards where task_id = p_task_id and task_type = p_task_type;
  
  for v_reward in select * from jsonb_to_recordset(p_rewards) as r(reward_type text, amount integer, cosmetic_id text) loop
    insert into public.task_rewards (task_id, task_type, reward_type, amount, cosmetic_id)
    values (p_task_id, p_task_type, v_reward.reward_type, v_reward.amount, v_reward.cosmetic_id);
  end loop;

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

-- Configure spin probabilities
create or replace function public.admin_configure_spin_reward(
  p_spin_type text,
  p_reward_type text,
  p_amount integer,
  p_cosmetic_id text,
  p_probability double precision
)
returns jsonb as $$
declare
  v_admin_id uuid := auth.uid();
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'UNAUTHORIZED: Admin access only.';
  end if;

  insert into public.spin_rewards (spin_type, reward_type, amount, cosmetic_id, probability)
  values (p_spin_type, p_reward_type, p_amount, p_cosmetic_id, p_probability)
  on conflict (id) do update
  set reward_type = excluded.reward_type, amount = excluded.amount, cosmetic_id = excluded.cosmetic_id, probability = excluded.probability, updated_at = now();

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

-- Grant cosmetics directly (Frames, Badges, Tags, etc.)
create or replace function public.admin_grant_cosmetic(
  p_target_user_id uuid,
  p_cosmetic_type text,
  p_cosmetic_id text
)
returns jsonb as $$
declare
  v_admin_id uuid := auth.uid();
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'UNAUTHORIZED: Admin access only.';
  end if;

  perform public.dispense_reward(
    p_target_user_id,
    'admin_grant',
    'admin_panel',
    p_cosmetic_type,
    1,
    p_cosmetic_id
  );

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

-- Grant currencies directly
create or replace function public.admin_grant_currency(
  p_target_user_id uuid,
  p_currency_type text, -- silver, gold
  p_amount integer
)
returns jsonb as $$
declare
  v_admin_id uuid := auth.uid();
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'UNAUTHORIZED: Admin access only.';
  end if;

  perform public.dispense_reward(
    p_target_user_id,
    'admin_grant',
    'admin_panel',
    p_currency_type,
    p_amount,
    null
  );

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

-- View abuse / anti-cheat reports
create or replace function public.admin_get_abuse_reports()
returns jsonb as $$
declare
  v_admin_id uuid := auth.uid();
  v_logs jsonb;
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'UNAUTHORIZED: Admin access only.';
  end if;

  select jsonb_agg(to_jsonb(l)) into v_logs
  from (
    select id, user_id, source_type, source_id, reward_type, amount, status, reason, created_at
    from public.reward_logs
    where status = 'Blocked'
    order by created_at desc
    limit 100
  ) l;

  return coalesce(v_logs, '[]'::jsonb);
end;
$$ language plpgsql security definer;

-- Reset user progression
create or replace function public.admin_reset_user_progression(
  p_target_user_id uuid
)
returns jsonb as $$
declare
  v_admin_id uuid := auth.uid();
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'UNAUTHORIZED: Admin access only.';
  end if;

  update public.user_levels
  set level = 1,
      xp = 0,
      total_xp = 0,
      today_earned_xp = 0,
      today_bonus_xp = 0,
      weekly_xp = 0,
      monthly_xp = 0,
      last_xp_update = now(),
      updated_at = now()
  where id = p_target_user_id;

  -- Clear claims and history
  delete from public.reward_claims where user_id = p_target_user_id;
  delete from public.xp_history where user_id = p_target_user_id;
  delete from public.task_progress where user_id = p_target_user_id;
  delete from public.checkin_history where user_id = p_target_user_id;
  delete from public.achievement_progress where user_id = p_target_user_id;
  delete from public.spin_history where user_id = p_target_user_id;

  -- Log action
  insert into public.audit_logs (actor_id, action, details)
  values (v_admin_id, 'admin_reset_progression', jsonb_build_object('target', p_target_user_id));

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;


-- =========================================================================
-- PRE-POPULATE DATA FOR CORE PROGRESSIONS
-- =========================================================================

-- Prepopulate XP configuration rewards
insert into public.xp_config (event_type, xp_reward, cooldown_seconds) values
('room_joined', 10, 300),
('room_hosted', 30, 1800),
('gift_sent', 20, 0),
('gift_received', 20, 0),
('daily_login', 50, 86400),
('community_joined', 15, 0),
('task_completed', 25, 0),
('quiz_passed', 40, 0),
('ad_watched', 50, 0),
('voice_chat_time', 10, 60),
('achievement_completed', 100, 0)
on conflict (event_type) do update set xp_reward = excluded.xp_reward, cooldown_seconds = excluded.cooldown_seconds;

-- Prepopulate default tasks
insert into public.daily_tasks (task_id, title, description, required_action, required_count, priority) values
('daily_login', 'Daily Login', 'Sign into Creaniaa today', 'daily_login', 1, 10),
('join_room', 'Join a Voice Room', 'Hangout in any voice chat room', 'room_joined', 1, 8),
('host_room', 'Host a Voice Room', 'Host an audio session for your friends', 'room_hosted', 1, 6),
('send_gift', 'Send a Gift', 'Send any virtual gift to another user', 'gift_sent', 1, 4),
('watch_ad', 'Watch Ad', 'Watch a rewarded video ad to earn rewards', 'ad_watched', 1, 2)
on conflict (task_id) do nothing;

insert into public.weekly_tasks (task_id, title, description, required_action, required_count, priority) values
('weekly_rooms', 'Weekly Hangout', 'Join 5 voice chat rooms this week', 'room_joined', 5, 5),
('weekly_gifts', 'Generous Giver', 'Send 10 gifts to users in voice rooms', 'gift_sent', 10, 3)
on conflict (task_id) do nothing;

insert into public.monthly_tasks (task_id, title, description, required_action, required_count, priority) values
('monthly_login', 'Consistent Learner', 'Log into Creaniaa 20 distinct days this month', 'daily_login', 20, 5)
on conflict (task_id) do nothing;

insert into public.season_tasks (task_id, title, description, required_action, required_count, priority) values
('season_hosted', 'Agora Host Master', 'Host 15 voice room sessions this season', 'room_hosted', 15, 10)
on conflict (task_id) do nothing;

-- Prepopulate task rewards
-- Daily Login rewards
insert into public.task_rewards (task_id, task_type, reward_type, amount) values
('daily_login', 'daily', 'xp', 50),
('daily_login', 'daily', 'silver', 100),
('join_room', 'daily', 'xp', 20),
('join_room', 'daily', 'silver', 50),
('host_room', 'daily', 'xp', 40),
('host_room', 'daily', 'silver', 100),
('send_gift', 'daily', 'xp', 30),
('send_gift', 'daily', 'silver', 100),
('watch_ad', 'daily', 'xp', 50),
('watch_ad', 'daily', 'silver', 200)
on conflict do nothing;

-- Weekly tasks rewards
insert into public.task_rewards (task_id, task_type, reward_type, amount) values
('weekly_rooms', 'weekly', 'xp', 150),
('weekly_rooms', 'weekly', 'silver', 500),
('weekly_gifts', 'weekly', 'xp', 200),
('weekly_gifts', 'weekly', 'silver', 600)
on conflict do nothing;

-- Monthly tasks rewards
insert into public.task_rewards (task_id, task_type, reward_type, amount) values
('monthly_login', 'monthly', 'xp', 500),
('monthly_login', 'monthly', 'silver', 2000)
on conflict do nothing;

-- Season tasks rewards
insert into public.task_rewards (task_id, task_type, reward_type, amount) values
('season_hosted', 'season', 'xp', 1000),
('season_hosted', 'season', 'silver', 5000)
on conflict do nothing;

-- Prepopulate Level Rewards
insert into public.level_rewards (level, reward_type, amount, cosmetic_id) values
(5, 'silver', 100, null),
(5, 'gold', 10, null),
(5, 'frame', 1, 'Beginner Frame'),
(10, 'silver', 500, null),
(10, 'gold', 20, null),
(10, 'badge', 1, 'Explorer Badge'),
(15, 'silver', 1000, null),
(15, 'tag', 1, 'Pathfinder Tag'),
(20, 'silver', 2000, null),
(20, 'bubble', 1, 'Trailblazer Bubble'),
(30, 'silver', 5000, null),
(30, 'theme', 1, 'Elite Theme'),
(45, 'silver', 10000, null),
(45, 'badge', 1, 'Vanguard Title'),
(60, 'silver', 20000, null),
(60, 'gold', 500, null),
(60, 'frame', 1, 'Immortal Crown')
on conflict do nothing;

-- Prepopulate Achievements
insert into public.achievements (achievement_id, title, description, required_action, required_count, reward_type, reward_amount, reward_cosmetic_id) values
('friend_100', 'Centurion Friendlist', 'Build relationships and gain 100 friends', 'friend_added', 100, 'frame', 1, 'Welcome Frame'),
('login_365', 'Yearly Dedication', 'Log in for 365 distinct days', 'daily_login', 365, 'badge', 1, 'Legend Badge'),
('rooms_hosted_100', 'Broadcasting Legend', 'Host 100 voice room broadcast sessions', 'room_hosted', 100, 'frame', 1, 'Host Frame'),
('messages_10000', 'Agora Chat Master', 'Send 10,000 chat messages', 'message_sent', 10000, 'tag', 1, 'Talkative Tag'),
('communities_100', 'Global Networker', 'Join 100 different study communities', 'community_joined', 100, 'badge', 1, 'Socializer Badge'),
('first_community_join', 'Creaniaa Community Welcome', 'Join your first study community', 'community_joined', 1, 'badge', 1, 'Welcome Badge')
on conflict (achievement_id) do nothing;

-- Prepopulate loyalty milestones
insert into public.loyalty_rewards (active_days, reward_type, amount, cosmetic_id) values
(100, 'badge', 1, 'Veteran Badge'),
(200, 'badge', 1, 'Elite Explorer Badge'),
(365, 'frame', 1, '365 Club Frame'),
(730, 'title', 1, 'Legendary Veteran Title'),
(1460, 'frame', 1, 'Agora Immortal Crown')
on conflict (active_days) do nothing;

-- Prepopulate Spin Rewards
-- Silver Spin
insert into public.spin_rewards (spin_type, reward_type, amount, cosmetic_id, probability) values
('silver', 'silver', 50, null, 0.40),
('silver', 'silver', 100, null, 0.30),
('silver', 'silver', 200, null, 0.15),
('silver', 'silver', 500, null, 0.08),
('silver', 'frame', 1, 'Spin Frame', 0.02),
('silver', 'xp', 50, null, 0.05)
on conflict do nothing;

-- Gold Spin
insert into public.spin_rewards (spin_type, reward_type, amount, cosmetic_id, probability) values
('gold', 'gold', 10, null, 0.40),
('gold', 'gold', 20, null, 0.30),
('gold', 'gold', 50, null, 0.15),
('gold', 'gold', 100, null, 0.08),
('gold', 'frame', 1, 'Gold Spin Frame', 0.02),
('gold', 'xp', 100, null, 0.05)
on conflict do nothing;

-- Premium Spin
insert into public.spin_rewards (spin_type, reward_type, amount, cosmetic_id, probability) values
('premium', 'silver', 5000, null, 0.30),
('premium', 'gold', 500, null, 0.20),
('premium', 'gold', 1000, null, 0.15),
('premium', 'frame', 1, 'Premium Avatar Frame', 0.10),
('premium', 'theme', 1, 'Premium Theme', 0.05),
('premium', 'xp', 500, null, 0.20)
on conflict do nothing;

-- Prepopulate Welcome Rewards for first community join
insert into public.community_rewards (reward_type, amount, cosmetic_id) values
('silver', 500, null),
('gift', 10, 'rose_2star'),
('xp', 50, null),
('badge', 1, 'Welcome Badge')
on conflict do nothing;


-- =========================================================================
-- SYSTEM REALTIME REGISTRATION
-- =========================================================================
do $$
begin
  alter publication supabase_realtime add table public.user_levels;
  alter publication supabase_realtime add table public.task_progress;
  alter publication supabase_realtime add table public.achievement_progress;
exception when others then
  raise notice 'Tables already registered in supabase_realtime';
end;
$$;
