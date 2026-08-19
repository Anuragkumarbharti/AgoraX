-- ==========================================================================
-- Consolidated Supabase Migration Module 03: 202607090003_store_plans_and_inventory.sql
-- Authoritative baseline schema, functions, triggers, policies, and seeds.
-- ==========================================================================

-- 202607090003_store_and_inventory.sql
-- Store cosmetic items, user inventories, and RLS policies

create table public.store_items (
  id text primary key,
  name text not null,
  description text,
  category text not null check (category in ('Cosmetic', 'Frame', 'Bubble', 'VirtualGift')),
  price_coins integer not null check (price_coins >= 0),
  price_inr numeric(10, 2) not null check (price_inr >= 0.00),
  is_active boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 202607090004_plans_and_purchases.sql
-- VIP / Novel plans, user purchase ledger entries, and RLS policies

create table public.vip_plans (
  id text primary key,
  vip_level integer not null check (vip_level between 1 and 7),
  duration text not null,
  price_inr numeric(10, 2) not null check (price_inr >= 0.00),
  price_coins integer not null check (price_coins >= 0)
);

create table public.novel_plans (
  id text primary key,
  novel_level integer not null check (novel_level between 1 and 7),
  duration text not null,
  price_inr numeric(10, 2) not null check (price_inr >= 0.00),
  price_coins integer not null check (price_coins >= 0)
);

-- 202607090019_vip_novel_system.sql
-- Backend Driven VIP & Novel Membership, Plans, Assets, and Purchases

-- 1. Create tables
drop table if exists public.vip_plans cascade;

drop table if exists public.novel_plans cascade;

create table public.vip_plans (
  id serial primary key,
  level int unique not null,
  name text not null,
  base_price_inr numeric not null,
  benefits text[] not null
);

create table public.novel_plans (
  id serial primary key,
  level int unique not null,
  name text not null,
  base_price_inr numeric not null,
  benefits text[] not null
);

create table if not exists public.vip_assets (
  asset_id uuid default gen_random_uuid() primary key,
  asset_type text not null,
  asset_url text not null,
  animation_type text,
  rarity text,
  level_required int references public.vip_plans(level) on delete cascade not null,
  enabled boolean default true not null,
  display_priority int default 0 not null
);

create table if not exists public.novel_assets (
  asset_id uuid default gen_random_uuid() primary key,
  asset_type text not null,
  asset_url text not null,
  animation_type text,
  rarity text,
  level_required int references public.novel_plans(level) on delete cascade not null,
  enabled boolean default true not null,
  display_priority int default 0 not null
);

-- Setup RLS policies
create policy "Allow select plans for authenticated users" on public.vip_plans for select using (auth.role() = 'authenticated');

-- 4. Create Unified Cosmetic Assets Table
drop table if exists public.cosmetic_assets cascade;

-- 5. Create Unified Inventory Table
drop table if exists public.inventory cascade;

-- 6. Create Subscriptions Table
drop table if exists public.subscriptions cascade;

drop trigger if exists tr_on_subscription_change on public.subscriptions;

drop trigger if exists tr_on_purchase_complete on public.purchases;

drop function if exists public.on_subscription_change() cascade;

drop function if exists public.on_purchase_complete() cascade;

create trigger tr_on_subscription_change
after insert or update on public.subscriptions
for each row execute function public.on_subscription_change();

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

-- 202607170012_creania_vault_system.sql

-- 1. Create asset_definitions table first
create table if not exists public.asset_definitions (
  id uuid default gen_random_uuid() primary key,
  category text not null check (category in ('Premium', 'Cosmetics', 'Effects', 'Tickets', 'Coupons', 'Boxes', 'Currency Packs', 'Collectibles', 'General', 'VIP', 'Novel', 'Community')),
  sub_category text not null,
  display_name text not null,
  short_description text,
  long_description text,
  thumbnail_url text,
  animation_url text,
  preview_url text,
  rarity text default 'Common' not null check (rarity in ('Common', 'Rare', 'Epic', 'Legendary', 'Mythic')),
  level_requirement integer default 0 not null,
  vip_requirement integer default 0 not null,
  creator_requirement boolean default false not null,
  tradable boolean default false not null,
  giftable boolean default true not null,
  marketable boolean default false not null,
  stackable boolean default true not null,
  consumable boolean default false not null,
  permanent boolean default true not null,
  duration_seconds bigint,
  auto_activate boolean default false not null,
  cooldown_seconds integer,
  custom_properties jsonb default '{}'::jsonb not null,
  enabled boolean default true not null,
  priority integer default 0 not null,
  visibility text default 'Public' not null check (visibility in ('Public', 'Hidden')),
  created_at timestamp with time zone default now() not null
);

-- 2. Populate asset_definitions from legacy cosmetic_assets if it exists
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'cosmetic_assets') then
    insert into public.asset_definitions (
      id, display_name, category, sub_category, thumbnail_url, preview_url, animation_url,
      level_requirement, vip_requirement, enabled, priority, visibility, permanent, created_at
    )
    select
      asset_id,
      name,
      category,
      type,
      thumbnail_url,
      preview_url,
      animation_url,
      required_level,
      case when required_membership = 'VIP' then 1 else 0 end,
      enabled,
      priority,
      visibility,
      case when expiry_rule = 'Permanent' then true else false end,
      created_at
    from public.cosmetic_assets
    on conflict (id) do nothing;
  end if;
