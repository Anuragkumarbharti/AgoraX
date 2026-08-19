-- ==========================================================================
-- Consolidated Supabase Migration Module 06: 202607090006_gifting_stars_and_gems.sql
-- Authoritative baseline schema, functions, triggers, policies, and seeds.
-- ==========================================================================

create trigger on_gift_history_insert
after insert
on public.gift_history
for each row execute procedure public.handle_gift_history_insert();

create index if not exists idx_gift_xp_logs_sender on public.gift_xp_logs(sender_id);

create index if not exists idx_gift_xp_logs_receiver on public.gift_xp_logs(receiver_id);

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

-- 5. Update send_gift task reward to grant 200 Silver Coins
delete from public.task_rewards where task_id = 'send_gift' and task_type = 'daily' and reward_type = 'silver';

insert into public.task_rewards (task_id, task_type, reward_type, amount)
values ('send_gift', 'daily', 'silver', 200);

-- 6. Configure Silver Spin probabilities to user specifications:
-- 50 to 200 Silver has 95% total probability (50 Silver: 0.50, 100 Silver: 0.30, 200 Silver: 0.15)
-- Gold 1 to 5 (amount: 3) has 0.0091 probability
-- 200+ Silver (500 Silver) has 0.0098 probability
-- XP reward (50 XP) takes the remainder: 0.0311
delete from public.spin_rewards where spin_type = 'silver';

insert into public.spin_rewards (spin_type, reward_type, amount, cosmetic_id, probability) values
('silver', 'silver', 50, null, 0.50),
('silver', 'silver', 100, null, 0.30),
('silver', 'silver', 200, null, 0.15),
('silver', 'gold', 3, null, 0.0091),
('silver', 'silver', 500, null, 0.0098),
('silver', 'xp', 50, null, 0.0311);

-- 202607170014_star_gift_system_tables.sql

-- 1. Create Gift Categories Table
create table if not exists public.gift_categories (
  id uuid default gen_random_uuid() primary key,
  name text not null unique,
  icon text,
  display_order integer default 0,
  created_at timestamptz default now()
);

-- 2. Create Gift Catalog Table
create table if not exists public.gift_catalog (
  id uuid default gen_random_uuid() primary key,
  category_id uuid references public.gift_categories(id) on delete cascade,
  name text not null,
  icon text not null,
  cost_stars numeric not null,
  currency text not null check (currency in ('gold', 'silver')),
  rarity text not null check (rarity in ('Common', 'Rare', 'Epic', 'Legendary', 'Mythic')),
  is_active boolean default true,
  is_limited boolean default false,
  is_new boolean default false,
  animation_url text,
  sound_url text,
  created_at timestamptz default now()
);

-- 6. Create Gift Animation Parameters Table
create table if not exists public.gift_animation (
  id uuid default gen_random_uuid() primary key,
  gift_id uuid references public.gift_catalog(id) on delete cascade,
  particle_count integer default 20,
  speed numeric default 1.0,
  easing_curve text default 'easeOut',
  created_at timestamptz default now()
);

-- 7. Create Gift Combos Table
create table if not exists public.gift_combo (
  id uuid default gen_random_uuid() primary key,
  gift_id uuid references public.gift_catalog(id) on delete cascade,
  min_count integer not null,
  effect_type text,
  created_at timestamptz default now()
);

alter table public.gift_history add column if not exists stars_value numeric;

-- 12. Create Gift Effects Table
create table if not exists public.gift_effects (
  id uuid default gen_random_uuid() primary key,
  gift_id uuid references public.gift_catalog(id) on delete cascade,
  effect_name text,
  parameters jsonb,
  created_at timestamptz default now()
);

-- 13. Create Gift Assets Table
create table if not exists public.gift_assets (
  id uuid default gen_random_uuid() primary key,
  gift_id uuid references public.gift_catalog(id) on delete cascade,
  asset_type text,
  file_url text,
  created_at timestamptz default now()
);

-- 14. Create Gift Settings Table
create table if not exists public.gift_settings (
  key text primary key,
  value text,
  updated_at timestamptz default now()
);

