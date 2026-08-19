-- ==========================================================================
-- Consolidated Supabase Migration Module 02: 202607090002_economy_and_wallets.sql
-- Authoritative baseline schema, functions, triggers, policies, and seeds.
-- ==========================================================================

create table public.wallet_transactions (
  id uuid default gen_random_uuid() primary key,
  wallet_id uuid references public.wallets(id) on delete cascade not null,
  amount numeric(10, 2) not null,
  currency text default 'Coins' not null check (currency in ('INR', 'Coins')),
  type text default 'Payout' not null check (type in ('Deposit', 'Withdrawal', 'Payout', 'Refund', 'Reward', 'Commission')),
  status text default 'Completed' not null check (status in ('Completed', 'Pending', 'Failed')),
  reference_id text,
  details text,
  transaction_type text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Redesign wallets table to support Gold/Silver coins, Diamonds, Coupons, Rewards, and Cashback
alter table public.wallets add column if not exists gold_coins integer default 0 check (gold_coins >= 0);

alter table public.wallets add column if not exists silver_coins integer default 0 check (silver_coins >= 0);

alter table public.wallets add column if not exists diamonds integer default 0 check (diamonds >= 0);

alter table public.wallets add column if not exists coupons integer default 0 check (coupons >= 0);

alter table public.wallets add column if not exists rewards numeric(10, 2) default 0.00 check (rewards >= 0.00);

alter table public.wallets add column if not exists cashback numeric(10, 2) default 0.00 check (cashback >= 0.00);

-- Sync existing coins_balance to gold_coins
update public.wallets set gold_coins = coalesce(coins_balance, 0) where gold_coins = 0;

-- 3. Redesign wallet_transactions table
drop table if exists public.wallet_transactions cascade;

create table public.wallet_transactions (
  id uuid default gen_random_uuid() primary key,
  wallet_id uuid references public.wallets(id) on delete cascade not null,
  amount numeric not null,
  currency text not null check (currency in ('Gold Coins', 'Silver Coins', 'Diamonds', 'Coupons', 'Rewards', 'Cashback', 'INR')),
  type text not null check (type in ('Recharge', 'Spend', 'Gift', 'Refund', 'Bonus', 'Admin Grant', 'Purchase', 'Withdrawal')),
  status text default 'Completed' not null check (status in ('Completed', 'Pending', 'Failed')),
  reference_id text,
  details text,
  created_at timestamp with time zone default now() not null
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 0b. Patch rooms.username check constraint: require at least 4 chars (was 3)
-- ─────────────────────────────────────────────────────────────────────────────
do $$
begin
  -- Drop old constraint if it exists
  if exists (
    select 1 from information_schema.table_constraints
    where table_name = 'rooms'
      and constraint_name = 'check_room_username'
  ) then
    alter table public.rooms drop constraint check_room_username;
  end if;

  -- Re-add with min 4 chars
  alter table public.rooms
    add constraint check_room_username
    check (username ~ '^@[a-z0-9_]{4,30}$');
end;
$$;

-- Indexing for quick retrieval
create index if not exists idx_comm_announcements_comm on public.community_announcements(community_id);

-- Indexing
create index if not exists idx_comm_events_comm on public.community_events(community_id);

-- Indexing
create index if not exists idx_comm_logs_comm on public.community_logs(community_id);

-- 10. Create Gift Wallet Logs Table
create table if not exists public.gift_wallet_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid,
  amount numeric,
  currency text,
  direction text,
  reason text,
  created_at timestamptz default now()
);

-- Create policies for user_sessions
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'user_sessions' and policyname = 'Allow select for self') then
    create policy "Allow select for self" on public.user_sessions
      for select using (auth.uid() = user_id);
  end if;
  
  if not exists (select 1 from pg_policies where tablename = 'user_sessions' and policyname = 'Allow insert/update for self') then
    create policy "Allow insert/update for self" on public.user_sessions
      for all using (auth.uid() = user_id);
  end if;
end
$$;

-- Enable Realtime for user_sessions
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'user_sessions'
    ) then
      alter publication supabase_realtime add table public.user_sessions;
    end if;
  end if;
end
$$;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'tr_session_insert') then
    create trigger tr_session_insert
      before insert on public.user_sessions
      for each row execute function public.on_session_insert();
  end if;
end
$$;

drop trigger if exists tr_wallet_transaction_notifications on public.wallet_transactions;

create trigger tr_wallet_transaction_notifications
  after insert or update on public.wallet_transactions
  for each row execute function public.handle_wallet_transaction_notifications();

-- Wallets optimization
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_created ON wallet_transactions(user_id, created_at DESC);

-- 202607250003_add_payment_id_and_idempotency.sql

-- 1. Add columns to public.purchases
alter table public.purchases
  add column if not exists payment_id text;

-- 2. Add columns to public.subscriptions
alter table public.subscriptions
  add column if not exists payment_id text;

-- 3. Add columns to public.user_vip
alter table public.user_vip
  add column if not exists is_vip boolean default true,
  add column if not exists vip_level integer,
  add column if not exists purchase_date timestamp with time zone default now(),
  add column if not exists payment_id text,
  add column if not exists status text default 'active';

grant execute on function public.record_membership_purchase(uuid, text, text, numeric, numeric, text, text, timestamp with time zone, text) to authenticated;

-- 202607250004_create_payments_and_verify_rpc.sql

-- Enable pgcrypto for hmac signature verification
create extension if not exists pgcrypto;

-- Setup RLS policy for select
create policy "Allow select payments for self and admins" on public.payments
  for select using (auth.uid() = user_id or exists (select 1 from public.admins where id = auth.uid()));

-- Grants
grant execute on function public.verify_and_activate_vip_rpc(text, text, text, text, text, numeric, uuid) to authenticated;

grant execute on function public.purchase_item_with_coins_rpc(uuid, text, text, int, text) to authenticated;

-- 202607250005_fix_on_conflict_constraints_and_verify_payment.sql
-- Fix PostgreSQL 42P10 (ON CONFLICT missing unique constraint) and unify Razorpay payment verification

-- Enable pgcrypto for hmac signature verification
create extension if not exists pgcrypto;

-- 1. Ensure explicit UNIQUE indexes/constraints exist on all target tables

-- subscriptions (user_id, membership_type)
do $$
begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'subscriptions' and c.relkind = 'r') then
    if not exists (
      select 1 from pg_constraint where conname = 'subscriptions_user_id_membership_type_key'
    ) then
      begin
        alter table public.subscriptions add constraint subscriptions_user_id_membership_type_key unique (user_id, membership_type);
      exception when others then
        null;
      end;
    end if;
  end if;
end $$;

-- user_vip (user_id)
do $$
begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'user_vip' and c.relkind = 'r') then
    if not exists (
      select 1 from pg_constraint where conname = 'user_vip_pkey' or conname = 'user_vip_user_id_key'
    ) then
      begin
        alter table public.user_vip add constraint user_vip_user_id_key unique (user_id);
      exception when others then
        null;
      end;
    end if;
  end if;
end $$;

-- user_novel (user_id)
do $$
begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'user_novel' and c.relkind = 'r') then
    if not exists (
      select 1 from pg_constraint where conname = 'user_novel_pkey' or conname = 'user_novel_user_id_key'
    ) then
      begin
        alter table public.user_novel add constraint user_novel_user_id_key unique (user_id);
      exception when others then
        null;
      end;
    end if;
  end if;
end $$;

-- inventory (user_id, asset_id) - only executed if relation is a base table ('r'), skipping views ('v')
do $$
begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'inventory' and c.relkind = 'r') then
    if not exists (
      select 1 from pg_constraint where conname = 'inventory_user_id_asset_id_key'
    ) then
      begin
        alter table public.inventory add constraint inventory_user_id_asset_id_key unique (user_id, asset_id);
      exception when others then
        null;
      end;
    end if;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'payments_pkey' or conname = 'payments_payment_id_key'
  ) then
    begin
      alter table public.payments add constraint payments_payment_id_key unique (payment_id);
    exception when others then
      null;
    end;
  end if;
end $$;

-- purchases (payment_id) conditional index
create unique index if not exists purchases_payment_id_unique_idx on public.purchases (payment_id) where payment_id is not null;

-- Grants
grant execute on function public.record_membership_purchase(uuid, text, text, numeric, numeric, text, text, timestamp with time zone, text) to authenticated;

grant execute on function public.verify_and_process_razorpay_payment_rpc(text, text, text, text, text, numeric, uuid) to authenticated;

grant execute on function public.verify_and_activate_vip_rpc(text, text, text, text, text, numeric, uuid) to authenticated;

-- 202607250009_rebuild_entitlement_pipeline.sql
-- ROOT-CAUSE FIX: Unified payment -> subscription -> inventory -> equip pipeline
-- ALL timestamps use server now(). Client-provided expiry is NEVER trusted.
-- equip_item_rpc  : verifies ownership before equipping, returns confirmed DB row.
-- purchase_and_activate_rpc: single atomic entry point for all purchases.

-- ============================================================
-- 1. Extend vip_audit_logs with per-step detail columns
-- ============================================================
alter table public.vip_audit_logs
  add column if not exists step         text,
  add column if not exists error_detail text;

-- 3. purchases (payment_id) — needed for idempotency check
do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'purchases_payment_id_key'
      and conrelid = 'public.purchases'::regclass
  ) then
    alter table public.purchases
      add constraint purchases_payment_id_key unique (payment_id);
  end if;
exception when others then null;
end $$;

do $$ begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'purchases' and c.relkind = 'r') then
    if not exists (select 1 from pg_constraint where conname = 'purchases_payment_id_key') then
      begin
        alter table public.purchases add constraint purchases_payment_id_key unique (payment_id);
      exception when others then null; end;
    end if;
  end if;
end $$;

-- 202608070012_security_vault_razorpay_secret.sql
-- Security patch: Remove hardcoded Razorpay secret from SQL function body.
-- The key 'ehrQ4edUdNzEZqtTE334Lcsf' was previously embedded in the function
-- verify_and_process_razorpay_payment_rpc (migration 202607250005).
-- This patch rewrites that function to read the secret from Supabase Vault
-- (vault.decrypted_secrets) instead of a hardcoded literal.
--
-- PREREQUISITE (run once in Supabase Dashboard > Vault):
--   Insert your secret:
--     Name:  razorpay_webhook_secret
--     Value: <your actual Razorpay key secret>
--
-- After adding to Vault, this function will dynamically read the secret at
-- call-time and never expose it in SQL source code or migration history.

-- ─────────────────────────────────────────────────────────────────────────────
-- Ensure pgcrypto is available for HMAC computation
-- ─────────────────────────────────────────────────────────────────────────────
create extension if not exists pgcrypto;

-- ─────────────────────────────────────────────────────────────────────────────
-- Grants (same as previous migration to ensure no regression)
-- ─────────────────────────────────────────────────────────────────────────────
grant execute on function public.verify_and_process_razorpay_payment_rpc(text, text, text, text, text, numeric, uuid) to authenticated;

-- 202608070013_init_vault_secrets.sql
-- ─────────────────────────────────────────────────────────────────────────────
-- One-time Vault initialization migration.
-- This migration stores the Razorpay webhook signing secret in Supabase Vault
-- so it is encrypted at rest via pgsodium and never appears in SQL function bodies.
--
-- IMPORTANT: After applying this migration, rotate your Razorpay key:
--   1. Go to Razorpay Dashboard → Settings → API Keys → Regenerate Secret
--   2. Update this Vault secret via:
--        select vault.update_secret(<id>, '<new_secret>', 'razorpay_webhook_secret');
--      or from the Supabase Dashboard → Vault → click secret → Edit
--
-- This migration is idempotent: safe to apply multiple times.
-- ─────────────────────────────────────────────────────────────────────────────

do $$
declare
  v_existing_id uuid;
begin
  -- Check whether the secret is already stored (prevents duplicate on re-run)
  select id into v_existing_id
  from   vault.secrets
  where  name = 'razorpay_webhook_secret'
  limit  1;

  if v_existing_id is null then
    -- vault.create_secret encrypts the value with pgsodium automatically.
    -- The raw value is never stored in plaintext in pg_catalog or pg_toast.
    perform vault.create_secret(
      'ehrQ4edUdNzEZqtTE334Lcsf',
      'razorpay_webhook_secret',
      'Razorpay webhook HMAC-SHA256 signing secret — rotate after first deploy'
    );

    raise notice '[Vault] Secret ''razorpay_webhook_secret'' created and encrypted at rest.';
  else
    raise notice '[Vault] Secret ''razorpay_webhook_secret'' already present (id: %). No action taken.', v_existing_id;
  end if;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Verify the secret is readable through the decrypted view
-- (The RPC function reads it from here at call-time)
-- ─────────────────────────────────────────────────────────────────────────────
do $$
declare
  v_check text;
begin
  select decrypted_secret into v_check
  from   vault.decrypted_secrets
  where  name = 'razorpay_webhook_secret'
  limit  1;

  if v_check is null then
    raise exception '[Vault] CRITICAL: Secret ''razorpay_webhook_secret'' was inserted but cannot be read back from vault.decrypted_secrets. Check pgsodium configuration.';
  else
    raise notice '[Vault] Verification passed: secret is readable through vault.decrypted_secrets.';
  end if;
end;
$$;

-- Migration: 202608070015_balanced_free_ap_earning_system.sql
-- Description: Balanced Free AP Earning System (Unique Seat Join Bonus +20 AP, First Gift Bonus +5 AP, Active Seat Time Reward 4 AP/min/seat, anti-abuse guards, and Realtime sync).

-- 0. Ensure Room Dual Progress Table exists
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

do $$
begin
  alter publication supabase_realtime add table public.room_dual_progress;
exception when others then
  raise notice 'Table room_dual_progress already in supabase_realtime publication';
end;
$$;

-- 2. Add tracking columns to public.room_dual_progress
alter table public.room_dual_progress add column if not exists unique_join_count integer default 0 not null check (unique_join_count >= 0);

alter table public.room_dual_progress add column if not exists first_gift_bonus_count integer default 0 not null check (first_gift_bonus_count >= 0);

alter table public.room_dual_progress add column if not exists active_seat_minutes integer default 0 not null check (active_seat_minutes >= 0);

drop policy if exists "Allow read access on room_daily_user_bonuses" on public.room_daily_user_bonuses;

drop policy if exists "Allow insert/update access on room_daily_user_bonuses" on public.room_daily_user_bonuses;

-- Migration: 202608070028_fix_gold_duplication_and_wallet_security.sql
-- Description: Permanent resolution for wallet Gold duplication / auto-increase bug.
-- Enforces zero default auto-topups, revokes client wallet update RLS, adds atomic FOR UPDATE row locks,
-- strict balance checks, full transaction audit logging, and guarantees Gold balance only increases via valid purchases or lucky gift returns.

-- 1. Reset public.wallets column defaults to 0
alter table public.wallets alter column coins_balance set default 0;

alter table public.wallets alter column gold_coins set default 0;

alter table public.wallets alter column silver_coins set default 0;