end;
$$;

-- 4. Populate vault_items from legacy inventory if it exists
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'inventory') then
    insert into public.vault_items (
      id, user_id, asset_id, quantity, status, purchase_source, purchase_date, expires_at, is_equipped, last_equipped_at
    )
    select
      id,
      user_id,
      asset_id,
      1,
      case when status = 'Active' then 'Activated'::text else 'Expired'::text end,
      purchase_source,
      purchase_date,
      expires_at,
      is_equipped,
      last_equipped_at
    from public.inventory
    on conflict (user_id, asset_id) do update set
      status = EXCLUDED.status,
      expires_at = EXCLUDED.expires_at,
      is_equipped = EXCLUDED.is_equipped,
      last_equipped_at = EXCLUDED.last_equipped_at;
  end if;
end;
$$;

-- 6. Setup Backward Compatibility views
-- Drop old tables and recreate them as views
drop table if exists public.inventory cascade;

-- A. cosmetic_assets View
create or replace view public.cosmetic_assets as
select
  id as asset_id,
  display_name as name,
  sub_category as type,
  category,
  1 as version,
  coalesce(thumbnail_url, '') as cdn_url,
  preview_url,
  thumbnail_url,
  animation_url,
  case when vip_requirement > 0 then 'VIP'::text else 'None'::text end as required_membership,
  level_requirement as required_level,
  enabled,
  priority,
  visibility,
  case when permanent then 'Permanent'::text else 'Rental'::text end as expiry_rule,
  created_at
from public.asset_definitions;

-- C. inventory View
create or replace view public.inventory as
select 
  id,
  user_id,
  asset_id,
  coalesce(purchase_source, 'Purchase') as purchase_source,
  purchase_date,
  expires_at,
  case when status in ('Activated', 'Unlocked') then 'Active'::text else 'Expired'::text end as status,
  is_equipped,
  last_equipped_at
from public.vault_items;

create trigger inventory_view_trigger
instead of insert or update or delete on public.inventory
for each row execute function public.sync_inventory_view_to_vault();

grant execute on function public.purchase_vip_subscription(uuid, int, int) to authenticated;

grant execute on function public.purchase_novel_subscription(uuid, int, int) to authenticated;

-- 202607230004_permanent_room_permissions.sql
-- StarMaker style Permanent Room & Role Permission System updates

-- 1. Add settings & configuration columns to rooms if they do not exist
alter table public.rooms
  add column if not exists join_policy text default 'Everyone' check (join_policy in ('Everyone', 'Followers Only', 'VIP Members Only', 'Community Members Only', 'Owner Following Only', 'Invite Only', 'Password Protected')),
  add column if not exists seat_request_mode text default 'Everyone' check (seat_request_mode in ('Everyone', 'Followers Only', 'VIP Only', 'Community Members Only', 'Friends Only', 'Disabled')),
  add column if not exists chat_permission_mode text default 'Everyone' check (chat_permission_mode in ('Everyone', 'Followers Only', 'VIP Only', 'Community Members Only', 'Seat Members Only', 'Admins Only', 'Owner Only', 'Chat Disabled')),
  add column if not exists gift_permission_mode text default 'Everyone' check (gift_permission_mode in ('Everyone', 'Followers Only', 'VIP Only', 'Community Members Only')),
  add column if not exists invite_permission_mode text default 'Everyone' check (invite_permission_mode in ('Everyone', 'Admin and Above', 'Co Owner and Owner', 'Owner Only')),
  add column if not exists entry_notification_mode text default 'Everyone' check (entry_notification_mode in ('Everyone', 'VIP Only', 'Nobility Only', 'Hosts and Admins Only', 'Disabled'));

-- 202607250002_add_asset_columns_to_user_customizations.sql
-- Add asset_id and path columns to user_customizations table for tracking equipped cosmetic details

alter table public.user_customizations 
  add column if not exists asset_id uuid,
  add column if not exists path text;

grant execute on function public.get_user_full_inventory_and_entitlements_rpc(uuid) to authenticated;

