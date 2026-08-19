-- ==========================================================================
-- Consolidated Supabase Migration Module 12: 202607090012_settings_and_system_events.sql
-- Authoritative baseline schema, functions, triggers, policies, and seeds.
-- ==========================================================================

-- 202607090000_extensions_and_privileges.sql
-- Enable database extensions and grant base privileges

create extension if not exists "uuid-ossp";

-- Grant explicit privileges on ALL current tables and sequences in public schema
grant select, insert, update, delete on all tables in schema public to authenticated;

grant select, insert, update, delete on all tables in schema public to anon;

grant usage, select on all sequences in schema public to authenticated;

grant usage, select on all sequences in schema public to anon;

-- Configure default privileges so any future tables automatically inherit these permissions
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;

alter default privileges in schema public grant select, insert, update, delete on tables to anon;

alter default privileges in schema public grant usage, select on sequences to authenticated;

alter default privileges in schema public grant usage, select on sequences to anon;

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

-- Setup Select Policies
create policy "Allow all read level_requirements" on public.level_requirements for select using (true);

-- Admin updates (write) policies for tables
create policy "Allow admin modify level_requirements" on public.level_requirements for all using (public.is_admin(auth.uid()));

insert into public.monthly_tasks (task_id, title, description, required_action, required_count, priority) values
('monthly_login', 'Consistent Learner', 'Log into Creaniaa 20 distinct days this month', 'daily_login', 20, 5)
on conflict (task_id) do nothing;

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

-- Migration 202607170011_adjust_progression_rules.sql
-- Adjust XP curve, activate tasks, configure rewarded ad rewards, and implement 7-day rolling streak check-in system.

-- 1. Increase XP curve requirements up to Level 60 (Base 200, 1.11 multiplier)
do $$
declare
  v_lvl integer;
  v_xp integer;
  v_total_xp integer := 0;
begin
  -- Update level 1
  insert into public.level_requirements (level, xp_required, total_xp_required)
  values (1, 0, 0)
  on conflict (level) do update set xp_required = 0, total_xp_required = 0;

  for v_lvl in 2..60 loop
    v_xp := round(200.0 * power(1.11, v_lvl - 1))::integer;
    v_total_xp := v_total_xp + v_xp;
    insert into public.level_requirements (level, xp_required, total_xp_required)
    values (v_lvl, v_xp, v_total_xp)
    on conflict (level) do update set xp_required = excluded.xp_required, total_xp_required = excluded.total_xp_required;
  end loop;
end;
$$;

-- 2. Ensure all Daily Tasks are active
update public.daily_tasks set is_active = true;

grant execute on function public.record_membership_purchase(uuid, text, text, numeric, numeric, text, text, timestamp with time zone) to authenticated;

select 'Constraints applied successfully' as result;

do $$
begin
  if not exists (
    select 1 from pg_policies 
    where tablename = 'user_anti_abuse_logs' and policyname = 'Admins can view anti abuse logs'
  ) then
    create policy "Admins can view anti abuse logs"
      on public.user_anti_abuse_logs for select
      using (
        exists (
          select 1 from public.admins where user_id = auth.uid()
        )
      );
  end if;
end;
$$;

-- Indexes
create index if not exists events_status_idx       on public.events(status);

create index if not exists events_is_official_idx  on public.events(is_official);

create index if not exists events_created_by_idx   on public.events(created_by);

-- Public read
create policy "events_public_read" on public.events
  for select using (is_public = true or auth.uid() is not null);

-- Admins can insert/update/delete
create policy "events_admin_write" on public.events
  for all using (
    exists (select 1 from public.admins where id = auth.uid())
  );

drop trigger if exists events_updated_at_trigger on public.events;

create trigger events_updated_at_trigger
  before update on public.events
  for each row execute function public.events_set_updated_at();

commit;

-- Auto-update updated_at
create or replace function public.events_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

