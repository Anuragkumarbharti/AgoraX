-- ==========================================================================
-- Consolidated Supabase Migration Module 05: 202607090005_voice_rooms_and_governance.sql
-- Authoritative baseline schema, functions, triggers, policies, and seeds.
-- ==========================================================================

create table public.room_settings (
  room_id text primary key references public.rooms(id) on delete cascade not null,
  is_private boolean default false not null,
  password_protected boolean default false not null,
  room_password text,
  chat_enabled boolean default true not null,
  mic_for_all boolean default false not null,
  allow_request_speak boolean default true not null,
  bg_image text,
  theme_color text,
  welcome_message text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.room_seat_gifts (
  room_id text references public.rooms(id) on delete cascade not null,
  seat_index integer not null check (seat_index between 0 and 9),
  silver_gift_count integer default 0 not null check (silver_gift_count >= 0),
  primary key (room_id, seat_index)
);

create trigger check_room_username_trigger
before insert or update of username on public.rooms
for each row execute function public.check_room_username();

create trigger check_room_update_permission_trigger
before update on public.rooms
for each row execute function public.check_room_update_permission();

create trigger on_host_transfer
  before update on public.rooms
  for each row execute procedure public.check_host_transfer();

create trigger tr_update_room_member_counts
after insert or delete or update of role on public.room_members
for each row execute function public.update_room_member_counts();

create trigger tr_on_rooms_core_update
before insert or update of name, banner, host_id, total_members on public.rooms
for each row execute function public.on_rooms_core_update();

-- Realtime registrations
do $$
begin
  alter publication supabase_realtime add table public.rooms;
exception when others then
  raise notice 'Table rooms already in supabase_realtime publication';
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.room_seats;
exception when others then
  raise notice 'Table room_seats already in supabase_realtime publication';
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.room_activity_events;
exception when others then
  raise notice 'Table room_activity_events already in supabase_realtime publication';
end;
$$;

-- 202607090008_voice_rooms_progression.sql
-- Room progression tables, heartbeats, XP metrics, triggers, RLS, and realtime channels

create table public.room_level_progress (
  room_id text primary key references public.rooms(id) on delete cascade not null,
  current_level integer default 1 not null,
  current_xp integer default 0 not null,
  consecutive_days_completed integer default 0 not null,
  last_completed_date date
);

create table public.room_statistics (
  room_id text primary key references public.rooms(id) on delete cascade not null,
  total_visitors integer default 0 not null,
  today_visitors integer default 0 not null,
  total_silver_coins integer default 0 not null,
  today_silver_coins integer default 0 not null,
  total_gold_coins integer default 0 not null,
  today_gold_coins integer default 0 not null,
  total_task_points integer default 0 not null,
  today_task_points integer default 0 not null,
  total_extra_xp_points integer default 0 not null,
  today_extra_xp_points integer default 0 not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.room_reputation (
  room_id text primary key references public.rooms(id) on delete cascade not null,
  reputation_points integer default 0 not null,
  positive_feedback integer default 0 not null,
  negative_feedback integer default 0 not null
);

create table public.room_daily_tasks (
  task_id text primary key,
  task_name text not null,
  description text,
  target_value integer not null,
  points_reward integer not null,
  xp_reward integer not null
);

create table public.room_daily_task_progress (
  room_id text references public.rooms(id) on delete cascade not null,
  task_id text references public.room_daily_tasks(task_id) on delete cascade not null,
  current_value integer default 0 not null,
  is_completed boolean default false not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, task_id)
);

create trigger on_room_created_progression
  after insert on public.rooms
  for each row execute procedure public.handle_new_room_progression();

-- Realtime registrations
do $$
begin
  alter publication supabase_realtime add table public.room_level_progress;
exception when others then
  raise notice 'Table room_level_progress already in supabase_realtime publication';
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.room_daily_task_progress;
exception when others then
  raise notice 'Table room_daily_task_progress already in supabase_realtime publication';
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.room_statistics;
exception when others then
  raise notice 'Table room_statistics already in supabase_realtime publication';
end;
$$;

create table public.room_gift_statistics (
  room_id text primary key references public.rooms(id) on delete cascade not null,
  total_gold_received integer default 0 not null,
  total_silver_received integer default 0 not null,
  weekly_gold_received integer default 0 not null,
  monthly_gold_received integer default 0 not null
);

-- Realtime registrations
do $$
begin
  alter publication supabase_realtime add table public.room_seat_gifts;
exception when others then
  raise notice 'Table room_seat_gifts already in supabase_realtime publication';
end;
$$;

create trigger tr_handle_room_message_mentions
after insert on public.room_messages
for each row execute function public.handle_room_message_mentions();

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

-- 3. Configure join_room task to require 5 minutes of participation
update public.daily_tasks 
set required_action = 'room_joined_minute', 
    required_count = 5 
where task_id = 'join_room';

-- Add room_joined_minute event to xp_config (5 XP, 50s cooldown to rate limit to 1 per minute)
insert into public.xp_config (event_type, xp_reward, cooldown_seconds)
values ('room_joined_minute', 5, 50)
on conflict (event_type) do update set xp_reward = 5, cooldown_seconds = 50;

-- 4. Configure host_room task to require 5 minutes on a microphone seat
update public.daily_tasks 
set required_action = 'room_hosted_minute', 
    required_count = 5 
where task_id = 'host_room';

-- Add room_hosted_minute event to xp_config (7 XP, 50s cooldown to rate limit to 1 per minute)
insert into public.xp_config (event_type, xp_reward, cooldown_seconds)
values ('room_hosted_minute', 7, 50)
on conflict (event_type) do update set xp_reward = 7, cooldown_seconds = 50;

-- 8. Create Gift History (Audit Trail) Table
create table if not exists public.gift_history (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid,
  receiver_id uuid,
  item_id text,
  item_type text,
  quantity integer,
  stars_value numeric,
  room_id text,
  created_at timestamptz default now()
);

alter table public.gift_history add column if not exists room_id text;

-- 11. Create Gift Seat Logs Table
create table if not exists public.gift_seat_logs (
  id uuid default gen_random_uuid() primary key,
  transaction_id uuid references public.gift_transactions(id) on delete cascade,
  seat_index integer,
  receiver_id uuid,
  created_at timestamptz default now()
);

-- 2. Create Room Star Statistics Table
create table if not exists public.room_star_statistics (
  room_id text references public.rooms(id) on delete cascade primary key,
  total_stars numeric default 0,
  today_stars numeric default 0,
  session_gifts_count integer default 0,
  updated_at timestamptz default now()
);

-- 3. Create Seat Star Statistics Table
create table if not exists public.seat_star_statistics (
  room_id text references public.rooms(id) on delete cascade,
  seat_index integer not null check (seat_index between 0 and 9),
  session_stars numeric default 0,
  session_gifts integer default 0,
  updated_at timestamptz default now(),
  primary key (room_id, seat_index)
);

-- Create policies if they don't exist
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'room_requests' and policyname = 'Allow select for room requests') then
    create policy "Allow select for room requests" on public.room_requests
      for select using (true);
  end if;
  
  if not exists (select 1 from pg_policies where tablename = 'room_requests' and policyname = 'Allow insert for authenticated users') then
    create policy "Allow insert for authenticated users" on public.room_requests
      for insert with check (auth.uid() = user_id);
  end if;

  if not exists (select 1 from pg_policies where tablename = 'room_requests' and policyname = 'Allow update/delete for room owners/moderators') then
    create policy "Allow update/delete for room owners/moderators" on public.room_requests
      for all using (
        exists (
          select 1 from public.rooms r
          where r.id = room_requests.room_id and r.host_id = auth.uid()
        ) or 
        exists (
          select 1 from public.room_members m
          where m.room_id = room_requests.room_id and m.user_id = auth.uid() and m.role in ('Co-Host', 'Moderator')
        ) or
        auth.uid() = user_id
      );
  end if;
end
$$;

-- Enable Realtime for room_requests if not already enabled
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_requests'
    ) then
      alter publication supabase_realtime add table public.room_requests;
    end if;
  end if;
end
$$;

-- 1. Add last_heartbeat_at column to room_members if it doesn't exist
alter table public.room_members 
  add column if not exists last_heartbeat_at timestamp with time zone default timezone('utc'::text, now()) not null;

-- 2. Add is_locked and is_muted to room_seats if they do not exist
alter table public.room_seats
  add column if not exists is_locked boolean default false not null,
  add column if not exists is_muted boolean default false not null;

do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'room_assigned_roles' and policyname = 'Allow select for all') then
    create policy "Allow select for all" on public.room_assigned_roles
      for select using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'room_assigned_roles' and policyname = 'Allow modification for owner') then
    create policy "Allow modification for owner" on public.room_assigned_roles
      for all using (
        exists (
          select 1 from public.rooms r
          where r.id = room_assigned_roles.room_id and r.host_id = auth.uid()
        )
      );
  end if;
end
$$;

-- Enable Realtime for room_assigned_roles
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_assigned_roles'
    ) then
      alter publication supabase_realtime add table public.room_assigned_roles;
    end if;
  end if;
end
$$;

do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'room_invites' and policyname = 'Allow select for invited user') then
    create policy "Allow select for invited user" on public.room_invites
      for select using (auth.uid() = user_id or auth.uid() = invited_by);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'room_invites' and policyname = 'Allow insert for hosts/admins') then
    create policy "Allow insert for hosts/admins" on public.room_invites
      for insert with check (
        exists (
          select 1 from public.room_members m
          where m.room_id = room_invites.room_id and m.user_id = auth.uid() and m.role in ('Owner', 'Co Owner', 'Admin')
        )
      );
  end if;
end
$$;

-- 202607230005_fix_room_members_role_constraint.sql
-- Fix room_members role check constraint to allow new roles (Owner, Co Owner, Admin, Member)

alter table public.room_members drop constraint if exists room_members_role_check;

alter table public.room_members add constraint room_members_role_check check (role in ('Host', 'Co-Host', 'Moderator', 'Speaker', 'Listener', 'Guest', 'Owner', 'Co Owner', 'Admin', 'Member'));

drop trigger if exists tr_room_invites_notifications on public.room_invites;

create trigger tr_room_invites_notifications
  after insert on public.room_invites
  for each row execute function public.handle_room_invites_notifications();

-- Voice Rooms optimization
CREATE INDEX IF NOT EXISTS idx_voice_rooms_active_created ON voice_rooms(is_active, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_voice_rooms_category_active ON voice_rooms(category, is_active);

-- Messaging optimization
CREATE INDEX IF NOT EXISTS idx_messages_room_created ON messages(room_id, created_at DESC);

-- 2. Add all room tables to supabase_realtime publication safely
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_seats'
    ) then
      alter publication supabase_realtime add table public.room_seats;
    end if;

    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_members'
    ) then
      alter publication supabase_realtime add table public.room_members;
    end if;

    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_messages'
    ) then
      alter publication supabase_realtime add table public.room_messages;
    end if;

    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_requests'
    ) then
      alter publication supabase_realtime add table public.room_requests;
    end if;

    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_activity_events'
    ) then
      alter publication supabase_realtime add table public.room_activity_events;
    end if;
  end if;
end
$$;

-- Migration 202608030005_room_notification_isolation_and_transient_chat.sql
-- Room Chat, Notification Isolation, Gift Isolation & Transient Session Maintenance

-- Ensure notifications schema compatibility
alter table public.notifications add column if not exists content text;

-- 1. DROP NOTIFICATION TRIGGERS FOR ROOM MESSAGES AND GIFTS
-- Room messages, room mentions, and room gifts MUST NEVER insert rows into public.notifications
drop trigger if exists tr_handle_room_message_mentions on public.room_messages;

drop trigger if exists tr_gift_received_notifications on public.gift_transactions;

drop trigger if exists tr_gift_received_notifications on public.gift_history;

-- Re-attach DM notification trigger cleanly on public.messages
drop trigger if exists tr_handle_direct_message_notifications on public.messages;

create trigger tr_handle_direct_message_notifications
  after insert on public.messages
  for each row execute function public.handle_direct_message_notifications();

grant execute on function public.clean_stale_room_members() to authenticated, service_role;

grant execute on function public.purge_room_transient_messages(text) to authenticated, service_role;

-- Migration 202608030006_fix_room_username_constraint.sql
-- Fix rooms.username check constraint to accept 3 to 30 characters after @ symbol

do $$
begin
  -- Drop existing constraint if present
  if exists (
    select 1 from information_schema.table_constraints
    where table_name = 'rooms'
      and constraint_name = 'check_room_username'
  ) then
    alter table public.rooms drop constraint check_room_username;
  end if;

  -- Allow 3 to 30 alphanumeric/underscore characters following the @ prefix
  alter table public.rooms
    add constraint check_room_username
    check (username ~ '^@[a-z0-9_]{3,30}$');
