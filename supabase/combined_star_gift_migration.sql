-- COMBINED STAR GIFT SYSTEM MIGRATION (CONSOLIDATING 0014, 0015, AND 0016 MIGRATIONS)
-- Sequential: creates tables, RLS policies, seeds catalog items, creates magic gift rules, and installs patched functions.

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
  is_magic boolean default false, -- from 0015
  created_at timestamptz default now()
);

-- 3. Create Gift Transactions Ledger Table
create table if not exists public.gift_transactions (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete set null,
  receiver_id uuid references public.profiles(id) on delete set null,
  room_id text,
  gift_id uuid references public.gift_catalog(id) on delete set null,
  stars_value numeric not null,
  quantity integer default 1,
  combo_count integer default 1,
  status text default 'Completed',
  is_self_gift boolean default false, -- from 0016
  created_at timestamptz default now()
);

-- 4. Create Gift Statistics Table
create table if not exists public.gift_statistics (
  user_id uuid references public.profiles(id) on delete cascade primary key,
  stars_sent_lifetime numeric default 0,
  stars_received_lifetime numeric default 0,
  highest_gift_value numeric default 0,
  highest_combo integer default 1,
  favorite_gift_id uuid references public.gift_catalog(id) on delete set null,
  favorite_receiver_id uuid references public.profiles(id) on delete set null,
  favorite_sender_id uuid references public.profiles(id) on delete set null,
  updated_at timestamptz default now()
);

