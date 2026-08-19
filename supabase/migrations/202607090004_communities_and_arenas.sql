-- ==========================================================================
-- Consolidated Supabase Migration Module 04: 202607090004_communities_and_arenas.sql
-- Authoritative baseline schema, functions, triggers, policies, and seeds.
-- ==========================================================================

create trigger trigger_sync_community_member_count
before insert or update on public.communities
for each row execute procedure public.sync_community_member_count();

create trigger trigger_enforce_single_official_community
before update on public.communities
for each row execute procedure public.enforce_single_official_community();

create trigger trigger_prevent_official_communities_deletion
before delete on public.communities
for each row execute procedure public.prevent_official_communities_deletion();

-- Seed System User & Official Communities
insert into auth.users (id, email)
values ('00000000-0000-0000-0000-000000000000', 'system@creaniaa.com')
on conflict (id) do nothing;

insert into public.communities (
  id, name, description, category, type, owner, image, banner, is_verified, member_count, members
)
values 
  (
    'comm-connect-005', 
    'Creaniaa Connect', 
    'Meet new people, make friends, chat, voice rooms, and social networking.', 
    'Social', 
    'Official', 
    '00000000-0000-0000-0000-000000000000', 
    '🤝', 
    'https://images.unsplash.com/photo-1522071820081-009f0129c71c', 
    true, 
    0, 
    '{}'
  ),
  (
    'comm-creators-002', 
    'Creaniaa Creators', 
    'Content creators, artists, designers, writers, and creators.', 
    'Education', 
    'Official', 
    '00000000-0000-0000-0000-000000000000', 
    '🎨', 
    'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe', 
    true, 
    0, 
    '{}'
  ),
  (
    'comm-gamers-003', 
    'Creaniaa Gamers', 
    'Gaming, esports, tournaments, and live gaming rooms.', 
    'Gaming', 
    'Official', 
    '00000000-0000-0000-0000-000000000000', 
    '🎮', 
    'https://images.unsplash.com/photo-1538481199705-c710c4e965fc', 
    true, 
    0, 
    '{}'
  ),
  (
    'comm-campus-004', 
    'Creaniaa Campus', 
    'Students, education, study groups, notes, and discussions.', 
    'College', 
    'Official', 
    '00000000-0000-0000-0000-000000000000', 
    '🏫', 
    'https://images.unsplash.com/photo-1523050854058-8df90110c9f1', 
    true, 
    0, 
    '{}'
  ),
  (
    'comm-official-001', 
    'Creaniaa Official', 
    'Official announcements, platform events, updates, and verified activities.', 
    'General', 
    'Official', 
    '00000000-0000-0000-0000-000000000000', 
    '📢', 
    'https://images.unsplash.com/photo-1579546929518-9e396f3cc809', 
    true, 
    0, 
    '{}'
  )
on conflict (id) do update set 
  name = excluded.name, 
  description = excluded.description, 
  type = excluded.type;

-- Realtime registration
do $$
begin
  alter publication supabase_realtime add table public.communities;
exception when others then
  raise notice 'Table communities already in supabase_realtime publication';
end;
$$;

create trigger on_community_membership_change
after update on public.communities
for each row execute procedure public.handle_community_membership_change();

create index if not exists idx_arena_tickets_user_id
  on public.arena_tickets (user_id)
  where is_consumed = false;

-- Users can see only their own tickets
create policy "Users can view their own arena tickets"
  on public.arena_tickets for select
  using (auth.uid() = user_id);

-- Only service_role / admin functions can insert (no direct client inserts)
create policy "Service role can insert arena tickets"
  on public.arena_tickets for insert
  with check (
    -- Only allow if current user is an admin (check admins table) or service role
    exists (
      select 1 from public.admins where id = auth.uid()
    )
  );

-- Users can view their own creation logs
create policy "Users can view their own arena creation logs"
  on public.arena_creation_logs for select
  using (auth.uid() = user_id);

-- Admins can view all
create policy "Admins can view all arena creation logs"
  on public.arena_creation_logs for select
  using (
    exists (select 1 from public.admins where id = auth.uid())
  );

-- 202607170002_community_system.sql
-- StarMaker-inspired Community System backend migrations

-- 1. Alter communities table to include additional preferences and settings
alter table public.communities add column if not exists is_official boolean default false;

alter table public.communities add column if not exists join_mode text default 'auto_join';