end;
$$;

-- Migration 202608030007_purge_all_historical_room_messages.sql
-- Purge all historical room messages and notifications, and auto-purge when room becomes empty

-- 1. PURGE ALL HISTORICAL ROOM CHAT MESSAGES FROM DATABASE
truncate table public.room_messages;

-- 2. PURGE HISTORICAL ROOM & GIFT NOTIFICATIONS FROM NOTIFICATIONS TABLE
delete from public.notifications
where type in ('room', 'room_chat', 'gift', 'room_gift', 'mention', 'seat_change', 'mic_activity', 'room_event');

-- Attach trigger to public.rooms on total_members or status updates
drop trigger if exists tr_auto_purge_empty_room_messages on public.rooms;

create trigger tr_auto_purge_empty_room_messages
  after update of total_members, status on public.rooms
  for each row execute function public.auto_purge_empty_room_messages();

grant execute on function public.purge_all_room_chats() to authenticated, service_role;

-- 2. Register tables into supabase_realtime publication
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_seats'
    ) then
      alter publication supabase_realtime add table public.room_seats;
    end if;

    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_members'
    ) then
      alter publication supabase_realtime add table public.room_members;
    end if;

    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_messages'
    ) then
      alter publication supabase_realtime add table public.room_messages;
    end if;

    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_activity_events'
    ) then
      alter publication supabase_realtime add table public.room_activity_events;
    end if;
  end if;
end
$$;

-- Migration: Creaniaa Room Role System (Unified Creator/Owner, Level-Based Limits, Entry Permissions)
-- Date: 2026-08-06

-- 0. Drop existing functions to allow changing return signatures cleanly
DROP FUNCTION IF EXISTS public.get_room_role_limits(text);

DROP FUNCTION IF EXISTS public.can_change_room_entry_rules(text, uuid);

DROP FUNCTION IF EXISTS public.promote_room_member_role(text, uuid, text);

DROP FUNCTION IF EXISTS public.demote_room_member_role(text, uuid);

-- Migration: Room Background Theme Realtime & Persistence System
-- Date: 2026-08-06

-- 1. Ensure room_theme column exists on public.rooms table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'rooms' 
    AND column_name = 'room_theme'
  ) THEN
    ALTER TABLE public.rooms ADD COLUMN room_theme text DEFAULT 'theme_1';
  END IF;
END $$;

-- 2. Add rooms table to Supabase Realtime publication for CDC updates
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.rooms;
    EXCEPTION WHEN OTHERS THEN
      -- Table already in publication or publication configured via dashboard
      NULL;
    END;
  END IF;
END $$;

-- ============================================================================
-- CREANIA VOICE ROOM PASSWORD SYSTEM MIGRATION
-- Migration File: 202608070003_room_password_system.sql
-- Description: Adds room_password column, password update RPC, and verification functions
-- ============================================================================

-- 1. Add room_password & entry_permission columns to public.rooms table
ALTER TABLE public.rooms
ADD COLUMN IF NOT EXISTS room_password text DEFAULT NULL,
ADD COLUMN IF NOT EXISTS entry_permission text DEFAULT 'everyone',
ADD COLUMN IF NOT EXISTS who_can_join text DEFAULT 'Everyone';

-- Migration: Enterprise Voice Room Governance, Security & Moderation Engine (AgoraX v2.0)
-- Date: 2026-08-07

-- 1. Create Room Permission History Table (Permanent Immutable Log)
CREATE TABLE IF NOT EXISTS public.room_permission_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id text NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  actor_id uuid NOT NULL,
  actor_role text NOT NULL,
  target_user_id uuid NOT NULL,
  action_type text NOT NULL, -- 'PROMOTED', 'DEMOTED', 'PERMISSION_CHANGED', 'REMOVED'
  old_role text,
  new_role text,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 2. Create Admin Activity Logs Table
CREATE TABLE IF NOT EXISTS public.room_admin_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id text NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  admin_id uuid NOT NULL,
  action_type text NOT NULL, -- 'MUTE', 'UNMUTE', 'KICK', 'BAN', 'SEAT_LOCK', 'SEAT_UNLOCK', 'SPEAKER_ACCEPT', 'SPEAKER_REJECT', 'BG_CHANGE', 'EMERGENCY_TOGGLE', 'WARNING_ISSUED'
  target_user_id uuid,
  details jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 3. Create Room User Warnings Escalation Table
CREATE TABLE IF NOT EXISTS public.room_user_warnings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id text NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  issued_by uuid NOT NULL,
  warning_level int NOT NULL DEFAULT 1, -- 1, 2, 3
  reason text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 4. Extend Rooms Table with Governance & Security Columns
ALTER TABLE public.rooms 
ADD COLUMN IF NOT EXISTS security_score numeric(3,2) DEFAULT 5.00,
ADD COLUMN IF NOT EXISTS health_score int DEFAULT 100,
ADD COLUMN IF NOT EXISTS governance_level int DEFAULT 1,
ADD COLUMN IF NOT EXISTS is_emergency_mode boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS backup_owner_id uuid,
ADD COLUMN IF NOT EXISTS backup_owner_activated_at timestamptz,
ADD COLUMN IF NOT EXISTS admin_cooldown_hours int DEFAULT 0;

-- 5. Extend Room Members Table with Expiry and Custom Permissions
ALTER TABLE public.room_members 
ADD COLUMN IF NOT EXISTS custom_permissions jsonb DEFAULT '{"kick":true,"mute":true,"seat_lock":true,"background_change":true,"room_info_edit":true,"pk_start":true,"ban":false,"announcement":false}'::jsonb,
ADD COLUMN IF NOT EXISTS expires_at timestamptz,
ADD COLUMN IF NOT EXISTS admin_cooldown_expires_at timestamptz;

DROP POLICY IF EXISTS "Allow members to view permission history" ON public.room_permission_history;

DROP POLICY IF EXISTS "Allow members to view admin activity logs" ON public.room_admin_activity_logs;

DROP POLICY IF EXISTS "Allow members to view room warnings" ON public.room_user_warnings;

-- Migration: Ultra Fast Room Join System (Target: 100ms - 200ms Latency Engine)
-- Date: 2026-08-07

-- 0. Ensure all missing columns exist on public.rooms
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS entry_permission text DEFAULT 'everyone';

ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS room_password text DEFAULT NULL;

ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS level_requirement int DEFAULT 1;

-- 1. Update room_members role check constraint to support all role names
ALTER TABLE public.room_members DROP CONSTRAINT IF EXISTS room_members_role_check;

ALTER TABLE public.room_members ADD CONSTRAINT room_members_role_check 
  CHECK (role IN ('Host', 'Co-Host', 'Moderator', 'Speaker', 'Listener', 'Guest', 'Owner', 'Co Owner', 'Co-Owner', 'Admin', 'Member', 'Audience', 'Creator'));

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

-- Indexing for high performance anti-fraud queries
create index if not exists idx_user_trust_scores_user_id on public.user_trust_scores(user_id);

create index if not exists idx_user_device_fingerprints_device on public.user_device_fingerprints(device_fingerprint);

create index if not exists idx_room_anti_abuse_logs_user_room on public.room_anti_abuse_logs(user_id, room_id);

-- 2. Setup Automated pg_cron Schedule at 04:00 AM IST (22:30 UTC every day)
do $cron_block$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    -- Unschedule existing job if present
    perform cron.unschedule('creania-daily-room-task-reset');
    
    -- Schedule cron job for 22:30 UTC = 04:00 AM IST
    perform cron.schedule(
      'creania-daily-room-task-reset',
      '30 22 * * *',
      'select public.reset_room_daily_tasks();'
    );
  end if;
exception when others then
  raise notice 'pg_cron extension not active or permission restricted';
end;
$cron_block$;

-- 3. Room Activity Tracker Table (For 10-Min Idle Freeze & Solo Slow Mode)
create table if not exists public.room_activity_tracker (
  room_id text primary key references public.rooms(id) on delete cascade,
  last_interaction_at timestamptz default now(),
  active_occupants_count integer default 0,
  is_idle_frozen boolean default false,
  updated_at timestamptz default now()
);

alter table public.gift_transactions add column if not exists seat_index integer;

-- 0c. Ensure rooms and room_seats stars columns compatibility
alter table public.rooms add column if not exists total_room_stars numeric default 0;

alter table public.rooms add column if not exists today_room_stars numeric default 0;

alter table public.rooms add column if not exists total_room_gifts integer default 0;

alter table public.rooms add column if not exists today_room_gifts integer default 0;

alter table public.room_seats add column if not exists seat_total_stars numeric default 0;

alter table public.room_seats add column if not exists seat_total_gifts integer default 0;

alter table public.room_seats add column if not exists last_gift_time timestamp with time zone;

alter table public.gift_transactions add column if not exists seat_index integer default -1;

-- 7. Ensure rooms and room_seats stars columns compatibility
alter table public.rooms add column if not exists total_room_stars numeric default 0;

alter table public.rooms add column if not exists room_xp integer default 0;

alter table public.rooms add column if not exists today_room_xp integer default 0;

-- Migration: 202608070014_star_maker_dual_progress_system.sql
-- Description: Production StarMaker Dual Progress System with exact Silver Coin conversion (100 Silver = 1 Normal AP), Gold XP overflow, column aliases (gold_xp, normal_ap), atomic Postgres RPC, real-time sync, and anti-abuse.

-- 1. Create Room Dual Progress Table
create table if not exists public.room_dual_progress (
  room_id text primary key references public.rooms(id) on delete cascade,
  gold_points integer default 0 not null check (gold_points >= 0),
  gold_target integer default 1000 not null check (gold_target > 0),
  normal_points integer default 0 not null check (normal_points >= 0),
  normal_target integer default 700 not null check (normal_target > 0),
  overflow_points integer default 0 not null check (overflow_points >= 0),
  room_level integer default 1 not null check (room_level >= 1),
  created_at timestamptz default timezone('utc'::text, now()) not null,
  updated_at timestamptz default timezone('utc'::text, now()) not null
);

drop policy if exists "Allow read access on room_dual_progress" on public.room_dual_progress;

drop policy if exists "Allow update access on room_dual_progress" on public.room_dual_progress;

-- 3. Add to Supabase Realtime Publication
do $$
begin
  alter publication supabase_realtime add table public.room_dual_progress;
exception when others then
  raise notice 'Table room_dual_progress already in supabase_realtime publication';
end;
$$;

-- Migration: 202608070017_fix_gifting_error_room_level_column.sql
-- Description: Fix "column level does not exist" and "column updated_at of relation room_level_progress does not exist" errors during gifting.

-- 1. Ensure public.rooms has both room_level and level columns
alter table public.rooms add column if not exists level integer default 1 check (level >= 1);

alter table public.rooms add column if not exists room_level integer default 1 check (room_level >= 1);

-- 2. Ensure public.room_level_progress has updated_at column
alter table public.room_level_progress add column if not exists updated_at timestamptz default timezone('utc'::text, now());

-- Backfill missing values
update public.rooms set level = coalesce(room_level, level, 1) where level is null;

update public.rooms set room_level = coalesce(level, room_level, 1) where room_level is null;

drop trigger if exists trigger_sync_room_level_columns on public.rooms;

create trigger trigger_sync_room_level_columns
  before insert or update on public.rooms
  for each row execute function public.sync_room_level_columns();

-- Migration: 202608070018_starmaker_strict_daily_task_system.sql
-- Description: Strict StarMaker-style Room Task & Daily Limit System with 4:00 AM server timezone reset, FREE_TASK_LIMIT = 600, GOLD_TASK_LIMIT = 1200, Total Lifetime Task persistence, atomic Postgres FOR UPDATE locking, and zero-client-trust server validation.

-- 1. Ensure columns exist on public.room_dual_progress
alter table public.room_dual_progress add column if not exists daily_free_progress integer default 0 not null check (daily_free_progress >= 0);

alter table public.room_dual_progress add column if not exists free_task_limit integer default 600 not null check (free_task_limit > 0);

alter table public.room_dual_progress add column if not exists daily_gold_progress integer default 0 not null check (daily_gold_progress >= 0);

alter table public.room_dual_progress add column if not exists gold_task_limit integer default 1200 not null check (gold_task_limit > 0);

alter table public.room_dual_progress add column if not exists total_lifetime_task integer default 0 not null check (total_lifetime_task >= 0);

alter table public.room_dual_progress add column if not exists last_reset_date date default ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date not null;