-- 5. Create Gift Leaderboards Table
create table if not exists public.gift_leaderboards (
  user_id uuid references public.profiles(id) on delete cascade,
  type text not null check (type in ('gifter', 'receiver')),
  cycle text not null check (cycle in ('daily', 'weekly', 'monthly', 'lifetime')),
  cycle_key text not null,
  value numeric default 0,
  updated_at timestamptz default now(),
  primary key (user_id, type, cycle, cycle_key)
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
alter table public.gift_history add column if not exists stars_value numeric;
alter table public.gift_history add column if not exists room_id text;

-- 9. Create Gift Notifications Table
create table if not exists public.gift_notifications (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade,
  title text not null,
  content text not null,
  status text default 'Unread',
  created_at timestamptz default now()
);

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

-- 11. Create Gift Seat Logs Table
create table if not exists public.gift_seat_logs (
  id uuid default gen_random_uuid() primary key,
  transaction_id uuid references public.gift_transactions(id) on delete cascade,
  seat_index integer,
  receiver_id uuid,
  created_at timestamptz default now()
);

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

-- Enable RLS for all newly created tables
alter table public.gift_categories enable row level security;
alter table public.gift_catalog enable row level security;
alter table public.gift_transactions enable row level security;
alter table public.gift_statistics enable row level security;
alter table public.gift_leaderboards enable row level security;
alter table public.gift_animation enable row level security;
alter table public.gift_combo enable row level security;
alter table public.gift_history enable row level security;
alter table public.gift_notifications enable row level security;
alter table public.gift_wallet_logs enable row level security;
alter table public.gift_seat_logs enable row level security;
alter table public.gift_effects enable row level security;
alter table public.gift_assets enable row level security;
alter table public.gift_settings enable row level security;
alter table public.gift_event_logs enable row level security;

-- Setup RLS Policies (Authenticated users can read, only admin/system functions can write)
create policy "Allow read access to authenticated users on gift_categories" on public.gift_categories for select to authenticated using (true);
create policy "Allow read access to authenticated users on gift_catalog" on public.gift_catalog for select to authenticated using (true);
create policy "Allow read access to authenticated users on gift_transactions" on public.gift_transactions for select to authenticated using (true);
create policy "Allow read access to authenticated users on gift_statistics" on public.gift_statistics for select to authenticated using (true);
create policy "Allow read access to authenticated users on gift_leaderboards" on public.gift_leaderboards for select to authenticated using (true);
create policy "Allow read access to authenticated users on gift_animation" on public.gift_animation for select to authenticated using (true);
create policy "Allow read access to authenticated users on gift_combo" on public.gift_combo for select to authenticated using (true);
create policy "Allow read access to authenticated users on gift_history" on public.gift_history for select to authenticated using (true);
create policy "Allow read access to authenticated users on gift_notifications" on public.gift_notifications for select to authenticated using (true);
create policy "Allow read access to authenticated users on gift_wallet_logs" on public.gift_wallet_logs for select to authenticated using (true);
create policy "Allow read access to authenticated users on gift_seat_logs" on public.gift_seat_logs for select to authenticated using (true);
create policy "Allow read access to authenticated users on gift_effects" on public.gift_effects for select to authenticated using (true);
create policy "Allow read access to authenticated users on gift_assets" on public.gift_assets for select to authenticated using (true);
create policy "Allow read access to authenticated users on gift_settings" on public.gift_settings for select to authenticated using (true);
create policy "Allow read access to authenticated users on gift_event_logs" on public.gift_event_logs for select to authenticated using (true);

-- Seed Categories
insert into public.gift_categories (id, name, icon, display_order) values
('c1000000-0000-0000-0000-000000000001', 'Gold', '⭐', 1),
('c1000000-0000-0000-0000-000000000002', 'Silver', '🪙', 2)
on conflict (id) do update set name = EXCLUDED.name, icon = EXCLUDED.icon;

-- Seed Catalog
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
('a2000000-0000-0000-0000-000000000021', 'c1000000-0000-0000-0000-000000000002', 'Like', '👍', 2.0, 'silver', 'Common', true, false),
('a2000000-0000-0000-0000-000000000022', 'c1000000-0000-0000-0000-000000000002', 'Flower', '🌼', 5.0, 'silver', 'Common', true, false),
('a2000000-0000-0000-0000-000000000023', 'c1000000-0000-0000-0000-000000000002', 'Rose', '🌹', 10.0, 'silver', 'Common', true, false),
('a2000000-0000-0000-0000-000000000024', 'c1000000-0000-0000-0000-000000000002', 'Heart', '❤️', 15.0, 'silver', 'Common', true, false),
('a2000000-0000-0000-0000-000000000025', 'c1000000-0000-0000-0000-000000000002', 'Coffee', '☕', 20.0, 'silver', 'Common', true, false),
('a2000000-0000-0000-0000-000000000026', 'c1000000-0000-0000-0000-000000000002', 'Chocolate', '🍫', 25.0, 'silver', 'Common', true, false),
('a2000000-0000-0000-0000-000000000027', 'c1000000-0000-0000-0000-000000000002', 'Cake', '🎂', 30.0, 'silver', 'Rare', true, false),
('a2000000-0000-0000-0000-000000000028', 'c1000000-0000-0000-0000-000000000002', 'Balloon', '🎈', 35.0, 'silver', 'Rare', true, false),
('a2000000-0000-0000-0000-000000000029', 'c1000000-0000-0000-0000-000000000002', 'Gift Box', '🎁', 40.0, 'silver', 'Rare', true, false),
('a2000000-0000-0000-0000-000000000030', 'c1000000-0000-0000-0000-000000000002', 'Diamond', '💎', 50.0, 'silver', 'Rare', true, false)
on conflict (id) do nothing;


-- 16. Magic Gift Rewards & Budget tables (from 0015)
create table if not exists public.magic_gift_rewards (
  id uuid default gen_random_uuid() primary key,
  price_coins integer not null check (price_coins in (5, 10, 50, 499)),
  payout_type text not null check (payout_type in ('coin_back', 'silver_reward', 'vault_reward', 'nothing')),
  multiplier integer default 1,
  silver_amount integer default 0,
  vault_definition_id uuid,
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

create table if not exists public.magic_reward_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade,
  gift_id uuid references public.gift_catalog(id) on delete cascade,
  cost_coins integer not null,
  payout_type text not null,
  multiplier integer,
  coins_back integer,
  silver_reward integer,
  vault_item_name text,
  created_at timestamptz default now()
);

create table if not exists public.room_star_statistics (
  room_id text primary key,
  total_stars numeric default 0,
  total_gifts integer default 0,
  today_stars numeric default 0,
  today_gifts integer default 0,
  updated_at timestamptz default now()
);

create table if not exists public.seat_star_statistics (
  room_id text,
  seat_index integer,
  user_id uuid references public.profiles(id) on delete set null,
  stars_total numeric default 0,
  gifts_total integer default 0,
  updated_at timestamptz default now(),
  primary key (room_id, seat_index)
);

create table if not exists public.vault_gift_logs (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete cascade,
  receiver_id uuid references public.profiles(id) on delete cascade,
  vault_item_id uuid,
  created_at timestamptz default now()
);

-- Enable RLS for magic tables
alter table public.magic_gift_rewards enable row level security;
alter table public.magic_gift_budget enable row level security;
alter table public.magic_reward_logs enable row level security;
alter table public.room_star_statistics enable row level security;
alter table public.seat_star_statistics enable row level security;
alter table public.vault_gift_logs enable row level security;

create policy "Allow read to authenticated magic_gift_rewards" on public.magic_gift_rewards for select to authenticated using (true);
create policy "Allow read to authenticated magic_gift_budget" on public.magic_gift_budget for select to authenticated using (true);
create policy "Allow read to authenticated magic_reward_logs" on public.magic_reward_logs for select to authenticated using (true);
create policy "Allow read to authenticated room_star_statistics" on public.room_star_statistics for select to authenticated using (true);
create policy "Allow read to authenticated seat_star_statistics" on public.seat_star_statistics for select to authenticated using (true);
create policy "Allow read to authenticated vault_gift_logs" on public.vault_gift_logs for select to authenticated using (true);

-- Seed Magic Gift Rewards Rules (from 0015)
insert into public.magic_gift_rewards (price_coins, payout_type, multiplier, silver_amount, probability) values
-- For 5 Gold Coins gift (e.g. Magic Box)
(5, 'coin_back', 1, 0, 0.10),
(5, 'coin_back', 2, 0, 0.05),
(5, 'coin_back', 10, 0, 0.01),
(5, 'silver_reward', 0, 100, 0.15),
(5, 'nothing', 0, 0, 0.69),

-- For 50 Gold Coins gift (e.g. Crystal Ball)
(50, 'coin_back', 1, 0, 0.12),
(50, 'coin_back', 3, 0, 0.04),
(50, 'coin_back', 10, 0, 0.008),
(50, 'silver_reward', 0, 500, 0.20),
(50, 'nothing', 0, 0, 0.632),

-- For 499 Gold Coins gift (e.g. Car)
(499, 'coin_back', 1, 0, 0.15),
(499, 'coin_back', 5, 0, 0.03);

-- Initialize global budget (from 0015)
insert into public.magic_gift_budget (id, total_sold_coins, total_payout_coins, max_payout_ratio)
values ('global', 0, 0, 0.70)
on conflict (id) do nothing;


-- 17. Create Gifting Settings (from 0016)
create table if not exists public.gifting_settings (
  id text primary key,
  allow_self_gifting boolean default true,
  self_gift_payout_ratio numeric default 0.0 check (self_gift_payout_ratio >= 0.0 and self_gift_payout_ratio <= 1.0),
  exclude_self_gifts_from_leaderboards boolean default true,
  exclude_self_gifts_from_xp boolean default true,
  exclude_self_gifts_from_milestones boolean default true,
  updated_at timestamptz default now()
);

alter table public.gifting_settings enable row level security;
create policy "Allow read access to gifting_settings" on public.gifting_settings for select to authenticated using (true);

-- Seed default settings
insert into public.gifting_settings (id, allow_self_gifting, self_gift_payout_ratio, exclude_self_gifts_from_leaderboards, exclude_self_gifts_from_xp, exclude_self_gifts_from_milestones)
values ('global', true, 0.0, true, true, true)
on conflict (id) do nothing;


-- 18. DB triggers for seating session stats (from 0015)
create or replace function public.sync_room_seats_user_profile()
returns trigger as $$
declare
  v_username text;
  v_avatar text;
  v_level integer;
  v_avatar_frame text;
  v_vip_level integer;
  v_noble_level integer;
begin
  new.seat_number := new.seat_index;
  
  if new.user_id is not null then
    select username, avatar_url, level, avatar_frame, vip_level, novel_level
    into v_username, v_avatar, v_level, v_avatar_frame, v_vip_level, v_noble_level
    from public.profiles where id = new.user_id;

    new.username := v_username;
    new.avatar := v_avatar;
    new.level := v_level;
    new.avatar_frame := v_avatar_frame;
    new.vip_level := v_vip_level;
    new.noble_level := v_noble_level;
  else
    new.username := null;
    new.avatar := null;
    new.level := null;
    new.avatar_frame := null;
    new.vip_level := null;
    new.noble_level := null;
    new.is_speaking := false;
    
    new.seat_total_gifts := 0;
    new.seat_total_stars := 0;
  end if;

  if old.user_id is distinct from new.user_id then
    new.seat_total_gifts := 0;
    new.seat_total_stars := 0;
  end if;

  return new;
end;
$$ language plpgsql;

create or replace trigger trigger_sync_room_seats_user_profile
before insert or update on public.room_seats
for each row execute function public.sync_room_seats_user_profile();


-- 19. Magic Gift lottery draw logic function (from 0015)
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
  v_cumulative numeric := 0;
begin
  select * into v_budget from public.magic_gift_budget where id = 'global';
  
  update public.magic_gift_budget
  set total_sold_coins = total_sold_coins + p_cost
  where id = 'global';
  
  if coalesce(v_budget.total_sold_coins, 0) > 0 then
    v_current_ratio := coalesce(v_budget.total_payout_coins, 0) / coalesce(v_budget.total_sold_coins, 0);
  else
    v_current_ratio := 0;
  end if;

  v_rand := random();
  
  for v_payout_rule in (
    select * from public.magic_gift_rewards 
    where price_coins = p_cost 
    order by probability asc
  ) loop
    v_cumulative := v_cumulative + v_payout_rule.probability;
    if v_rand <= v_cumulative then
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

  if v_outcome_type = 'coin_back' and v_outcome_multiplier > 0 then
    update public.wallets set coins_balance = coins_balance + v_final_payout_cost where id = p_sender_id;
    update public.magic_gift_budget set total_payout_coins = total_payout_coins + v_final_payout_cost where id = 'global';
  elsif v_outcome_type = 'silver_reward' and v_silver_reward > 0 then
    update public.wallets set silver_coins_balance = silver_coins_balance + v_silver_reward where id = p_sender_id;
  end if;

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


-- 20. Centralized send_star_gift RPC fully patched (combines 0014, 0015, and 0016 settings checks)
create or replace function public.send_star_gift(
  p_room_id text,
  p_receiver_ids uuid[],
  p_gift_id uuid,
  p_quantity integer default 1,
  p_combo_count integer default 1,
  p_seat_indices integer[] default null
) returns jsonb as $$
declare
  v_sender_id uuid := auth.uid();
  v_sender_name text;
  v_sender_balance integer;
  v_gift_record record;
  v_receivers_count integer;
  v_cost_stars numeric;
  v_cost_coins integer;
  v_total_coins_cost integer;
  v_total_stars_cost numeric;
  v_receiver_id uuid;
  v_receiver_name text;
  v_receiver_idx integer;
  v_seat_index integer;
  v_tx_id uuid;
  
  v_daily_cycle text := to_char(current_date, 'YYYY-MM-DD');
  v_weekly_cycle text := to_char(current_date, 'YYYY-') || 'W' || to_char(current_date, 'IW');
  v_monthly_cycle text := to_char(current_date, 'YYYY-MM');
  v_lifetime_cycle text := 'lifetime';
  
  v_receivers_names_list text := '';
  v_magic_result jsonb := null;
  
  -- Self-gifting anti-abuse configuration parameters
  v_allow_self_gifting boolean;
  v_self_gift_payout_ratio numeric;
  v_exclude_self_gifts_from_leaderboards boolean;
  v_exclude_self_gifts_from_xp boolean;
  v_is_self_gift boolean := false;
begin
  if v_sender_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Load global settings
  select allow_self_gifting, self_gift_payout_ratio, exclude_self_gifts_from_leaderboards, exclude_self_gifts_from_xp
  into v_allow_self_gifting, v_self_gift_payout_ratio, v_exclude_self_gifts_from_leaderboards, v_exclude_self_gifts_from_xp
  from public.gifting_settings where id = 'global';

  v_receivers_count := array_length(p_receiver_ids, 1);
  if v_receivers_count is null or v_receivers_count = 0 then
    raise exception 'Recipient list cannot be empty.';
  end if;

  select * into v_gift_record from public.gift_catalog where id = p_gift_id and is_active = true;
  if v_gift_record.id is null then
    raise exception 'Selected gift is inactive or does not exist.';
  end if;

  v_cost_stars := v_gift_record.cost_stars;
  if v_gift_record.currency = 'gold' then
    v_cost_coins := v_cost_stars::integer;
  else
    v_cost_coins := (v_cost_stars * 100)::integer;
  end if;

  v_total_coins_cost := v_cost_coins * p_quantity * v_receivers_count;
  v_total_stars_cost := v_cost_stars * p_quantity * v_receivers_count;

  select username into v_sender_name from public.profiles where id = v_sender_id;
  if v_sender_name is null then
    v_sender_name := 'Sender';
  end if;

  if v_gift_record.currency = 'gold' then
    select coins_balance into v_sender_balance from public.wallets where id = v_sender_id;
    if coalesce(v_sender_balance, 0) < v_total_coins_cost then
      raise exception 'Insufficient Gold Coins (Requires % coins)', v_total_coins_cost;
    end if;
    update public.wallets set coins_balance = coins_balance - v_total_coins_cost where id = v_sender_id;
  else
    select silver_coins_balance into v_sender_balance from public.wallets where id = v_sender_id;
    if coalesce(v_sender_balance, 0) < v_total_coins_cost then
      raise exception 'Insufficient Silver Coins (Requires % coins)', v_total_coins_cost;
    end if;
    update public.wallets set silver_coins_balance = silver_coins_balance - v_total_coins_cost where id = v_sender_id;
  end if;

  insert into public.gift_wallet_logs (user_id, amount, currency, direction, reason)
  values (v_sender_id, v_total_coins_cost, v_gift_record.currency, 'Debit', 'Sent ' || v_gift_record.name || ' gift in room ' || p_room_id);

  if v_gift_record.is_magic = true and v_gift_record.currency = 'gold' then
    begin
      v_magic_result := public.draw_magic_gift_reward(v_sender_id, p_gift_id, v_cost_coins * p_quantity);
    exception when others then
      v_magic_result := null;
    end;
  end if;

  for v_receiver_idx in 1..v_receivers_count loop
    v_receiver_id := p_receiver_ids[v_receiver_idx];
    
    select username into v_receiver_name from public.profiles where id = v_receiver_id;
    if v_receiver_name is null then
      v_receiver_name := 'Receiver';
    end if;

    if v_receiver_idx = 1 then
      v_receivers_names_list := v_receiver_name;
    elsif v_receiver_idx = v_receivers_count then
      v_receivers_names_list := v_receivers_names_list || ' and ' || v_receiver_name;
    else
      v_receivers_names_list := v_receivers_names_list || ', ' || v_receiver_name;
    end if;

    if v_sender_id = v_receiver_id then
      if coalesce(v_allow_self_gifting, true) = false then
        raise exception 'Self-gifting is disabled by administrator.';
      end if;
      v_is_self_gift := true;
    end if;

    declare
      v_payout_amount integer;
    begin
      if v_is_self_gift then
        v_payout_amount := ((v_cost_coins * p_quantity) * coalesce(v_self_gift_payout_ratio, 0.0))::integer;
      else
        v_payout_amount := v_cost_coins * p_quantity;
      end if;

      if v_payout_amount > 0 then
        if v_gift_record.currency = 'gold' then
          update public.wallets set coins_balance = coins_balance + v_payout_amount where id = v_receiver_id;
        else
          update public.wallets set silver_coins_balance = silver_coins_balance + v_payout_amount where id = v_receiver_id;
        end if;

        insert into public.gift_wallet_logs (user_id, amount, currency, direction, reason)
        values (v_receiver_id, v_payout_amount, v_gift_record.currency, 'Credit', 'Received ' || v_gift_record.name || ' gift in room ' || p_room_id);
      end if;
    end;

    insert into public.gift_transactions (sender_id, receiver_id, room_id, gift_id, stars_value, quantity, combo_count, is_self_gift)
    values (v_sender_id, v_receiver_id, p_room_id, p_gift_id, v_cost_stars * p_quantity, p_quantity, p_combo_count, v_is_self_gift)
    returning id into v_tx_id;

    if p_seat_indices is not null and array_length(p_seat_indices, 1) >= v_receiver_idx then
      v_seat_index := p_seat_indices[v_receiver_idx];
      insert into public.gift_seat_logs (transaction_id, seat_index, receiver_id)
      values (v_tx_id, v_seat_index, v_receiver_id);
      
      update public.room_seats
      set seat_total_gifts = seat_total_gifts + p_quantity,
          seat_total_stars = seat_total_stars + (v_cost_stars * p_quantity),
          last_gift_time = now()
      where room_id = p_room_id and user_id = v_receiver_id;
    end if;

    insert into public.gift_history (sender_id, receiver_id, item_id, item_type, quantity, stars_value, room_id)
    values (v_sender_id, v_receiver_id, v_gift_record.name, 'VirtualGift', p_quantity, v_cost_stars * p_quantity, p_room_id);

    insert into public.gift_statistics (user_id, stars_received_lifetime, highest_gift_value, favorite_sender_id)
    values (v_receiver_id, v_cost_stars * p_quantity, v_cost_stars * p_quantity, v_sender_id)
    on conflict (user_id) do update set
      stars_received_lifetime = gift_statistics.stars_received_lifetime + (v_cost_stars * p_quantity),
      highest_gift_value = greatest(gift_statistics.highest_gift_value, v_cost_stars * p_quantity),
      favorite_sender_id = EXCLUDED.favorite_sender_id,
      updated_at = now();

    if not (v_is_self_gift and coalesce(v_exclude_self_gifts_from_leaderboards, true)) then
      insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value)
      values (v_receiver_id, 'receiver', 'daily', v_daily_cycle, v_cost_stars * p_quantity)
      on conflict (user_id, type, cycle, cycle_key) do update set value = gift_leaderboards.value + (v_cost_stars * p_quantity), updated_at = now();
      
      insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value)
      values (v_receiver_id, 'receiver', 'weekly', v_weekly_cycle, v_cost_stars * p_quantity)
      on conflict (user_id, type, cycle, cycle_key) do update set value = gift_leaderboards.value + (v_cost_stars * p_quantity), updated_at = now();

      insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value)
      values (v_receiver_id, 'receiver', 'monthly', v_monthly_cycle, v_cost_stars * p_quantity)
      on conflict (user_id, type, cycle, cycle_key) do update set value = gift_leaderboards.value + (v_cost_stars * p_quantity), updated_at = now();

      insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value)
      values (v_receiver_id, 'receiver', 'lifetime', v_lifetime_cycle, v_cost_stars * p_quantity)
      on conflict (user_id, type, cycle, cycle_key) do update set value = gift_leaderboards.value + (v_cost_stars * p_quantity), updated_at = now();
    end if;

    insert into public.gift_notifications (user_id, title, content)
    values (v_receiver_id, 'Received Gift! 🎁', v_sender_name || ' sent you ' || p_quantity || 'x ' || v_gift_record.name || ' (' || (v_cost_stars * p_quantity) || '★)');
  end loop;

  insert into public.gift_statistics (user_id, stars_sent_lifetime, highest_combo, favorite_gift_id)
  values (v_sender_id, v_total_stars_cost, p_combo_count, p_gift_id)
  on conflict (user_id) do update set
    stars_sent_lifetime = gift_statistics.stars_sent_lifetime + v_total_stars_cost,
    highest_combo = greatest(gift_statistics.highest_combo, p_combo_count),
    favorite_gift_id = EXCLUDED.favorite_gift_id,
    updated_at = now();

  if not (v_is_self_gift and coalesce(v_exclude_self_gifts_from_leaderboards, true)) then
    insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value)
    values (v_sender_id, 'gifter', 'daily', v_daily_cycle, v_total_stars_cost)
    on conflict (user_id, type, cycle, cycle_key) do update set value = gift_leaderboards.value + v_total_stars_cost, updated_at = now();

    insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value)
    values (v_sender_id, 'gifter', 'weekly', v_weekly_cycle, v_total_stars_cost)
    on conflict (user_id, type, cycle, cycle_key) do update set value = gift_leaderboards.value + v_total_stars_cost, updated_at = now();

    insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value)
    values (v_sender_id, 'gifter', 'monthly', v_monthly_cycle, v_total_stars_cost)
    on conflict (user_id, type, cycle, cycle_key) do update set value = gift_leaderboards.value + v_total_stars_cost, updated_at = now();

    insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value)
    values (v_sender_id, 'gifter', 'lifetime', v_lifetime_cycle, v_total_stars_cost)
    on conflict (user_id, type, cycle, cycle_key) do update set value = gift_leaderboards.value + v_total_stars_cost, updated_at = now();
  end if;

  update public.rooms
  set total_room_gifts = total_room_gifts + (p_quantity * v_receivers_count),
      today_room_gifts = today_room_gifts + (p_quantity * v_receivers_count),
      total_room_stars = total_room_stars + v_total_stars_cost,
      today_room_stars = today_room_stars + v_total_stars_cost,
      updated_at = now()
  where id = p_room_id;

  declare
    v_message_content text;
  begin
    if v_is_self_gift then
      if p_quantity > 1 then
        v_message_content := v_sender_name || ' self-gifted ' || p_quantity || '× ' || v_gift_record.icon || ' ' || v_gift_record.name || ' to themselves';
      else
        v_message_content := v_sender_name || ' self-gifted ' || v_gift_record.icon || ' ' || v_gift_record.name || ' to themselves';
      end if;
    else
      if v_receivers_count = 1 then
        if p_quantity > 1 then
          v_message_content := v_sender_name || ' sent ' || p_quantity || '× ' || v_gift_record.icon || ' ' || v_gift_record.name || ' to ' || v_receivers_names_list;
        else
          v_message_content := v_sender_name || ' sent ' || v_gift_record.icon || ' ' || v_gift_record.name || ' to ' || v_receivers_names_list;
        end if;
      elsif v_receivers_count >= 10 then 
        v_message_content := v_sender_name || ' gifted everyone with ' || v_gift_record.icon || ' ' || v_gift_record.name;
      else
        v_message_content := v_sender_name || ' sent ' || v_gift_record.icon || ' ' || v_gift_record.name || ' to ' || v_receivers_count || ' selected users';
      end if;
    end if;

    insert into public.room_messages (
      room_id, sender_id, content, message_type, metadata
    ) values (
      p_room_id, v_sender_id,
      v_message_content,
      'gift',
      jsonb_build_object(
        'gift_id', p_gift_id::text,
        'gift_name', v_gift_record.name,
        'gift_icon', v_gift_record.icon,
        'stars_value', v_cost_stars,
        'quantity', p_quantity,
        'combo_count', p_combo_count,
        'receivers_count', v_receivers_count,
        'receivers_names', v_receivers_names_list,
        'receiver_ids', p_receiver_ids,
        'is_self_gift', v_is_self_gift
      )
    );
  end;

  if not (v_is_self_gift and coalesce(v_exclude_self_gifts_from_xp, true)) then
    begin
      perform public.process_xp_event('gift_sent', jsonb_build_object('recipient_id', p_receiver_ids[1], 'gift_id', p_gift_id::text));
    exception when others then
      null;
    end;
  end if;

  return jsonb_build_object(
    'success', true,
    'remaining_balance', v_sender_balance - v_total_coins_cost,
    'total_stars_cost', v_total_stars_cost,
    'magic_result', v_magic_result
  );
