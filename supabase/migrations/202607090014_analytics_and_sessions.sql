-- 202607090014_analytics_and_sessions.sql
-- Analytics, login metrics, active device sessions, and RLS policies

create table public.user_activity (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  activity_type text not null,
  duration_seconds integer,
  metadata jsonb default '{}'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.login_history (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  ip_address text,
  user_agent text,
  device_id text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.device_sessions (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  device_id text not null,
  device_name text,
  os_version text,
  push_token text,
  is_active boolean default true,
  last_active_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(user_id, device_id)
);

-- Row Level Security (RLS) Policies
alter table public.user_activity enable row level security;
create policy "Users can view their activity logs" on public.user_activity for select using (auth.uid() = user_id);
create policy "Allow insert activity logs" on public.user_activity for insert with check (auth.role() = 'authenticated');

alter table public.login_history enable row level security;
create policy "Users can view their login history" on public.login_history for select using (auth.uid() = user_id);

alter table public.device_sessions enable row level security;
create policy "Users can view their device sessions" on public.device_sessions for select using (auth.uid() = user_id);
create policy "Allow all actions on own device sessions" on public.device_sessions for all using (auth.uid() = user_id);