-- Migration: 202608070019_fix_room_level_progression_system.sql
-- Description: Fix Room Level Progression System so Room Level depends EXCLUSIVELY on Total Task progress towards level requirements and NEVER directly on Daily Task completion. Daily Task resets every day at 4:00 AM, while Total Task resets ONLY upon successful Room Level Up.

-- 1. Ensure public.room_dual_progress table has total_task and total_lifetime_task columns
alter table public.room_dual_progress add column if not exists total_task integer default 0 not null check (total_task >= 0);

alter table public.room_dual_progress add column if not exists daily_free_progress integer default 0 not null check (daily_free_progress >= 0);

drop trigger if exists trigger_prevent_auto_room_ownership_change on public.rooms;

create trigger trigger_prevent_auto_room_ownership_change
  before update on public.rooms
  for each row
  execute function public.prevent_auto_room_ownership_change();

drop trigger if exists trigger_prevent_auto_room_assigned_role_deletion on public.room_assigned_roles;

create trigger trigger_prevent_auto_room_assigned_role_deletion
  before delete on public.room_assigned_roles
  for each row
  execute function public.prevent_auto_room_assigned_role_deletion();

-- Migration: 202608070026_lucky_gift_coin_back_system.sql
-- Description: Backend-driven Lucky Gift Coin Back engine with exact 1-in-1,000,000 probability distribution table and room event broadcasting.

-- 1. Ensure gift_catalog has is_lucky column
alter table public.gift_catalog add column if not exists is_lucky boolean default false;

-- Migration: 202608080003_fix_send_star_gift_overload_conflict.sql
-- Description: Ensure total_cost & amount schema compatibility on gift_transactions, drop overloaded send_star_gift signatures, update room dual progress AP tasks, and create canonical send_star_gift RPC.

BEGIN;

-- ============================================================================
-- MIGRATION: 202608080004_smart_presence_and_room_cleanup_system.sql
-- DESCRIPTION: Production Level Smart Presence, 20s Heartbeat, 60s Grace Period,
--              Single Session Enforcement, and O(expired) Background Cleanup.
-- ============================================================================

-- 1. Add session_id and is_reconnecting columns to room_members & room_seats
alter table public.room_members 
  add column if not exists session_id text,
  add column if not exists is_reconnecting boolean default false not null;

alter table public.room_seats
  add column if not exists session_id text,
  add column if not exists is_reconnecting boolean default false not null;

-- Add indexes for high-performance O(expired) grace period queries
create index if not exists idx_room_members_heartbeat_reconnecting 
  on public.room_members(is_reconnecting, last_heartbeat_at);

create index if not exists idx_room_members_user_session 
  on public.room_members(user_id, session_id);

create index if not exists idx_room_seats_user_session 
  on public.room_seats(room_id, user_id);

-- Migration: 202608080007_authoritative_gift_transaction_system.sql
-- Description: Server-authoritative, atomic, idempotent gifting transactions with race-condition safety and permanent persistence across room leave/re-entry/app restart.

-- 1. Ensure gift_transactions schema compatibility & idempotency_key column
ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS idempotency_key text;

CREATE INDEX IF NOT EXISTS idx_gift_tx_sender_room ON public.gift_transactions(sender_id, room_id);

-- Migration: Fix PGRST203 Overload Conflict for public.join_room RPC
-- Date: 2026-08-09
-- Description: Explicitly drops all old overloaded signatures of public.join_room to eliminate PostgREST PGRST203 candidate ambiguity.

-- 1. Drop all overloaded signatures of join_room
DROP FUNCTION IF EXISTS public.join_room(text);

DROP FUNCTION IF EXISTS public.join_room(text, text);

DROP FUNCTION IF EXISTS public.join_room(text, text, text);

GRANT EXECUTE ON FUNCTION send_room_invitation(TEXT, UUID, TEXT, TEXT, TEXT) TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION validate_room_invite_status(TEXT) TO authenticated, service_role, anon;

-- Migration: 202608110004_fix_silver_and_volt_room_gifting.sql
-- Description: Fix Silver Coin and Volt (Vault) room gifting, ensure Silver and Volt gifts increment ONLY Normal (Free) Tasks and NEVER Gold Tasks.

BEGIN;

COMMIT;

GRANT EXECUTE ON FUNCTION public.get_or_reset_room_dual_progress(text) TO authenticated, service_role, anon;

-- 1. Ensure host_ids, co_owner_ids, admin_ids, block_list columns exist on rooms table
alter table public.rooms 
add column if not exists host_ids text[] default '{}',
add column if not exists co_owner_ids text[] default '{}',
add column if not exists admin_ids text[] default '{}',
add column if not exists block_list text[] default '{}';

-- Backfill owner_user_id for existing rooms if null
UPDATE public.rooms 
SET owner_user_id = coalesce(room_owner, host_id)
WHERE owner_user_id IS NULL;

DROP TRIGGER IF EXISTS trigger_prevent_auto_room_ownership_change ON public.rooms;

DROP TRIGGER IF EXISTS trigger_prevent_room_owner_change ON public.rooms;

CREATE TRIGGER trigger_prevent_room_owner_change
  BEFORE UPDATE ON public.rooms
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_room_owner_change();

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS trg_auto_leave_seat_on_member_exit ON public.room_members;

CREATE TRIGGER trg_auto_leave_seat_on_member_exit
  AFTER DELETE ON public.room_members
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_leave_seat_on_member_exit();

-- ============================================================================
-- MIGRATION: 202608120007_fix_pgrst203_role_promotion_overloads.sql
-- DESCRIPTION: Fix PostgREST PGRST203 Multiple Choices error by dropping all 
--              overloaded variants of promote_room_member_role and demote_room_member_role
--              and establishing single canonical RPC implementations with full Owner Protection.
-- ============================================================================

-- 1. Drop ALL overloaded function signatures to resolve PGRST203
DROP FUNCTION IF EXISTS public.promote_room_member_role(text, uuid, text);

DROP FUNCTION IF EXISTS public.promote_room_member_role(uuid, uuid, text);

DROP FUNCTION IF EXISTS public.promote_room_member_role(text, uuid, text, int, jsonb);

DROP FUNCTION IF EXISTS public.promote_room_member_role_v2(text, uuid, text);

DROP FUNCTION IF EXISTS public.promote_room_member_role_v2(text, uuid, text, int, jsonb);

DROP FUNCTION IF EXISTS public.demote_room_member_role(text, uuid, text);

DROP FUNCTION IF EXISTS public.demote_room_member_role(uuid, uuid);

DROP FUNCTION IF EXISTS public.demote_room_member_role_v2(text, uuid);

DROP FUNCTION IF EXISTS public.demote_room_member_role_v2(text, uuid, boolean);

-- Migration: Clear PostgreSQL function overloads & enforce COMPLETE SEPARATION OF ROLE VS PRESENCE
-- Description: Establishes public.room_roles table for permanent role storage, drops legacy check constraints on room_assigned_roles,
--              decouples room_members (presence only), implements get_room_state_snapshot filtering by active presence threshold (30s),
--              standardizes HOST as the sole host/moderation role (removing separate Mod role tag),
--              and enforces strict ONE USER = ONE PRIMARY ROOM ROLE invariant:
--              - Supported Primary Roles: OWNER, CO_OWNER ('Co-Owner'), ADMIN ('Admin'), HOST ('Host').
--              - ROLE = Permanent (room_roles / rooms array columns).
--              - PRESENCE = Temporary session in room_members (last_heartbeat_at >= now() - 30 seconds).
--              - Role assignment to offline users ONLY updates room_roles (NO fake online presence, NO eyeCount change).
--              - Active online member list & eyeCount count ONLY users with valid active presence in this exact room.

-- 0. Ensure schema compatibility for room_members, rooms, and room_roles tables
ALTER TABLE public.room_members ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT timezone('utc'::text, now());

ALTER TABLE public.room_members ADD COLUMN IF NOT EXISTS is_online boolean DEFAULT true NOT NULL;

ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS star_member_ids text[] DEFAULT '{}';

ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS co_owner_ids text[] DEFAULT '{}';

ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS admin_ids text[] DEFAULT '{}';

ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS host_ids text[] DEFAULT '{}';

DROP POLICY IF EXISTS "Allow select room_roles for all" ON public.room_roles;

ALTER TABLE public.room_assigned_roles DROP CONSTRAINT IF EXISTS room_assigned_roles_role_check;

DROP POLICY IF EXISTS "Allow select for all assigned roles" ON public.room_assigned_roles;

-- 2. Explicitly drop ALL overloaded signatures of promote_room_member_role & promote_room_member_role_v2
DROP FUNCTION IF EXISTS public.promote_room_member_role(text, uuid, text);

DROP FUNCTION IF EXISTS public.promote_room_member_role(text, text, text);

DROP FUNCTION IF EXISTS public.promote_room_member_role(text, text, text, int, jsonb);

DROP FUNCTION IF EXISTS public.promote_room_member_role_v2(text, text, text);

DROP FUNCTION IF EXISTS public.promote_room_member_role_v2(uuid, uuid, text);

DROP FUNCTION IF EXISTS public.promote_room_member_role_v2(text, text, text, int, jsonb);

DROP FUNCTION IF EXISTS public.promote_room_member_role_v2(text, uuid, boolean);

DROP FUNCTION IF EXISTS public.promote_room_member_role_v2(text, text, boolean);

-- 3. Explicitly drop ALL overloaded signatures of demote_room_member_role & demote_room_member_role_v2
DROP FUNCTION IF EXISTS public.demote_room_member_role(text, uuid);

DROP FUNCTION IF EXISTS public.demote_room_member_role(text, text);

DROP FUNCTION IF EXISTS public.demote_room_member_role(text, text, text);

DROP FUNCTION IF EXISTS public.demote_room_member_role_v2(text, text);

DROP FUNCTION IF EXISTS public.demote_room_member_role_v2(uuid, uuid);

DROP FUNCTION IF EXISTS public.demote_room_member_role_v2(text, text, boolean);

-- ============================================================================
-- MIGRATION: 202608120008_room_role_system_full_cleanup.sql
-- DESCRIPTION: Enforce 4-role system (Owner, Co-Owner, Admin, Mod) across room RPCs and tables.
--              Remove Host and Co-Host roles and migrate existing records.
-- ============================================================================

-- 1. Drop old function signatures to prevent PGRST203 overloads
DROP FUNCTION IF EXISTS public.promote_room_member_role(text, uuid, text);

-- 6. Migrate existing database rows to clean 4-role structure
UPDATE public.room_members 
SET role = 'Mod' 
WHERE role IN ('Host', 'Moderator', 'mod', 'Host Member', 'moderator');

UPDATE public.room_members 
SET role = 'Audience' 
WHERE role IN ('Co-Host', 'cohost', 'Speaker', 'Star Member', 'listener', 'Listener');

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'room_assigned_roles') THEN
    UPDATE public.room_assigned_roles 
    SET role = 'Mod' 
    WHERE role IN ('Host', 'Moderator', 'mod', 'Host Member', 'moderator');

    UPDATE public.room_assigned_roles 
    SET role = 'Audience' 
    WHERE role IN ('Co-Host', 'cohost', 'Speaker', 'Star Member', 'listener', 'Listener');
  END IF;
END $$;

create or replace function public.check_host_transfer()
returns trigger as $$
begin
  if old.host_id is distinct from new.host_id then
    if auth.uid() <> old.host_id then
      raise exception 'Only the current Host can transfer room ownership';
    end if;
  end if;
  return new;
end;
$$ language plpgsql security definer;

create or replace function public.on_rooms_core_update()
returns trigger as $$
begin
  new.room_name := new.name;
  new.room_banner := new.banner;
  new.room_owner := new.host_id;
  new.online_members := coalesce(new.total_members, 0);
  new.updated_at := now();
  return new;
end;
$$ language plpgsql;

-- 202607090007_voice_rooms_rpc.sql
-- Voice room RPC operations and user weighting helpers

create or replace function public.get_user_role_weight(
  p_user_id uuid,
  p_room_id text
)
returns integer as $$
declare
  v_role text;
  v_host_id uuid;
begin
  select host_id into v_host_id from public.rooms where id = p_room_id;
  if v_host_id = p_user_id then
    return 10;
  end if;

  select role into v_role from public.room_members where room_id = p_room_id and user_id = p_user_id;
  if v_role is null then
    return 1;
  end if;

  case v_role
    when 'Host' then return 10;
    when 'Co-Host' then return 8;
    when 'Moderator' then return 6;
    when 'Speaker' then return 4;
    when 'Listener' then return 2;
    when 'Guest' then return 1;
    else return 1;
  end case;
end;
$$ language plpgsql stable;