-- 'auto_join' or 'approval_required'
alter table public.communities add column if not exists language text default 'en';

alter table public.communities add column if not exists country text default 'IN';

alter table public.communities add column if not exists min_id_level integer default 1;

alter table public.communities add column if not exists preferred_languages text[] default '{}';

alter table public.communities add column if not exists preferred_countries text[] default '{}';

alter table public.communities add column if not exists preferred_interests text[] default '{}';

alter table public.communities add column if not exists tags text[] default '{}';

alter table public.communities add column if not exists visibility text default 'public';

-- 'public' or 'private'

-- Update seeded official communities to be marked is_official = true
update public.communities
set is_official = true,
    is_verified = true
where id in ('comm-official-001','comm-creators-002','comm-gamers-003','comm-campus-004','comm-connect-005') or type = 'Official';

-- Indexing for quick lookups
create index if not exists idx_community_memberships_comm on public.community_memberships(community_id);

-- Ensure owners have a membership entry
insert into public.community_memberships (community_id, user_id, role, join_method)
select c.id, c.owner, 'owner', 'creator'
from public.communities c
on conflict (user_id) do nothing;

drop trigger if exists trigger_on_community_membership_change on public.community_memberships;

create trigger trigger_on_community_membership_change
after insert or update or delete on public.community_memberships
for each row execute procedure public.tr_on_community_membership_change();

-- 202607170003_community_progression.sql
-- StarMaker-inspired Community Level, EXP, Contribution, and Reward system migrations

-- 1. Alter public.communities to add progression columns
alter table public.communities add column if not exists lifetime_exp bigint default 0 not null;

alter table public.communities add column if not exists daily_exp bigint default 0 not null;

alter table public.communities add column if not exists weekly_exp bigint default 0 not null;

alter table public.communities add column if not exists monthly_exp bigint default 0 not null;

alter table public.communities add column if not exists activity_score integer default 0 not null;

alter table public.communities add column if not exists last_exp_reset_at timestamp with time zone default now() not null;

alter table public.communities add column if not exists co_owner_limit integer default 2 not null;

alter table public.communities add column if not exists admin_limit integer default 5 not null;

-- Indexing for daily limits
create index if not exists idx_comm_daily_limits_lookup on public.community_member_daily_limits(community_id, user_id, day);

-- Create Gift history trigger
drop trigger if exists trg_community_gift_exp on public.gift_history;

create trigger trg_community_gift_exp
  after insert on public.gift_history
  for each row execute procedure public.process_community_gift_exp_trigger_fn();

-- Drop trigger if exists
drop trigger if exists trigger_sync_members_on_membership_change on public.community_memberships;

-- Create trigger
create trigger trigger_sync_members_on_membership_change
after insert or update or delete on public.community_memberships
for each row execute procedure public.tr_sync_members_on_membership_change();

-- Seed sync for existing memberships (to populate members arrays immediately)
do $$
declare
  r record;
  v_members text[];
begin
  for r in select id from public.communities loop
    select array_agg(user_id::text) into v_members
    from public.community_memberships
    where community_id = r.id;

    update public.communities
    set members = coalesce(v_members, '{}'::text[])
    where id = r.id;
  end loop;
end;
$$;

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

-- Prepopulate Welcome Rewards for first community join
insert into public.community_rewards (reward_type, amount, cosmetic_id) values
('silver', 500, null),
('gift', 10, 'rose_2star'),
('xp', 50, null),
('badge', 1, 'Welcome Badge')
on conflict do nothing;

drop trigger if exists tr_community_membership_notifications on public.community_memberships;

create trigger tr_community_membership_notifications
  after insert or delete on public.community_memberships
  for each row execute function public.handle_community_membership_notifications();

drop trigger if exists tr_community_applications_notifications on public.community_applications;

create trigger tr_community_applications_notifications
  after insert or update on public.community_applications
  for each row execute function public.handle_community_applications_notifications();

drop trigger if exists tr_community_announcement_notifications on public.community_announcements;

create trigger tr_community_announcement_notifications
  after insert on public.community_announcements
  for each row execute function public.handle_community_announcement_notifications();

drop trigger if exists tr_community_event_notifications on public.community_events;

create trigger tr_community_event_notifications
  after insert on public.community_events
  for each row execute function public.handle_community_event_notifications();