-- 202607250008_atomic_equip_item_rpc.sql
-- Atomic equip/unequip item RPC (prevents race conditions from separate update + upsert)
-- Also adds missing index for fast equipped-item lookups

-- Ensure unique constraint for equipped item per category per user exists
do $$
begin
  if not exists (
    select 1 from pg_index i join pg_class c on c.oid = i.indexrelid
    where c.relname = 'idx_user_customizations_single_equipped'
  ) then
    create unique index idx_user_customizations_single_equipped
      on public.user_customizations (user_id, type) where is_equipped = true;
  end if;
end $$;

grant execute on function public.equip_item_rpc(uuid, text, text, text, text) to authenticated, service_role;

grant execute on function public.unequip_item_rpc(uuid, text) to authenticated, service_role;

-- ============================================================
-- 2. Unique partial index: one equipped item per (user_id, category)
-- ============================================================
do $body$
begin
  if not exists (
    select 1 from pg_index i join pg_class c on c.oid = i.indexrelid
    where c.relname = 'idx_uc_single_equipped_v2'
  ) then
    drop index if exists public.idx_user_customizations_single_equipped;
    create unique index idx_uc_single_equipped_v2
      on public.user_customizations (user_id, type)
      where is_equipped = true;
  end if;
end $body$;

grant execute on function public._log_equip_step(uuid,text,text,text,text,jsonb,text)
  to authenticated, service_role;

grant execute on function public.equip_item_rpc(uuid,text,text,text,text) to authenticated, service_role;

grant execute on function public.purchase_and_activate_rpc(uuid,text,text,numeric,numeric,text,text,text,text)
  to authenticated, service_role;

-- ============================================================
-- 6. Ensure subscriptions unique constraint (needed for ON CONFLICT)
-- ============================================================
do $body$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'subscriptions_user_membership_unique'
      and conrelid = 'public.subscriptions'::regclass
  ) then
    alter table public.subscriptions
      add constraint subscriptions_user_membership_unique unique (user_id, membership_type);
  end if;
exception when others then null;
end $body$;

﻿-- 202607250011_add_missing_unique_constraints.sql
-- Safe idempotent migration: adds all unique constraints needed for ON CONFLICT clauses
-- Apply via Supabase Dashboard > SQL Editor

-- 1. user_customizations (user_id, type, name) — needed for equip ON CONFLICT
do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'user_customizations_user_id_type_name_key'
      and conrelid = 'public.user_customizations'::regclass
  ) then
    alter table public.user_customizations
      add constraint user_customizations_user_id_type_name_key unique (user_id, type, name);
  end if;
exception when others then null;
end $$;

-- 2. subscriptions (user_id, membership_type) — needed for VIP/Novel upserts
do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conname in ('subscriptions_user_id_membership_type_key', 'subscriptions_user_membership_unique')
      and conrelid = 'public.subscriptions'::regclass
  ) then
    alter table public.subscriptions
      add constraint subscriptions_user_id_membership_type_key unique (user_id, membership_type);
  end if;
exception when others then null;
end $$;

do $$ begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'user_customizations' and c.relkind = 'r') then
    if not exists (select 1 from pg_constraint where conname = 'user_customizations_user_id_type_name_key') then
      begin
        alter table public.user_customizations add constraint user_customizations_user_id_type_name_key unique (user_id, type, name);
      exception when others then null; end;
    end if;
  end if;
end $$;

do $$ begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'inventory' and c.relkind = 'r') then
    if not exists (select 1 from pg_constraint where conname = 'inventory_user_id_asset_id_key') then
      begin
        alter table public.inventory add constraint inventory_user_id_asset_id_key unique (user_id, asset_id);
      exception when others then null; end;
    end if;
  end if;
end $$;

do $$ begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'user_vip' and c.relkind = 'r') then
    if not exists (select 1 from pg_constraint where conname = 'user_vip_pkey' or conname = 'user_vip_user_id_key') then
      begin
        alter table public.user_vip add constraint user_vip_user_id_key unique (user_id);
      exception when others then null; end;
    end if;
  end if;
end $$;

do $$ begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'user_novel' and c.relkind = 'r') then
    if not exists (select 1 from pg_constraint where conname = 'user_novel_pkey' or conname = 'user_novel_user_id_key') then
      begin
        alter table public.user_novel add constraint user_novel_user_id_key unique (user_id);
      exception when others then null; end;
    end if;
  end if;
end $$;

grant execute on function public.purchase_and_activate_rpc(uuid,text,text,numeric,numeric,text,text,text,text) to authenticated, service_role;

grant execute on function public.purchase_item_with_coins_rpc(uuid,text,text,int,text) to authenticated, service_role;

grant execute on function public.recompute_user_entitlements(uuid) to authenticated, service_role;