end;
$$ language plpgsql security definer;


-- 21. Create get_room_contribution_stats (from 0015)
create or replace function public.get_room_contribution_stats(p_room_id text)
returns jsonb as $$
declare
  v_total_stars numeric := 0;
  v_total_gifts integer := 0;
  v_today_stars numeric := 0;
  v_today_gifts integer := 0;
  v_top_contributors jsonb;
  v_top_receivers jsonb;
begin
  select coalesce(total_room_stars, 0), coalesce(total_room_gifts, 0), coalesce(today_room_stars, 0), coalesce(today_room_gifts, 0)
  into v_total_stars, v_total_gifts, v_today_stars, v_today_gifts
  from public.rooms where id = p_room_id;

  select jsonb_agg(d) into v_top_contributors from (
    select 
      t.sender_id as user_id, 
      p.username, 
      p.avatar_url as avatar,
      sum(t.stars_value) as stars_value
    from public.gift_transactions t
    join public.profiles p on p.id = t.sender_id
    where t.room_id = p_room_id
    group by t.sender_id, p.username, p.avatar_url
    order by stars_value desc
    limit 5
  ) d;

  select jsonb_agg(d) into v_top_receivers from (
    select 
      t.receiver_id as user_id, 
      p.username, 
      p.avatar_url as avatar,
      sum(t.stars_value) as stars_value
    from public.gift_transactions t
    join public.profiles p on p.id = t.receiver_id
    where t.room_id = p_room_id
    group by t.receiver_id, p.username, p.avatar_url
    order by stars_value desc
    limit 5
  ) d;

  return jsonb_build_object(
    'total_stars', v_total_stars,
    'total_gifts', v_total_gifts,
    'session_stars', v_today_stars,
    'session_gifts', v_today_gifts,
    'top_contributors', coalesce(v_top_contributors, '[]'::jsonb),
    'top_receivers', coalesce(v_top_receivers, '[]'::jsonb)
  );