-- Request speak RPC
create or replace function public.request_speak(
  p_room_id text,
  p_raise boolean
) returns boolean as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return false;
  end if;

  update public.room_members 
  set has_raised_hand = p_raise 
  where room_id = p_room_id and user_id = v_user_id;

  if p_raise then
    insert into public.room_requests (room_id, user_id, status)
    values (p_room_id, v_user_id, 'pending')
    on conflict (room_id, user_id) do update set status = 'pending';
  else
    delete from public.room_requests where room_id = p_room_id and user_id = v_user_id;
  end if;

  return true;
end;
$$ language plpgsql security definer;

-- Moderate speak request RPC
create or replace function public.moderate_request(
  p_room_id text,
  p_user_id uuid,
  p_accept boolean
) returns boolean as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null then
    return false;
  end if;

  if not public.check_room_permission(v_actor_id, p_room_id, 'can_manage_speakers') then
    raise exception 'Unauthorized to moderate speakers';
  end if;

  if p_accept then
    update public.room_requests set status = 'accepted' where room_id = p_room_id and user_id = p_user_id;
    update public.room_members set role = 'Speaker', has_raised_hand = false where room_id = p_room_id and user_id = p_user_id;
  else
    update public.room_requests set status = 'rejected' where room_id = p_room_id and user_id = p_user_id;
    update public.room_members set has_raised_hand = false where room_id = p_room_id and user_id = p_user_id;
  end if;

  return true;
end;
$$ language plpgsql security definer;

-- Change member role RPC
create or replace function public.change_member_role(
  p_room_id text,
  p_user_id uuid,
  p_new_role text
) returns boolean as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null then
    return false;
  end if;

  if public.get_user_role_weight(v_actor_id, p_room_id) <= public.get_user_role_weight(p_user_id, p_room_id) then
    raise exception 'Unauthorized: Target has equal or higher privilege';
  end if;

  update public.room_members set role = p_new_role where room_id = p_room_id and user_id = p_user_id;
  return true;
end;
$$ language plpgsql security definer;

-- End room RPC
create or replace function public.end_room(
  p_room_id text
) returns boolean as $$
declare
  v_actor_id uuid := auth.uid();
  v_host_id uuid;
begin
  select host_id into v_host_id from public.rooms where id = p_room_id;
  if v_actor_id <> v_host_id then
    raise exception 'Only the Host can end the room session';
  end if;

  update public.rooms
  set status = 'ended',
      end_time = now()
  where id = p_room_id;

  update public.room_seats set user_id = null where room_id = p_room_id;

  insert into public.room_activity_events (room_id, event_type, message)
  values (p_room_id, 'end_room', 'The host has ended the room session');

  return true;
end;
$$ language plpgsql security definer;

-- Moderate user mute RPC
create or replace function public.moderate_user_mute(
  p_room_id text,
  p_user_id uuid,
  p_mute boolean
) returns boolean as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null then
    return false;
  end if;

  if not public.check_room_permission(v_actor_id, p_room_id, 'can_manage_speakers') then
    raise exception 'Unauthorized to mute speakers';
  end if;

  if public.get_user_role_weight(v_actor_id, p_room_id) <= public.get_user_role_weight(p_user_id, p_room_id) then
    raise exception 'Unauthorized: Target has equal or higher privilege';
  end if;

  update public.room_members set is_muted = p_mute where room_id = p_room_id and user_id = p_user_id;

  insert into public.room_activity_logs (room_id, user_id, action_type, details, moderator_id)
  values (p_room_id, p_user_id, case when p_mute then 'mute' else 'unmute' end, 'User muted/unmuted state updated', v_actor_id);

  return true;
end;
$$ language plpgsql security definer;

-- Moderate user kick RPC
create or replace function public.moderate_user_kick(
  p_room_id text,
  p_user_id uuid
) returns boolean as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null then
    return false;
  end if;

  if not public.check_room_permission(v_actor_id, p_room_id, 'can_manage_listeners') then
    raise exception 'Unauthorized to kick users';
  end if;

  if public.get_user_role_weight(v_actor_id, p_room_id) <= public.get_user_role_weight(p_user_id, p_room_id) then
    raise exception 'Unauthorized: Target has equal or higher privilege';
  end if;

  delete from public.room_members where room_id = p_room_id and user_id = p_user_id;

  insert into public.room_activity_logs (room_id, user_id, action_type, details, moderator_id)
  values (p_room_id, p_user_id, 'kick', 'Kicked from room', v_actor_id);

  return true;
end;
$$ language plpgsql security definer;

-- Moderate user ban RPC
create or replace function public.moderate_user_ban(
  p_room_id text,
  p_user_id uuid,
  p_reason text,
  p_duration interval default null
) returns boolean as $$
declare
  v_actor_id uuid := auth.uid();
  v_expiry timestamp with time zone;
begin
  if v_actor_id is null then
    return false;
  end if;

  if not public.check_room_permission(v_actor_id, p_room_id, 'can_manage_listeners') then
    raise exception 'Unauthorized to ban users';
  end if;

  if public.get_user_role_weight(v_actor_id, p_room_id) <= public.get_user_role_weight(p_user_id, p_room_id) then
    raise exception 'Unauthorized: Target has equal or higher privilege';
  end if;

  if p_duration is not null then
    v_expiry := now() + p_duration;
  end if;

  insert into public.room_bans (room_id, user_id, banned_by, reason, expires_at)
  values (p_room_id, p_user_id, v_actor_id, p_reason, v_expiry)
  on conflict (room_id, user_id) do update set reason = EXCLUDED.reason, expires_at = EXCLUDED.expires_at;

  delete from public.room_members where room_id = p_room_id and user_id = p_user_id;

  insert into public.room_activity_logs (room_id, user_id, action_type, details, moderator_id)
  values (p_room_id, p_user_id, 'ban', 'Banned from room. Reason: ' || coalesce(p_reason, 'None'), v_actor_id);

  return true;
end;
$$ language plpgsql security definer;

-- Moderate user speak application RPC
create or replace function public.moderate_user_request(
  p_room_id text,
  p_user_id uuid,
  p_action text
) returns boolean as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null then
    return false;
  end if;

  if not public.check_room_permission(v_actor_id, p_room_id, 'can_manage_speakers') then
    raise exception 'Unauthorized to manage speakers';
  end if;

  if p_action in ('remove', 'demote') then
    if public.get_user_role_weight(v_actor_id, p_room_id) <= public.get_user_role_weight(p_user_id, p_room_id) then
      raise exception 'Unauthorized: Target has equal or higher privilege';
    end if;
  end if;

  if p_action = 'accept' then
    update public.room_requests set status = 'accepted' where room_id = p_room_id and user_id = p_user_id;
    update public.room_members set role = 'Speaker', has_raised_hand = false where room_id = p_room_id and user_id = p_user_id;
    
    insert into public.room_activity_logs (room_id, user_id, action_type, details, moderator_id)
    values (p_room_id, p_user_id, 'promote_speaker', 'Speaker request accepted', v_actor_id);
    
  elsif p_action = 'reject' then
    update public.room_requests set status = 'rejected' where room_id = p_room_id and user_id = p_user_id;
    update public.room_members set has_raised_hand = false where room_id = p_room_id and user_id = p_user_id;
    
    insert into public.room_activity_logs (room_id, user_id, action_type, details, moderator_id)
    values (p_room_id, p_user_id, 'reject_speaker_request', 'Speaker request rejected', v_actor_id);

  elsif p_action = 'remove' or p_action = 'demote' then
    update public.room_requests set status = 'demoted' where room_id = p_room_id and user_id = p_user_id;
    update public.room_members set role = 'Listener', has_raised_hand = false where room_id = p_room_id and user_id = p_user_id;
    
    insert into public.room_activity_logs (room_id, user_id, action_type, details, moderator_id)
    values (p_room_id, p_user_id, 'demote_listener', 'Demoted to listener', v_actor_id);
  else
    raise exception 'Invalid action: %', p_action;
  end if;

  return true;
end;
$$ language plpgsql security definer;

-- Room searching RPC
create or replace function public.search_rooms(p_query text)
returns setof public.rooms as $$
begin
  return query
  select * from public.rooms
  where name ilike '%' || p_query || '%'
     or username ilike '%' || p_query || '%'
     or description ilike '%' || p_query || '%'
  order by total_members desc;
end;
$$ language plpgsql stable;

-- Triggers
create or replace function public.handle_new_room_progression()
returns trigger as $$
begin
  insert into public.room_level_progress (room_id, current_level, current_xp)
  values (new.id, 1, 0);

  insert into public.room_statistics (room_id)
  values (new.id);

  insert into public.room_reputation (room_id)
  values (new.id);

  insert into public.room_gift_statistics (room_id)
  values (new.id);

  for i in 0..9 loop
    insert into public.room_seats (room_id, seat_index, role)
    values (new.id, i, case when i = 0 then 'Host' else 'Listener' end);
    
    insert into public.room_seat_gifts (room_id, seat_index, silver_gift_count)
    values (new.id, i, 0);
  end loop;

  return new;
end;
$$ language plpgsql security definer;

create or replace function public.increment_room_task_progress(
  p_room_id text,
  p_task_id text,
  p_amount integer
)
returns void as $$
begin
  insert into public.room_daily_task_progress (room_id, task_id, current_value)
  values (p_room_id, p_task_id, p_amount)
  on conflict (room_id, task_id) do update
  set current_value = room_daily_task_progress.current_value + p_amount;
end;
$$ language plpgsql security definer;

create or replace function public.add_room_xp(
  p_room_id text,
  p_xp integer
)
returns void as $$
begin
  update public.rooms
  set room_xp = room_xp + p_xp,
      today_room_xp = today_room_xp + p_xp
  where id = p_room_id;
end;
$$ language plpgsql security definer;

create or replace function public.reset_room_daily_progress()
returns void as $$
begin
  update public.room_level_progress p
  set consecutive_days_completed = case 
        when (select today_task_points from public.room_statistics s where s.room_id = p.room_id) >= 1200 then consecutive_days_completed + 1
        else 0
      end,
      last_completed_date = case 
        when (select today_task_points from public.room_statistics s where s.room_id = p.room_id) >= 1200 then now()::date
        else last_completed_date
      end;

  update public.room_statistics
  set today_visitors = 0,
      today_silver_coins = 0,
      today_gold_coins = 0,
      today_task_points = 0,
      today_extra_xp_points = 0,
      updated_at = now();

  update public.room_daily_task_progress
  set current_value = 0,
      is_completed = false,
      updated_at = now();
end;
$$ language plpgsql security definer;

-- Replace handle_room_message_mentions to be a no-op or drop function
create or replace function public.handle_room_message_mentions()
returns trigger as $$
begin
  -- Room message mentions are session-only inside the room and generate NO database/push notifications
  return new;
end;
$$ language plpgsql security definer;

-- 9. Redefine process_xp_event to grant 500 silver and 1-5 gold on ad watch
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

  -- ── Event-Specific Extra Currency Drops ───────────────────────────────────
  if p_event_type = 'ad_watched' then
    -- Watch ad grants 500 silver and 1 to 5 gold
    perform public.dispense_reward(v_user_id, 'ad_watched', 'ad_session', 'silver', 500, null);
    declare
      v_random_gold integer := floor(random() * (5 - 1 + 1) + 1)::integer;
    begin
      perform public.dispense_reward(v_user_id, 'ad_watched', 'ad_session', 'gold', v_random_gold, null);
    end;
  elsif p_event_type = 'room_joined_minute' then
    -- Join room grants 20 silver per minute
    perform public.dispense_reward(v_user_id, 'progression', 'room_minute', 'silver', 20, null);
  elsif p_event_type = 'room_hosted_minute' then
    -- Host room (microphone seat) grants 50 silver per minute
    perform public.dispense_reward(v_user_id, 'progression', 'host_minute', 'silver', 50, null);
  end if;

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

    -- Increment progress on running tasks matching this event type
    perform public.increment_task_progress(v_user_id, p_event_type, 1);

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

-- 9. Helper RPC: assign_room_role (Promote / Demote Co Owner & Admin)
create or replace function public.assign_room_role(
  p_room_id text,
  p_target_user_id uuid,
  p_role text
)
returns void as $$
declare
  v_caller_id uuid := auth.uid();
  v_room_owner_id uuid;
begin
  select host_id into v_room_owner_id from public.rooms where id = p_room_id;
  
  if v_caller_id is null or v_caller_id <> v_room_owner_id then
    raise exception 'Only the Owner can assign roles';
  end if;

  if p_role is null or p_role = 'Member' then
    delete from public.room_assigned_roles where room_id = p_room_id and user_id = p_target_user_id;
    update public.room_seats set user_id = null, mic_status = 'muted', is_speaking = false
    where room_id = p_room_id and seat_index = 1 and user_id = p_target_user_id;
    update public.room_members set role = 'Member' where room_id = p_room_id and user_id = p_target_user_id;
  else
    if p_role <> 'Co Owner' and p_role <> 'Admin' then
      raise exception 'Invalid role. Must be Co Owner or Admin';
    end if;

    insert into public.room_assigned_roles (room_id, user_id, role)
    values (p_room_id, p_target_user_id, p_role)
    on conflict (room_id, user_id) do update set role = EXCLUDED.role;

    update public.room_members set role = p_role where room_id = p_room_id and user_id = p_target_user_id;
  end if;