grant execute on function public.get_user_full_inventory_and_entitlements_rpc(uuid) to authenticated, service_role;

ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS vip_requirement int DEFAULT 0;

-- Seed Level Matrix (Levels 1 to 7)
insert into public.room_level_matrix 
  (level, required_vp, max_co_owners, max_admins, max_host_seats, has_room_music, has_showcase_badge, has_permanent_chat_bubble, title, description)
values
  (1, 0, 1, 4, 4, true, false, false, 'Basic Arena', 'Basic background, basic announcement, normal daily tasks, arena music'),
  (2, 35500, 1, 7, 6, true, false, false, 'Premium Arena', 'Premium background, welcome banner, arena statistics, arena music'),
  (3, 59500, 2, 11, 8, true, true, false, 'Animated Arena', 'Animated arena frame, gift wall, showcase badge, arena music'),
  (4, 95000, 2, 14, 11, true, true, false, 'Dynamic Arena', 'Dynamic background, premium arena effects, event scheduler, arena music'),
  (5, 490000, 3, 16, 13, true, true, true, 'Official Arena', 'GRAND PRIZE: 2,000 Gold Coins + VIP 2 (60 Days)! Official badge, permanent chat bubble, analytics, arena music'),
  (6, 940000, 3, 18, 14, true, true, true, 'Luxury Arena', 'GRAND PRIZE: 5,000 Gold Coins + VIP 2 (6 Months)! Luxury theme, animated entry, VIP features, arena music'),
  (7, 1590000, 3, 20, 15, true, true, true, 'Legendary Arena', 'GRAND PRIZE: 12,000 Gold Coins + VIP 3 (1 Year)! Legendary crown, exclusive backgrounds, official recommendation, arena music')
on conflict (level) do update set
  required_vp = excluded.required_vp,
  max_co_owners = excluded.max_co_owners,
  max_admins = excluded.max_admins,
  max_host_seats = excluded.max_host_seats,
  has_room_music = excluded.has_room_music,
  has_showcase_badge = excluded.has_showcase_badge,
  has_permanent_chat_bubble = excluded.has_permanent_chat_bubble,
  title = excluded.title,
  description = excluded.description;

-- Ensure column compatibility / aliases
alter table public.room_dual_progress add column if not exists gold_xp integer generated always as (gold_points) stored;

alter table public.room_dual_progress add column if not exists normal_ap integer generated always as (normal_points) stored;