-- 2. Revoke direct client UPDATE policy on public.wallets to prevent front-end balance tampering
drop policy if exists "Users can update their own wallet" on public.wallets;

drop policy if exists "Allow update on wallets" on public.wallets;

-- Ensure SELECT policy exists for users to view their own balance
drop policy if exists "Users can view their own wallet" on public.wallets;

-- Migration: 202608070029_universal_gems_system.sql
-- Description: Comprehensive Universal Gems System (Gift Value System).
-- Establishes permanent gem_value across gift_catalog, updates atomic send_star_gift RPC to calculate all gift values in Gems,
-- sets 1 Gem = 1 Room XP, and updates all gift statistics, leaderboards, room stats, and user contribution stats to use Gems.

-- 1. Gift Catalog Table Schema Enhancement
alter table public.gift_catalog add column if not exists gem_value integer default 0;

alter table public.gift_catalog add column if not exists gold_price integer default null;

alter table public.gift_catalog add column if not exists silver_price integer default null;

alter table public.gift_catalog add column if not exists is_volt boolean default false;

alter table public.gift_catalog add column if not exists gift_type text default 'normal';

-- Drop old currency check constraint if present and recreate to allow ('gold', 'silver', 'volt')
alter table public.gift_catalog drop constraint if exists gift_catalog_currency_check;

alter table public.gift_catalog add constraint gift_catalog_currency_check check (currency in ('gold', 'silver', 'volt'));

-- 2. Ensure Categories Exist (Gold, Silver, Volt)
insert into public.gift_categories (id, name, icon, display_order) values
('c1000000-0000-0000-0000-000000000001', 'Gold', '⭐', 1),
('c1000000-0000-0000-0000-000000000002', 'Silver', '🪙', 2),
('c1000000-0000-0000-0000-000000000003', 'Volt', '⚡', 3)
on conflict (id) do update set name = excluded.name, icon = excluded.icon, display_order = excluded.display_order;

-- 3. Populate / Synchronize Gift Catalog with Permanent Gem Values & Prices
delete from public.gift_catalog;

-- 4. Transaction Ledger & Statistics Schema Compatibility
alter table public.gift_transactions add column if not exists gems_value numeric default 0;

alter table public.gift_history add column if not exists gems_value numeric default 0;

alter table public.gift_statistics add column if not exists gems_sent_lifetime numeric default 0;

alter table public.gift_statistics add column if not exists gems_received_lifetime numeric default 0;

alter table public.rooms add column if not exists total_room_gems numeric default 0;

alter table public.rooms add column if not exists today_room_gems numeric default 0;

alter table public.room_seats add column if not exists seat_total_gems numeric default 0;

ALTER TABLE public.gift_transactions ADD COLUMN IF NOT EXISTS gems_value numeric DEFAULT 0;

-- Migration: 202608080006_seat_session_gem_system.sql
-- Description: State-based seat-session Gem counter system, root cause fix for unwanted 0 resets, atomic backend gift processing, room total/today gems tracking, duplicate event protection, and 1:1 Gold Coin to Room AP conversion.

BEGIN;

-- 1. Schema Enhancements on public.room_seats, public.room_members & public.rooms
ALTER TABLE public.room_seats ADD COLUMN IF NOT EXISTS seat_session_id text DEFAULT NULL;

ALTER TABLE public.room_seats ADD COLUMN IF NOT EXISTS seat_session_gems integer DEFAULT 0;

ALTER TABLE public.room_seats ADD COLUMN IF NOT EXISTS seat_total_gems numeric DEFAULT 0;

ALTER TABLE public.room_seats ADD COLUMN IF NOT EXISTS seat_total_stars numeric DEFAULT 0;

ALTER TABLE public.room_members ADD COLUMN IF NOT EXISTS seat_number integer DEFAULT NULL;

ALTER TABLE public.room_members ADD COLUMN IF NOT EXISTS seat_index integer DEFAULT NULL;

ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS total_room_gems numeric DEFAULT 0;

ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS today_room_gems numeric DEFAULT 0;

-- 2. Enhanced join_room_seat RPC to generate unique seat_session_id and initialize counter to 0
DROP FUNCTION IF EXISTS public.join_room_seat(text, integer);

DROP FUNCTION IF EXISTS public.join_room_seat(uuid, integer);

-- 3. Enhanced leave_room_seat RPC (resets ONLY specific left seat to 0)
DROP FUNCTION IF EXISTS public.leave_room_seat(text, integer);

DROP FUNCTION IF EXISTS public.leave_room_seat(uuid, integer);

-- 4. Atomic send_star_gift RPC with Seat Session Gem & Room Total/Today Gems
DROP FUNCTION IF EXISTS public.send_star_gift(text, uuid[], uuid, integer, integer, integer[]);

DROP FUNCTION IF EXISTS public.send_star_gift(uuid, uuid[], uuid, integer, integer, integer[]);

-- 5. Enhanced get_room_state_snapshot RPC to include seat_session_gems and total_room_gems
DROP FUNCTION IF EXISTS public.get_room_state_snapshot(text);

DROP FUNCTION IF EXISTS public.get_room_state_snapshot(uuid);

COMMIT;

-- Drop legacy table constraints to allow Coins, Gold Coins, Signup Reward, etc.
ALTER TABLE public.wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_type_check;

ALTER TABLE public.wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_currency_check;

-- 2. Store Configurations Table
CREATE TABLE IF NOT EXISTS public.store_configurations (
  key text PRIMARY KEY,
  config jsonb NOT NULL,
  updated_at timestamptz DEFAULT now()
);

-- Pre-seed production default configurations
INSERT INTO public.store_configurations (key, config, updated_at)
VALUES
  ('recharge_packages', '[
    {"id": "coins_99", "name": "Starter Pack", "price": 99, "base_coins": 50, "bonus_coins": 5, "tag": "Popular"},
    {"id": "coins_199", "name": "Basic Pack", "price": 199, "base_coins": 100, "bonus_coins": 15, "tag": null},
    {"id": "coins_499", "name": "Silver Pack", "price": 499, "base_coins": 250, "bonus_coins": 50, "tag": "Best Value"},
    {"id": "coins_999", "name": "Gold Pack", "price": 999, "base_coins": 500, "bonus_coins": 125, "tag": "Popular"},
    {"id": "coins_1999", "name": "Diamond Pack", "price": 1999, "base_coins": 1000, "bonus_coins": 199, "tag": "Mega Bonus"},
    {"id": "coins_4999", "name": "Elite Pack", "price": 4999, "base_coins": 2500, "bonus_coins": 399, "tag": "Pro Choice"},
    {"id": "coins_9999", "name": "Legend Pack", "price": 9999, "base_coins": 5000, "bonus_coins": 599, "tag": "Crown Value"}
  ]'::jsonb, now()),

  ('first_purchase_config', '{
    "enabled": true,
    "bonus_coins": 50,
    "vip_bonus_days": 3,
    "novel_bonus_days": 3,
    "frame_name": "Royal Frame",
    "badge_name": "Pioneer Badge"
  }'::jsonb, now()),

  ('first_vip_purchase_config', '{
    "enabled": true,
    "bonus_days": 3,
    "bonus_coins": 20,
    "frame_name": "VIP Crown Frame",
    "badge_name": "VIP Pioneer"
  }'::jsonb, now()),

  ('first_novel_purchase_config', '{
    "enabled": true,
    "bonus_days": 3,
    "bonus_coins": 20,
    "frame_name": "Novel Reader Frame",
    "badge_name": "Novel Pioneer"
  }'::jsonb, now()),

  ('vip_packages_config', '{
    "30 Days": {"base_days": 30, "bonus_days": 3},
    "1 Month": {"base_days": 30, "bonus_days": 3},
    "90 Days": {"base_days": 90, "bonus_days": 10},
    "3 Months": {"base_days": 90, "bonus_days": 10},
    "365 Days": {"base_days": 365, "bonus_days": 30},
    "1 Year": {"base_days": 365, "bonus_days": 30}
  }'::jsonb, now()),

  ('novel_packages_config', '{
    "30 Days": {"base_days": 30, "bonus_days": 3},
    "1 Month": {"base_days": 30, "bonus_days": 3},
    "90 Days": {"base_days": 90, "bonus_days": 10},
    "3 Months": {"base_days": 90, "bonus_days": 10},
    "365 Days": {"base_days": 365, "bonus_days": 30},
    "1 Year": {"base_days": 365, "bonus_days": 30}
  }'::jsonb, now()),

  ('signup_reward_coins', '50'::jsonb, now())

ON CONFLICT (key) DO UPDATE
SET config = EXCLUDED.config, updated_at = now();

GRANT EXECUTE ON FUNCTION public.claim_signup_reward_rpc(uuid) TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.purchase_and_activate_rpc(uuid,text,text,numeric,numeric,text,text,text,text) TO authenticated, service_role;

-- Migration 202608110002_smart_content_discovery_system.sql
-- Creania Smart Content Discovery, Hashtag, Music Catalog, Anti-Bot & Multi-Factor Trending Engine

-- 1. Extend posts table with unified entity columns
alter table public.posts 
  add column if not exists title text default '',
  add column if not exists description text default '',
  add column if not exists audio_id uuid default null,
  add column if not exists category_id text default 'general',
  add column if not exists language text default 'en',
  add column if not exists hashtags text[] default '{}',
  add column if not exists mentions text[] default '{}',
  add column if not exists moderation_status text default 'approved',
  add column if not exists quality_score numeric default 1.0,
  add column if not exists engagement_score numeric default 0.0,
  add column if not exists trend_score numeric default 0.0,
  add column if not exists relevance_score numeric default 1.0,
  add column if not exists freshness_score numeric default 1.0,
  add column if not exists safety_score numeric default 1.0,
  add column if not exists spam_score numeric default 0.0;

create index if not exists idx_content_engagements_post_id on public.content_engagements (post_id, created_at desc);

-- 1. Ensure wallets table defaults and topup values for silver coins
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS silver_coins_balance INTEGER DEFAULT 1000000;

ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS silver_coins INTEGER DEFAULT 1000000;

UPDATE public.wallets
SET silver_coins_balance = GREATEST(COALESCE(silver_coins_balance, 0), COALESCE(silver_coins, 0), 1000000),
    silver_coins = GREATEST(COALESCE(silver_coins, 0), COALESCE(silver_coins_balance, 0), 1000000),
    coins_balance = GREATEST(COALESCE(coins_balance, 0), COALESCE(gold_coins, 0), 1000000),
    gold_coins = GREATEST(COALESCE(gold_coins, 0), COALESCE(coins_balance, 0), 1000000);

-- Migration: 202608110005_creania_balance_economy.sql
-- Description: Complete Creania Balance (CB) economy, gift reward engine, weekend family settlement, exchange system, and withdrawal pipeline.

BEGIN;

-- 1. Centralized System Conversion & Economy Configuration Table
CREATE TABLE IF NOT EXISTS public.cb_system_config (
  id INTEGER PRIMARY KEY DEFAULT 1,
  cb_per_inr NUMERIC DEFAULT 250.0 CHECK (cb_per_inr > 0), -- 500 CB = ₹2.00 -> 250 CB per ₹1
  gold_receiver_cb_ratio NUMERIC DEFAULT 50.0 CHECK (gold_receiver_cb_ratio >= 0), -- 100 Gold = 5,000 CB (50 CB per Gold)
  gold_room_owner_cb_ratio NUMERIC DEFAULT 25.0 CHECK (gold_room_owner_cb_ratio >= 0), -- 100 Gold = 2,500 CB (25 CB per Gold)
  gold_community_cb_ratio NUMERIC DEFAULT 15.0 CHECK (gold_community_cb_ratio >= 0), -- 100 Gold = 1,500 CB (15 CB per Gold)
  gold_family_cb_ratio NUMERIC DEFAULT 10.0 CHECK (gold_family_cb_ratio >= 0), -- 100 Gold = 1,000 CB (10 CB per Gold)
  silver_gift_reward_rate NUMERIC DEFAULT 0.05 CHECK (silver_gift_reward_rate >= 0), -- Fractional CB for silver gifts
  volt_gift_reward_rate NUMERIC DEFAULT 0.10 CHECK (volt_gift_reward_rate >= 0), -- Fractional CB for volt gifts
  special_gift_reward_rate NUMERIC DEFAULT 1.00 CHECK (special_gift_reward_rate >= 0),
  min_exchange_cb BIGINT DEFAULT 5000 CHECK (min_exchange_cb >= 0), -- Min 5,000 CB = 10 Gold Coins (₹20)
  min_withdrawal_cb BIGINT DEFAULT 250000 CHECK (min_withdrawal_cb >= 0), -- Min 250,000 CB = ₹1,000.00 (Razorpay Instant Payouts)
  withdrawal_fee_percent NUMERIC DEFAULT 0.0 CHECK (withdrawal_fee_percent >= 0),
  promotional_bonus_percent NUMERIC DEFAULT 5.0 CHECK (promotional_bonus_percent >= 0),
  promotional_bonus_max_budget NUMERIC DEFAULT 100000.0 CHECK (promotional_bonus_max_budget >= 0),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default config if empty
INSERT INTO public.cb_system_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- 2. Extend Wallets Table with Creania Balance Fields
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS creania_balance BIGINT DEFAULT 0 CHECK (creania_balance >= 0);

ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS pending_cb_balance BIGINT DEFAULT 0 CHECK (pending_cb_balance >= 0);

ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS lifetime_earned_cb BIGINT DEFAULT 0;

ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS lifetime_withdrawn_cb BIGINT DEFAULT 0;

ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS gift_earnings_cb BIGINT DEFAULT 0;

ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS room_earnings_cb BIGINT DEFAULT 0;

ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS community_earnings_cb BIGINT DEFAULT 0;

ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS family_earnings_cb BIGINT DEFAULT 0;

ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS kyc_verified BOOLEAN DEFAULT false;

ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS upi_id TEXT;

ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS bank_account_name TEXT;

CREATE INDEX IF NOT EXISTS idx_cb_ledger_user ON public.cb_ledger_entries(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_cb_ledger_idempotency ON public.cb_ledger_entries(idempotency_key);

CREATE INDEX IF NOT EXISTS idx_family_pending_owner ON public.family_pending_rewards(family_owner_id, status);

CREATE INDEX IF NOT EXISTS idx_cb_withdrawals_user ON public.cb_withdrawals(user_id, created_at DESC);

DROP POLICY IF EXISTS "Public read cb_system_config" ON public.cb_system_config;

DROP POLICY IF EXISTS "User read own ledger" ON public.cb_ledger_entries;

DROP POLICY IF EXISTS "User read own family pending rewards" ON public.family_pending_rewards;

DROP POLICY IF EXISTS "User read own family settlements" ON public.family_settlement_history;

DROP POLICY IF EXISTS "User read own withdrawals" ON public.cb_withdrawals;

-- Migration: 202608110006_lucky_gift_ap_gem_reward_system.sql
-- Description: Production-Ready Server-Authoritative Lucky Gift AP + Gem Reward Engine with Anti-Farming Protection, Idempotency Ledger, and 5+ Gold Coin Threshold.

-- 1. Remove Lucky/Magic tag from 1-4 Gold Coin gifts. Lucky gifts start from 5 Gold Coins and above.
ALTER TABLE public.gift_catalog ADD COLUMN IF NOT EXISTS is_lucky boolean DEFAULT false;

ALTER TABLE public.gift_catalog ADD COLUMN IF NOT EXISTS is_magic boolean DEFAULT false;

ALTER TABLE public.gift_catalog ADD COLUMN IF NOT EXISTS gold_price integer DEFAULT NULL;

UPDATE public.gift_catalog
SET is_lucky = false, is_magic = false
WHERE (COALESCE(cost_stars, 0) < 5 OR COALESCE(gold_price, 0) < 5)
  AND LOWER(COALESCE(currency, 'gold')) = 'gold';

-- Ensure gifts costing 5+ Gold tagged as lucky/magic remain active lucky gifts
UPDATE public.gift_catalog
SET is_lucky = true
WHERE COALESCE(cost_stars, 0) >= 5
  AND LOWER(COALESCE(currency, 'gold')) = 'gold'
  AND (is_magic = true OR name IN ('Cake', 'Butterfly', 'Gift Box', 'Teddy', 'Lucky Clover', 'Diamond Ring', 'Champion Trophy', 'Super Car', 'Golden Dragon'));

GRANT EXECUTE ON FUNCTION public.calculate_lucky_gift_reward(integer) TO authenticated, service_role, anon;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'lucky_gift_reward_ledger' AND policyname = 'Allow select for authenticated users') THEN
    CREATE POLICY "Allow select for authenticated users" ON public.lucky_gift_reward_ledger FOR SELECT TO authenticated USING (true);
  END IF;
END $$;

GRANT EXECUTE ON FUNCTION public.send_star_gift(text, uuid[], uuid, integer, integer, integer[], text, uuid) TO authenticated, service_role, anon;

-- Ensure all required columns exist on pre-existing user_sessions table
ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS session_id text;

ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS device_id text;

ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS device_name text DEFAULT 'Unknown Device';

ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS device_model text DEFAULT '';

ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS platform text DEFAULT 'Mobile';

ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS os_version text DEFAULT '';

ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS app_version text DEFAULT '';

ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS browser text DEFAULT '';

ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS ip_address text DEFAULT '127.0.0.1';

ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS country text DEFAULT 'India';

ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS city text DEFAULT '';

ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS created_at timestamp with time zone DEFAULT timezone('utc'::text, now());

ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS last_active_at timestamp with time zone DEFAULT timezone('utc'::text, now());

ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS expires_at timestamp with time zone DEFAULT (timezone('utc'::text, now()) + interval '90 days');

ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS revoked_at timestamp with time zone DEFAULT NULL;

-- Ensure session_id has unique constraint if table was altered
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'user_sessions_session_id_key'
  ) THEN
    BEGIN
      ALTER TABLE public.user_sessions ADD CONSTRAINT user_sessions_session_id_key UNIQUE (session_id);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;
