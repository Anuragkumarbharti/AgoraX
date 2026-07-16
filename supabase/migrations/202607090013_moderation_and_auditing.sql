-- 202607090013_moderation_and_auditing.sql
-- Administrative roles, user reports, bans ledger, security auditing, and is_admin helper

create table public.admins (
  id uuid references public.profiles(id) on delete cascade primary key,
  role text not null check (role in ('SuperAdmin', 'Moderator', 'Support')),
  assigned_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.reports (
  id uuid default gen_random_uuid() primary key,
  reporter_id uuid references public.profiles(id) on delete cascade not null,
  reported_user_id uuid references public.profiles(id) on delete cascade,
  resource_type text not null check (resource_type in ('user', 'book', 'message', 'room')),
  resource_id text not null,
  reason text not null,
  status text default 'Open' check (status in ('Open', 'Reviewed', 'Resolved')),
  admin_comment text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.bans (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  banned_by uuid references public.admins(id) on delete set null,
  reason text not null,
  expires_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.audit_logs (
  id uuid default gen_random_uuid() primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  details jsonb default '{}'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.moderation_logs (
  id uuid default gen_random_uuid() primary key,
  admin_id uuid references public.admins(id) on delete set null,
  target_id text not null,
  target_type text not null,
  action text not null,
  reason text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Functions
create or replace function public.is_admin(user_id uuid)
returns boolean
security definer
stable
language sql
as $$
  select exists (
    select 1 from public.admins where id = user_id
  );
$$;

-- Row Level Security (RLS) Policies
alter table public.admins enable row level security;
create policy "Admin roles viewable by admins and owners" on public.admins for select using (true);

alter table public.reports enable row level security;
create policy "Allow select reports for owner and admins" on public.reports for select using (
  auth.uid() = reporter_id or exists (select 1 from public.admins where id = auth.uid())
);
create policy "Allow insert reports for authenticated users" on public.reports for insert with check (auth.role() = 'authenticated');

alter table public.bans enable row level security;
create policy "Bans viewable by everyone" on public.bans for select using (true);
create policy "Bans manageable by admins only" on public.bans for all using (
  exists (select 1 from public.admins where id = auth.uid())
);

alter table public.audit_logs enable row level security;
create policy "Audit logs manageable by admins only" on public.audit_logs for all using (
  exists (select 1 from public.admins where id = auth.uid())
);

alter table public.moderation_logs enable row level security;
create policy "Moderation logs manageable by admins only" on public.moderation_logs for all using (
  exists (select 1 from public.admins where id = auth.uid())
);