-- 3. Seed 35 New Gifts with Valid Hex UUIDs
-- 🥈 Tier 1 (15 Gifts: 3 Silver, 12 Gold)
INSERT INTO public.gift_catalog (id, category_id, name, icon, cost_stars, currency, rarity, is_active, is_magic) VALUES
-- Silver (3)
('f1000001-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'Rose', '🌹', 100, 'silver', 'Common', true, false),
('f1000001-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001', 'Heart', '❤️', 300, 'silver', 'Common', true, false),
('f1000001-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000001', 'Coffee', '☕', 800, 'silver', 'Common', true, false),
-- Gold (12)
('f1000001-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000001', 'Sakura', '🌸', 2, 'gold', 'Common', true, true), -- Lucky 1
('f1000001-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000001', 'Lucky Star', '⭐', 2, 'gold', 'Common', true, false),
('f1000001-0000-0000-0000-000000000006', 'c1000000-0000-0000-0000-000000000001', 'Chocolate', '🍫', 4, 'gold', 'Common', true, false),
('f1000001-0000-0000-0000-000000000007', 'c1000000-0000-0000-0000-000000000001', 'Balloon', '🎈', 4, 'gold', 'Common', true, false),
('f1000001-0000-0000-0000-000000000008', 'c1000000-0000-0000-0000-000000000001', 'Cake', '🍰', 5, 'gold', 'Common', true, false),
('f1000001-0000-0000-0000-000000000009', 'c1000000-0000-0000-0000-000000000001', 'Butterfly', '🦋', 5, 'gold', 'Common', true, false),
('f1000001-0000-0000-0000-000000000010', 'c1000000-0000-0000-0000-000000000001', 'Love Letter', '💌', 8, 'gold', 'Common', true, false),
('f1000001-0000-0000-0000-000000000011', 'c1000000-0000-0000-0000-000000000001', 'Gift Box', '🎁', 9, 'gold', 'Common', true, true), -- Lucky 2 (Updated to 9 Gold)
('f1000001-0000-0000-0000-000000000012', 'c1000000-0000-0000-0000-000000000001', 'Teddy', '🧸', 9, 'gold', 'Common', true, false), -- Updated to 9 Gold
('f1000001-0000-0000-0000-000000000013', 'c1000000-0000-0000-0000-000000000001', 'Lucky Clover', '🍀', 15, 'gold', 'Common', true, false),
('f1000001-0000-0000-0000-000000000014', 'c1000000-0000-0000-0000-000000000001', 'Moon', '🌙', 19, 'gold', 'Rare', true, false),
('f1000001-0000-0000-0000-000000000015', 'c1000000-0000-0000-0000-000000000001', 'Sunshine', '☀️', 19, 'gold', 'Rare', true, false),

-- 🥇 Tier 2 (7 Gifts: 2 Silver, 5 Gold)
-- Silver (2)
('f1000002-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000002', 'Bouquet', '💐', 2000, 'silver', 'Rare', true, false),
('f1000002-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000002', 'Birthday Cake', '🎂', 5000, 'silver', 'Rare', true, false),
-- Gold (5)
('f1000002-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000002', 'Diamond Ring', '💍', 29, 'gold', 'Epic', true, true), -- Lucky 3
('f1000002-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000002', 'Crown', '👑', 49, 'gold', 'Epic', true, false),
('f1000002-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000002', 'Golden Mic', '🎤', 79, 'gold', 'Epic', true, false),
('f1000002-0000-0000-0000-000000000006', 'c1000000-0000-0000-0000-000000000002', 'Champion Trophy', '🏆', 119, 'gold', 'Epic', true, true), -- Lucky 4
('f1000002-0000-0000-0000-000000000007', 'c1000000-0000-0000-0000-000000000002', 'Crystal Diamond', '💎', 149, 'gold', 'Epic', true, false),

-- 👑 Tier 3 (5 Gifts: 1 Silver, 4 Gold)
-- Silver (1)
('f1000003-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000003', 'Fireworks', '🎆', 10000, 'silver', 'Legendary', true, false),
-- Gold (4)
('f1000003-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000003', 'Super Car', '🏎️', 299, 'gold', 'Legendary', true, true), -- Lucky 5
('f1000003-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000003', 'Rocket', '🚀', 499, 'gold', 'Legendary', true, false),
('f1000003-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000003', 'Private Jet', '✈️', 799, 'gold', 'Legendary', true, false),
('f1000003-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000003', 'Treasure Chest', '💰', 999, 'gold', 'Legendary', true, false),

-- 💎 Tier 4 (4 Gifts: 0 Silver, 4 Gold)
('f1000004-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000004', 'Golden Dragon', '🐉', 1999, 'gold', 'Mythic', true, true), -- Lucky 6
('f1000004-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000004', 'Phoenix', '🔥', 2999, 'gold', 'Mythic', true, false),
('f1000004-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000004', 'Galaxy Portal', '🌌', 4499, 'gold', 'Mythic', true, false),
('f1000004-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000004', 'Crystal Castle', '🏰', 6999, 'gold', 'Mythic', true, false),

-- ⚡ Tier 5 (4 Gifts: 0 Silver, 4 Gold)
('f1000005-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000005', 'Celestial Emperor', '👑', 7999, 'gold', 'Mythic', true, false),
('f1000005-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000005', 'Planet Creation', '🌍', 19999, 'gold', 'Mythic', true, false),
('f1000005-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000005', 'World Tree', '🌳', 19999, 'gold', 'Mythic', true, false),
('f1000005-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000005', 'Infinity Cosmos', '🌠', 29999, 'gold', 'Mythic', true, false);

-- 2. MCQ / Quiz Data Table
create table if not exists public.post_mcqs (
  post_id text primary key references public.posts(id) on delete cascade,
  question text not null,
  options jsonb not null default '[]'::jsonb, -- Array of {id: string, text: string, is_correct: bool}
  explanation text default '',
  timer_seconds integer default 0,
  difficulty text default 'Medium',
  category text default 'General',
  xp_reward integer default 10,
  created_at timestamp with time zone default now()
);

-- 2. Enhanced Heartbeat RPC with Instant Reconnection Restoration
create or replace function public.heartbeat_room_member(
  p_room_id text,
  p_session_id text default null,
  p_is_speaking boolean default false
) returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_was_reconnecting boolean := false;
begin
  if v_user_id is null then
    raise exception 'Unauthenticated user';
  end if;

  -- Run background cleanup
  perform public.process_presence_grace_period_and_cleanup();

  -- Verify membership
  select is_reconnecting into v_was_reconnecting
  from public.room_members
  where room_id = p_room_id and user_id = v_user_id;

  if v_was_reconnecting is null then
    return jsonb_build_object('success', false, 'reason', 'Not a member of this room');
  end if;

  -- Refresh heartbeat timestamp and restore active status
  update public.room_members
  set last_heartbeat_at = now(),
      is_reconnecting = false,
      session_id = coalesce(p_session_id, session_id)
  where room_id = p_room_id and user_id = v_user_id;

  -- Restore seat reconnecting status if user is seated
  update public.room_seats
  set is_reconnecting = false,
      is_speaking = p_is_speaking,
      session_id = coalesce(p_session_id, session_id)
  where room_id = p_room_id and user_id = v_user_id;

  -- Update session last_seen in user_sessions
  if p_session_id is not null then
    update public.user_sessions
    set last_seen = now(), online_status = 'In Room'
    where session_id = p_session_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'restored_from_grace_period', v_was_reconnecting
  );