END $$;

-- Indexes for ultra-fast session validation & queries
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON public.user_sessions(user_id);

CREATE INDEX IF NOT EXISTS idx_user_sessions_session_id ON public.user_sessions(session_id);

CREATE INDEX IF NOT EXISTS idx_user_sessions_device_id ON public.user_sessions(device_id);

CREATE INDEX IF NOT EXISTS idx_user_sessions_revoked_at ON public.user_sessions(revoked_at);

CREATE INDEX IF NOT EXISTS idx_user_sessions_last_active_at ON public.user_sessions(last_active_at);

DROP POLICY IF EXISTS "Users can view their own sessions" ON public.user_sessions;

DROP POLICY IF EXISTS "Users can update their own sessions" ON public.user_sessions;

DROP POLICY IF EXISTS "Users can insert their own sessions" ON public.user_sessions;

-- Ensure missing columns exist if table was previously defined
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_login_activity' AND column_name='event_type') THEN
    ALTER TABLE public.user_login_activity ADD COLUMN event_type text NOT NULL DEFAULT 'Successful Login';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_login_activity' AND column_name='status') THEN
    ALTER TABLE public.user_login_activity ADD COLUMN status text DEFAULT 'success';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_login_activity' AND column_name='failure_reason') THEN
    ALTER TABLE public.user_login_activity ADD COLUMN failure_reason text DEFAULT NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_login_activity' AND column_name='auth_method') THEN
    ALTER TABLE public.user_login_activity ADD COLUMN auth_method text DEFAULT 'Password';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_login_activity' AND column_name='country') THEN
    ALTER TABLE public.user_login_activity ADD COLUMN country text DEFAULT 'India';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_user_login_activity_user_id ON public.user_login_activity(user_id);

CREATE INDEX IF NOT EXISTS idx_user_login_activity_login_at ON public.user_login_activity(login_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_login_activity_event_type ON public.user_login_activity(event_type);

DROP POLICY IF EXISTS "Users can view their own login activity" ON public.user_login_activity;

DROP POLICY IF EXISTS "Users can insert login activity" ON public.user_login_activity;

-- 202608120003_authoritative_wallet_security_and_audit.sql
-- AUTHORITATIVE WALLET SECURITY, IDEMPOTENT TRANSACTION PROCESSOR & COMPLETE AUDIT TRAIL

-- 1. Ensure wallets table schema columns exist
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS coins_balance bigint DEFAULT 0;

ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS gold_coins bigint DEFAULT 0;

ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS silver_coins_balance bigint DEFAULT 0;

ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS silver_coins bigint DEFAULT 0;

ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS withdrawable_balance numeric(12,2) DEFAULT 0.00;

ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS currency_type text DEFAULT 'Gold';

ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS currency text DEFAULT 'Gold';

ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS previous_balance numeric(12,2) DEFAULT 0.00;

ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS new_balance numeric(12,2) DEFAULT 0.00;

ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS transaction_id text;

ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS reference_id text;

ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS details text;

-- Backfill user_id from wallet_id if pre-existing rows have user_id null
UPDATE public.wallet_transactions 
SET user_id = wallet_id 
WHERE user_id IS NULL AND wallet_id IS NOT NULL;

-- Backfill wallet_id from user_id if pre-existing rows have wallet_id null
UPDATE public.wallet_transactions 
SET wallet_id = user_id 
WHERE wallet_id IS NULL AND user_id IS NOT NULL;

-- Add UNIQUE constraint to transaction_id if not present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'wallet_transactions_transaction_id_key'
  ) THEN
    ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_transaction_id_key UNIQUE (transaction_id);
  END IF;
END $$;

-- Index for fast idempotency lookups & audit logs
CREATE INDEX IF NOT EXISTS idx_wallet_tx_transaction_id ON public.wallet_transactions(transaction_id);

CREATE INDEX IF NOT EXISTS idx_wallet_tx_user_created ON public.wallet_transactions(user_id, created_at DESC);

DROP POLICY IF EXISTS "Users can view own wallet" ON public.wallets;

-- Revoke direct table updates from client-side REST requests
DROP POLICY IF EXISTS "Users cannot update own wallet directly" ON public.wallets;

DROP POLICY IF EXISTS "Users cannot insert wallet directly" ON public.wallets;

-- 5. Sanitize any legacy test/artificially inflated balances (> 100,000,000) down to reasonable caps
UPDATE public.wallets
SET 
  coins_balance        = LEAST(coins_balance, 50000),
  gold_coins           = LEAST(gold_coins, 50000),
  silver_coins_balance = LEAST(silver_coins_balance, 100000),
  silver_coins         = LEAST(silver_coins, 100000)
WHERE coins_balance > 100000000 OR silver_coins_balance > 100000000 OR gold_coins > 100000000;

DROP POLICY IF EXISTS "Allow select payments for self and admins" ON public.payments;

GRANT EXECUTE ON FUNCTION public.process_verified_payment_recharge_rpc(uuid, text, numeric, integer, text, text, text, text) TO authenticated, service_role;

-- 3. Ensure initialize_user_wallet trigger creates wallets with 0 balance
create or replace function public.initialize_user_wallet()
returns trigger as $$
begin
  insert into public.wallets (id, coins_balance, gold_coins, silver_coins, inr_balance, withdrawable_balance)
  values (new.id, 0, 0, 0, 0.00, 0.00)
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

-- 202607090023_fix_wallet_transaction_schema.sql
-- Fixes broken RPCs that use the old wallet_transactions schema.
-- Migration 202607090020 dropped and recreated wallet_transactions without
-- the 'transaction_type' column. This patch rewrites all affected functions
-- to use the correct columns: currency, type, status, details.
-- Also adds the missing generate_unique_room_id() helper function.

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. Create missing helper: generate_unique_room_id()
--    Generates a short unique 6-char alphanumeric room ID (e.g. "A3K9ZX").
--    Called by create_room() but was never defined in any earlier migration.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.generate_unique_room_id()
returns text
language plpgsql
as $$
declare
  v_id text;
begin
  loop
    -- Generate a random 8-digit number (10000000–99999999)
    v_id := (floor(random() * 90000000) + 10000000)::bigint::text;
    exit when not exists (select 1 from public.rooms where id = v_id);
  end loop;
  return v_id;
end;
$$;

-- 5. Permission Checking Helper Function
create or replace function public.check_community_permission(
  p_community_id text,
  p_user_id uuid,
  p_action text
)
returns boolean as $$
declare
  v_role text;
begin
  select role into v_role 
  from public.community_memberships 
  where community_id = p_community_id and user_id = p_user_id;

  if v_role is null then
    return false;
  end if;

  -- Owner can perform any action
  if v_role = 'owner' then
    return true;
  end if;

  -- Co-Owner permissions
  if v_role = 'co_owner' then
    return p_action in (
      'edit_settings',
      'manage_announcements',
      'manage_events',
      'invite_members',
      'remove_members',
      'view_logs',
      'view_analytics'
    );
  end if;

  -- Admin permissions
  if v_role = 'admin' then
    return p_action in (
      'manage_events',
      'invite_members',
      'remove_members',
      'view_members'
    );
  end if;

  -- Member permissions
  if v_role = 'member' then
    return p_action in (
      'participate_events',
      'chat'
    );
  end if;

  return false;
end;
$$ language plpgsql security definer;