-- 15. Create Gift Event Logs Table
create table if not exists public.gift_event_logs (
  id uuid default gen_random_uuid() primary key,
  event_name text,
  user_id uuid,
  details jsonb,
  created_at timestamptz default now()
);

-- Setup RLS Policies (Authenticated users can read, only admin/system functions can write)
create policy "Allow read access to authenticated users on gift_categories" on public.gift_categories for select to authenticated using (true);

-- Seed Categories
insert into public.gift_categories (id, name, icon, display_order) values
('c1000000-0000-0000-0000-000000000001', 'Stars', '⭐', 1),
('c1000000-0000-0000-0000-000000000002', 'Silver', '🪙', 2)
on conflict (name) do nothing;

-- Seed Catalog
insert into public.gift_catalog (id, category_id, name, icon, cost_stars, currency, rarity, is_active) values
-- Stars gifts (cost_stars represents stars, matches gold coins 1-to-1)
('a1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'Rose', '🌹', 2, 'gold', 'Common', true),
('a1000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001', 'Heart', '❤️', 10, 'gold', 'Common', true),
('a1000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000001', 'Crown', '👑', 500, 'gold', 'Epic', true),
('a1000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000001', 'Sports Car', '🏎️', 1000, 'gold', 'Legendary', true),
('a1000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000001', 'Castle', '🏰', 5000, 'gold', 'Mythic', true),
('a1000000-0000-0000-0000-000000000006', 'c1000000-0000-0000-0000-000000000001', 'Rocket', '🚀', 10000, 'gold', 'Mythic', true),

-- Silver gifts (cost_stars represents converted stars: 100 silver = 1 star. E.g. Like is 50 silver = 0.5 stars)
('a1000000-0000-0000-0000-000000000011', 'c1000000-0000-0000-0000-000000000002', 'Like', '👍', 0.5, 'silver', 'Common', true),
('a1000000-0000-0000-0000-000000000012', 'c1000000-0000-0000-0000-000000000002', 'Coffee', '☕', 1.0, 'silver', 'Common', true),
('a1000000-0000-0000-0000-000000000013', 'c1000000-0000-0000-0000-000000000002', 'Chocolate', '🍫', 2.0, 'silver', 'Common', true),
('a1000000-0000-0000-0000-000000000014', 'c1000000-0000-0000-0000-000000000002', 'Flower', '🌼', 5.0, 'silver', 'Common', true),
('a1000000-0000-0000-0000-000000000015', 'c1000000-0000-0000-0000-000000000002', 'Cake', '🎂', 10.0, 'silver', 'Rare', true),
('a1000000-0000-0000-0000-000000000016', 'c1000000-0000-0000-0000-000000000002', 'Small Heart', '❤️', 20.0, 'silver', 'Rare', true)
on conflict (id) do nothing;

-- 202607170015_star_gift_system_v2.sql

-- 1. Create Magic Gift Rewards Tables
create table if not exists public.magic_gift_rewards (
  id uuid default gen_random_uuid() primary key,
  price_coins integer not null check (price_coins in (5, 10, 50, 499)),
  payout_type text not null check (payout_type in ('coin_back', 'silver_reward', 'vault_reward', 'nothing')),
  multiplier integer default 1,
  silver_amount integer default 0,
  vault_definition_id uuid, -- references asset_definitions(id)
  probability numeric not null check (probability >= 0 and probability <= 1),
  created_at timestamptz default now()
);

create table if not exists public.magic_gift_budget (
  id text primary key,
  total_sold_coins numeric default 0,
  total_payout_coins numeric default 0,
  max_payout_ratio numeric default 0.70,
  updated_at timestamptz default now()
);

-- Setup RLS Policies
create policy "Allow read access to magic_gift_rewards" on public.magic_gift_rewards for select to authenticated using (true);

-- 5. Seeding Categories & Catalog with exact Gold (14) and Silver (10) gifts
alter table public.gift_catalog add column if not exists is_magic boolean default false;

-- Clean existing catalog to ensure exact specs
delete from public.gift_catalog;

delete from public.gift_categories;

insert into public.gift_categories (id, name, icon, display_order) values
('c1000000-0000-0000-0000-000000000001', 'Gold', '⭐', 1),
('c1000000-0000-0000-0000-000000000002', 'Silver', '🪙', 2);

insert into public.gift_catalog (id, category_id, name, icon, cost_stars, currency, rarity, is_active, is_magic) values
-- Gold Gifts
('a2000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'Like', '👍', 2, 'gold', 'Common', true, false),
('a2000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001', 'Flower', '🌼', 5, 'gold', 'Common', true, true), -- Magic Gift
('a2000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000001', 'Rose', '🌹', 10, 'gold', 'Common', true, true), -- Magic Gift
('a2000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000001', 'Heart', '❤️', 15, 'gold', 'Common', true, false),
('a2000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000001', 'Coffee', '☕', 20, 'gold', 'Common', true, false),
('a2000000-0000-0000-0000-000000000006', 'c1000000-0000-0000-0000-000000000001', 'Chocolate', '🍫', 25, 'gold', 'Common', true, false),
('a2000000-0000-0000-0000-000000000007', 'c1000000-0000-0000-0000-000000000001', 'Cake', '🎂', 30, 'gold', 'Common', true, false),
('a2000000-0000-0000-0000-000000000008', 'c1000000-0000-0000-0000-000000000001', 'Balloon', '🎈', 35, 'gold', 'Common', true, false),
('a2000000-0000-0000-0000-000000000009', 'c1000000-0000-0000-0000-000000000001', 'Gift Box', '🎁', 40, 'gold', 'Common', true, false),
('a2000000-0000-0000-0000-000000000010', 'c1000000-0000-0000-0000-000000000001', 'Diamond', '💎', 50, 'gold', 'Common', true, true), -- Magic Gift
('a2000000-0000-0000-0000-000000000011', 'c1000000-0000-0000-0000-000000000001', 'Crown', '👑', 99, 'gold', 'Epic', true, false),
('a2000000-0000-0000-0000-000000000012', 'c1000000-0000-0000-0000-000000000001', 'Butterfly', '🦋', 99, 'gold', 'Epic', true, false),
('a2000000-0000-0000-0000-000000000013', 'c1000000-0000-0000-0000-000000000001', 'Sports Car', '🏎️', 499, 'gold', 'Legendary', true, true), -- Magic Gift
('a2000000-0000-0000-0000-000000000014', 'c1000000-0000-0000-0000-000000000001', 'Private Jet', '✈️', 499, 'gold', 'Mythic', true, true), -- Magic Gift

-- Silver Gifts
('a2000000-0000-0000-0000-000000000021', 'c1000000-0000-0000-0000-000000000002', 'Like', '👍', 2.0, 'silver', 'Common', true, false), -- Converted stars
('a2000000-0000-0000-0000-000000000022', 'c1000000-0000-0000-0000-000000000002', 'Flower', '🌼', 5.0, 'silver', 'Common', true, false),
('a2000000-0000-0000-0000-000000000023', 'c1000000-0000-0000-0000-000000000002', 'Rose', '🌹', 10.0, 'silver', 'Common', true, false),
('a2000000-0000-0000-0000-000000000024', 'c1000000-0000-0000-0000-000000000002', 'Heart', '❤️', 15.0, 'silver', 'Common', true, false),
('a2000000-0000-0000-0000-000000000025', 'c1000000-0000-0000-0000-000000000002', 'Coffee', '☕', 20.0, 'silver', 'Common', true, false),
('a2000000-0000-0000-0000-000000000026', 'c1000000-0000-0000-0000-000000000002', 'Chocolate', '🍫', 25.0, 'silver', 'Common', true, false),
('a2000000-0000-0000-0000-000000000027', 'c1000000-0000-0000-0000-000000000002', 'Cake', '🎂', 30.0, 'silver', 'Rare', true, false),
('a2000000-0000-0000-0000-000000000028', 'c1000000-0000-0000-0000-000000000002', 'Balloon', '🎈', 35.0, 'silver', 'Rare', true, false),
('a2000000-0000-0000-0000-000000000029', 'c1000000-0000-0000-0000-000000000002', 'Gift Box', '🎁', 40.0, 'silver', 'Rare', true, false),
('a2000000-0000-0000-0000-000000000030', 'c1000000-0000-0000-0000-000000000002', 'Diamond', '💎', 50.0, 'silver', 'Rare', true, false);

-- Seed Magic Gift Lottery rules
insert into public.magic_gift_rewards (price_coins, payout_type, multiplier, silver_amount, probability) values
-- For 5 Coins Magic Gifts
(5, 'nothing', 0, 0, 0.40),
(5, 'coin_back', 1, 0, 0.35),
(5, 'coin_back', 2, 0, 0.15),
(5, 'coin_back', 3, 0, 0.08),
(5, 'coin_back', 5, 0, 0.02),

-- For 10 Coins Magic Gifts
(10, 'nothing', 0, 0, 0.40),
(10, 'coin_back', 1, 0, 0.35),
(10, 'coin_back', 2, 0, 0.15),
(10, 'coin_back', 3, 0, 0.08),
(10, 'coin_back', 5, 0, 0.02),

-- For 50 Coins Magic Gifts
(50, 'nothing', 0, 0, 0.50),
(50, 'coin_back', 1, 0, 0.25),
(50, 'coin_back', 2, 0, 0.15),
(50, 'coin_back', 3, 0, 0.08),
(50, 'coin_back', 5, 0, 0.02),

-- For 499 Coins Magic Gifts
(499, 'nothing', 0, 0, 0.60),
(499, 'coin_back', 1, 0, 0.20),
(499, 'coin_back', 2, 0, 0.10),
(499, 'coin_back', 3, 0, 0.07),
(499, 'coin_back', 5, 0, 0.03);

-- Initialize global budget
insert into public.magic_gift_budget (id, total_sold_coins, total_payout_coins, max_payout_ratio)
values ('global', 0, 0, 0.70)
on conflict (id) do nothing;

-- 202607170016_self_gifting_anti_abuse.sql

-- 1. Create gifting_settings table
create table if not exists public.gifting_settings (
  id text primary key,
  allow_self_gifting boolean default true,
  self_gift_payout_ratio numeric default 0.0 check (self_gift_payout_ratio >= 0.0 and self_gift_payout_ratio <= 1.0),
  exclude_self_gifts_from_leaderboards boolean default true,
  exclude_self_gifts_from_xp boolean default true,
  exclude_self_gifts_from_milestones boolean default true,
  updated_at timestamptz default now()
);

-- Seed default settings
insert into public.gifting_settings (id, allow_self_gifting, self_gift_payout_ratio, exclude_self_gifts_from_leaderboards, exclude_self_gifts_from_xp, exclude_self_gifts_from_milestones)
values ('global', true, 0.0, true, true, true)
on conflict (id) do nothing;

-- 2. Alter gift_transactions table to add is_self_gift flag
alter table public.gift_transactions add column if not exists is_self_gift boolean default false;

drop trigger if exists tr_gift_received_notifications on public.gift_transactions;

create trigger tr_gift_received_notifications
  after insert or update of status on public.gift_transactions
  for each row execute function public.handle_gift_received_notifications();

alter table public.messages add constraint messages_media_type_check 
  check (media_type in ('text', 'image', 'video', 'audio', 'file', 'document', 'gif', 'sticker', 'location', 'contact', 'gift'));

-- Migration: 202608030001_sync_production_gift_catalog.sql
-- Synchronizes backend database gift catalog with official production StarMaker gift specification.

delete from public.gift_catalog;

insert into public.gift_catalog (id, category_id, name, icon, cost_stars, currency, rarity, is_active, is_magic) values
-- Gold Gifts
('a2000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'Like', '👍', 2, 'gold', 'Common', true, false),
('a2000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001', 'Flower', '🌼', 5, 'gold', 'Common', true, true),
('a2000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000001', 'Rose', '🌹', 10, 'gold', 'Common', true, true),
('a2000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000001', 'Heart', '❤️', 15, 'gold', 'Common', true, false),
('a2000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000001', 'Coffee', '☕', 20, 'gold', 'Common', true, false),
('a2000000-0000-0000-0000-000000000006', 'c1000000-0000-0000-0000-000000000001', 'Chocolate', '🍫', 25, 'gold', 'Common', true, false),
('a2000000-0000-0000-0000-000000000007', 'c1000000-0000-0000-0000-000000000001', 'Cake', '🎂', 30, 'gold', 'Common', true, false),
('a2000000-0000-0000-0000-000000000008', 'c1000000-0000-0000-0000-000000000001', 'Balloon', '🎈', 35, 'gold', 'Common', true, false),
('a2000000-0000-0000-0000-000000000009', 'c1000000-0000-0000-0000-000000000001', 'Gift Box', '🎁', 40, 'gold', 'Common', true, false),
('a2000000-0000-0000-0000-000000000010', 'c1000000-0000-0000-0000-000000000001', 'Diamond', '💎', 50, 'gold', 'Common', true, true),
('a2000000-0000-0000-0000-000000000011', 'c1000000-0000-0000-0000-000000000001', 'Crown', '👑', 99, 'gold', 'Epic', true, false),
('a2000000-0000-0000-0000-000000000012', 'c1000000-0000-0000-0000-000000000001', 'Butterfly', '🦋', 99, 'gold', 'Epic', true, false),
('a2000000-0000-0000-0000-000000000013', 'c1000000-0000-0000-0000-000000000001', 'Sports Car', '🏎️', 499, 'gold', 'Legendary', true, true),
('a2000000-0000-0000-0000-000000000014', 'c1000000-0000-0000-0000-000000000001', 'Private Jet', '✈️', 499, 'gold', 'Mythic', true, true),

-- Silver Gifts
('a2000000-0000-0000-0000-000000000021', 'c1000000-0000-0000-0000-000000000002', 'Like', '👍', 200, 'silver', 'Common', true, false),
('a2000000-0000-0000-0000-000000000022', 'c1000000-0000-0000-0000-000000000002', 'Flower', '🌼', 500, 'silver', 'Common', true, false),
('a2000000-0000-0000-0000-000000000023', 'c1000000-0000-0000-0000-000000000002', 'Rose', '🌹', 1000, 'silver', 'Common', true, false),
('a2000000-0000-0000-0000-000000000024', 'c1000000-0000-0000-0000-000000000002', 'Heart', '❤️', 1500, 'silver', 'Common', true, false),
('a2000000-0000-0000-0000-000000000025', 'c1000000-0000-0000-0000-000000000002', 'Coffee', '☕', 2000, 'silver', 'Common', true, false),
('a2000000-0000-0000-0000-000000000026', 'c1000000-0000-0000-0000-000000000002', 'Chocolate', '🍫', 2500, 'silver', 'Common', true, false),
('a2000000-0000-0000-0000-000000000027', 'c1000000-0000-0000-0000-000000000002', 'Cake', '🎂', 3000, 'silver', 'Rare', true, false),
('a2000000-0000-0000-0000-000000000028', 'c1000000-0000-0000-0000-000000000002', 'Balloon', '🎈', 3500, 'silver', 'Rare', true, false),
('a2000000-0000-0000-0000-000000000029', 'c1000000-0000-0000-0000-000000000002', 'Gift Box', '🎁', 4000, 'silver', 'Rare', true, false),
('a2000000-0000-0000-0000-000000000030', 'c1000000-0000-0000-0000-000000000002', 'Diamond', '💎', 5000, 'silver', 'Rare', true, false);

-- 0b. Ensure gift_transactions schema compatibility
alter table public.gift_transactions add column if not exists gift_name text;

alter table public.gift_transactions add column if not exists gift_icon text;

alter table public.gift_transactions add column if not exists amount numeric;

alter table public.gift_transactions add column if not exists currency text;

alter table public.gift_transactions add column if not exists count integer;

alter table public.gift_transactions add column if not exists stars_value numeric;

-- 2. Drop existing overloaded send_star_gift functions to avoid 42601 record return type conflict
drop function if exists public.send_star_gift(text, uuid[], uuid, integer, integer, integer[]);

drop function if exists public.send_star_gift(text, uuid[], uuid, integer, integer);

drop function if exists public.send_star_gift(text, uuid[], uuid, integer);

drop function if exists public.send_star_gift(text, uuid[], uuid);

alter table public.gift_transactions add column if not exists gift_name text;

alter table public.gift_transactions add column if not exists currency text default 'gold';

alter table public.gift_transactions add column if not exists count integer default 1;

alter table public.gift_transactions add column if not exists stars_value numeric default 0;

alter table public.gift_transactions add column if not exists is_self_gift boolean default false;

drop policy if exists "Allow select on gift_transactions" on public.gift_transactions;

drop policy if exists "Allow select on gift_history" on public.gift_history;

drop policy if exists "Allow select on gift_statistics" on public.gift_statistics;

drop policy if exists "Allow select on gift_leaderboards" on public.gift_leaderboards;

-- 10. Drop old send_star_gift function signatures
drop function if exists public.send_star_gift(text, uuid[], uuid, integer, integer, integer[]);

alter table public.gift_catalog add column if not exists is_magic boolean default false;

-- 2. Update existing gift_catalog entries to set is_lucky = true for lucky gifts
update public.gift_catalog
set is_lucky = true
where name in ('Flower', 'Rose', 'Cake', 'Gift Box', 'Diamond', 'Sports Car', 'Private Jet')
   or is_magic = true;

-- Setup RLS Policies
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'lucky_reward_logs' and policyname = 'Allow read access to lucky_reward_logs') then
    create policy "Allow read access to lucky_reward_logs" on public.lucky_reward_logs for select to authenticated using (true);
  end if;
end $$;

-- Migration: 202608080001_rebuild_gift_system_35_gifts.sql
-- Complete rebuild of Gift Catalog with 35 gifts (29 Gold, 6 Silver) across 5 Tiers.
-- Uses valid UUIDs (hex characters 0-9, a-f). Updated 10 Gold items to 9 Gold.

BEGIN;

-- 1. Clear out previous gift catalog and categories
DELETE FROM public.gift_catalog;

DELETE FROM public.gift_categories;

-- 2. Seed Tier Categories
INSERT INTO public.gift_categories (id, name, icon, display_order) VALUES
('c1000000-0000-0000-0000-000000000001', 'Tier 1', '🥈', 1),
('c1000000-0000-0000-0000-000000000002', 'Tier 2', '🥇', 2),
('c1000000-0000-0000-0000-000000000003', 'Tier 3', '👑', 3),
('c1000000-0000-0000-0000-000000000004', 'Tier 4', '💎', 4),
('c1000000-0000-0000-0000-000000000005', 'Tier 5', '⚡', 5);

-- 4. Update send_star_gift RPC to seamlessly support 35 gifts & lucky rewards
DROP FUNCTION IF EXISTS public.send_star_gift(text, uuid[], uuid, integer, integer, integer[]);

DROP FUNCTION IF EXISTS public.send_star_gift(uuid, uuid[], uuid, integer, integer, integer[]);

COMMIT;

create index if not exists events_start_date_idx   on public.events(start_date);

-- 1. Ensure gift_transactions schema compatibility for total_cost, amount, gift_name, gift_icon, stars_value
ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS total_cost numeric;

ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS amount numeric;

ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS gift_name text;

ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS gift_icon text;

ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS stars_value numeric DEFAULT 0;

-- 2. Explicitly drop all historical overloaded send_star_gift RPC signatures
DROP FUNCTION IF EXISTS public.send_star_gift(text, uuid[], uuid, integer, integer, integer[]);

DROP FUNCTION IF EXISTS public.send_star_gift(text, uuid[], uuid, integer, integer);

DROP FUNCTION IF EXISTS public.send_star_gift(uuid, uuid[], uuid, integer, integer);

DROP FUNCTION IF EXISTS public.send_star_gift(text, uuid[], uuid, integer);

DROP FUNCTION IF EXISTS public.send_star_gift(uuid, uuid[], uuid, integer);

DROP FUNCTION IF EXISTS public.send_star_gift(text, uuid[], uuid);

DROP FUNCTION IF EXISTS public.send_star_gift(uuid, uuid[], uuid);

DROP FUNCTION IF EXISTS public.send_star_gift(text, uuid[], uuid, integer, integer, integer[], text);

DROP FUNCTION IF EXISTS public.send_star_gift(uuid, uuid[], uuid, integer, integer, integer[], text);

ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS total_cost numeric;

CREATE INDEX IF NOT EXISTS idx_gift_tx_idempotency ON public.gift_transactions(idempotency_key);

-- 2. Drop legacy signatures of send_star_gift to avoid overload ambiguity
DROP FUNCTION IF EXISTS public.send_star_gift(text, uuid[], uuid, integer, integer, integer[]);

DROP FUNCTION IF EXISTS public.send_star_gift(text, uuid[], uuid, integer, integer, integer[], text, uuid);

-- Functions
create or replace function public.calculate_gift_stars(item_id text, coins_value integer, quantity integer)
returns integer as $$
declare
  stars_per_unit integer;
begin
  if item_id = '2-Star Gift' then
    stars_per_unit := 2;
  elsif item_id = '1-Star Gift' then
    stars_per_unit := 1;
  else
    stars_per_unit := greatest(1, coins_value / 10);
  end if;
  return stars_per_unit * quantity;
end;
$$ language plpgsql immutable;

-- 8. Rebuild checkin calendar APIs to support the 7-day rolling check-in system
create or replace function public.get_checkin_status()
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_streak_count integer := 0;
  v_can_claim_today boolean := true;
  v_next_day_to_claim integer := 1;
  v_current_week_start integer := 1;
  v_current_week_end integer := 7;
  v_claimed_days integer[] := '{}';
  v_history_record record;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  -- Calculate current active consecutive streak
  v_streak_count := public.calculate_checkin_streak(v_user_id);

  -- Check if already claimed today
  if exists (
    select 1 from public.checkin_history
    where user_id = v_user_id
      and claimed_at::date = current_date
  ) then
    v_can_claim_today := false;
    v_next_day_to_claim := v_streak_count;
  else
    v_can_claim_today := true;
    v_next_day_to_claim := v_streak_count + 1;
  end if;

  -- Calculate current 7-day rolling window
  -- Week 1: 1-7, Week 2: 8-14, Week 3: 15-21, etc.
  v_current_week_start := (((v_next_day_to_claim - 1) / 7) * 7) + 1;
  v_current_week_end := v_current_week_start + 6;

  -- Get which days in the current 7-day block have been claimed
  -- Find matches from checkin_history using day numbers in that range
  -- Because of streak resets, we only look at the most recent checkins matching the streak days
  for v_history_record in 
    select day_number 
    from (
      select day_number, claimed_at 
      from public.checkin_history 
      where user_id = v_user_id
      order by claimed_at desc 
      limit v_streak_count
    ) h
    where h.day_number between v_current_week_start and v_current_week_end
  loop
    v_claimed_days := array_append(v_claimed_days, v_history_record.day_number);
  end loop;

  return jsonb_build_object(
    'streak_count', v_streak_count,
    'can_claim_today', v_can_claim_today,
    'next_day_to_claim', v_next_day_to_claim,
    'week_start', v_current_week_start,
    'week_end', v_current_week_end,
    'claimed_days', coalesce(to_jsonb(v_claimed_days), '[]'::jsonb)
  );
end;
$$ language plpgsql security definer;

-- Claim checkin reward under rolling streak calendar rules
create or replace function public.claim_checkin()
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_streak_count integer := 0;
  v_next_day integer := 1;
  v_reward_type text;
  v_amount integer;
  v_cosmetic_id text;
  v_week_factor integer;
  v_day_of_week integer;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  perform pg_advisory_xact_lock(('x' || substr(md5(v_user_id::text), 1, 15))::bit(60)::bigint);

  -- 1. Check if already claimed today
  if exists (
    select 1 from public.checkin_history
    where user_id = v_user_id
      and claimed_at::date = current_date
  ) then
    raise exception 'ALREADY_CLAIMED: You have already checked in today.';
  end if;

  -- 2. Calculate next day in sequence based on consecutive days
  v_streak_count := public.calculate_checkin_streak(v_user_id);
  v_next_day := v_streak_count + 1;

  -- 3. Determine rolling rewards sequence
  -- Week multiplier factor: 1 for Week 1 (Days 1-7), 2 for Week 2 (Days 8-14), etc.
  v_week_factor := ((v_next_day - 1) / 7) + 1;
  v_day_of_week := ((v_next_day - 1) % 7) + 1;

  if v_day_of_week = 1 then
    v_reward_type := 'silver'; v_amount := 200 * v_week_factor; v_cosmetic_id := null;
  elsif v_day_of_week = 2 then
    v_reward_type := 'silver'; v_amount := 300 * v_week_factor; v_cosmetic_id := null;
  elsif v_day_of_week = 3 then
    v_reward_type := 'xp'; v_amount := 100; v_cosmetic_id := null;
  elsif v_day_of_week = 4 then
    v_reward_type := 'gold'; v_amount := 1 * v_week_factor; v_cosmetic_id := null;
  elsif v_day_of_week = 5 then
    v_reward_type := 'silver'; v_amount := 600 * v_week_factor; v_cosmetic_id := null;
  elsif v_day_of_week = 6 then
    v_reward_type := 'spin_ticket'; v_amount := 1; v_cosmetic_id := null;
  else -- Day 7 (Jackpot)
    v_reward_type := 'gold'; v_amount := 15 * v_week_factor; v_cosmetic_id := null;
  end if;

  -- Record checkin in database history
  insert into public.checkin_history (user_id, month_key, day_number)
  values (v_user_id, to_char(current_date, 'YYYY-MM'), v_next_day);

  -- Record claim
  insert into public.reward_claims (user_id, source_type, source_id)
  values (v_user_id, 'checkin', to_char(current_date, 'YYYY-MM') || ':' || v_next_day)
  on conflict (user_id, source_type, source_id) do nothing;

  -- Dispense rewards
  perform public.dispense_reward(
    v_user_id,
    'checkin',
    v_next_day::text,
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

-- 7. Recalculate checkin streak based on consecutive check-ins (resets on miss)
create or replace function public.calculate_checkin_streak(p_user_id uuid)
returns integer as $$
declare
  v_streak integer := 0;
  v_check_date date := current_date;
  v_has_checkin boolean;
begin
  -- Check if they checked in today or yesterday. If neither, streak is broken (0).
  select exists (
    select 1 from public.checkin_history
    where user_id = p_user_id and claimed_at::date in (current_date, current_date - 1)
  ) into v_has_checkin;

  if not v_has_checkin then
    return 0;
  end if;

  -- Start checking backwards from the last check-in date
  if exists (select 1 from public.checkin_history where user_id = p_user_id and claimed_at::date = current_date) then
    v_check_date := current_date;
  else
    v_check_date := current_date - 1;
  end if;

  loop
    select exists (
      select 1 from public.checkin_history
      where user_id = p_user_id and claimed_at::date = v_check_date
    ) into v_has_checkin;

    exit when not v_has_checkin;

    v_streak := v_streak + 1;
    v_check_date := v_check_date - 1;
  end loop;

  return v_streak;
end;
$$ language plpgsql security definer;

-- 9. RPC: Music Catalog Search
create or replace function public.search_audio_tracks(
  p_query text default '',
  p_category text default '',
  p_limit integer default 20
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_results jsonb;
begin
  select jsonb_agg(track_item)
  into v_results
  from (
    select 
      id,
      title,
      artist,
      cover_url,
      audio_url,
      license_type,
      duration,
      start_offset,
      end_offset,
      is_original_audio,
      audio_usage_count,
      trend_score
    from public.audio_tracks
    where rights_status = 'approved'
      and (p_query = '' or lower(title) like '%' || lower(p_query) || '%' or lower(artist) like '%' || lower(p_query) || '%')
    order by trend_score desc, audio_usage_count desc
    limit p_limit
  ) track_item;

  return coalesce(v_results, '[]'::jsonb);
end;
$$;