end;
$$ language plpgsql security definer set search_path = public;

-- 3. Function to compile and rebuild active cosmetic assets
create or replace function public.rebuild_user_membership_assets(p_user_id uuid)
returns jsonb as $$
declare
  v_vip_level int;
  v_novel_level int;
  v_assets jsonb := '{}'::jsonb;
  v_asset record;
begin
  -- Get user active levels from user_vip / user_novel tables
  select level into v_vip_level 
  from public.user_vip 
  where user_id = p_user_id and is_active = true and expiry_date > now();
  
  select level into v_novel_level 
  from public.user_novel 
  where user_id = p_user_id and is_active = true and expiry_date > now();

  v_vip_level := coalesce(v_vip_level, 0);
  v_novel_level := coalesce(v_novel_level, 0);

  -- Compile VIP assets
  if v_vip_level > 0 then
    for v_asset in 
      select asset_type, asset_url
      from public.vip_assets
      where level_required = v_vip_level and enabled = true
      order by display_priority asc
    loop
      v_assets := jsonb_set(v_assets, array[v_asset.asset_type], to_jsonb(v_asset.asset_url));
    end loop;
  end if;

  -- Compile Novel assets (merge/override if higher priority)
  if v_novel_level > 0 then
    for v_asset in 
      select asset_type, asset_url
      from public.novel_assets
      where level_required = v_novel_level and enabled = true
      order by display_priority asc
    loop
      v_assets := jsonb_set(v_assets, array[v_asset.asset_type], to_jsonb(v_asset.asset_url));
    end loop;
  end if;

  return v_assets;
end;
$$ language plpgsql security definer;

-- Helper function to calculate remaining days
create or replace function public.get_membership_remaining_days(p_expiry timestamp with time zone)
returns integer as $$
begin
  return coalesce(greatest(0, date_part('day', p_expiry - now())::integer), 0);
end;
$$ language plpgsql stable;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 5: Auto-trigger on subscriptions table INSERT/UPDATE
-- Purchases insert into subscriptions → this auto-grants entitlements immediately
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.on_subscription_change()
returns trigger as $$
begin
  perform public.recompute_user_entitlements(new.user_id);
  return new;
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

-- B. cosmetic_assets View Trigger for writes (achievements, inserts)
create or replace function public.sync_cosmetic_assets_view_to_definitions()
returns trigger as $$
begin
  if TG_OP = 'INSERT' then
    insert into public.asset_definitions (
      id, display_name, category, sub_category, thumbnail_url, preview_url, animation_url, 
      vip_requirement, level_requirement, enabled, priority, visibility, permanent
    ) values (
      coalesce(NEW.asset_id, gen_random_uuid()),
      NEW.name,
      coalesce(NEW.category, 'Cosmetics'),
      NEW.type,
      NEW.thumbnail_url,
      NEW.preview_url,
      NEW.animation_url,
      case when NEW.required_membership = 'VIP' then 1 else 0 end,
      coalesce(NEW.required_level, 0),
      coalesce(NEW.enabled, true),
      coalesce(NEW.priority, 0),
      coalesce(NEW.visibility, 'Public'),
      case when NEW.expiry_rule = 'Permanent' then true else false end
    );
    return NEW;
  elsif TG_OP = 'UPDATE' then
    update public.asset_definitions set
      display_name = NEW.name,
      sub_category = NEW.type,
      category = NEW.category,
      thumbnail_url = NEW.thumbnail_url,
      preview_url = NEW.preview_url,
      animation_url = NEW.animation_url,
      vip_requirement = case when NEW.required_membership = 'VIP' then 1 else 0 end,
      level_requirement = coalesce(NEW.required_level, 0),
      enabled = coalesce(NEW.enabled, true),
      priority = coalesce(NEW.priority, 0),
      visibility = coalesce(NEW.visibility, 'Public'),
      permanent = case when NEW.expiry_rule = 'Permanent' then true else false end
    where id = OLD.asset_id;
    return NEW;
  elsif TG_OP = 'DELETE' then
    delete from public.asset_definitions where id = OLD.asset_id;
    return OLD;
  end if;
  return null;
end;
$$ language plpgsql;