end;
$$ language plpgsql security definer;


-- 22. Create get_user_contribution_stats (from 0015)
create or replace function public.get_user_contribution_stats(p_user_id uuid)
returns jsonb as $$
declare
  v_lifetime_sent numeric := 0;
  v_today_sent numeric := 0;
  v_month_sent numeric := 0;
  v_year_sent numeric := 0;
  
  v_daily_key text := to_char(current_date, 'YYYY-MM-DD');
  v_monthly_key text := to_char(current_date, 'YYYY-MM');
  v_yearly_key text := to_char(current_date, 'YYYY');
  
  v_top_friend_name text;
  v_favorite_gift_name text;
begin
  select coalesce(sum(stars_value), 0) into v_lifetime_sent from public.gift_transactions where sender_id = p_user_id;
  select coalesce(sum(stars_value), 0) into v_today_sent from public.gift_transactions where sender_id = p_user_id and to_char(created_at, 'YYYY-MM-DD') = v_daily_key;
  select coalesce(sum(stars_value), 0) into v_month_sent from public.gift_transactions where sender_id = p_user_id and to_char(created_at, 'YYYY-MM') = v_monthly_key;
  select coalesce(sum(stars_value), 0) into v_year_sent from public.gift_transactions where sender_id = p_user_id and to_char(created_at, 'YYYY') = v_yearly_key;

  select p.username into v_top_friend_name
  from public.gift_transactions t
  join public.profiles p on p.id = t.receiver_id
  where t.sender_id = p_user_id
  group by p.username
  order by sum(t.stars_value) desc
  limit 1;

  select c.name into v_favorite_gift_name
  from public.gift_transactions t
  join public.gift_catalog c on c.id = t.gift_id
  where t.sender_id = p_user_id
  group by c.name
  order by count(t.id) desc
  limit 1;

  return jsonb_build_object(
    'lifetime_contribution', v_lifetime_sent,
    'today_contribution', v_today_sent,
    'monthly_contribution', v_month_sent,
    'yearly_contribution', v_year_sent,
    'top_friend', coalesce(v_top_friend_name, 'None'),
    'favorite_gift', coalesce(v_favorite_gift_name, 'None')
  );