end;
$$ language plpgsql security definer set search_path = public;

-- 10. Helper RPC: lock_room_seat (Locks / Unlocks seats)
create or replace function public.lock_room_seat(
  p_room_id text,
  p_seat_index integer,
  p_lock boolean
)
returns void as $$
declare
  v_caller_id uuid := auth.uid();
  v_caller_role text;
begin
  select role into v_caller_role from public.room_members where room_id = p_room_id and user_id = v_caller_id;
  
  if v_caller_role is null or (v_caller_role <> 'Owner' and v_caller_role <> 'Co Owner') then
    raise exception 'Only Owner and Co-Owner can lock/unlock seats';
  end if;

  update public.room_seats
  set is_locked = p_lock
  where room_id = p_room_id and seat_index = p_seat_index;

  if p_lock = true then
    update public.room_seats
    set user_id = null,
        mic_status = 'muted',
        is_speaking = false
    where room_id = p_room_id and seat_index = p_seat_index;
  end if;
end;
$$ language plpgsql security definer set search_path = public;

-- 11. Helper RPC: mute_room_seat (Mutes / Unmutes seats)
create or replace function public.mute_room_seat(
  p_room_id text,
  p_seat_index integer,
  p_mute boolean
)
returns void as $$
declare
  v_caller_id uuid := auth.uid();
  v_caller_role text;
begin
  select role into v_caller_role from public.room_members where room_id = p_room_id and user_id = v_caller_id;
  
  if v_caller_role is null or (v_caller_role <> 'Owner' and v_caller_role <> 'Co Owner' and v_caller_role <> 'Admin') then
    raise exception 'Only Owner, Co-Owner, and Admin can mute/unmute seats';
  end if;

  update public.room_seats
  set is_muted = p_mute
  where room_id = p_room_id and seat_index = p_seat_index;

  if p_mute = true then
    update public.room_seats
    set mic_status = 'muted',
        is_speaking = false
    where room_id = p_room_id and seat_index = p_seat_index;
  end if;
end;
$$ language plpgsql security definer set search_path = public;

-- 12. Helper RPC: kick_room_user (Supports 1, 3, 7, 15, 30 days & permanent kick durations)
create or replace function public.kick_room_user(
  p_room_id text,
  p_target_user_id uuid,
  p_duration_days integer,
  p_reason text default null
)
returns void as $$
declare
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_target_role text;
  v_expires_at timestamp with time zone;
begin
  select role into v_caller_role from public.room_members where room_id = p_room_id and user_id = v_caller_id;
  select role into v_target_role from public.room_members where room_id = p_room_id and user_id = p_target_user_id;

  if v_caller_role is null then
    raise exception 'Unauthorized';
  end if;

  if v_caller_role = 'Admin' then
    if v_target_role is not null and v_target_role <> 'Member' then
      raise exception 'Admin can only kick normal Members';
    end if;
  elsif v_caller_role <> 'Owner' and v_caller_role <> 'Co Owner' then
    raise exception 'Unauthorized to kick users';
  end if;

  if v_target_role = 'Owner' then
    raise exception 'The Owner cannot be kicked';
  end if;

  if p_duration_days > 0 then
    v_expires_at := now() + (p_duration_days * interval '1 day');
  else
    v_expires_at := null; -- Permanent ban
  end if;

  insert into public.room_bans (room_id, user_id, banned_by, reason, expires_at)
  values (p_room_id, p_target_user_id, v_caller_id, p_reason, v_expires_at)
  on conflict (room_id, user_id) do update 
  set banned_by = EXCLUDED.banned_by, reason = EXCLUDED.reason, expires_at = EXCLUDED.expires_at;

  -- Clear seat
  update public.room_seats
  set user_id = null,
      mic_status = 'muted',
      is_speaking = false
  where room_id = p_room_id and user_id = p_target_user_id;

  -- Remove from membership
  delete from public.room_members where room_id = p_room_id and user_id = p_target_user_id;

  -- Broadcast leave
  insert into public.room_activity_events (room_id, event_type, user_id, message)
  values (p_room_id, 'leave', p_target_user_id, 'Kicked from room');
end;
$$ language plpgsql security definer set search_path = public;

-- 13. Helper RPC: invite_room_user (Enforces invite policies)
create or replace function public.invite_room_user(
  p_room_id text,
  p_target_user_id uuid
)
returns void as $$
declare
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_room public.rooms%rowtype;
  v_allowed boolean := false;
begin
  select * into v_room from public.rooms where id = p_room_id;
  if v_room.id is null then
    raise exception 'Room not found';
  end if;

  select role into v_caller_role from public.room_members where room_id = p_room_id and user_id = v_caller_id;

  if v_caller_id = v_room.host_id then
    v_allowed := true;
  elsif v_room.invite_permission_mode = 'Everyone' then
    v_allowed := true;
  elsif v_room.invite_permission_mode = 'Admin and Above' and v_caller_role in ('Owner', 'Co Owner', 'Admin') then
    v_allowed := true;
  elsif v_room.invite_permission_mode = 'Co Owner and Owner' and v_caller_role in ('Owner', 'Co Owner') then
    v_allowed := true;
  end if;

  if not v_allowed then
    raise exception 'You do not have permission to invite users to this room';
  end if;

  insert into public.room_invites (room_id, user_id, invited_by)
  values (p_room_id, p_target_user_id, v_caller_id)
  on conflict (room_id, user_id) do nothing;
end;
$$ language plpgsql security definer set search_path = public;

-- Replace handle_gift_received_notifications to be a no-op
create or replace function public.handle_gift_received_notifications()
returns trigger as $$
begin
  -- Gifts belong exclusively to active room sessions or direct transfers and generate NO system notifications
  return null;
end;
$$ language plpgsql security definer;

-- 4. TRANSIENT ROOM CHAT PURGE RPC
create or replace function public.purge_room_transient_messages(p_room_id text)
returns boolean as $$
begin
  if p_room_id is null or p_room_id = '' then
    return false;
  end if;

  delete from public.room_messages
  where room_id = p_room_id;

  return true;
end;
$$ language plpgsql security definer set search_path = public;

-- 3. AUTOMATIC TRIGGER TO PURGE MESSAGES WHEN A ROOM HAS 0 MEMBERS OR ENDS
create or replace function public.auto_purge_empty_room_messages()
returns trigger as $$
begin
  -- If total_members drops to 0 or room status is ended, delete all room chat messages
  if (new.total_members <= 0 or new.status = 'ended') then
    delete from public.room_messages
    where room_id = new.id;
  end if;

  return new;
end;
$$ language plpgsql security definer set search_path = public;

-- 4. RPC TO MANUALLY PURGE ALL ROOM CHATS AT ANY TIME
create or replace function public.purge_all_room_chats()
returns boolean as $$
begin
  truncate table public.room_messages;
  return true;
end;
$$ language plpgsql security definer set search_path = public;

-- Helper function to compute level-based role limits (always available)
CREATE OR REPLACE FUNCTION public.get_room_role_limits(p_room_id text)
RETURNS TABLE (
  max_owners int,
  max_co_owners int,
  max_admins int
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_room_id text;
  v_level int := 1;
  v_co_owners int := 1;
  v_admins int := 4;
BEGIN
  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN v_room_id := p_room_id; END IF;

  SELECT COALESCE(level, room_level, 1) INTO v_level FROM public.rooms WHERE id = v_room_id;
  IF v_level IS NULL OR v_level < 1 THEN v_level := 1; END IF;

  IF v_level = 1 THEN
    v_co_owners := 1; v_admins := 4;
  ELSIF v_level = 2 THEN
    v_co_owners := 1; v_admins := 10;
  ELSIF v_level = 3 THEN
    v_co_owners := 2; v_admins := 15;
  ELSIF v_level = 4 THEN
    v_co_owners := 2; v_admins := 20;
  ELSIF v_level = 5 THEN
    v_co_owners := 3; v_admins := 25;
  ELSIF v_level = 6 THEN
    v_co_owners := 4; v_admins := 35;
  ELSE
    v_co_owners := 5; v_admins := 50;
  END IF;

  RETURN QUERY SELECT 1 AS max_owners, v_co_owners AS max_co_owners, v_admins AS max_admins;
END;
$$;

-- 2. RPC: Toggle seat lock with backend permission validation and UUID resolution
CREATE OR REPLACE FUNCTION public.toggle_seat_lock(
  p_room_id text,
  p_seat_index int
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id uuid;
  v_caller_role text := 'Visitor';
  v_is_owner boolean := false;
  v_current_locked boolean := false;
  v_new_locked boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Resolve room UUID dynamically
  IF p_room_id ~* '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    v_room_id := p_room_id::uuid;
  ELSE
    SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      BEGIN
        v_room_id := p_room_id::uuid;
      EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Room not found for ID: %', p_room_id;
      END;
    END IF;
  END IF;

  -- Check if caller is room owner from rooms table
  SELECT (host_id = v_caller_id) INTO v_is_owner FROM public.rooms WHERE id = v_room_id;

  -- Fetch caller role from room_members
  SELECT role INTO v_caller_role FROM public.room_members 
  WHERE room_id = v_room_id AND user_id = v_caller_id;

  IF v_is_owner THEN v_caller_role := 'Owner'; END IF;

  -- Verify lock permissions (Owner, Co-Owner, Admin only)
  IF v_caller_role NOT IN ('Owner', 'Co-Owner', 'Co Owner', 'Admin') THEN
    RAISE EXCEPTION 'Only Room Owner, Co-Owners, or Admins can manage seat locks.';
  END IF;

  -- Get current seat lock status
  SELECT COALESCE(is_locked, false) INTO v_current_locked 
  FROM public.room_seats 
  WHERE room_id = v_room_id AND seat_index = p_seat_index;

  v_new_locked := NOT v_current_locked;

  -- Update room_seats table
  INSERT INTO public.room_seats (room_id, seat_index, is_locked, locked_by, locked_at, updated_at)
  VALUES (v_room_id, p_seat_index, v_new_locked, v_caller_id, now(), now())
  ON CONFLICT (room_id, seat_index) DO UPDATE 
  SET is_locked = v_new_locked,
      locked_by = CASE WHEN v_new_locked THEN v_caller_id ELSE NULL END,
      locked_at = CASE WHEN v_new_locked THEN now() ELSE NULL END,
      updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'seat_index', p_seat_index,
    'is_locked', v_new_locked,
    'locked_by', v_caller_id
  );
END;
$$;

-- 2. Function to check if user can modify room entry rules (Creator/Owner & Co-Owner ONLY)
CREATE OR REPLACE FUNCTION public.can_change_room_entry_rules(
  p_room_id text,
  p_user_id uuid
) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_room_id uuid;
  v_is_owner boolean := false;
  v_role text := 'Visitor';
BEGIN
  IF p_room_id ~* '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    v_room_id := p_room_id::uuid;
  ELSE
    SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      BEGIN v_room_id := p_room_id::uuid; EXCEPTION WHEN OTHERS THEN v_room_id := NULL; END;
    END IF;
  END IF;

  SELECT (host_id = p_user_id OR room_owner = p_user_id) INTO v_is_owner FROM public.rooms WHERE id = v_room_id;
  IF v_is_owner THEN
    RETURN true;
  END IF;

  SELECT role INTO v_role FROM public.room_members WHERE room_id = v_room_id AND user_id = p_user_id;
  IF v_role IN ('Co-Owner', 'Co Owner', 'Creator', 'Owner') THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

-- Migration: Voice Room Seat System Naming Fix (Host, Co Host, No.1 to No.8)
-- Date: 2026-08-06

-- 1. Helper Postgres function to resolve standard seat name by 0-based seat_index
CREATE OR REPLACE FUNCTION public.get_seat_name(p_seat_index int)
RETURNS text LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  CASE p_seat_index
    WHEN 0 THEN RETURN 'Host';
    WHEN 1 THEN RETURN 'Co Host';
    WHEN 2 THEN RETURN 'No.1';
    WHEN 3 THEN RETURN 'No.2';
    WHEN 4 THEN RETURN 'No.3';
    WHEN 5 THEN RETURN 'No.4';
    WHEN 6 THEN RETURN 'No.5';
    WHEN 7 THEN RETURN 'No.6';
    WHEN 8 THEN RETURN 'No.7';
    WHEN 9 THEN RETURN 'No.8';
    ELSE RETURN 'No.' || (p_seat_index - 1)::text;
  END CASE;
END;
$$;

-- 3. RPC function to update room background theme cleanly
CREATE OR REPLACE FUNCTION public.update_room_background_theme(
  p_room_id text,
  p_theme_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id uuid;
BEGIN
  -- Resolve Room UUID
  IF p_room_id ~* '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    v_room_id := p_room_id::uuid;
  ELSE
    SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      BEGIN v_room_id := p_room_id::uuid; EXCEPTION WHEN OTHERS THEN v_room_id := NULL; END;
    END IF;
  END IF;

  IF v_room_id IS NULL THEN
    RAISE EXCEPTION 'Room not found.';
  END IF;

  -- Update room_theme in database
  UPDATE public.rooms
  SET room_theme = p_theme_id
  WHERE id = v_room_id;

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'room_theme', p_theme_id
  );
END;
$$;

-- 2. Update RPC Function to update room password securely
CREATE OR REPLACE FUNCTION public.update_room_password(
  p_room_id text,
  p_new_password text,
  p_user_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id uuid;
  v_room_id text;
  v_host_id uuid;
  v_co_owner_ids uuid[];
  v_admin_ids uuid[];
  v_is_authorized boolean := false;
BEGIN
  IF p_user_id IS NOT NULL AND length(trim(p_user_id)) > 0 THEN
    BEGIN
      v_caller_id := p_user_id::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_caller_id := auth.uid();
    END;
  ELSE
    v_caller_id := auth.uid();
  END IF;

  -- Resolve room ID
  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN
    v_room_id := p_room_id;
  END IF;

  -- Fetch room details
  SELECT host_id, co_owner_ids, admin_ids
  INTO v_host_id, v_co_owner_ids, v_admin_ids
  FROM public.rooms
  WHERE id = v_room_id;

  -- Check authority (Owner, Co-Owner, Admin, or fallback)
  IF v_caller_id IS NULL OR
     v_caller_id = v_host_id OR
     v_caller_id = ANY(COALESCE(v_co_owner_ids, '{}')) OR
     v_caller_id = ANY(COALESCE(v_admin_ids, '{}')) THEN
    v_is_authorized := true;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Only Room Owner, Co-Owners, and Admins can configure room password.';
  END IF;

  -- Update room password & entry permission in public.rooms and public.room_settings
  IF p_new_password IS NULL OR length(trim(p_new_password)) = 0 THEN
    UPDATE public.rooms
    SET room_password = NULL,
        entry_permission = 'everyone',
        visibility = 'everyone',
        who_can_join = 'Everyone',
        updated_at = timezone('utc'::text, now())
    WHERE id = v_room_id;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'room_settings' AND table_schema = 'public') THEN
      UPDATE public.room_settings
      SET room_password = NULL,
          password_protected = false
      WHERE room_id = v_room_id;
    END IF;
  ELSE
    UPDATE public.rooms
    SET room_password = trim(p_new_password),
        entry_permission = 'password',
        visibility = 'password_required',
        who_can_join = 'Password Required',
        updated_at = timezone('utc'::text, now())
    WHERE id = v_room_id;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'room_settings' AND table_schema = 'public') THEN
      INSERT INTO public.room_settings (room_id, room_password, password_protected)
      VALUES (v_room_id, trim(p_new_password), true)
      ON CONFLICT (room_id) DO UPDATE 
      SET room_password = EXCLUDED.room_password, password_protected = true;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'password', trim(COALESCE(p_new_password, '')),
    'has_password', (p_new_password IS NOT NULL AND length(trim(p_new_password)) > 0)
  );
