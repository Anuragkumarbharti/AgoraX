-- 202607230011_fcm_notifications.sql
-- Table for FCM device tokens
create table if not exists public.fcm_tokens (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  token text not null unique,
  device_id text,
  device_type text check (device_type in ('android', 'ios', 'web')),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Table for notification settings
create table if not exists public.notification_settings (
  user_id uuid references public.profiles(id) on delete cascade primary key,
  mute_all boolean default false not null,
  messages boolean default true not null,
  followers boolean default true not null,
  community boolean default true not null,
  voice_rooms boolean default true not null,
  quiz boolean default true not null,
  wallet boolean default true not null,
  security boolean default true not null,
  marketing boolean default true not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Table for tracking notification delivery and logs (analytics)
create table if not exists public.notification_logs (
  id uuid default gen_random_uuid() primary key,
  notification_id uuid references public.notifications(id) on delete cascade,
  receiver_id uuid references public.profiles(id) on delete cascade not null,
  fcm_token text,
  status text not null check (status in ('pending', 'delivered', 'failed', 'clicked', 'dismissed')),
  failure_reason text,
  delivered_at timestamp with time zone,
  clicked_at timestamp with time zone,
  dismissed_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Table for scheduled notifications
create table if not exists public.scheduled_notifications (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  type text not null,
  payload jsonb default '{}'::jsonb,
  scheduled_for timestamp with time zone not null,
  status text default 'pending' check (status in ('pending', 'sent', 'failed')),
  retry_count integer default 0 not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.fcm_tokens enable row level security;
alter table public.notification_settings enable row level security;
alter table public.notification_logs enable row level security;
alter table public.scheduled_notifications enable row level security;

-- RLS Policies
create policy "Users can manage their own fcm tokens" on public.fcm_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users can read their own notification settings" on public.notification_settings
  for select using (auth.uid() = user_id);

create policy "Users can update their own notification settings" on public.notification_settings
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users can insert their own notification settings" on public.notification_settings
  for insert with check (auth.uid() = user_id);

create policy "Users can read their own notification logs" on public.notification_logs
  for select using (auth.uid() = receiver_id);

create policy "Users can update their own notification logs" on public.notification_logs
  for update using (auth.uid() = receiver_id) with check (auth.uid() = receiver_id);

create policy "Allow all actions on logs for service_role" on public.notification_logs
  for all using (true) with check (true);

create policy "Users can read their own scheduled notifications" on public.scheduled_notifications
  for select using (auth.uid() = user_id);

-- Functions
create or replace function public.register_fcm_token(
  p_user_id uuid,
  p_token text,
  p_device_id text,
  p_device_type text
)
returns void as $$
begin
  insert into public.fcm_tokens(user_id, token, device_id, device_type)
  values (p_user_id, p_token, p_device_id, p_device_type)
  on conflict (token) do update set
    user_id = excluded.user_id,
    device_id = excluded.device_id,
    device_type = excluded.device_type,
    updated_at = now();
end;
$$ language plpgsql security definer;

create or replace function public.unregister_fcm_token(
  p_token text
)
returns void as $$
begin
  delete from public.fcm_tokens where token = p_token;
end;
$$ language plpgsql security definer;

-- Trigger to create notification settings on user signup
create or replace function public.handle_new_profile_notification_settings()
returns trigger as $$
begin
  insert into public.notification_settings(user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists tr_handle_new_profile_notification_settings on public.profiles;
create trigger tr_handle_new_profile_notification_settings
  after insert on public.profiles
  for each row execute function public.handle_new_profile_notification_settings();

-- Backfill existing profiles
insert into public.notification_settings(user_id)
select id from public.profiles
on conflict (user_id) do nothing;

-- Realtime replication
do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception when others then
  raise notice 'Table notifications already in supabase_realtime publication';
end;
$$;