-- D. inventory View Trigger for legacy writes (entitlements, updates)
create or replace function public.sync_inventory_view_to_vault()
returns trigger as $$
begin
  if TG_OP = 'INSERT' then
    insert into public.vault_items (
      id, user_id, asset_id, quantity, status, purchase_source, purchase_date, expires_at, is_equipped, last_equipped_at
    ) values (
      coalesce(NEW.id, gen_random_uuid()),
      NEW.user_id,
      NEW.asset_id,
      1,
      case when NEW.status = 'Active' then 'Activated'::text else 'Expired'::text end,
      NEW.purchase_source,
      coalesce(NEW.purchase_date, now()),
      NEW.expires_at,
      coalesce(NEW.is_equipped, false),
      NEW.last_equipped_at
    )
    on conflict (user_id, asset_id) do update set
      status = EXCLUDED.status,
      expires_at = EXCLUDED.expires_at,
      is_equipped = EXCLUDED.is_equipped,
      last_equipped_at = EXCLUDED.last_equipped_at;
    return NEW;
  elsif TG_OP = 'UPDATE' then
    update public.vault_items set
      status = case when NEW.status = 'Active' then 'Activated'::text else 'Expired'::text end,
      expires_at = NEW.expires_at,
      is_equipped = NEW.is_equipped,
      last_equipped_at = NEW.last_equipped_at,
      updated_at = now()
    where id = OLD.id;
    return NEW;
  elsif TG_OP = 'DELETE' then
    delete from public.vault_items where id = OLD.id;
    return OLD;
  end if;
  return null;
end;
$$ language plpgsql;

-- 7. Stored Procedures / RPC APIs for Vault Operations

-- A. Retrieve User Vault
create or replace function public.get_user_vault()
returns table (
  id uuid,
  asset_id uuid,
  category text,
  sub_category text,
  display_name text,
  short_description text,
  long_description text,
  thumbnail_url text,
  animation_url text,
  preview_url text,
  rarity text,
  quantity integer,
  status text,
  purchase_source text,
  purchase_date timestamp with time zone,
  expires_at timestamp with time zone,
  activated_at timestamp with time zone,
  is_equipped boolean,
  last_equipped_at timestamp with time zone,
  custom_metadata jsonb,
  tradable boolean,
  giftable boolean,
  stackable boolean,
  consumable boolean,
  permanent boolean,
  duration_seconds bigint
) as $$
begin
  return query
  select 
    vi.id,
    vi.asset_id,
    ad.category,
    ad.sub_category,
    ad.display_name,
    ad.short_description,
    ad.long_description,
    ad.thumbnail_url,
    ad.animation_url,
    ad.preview_url,
    ad.rarity,
    vi.quantity,
    vi.status,
    vi.purchase_source,
    vi.purchase_date,
    vi.expires_at,
    vi.activated_at,
    vi.is_equipped,
    vi.last_equipped_at,
    vi.custom_metadata,
    ad.tradable,
    ad.giftable,
    ad.stackable,
    ad.consumable,
    ad.permanent,
    ad.duration_seconds
  from public.vault_items vi
  join public.asset_definitions ad on vi.asset_id = ad.id
  where vi.user_id = auth.uid() and ad.enabled = true
  order by vi.created_at desc;
end;
$$ language plpgsql security definer;

-- ══════════════════════════════════════════════════════════════
-- 2. Auto-update conversations table on every new message insert
--    This keeps last_message, last_message_time, sender consistent
--    in the database so any client or dashboard can query it.
-- ══════════════════════════════════════════════════════════════

create or replace function public.update_conversation_on_new_message()
returns trigger as $$
declare
  v_conv_id text;
  v_part_a uuid;
  v_part_b uuid;
begin
  -- Only handle private direct messages
  if new.receiver_id is null or new.receiver_id = new.sender_id then
    return new;
  end if;

  -- Determine deterministic conversation ID (smaller UUID first)
  if new.sender_id < new.receiver_id then
    v_part_a := new.sender_id;
    v_part_b := new.receiver_id;
  else
    v_part_a := new.receiver_id;
    v_part_b := new.sender_id;
  end if;

  v_conv_id := v_part_a::text || '_' || v_part_b::text;

  -- Upsert conversation metadata atomically
  insert into public.conversations (
    id,
    participant_a,
    participant_b,
    last_message,
    last_message_time,
    last_message_sender_id,
    created_at
  ) values (
    v_conv_id,
    v_part_a,
    v_part_b,
    -- Store generic preview in conversations table (not encrypted_content)
    case new.media_type
      when 'image' then '📷 Photo'
      when 'video' then '🎥 Video'
      when 'audio' then '🎤 Voice message'
      when 'document' then '📄 Document'
      when 'file' then '📄 File'
      when 'location' then '📍 Location'
      when 'contact' then '👤 Contact'
      when 'gift' then '🎁 Gift'
      else '💬 Message'
    end,
    new.created_at,
    new.sender_id,
    timezone('utc'::text, now())
  )
  on conflict (participant_a, participant_b) do update
  set
    last_message = excluded.last_message,
    last_message_time = excluded.last_message_time,
    last_message_sender_id = excluded.last_message_sender_id;

  -- Also update conversation_id on the message itself if not set
  if new.conversation_id is null or new.conversation_id = '' then
    update public.messages
    set conversation_id = v_conv_id
    where id = new.id;
  end if;

  return new;