end;
$$ language plpgsql security definer;


-- 23. Create User Gifting History list views (from 0015)
create or replace view public.user_received_gifts as
select 
  t.id,
  t.sender_id,
  p_sender.username as sender_username,
  p_sender.avatar_url as sender_avatar,
  t.receiver_id,
  p_receiver.username as receiver_username,
  t.gift_id,
  c.name as gift_name,
  c.icon as gift_icon,
  t.stars_value,
  t.quantity,
  t.created_at
from public.gift_transactions t
join public.profiles p_sender on p_sender.id = t.sender_id
join public.profiles p_receiver on p_receiver.id = t.receiver_id
join public.gift_catalog c on c.id = t.gift_id;

create or replace view public.user_sent_gifts as
select 
  t.id,
  t.sender_id,
  p_sender.username as sender_username,
  t.receiver_id,
  p_receiver.username as receiver_username,
  p_receiver.avatar_url as receiver_avatar,
  t.gift_id,
  c.name as gift_name,
  c.icon as gift_icon,
  t.stars_value,
  t.quantity,
  t.created_at
from public.gift_transactions t
join public.profiles p_sender on p_sender.id = t.sender_id
join public.profiles p_receiver on p_receiver.id = t.receiver_id
join public.gift_catalog c on c.id = t.gift_id;