-- Communities & Study Vault optimization
CREATE INDEX IF NOT EXISTS idx_communities_updated ON communities(updated_at DESC);

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

-- Migration: 202608080002_events_table.sql
-- Creates the public.events table for community events/tournaments.
-- Required by EventController in lib/services/community/event_controller.dart

begin;

-- Migration: 202608100001_canonical_arena_events.sql
-- Description: Enforce single canonical Arena activity event pipeline, remove redundant unformatted DB activity inserts in join_room_seat and leave_room_seat.

-- 1. Ensure event_id column exists on room_activity_events table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'room_activity_events'
    AND column_name = 'event_id'
  ) THEN
    ALTER TABLE public.room_activity_events ADD COLUMN event_id text;
  END IF;
END $$;

create index if not exists idx_posts_community_id on public.posts (community_id);

-- Triggers
create or replace function public.sync_community_member_count()
returns trigger as $$
begin
  new.member_count := coalesce(cardinality(new.members), 0);
  return new;
end;
$$ language plpgsql;

create or replace function public.enforce_single_official_community()
returns trigger as $$
declare
  v_user_id text;
  v_comm_row record;
begin
  if new.type = 'Official' and new.members is distinct from old.members then
    select val into v_user_id
    from unnest(new.members) as val
    except
    select val from unnest(old.members) as val
    limit 1;

    if v_user_id is not null then
      if pg_trigger_depth() < 2 then
        for v_comm_row in 
          select id, members 
          from public.communities 
          where type = 'Official' and id <> new.id and v_user_id = any(members)
        loop
          update public.communities
          set members = array_remove(members, v_user_id),
              member_count = greatest(0, member_count - 1)
          where id = v_comm_row.id;
        end loop;
      end if;
    end if;
  end if;
  return new;
end;
$$ language plpgsql;

create or replace function public.prevent_official_communities_deletion()
returns trigger as $$
begin
  if old.type = 'Official' then
    raise exception 'Permanent official system communities cannot be deleted.';
  end if;
  return old;
end;
$$ language plpgsql;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Update update_room_member_counts trigger
--    Remove the temporary-room auto-delete branch.
--    Going forward all Arenas are permanent (is_permanent = true).
--    Permanent Arenas persist even when member count drops to zero.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.update_room_member_counts()
returns trigger as $$
declare
  v_room_id text;
  v_count integer;
begin
  if tg_op = 'INSERT' or tg_op = 'UPDATE' then
    v_room_id := new.room_id;
  else
    v_room_id := old.room_id;
  end if;

  v_count := (select count(*) from public.room_members where room_id = v_room_id);

  -- All Arenas are permanent. Never auto-delete based on member count.
  -- (Temporary room auto-delete has been removed as part of the Arena v2 migration.)
  update public.rooms
  set
    total_members   = v_count,
    total_speakers  = (select count(*) from public.room_members
                       where room_id = v_room_id
                         and role in ('Host', 'Co-Host', 'Speaker')),
    total_listeners = (select count(*) from public.room_members
                       where room_id = v_room_id
                         and role in ('Moderator', 'Listener', 'Guest')),
    peak_members    = greatest(peak_members, v_count)
  where id = v_room_id;

  return null;
end;
$$ language plpgsql security definer;

-- Community searching RPC
create or replace function public.search_communities(p_query text)
returns setof public.communities as $$
begin
  return query
  select * from public.communities
  where name ilike '%' || p_query || '%'
     or description ilike '%' || p_query || '%'
  order by member_count desc;
end;
$$ language plpgsql stable;

create or replace function public.handle_community_membership_change()
returns trigger as $$
declare
  joined_user_id text;
  left_user_id text;
begin
  if new.members is distinct from old.members then
    select val into joined_user_id
    from unnest(new.members) as val
    except
    select val from unnest(old.members) as val
    limit 1;

    if joined_user_id is not null then
      perform public.rebuild_user_tag_system(joined_user_id::uuid);
    end if;

    select val into left_user_id
    from unnest(old.members) as val
    except
    select val from unnest(new.members) as val
    limit 1;

    if left_user_id is not null then
      perform public.rebuild_user_tag_system(left_user_id::uuid);
    end if;
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Helper: count available arena tickets for a user
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.get_arena_ticket_count(p_user_id uuid default null)
returns integer as $$
declare
  v_user_id uuid;
