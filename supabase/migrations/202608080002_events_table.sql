-- Migration: 202608080002_events_table.sql
-- Creates the public.events table for community events/tournaments.
-- Required by EventController in lib/services/community/event_controller.dart

begin;

create table if not exists public.events (
  id                          uuid default gen_random_uuid() primary key,
  title                       text not null,
  description                 text,
  banner_url                  text default '',
  category                    text,
  difficulty                  text,
  organizer                   text,
  is_official                 boolean default false,
  start_date                  timestamp with time zone not null,
  end_date                    timestamp with time zone not null,
  registration_deadline       timestamp with time zone,
  result_date                 timestamp with time zone,
  max_participants            integer default 100,
  is_unlimited                boolean default false,
  entry_fee_type              text default 'free' check (entry_fee_type in ('free', 'coins', 'cash')),
  entry_fee_amount            numeric default 0,
  prize_pool                  text default '',
  rewards                     jsonb default '{}'::jsonb,
  status                      text default 'registrationOpen'
                                check (status in ('registrationOpen','registrationClosed','ongoing','completed','cancelled','upcoming')),
  format                      text default 'quiz'
                                check (format in ('quiz','tournament','challenge','hackathon','creative','sports','gaming','debate','other')),
  rules                       text[] default '{}',
  required_level              integer default 1,
  required_badge              text,
  tags                        text[] default '{}',
  language                    text default 'English',
  is_public                   boolean default true,
  participants_count          integer default 0,
  anti_cheat                  jsonb default '{}'::jsonb,
  negative_marking            boolean default false,
  duration_minutes            integer default 60,
  question_count              integer default 30,
  passing_marks               integer default 40,
  required_registration_fields text[] default array['name','email','phone'],
  terms_and_conditions        text default '',
  is_paid                     boolean default false,
  winners                     jsonb default '[]'::jsonb,
  rounds                      jsonb default '[]'::jsonb,
  created_by                  uuid references public.profiles(id) on delete set null,
  created_at                  timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at                  timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Indexes
create index if not exists events_status_idx       on public.events(status);
create index if not exists events_start_date_idx   on public.events(start_date);
create index if not exists events_is_official_idx  on public.events(is_official);
create index if not exists events_created_by_idx   on public.events(created_by);

-- RLS
alter table public.events enable row level security;

-- Public read
create policy "events_public_read" on public.events
  for select using (is_public = true or auth.uid() is not null);

-- Admins can insert/update/delete
create policy "events_admin_write" on public.events
  for all using (
    exists (select 1 from public.admins where id = auth.uid())
  );

-- Auto-update updated_at
create or replace function public.events_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists events_updated_at_trigger on public.events;
create trigger events_updated_at_trigger
  before update on public.events
  for each row execute function public.events_set_updated_at();

commit;