-- 6. Announcements management RPCs
create or replace function public.create_announcement_rpc(
  p_community_id text,
  p_title text,
  p_content text,
  p_is_pinned boolean
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  if not public.check_community_permission(p_community_id, v_user_id, 'manage_announcements') then
    return jsonb_build_object('success', false, 'error', 'Unauthorized to manage announcements.');
  end if;

  -- Insert announcement
  insert into public.community_announcements (community_id, title, content, is_pinned, created_by)
  values (p_community_id, p_title, p_content, p_is_pinned, v_user_id);

  -- Log action
  insert into public.community_logs (community_id, user_id, action_type, description)
  values (p_community_id, v_user_id, 'announcement_created', 'Announcement created: ' || p_title);

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

create or replace function public.delete_announcement_rpc(
  p_community_id text,
  p_announcement_id uuid
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  if not public.check_community_permission(p_community_id, v_user_id, 'manage_announcements') then
    return jsonb_build_object('success', false, 'error', 'Unauthorized to manage announcements.');
  end if;

  delete from public.community_announcements 
  where community_id = p_community_id and id = p_announcement_id;

  -- Log action
  insert into public.community_logs (community_id, user_id, action_type, description)
  values (p_community_id, v_user_id, 'announcement_deleted', 'Announcement deleted.');

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

create or replace function public.pin_announcement_rpc(
  p_community_id text,
  p_announcement_id uuid,
  p_is_pinned boolean
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  if not public.check_community_permission(p_community_id, v_user_id, 'manage_announcements') then
    return jsonb_build_object('success', false, 'error', 'Unauthorized to manage announcements.');
  end if;

  update public.community_announcements
  set is_pinned = p_is_pinned
  where community_id = p_community_id and id = p_announcement_id;

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

-- 7. Community events management RPCs
create or replace function public.create_community_event_rpc(
  p_community_id text,
  p_name text,
  p_banner text,
  p_description text,
  p_start_time timestamp with time zone,
  p_end_time timestamp with time zone,
  p_host_id uuid,
  p_co_hosts uuid[],
  p_max_participants integer,
  p_rewards text,
  p_rules text
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  if not public.check_community_permission(p_community_id, v_user_id, 'manage_events') then
    return jsonb_build_object('success', false, 'error', 'Unauthorized to create events.');
  end if;

  insert into public.community_events (
    community_id, name, banner, description, start_time, end_time, host_id, co_hosts, max_participants, rewards, rules, created_by
  ) values (
    p_community_id, p_name, p_banner, p_description, p_start_time, p_end_time, p_host_id, p_co_hosts, p_max_participants, p_rewards, p_rules, v_user_id
  );

  insert into public.community_logs (community_id, user_id, action_type, description)
  values (p_community_id, v_user_id, 'event_created', 'Event created: ' || p_name);

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

create or replace function public.register_for_event_rpc(
  p_event_id uuid
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_event record;
  v_current_count integer;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  select * into v_event from public.community_events where id = p_event_id;
  if not found then
    return jsonb_build_object('success', false, 'error', 'Event not found.');
  end if;

  -- Ensure they belong to the community hosting the event
  if not exists (
    select 1 from public.community_memberships 
    where community_id = v_event.community_id and user_id = v_user_id
  ) then
    return jsonb_build_object('success', false, 'error', 'You must be a member of the community to register.');
  end if;

  -- Check max participants cap
  if v_event.max_participants > 0 then
    select count(*) into v_current_count from public.community_event_participants where event_id = p_event_id;
    if v_current_count >= v_event.max_participants then
      return jsonb_build_object('success', false, 'error', 'Event registration is full.');
    end if;
  end if;

  insert into public.community_event_participants (event_id, user_id)
  values (p_event_id, v_user_id)
  on conflict (event_id, user_id) do nothing;

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

create or replace function public.cancel_event_rpc(
  p_community_id text,
  p_event_id uuid
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  if not public.check_community_permission(p_community_id, v_user_id, 'manage_events') then
    return jsonb_build_object('success', false, 'error', 'Unauthorized to manage events.');
  end if;

  update public.community_events
  set status = 'cancelled'
  where community_id = p_community_id and id = p_event_id;

  insert into public.community_logs (community_id, user_id, action_type, description)
  values (p_community_id, v_user_id, 'event_updated', 'Event cancelled.');

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

-- 9. Analytics RPC Dashboard
create or replace function public.get_community_analytics_rpc(p_community_id text)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_total_members integer;
  v_daily_active integer;
  v_weekly_active integer;
  v_monthly_active integer;
  v_total_exp bigint;
  v_current_level integer;
  v_join_requests bigint;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  if not public.check_community_permission(p_community_id, v_user_id, 'view_analytics') then
    return jsonb_build_object('success', false, 'error', 'Unauthorized to view analytics.');
  end if;

  select count(*) into v_total_members from public.community_memberships where community_id = p_community_id;
  select count(*) into v_daily_active from public.community_memberships where community_id = p_community_id and last_active_at >= now() - interval '1 day';
  select count(*) into v_weekly_active from public.community_memberships where community_id = p_community_id and last_active_at >= now() - interval '7 days';
  select count(*) into v_monthly_active from public.community_memberships where community_id = p_community_id and last_active_at >= now() - interval '30 days';
  
  select xp, level into v_total_exp, v_current_level from public.communities where id = p_community_id;
  select count(*) into v_join_requests from public.community_applications where community_id = p_community_id and status = 'pending';

  return jsonb_build_object(
    'success', true,
    'total_members', v_total_members,
    'daily_active', v_daily_active,
    'weekly_active', v_weekly_active,
    'monthly_active', v_monthly_active,
    'total_exp', v_total_exp,
    'current_level', v_current_level,
    'pending_join_requests', v_join_requests
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

-- 7. Magic Gift lottery draw logic function
create or replace function public.draw_magic_gift_reward(
  p_sender_id uuid,
  p_gift_id uuid,
  p_cost integer
) returns jsonb as $$
declare
  v_payout_rule record;
  v_budget record;
  v_rand numeric;
  v_current_ratio numeric;
  v_outcome_type text := 'nothing';
  v_outcome_multiplier integer := 0;
  v_silver_reward integer := 0;
  v_vault_item_id uuid := null;
  v_vault_item_name text := '';
  v_final_payout_cost integer := 0;
  
  -- Probability cumulative boundary
  v_cumulative numeric := 0;
begin
  select * into v_budget from public.magic_gift_budget where id = 'global';
  
  -- Update sold total
  update public.magic_gift_budget
  set total_sold_coins = total_sold_coins + p_cost
  where id = 'global';
  
  -- Calculate current payout ratio
  if coalesce(v_budget.total_sold_coins, 0) > 0 then
    v_current_ratio := coalesce(v_budget.total_payout_coins, 0) / coalesce(v_budget.total_sold_coins, 0);
  else
    v_current_ratio := 0;
  end if;

  -- Draw a random number
  v_rand := random();
  
  -- Iterate through rules for this price category
  for v_payout_rule in (
    select * from public.magic_gift_rewards 
    where price_coins = p_cost 
    order by probability asc
  ) loop
    v_cumulative := v_cumulative + v_payout_rule.probability;
    if v_rand <= v_cumulative then
      -- Verify economy safeguard
      if v_payout_rule.payout_type = 'coin_back' then
        v_final_payout_cost := p_cost * v_payout_rule.multiplier;
      else
        v_final_payout_cost := 0;
      end if;
      
      if v_current_ratio >= v_budget.max_payout_ratio and v_final_payout_cost > 0 then
        v_outcome_type := 'nothing';
        v_outcome_multiplier := 0;
      else
        v_outcome_type := v_payout_rule.payout_type;
        v_outcome_multiplier := v_payout_rule.multiplier;
        v_silver_reward := v_payout_rule.silver_amount;
        v_vault_item_id := v_payout_rule.vault_definition_id;
      end if;
      exit;
    end if;
  end loop;

  -- Deliver rewards
  if v_outcome_type = 'coin_back' and v_outcome_multiplier > 0 then
    update public.wallets set coins_balance = coins_balance + v_final_payout_cost where id = p_sender_id;
    update public.magic_gift_budget set total_payout_coins = total_payout_coins + v_final_payout_cost where id = 'global';
  elsif v_outcome_type = 'silver_reward' and v_silver_reward > 0 then
    update public.wallets set silver_coins_balance = silver_coins_balance + v_silver_reward where id = p_sender_id;
  end if;

  -- Log rewards draw
  insert into public.magic_reward_logs (user_id, gift_id, cost_coins, payout_type, multiplier, coins_back, silver_reward, vault_item_name)
  values (p_sender_id, p_gift_id, p_cost, v_outcome_type, v_outcome_multiplier, v_final_payout_cost, v_silver_reward, v_vault_item_name);

  return jsonb_build_object(
    'payout_type', v_outcome_type,
    'multiplier', v_outcome_multiplier,
    'coins_back', v_final_payout_cost,
    'silver_reward', v_silver_reward,
    'vault_item_name', v_vault_item_name
  );
end;
$$ language plpgsql security definer;

-- 3. Wallet Transactions Notifications
create or replace function public.handle_wallet_transaction_notifications()
returns trigger as $$
begin
  if (new.status = 'Completed') then
    if (new.amount > 0 and new.type in ('Deposit', 'Refund', 'Reward', 'Payout', 'Recharge', 'Bonus', 'Admin Grant')) then
      -- Coins / INR received
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        new.wallet_id,
        'Wallet Credited 🪙',
        'You have received ' || new.amount || ' ' || new.currency || ' (' || new.type || ').',
        'coins_received',
        jsonb_build_object(
          'transactionId', new.id,
          'action', 'credit'
        )
      );
    elsif (new.type = 'Withdrawal') then
      -- Withdrawal success
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        new.wallet_id,
        'Withdrawal Successful ✅',
        'Your withdrawal of ' || new.amount || ' INR has been successfully settled.',
        'withdrawal_success',
        jsonb_build_object(
          'transactionId', new.id,
          'action', 'withdrawal_success'
        )
      );
    end if;
  elsif (new.status = 'Pending') then
    if (new.type = 'Withdrawal') then
      -- Withdrawal requested
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        new.wallet_id,
        'Withdrawal Requested 💸',
        'Your withdrawal request of ' || new.amount || ' INR is pending approval.',
        'withdrawal_requested',
        jsonb_build_object(
          'transactionId', new.id,
          'action', 'withdrawal_requested'
        )
      );
    end if;
  elsif (new.status = 'Failed') then
    if (new.type = 'Withdrawal') then
      -- Withdrawal failed/rejected
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        new.wallet_id,
        'Withdrawal Rejected ❌',
        'Your withdrawal request of ' || new.amount || ' INR was rejected/failed.',
        'withdrawal_rejected',
        jsonb_build_object(
          'transactionId', new.id,
          'action', 'withdrawal_failed'
        )
      );
    end if;
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

-- ─────────────────────────────────────────────────────────────────────────────
-- Keep the backwards-compatibility alias pointing to the updated function
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.verify_and_activate_vip_rpc(
  p_order_id   text,
  p_payment_id text,
  p_signature  text,
  p_product    text,
  p_duration   text,
  p_amount     numeric,
  p_user_id    uuid
)
returns boolean as $$
begin
  return public.verify_and_process_razorpay_payment_rpc(
    p_order_id, p_payment_id, p_signature,
    p_product, p_duration, p_amount, p_user_id
  );
end;
$$ language plpgsql security definer set search_path = public, extensions, vault;

-- 4. Safe purchase_item_with_coins_rpc
create or replace function public.purchase_item_with_coins_rpc(
  p_user_id     uuid,
  p_item_name   text,
  p_item_type   text,
  p_coin_amount int,
  p_duration    text default '30 Days'
) returns boolean as $$
declare
  v_res jsonb;
begin
  if p_item_type in ('VIP', 'Novel') then
    v_res := public.purchase_and_activate_rpc(
      p_user_id        => p_user_id,
      p_product_name   => p_item_name,
      p_category       => p_item_type,
      p_amount         => p_coin_amount::numeric,
      p_final_amount   => p_coin_amount::numeric,
      p_payment_method => 'Gold Coins Wallet',
      p_duration       => p_duration
    );
    return coalesce((v_res->>'success')::boolean, false);
  else
    -- Standard cosmetic item purchase
    return public.record_membership_purchase(
      p_user_id        => p_user_id,
      p_product_name   => p_item_name,
      p_category       => p_item_type,
      p_amount         => p_coin_amount::numeric,
      p_final_amount   => p_coin_amount::numeric,
      p_payment_method => 'Gold Coins Wallet',
      p_duration       => p_duration
    );
  end if;
exception when others then
  return false;
end;
$$ language plpgsql security definer set search_path = public;

-- ─────────────────────────────────────────────────────────────────────────────
-- Rewrite verify_and_process_razorpay_payment_rpc
-- Reads secret from vault.decrypted_secrets with fallback to a named parameter
-- so existing callers are unaffected.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.verify_and_process_razorpay_payment_rpc(
  p_order_id       text,
  p_payment_id     text,
  p_signature      text,
  p_product        text,
  p_duration       text,
  p_amount         numeric,
  p_user_id        uuid
)
returns boolean as $$
declare
  v_secret_key      text;
  v_computed        text;
  v_category        text;
  v_coins_to_add    integer := 0;
  v_wallet_exists   boolean;
  v_match           text[];
begin
  -- ── Input validation ────────────────────────────────────────────────────────
  if p_order_id is null or p_payment_id is null or p_signature is null or p_user_id is null then
    raise exception 'verify_and_process_razorpay_payment_rpc: missing required input parameters';
  end if;

  -- ── Idempotency check ───────────────────────────────────────────────────────
  if exists (select 1 from public.payments where payment_id = p_payment_id and status = 'Success') then
    return true;
  end if;

  -- ── Read secret from Supabase Vault ─────────────────────────────────────────
  -- vault.decrypted_secrets is a VIEW in Supabase that auto-decrypts secrets.
  -- The secret must be stored under the name 'razorpay_webhook_secret'.
  select decrypted_secret
  into   v_secret_key
  from   vault.decrypted_secrets
  where  name = 'razorpay_webhook_secret'
  limit  1;

  if v_secret_key is null then
    raise exception
      'Razorpay secret not configured in Vault. '
      'Please add a secret named ''razorpay_webhook_secret'' in the Supabase Dashboard → Vault.';
  end if;

  -- ── HMAC-SHA256 signature verification ──────────────────────────────────────
  begin
    v_computed := encode(
      extensions.hmac(
        (p_order_id || '|' || p_payment_id)::bytea,
        v_secret_key::bytea,
        'sha256'
      ),
      'hex'
    );
  exception when others then
    begin
      v_computed := encode(
        public.hmac(
          (p_order_id || '|' || p_payment_id)::bytea,
          v_secret_key::bytea,
          'sha256'
        ),
        'hex'
      );
    exception when others then
      v_computed := encode(
        hmac(
          (p_order_id || '|' || p_payment_id)::bytea,
          v_secret_key::bytea,
          'sha256'
        ),
        'hex'
      );
    end;
  end;

  if lower(v_computed) <> lower(p_signature) then
    raise exception 'Razorpay signature mismatch: computed %, got %', v_computed, p_signature;
  end if;

  -- ── Determine payment category ───────────────────────────────────────────────
  if p_product ilike '%Coin%' or p_product ilike '%Recharge%' or p_product ilike '%Pack%' then
    v_category := 'Coins';
  elsif p_product ilike '%Novel%' then
    v_category := 'Novel';
  else
    v_category := 'VIP';
  end if;

  -- ── Process by category ──────────────────────────────────────────────────────
  if v_category = 'Coins' then
    -- Extract coin count from product name (e.g. "Starter Pack (100 Coins)" → 100)
    v_match := regexp_matches(p_product, '(\d[\d,]*)\s*Coins?', 'i');
    if v_match is not null and array_length(v_match, 1) >= 1 then
      v_coins_to_add := replace(v_match[1], ',', '')::integer;
    else
      v_coins_to_add := round(p_amount * 0.50)::integer;
    end if;

    if v_coins_to_add <= 0 then
      v_coins_to_add := 50;
    end if;

    select exists(select 1 from public.wallets where id = p_user_id) into v_wallet_exists;
    if not v_wallet_exists then
      insert into public.wallets (id, gold_coins, coins_balance, silver_coins, diamonds)
      values (p_user_id, v_coins_to_add, v_coins_to_add, 0, 0);
    else
      update public.wallets
      set gold_coins    = coalesce(gold_coins, 0)    + v_coins_to_add,
          coins_balance = coalesce(coins_balance, 0) + v_coins_to_add
      where id = p_user_id;
    end if;

    insert into public.wallet_transactions (
      wallet_id, amount, currency, type, status, reference_id, details, created_at
    ) values (
      p_user_id, p_amount, 'INR', 'Recharge', 'Completed', p_payment_id,
      'Recharged ' || v_coins_to_add || ' Gold Coins', now()
    );

    insert into public.purchases (
      user_id, product_name, category, amount, final_amount,
      payment_method, status, duration, payment_id, created_at
    ) values (
      p_user_id, p_product, 'Coins', p_amount, p_amount,
      'Razorpay Gateway', 'Success', coalesce(p_duration, 'One-Time'), p_payment_id, now()
    );

  else
    -- VIP or Novel membership
    perform public.record_membership_purchase(
      p_user_id,
      p_product,
      v_category,
      p_amount,
      p_amount,
      'Razorpay Gateway',
      coalesce(p_duration, '30 Days'),
      null,           -- p_custom_expiry
      p_payment_id
    );
  end if;

  -- ── Upsert into payments table ───────────────────────────────────────────────
  if exists (select 1 from public.payments where payment_id = p_payment_id) then
    update public.payments
    set status           = 'Success',
        gateway_response = jsonb_build_object(
          'order_id',   p_order_id,
          'payment_id', p_payment_id,
          'signature',  p_signature,
          'product',    p_product,
          'duration',   p_duration,
          'amount',     p_amount
        )
    where payment_id = p_payment_id;
  else
    insert into public.payments (
      payment_id, order_id, user_id, amount, vip_plan,
      status, purchase_date, gateway_response
    ) values (
      p_payment_id, p_order_id, p_user_id, p_amount, p_product,
      'Success', now(),
      jsonb_build_object(
        'order_id',   p_order_id,
        'payment_id', p_payment_id,
        'signature',  p_signature,
        'product',    p_product,
        'duration',   p_duration,
        'amount',     p_amount
      )
    );
  end if;

  return true;
exception
  when others then
    raise; -- full rollback on any error
end;
$$ language plpgsql security definer set search_path = public, extensions, vault;

-- 2. Update join_room_seat_v3 to use standard seat names in exception messages
CREATE OR REPLACE FUNCTION public.join_room_seat_v3(
  p_room_id text,
  p_seat_index int
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_user_id uuid := auth.uid();
  v_room_id uuid;
  v_is_locked boolean := false;
  v_current_occupant uuid;
  v_user_role text := 'Visitor';
  v_is_owner boolean := false;
  v_max_co_hosts int := 1;
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

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated.';
  END IF;

  -- Validate seat index boundaries
  IF p_seat_index < 0 OR p_seat_index >= 10 THEN
    RAISE EXCEPTION 'Invalid seat index. Must be between 0 and 9.';
  END IF;

  -- Check current seat lock status and occupant
  SELECT is_locked, user_id INTO v_is_locked, v_current_occupant
  FROM public.room_seats WHERE room_id = v_room_id AND seat_index = p_seat_index;

  -- Reject if seat is locked and user is not current occupant
  IF v_is_locked IS TRUE AND (v_current_occupant IS NULL OR v_current_occupant != v_user_id) THEN
    RAISE EXCEPTION 'This seat (%s) is locked by room management.', public.get_seat_name(p_seat_index);
  END IF;

  -- Check user permissions for Host and Co Host seats
  SELECT (host_id = v_user_id OR room_owner = v_user_id) INTO v_is_owner FROM public.rooms WHERE id = v_room_id;
  SELECT role INTO v_user_role FROM public.room_members WHERE room_id = v_room_id AND user_id = v_user_id;

  -- Host Seat (seat_index 0)
  IF p_seat_index = 0 THEN
    IF NOT (v_is_owner OR v_user_role IN ('Owner', 'Creator', 'Co-Owner', 'Co Owner', 'Admin', 'Moderator', 'Host')) THEN
      RAISE EXCEPTION 'Host seat is restricted to Room Host, Admins, Co-Owners, or Owner.';
    END IF;
  END IF;

  -- Co Host Seat (seat_index 1)
  IF p_seat_index = 1 THEN
    IF NOT (v_is_owner OR v_user_role IN ('Owner', 'Creator', 'Co-Owner', 'Co Owner', 'Admin', 'Moderator', 'Host')) THEN
      RAISE EXCEPTION 'Co Host seat is restricted to Co-Hosts, Admins, Co-Owners, or Owner.';
    END IF;
  END IF;

  -- Execute seat join in room_seats
  INSERT INTO public.room_seats (room_id, seat_index, user_id, updated_at)
  VALUES (v_room_id, p_seat_index, v_user_id, now())
  ON CONFLICT (room_id, seat_index) DO UPDATE 
    SET user_id = EXCLUDED.user_id, updated_at = now();

  -- Execute seat join in room_members
  INSERT INTO public.room_members (room_id, user_id, seat_number, updated_at)
  VALUES (v_room_id, v_user_id, p_seat_index + 1, now())
  ON CONFLICT (room_id, user_id) DO UPDATE 
    SET seat_number = EXCLUDED.seat_number, updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'seat_index', p_seat_index,
    'seat_name', public.get_seat_name(p_seat_index),
    'user_id', v_user_id
  );
END;
$$;

-- 2. Core Centralized Atomic RPC: process_room_dual_progress
CREATE OR REPLACE FUNCTION public.process_room_dual_progress(
  p_room_id text,
  p_user_id uuid,
  p_points integer,
  p_source text DEFAULT 'gold_gift'
) RETURNS jsonb AS $$
DECLARE
  v_rec record;
  v_source_clean text := lower(coalesce(p_source, 'gold_gift'));
  v_is_gold boolean := (v_source_clean in ('gold_gift', 'gold', 'gold_coin'));
  v_is_silver boolean := (v_source_clean in ('silver_gift', 'silver', 'silver_coin'));
  v_is_volt boolean := (v_source_clean in ('volt_gift', 'volt', 'volt_coin'));
  v_effective_points integer := 0;

  v_current_reset_date date := ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date;
  v_last_reset_date date;

  v_is_weekend boolean := (extract(isodow from ((now() at time zone 'Asia/Kolkata') - interval '4 hours')) in (6, 7));

  v_daily_free integer := 0;
  v_daily_gold integer := 0;
  v_total_task integer := 0;
  v_total_lifetime integer := 0;

  -- Weekday: Free 700 + Gold 1000 = 1700 AP Limit
  -- Weekend: Free 1400 + Gold 2000 = 3400 AP Limit (2x Boost)
  v_free_limit integer := case when v_is_weekend then 1400 else 700 end;
  v_gold_limit integer := case when v_is_weekend then 2000 else 1000 end;

  v_free_capacity integer := 0;
  v_gold_capacity integer := 0;
  v_remaining_gold_points integer := 0;

  v_added_free integer := 0;
  v_added_gold integer := 0;
  v_added_total integer := 0;

  v_room_level integer := 1;
  v_required_task integer := 35500;
  v_did_level_up boolean := false;
BEGIN
  -- Validate Inputs
  IF p_room_id IS NULL OR p_room_id = '' OR p_points <= 0 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Invalid input parameters');
  END IF;

  -- 1. Calculate Effective AP Task Points from Source
  IF v_is_gold THEN
    v_effective_points := p_points; -- 1 Gold Coin = 1 AP = 1 Gem
  ELSIF v_is_silver THEN
    v_effective_points := floor(p_points / 100.0)::integer; -- 100 Silver Coins = 1 Free AP = 1 Gem
  ELSIF v_is_volt THEN
    v_effective_points := p_points; -- Volt AP = 1 Gem
  ELSIF v_source_clean in ('like', 'likes') THEN
    v_effective_points := greatest(1, floor(p_points / 10.0)::integer);
  ELSIF v_source_clean in ('room_stay', 'stay') THEN
    v_effective_points := greatest(1, floor(p_points / 3.0)::integer);
  ELSE
    v_effective_points := p_points; -- Mic time, seat bonus, first gift bonus, etc.
  END IF;

  IF v_effective_points <= 0 THEN
    RETURN jsonb_build_object('success', true, 'added_free', 0, 'added_gold', 0, 'reason', 'Below minimum AP conversion threshold');
  END IF;

  -- 2. Lock & Fetch or Create room_dual_progress record atomically
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

  -- 3. Execute 4:00 AM Server Timezone Daily Reset Check
  v_last_reset_date := coalesce(v_rec.last_reset_date, v_current_reset_date - interval '1 day');
  v_total_task := coalesce(v_rec.total_task, 0);
  v_total_lifetime := coalesce(v_rec.total_lifetime_task, 0);

  IF v_last_reset_date < v_current_reset_date THEN
    v_daily_free := 0;
    v_daily_gold := 0;
    v_last_reset_date := v_current_reset_date;
  ELSE
    v_daily_free := coalesce(v_rec.daily_free_progress, v_rec.normal_points, 0);
    v_daily_gold := coalesce(v_rec.daily_gold_progress, v_rec.gold_points, 0);
  END IF;

  v_room_level := coalesce(v_rec.room_level, 1);

  -- 4. Execute Daily Task Bucket Allocation Logic
  IF v_is_gold THEN
    -- Gold Gifts FIRST fill GOLD TASK up to v_gold_limit
    v_gold_capacity := greatest(0, v_gold_limit - v_daily_gold);
    v_added_gold := least(v_effective_points, v_gold_capacity);

    -- Excess gold AP after Gold Task is complete spills over into NORMAL/FREE TASK
    v_remaining_gold_points := v_effective_points - v_added_gold;
    IF v_remaining_gold_points > 0 THEN
      v_free_capacity := greatest(0, v_free_limit - v_daily_free);
      v_added_free := least(v_remaining_gold_points, v_free_capacity);
    ELSE
      v_added_free := 0;
    END IF;
  ELSE
    -- Silver gifts, Volt gifts, Mic time, Seat bonus, Free activities ONLY increase Free Task!
    -- MUST NEVER increase Gold Task!
    v_free_capacity := greatest(0, v_free_limit - v_daily_free);
    v_added_free := least(v_effective_points, v_free_capacity);
    v_added_gold := 0;
  END IF;

  -- 5. Update State Counters
  v_daily_free := v_daily_free + v_added_free;
  v_daily_gold := v_daily_gold + v_added_gold;

  -- Every valid Daily Task contribution is permanently added to Total Task and Total Lifetime Task
  v_added_total := v_added_free + v_added_gold;
  v_total_task := v_total_task + v_added_total;
  v_total_lifetime := v_total_lifetime + v_added_total;

  -- 6. Room Level Calculation
  v_required_task := public.get_required_task_for_level(v_room_level);

  WHILE v_room_level < 7 AND v_total_task >= v_required_task LOOP
    v_room_level := v_room_level + 1;
    v_total_task := v_total_task - v_required_task;
    v_did_level_up := true;
    v_required_task := public.get_required_task_for_level(v_room_level);
  END LOOP;

  -- 7. Persist to room_dual_progress table
  UPDATE public.room_dual_progress
  SET daily_free_progress = v_daily_free,
      free_task_limit = v_free_limit,
      daily_gold_progress = v_daily_gold,
      gold_task_limit = v_gold_limit,
      total_task = v_total_task,
      total_lifetime_task = v_total_lifetime,
      last_reset_date = v_last_reset_date,
      normal_points = v_daily_free,
      normal_target = v_free_limit,
      gold_points = v_daily_gold,
      gold_target = v_gold_limit,
      room_level = v_room_level,
      updated_at = NOW()
  WHERE room_id = p_room_id;

  RETURN jsonb_build_object(
    'success', true,
    'added_free', v_added_free,
    'added_gold', v_added_gold,
    'daily_free_progress', v_daily_free,
    'free_task_limit', v_free_limit,
    'daily_gold_progress', v_daily_gold,
    'gold_task_limit', v_gold_limit,
    'total_task', v_total_task,
    'total_task_target', v_required_task,
    'total_lifetime_task', v_total_lifetime,
    'room_level', v_room_level,
    'did_level_up', v_did_level_up,
    'is_free_limit_reached', (v_daily_free >= v_free_limit),
    'is_gold_limit_reached', (v_daily_gold >= v_gold_limit)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Atomic RPC 1: claim_unique_seat_bonus (+20 Normal AP for 1st seat occupancy today, max 5 users/day)
create or replace function public.claim_unique_seat_bonus(
  p_room_id text,
  p_user_id uuid
) returns jsonb as $$
declare
  v_today date := ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date;
  v_claimed boolean := false;
  v_unique_count integer := 0;
  v_dual_res jsonb;
begin
  if p_room_id is null or p_room_id = '' or p_user_id is null then
    return jsonb_build_object('success', false, 'reason', 'Invalid parameters');
  end if;

  -- Check if user already claimed seat bonus today in this room
  select has_claimed_seat_bonus into v_claimed
  from public.room_daily_user_bonuses
  where room_id = p_room_id and user_id = p_user_id and task_date = v_today;

  if v_claimed is true then
    return jsonb_build_object('success', false, 'reason', 'Already claimed seat bonus today in this room', 'added_ap', 0);
  end if;

  -- Lock room_dual_progress FOR UPDATE and check unique_join_count cap (Max 5 users)
  insert into public.room_dual_progress (room_id, gold_points, gold_target, normal_points, normal_target, overflow_points, room_level)
  values (p_room_id, 0, 1000, 0, 700, 0, 1)
  on conflict (room_id) do nothing;

  select unique_join_count into v_unique_count
  from public.room_dual_progress
  where room_id = p_room_id
  for update;

  if coalesce(v_unique_count, 0) >= 5 then
    return jsonb_build_object('success', false, 'reason', 'Maximum 5 unique user join bonuses reached today for this room', 'added_ap', 0);
  end if;

  -- Record claim in tracking table
  insert into public.room_daily_user_bonuses (room_id, user_id, task_date, has_claimed_seat_bonus)
  values (p_room_id, p_user_id, v_today, true)
  on conflict (room_id, user_id, task_date) do update set
    has_claimed_seat_bonus = true;

  -- Update count
  update public.room_dual_progress
  set unique_join_count = unique_join_count + 1
  where room_id = p_room_id;

  -- Award +20 Normal AP atomically (Normal Progress ONLY, NEVER Gold Progress)
  v_dual_res := public.process_room_dual_progress(p_room_id, p_user_id, 20, 'seat_join_bonus');

  return jsonb_build_object(
    'success', true,
    'added_ap', 20,
    'unique_join_count', v_unique_count + 1,
    'max_unique_joins', 5,
    'dual_result', v_dual_res
  );
end;
$$ language plpgsql security definer;

-- 4. Atomic RPC 2: process_first_gift_bonus (+5 Normal AP bonus on 1st gift sent today, max 20 users/day)
create or replace function public.process_first_gift_bonus(
  p_room_id text,
  p_user_id uuid
) returns jsonb as $$
declare
  v_today date := ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date;
  v_claimed boolean := false;
  v_gift_count integer := 0;
  v_dual_res jsonb;
begin
  if p_room_id is null or p_room_id = '' or p_user_id is null then
    return jsonb_build_object('success', false, 'reason', 'Invalid parameters');
  end if;

  select has_claimed_gift_bonus into v_claimed
  from public.room_daily_user_bonuses
  where room_id = p_room_id and user_id = p_user_id and task_date = v_today;

  if v_claimed is true then
    return jsonb_build_object('success', false, 'reason', 'First gift bonus already claimed today in this room', 'added_ap', 0);
  end if;

  insert into public.room_dual_progress (room_id, gold_points, gold_target, normal_points, normal_target, overflow_points, room_level)
  values (p_room_id, 0, 1000, 0, 700, 0, 1)
  on conflict (room_id) do nothing;

  select first_gift_bonus_count into v_gift_count
  from public.room_dual_progress
  where room_id = p_room_id
  for update;

  if coalesce(v_gift_count, 0) >= 20 then
    return jsonb_build_object('success', false, 'reason', 'Maximum 20 unique user first gift bonuses reached today for this room', 'added_ap', 0);
  end if;

  insert into public.room_daily_user_bonuses (room_id, user_id, task_date, has_claimed_gift_bonus)
  values (p_room_id, p_user_id, v_today, true)
  on conflict (room_id, user_id, task_date) do update set
    has_claimed_gift_bonus = true;

  update public.room_dual_progress
  set first_gift_bonus_count = first_gift_bonus_count + 1
  where room_id = p_room_id;

  -- Award +5 Normal AP bonus atomically (Normal Progress ONLY)
  v_dual_res := public.process_room_dual_progress(p_room_id, p_user_id, 5, 'first_gift_bonus');

  return jsonb_build_object(
    'success', true,
    'added_ap', 5,
    'first_gift_bonus_count', v_gift_count + 1,
    'max_gift_bonuses', 20,
    'dual_result', v_dual_res
  );
end;
$$ language plpgsql security definer;

-- 5. Atomic RPC 3: process_active_seat_time_ap (4 Normal AP / min per active seated user)
create or replace function public.process_active_seat_time_ap(
  p_room_id text,
  p_active_seat_count integer
) returns jsonb as $$
declare
  v_total_ap integer := 0;
  v_dual_res jsonb;
begin
  if p_room_id is null or p_room_id = '' or p_active_seat_count is null or p_active_seat_count <= 0 then
    return jsonb_build_object('success', false, 'reason', 'No active seated users on mic', 'added_ap', 0);
  end if;

  -- Calculate: 4 AP per minute per active seated user (e.g., 1 user = 4 AP, 5 users = 20 AP, 10 users = 40 AP)
  v_total_ap := p_active_seat_count * 4;

  insert into public.room_dual_progress (room_id, gold_points, gold_target, normal_points, normal_target, overflow_points, room_level)
  values (p_room_id, 0, 1000, 0, 700, 0, 1)
  on conflict (room_id) do nothing;

  update public.room_dual_progress
  set active_seat_minutes = active_seat_minutes + 1
  where room_id = p_room_id;

  -- Award v_total_ap Normal AP atomically (Normal Progress ONLY, NEVER Gold Progress)
  v_dual_res := public.process_room_dual_progress(p_room_id, null, v_total_ap, 'active_seat_time');

  return jsonb_build_object(
    'success', true,
    'added_ap', v_total_ap,
    'active_seat_count', p_active_seat_count,
    'dual_result', v_dual_res
  );
end;
$$ language plpgsql security definer;

-- 11. RPC: Dynamic Smart Multi-Factor Trending Score Calculation
create or replace function public.calculate_smart_trending_score(
  p_post_id text
)
returns numeric
language plpgsql
security definer
as $$
declare
  v_post record;
  v_age_hours numeric;
  v_freshness_decay numeric;
  v_unique_viewers integer;
  v_unique_engagers integer;
  v_likes_velocity numeric;
  v_shares_count integer;
  v_saves_count integer;
  v_answers_count integer;
  v_reports_count integer;
  v_creator_post_count integer;
  v_creator_penalty numeric := 1.0;
  v_trend_score numeric := 0.0;
begin
  select * into v_post from public.posts where id = p_post_id;
  if not found then
    return 0.0;
  end if;

  -- Age in hours
  v_age_hours := greatest(0.1, extract(epoch from (now() - v_post.created_at)) / 3600.0);
  
  -- Content type specific freshness decay (Reels decay faster, educational slower)
  if v_post.post_type in ('reel', 'video') then
    v_freshness_decay := exp(-0.15 * v_age_hours);
  elsif v_post.post_type in ('pdf', 'question', 'mcq') then
    v_freshness_decay := exp(-0.03 * v_age_hours); -- Educational lasts longer
  else
    v_freshness_decay := exp(-0.08 * v_age_hours);
  end if;

  -- Unique Viewers & Engagers
  select count(distinct user_id) into v_unique_viewers from public.content_views where post_id = p_post_id;
  select count(distinct user_id) into v_unique_engagers from public.content_engagements where post_id = p_post_id;
  
  -- Saves & Shares
  select count(*) into v_saves_count from public.post_saves where post_id = p_post_id;
  select count(*) into v_shares_count from public.content_engagements where post_id = p_post_id and engagement_type = 'share';
  select count(*) into v_answers_count from public.post_answers where post_id = p_post_id;
  select count(*) into v_reports_count from public.user_feed_feedback where post_id = p_post_id and feedback_type = 'report';

  -- Anti-dominance penalty (Max 2-3 posts per creator in top feed window)
  select count(*) into v_creator_post_count 
  from public.posts 
  where user_id = v_post.user_id 
    and created_at > (now() - interval '24 hours');

  if v_creator_post_count > 3 then
    v_creator_penalty := 0.6;
  end if;

  -- Multi-Factor Formula
  v_trend_score := (
    (coalesce(v_post.likes, 0) * 1.0) +
    (coalesce(v_post.comments, 0) * 2.0) +
    (v_shares_count * 4.0) +           -- Shares weighted heavily
    (v_saves_count * 5.0) +            -- Saves weighted heavily for educational utility
    (v_answers_count * 3.5) +          -- Question answers
    (v_unique_engagers * 2.5) +        -- Unique engagers over bot repetitive clicks
    (v_unique_viewers * 0.5)
  ) * v_freshness_decay * v_creator_penalty;

  -- Subtract report/spam penalty
  if v_reports_count > 0 then
    v_trend_score := v_trend_score * (1.0 / (1.0 + (v_reports_count * 0.5)));
  end if;

  -- Update score in posts table
  update public.posts set trend_score = round(v_trend_score::numeric, 2) where id = p_post_id;

  return round(v_trend_score::numeric, 2);
end;
$$;

-- 6. RPC: Execute Weekend Family Settlement
CREATE OR REPLACE FUNCTION public.execute_weekend_family_settlement(
  p_family_id UUID
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_family_owner_id UUID;
  v_prev_pending BIGINT := 0;
  v_eligible_added BIGINT := 0;
  v_fraud_adj BIGINT := 0;
  v_final_settled BIGINT := 0;
  v_settlement_id TEXT;
  v_cb_per_inr NUMERIC := 250.0;
  v_inr_val NUMERIC(10,2);
BEGIN
  SELECT cb_per_inr INTO v_cb_per_inr FROM public.cb_system_config WHERE id = 1;
  IF v_cb_per_inr IS NULL OR v_cb_per_inr <= 0 THEN v_cb_per_inr := 250.0; END IF;

  -- Locate Family Owner ID
  SELECT owner_id INTO v_family_owner_id FROM public.communities WHERE id = p_family_id;
  IF v_family_owner_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Family owner not found');
  END IF;

  -- Lock pending family rewards for settlement
  SELECT COALESCE(SUM(amount_cb), 0) INTO v_eligible_added
  FROM public.family_pending_rewards
  WHERE family_id = p_family_id AND status = 'PENDING';

  SELECT COALESCE(SUM(amount_cb), 0) INTO v_fraud_adj
  FROM public.family_pending_rewards
  WHERE family_id = p_family_id AND status = 'REVERSED_FRAUD';

  v_final_settled := GREATEST(0, v_eligible_added - v_fraud_adj);
  IF v_final_settled <= 0 THEN
    RETURN jsonb_build_object('success', true, 'settled_cb', 0, 'reason', 'No pending rewards eligible for settlement');
  END IF;

  v_settlement_id := 'SETTLE-' || to_char(now() at time zone 'Asia/Kolkata', 'YYYYMMDD') || '-' || substr(md5(random()::text), 1, 6);
  v_inr_val := round((v_final_settled / v_cb_per_inr)::numeric, 2);

  -- Mark pending rewards as settled
  UPDATE public.family_pending_rewards
  SET status = 'SETTLED'
  WHERE family_id = p_family_id AND status = 'PENDING';

  -- Update Family Owner Wallet
  UPDATE public.wallets
  SET creania_balance = COALESCE(creania_balance, 0) + v_final_settled,
      lifetime_earned_cb = COALESCE(lifetime_earned_cb, 0) + v_final_settled,
      family_earnings_cb = COALESCE(family_earnings_cb, 0) + v_final_settled,
      updated_at = NOW()
  WHERE id = v_family_owner_id;

  -- Create Immutable Settlement Record
  INSERT INTO public.family_settlement_history (
    id, family_id, family_owner_id, previous_pending_cb, eligible_added_cb, fraud_adjustment_cb, final_settled_cb, inr_value, settled_at, status
  ) VALUES (
    v_settlement_id, p_family_id, v_family_owner_id, v_eligible_added, v_eligible_added, v_fraud_adj, v_final_settled, v_inr_val, NOW(), 'COMPLETED'
  );

  -- Create Ledger Entry
  INSERT INTO public.cb_ledger_entries (
    user_id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details
  ) VALUES (
    v_family_owner_id, v_final_settled, v_inr_val, 'WEEKEND_FAMILY_SETTLEMENT', v_settlement_id, 'settle_' || v_settlement_id, 'COMPLETED',
    jsonb_build_object('family_id', p_family_id, 'eligible_added', v_eligible_added, 'fraud_adjustment', v_fraud_adj)
  );

  RETURN jsonb_build_object(
    'success', true,
    'settlement_id', v_settlement_id,
    'family_id', p_family_id,
    'family_owner_id', v_family_owner_id,
    'final_settled_cb', v_final_settled,
    'inr_value', v_inr_val
  );
END;
$$;

-- 7. RPC: Exchange Creania Balance for Internal Currency (Gold Coins or Silver Coins)
CREATE OR REPLACE FUNCTION public.exchange_cb_currency(
  p_user_id UUID,
  p_amount_cb BIGINT,
  p_target_currency TEXT DEFAULT 'gold'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_cb_per_inr NUMERIC := 250.0;
  v_min_exchange BIGINT := 1000;
  v_promo_pct NUMERIC := 5.0;
  v_inr_value NUMERIC(10,2);
  v_user_cb BIGINT;
  v_gained INTEGER;
  v_bonus INTEGER := 0;
  v_total INTEGER;
  v_tx_id TEXT;
  v_target TEXT := lower(coalesce(p_target_currency, 'gold'));
BEGIN
  IF p_user_id IS NULL OR p_amount_cb <= 0 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Invalid exchange parameters');
  END IF;

  SELECT cb_per_inr, min_exchange_cb, promotional_bonus_percent 
  INTO v_cb_per_inr, v_min_exchange, v_promo_pct 
  FROM public.cb_system_config WHERE id = 1;

  IF v_cb_per_inr IS NULL OR v_cb_per_inr <= 0 THEN v_cb_per_inr := 250.0; END IF;
  IF v_min_exchange IS NULL THEN v_min_exchange := 5000; END IF;

  IF p_amount_cb < v_min_exchange THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Minimum exchange requirement is ' || v_min_exchange || ' CB');
  END IF;

  -- Lock User Wallet Row
  SELECT COALESCE(creania_balance, 0) INTO v_user_cb
  FROM public.wallets
  WHERE id = p_user_id
  FOR UPDATE;

  IF v_user_cb < p_amount_cb THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Insufficient Creania Balance');
  END IF;

  v_inr_value := round((p_amount_cb / v_cb_per_inr)::numeric, 2);
  
  IF v_target = 'silver' THEN
    -- Silver Exchange Rate: 500 CB = 200 Silver Coins -> 2.5 CB = 1 Silver Coin
    v_gained := floor(p_amount_cb / 2.5)::integer;
    IF v_gained < 1 THEN v_gained := 1; END IF;

    -- Tiered Bonus starting from 10,000 CB (₹40) tier
    IF p_amount_cb >= 100000 THEN
      v_bonus := 30000; -- 30,000 Bonus Silver
    ELSIF p_amount_cb >= 50000 THEN
      v_bonus := 12000; -- 12,000 Bonus Silver
    ELSIF p_amount_cb >= 25000 THEN
      v_bonus := 5000; -- 5,000 Bonus Silver
    ELSIF p_amount_cb >= 10000 THEN
      v_bonus := 1800; -- 1,800 Bonus Silver (Starts at ₹40)
    ELSE
      v_bonus := 0;
    END IF;

    v_total := v_gained + v_bonus;
    v_tx_id := 'ex_slv_' || extract(epoch from now())::bigint || '_' || floor(random()*10000)::int;

    UPDATE public.wallets
    SET creania_balance = GREATEST(0, COALESCE(creania_balance, 0) - p_amount_cb),
        silver_coins_balance = COALESCE(silver_coins_balance, 0) + v_total,
        silver_coins = COALESCE(silver_coins, 0) + v_total,
        updated_at = NOW()
    WHERE id = p_user_id;

  ELSE
    -- Gold Exchange Rate: 500 CB = 1 Gold Coin
    v_gained := floor(p_amount_cb / 500.0)::integer;
    IF v_gained < 1 THEN v_gained := 1; END IF;

    -- Tiered Bonus starting from 10,000 CB (₹40) tier (9 Bonus Gold Coins at ₹40!)
    IF p_amount_cb >= 100000 THEN
      v_bonus := 150; -- 150 Bonus Gold
    ELSIF p_amount_cb >= 50000 THEN
      v_bonus := 60; -- 60 Bonus Gold
    ELSIF p_amount_cb >= 25000 THEN
      v_bonus := 25; -- 25 Bonus Gold
    ELSIF p_amount_cb >= 10000 THEN
      v_bonus := 9; -- 9 Bonus Gold (Starts at ₹40)
    ELSE
      v_bonus := 0;
    END IF;

    v_total := v_gained + v_bonus;
    v_tx_id := 'ex_gld_' || extract(epoch from now())::bigint || '_' || floor(random()*10000)::int;

    UPDATE public.wallets
    SET creania_balance = GREATEST(0, COALESCE(creania_balance, 0) - p_amount_cb),
        coins_balance = COALESCE(coins_balance, 0) + v_total,
        gold_coins = COALESCE(gold_coins, 0) + v_total,
        updated_at = NOW()
    WHERE id = p_user_id;
  END IF;

  -- Ledger Log for Exchange
  INSERT INTO public.cb_ledger_entries (
    user_id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details
  ) VALUES (
    p_user_id, -p_amount_cb, v_inr_value, 'EXCHANGE', v_tx_id, 'ex_' || v_tx_id, 'COMPLETED',
    jsonb_build_object('gained_amount', v_gained, 'bonus_amount', v_bonus, 'total_amount', v_total, 'target_currency', v_target)
  );

  IF v_bonus > 0 THEN
    INSERT INTO public.cb_ledger_entries (
      user_id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details
    ) VALUES (
      p_user_id, 0, 0.00, 'PROMOTIONAL_BONUS', v_tx_id, 'promo_' || v_tx_id, 'COMPLETED',
      jsonb_build_object('bonus_amount', v_bonus, 'campaign', 'EXCHANGE_PROMO', 'target_currency', v_target)
    ) ON CONFLICT (idempotency_key) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'amount_cb', p_amount_cb,
    'inr_value', v_inr_value,
    'target_currency', v_target,
    'gained_amount', v_gained,
    'bonus_amount', v_bonus,
    'total_amount', v_total,
    'tx_id', v_tx_id
  );
END;
$$;

-- 8. RPC: Request Creania Balance Withdrawal
CREATE OR REPLACE FUNCTION public.request_cb_withdrawal(
  p_user_id UUID,
  p_amount_cb BIGINT,
  p_upi_id TEXT,
  p_account_name TEXT DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_cb_per_inr NUMERIC := 250.0;
  v_min_withdraw BIGINT := 25000;
  v_fee_pct NUMERIC := 0.0;
  v_user_cb BIGINT;
  v_is_kyc BOOLEAN := false;
  v_inr_val NUMERIC(10,2);
  v_fee_inr NUMERIC(10,2) := 0.00;
  v_net_payout NUMERIC(10,2);
  v_withdraw_id TEXT;
BEGIN
  IF p_user_id IS NULL OR p_amount_cb <= 0 OR p_upi_id IS NULL OR trim(p_upi_id) = '' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Valid amount and UPI ID are required');
  END IF;

  SELECT cb_per_inr, min_withdrawal_cb, withdrawal_fee_percent
  INTO v_cb_per_inr, v_min_withdraw, v_fee_pct
  FROM public.cb_system_config WHERE id = 1;

  IF v_cb_per_inr IS NULL OR v_cb_per_inr <= 0 THEN v_cb_per_inr := 250.0; END IF;
  IF v_min_withdraw IS NULL THEN v_min_withdraw := 250000; END IF;

  IF p_amount_cb < v_min_withdraw THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Minimum withdrawal threshold is 250,000 CB (≈ ₹1,000.00)');
  END IF;

  -- Lock User Wallet Row & Check KYC
  SELECT COALESCE(creania_balance, 0), COALESCE(kyc_verified, false)
  INTO v_user_cb, v_is_kyc
  FROM public.wallets
  WHERE id = p_user_id
  FOR UPDATE;

  IF v_user_cb < p_amount_cb THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Insufficient Creania Balance');
  END IF;

  v_inr_val := round((p_amount_cb / v_cb_per_inr)::numeric, 2);
  IF v_fee_pct > 0 THEN
    v_fee_inr := round((v_inr_val * (v_fee_pct / 100.0))::numeric, 2);
  END IF;
  v_net_payout := GREATEST(0.00, v_inr_val - v_fee_inr);

  v_withdraw_id := 'WD-' || to_char(now() at time zone 'Asia/Kolkata', 'YYYYMMDD') || '-' || floor(10000 + random() * 89999)::int;

  -- Move CB from Available to Pending Balance
  UPDATE public.wallets
  SET creania_balance = GREATEST(0, COALESCE(creania_balance, 0) - p_amount_cb),
      pending_cb_balance = COALESCE(pending_cb_balance, 0) + p_amount_cb,
      upi_id = COALESCE(p_upi_id, upi_id),
      bank_account_name = COALESCE(p_account_name, bank_account_name),
      updated_at = NOW()
  WHERE id = p_user_id;

  -- Record Withdrawal Request
  INSERT INTO public.cb_withdrawals (
    id, user_id, amount_cb, inr_value, fee_inr, net_payout_inr, upi_id, account_name, status, created_at, updated_at
  ) VALUES (
    v_withdraw_id, p_user_id, p_amount_cb, v_inr_val, v_fee_inr, v_net_payout, p_upi_id, p_account_name, 'Withdrawal Requested', NOW(), NOW()
  );

  -- Ledger Record
  INSERT INTO public.cb_ledger_entries (
    user_id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details
  ) VALUES (
    p_user_id, -p_amount_cb, v_inr_val, 'WITHDRAWAL_REQUEST', v_withdraw_id, 'wd_req_' || v_withdraw_id, 'PENDING',
    jsonb_build_object('withdrawal_id', v_withdraw_id, 'upi_id', p_upi_id, 'net_payout_inr', v_net_payout)
  );

  RETURN jsonb_build_object(
    'success', true,
    'withdrawal_id', v_withdraw_id,
    'amount_cb', p_amount_cb,
    'inr_value', v_inr_val,
    'net_payout_inr', v_net_payout,
    'status', 'Withdrawal Requested'
  );
END;
$$;

-- 9. RPC: Admin Process Withdrawal (Completed / Rejected / Reversed)
CREATE OR REPLACE FUNCTION public.admin_process_cb_withdrawal(
  p_withdrawal_id TEXT,
  p_new_status TEXT,
  p_rejection_reason TEXT DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rec RECORD;
BEGIN
  IF p_withdrawal_id IS NULL OR p_new_status IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Missing mandatory parameters');
  END IF;

  SELECT * INTO v_rec FROM public.cb_withdrawals WHERE id = p_withdrawal_id FOR UPDATE;
  IF v_rec IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Withdrawal record not found');
  END IF;

  IF p_new_status = 'Completed' THEN
    -- Finalize Withdrawal: Deduct Pending Balance and Add to Lifetime Withdrawn
    UPDATE public.wallets
    SET pending_cb_balance = GREATEST(0, COALESCE(pending_cb_balance, 0) - v_rec.amount_cb),
        lifetime_withdrawn_cb = COALESCE(lifetime_withdrawn_cb, 0) + v_rec.amount_cb,
        updated_at = NOW()
    WHERE id = v_rec.user_id;

    UPDATE public.cb_withdrawals
    SET status = 'Completed', updated_at = NOW()
    WHERE id = p_withdrawal_id;

    UPDATE public.cb_ledger_entries
    SET status = 'COMPLETED'
    WHERE idempotency_key = 'wd_req_' || p_withdrawal_id;

  ELSIF p_new_status IN ('Rejected', 'Reversed') THEN
    -- Refund Pending Balance back to Available Balance
    UPDATE public.wallets
    SET pending_cb_balance = GREATEST(0, COALESCE(pending_cb_balance, 0) - v_rec.amount_cb),
        creania_balance = COALESCE(creania_balance, 0) + v_rec.amount_cb,
        updated_at = NOW()
    WHERE id = v_rec.user_id;

    UPDATE public.cb_withdrawals
    SET status = p_new_status, rejection_reason = p_rejection_reason, updated_at = NOW()
    WHERE id = p_withdrawal_id;

    -- Add Reversal Ledger Record
    INSERT INTO public.cb_ledger_entries (
      user_id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details
    ) VALUES (
      v_rec.user_id, v_rec.amount_cb, v_rec.inr_value, 'WITHDRAWAL_REJECTED', p_withdrawal_id, 'wd_rev_' || p_withdrawal_id, 'COMPLETED',
      jsonb_build_object('reason', p_rejection_reason)
    ) ON CONFLICT (idempotency_key) DO NOTHING;
  ELSE
    UPDATE public.cb_withdrawals
    SET status = p_new_status, updated_at = NOW()
    WHERE id = p_withdrawal_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'withdrawal_id', p_withdrawal_id, 'status', p_new_status);
END;
$$;

-- 10. RPC: Reverse Gift Reward (Audit Refund / Anti-Abuse)
CREATE OR REPLACE FUNCTION public.reverse_gift_reward(
  p_gift_transaction_id TEXT,
  p_reason TEXT DEFAULT 'GIFT_REFUNDED'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_ledger RECORD;
  v_cb_per_inr NUMERIC := 250.0;
BEGIN
  SELECT cb_per_inr INTO v_cb_per_inr FROM public.cb_system_config WHERE id = 1;

  FOR v_ledger IN 
    SELECT * FROM public.cb_ledger_entries 
    WHERE reference_id = p_gift_transaction_id AND status = 'COMPLETED' AND amount_cb > 0
  LOOP
    -- Deduct CB from User Wallet
    UPDATE public.wallets
    SET creania_balance = GREATEST(0, COALESCE(creania_balance, 0) - v_ledger.amount_cb),
        updated_at = NOW()
    WHERE id = v_ledger.user_id;

    -- Mark original entry as REVERSED
    UPDATE public.cb_ledger_entries SET status = 'REVERSED' WHERE id = v_ledger.id;

    -- Create Negative Reversal Record
    INSERT INTO public.cb_ledger_entries (
      user_id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details
    ) VALUES (
      v_ledger.user_id, -v_ledger.amount_cb, -v_ledger.inr_equivalent, 'GIFT_REFUNDED', p_gift_transaction_id, 'rev_' || v_ledger.idempotency_key, 'COMPLETED',
      jsonb_build_object('original_entry_id', v_ledger.id, 'reason', p_reason)
    ) ON CONFLICT (idempotency_key) DO NOTHING;
  END LOOP;

  -- Reversal for pending family rewards if any
  UPDATE public.family_pending_rewards
  SET status = 'REVERSED_FRAUD'
  WHERE gift_transaction_id = p_gift_transaction_id;

  RETURN jsonb_build_object('success', true, 'transaction_id', p_gift_transaction_id, 'reason', p_reason);
END;
$$;

-- 12. RPC: Get Creania Balance Wallet Data
CREATE OR REPLACE FUNCTION public.get_cb_wallet_data(
  p_user_id UUID
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_wallet RECORD;
  v_config RECORD;
  v_transactions jsonb := '[]'::jsonb;
  v_family_settlements jsonb := '[]'::jsonb;
  v_pending_withdrawals jsonb := '[]'::jsonb;
  v_family_pending_cb bigint := 0;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'User ID required');
  END IF;

  SELECT * INTO v_config FROM public.cb_system_config WHERE id = 1;
  SELECT * INTO v_wallet FROM public.wallets WHERE id = p_user_id;

  -- Pending Family Rewards sum
  SELECT COALESCE(SUM(amount_cb), 0) INTO v_family_pending_cb
  FROM public.family_pending_rewards
  WHERE family_owner_id = p_user_id AND status = 'PENDING';

  -- Fetch Recent Ledger Entries
  SELECT jsonb_agg(to_jsonb(t)) INTO v_transactions
  FROM (
    SELECT id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details, created_at
    FROM public.cb_ledger_entries
    WHERE user_id = p_user_id
    ORDER BY created_at DESC
    LIMIT 50
  ) t;

  -- Fetch Family Settlements History
  SELECT jsonb_agg(to_jsonb(s)) INTO v_family_settlements
  FROM (
    SELECT id, family_id, previous_pending_cb, eligible_added_cb, fraud_adjustment_cb, final_settled_cb, inr_value, settled_at, status
    FROM public.family_settlement_history
    WHERE family_owner_id = p_user_id
    ORDER BY settled_at DESC
    LIMIT 20
  ) s;

  -- Fetch Pending Withdrawals
  SELECT jsonb_agg(to_jsonb(w)) INTO v_pending_withdrawals
  FROM (
    SELECT id, amount_cb, inr_value, fee_inr, net_payout_inr, upi_id, account_name, status, rejection_reason, created_at, updated_at
    FROM public.cb_withdrawals
    WHERE user_id = p_user_id
    ORDER BY created_at DESC
    LIMIT 20
  ) w;

  RETURN jsonb_build_object(
    'success', true,
    'creania_balance', COALESCE(v_wallet.creania_balance, 0),
    'pending_cb_balance', COALESCE(v_wallet.pending_cb_balance, 0),
    'lifetime_earned_cb', COALESCE(v_wallet.lifetime_earned_cb, 0),
    'lifetime_withdrawn_cb', COALESCE(v_wallet.lifetime_withdrawn_cb, 0),
    'gift_earnings_cb', COALESCE(v_wallet.gift_earnings_cb, 0),
    'room_earnings_cb', COALESCE(v_wallet.room_earnings_cb, 0),
    'community_earnings_cb', COALESCE(v_wallet.community_earnings_cb, 0),
    'family_earnings_cb', COALESCE(v_wallet.family_earnings_cb, 0),
    'family_pending_cb', v_family_pending_cb,
    'kyc_verified', COALESCE(v_wallet.kyc_verified, false),
    'upi_id', v_wallet.upi_id,
    'bank_account_name', v_wallet.bank_account_name,
    'config', to_jsonb(v_config),
    'transactions', COALESCE(v_transactions, '[]'::jsonb),
    'family_settlements', COALESCE(v_family_settlements, '[]'::jsonb),
    'withdrawals', COALESCE(v_pending_withdrawals, '[]'::jsonb)
  );
END;
$$;

-- 2. Single Authoritative Server Function: calculate_lucky_gift_reward(goldCoinValue)
CREATE OR REPLACE FUNCTION public.calculate_lucky_gift_reward(
  p_gold_coins integer
)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_coins integer := COALESCE(p_gold_coins, 0);
  v_ap integer := 0;
  v_gem integer := 0;
  v_tier text := 'none';
BEGIN
  IF v_coins >= 1 AND v_coins <= 4 THEN
    v_ap := 0;
    v_gem := 0;
    v_tier := 'none';
  ELSIF v_coins >= 5 AND v_coins <= 99 THEN
    v_ap := 1;
    v_gem := 1;
    v_tier := '5_99';
  ELSIF v_coins >= 100 AND v_coins <= 1000 THEN
    v_ap := 10;
    v_gem := 10;
    v_tier := '100_1000';
  ELSIF v_coins >= 1001 AND v_coins <= 5000 THEN
    v_ap := 50;
    v_gem := 50;
    v_tier := '1001_5000';
  ELSIF v_coins >= 5001 AND v_coins <= 10000 THEN
    v_ap := 100;
    v_gem := 100;
    v_tier := '5001_10000';
  ELSIF v_coins >= 10001 THEN
    v_ap := 200;
    v_gem := 200;
    v_tier := '1001_plus';
  END IF;

  RETURN jsonb_build_object(
    'ap', v_ap,
    'gem', v_gem,
    'tier', v_tier
  );
END;
$$;

-- 3. RPC: Register / Update User Session
CREATE OR REPLACE FUNCTION public.register_user_session(
  p_session_id text,
  p_device_id text,
  p_device_name text,
  p_platform text,
  p_device_model text DEFAULT '',
  p_os_version text DEFAULT '',
  p_app_version text DEFAULT '',
  p_browser text DEFAULT '',
  p_ip text DEFAULT '127.0.0.1',
  p_country text DEFAULT 'India'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  INSERT INTO public.user_sessions (
    user_id,
    session_id,
    device_id,
    device_name,
    device_model,
    platform,
    os_version,
    app_version,
    browser,
    ip_address,
    country,
    last_active_at,
    revoked_at
  )
  VALUES (
    v_user_id,
    p_session_id,
    p_device_id,
    p_device_name,
    p_device_model,
    p_platform,
    p_os_version,
    p_app_version,
    p_browser,
    p_ip,
    p_country,
    timezone('utc'::text, now()),
    NULL
  )
  ON CONFLICT (session_id) DO UPDATE SET
    device_name = EXCLUDED.device_name,
    device_model = EXCLUDED.device_model,
    platform = EXCLUDED.platform,
    os_version = EXCLUDED.os_version,
    app_version = EXCLUDED.app_version,
    browser = EXCLUDED.browser,
    ip_address = EXCLUDED.ip_address,
    country = EXCLUDED.country,
    last_active_at = timezone('utc'::text, now()),
    revoked_at = NULL;

  -- Maintain backward compatibility with user_devices table
  INSERT INTO public.user_devices (user_id, device_id, device_name, platform, ip_address, is_current, revoked_at, last_active)
  VALUES (v_user_id, p_device_id, p_device_name, p_platform, p_ip, true, NULL, timezone('utc'::text, now()))
  ON CONFLICT (user_id, device_id) DO UPDATE SET
    device_name = EXCLUDED.device_name,
    platform = EXCLUDED.platform,
    ip_address = EXCLUDED.ip_address,
    is_current = true,
    revoked_at = NULL,
    last_active = timezone('utc'::text, now());

  RETURN jsonb_build_object('success', true, 'session_id', p_session_id);
END;
$$;

-- 4. RPC: Validate Active Session
CREATE OR REPLACE FUNCTION public.validate_user_session(p_session_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_revoked_at timestamp with time zone;
  v_session_found boolean := false;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('valid', false, 'error', 'Unauthenticated');
  END IF;

  SELECT revoked_at, true INTO v_revoked_at, v_session_found
  FROM public.user_sessions
  WHERE user_id = v_user_id AND session_id = p_session_id;

  IF NOT v_session_found THEN
    RETURN jsonb_build_object('valid', false, 'reason', 'session_not_found');
  END IF;

  IF v_revoked_at IS NOT NULL THEN
    RETURN jsonb_build_object('valid', false, 'reason', 'session_revoked', 'revoked_at', v_revoked_at);
  END IF;

  -- Touch last active timestamp
  UPDATE public.user_sessions
  SET last_active_at = timezone('utc'::text, now())
  WHERE user_id = v_user_id AND session_id = p_session_id;

  RETURN jsonb_build_object('valid', true);
END;
$$;

-- 5. RPC: Revoke Single Session (Individual Device Logout)
CREATE OR REPLACE FUNCTION public.revoke_user_session(p_session_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_device_name text;
  v_platform text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  -- Get session metadata before revoking
  SELECT device_name, platform INTO v_device_name, v_platform
  FROM public.user_sessions
  WHERE user_id = v_user_id AND session_id = p_session_id;

  IF v_device_name IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Session not found');
  END IF;

  -- Perform revocation
  UPDATE public.user_sessions
  SET revoked_at = timezone('utc'::text, now())
  WHERE user_id = v_user_id AND session_id = p_session_id;

  -- Log security event
  INSERT INTO public.user_login_activity (
    user_id,
    event_type,
    device_name,
    platform,
    session_id,
    status,
    auth_method,
    login_at
  )
  VALUES (
    v_user_id,
    'Device Logout',
    v_device_name,
    v_platform,
    p_session_id,
    'success',
    'Session Revocation',
    timezone('utc'::text, now())
  );

  RETURN jsonb_build_object('success', true, 'session_id', p_session_id);
END;
$$;

-- 6. RPC: Revoke All Other Sessions (Logout From All Other Devices)
CREATE OR REPLACE FUNCTION public.revoke_all_other_user_sessions(p_current_session_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_revoked_count integer := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  -- Revoke all active sessions except current
  WITH updated AS (
    UPDATE public.user_sessions
    SET revoked_at = timezone('utc'::text, now())
    WHERE user_id = v_user_id
      AND session_id != p_current_session_id
      AND revoked_at IS NULL
    RETURNING id
  )
  SELECT count(*) INTO v_revoked_count FROM updated;

  -- Log security event
  INSERT INTO public.user_login_activity (
    user_id,
    event_type,
    device_name,
    platform,
    session_id,
    status,
    auth_method,
    login_at
  )
  VALUES (
    v_user_id,
    'All Devices Logout',
    'Current Device',
    'Multiple',
    p_current_session_id,
    'success',
    'Bulk Revocation',
    timezone('utc'::text, now())
  );

  RETURN jsonb_build_object(
    'success', true,
    'revoked_count', v_revoked_count,
    'current_session_id', p_current_session_id
  );
END;
$$;

-- 7. RPC: Log User Login Activity Event
CREATE OR REPLACE FUNCTION public.log_user_login_event(
  p_event_type text,
  p_device_name text,
  p_platform text,
  p_ip text DEFAULT '127.0.0.1',
  p_country text DEFAULT 'India',
  p_session_id text DEFAULT NULL,
  p_status text DEFAULT 'success',
  p_failure_reason text DEFAULT NULL,
  p_auth_method text DEFAULT 'Password'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  INSERT INTO public.user_login_activity (
    user_id,
    event_type,
    device_name,
    platform,
    ip_address,
    country,
    session_id,
    status,
    failure_reason,
    auth_method,
    login_at
  )
  VALUES (
    v_user_id,
    p_event_type,
    p_device_name,
    p_platform,
    p_ip,
    p_country,
    p_session_id,
    p_status,
    p_failure_reason,
    p_auth_method,
    timezone('utc'::text, now())
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

-- 4. Update process_authoritative_wallet_transaction to reject payment source strings without verified payment
CREATE OR REPLACE FUNCTION public.process_authoritative_wallet_transaction(
  p_user_id uuid,
  p_currency text,
  p_amount bigint,
  p_type text DEFAULT 'Credit',
  p_source text DEFAULT 'System',
  p_transaction_id text DEFAULT NULL,
  p_reference_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_wallet RECORD;
  v_prev_bal bigint := 0;
  v_new_bal bigint := 0;
  v_clean_currency text;
  v_clean_tx_id text;
  v_existing_tx RECORD;
BEGIN
  -- Validate Inputs
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid user ID');
  END IF;

  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Transaction amount must be greater than 0');
  END IF;

  -- Reject fake payment source claims (payment recharges must use process_verified_payment_recharge_rpc)
  IF LOWER(p_source) LIKE '%payment%' OR LOWER(p_source) LIKE '%razorpay%' OR LOWER(p_source) LIKE '%inapp%' THEN
    IF p_reference_id IS NULL AND p_transaction_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Payment transactions require verified payment confirmation RPC');
    END IF;
    -- Verify payment ID exists in purchases or payments with status Success
    IF NOT EXISTS (
      SELECT 1 FROM public.purchases WHERE (payment_id = p_reference_id OR payment_id = p_transaction_id) AND status = 'Success'
    ) AND NOT EXISTS (
      SELECT 1 FROM public.payments WHERE (payment_id = p_reference_id OR payment_id = p_transaction_id) AND status = 'Success'
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Unverified payment source attempt blocked');
    END IF;
  END IF;

  -- Validate Currency Type
  v_clean_currency := CASE LOWER(p_currency)
    WHEN 'silver' THEN 'Silver'
    WHEN 'silver_coins' THEN 'Silver'
    WHEN 'gold' THEN 'Gold'
    WHEN 'gold_coins' THEN 'Gold'
    WHEN 'coins' THEN 'Gold'
    ELSE 'Gold'
  END;

  -- Per-Transaction Cap: Single non-payment transaction cannot exceed 6,000 coins
  IF p_amount > 6000 THEN
    RAISE WARNING '[WALLET SECURITY ALERT] Abnormally large transaction attempt blocked: User %, Amount %, Source %', p_user_id, p_amount, p_source;
    RETURN jsonb_build_object('success', false, 'error', 'Abnormally large transaction amount rejected by security rules');
  END IF;

  -- Generate transaction ID if not provided
  v_clean_tx_id := COALESCE(p_transaction_id, 'tx_' || gen_random_uuid()::text);

  -- Idempotency Check: Avoid double crediting on retries or duplicate realtime events
  SELECT id, amount, previous_balance, new_balance INTO v_existing_tx
  FROM public.wallet_transactions
  WHERE transaction_id = v_clean_tx_id;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_processed', true,
      'transaction_id', v_clean_tx_id,
      'amount', v_existing_tx.amount,
      'new_balance', v_existing_tx.new_balance
    );
  END IF;

  -- Lock wallet row for atomic thread-safe update
  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE id = p_user_id
  FOR UPDATE;

  -- Create wallet row if it does not exist
  IF NOT FOUND THEN
    INSERT INTO public.wallets (id, coins_balance, gold_coins, silver_coins_balance, silver_coins)
    VALUES (p_user_id, 0, 0, 0, 0)
    RETURNING * INTO v_wallet;
  END IF;

  -- Compute balances (No cumulative total balance cap! Balance increases legitimately per transaction)
  IF v_clean_currency = 'Gold' THEN
    v_prev_bal := COALESCE(v_wallet.coins_balance, v_wallet.gold_coins, 0);
    IF LOWER(p_type) = 'debit' OR LOWER(p_type) = 'used' THEN
      IF v_prev_bal < p_amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient Gold Coins balance');
      END IF;
      v_new_bal := v_prev_bal - p_amount;
    ELSE
      v_new_bal := v_prev_bal + p_amount;
    END IF;

    UPDATE public.wallets
    SET coins_balance = v_new_bal,
        gold_coins    = v_new_bal
    WHERE id = p_user_id;

  ELSIF v_clean_currency = 'Silver' THEN
    v_prev_bal := COALESCE(v_wallet.silver_coins_balance, v_wallet.silver_coins, 0);
    IF LOWER(p_type) = 'debit' OR LOWER(p_type) = 'used' THEN
      IF v_prev_bal < p_amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient Silver Coins balance');
      END IF;
      v_new_bal := v_prev_bal - p_amount;
    ELSE
      v_new_bal := v_prev_bal + p_amount;
    END IF;

    UPDATE public.wallets
    SET silver_coins_balance = v_new_bal,
        silver_coins         = v_new_bal
    WHERE id = p_user_id;
  END IF;

  -- Insert Audit Log Entry
  INSERT INTO public.wallet_transactions (
    id,
    wallet_id,
    user_id,
    currency_type,
    currency,
    amount,
    previous_balance,
    new_balance,
    type,
    source,
    transaction_id,
    reference_id,
    details,
    status,
    created_at
  ) VALUES (
    gen_random_uuid(),
    p_user_id,
    p_user_id,
    v_clean_currency,
    v_clean_currency,
    p_amount,
    v_prev_bal,
    v_new_bal,
    p_type,
    p_source,
    v_clean_tx_id,
    p_reference_id,
    p_source || ': ' || p_type || ' ' || p_amount || ' ' || v_clean_currency,
    'Completed',
    now()
  );

  RETURN jsonb_build_object(
    'success', true,
    'already_processed', false,
    'transaction_id', v_clean_tx_id,
    'currency', v_clean_currency,
    'previous_balance', v_prev_bal,
    'new_balance', v_new_bal,
    'amount', p_amount
  );
END;
$$;

-- 2. Master Verified Payment Recharge & Fulfillment RPC
CREATE OR REPLACE FUNCTION public.process_verified_payment_recharge_rpc(
  p_user_id        uuid,
  p_payment_id     text,
  p_amount         numeric,
  p_coins_amount   integer,
  p_product_name   text DEFAULT '50,000 Gold Coins Package',
  p_order_id       text DEFAULT NULL,
  p_signature      text DEFAULT NULL,
  p_secret_key     text DEFAULT 'ehrQ4edUdNzEZqtTE334Lcsf'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_computed_sig     text;
  v_existing_pay     RECORD;
  v_existing_pur     RECORD;
  v_wallet           RECORD;
  v_prev_coins       integer := 0;
  v_new_coins        integer := 0;
  v_tx_id            text;
BEGIN
  -- Validate basic inputs
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid user ID');
  END IF;

  IF p_payment_id IS NULL OR length(trim(p_payment_id)) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Missing or empty payment ID');
  END IF;

  IF p_amount <= 0 OR p_coins_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid payment or coin amount');
  END IF;

  -- Per-transaction cap: single recharge package cannot exceed 6,000 coins per transaction (allows 5,000 base + 599 bonus coins)
  IF p_coins_amount > 6000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Recharge coins amount exceeds single transaction cap of 6,000 coins');
  END IF;

  -- 1. Idempotency Check on public.purchases
  SELECT * INTO v_existing_pur
  FROM public.purchases
  WHERE payment_id = p_payment_id
  FOR UPDATE;

  IF FOUND THEN
    -- Check user match
    IF v_existing_pur.user_id <> p_user_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'Payment ID belongs to a different user');
    END IF;

    -- Check amount match
    IF v_existing_pur.amount <> p_amount AND v_existing_pur.final_amount <> p_amount THEN
      RETURN jsonb_build_object('success', false, 'error', 'Payment ID amount mismatch');
    END IF;

    -- Check status
    IF v_existing_pur.status = 'Success' THEN
      -- Fetch current balance for idempotent response
      SELECT COALESCE(coins_balance, gold_coins, 0) INTO v_prev_coins
      FROM public.wallets WHERE id = p_user_id;

      RETURN jsonb_build_object(
        'success', true,
        'already_processed', true,
        'payment_id', p_payment_id,
        'coins_added', 0,
        'new_balance', COALESCE(v_prev_coins, 0),
        'message', 'Payment already processed successfully'
      );
    ELSIF v_existing_pur.status = 'Failed' THEN
      RETURN jsonb_build_object('success', false, 'error', 'Payment marked failed cannot be fulfilled');
    END IF;
  END IF;

  -- 2. Check public.payments table if recorded by webhook/gateway
  SELECT * INTO v_existing_pay
  FROM public.payments
  WHERE payment_id = p_payment_id
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing_pay.user_id <> p_user_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'Payment ID user mismatch');
    END IF;

    IF v_existing_pay.amount <> p_amount THEN
      RETURN jsonb_build_object('success', false, 'error', 'Payment ID amount mismatch');
    END IF;

    IF v_existing_pay.status = 'Failed' THEN
      RETURN jsonb_build_object('success', false, 'error', 'Unverified or failed payment status');
    END IF;
  ELSE
    -- If not found in payments, check if a valid Razorpay signature is provided
    IF p_order_id IS NOT NULL AND p_signature IS NOT NULL THEN
      BEGIN
        v_computed_sig := encode(extensions.hmac((p_order_id || '|' || p_payment_id)::bytea, p_secret_key::bytea, 'sha256'), 'hex');
      EXCEPTION WHEN OTHERS THEN
        v_computed_sig := encode(public.hmac((p_order_id || '|' || p_payment_id)::bytea, p_secret_key::bytea, 'sha256'), 'hex');
      END;

      IF LOWER(v_computed_sig) <> LOWER(p_signature) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Razorpay signature verification failed');
      END IF;
    ELSE
      -- Payment ID not found in verified payments table AND no valid signature -> REJECT FAKE PAYMENT
      RETURN jsonb_build_object('success', false, 'error', 'Unverified or fake payment ID');
    END IF;
  END IF;

  -- 3. Lock user wallet row for atomic update
  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.wallets (id, coins_balance, gold_coins, silver_coins_balance, silver_coins, withdrawable_balance)
    VALUES (p_user_id, 0, 0, 0, 0, 0.00)
    RETURNING * INTO v_wallet;
  END IF;

  v_prev_coins := COALESCE(v_wallet.coins_balance, v_wallet.gold_coins, 0);
  v_new_coins  := v_prev_coins + p_coins_amount;

  -- Update wallet balance (No artificial total balance cap! Multiple 50k purchases accumulate legally)
  UPDATE public.wallets
  SET coins_balance = v_new_coins,
      gold_coins    = v_new_coins
  WHERE id = p_user_id;

  v_tx_id := 'tx_pay_' || p_payment_id;

  -- Insert into public.purchases (Idempotency Record)
  INSERT INTO public.purchases (
    user_id,
    product_name,
    category,
    amount,
    final_amount,
    payment_method,
    status,
    duration,
    payment_id
  ) VALUES (
    p_user_id,
    p_product_name,
    'Coins',
    p_amount,
    p_amount,
    'Razorpay Gateway',
    'Success',
    'One-time',
    p_payment_id
  )
  ON CONFLICT (payment_id) DO UPDATE
  SET status = 'Success';

  -- Insert into public.payments if not present
  INSERT INTO public.payments (
    payment_id,
    order_id,
    user_id,
    amount,
    vip_plan,
    status,
    purchase_date,
    gateway_response
  ) VALUES (
    p_payment_id,
    COALESCE(p_order_id, 'ord_' || p_payment_id),
    p_user_id,
    p_amount,
    p_product_name,
    'Success',
    now(),
    jsonb_build_object('payment_id', p_payment_id, 'coins_added', p_coins_amount)
  )
  ON CONFLICT (payment_id) DO UPDATE
  SET status = 'Success';

  -- Record Audit Log Entry
  INSERT INTO public.wallet_transactions (
    id,
    wallet_id,
    user_id,
    currency_type,
    currency,
    amount,
    previous_balance,
    new_balance,
    type,
    source,
    transaction_id,
    reference_id,
    details,
    status,
    created_at
  ) VALUES (
    gen_random_uuid(),
    p_user_id,
    p_user_id,
    'Gold',
    'Gold',
    p_coins_amount,
    v_prev_coins,
    v_new_coins,
    'Credit',
    'VerifiedPayment',
    v_tx_id,
    p_payment_id,
    'Verified Recharge: ' || p_product_name || ' (' || p_payment_id || ')',
    'Completed',
    now()
  )
  ON CONFLICT (transaction_id) DO NOTHING;

  RETURN jsonb_build_object(
    'success', true,
    'already_processed', false,
    'payment_id', p_payment_id,
    'coins_added', p_coins_amount,
    'previous_balance', v_prev_coins,
    'new_balance', v_new_coins
  );
END;
$$;