end;
$$ language plpgsql security definer set search_path = public;

-- ============================================================
-- 3. Helper: silent per-step audit logger (never raises)
-- ============================================================
create or replace function public._log_equip_step(
  p_user_id   uuid,
  p_action    text,
  p_category  text,
  p_item_name text,
  p_step      text,
  p_detail    jsonb default null,
  p_error     text  default null
) returns void language plpgsql security definer set search_path = public as $fn$
begin
  insert into public.vip_audit_logs
    (user_id, action, category, item_name, step, details, error_detail, created_at)
  values (p_user_id, p_action, p_category, p_item_name, p_step,
          coalesce(p_detail, '{}'::jsonb), p_error, now());
exception when others then null;
end;
$fn$;

-- 3. RPC Function to verify room password
CREATE OR REPLACE FUNCTION public.verify_room_password(
  p_room_id text,
  p_password text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_stored_password text;
BEGIN
  SELECT room_password
  INTO v_stored_password
  FROM public.rooms
  WHERE id = p_room_id OR username = p_room_id LIMIT 1;

  IF v_stored_password IS NULL OR length(trim(v_stored_password)) = 0 THEN
    SELECT room_password INTO v_stored_password FROM public.room_settings WHERE room_id = p_room_id LIMIT 1;
  END IF;

  IF v_stored_password IS NULL OR length(trim(v_stored_password)) = 0 THEN
    RETURN true; -- No password set
  END IF;

  RETURN (trim(v_stored_password) = trim(p_password));
END;
$$;

-- ============================================================
-- 202608070025_permanent_room_roles_and_task_retention.sql
-- Permanent Room Roles, Tasks, & Progress Retention System
--
-- Rules:
-- 1. Permanent Assigned Roles: Co-Owner, Admin, Star Member roles are permanently saved on public.room_assigned_roles & public.rooms.
-- 2. No Role Stripping: Disconnecting, leaving, or app restarts NEVER strip assigned roles.
-- 3. Auto-Role Restoration: Rejoining a room automatically restores assigned Co-Owner/Admin/Star Member roles.
-- 4. Room Tasks & Progress Retention: Dual progress, daily tasks, AP/VP points, room XP, and room level are 100% bound to room_id.
-- ============================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Database Protection Trigger for room_assigned_roles
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.prevent_auto_room_assigned_role_deletion()
returns trigger as $$
begin
  if (TG_OP = 'DELETE') then
    if current_setting('app.allow_role_modification', true) is distinct from 'true' then
      raise exception 'UNAUTHORIZED_ROLE_DELETION: Assigned room roles can only be removed via demote_room_member_role() or transfer_room_ownership().';
    end if;
  end if;
  return old;
end;
$$ language plpgsql security definer set search_path = public;

-- 6. RPC Function for Atomic MCQ Voting
create or replace function public.submit_mcq_vote(
  p_post_id text,
  p_user_id uuid,
  p_option_id text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_result jsonb;
  v_is_correct bool := false;
  v_explanation text := '';
  v_correct_option_id text := '';
begin
  -- Record vote
  insert into public.post_mcq_votes (post_id, user_id, option_id)
  values (p_post_id, p_user_id, p_option_id)
  on conflict (post_id, user_id) 
  do update set option_id = p_option_id, created_at = now();

  -- Get correct details
  select 
    (elem->>'is_correct')::boolean,
    m.explanation,
    (select elem2->>'id' from jsonb_array_elements(m.options) elem2 where (elem2->>'is_correct')::boolean is true limit 1)
  into v_is_correct, v_explanation, v_correct_option_id
  from public.post_mcqs m,
  jsonb_array_elements(m.options) elem
  where m.post_id = p_post_id and elem->>'id' = p_option_id;

  select jsonb_build_object(
    'success', true,
    'selected_option_id', p_option_id,
    'correct_option_id', coalesce(v_correct_option_id, ''),
    'is_correct', coalesce(v_is_correct, false),
    'explanation', coalesce(v_explanation, '')
  ) into v_result;

  return v_result;
end;
$$;