-- 24. Patch public.gift_vault_item (from 0016)
create or replace function public.gift_vault_item(p_item_id uuid, p_receiver_id uuid)
returns jsonb as $$
declare
  v_item record;
  v_asset record;
  v_allow_self_gifting boolean;
  v_exclude_self_gifts_from_xp boolean;
begin
  select allow_self_gifting, exclude_self_gifts_from_xp
  into v_allow_self_gifting, v_exclude_self_gifts_from_xp
  from public.gifting_settings where id = 'global';

  if not exists (select 1 from public.profiles where id = p_receiver_id) then
    return jsonb_build_object('success', false, 'reason', 'Receiver profile not found.');
  end if;

  if p_receiver_id = auth.uid() and coalesce(v_allow_self_gifting, true) = false then
    return jsonb_build_object('success', false, 'reason', 'Self-gifting is disabled by administrator.');
  end if;

  select * into v_item from public.vault_items where id = p_item_id and user_id = auth.uid();
  if not found then
    return jsonb_build_object('success', false, 'reason', 'Item not found in your vault.');
  end if;

  select * into v_asset from public.asset_definitions where id = v_item.asset_id;

  if not v_asset.giftable then
    return jsonb_build_object('success', false, 'reason', 'This item is not giftable.');
  end if;

  if v_item.quantity <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Insufficient item quantity.');
  end if;

  update public.vault_items 
  set quantity = quantity - 1,
      status = case when quantity - 1 = 0 then 'Gifted'::text else status end
  where id = p_item_id;

  insert into public.vault_item_history (user_id, vault_item_id, action_type, quantity, details)
  values (auth.uid(), p_item_id, 'Gifted', 1, 'Gifted ' || v_asset.display_name || ' to user ' || p_receiver_id);

  insert into public.vault_items (user_id, asset_id, quantity, status)
  values (p_receiver_id, v_asset.id, 1, 'Active')
  on conflict (user_id, asset_id) do update set 
    quantity = vault_items.quantity + 1,
    status = 'Active';

  insert into public.vault_item_history (user_id, vault_item_id, action_type, quantity, details)
  values (p_receiver_id, p_item_id, 'Received', 1, 'Received ' || v_asset.display_name || ' as a gift from user ' || auth.uid());

  if not (p_receiver_id = auth.uid() and coalesce(v_exclude_self_gifts_from_xp, true)) then
    begin
      perform public.process_xp_event('gift_sent', jsonb_build_object('recipient_id', p_receiver_id, 'gift_id', p_item_id::text));
    exception when others then
      null;
    end;
  end if;

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;