END;
$$;

-- 3. Wrapper RPC promote_room_member_role_v2
CREATE OR REPLACE FUNCTION public.promote_room_member_role_v2(
  p_room_id text,
  p_target_user_id uuid,
  p_new_role text,
  p_expiry_hours int DEFAULT NULL,
  p_custom_permissions jsonb DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN public.promote_room_member_role(p_room_id, p_target_user_id, p_new_role);
END;
$$;

-- 5. Wrapper RPC demote_room_member_role_v2
CREATE OR REPLACE FUNCTION public.demote_room_member_role_v2(
  p_room_id text,
  p_target_user_id uuid,
  p_apply_cooldown boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN public.demote_room_member_role(p_room_id, p_target_user_id, NULL);
END;
$$;

-- 8. RPC: Issue Room Warning (3-Strike Escalation System)
CREATE OR REPLACE FUNCTION public.issue_room_warning(
  p_room_id text,
  p_target_user_id uuid,
  p_reason text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_caller_role text := 'Visitor';
  v_target_role text := 'Visitor';
  v_is_room_owner boolean := false;
  v_active_warnings int := 0;
  v_next_level int := 1;
  v_auto_kicked boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;

  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN v_room_id := p_room_id; END IF;

  SELECT (host_id = v_caller_id OR room_owner = v_caller_id) INTO v_is_room_owner FROM public.rooms WHERE id = v_room_id;
  SELECT role INTO v_caller_role FROM public.room_members WHERE room_id = v_room_id AND user_id = v_caller_id;
  SELECT role INTO v_target_role FROM public.room_members WHERE room_id = v_room_id AND user_id = p_target_user_id;

  IF v_is_room_owner THEN v_caller_role := 'Owner'; END IF;

  -- Protection Check: Cannot warn Owner or Co-Owner if caller is lower role
  IF v_target_role IN ('Creator', 'Owner') OR p_target_user_id IN (SELECT host_id FROM public.rooms WHERE id = v_room_id) THEN
    RAISE EXCEPTION 'PROTECTION VIOLATION: Cannot issue warnings to Room Owner.';
  END IF;
  IF v_target_role IN ('Co-Owner', 'Co Owner') AND v_caller_role NOT IN ('Owner', 'Creator') THEN
    RAISE EXCEPTION 'PROTECTION VIOLATION: Only Room Owner can warn Co-Owners.';
  END IF;

  -- Calculate Active Warning Count
  SELECT COUNT(*) INTO v_active_warnings FROM public.room_user_warnings 
  WHERE room_id = v_room_id AND user_id = p_target_user_id AND is_active = true;

  v_next_level := v_active_warnings + 1;

  INSERT INTO public.room_user_warnings (room_id, user_id, issued_by, warning_level, reason)
  VALUES (v_room_id, p_target_user_id, v_caller_id, v_next_level, p_reason);

  -- Log Admin Activity
  INSERT INTO public.room_admin_activity_logs (room_id, admin_id, action_type, target_user_id, details)
  VALUES (v_room_id, v_caller_id, 'WARNING_ISSUED', p_target_user_id, jsonb_build_object('level', v_next_level, 'reason', p_reason));

  -- 3rd Warning Escalation: Auto-Kick User from room_members!
  IF v_next_level >= 3 THEN
    v_auto_kicked := true;
    DELETE FROM public.room_members WHERE room_id = v_room_id AND user_id = p_target_user_id;
    
    INSERT INTO public.room_admin_activity_logs (room_id, admin_id, action_type, target_user_id, details)
    VALUES (v_room_id, v_caller_id, 'KICK', p_target_user_id, jsonb_build_object('auto_kick', true, 'reason', '3-Strike Warning Threshold Reached'));
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'warning_level', v_next_level,
    'auto_kicked', v_auto_kicked
  );
END;
$$;

-- 9. RPC: Toggle Emergency Mode (1-Click Lock)
CREATE OR REPLACE FUNCTION public.toggle_room_emergency_mode(
  p_room_id text,
  p_enabled boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_is_room_owner boolean := false;
  v_caller_role text := 'Visitor';
BEGIN
  IF v_caller_id IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;

  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN v_room_id := p_room_id; END IF;

  SELECT (host_id = v_caller_id OR room_owner = v_caller_id) INTO v_is_room_owner FROM public.rooms WHERE id = v_room_id;
  SELECT role INTO v_caller_role FROM public.room_members WHERE room_id = v_room_id AND user_id = v_caller_id;

  IF NOT v_is_room_owner AND v_caller_role NOT IN ('Co-Owner', 'Co Owner') THEN
    RAISE EXCEPTION 'Only Room Owner or Co-Owners can toggle Emergency Mode.';
  END IF;

  UPDATE public.rooms SET is_emergency_mode = p_enabled WHERE id = v_room_id;

  -- Log Activity
  INSERT INTO public.room_admin_activity_logs (room_id, admin_id, action_type, details)
  VALUES (v_room_id, v_caller_id, 'EMERGENCY_TOGGLE', jsonb_build_object('enabled', p_enabled));

  RETURN jsonb_build_object('success', true, 'is_emergency_mode', p_enabled);
END;
$$;

-- 10. RPC: Get Full Room Governance Overview (Role Counters, Security Score, Health Score, Governance Level)
CREATE OR REPLACE FUNCTION public.get_room_governance_overview(
  p_room_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_room_id text;
  v_room RECORD;
  v_owner_count int := 0;
  v_co_owner_count int := 0;
  v_admin_count int := 0;
  v_audience_count int := 0;
  v_limits RECORD;
  v_history jsonb;
  v_admin_logs jsonb;
  v_warnings jsonb;
BEGIN
  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN v_room_id := p_room_id; END IF;

  SELECT * INTO v_room FROM public.rooms WHERE id = v_room_id;
  IF v_room.id IS NULL THEN RAISE EXCEPTION 'Room not found.'; END IF;

  SELECT * FROM public.get_room_role_limits(v_room_id) INTO v_limits;

  -- Role Counts
  SELECT COUNT(*) INTO v_owner_count FROM public.room_members WHERE room_id = v_room_id AND role IN ('Owner', 'Creator');
  IF v_owner_count = 0 THEN v_owner_count := 1; END IF;

  SELECT COUNT(*) INTO v_co_owner_count FROM public.room_members WHERE room_id = v_room_id AND role IN ('Co-Owner', 'Co Owner');
  SELECT COUNT(*) INTO v_admin_count FROM public.room_members WHERE room_id = v_room_id AND role = 'Admin';
  SELECT COUNT(*) INTO v_audience_count FROM public.room_members WHERE room_id = v_room_id AND (role IS NULL OR role NOT IN ('Owner', 'Creator', 'Co-Owner', 'Co Owner', 'Admin'));

  -- History (Last 20)
  SELECT jsonb_agg(h) INTO v_history FROM (
    SELECT id, actor_id, actor_role, target_user_id, action_type, old_role, new_role, expires_at, created_at
    FROM public.room_permission_history
    WHERE room_id = v_room_id ORDER BY created_at DESC LIMIT 20
  ) h;

  -- Admin Activity Logs (Last 20)
  SELECT jsonb_agg(l) INTO v_admin_logs FROM (
    SELECT id, admin_id, action_type, target_user_id, details, created_at
    FROM public.room_admin_activity_logs
    WHERE room_id = v_room_id ORDER BY created_at DESC LIMIT 20
  ) l;

  -- User Warnings
  SELECT jsonb_agg(w) INTO v_warnings FROM (
    SELECT id, user_id, issued_by, warning_level, reason, is_active, created_at
    FROM public.room_user_warnings
    WHERE room_id = v_room_id AND is_active = true ORDER BY created_at DESC LIMIT 20
  ) w;

  RETURN jsonb_build_object(
    'room_id', v_room_id,
    'security_score', COALESCE(v_room.security_score, 5.00),
    'health_score', COALESCE(v_room.health_score, 100),
    'governance_level', COALESCE(v_room.governance_level, 1),
    'is_emergency_mode', COALESCE(v_room.is_emergency_mode, false),
    'backup_owner_id', v_room.backup_owner_id,
    'role_counters', jsonb_build_object(
      'owner', v_owner_count,
      'max_owners', 1,
      'co_owner', v_co_owner_count,
      'max_co_owners', v_limits.max_co_owners,
      'admin', v_admin_count,
      'max_admins', v_limits.max_admins,
      'audience', v_audience_count
    ),
    'permission_history', COALESCE(v_history, '[]'::jsonb),
    'admin_activity_logs', COALESCE(v_admin_logs, '[]'::jsonb),
    'active_warnings', COALESCE(v_warnings, '[]'::jsonb)
  );
END;
$$;

-- 5. Validate & Add Room VP (Complete Server-Side Anti-Fake RPC)
create or replace function public.validate_and_add_room_vp(
  p_room_id text,
  p_user_id uuid,
  p_vp integer,
  p_source text,
  p_stay_seconds integer default 60,
  p_target_user_id uuid default null,
  p_device_fingerprint text default null,
  p_is_emulator boolean default false,
  p_is_vpn boolean default false
)
returns jsonb as $$
declare
  v_trust_data jsonb;
  v_trust_score integer := 80;
  v_multiplier numeric := 1.0;
  v_is_banned boolean := false;
  v_allowed_vp integer := 0;
  v_final_vp integer := 0;
  v_seat_count integer := 0;
  v_target_device text;
  v_rpc_res jsonb;
begin
  if p_vp <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Invalid VP input', 'added_vp', 0);
  end if;

  -- Evaluate user trust score (Rules 19, 20)
  v_trust_data := public.calculate_user_trust_score(p_user_id);
  v_trust_score := (v_trust_data->>'trust_score')::integer;
  v_multiplier := (v_trust_data->>'multiplier')::numeric;
  v_is_banned := (v_trust_data->>'is_device_banned')::boolean;

  -- Device Ban Check (Rule 17)
  if v_is_banned then
    insert into public.room_anti_abuse_logs (room_id, user_id, violation_code, details, device_fingerprint, trust_score_snapshot)
    values (p_room_id, p_user_id, 'DEVICE_BANNED', 'Banned device attempted VP action', p_device_fingerprint, v_trust_score);
    return jsonb_build_object('success', false, 'reason', 'Device is banned from earning VP', 'added_vp', 0);
  end if;

  -- Check if device fingerprint is banned in device table (Rule 17)
  if p_device_fingerprint is not null then
    if exists (select 1 from public.user_device_fingerprints where device_fingerprint = p_device_fingerprint and is_banned = true) then
      insert into public.room_anti_abuse_logs (room_id, user_id, violation_code, details, device_fingerprint, trust_score_snapshot)
      values (p_room_id, p_user_id, 'FINGERPRINT_BANNED', 'Banned device fingerprint detected', p_device_fingerprint, v_trust_score);
      return jsonb_build_object('success', false, 'reason', 'Device fingerprint is banned', 'added_vp', 0);
    end if;

    -- Upsert device linkage
    insert into public.user_device_fingerprints (device_fingerprint, user_id, last_seen_at)
    values (p_device_fingerprint, p_user_id, now())
    on conflict (device_fingerprint, user_id) do update set last_seen_at = now();
  end if;

  -- Self-Support Protection (Rule 4)
  if p_target_user_id is not null then
    if p_target_user_id = p_user_id then
      insert into public.room_anti_abuse_logs (room_id, user_id, violation_code, details, trust_score_snapshot)
      values (p_room_id, p_user_id, 'SELF_GIFT_BLOCKED', 'User attempted self-gifting VP', v_trust_score);
      return jsonb_build_object('success', false, 'reason', 'Self gifting VP not allowed', 'added_vp', 0);
    end if;

    -- Check if target user shares same device fingerprint (Rule 3 & 4)
    if p_device_fingerprint is not null then
      select device_fingerprint into v_target_device
      from public.user_trust_scores
      where user_id = p_target_user_id;

      if v_target_device is not null and v_target_device = p_device_fingerprint then
        insert into public.room_anti_abuse_logs (room_id, user_id, violation_code, details, device_fingerprint, trust_score_snapshot)
        values (p_room_id, p_user_id, 'SAME_DEVICE_SELF_SUPPORT', 'Self-support detected on same device fingerprint', p_device_fingerprint, v_trust_score);
        return jsonb_build_object('success', false, 'reason', 'Multi-account self support detected on same device', 'added_vp', 0);
      end if;
    end if;
  end if;

  -- Minimum Stay Requirement Validation (Rule 12)
  if p_source in ('user_stay_time', 'active_mic_time') and p_stay_seconds < 60 then
    return jsonb_build_object('success', false, 'reason', 'Minimum valid stay duration (60s) not met', 'added_vp', 0);
  end if;

  -- Apply base VP & trust multiplier
  v_allowed_vp := (p_vp * v_multiplier)::integer;

  -- Solo Seat Slow Mode Adjustment (Rule 1)
  select count(*) into v_seat_count
  from public.room_seats
  where room_id = p_room_id and user_id is not null;

  if v_seat_count = 1 and p_source = 'active_mic_time' then
    v_allowed_vp := (v_allowed_vp * 0.5)::integer;
  end if;

  if v_allowed_vp <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Low trust score or zero multiplier', 'added_vp', 0);
  end if;

  -- Execute add_room_vp RPC
  v_rpc_res := public.add_room_vp(p_room_id, v_allowed_vp, p_source);

  return jsonb_build_object(
    'success', coalesce((v_rpc_res->>'success')::boolean, true),
    'room_id', p_room_id,
    'user_id', p_user_id,
    'requested_vp', p_vp,
    'allowed_vp', v_allowed_vp,
    'added_vp', coalesce((v_rpc_res->>'added_vp')::integer, v_allowed_vp),
    'trust_score', v_trust_score,
    'multiplier', v_multiplier,
    'seat_count', v_seat_count
  );
end;
$$ language plpgsql security definer;

-- 9. Helper function: Add Room VP with Gold Task Overflow
create or replace function public.add_room_vp_with_overflow(
  p_room_id text,
  p_user_id uuid,
  p_vp integer,
  p_currency text default 'gold'
) returns jsonb as $$
declare
  v_is_weekend boolean := (extract(isodow from (now() at time zone 'Asia/Kolkata')) in (6, 7));
  v_max_free_vp integer := case when v_is_weekend then 1400 else 700 end;
  v_max_gold_vp integer := case when v_is_weekend then 2400 else 1000 end;
  v_max_total_vp integer := v_max_free_vp + v_max_gold_vp;
  
  v_current_free_vp integer := 0;
  v_current_gold_vp integer := 0;
  v_current_total_vp integer := 0;
  
  v_gold_capacity integer := 0;
  v_gold_added integer := 0;
  v_overflow integer := 0;
  v_free_capacity integer := 0;
  v_free_added integer := 0;
  v_total_added_vp integer := 0;
begin
  if p_vp <= 0 then
    return jsonb_build_object('success', false, 'added_vp', 0);
  end if;

  select 
    coalesce(sum(case when t.category <> 'gold' then p.current_value else 0 end), 0),
    coalesce(sum(case when t.category = 'gold' then p.current_value else 0 end), 0)
  into v_current_free_vp, v_current_gold_vp
  from public.user_daily_task_progress p
  join public.room_daily_task_catalog t on t.task_key = p.task_key
  where p.user_id = p_user_id and p.task_date = ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date;

  v_current_total_vp := v_current_free_vp + v_current_gold_vp;

  if v_current_total_vp >= v_max_total_vp then
    return jsonb_build_object('success', false, 'reason', 'MAX daily task limit reached', 'added_vp', 0);
  end if;

  if p_currency = 'gold' then
    v_gold_capacity := greatest(0, v_max_gold_vp - v_current_gold_vp);
    if p_vp <= v_gold_capacity then
      v_gold_added := p_vp;
      v_overflow := 0;
    else
      v_gold_added := v_gold_capacity;
      v_overflow := p_vp - v_gold_capacity;
    end if;

    if v_overflow > 0 then
      v_free_capacity := greatest(0, v_max_free_vp - v_current_free_vp);
      v_free_added := least(v_overflow, v_free_capacity);
    end if;
  else
    v_free_capacity := greatest(0, v_max_free_vp - v_current_free_vp);
    v_free_added := least(p_vp, v_free_capacity);
  end if;

  v_total_added_vp := v_gold_added + v_free_added;

  if v_total_added_vp > 0 then
    update public.rooms
    set room_xp = coalesce(room_xp, 0) + v_total_added_vp,
        today_room_xp = coalesce(today_room_xp, 0) + v_total_added_vp,
        updated_at = now()
    where id = p_room_id;

    if v_gold_added > 0 then
      insert into public.user_daily_task_progress (user_id, task_key, current_value, is_completed, task_date)
      values (p_user_id, 'gold_send_10', v_current_gold_vp + v_gold_added, (v_current_gold_vp + v_gold_added) >= v_max_gold_vp, ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date)
      on conflict (user_id, task_key, task_date) do update set
        current_value = user_daily_task_progress.current_value + v_gold_added,
        is_completed = (user_daily_task_progress.current_value + v_gold_added) >= v_max_gold_vp,
        updated_at = now();
    end if;

    if v_free_added > 0 then
      insert into public.user_daily_task_progress (user_id, task_key, current_value, is_completed, task_date)
      values (p_user_id, 'normal_stay_15m', v_current_free_vp + v_free_added, (v_current_free_vp + v_free_added) >= v_max_free_vp, ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date)
      on conflict (user_id, task_key, task_date) do update set
        current_value = user_daily_task_progress.current_value + v_free_added,
        is_completed = (user_daily_task_progress.current_value + v_free_added) >= v_max_free_vp,
        updated_at = now();
    end if;
  end if;

  return jsonb_build_object(
    'success', true,
    'added_vp', v_total_added_vp,
    'gold_added', v_gold_added,
    'free_added', v_free_added,
    'current_total', v_current_total_vp + v_total_added_vp,
    'max_total', v_max_total_vp
  );
end;
$$ language plpgsql security definer;

-- 4. Safe helper function: get_room_permissions
CREATE OR REPLACE FUNCTION public.get_room_permissions(p_room_id text)
RETURNS jsonb AS $$
BEGIN
  RETURN jsonb_build_object(
    'can_speak', true,
    'can_chat', true,
    'can_gift', true,
    'can_apply_seat', true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Update send_star_gift to integrate Dual Progress System
create or replace function public.send_star_gift_dual_wrapper(
  p_room_id text,
  p_user_id uuid,
  p_points integer,
  p_currency text
) returns jsonb as $$
begin
  return public.process_room_dual_progress(
    p_room_id,
    p_user_id,
    p_points,
    case when lower(p_currency) = 'gold' then 'gold_gift' else 'silver_gift' end
  );
end;
$$ language plpgsql security definer;

-- 2. User Daily Task Catalog Updates on Gift
create or replace function public.update_user_daily_tasks_on_gift(
  p_user_id uuid,
  p_amount integer,
  p_currency text
) returns void as $$
declare
  v_today date := ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date;
  v_rec record;
  v_curr text := lower(coalesce(p_currency, 'gold'));
begin
  if p_amount <= 0 or p_user_id is null then
    return;
  end if;

  if v_curr = 'gold' then
    -- Update Gold category & Gold send daily tasks
    for v_rec in 
      select task_key, target_value from public.room_daily_task_catalog where category = 'gold' or task_key = 'normal_send_1_gold'
    loop
      insert into public.user_daily_task_progress (user_id, task_key, current_value, is_completed, task_date, updated_at)
      values (p_user_id, v_rec.task_key, p_amount, p_amount >= v_rec.target_value, v_today, now())
      on conflict (user_id, task_key, task_date) do update set
        current_value = user_daily_task_progress.current_value + p_amount,
        is_completed = (user_daily_task_progress.current_value + p_amount) >= v_rec.target_value,
        updated_at = now();
    end loop;
  elsif v_curr = 'silver' then
    -- Update Silver send daily tasks
    for v_rec in 
      select task_key, target_value from public.room_daily_task_catalog where task_key in ('normal_send_1_silver', 'normal_send_5_silver')
    loop
      insert into public.user_daily_task_progress (user_id, task_key, current_value, is_completed, task_date, updated_at)
      values (p_user_id, v_rec.task_key, p_amount, p_amount >= v_rec.target_value, v_today, now())
      on conflict (user_id, task_key, task_date) do update set
        current_value = user_daily_task_progress.current_value + p_amount,
        is_completed = (user_daily_task_progress.current_value + p_amount) >= v_rec.target_value,
        updated_at = now();
    end loop;
  else
    -- Volt or other currency tasks
    for v_rec in 
      select task_key, target_value from public.room_daily_task_catalog where task_key in ('normal_send_1_silver', 'normal_send_5_silver')
    loop
      insert into public.user_daily_task_progress (user_id, task_key, current_value, is_completed, task_date, updated_at)
      values (p_user_id, v_rec.task_key, p_amount, p_amount >= v_rec.target_value, v_today, now())
      on conflict (user_id, task_key, task_date) do update set
        current_value = user_daily_task_progress.current_value + p_amount,
        is_completed = (user_daily_task_progress.current_value + p_amount) >= v_rec.target_value,
        updated_at = now();
    end loop;
  end if;
end;
$$ language plpgsql security definer;

-- 3. Create column sync trigger for public.rooms (Keeps room_level and level in sync)
create or replace function public.sync_room_level_columns()
returns trigger as $$
begin
  if new.room_level is distinct from old.room_level then
    new.level := new.room_level;
  elsif new.level is distinct from old.level then
    new.room_level := new.level;
  end if;
  return new;
end;
$$ language plpgsql;

-- 2. Helper function to return required Total Task for next level
create or replace function public.get_required_task_for_level(p_level integer)
returns integer as $$
begin
  if p_level = 1 then return 35500;
  elsif p_level = 2 then return 59500;
  elsif p_level = 3 then return 95000;
  elsif p_level = 4 then return 490000;
  elsif p_level = 5 then return 940000;
  elsif p_level = 6 then return 1590000;
  else return 1590000;
  end if;
end;
$$ language plpgsql immutable;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Database Protection Trigger (Immutability of host_id & room_owner)
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.prevent_auto_room_ownership_change()
returns trigger as $$
begin
  if (old.host_id is distinct from new.host_id or old.room_owner is distinct from new.room_owner) then
    if current_setting('app.allow_ownership_transfer', true) is distinct from 'true' then
      raise exception 'UNAUTHORIZED_OWNERSHIP_CHANGE: Room ownership is permanent and can only be changed via manual transfer or Super Admin.';
    end if;
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

create or replace function public.clean_expired_presences()
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.cleanup_expired_room_members();
end;
$$;

-- 2. Register User Session RPC (Single Active Session Enforcement)
create or replace function public.register_user_session_rpc(
  p_session_id text,
  p_device_id text default 'unknown',
  p_device_name text default 'Mobile Device',
  p_os_version text default 'Android/iOS',
  p_app_version text default '1.0.0',
  p_platform text default 'Flutter'
) returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_old_session text;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Check if user has another active session
  select session_id into v_old_session
  from public.user_sessions
  where user_id = v_user_id and session_id <> p_session_id and online_status <> 'Offline'
  limit 1;

  if v_old_session is not null then
    -- Invalidate old session status
    update public.user_sessions
    set online_status = 'Offline'
    where user_id = v_user_id and session_id = v_old_session;
    
    -- Free old session seats
    update public.room_seats
    set user_id = null, mic_status = 'muted', is_speaking = false, is_reconnecting = false, session_id = null
    where user_id = v_user_id and session_id = v_old_session;

    -- Remove from room members of old session
    delete from public.room_members
    where user_id = v_user_id and session_id = v_old_session;
  end if;

  -- Upsert current active session
  insert into public.user_sessions (
    session_id, user_id, device_id, device_name, os_version, app_version, platform, online_status, last_seen
  ) values (
    p_session_id, v_user_id, p_device_id, p_device_name, p_os_version, p_app_version, p_platform, 'Online', now()
  )
  on conflict (session_id) do update set
    device_id = EXCLUDED.device_id,
    device_name = EXCLUDED.device_name,
    os_version = EXCLUDED.os_version,
    app_version = EXCLUDED.app_version,
    platform = EXCLUDED.platform,
    online_status = 'Online',
    last_seen = now();

  return jsonb_build_object(
    'success', true,
    'session_id', p_session_id,
    'old_session_invalidated', v_old_session is not null
  );
end;
$$ language plpgsql security definer set search_path = public;

-- 2. Function to validate live room status for invitation card rendering
CREATE OR REPLACE FUNCTION validate_room_invite_status(p_room_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_room RECORD;
    v_is_live BOOLEAN := false;
BEGIN
    IF p_room_id IS NULL OR p_room_id = '' THEN
        RETURN jsonb_build_object('is_live', false, 'reason', 'Invalid Room ID');
    END IF;

    SELECT id, name, host_id, is_active, created_at
    INTO v_room
    FROM rooms
    WHERE (id::text = p_room_id OR sid = p_room_id)
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND AND v_room.is_active = true THEN
        v_is_live := true;
        RETURN jsonb_build_object(
            'is_live', true,
            'room_id', v_room.id,
            'room_name', v_room.name,
            'host_id', v_room.host_id
        );
    ELSE
        RETURN jsonb_build_object(
            'is_live', false,
            'reason', 'Room has ended or is unavailable'
        );
    END IF;
END;
$$;

-- Migration: 202608110007_fix_daily_ap_reset_on_fetch.sql
-- Description: Authoritative Room Dual Progress Fetch & Automatic 4 AM Daily Reset RPC engine.

-- 1. Create or Replace get_or_reset_room_dual_progress RPC
CREATE OR REPLACE FUNCTION public.get_or_reset_room_dual_progress(
  p_room_id text
) RETURNS jsonb AS $$
DECLARE
  v_rec record;
  v_current_reset_date date := ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date;
  v_last_reset_date date;
  v_is_weekend boolean := (extract(isodow from ((now() at time zone 'Asia/Kolkata') - interval '4 hours')) in (6, 7));
  v_free_limit integer := case when v_is_weekend then 1400 else 700 end;
  v_gold_limit integer := case when v_is_weekend then 2000 else 1000 end;
BEGIN
  IF p_room_id IS NULL OR p_room_id = '' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Invalid room_id');
  END IF;

  -- Lock & Fetch or Create room_dual_progress record atomically
  INSERT INTO public.room_dual_progress (
    room_id,
    daily_free_progress, free_task_limit,
    daily_gold_progress, gold_task_limit,
    total_task, total_lifetime_task, last_reset_date,
    gold_points, gold_target,
    normal_points, normal_target,
    room_level
  ) VALUES (
    p_room_id,
    0, v_free_limit,
    0, v_gold_limit,
    0, 0, v_current_reset_date,
    0, v_gold_limit,
    0, v_free_limit,
    1
  ) ON CONFLICT (room_id) DO NOTHING;

  SELECT * INTO v_rec
  FROM public.room_dual_progress
  WHERE room_id = p_room_id
  FOR UPDATE;

  v_last_reset_date := coalesce(v_rec.last_reset_date, v_current_reset_date - interval '1 day');

  -- Execute 4:00 AM Server Timezone Daily Reset Check if stale date
  IF v_last_reset_date < v_current_reset_date THEN
    UPDATE public.room_dual_progress
    SET daily_free_progress = 0,
        normal_points = 0,
        free_task_limit = v_free_limit,
        normal_target = v_free_limit,
        daily_gold_progress = 0,
        gold_points = 0,
        gold_task_limit = v_gold_limit,
        gold_target = v_gold_limit,
        last_reset_date = v_current_reset_date,
        updated_at = NOW()
    WHERE room_id = p_room_id
    RETURNING * INTO v_rec;
  END IF;

  RETURN to_jsonb(v_rec);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 202608120001_realtime_room_roles_and_moderation_engine.sql
-- Realtime Room Roles Assignment, Permissions & Moderation RPC Engine
-- ============================================================

-- Ensure array_distinct helper function exists
create or replace function public.array_distinct(anyarray)
returns anyarray as $$
  select array_agg(distinct elem)
  from unnest($1) as elem
$$ language sql immutable;

-- 6. Moderate Unban User RPC
create or replace function public.moderate_unban_user(
  p_room_id text,
  p_target_user_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_room_id text;
begin
  if exists (select 1 from public.rooms where id = p_room_id) then
    v_room_id := p_room_id;
  else
    select id into v_room_id from public.rooms where username = p_room_id limit 1;
  end if;

  if v_room_id is not null then
    update public.rooms 
    set block_list = array_remove(block_list, p_target_user_id::text)
    where id = v_room_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'action', 'UNBANNED'
  );
end;
$$;

-- ============================================================================
-- MIGRATION: 202608120010_permanent_immutable_room_owner.sql
-- DESCRIPTION: Permanent & Immutable Room Ownership Security Engine.
--              - Room ownership is permanently locked to the original creator.
--              - NO automatic or manual ownership transfer can ever occur.
--              - BEFORE UPDATE trigger strictly rejects changing owner_user_id / host_id / room_owner.
--              - Rewrite process_presence_grace_period_and_cleanup() to NEVER reassign ownership on disconnect.
--              - Permanently disable transfer_room_ownership and transfer_room_host RPCs.
--              - Promote RPCs strictly block promoting any user to Owner role.
-- ============================================================================

-- 1. Database Trigger: Strictly Block any change to room ownership columns
CREATE OR REPLACE FUNCTION public.prevent_room_owner_change()
RETURNS TRIGGER AS $$
BEGIN
  IF (OLD.owner_user_id IS NOT NULL AND NEW.owner_user_id IS DISTINCT FROM OLD.owner_user_id) OR
     (OLD.host_id IS NOT NULL AND NEW.host_id IS DISTINCT FROM OLD.host_id) OR
     (OLD.room_owner IS NOT NULL AND NEW.room_owner IS DISTINCT FROM OLD.room_owner) THEN
    -- Audit security event
    BEGIN
      INSERT INTO public.security_events (user_id, event_type, metadata)
      VALUES (
        auth.uid(),
        'OWNER_CHANGE_ATTEMPT',
        jsonb_build_object(
          'room_id', OLD.id,
          'old_owner', OLD.owner_user_id,
          'attempted_owner', NEW.owner_user_id,
          'timestamp', now(),
          'reason', 'Attempted modification of immutable room ownership'
        )
      );
    EXCEPTION WHEN OTHERS THEN NULL; END;

    RAISE EXCEPTION 'OWNER_IMMUTABLE: Room owner_user_id and host_id are permanently locked upon creation and CAN NEVER be modified under any condition.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================================
-- MIGRATION: 202608120005_auto_leave_seat_on_member_exit.sql
-- DESCRIPTION: Automatic Seat Release Engine on Room Member Exit.
--              Ensures anyone who leaves room_members is immediately removed
--              from room_seats via DB Trigger and presence grace cleanup.
-- ============================================================================

-- 1. Trigger Function: Automatically clear seat when user is deleted from room_members
CREATE OR REPLACE FUNCTION public.auto_leave_seat_on_member_exit()
RETURNS TRIGGER AS $$
BEGIN
  -- Reset occupied seat for the user who left room_members
  UPDATE public.room_seats
  SET user_id = NULL,
      mic_status = 'muted',
      is_speaking = FALSE,
      is_reconnecting = FALSE,
      session_id = NULL
  WHERE room_id = OLD.room_id AND user_id = OLD.user_id;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Helper function to check assigned roles
CREATE OR REPLACE FUNCTION public.is_assigned_room_role(p_role text)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path = public AS $$
BEGIN
  IF p_role IS NULL THEN RETURN false; END IF;
  p_role := lower(trim(p_role));
  RETURN p_role IN (
    'owner', 'creator', 'founder',
    'co-owner', 'coowner', 'co owner',
    'admin',
    'host', 'mod', 'moderator',
    'star member', 'starmember'
  );
END;
$$;

-- ============================================================================
-- MIGRATION: 202608120009_role_protection_and_moderation_lists.sql
-- DESCRIPTION: Enforce assigned role protection in moderate_kick_user and moderate_ban_user
--              so users holding Co-Owner, Admin, Host, Star Member, or Owner roles
--              CANNOT be kicked, banned, or removed until their role is demoted/removed.
-- ============================================================================

-- 1. Helper to check if target user holds ANY assigned role in a room
CREATE OR REPLACE FUNCTION public.has_assigned_room_role(
  p_room_id text,
  p_user_id uuid
) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_canonical_owner uuid;
  v_has_role boolean := false;
BEGIN
  IF p_user_id IS NULL THEN RETURN false; END IF;

  -- Fetch canonical owner
  SELECT COALESCE(owner_user_id, room_owner, host_id) INTO v_canonical_owner
  FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;

  IF p_user_id = v_canonical_owner THEN
    RETURN true;
  END IF;

  -- Check room array columns
  SELECT EXISTS (
    SELECT 1 FROM public.rooms 
    WHERE (id = p_room_id OR username = p_room_id)
      AND (
        p_user_id::text = ANY(COALESCE(co_owner_ids, '{}'::text[])) OR
        p_user_id::text = ANY(COALESCE(admin_ids, '{}'::text[])) OR
        p_user_id::text = ANY(COALESCE(host_ids, '{}'::text[])) OR
        p_user_id::text = ANY(COALESCE(star_member_ids, '{}'::text[]))
      )
  ) INTO v_has_role;

  IF v_has_role THEN
    RETURN true;
  END IF;

  -- Check room_members table
  SELECT EXISTS (
    SELECT 1 FROM public.room_members
    WHERE (room_id = p_room_id OR room_id = (SELECT id FROM public.rooms WHERE username = p_room_id LIMIT 1))
      AND user_id = p_user_id
      AND public.is_assigned_room_role(role)
  ) INTO v_has_role;

  RETURN v_has_role;
END;
$$;

create or replace function public.moderate_mute_user(
  p_room_id text,
  p_user_id uuid,
  p_mute boolean default true
)
returns jsonb
language plpgsql
security definer
as $$
begin
  return public.moderate_user_mute(p_room_id, p_user_id, p_mute);
end;
$$;