begin
  v_user_id := coalesce(p_user_id, auth.uid());
  if v_user_id is null then
    return 0;
  end if;
  return (
    select count(*)::integer
    from public.arena_tickets
    where user_id = v_user_id
      and is_consumed = false
  );
end;
$$ language plpgsql stable security definer;

-- 11. Process Application RPC Function
create or replace function public.process_application_rpc(
  p_application_id uuid,
  p_action text -- 'approve', 'reject', 'block'
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_app record;
  v_my_role text;
  v_applicant_already_member boolean;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  select * into v_app from public.community_applications where id = p_application_id;
  if v_app is null then
    return jsonb_build_object('success', false, 'error', 'Application not found.');
  end if;

  select role into v_my_role from public.community_memberships where community_id = v_app.community_id and user_id = v_user_id;
  if v_my_role is null or v_my_role not in ('owner', 'co_owner') then
    return jsonb_build_object('success', false, 'error', 'Only owners or co-owners can process applications.');
  end if;

  if p_action = 'approve' then
    -- Check if applicant is already in a community
    select exists (
      select 1 from public.community_memberships where user_id = v_app.user_id
    ) into v_applicant_already_member;
    if v_applicant_already_member then
      update public.community_applications set status = 'rejected', processed_at = now(), processed_by = v_user_id where id = p_application_id;
      return jsonb_build_object('success', false, 'error', 'Applicant is already a member of another community.');
    end if;

    update public.community_applications set status = 'approved', processed_at = now(), processed_by = v_user_id where id = p_application_id;

    insert into public.community_memberships (
      community_id, user_id, role, join_method, joined_by
    ) values (
      v_app.community_id, v_app.user_id, 'member', 'approved', v_user_id
    );

    update public.communities set member_count = coalesce(member_count, 0) + 1 where id = v_app.community_id;

  elsif p_action = 'reject' then
    update public.community_applications set status = 'rejected', processed_at = now(), processed_by = v_user_id where id = p_application_id;

  elsif p_action = 'block' then
    update public.community_applications set status = 'blocked', processed_at = now(), processed_by = v_user_id where id = p_application_id;

  else
    return jsonb_build_object('success', false, 'error', 'Invalid action. Must be approve, reject, or block.');
  end if;

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer set search_path = public;

-- 9. Rewrite manage_member_role_rpc with Level limits
create or replace function public.manage_member_role_rpc(
  p_community_id text,
  p_target_user_id uuid,
  p_role text -- 'owner', 'co_owner', 'admin', 'member', 'kick'
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_my_role text;
  v_target_role text;
  v_comm record;
  v_co_owner_count integer;
  v_admin_count integer;
  v_co_owner_limit integer;
  v_admin_limit integer;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  select role into v_my_role from public.community_memberships where community_id = p_community_id and user_id = v_user_id;
  if v_my_role is null or v_my_role not in ('owner', 'co_owner') then
    return jsonb_build_object('success', false, 'error', 'Only owners or co-owners can manage member roles.');
  end if;

  select role into v_target_role from public.community_memberships where community_id = p_community_id and user_id = p_target_user_id;
  if v_target_role is null then
    return jsonb_build_object('success', false, 'error', 'Target user is not a member of this community.');
  end if;

  if v_target_role = 'owner' then
    return jsonb_build_object('success', false, 'error', 'Cannot change the role of the community owner.');
  end if;

  if v_my_role = 'co_owner' and v_target_role in ('co_owner', 'admin') then
    return jsonb_build_object('success', false, 'error', 'Co-owners cannot change roles of other co-owners or admins.');
  end if;

  select * into v_comm from public.communities where id = p_community_id;

  if p_role = 'kick' then
    delete from public.community_memberships where community_id = p_community_id and user_id = p_target_user_id;
    update public.communities set member_count = greatest(0, member_count - 1) where id = p_community_id;
    return jsonb_build_object('success', true);
  end if;

  -- Limit validations based on Level
  if not v_comm.is_official then
    v_co_owner_limit := case v_comm.level
      when 1 then 2
      when 2 then 3
      when 3 then 4
      when 4 then 5
      when 5 then 6
      when 6 then 8
      when 7 then 10
      else 2
    end;

    v_admin_limit := case v_comm.level
      when 1 then 5
      when 2 then 7
      when 3 then 10
      when 4 then 15
      when 5 then 20
      when 6 then 25
      when 7 then 30
      else 5
    end;

    if p_role = 'co_owner' then
      select count(*) into v_co_owner_count from public.community_memberships where community_id = p_community_id and role = 'co_owner';
      if v_co_owner_count >= v_co_owner_limit then
        return jsonb_build_object('success', false, 'error', 'Co-owner limit reached for this community level (' || v_co_owner_limit || ').');
      end if;
    elsif p_role = 'admin' then
      select count(*) into v_admin_count from public.community_memberships where community_id = p_community_id and role = 'admin';
      if v_admin_count >= v_admin_limit then
        return jsonb_build_object('success', false, 'error', 'Admin limit reached for this community level (' || v_admin_limit || ').');
      end if;
    end if;
  end if;

  update public.community_memberships
  set role = p_role
  where community_id = p_community_id and user_id = p_target_user_id;

  -- Rebuild target tag
  perform public.rebuild_user_tag_system(p_target_user_id);

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer set search_path = public;

-- 13. Transfer Ownership RPC Function
create or replace function public.transfer_community_ownership_rpc(
  p_community_id text,
  p_target_user_id uuid
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_target_role text;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  -- Must be current owner
  if not exists (
    select 1 from public.community_memberships where community_id = p_community_id and user_id = v_user_id and role = 'owner'
  ) then
    return jsonb_build_object('success', false, 'error', 'Only the owner can transfer ownership.');
  end if;

  select role into v_target_role from public.community_memberships where community_id = p_community_id and user_id = p_target_user_id;
  if v_target_role is null then
    return jsonb_build_object('success', false, 'error', 'Target user is not a member of this community.');
  end if;

  -- Perform transfer
  update public.community_memberships set role = 'member' where community_id = p_community_id and user_id = v_user_id;
  update public.community_memberships set role = 'owner' where community_id = p_community_id and user_id = p_target_user_id;
  update public.communities set owner = p_target_user_id where id = p_community_id;

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer set search_path = public;

-- 4. Progression Helper Functions
create or replace function public.get_required_exp_for_level(p_level integer)
returns bigint as $$
begin
  case p_level
    when 1 then return 150000;
    when 2 then return 600000;
    when 3 then return 1600000;
    when 4 then return 3400000;
    when 5 then return 5400000;
    when 6 then return 7900000;
    else return 999999999999; -- Level 7 is max, infinite EXP required
  end case;
end;
$$ language plpgsql immutable;

-- 5. Lazy Reset Function
create or replace function public.check_and_reset_exp_stats(p_community_id text)
returns void as $$
declare
  v_last_reset timestamp with time zone;
  v_now timestamp with time zone := now();
begin
  select last_exp_reset_at into v_last_reset from public.communities where id = p_community_id;
  if v_last_reset is null then
    update public.communities set last_exp_reset_at = v_now where id = p_community_id;
    return;
  end if;

  -- Day change
  if date_trunc('day', v_last_reset) != date_trunc('day', v_now) then
    update public.communities set daily_exp = 0 where id = p_community_id;
  end if;

  -- Week change (ISO standard week)
  if date_trunc('week', v_last_reset) != date_trunc('week', v_now) then
    update public.communities set weekly_exp = 0 where id = p_community_id;
  end if;

  -- Month change
  if date_trunc('month', v_last_reset) != date_trunc('month', v_now) then
    update public.communities set monthly_exp = 0 where id = p_community_id;
  end if;

  update public.communities set last_exp_reset_at = v_now where id = p_community_id;
end;
$$ language plpgsql security definer;

-- 6. Core EXP adding procedure
create or replace function public.add_community_exp_rpc(
  p_community_id text,
  p_user_id uuid,
  p_source_type text, -- 'normal', 'gold_gift', 'star_gift'
  p_amount integer,
  p_reference_id text default null
)
returns jsonb as $$
declare
  v_is_member boolean;
  v_limit_record record;
  v_allowed_exp integer := 0;
  v_current_exp bigint;
  v_current_level integer;
  v_next_level_required bigint;
  v_new_level integer;
  v_new_xp bigint;
  v_co_limit integer;
  v_adm_limit integer;
begin
  -- Authentication check is not strictly needed for system triggers but good for RPC direct calls
  if p_user_id is null then
    return jsonb_build_object('success', false, 'error', 'User ID is required.');
  end if;

  -- Verify membership
  select exists (
    select 1 from public.community_memberships 
    where community_id = p_community_id and user_id = p_user_id
  ) into v_is_member;

  if not v_is_member then
    return jsonb_build_object('success', false, 'error', 'User is not a member of this community.');
  end if;

  -- Lazy Reset stats
  perform public.check_and_reset_exp_stats(p_community_id);

  -- Load/Create daily limits
  insert into public.community_member_daily_limits (community_id, user_id, day, normal_exp, gold_gift_exp, star_gift_exp)
  values (p_community_id, p_user_id, current_date, 0, 0, 0)
  on conflict (community_id, user_id, day) do nothing;

  select normal_exp, gold_gift_exp, star_gift_exp into v_limit_record
  from public.community_member_daily_limits
  where community_id = p_community_id and user_id = p_user_id and day = current_date;

  -- Calculate allowed EXP based on source type and caps
  if p_source_type = 'normal' then
    v_allowed_exp := least(p_amount, 250 - v_limit_record.normal_exp);
    if v_allowed_exp > 0 then
      update public.community_member_daily_limits
      set normal_exp = normal_exp + v_allowed_exp
      where community_id = p_community_id and user_id = p_user_id and day = current_date;
    end if;
  elsif p_source_type = 'gold_gift' then
    v_allowed_exp := least(p_amount, 2500 - v_limit_record.gold_gift_exp);
    if v_allowed_exp > 0 then
      update public.community_member_daily_limits
      set gold_gift_exp = gold_gift_exp + v_allowed_exp
      where community_id = p_community_id and user_id = p_user_id and day = current_date;
    end if;
  elsif p_source_type = 'star_gift' then
    v_allowed_exp := least(p_amount, 2000 - v_limit_record.star_gift_exp);
    if v_allowed_exp > 0 then
      update public.community_member_daily_limits
      set star_gift_exp = star_gift_exp + v_allowed_exp
      where community_id = p_community_id and user_id = p_user_id and day = current_date;
    end if;
  else
    return jsonb_build_object('success', false, 'error', 'Invalid source type.');
  end if;

  if v_allowed_exp <= 0 then
    return jsonb_build_object('success', true, 'exp_added', 0, 'reason', 'Daily limit reached for this source.');
  end if;

  -- Log transaction
  insert into public.community_exp_transactions (community_id, user_id, source_type, amount, reference_id)
  values (p_community_id, p_user_id, p_source_type, v_allowed_exp, p_reference_id);

  -- Fetch current level and xp
  select level, xp into v_current_level, v_current_exp from public.communities where id = p_community_id;
  if v_current_level is null then v_current_level := 1; end if;
  if v_current_exp is null then v_current_exp := 0; end if;

  -- Update community EXP stats
  update public.communities
  set xp = xp + v_allowed_exp,
      lifetime_exp = lifetime_exp + v_allowed_exp,
      daily_exp = daily_exp + v_allowed_exp,
      weekly_exp = weekly_exp + v_allowed_exp,
      monthly_exp = monthly_exp + v_allowed_exp,
      activity_score = activity_score + greatest(1, v_allowed_exp / 10)
  where id = p_community_id;

  -- Update user contribution in community memberships
  update public.community_memberships
  set contribution = contribution + v_allowed_exp,
      exp_contribution = exp_contribution + v_allowed_exp,
      activity_score = activity_score + greatest(1, v_allowed_exp / 10),
      last_active_at = now()
  where community_id = p_community_id and user_id = p_user_id;

  -- Evaluate progression / level up
  v_new_level := v_current_level;
  v_new_xp := v_current_exp + v_allowed_exp;

  loop
    exit when v_new_level >= 7;
    v_next_level_required := public.get_required_exp_for_level(v_new_level);
    if v_new_xp >= v_next_level_required then
      v_new_level := v_new_level + 1;
    else
      exit;
    end if;
  end loop;

  -- Update level if changed
  if v_new_level != v_current_level then
    -- Determine role limits for new level
    case v_new_level
      when 1 then v_co_limit := 2; v_adm_limit := 5;
      when 2 then v_co_limit := 3; v_adm_limit := 7;
      when 3 then v_co_limit := 4; v_adm_limit := 10;
      when 4 then v_co_limit := 5; v_adm_limit := 15;
      when 5 then v_co_limit := 6; v_adm_limit := 20;
      when 6 then v_co_limit := 8; v_adm_limit := 25;
      when 7 then v_co_limit := 10; v_adm_limit := 30;
      else v_co_limit := 2; v_adm_limit := 5;
    end case;

    update public.communities
    set level = v_new_level,
        co_owner_limit = v_co_limit,
        admin_limit = v_adm_limit
    where id = p_community_id;

    -- Sync community tag style properties
    perform public.sync_community_tags(p_community_id);
  end if;

  return jsonb_build_object(
    'success', true, 
    'exp_added', v_allowed_exp, 
    'new_level', v_new_level,
    'new_xp', v_new_xp
  );
end;
$$ language plpgsql security definer;

-- 7. Community Check-In RPC Function
create or replace function public.check_in_community_rpc(p_community_id text)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_res jsonb;
  v_already_checked boolean;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  -- Verify membership
  if not exists (
    select 1 from public.community_memberships
    where community_id = p_community_id and user_id = v_user_id
  ) then
    return jsonb_build_object('success', false, 'error', 'You must join this community first to check in.');
  end if;

  -- Verify they haven't checked in today yet
  select exists (
    select 1 from public.community_exp_transactions
    where community_id = p_community_id
      and user_id = v_user_id
      and source_type = 'normal'
      and reference_id = 'check_in_' || current_date::text
  ) into v_already_checked;

  if v_already_checked then
    return jsonb_build_object('success', false, 'error', 'You have already checked in today.');
  end if;

  -- Award 50 EXP (normal daily task EXP)
  select public.add_community_exp_rpc(p_community_id, v_user_id, 'normal', 50, 'check_in_' || current_date::text) into v_res;

  return v_res;
end;
$$ language plpgsql security definer;

-- 8. Gift Hook Trigger Function (Implements Gift rules 1 to 5)
create or replace function public.process_community_gift_exp_trigger_fn()
returns trigger as $$
declare
  v_gifter_comm_id text;
  v_receiver_comm_id text;
  v_gold_reward integer;
  v_star_reward integer;
begin
  -- Prevent self gifting abuse
  if NEW.sender_id = NEW.receiver_id then
    return NEW;
  end if;

  -- Fetch gifter community
  select community_id into v_gifter_comm_id from public.community_memberships where user_id = NEW.sender_id limit 1;

  -- Fetch receiver community
  select community_id into v_receiver_comm_id from public.community_memberships where user_id = NEW.receiver_id limit 1;

  -- Calculate rewards
  v_gold_reward := round(coalesce(NEW.coins_value, 0) * 1.25);
  v_star_reward := round(coalesce(NEW.coins_value, 0) / 3.0);

  if v_gifter_comm_id is not null and v_receiver_comm_id is not null then
    if v_gifter_comm_id = v_receiver_comm_id then
      -- Rule 4: Same community -> Grant Gold Gift Bonus once (no double counting)
      if v_gold_reward > 0 then
        perform public.add_community_exp_rpc(v_gifter_comm_id, NEW.sender_id, 'gold_gift', v_gold_reward, NEW.id::text);
      end if;
    else
      -- Rule 3: Different communities -> Both receive their own bonus
      if v_gold_reward > 0 then
        perform public.add_community_exp_rpc(v_gifter_comm_id, NEW.sender_id, 'gold_gift', v_gold_reward, NEW.id::text);
      end if;
      if v_star_reward > 0 then
        perform public.add_community_exp_rpc(v_receiver_comm_id, NEW.receiver_id, 'star_gift', v_star_reward, NEW.id::text);
      end if;
    end if;
  elsif v_gifter_comm_id is not null then
    -- Rule 1: Gifter community only
    if v_gold_reward > 0 then
      perform public.add_community_exp_rpc(v_gifter_comm_id, NEW.sender_id, 'gold_gift', v_gold_reward, NEW.id::text);
    end if;
  elsif v_receiver_comm_id is not null then
    -- Rule 2: Receiver community only
    if v_star_reward > 0 then
      perform public.add_community_exp_rpc(v_receiver_comm_id, NEW.receiver_id, 'star_gift', v_star_reward, NEW.id::text);
    end if;
  end if;

  return NEW;
end;
$$ language plpgsql security definer;

-- 202607170005_community_sync_members.sql
-- Trigger to keep public.communities.members array and member_count in perfect sync with public.community_memberships

create or replace function public.tr_sync_members_on_membership_change()
returns trigger as $$
declare
  v_comm_id text;
  v_members text[];
begin
  if tg_op = 'INSERT' then
    v_comm_id := new.community_id;
  elsif tg_op = 'UPDATE' then
    v_comm_id := new.community_id;
  elsif tg_op = 'DELETE' then
    v_comm_id := old.community_id;
  end if;

  if v_comm_id is not null then
    -- Select all user_ids as text array for this community
    select array_agg(user_id::text) into v_members
    from public.community_memberships
    where community_id = v_comm_id;

    -- Update public.communities members array
    update public.communities
    set members = coalesce(v_members, '{}'::text[])
    where id = v_comm_id;
  end if;

  return null;
end;
$$ language plpgsql security definer set search_path = public;

-- 11. Community Announcements Notifications
create or replace function public.handle_community_announcement_notifications()
returns trigger as $$
declare
  v_community_name text;
begin
  select name into v_community_name from public.communities where id = new.community_id;
  if (v_community_name is null) then
    v_community_name := 'Community';
  end if;

  -- Notify all community members
  insert into public.notifications (user_id, title, body, type, payload)
  select 
    user_id,
    'Community Announcement 📢',
    '"' || v_community_name || '": ' || new.title,
    'community',
    jsonb_build_object(
      'communityId', new.community_id,
      'announcementId', new.id,
      'action', 'announcement'
    )
  from public.community_memberships
  where community_id = new.community_id;

  return null;
end;
$$ language plpgsql security definer set search_path = public;

-- 12. Community Events Notifications
create or replace function public.handle_community_event_notifications()
returns trigger as $$
declare
  v_community_name text;
begin
  select name into v_community_name from public.communities where id = new.community_id;
  if (v_community_name is null) then
    v_community_name := 'Community';
  end if;

  -- Notify all community members
  insert into public.notifications (user_id, title, body, type, payload)
  select 
    user_id,
    'New Community Event 🗓️',
    '"' || v_community_name || '" created event: ' || new.name,
    'community',
    jsonb_build_object(
      'communityId', new.community_id,
      'eventId', new.id,
      'action', 'event'
    )
  from public.community_memberships
  where community_id = new.community_id;

  return null;
end;
$$ language plpgsql security definer set search_path = public;

-- 2. Permanently Disable Ownership Transfer RPCs
CREATE OR REPLACE FUNCTION public.transfer_room_ownership(
  p_room_id text,
  p_new_owner_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RAISE EXCEPTION 'OWNERSHIP_TRANSFER_DISABLED: Room ownership transfer is permanently disabled in Creania Arena.';
END;
$$;

-- 202608070008_creania_daily_task_reset_cron.sql
-- Creania Arena Daily Task 04:00 AM IST Reset RPC & Automated pg_cron Schedule

-- 1. Reset Function RPC (Resets daily progress, preserves total XP & Levels)
create or replace function public.reset_room_daily_tasks()
returns void as $$
declare
  v_today date := ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date;
begin
  -- 1. Reset daily room statistics (today_room_xp, today_visitors, etc.)
  -- Total room_xp and current_level in public.rooms & public.room_level_progress are PERMANENTLY PRESERVED!
  update public.rooms
  set today_room_xp = 0;

  update public.room_statistics
  set today_visitors = 0,
      today_silver_coins = 0,
      today_gold_coins = 0,
      today_task_points = 0,
      today_extra_xp_points = 0,
      updated_at = now();

  -- 2. Reset seat daily gift counters
  update public.room_seat_gifts
  set silver_gift_count = 0,
      gold_gift_count = 0,
      updated_at = now();

  -- 3. Clear old day task progress entries so new date begins fresh at 04:00 AM IST
  delete from public.user_daily_task_progress
  where task_date < v_today;

  delete from public.room_team_task_progress
  where task_date < v_today;

  raise notice 'Creania Daily Room Tasks reset successfully for date % at 04:00 AM IST', v_today;
end;
$$ language plpgsql security definer;

CREATE OR REPLACE FUNCTION public.transfer_room_host(
  p_room_id text,
  p_new_host_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RAISE EXCEPTION 'OWNERSHIP_TRANSFER_DISABLED: Room ownership transfer is permanently disabled in Creania Arena.';
END;
$$;

