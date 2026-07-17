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

create table if not exists public.magic_reward_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete set null,
  gift_id uuid,
  cost_coins integer,
  payout_type text,
  multiplier integer,
  coins_back integer,
  silver_reward integer,
  vault_item_name text,
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

-- 4. Create Vault Gift Logs Table
create table if not exists public.vault_gift_logs (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete set null,
  receiver_id uuid references public.profiles(id) on delete set null,
  room_id text,
  definition_id uuid,
  quantity integer default 1,
  created_at timestamptz default now()
);

-- Enable RLS for newly created tables
alter table public.magic_gift_rewards enable row level security;
alter table public.magic_gift_budget enable row level security;
alter table public.magic_reward_logs enable row level security;
alter table public.room_star_statistics enable row level security;
alter table public.seat_star_statistics enable row level security;
alter table public.vault_gift_logs enable row level security;

-- Setup RLS Policies
create policy "Allow read access to magic_gift_rewards" on public.magic_gift_rewards for select to authenticated using (true);
create policy "Allow read access to magic_gift_budget" on public.magic_gift_budget for select to authenticated using (true);
create policy "Allow read access to magic_reward_logs" on public.magic_reward_logs for select to authenticated using (true);
create policy "Allow read access to room_star_statistics" on public.room_star_statistics for select to authenticated using (true);
create policy "Allow read access to seat_star_statistics" on public.seat_star_statistics for select to authenticated using (true);
create policy "Allow read access to vault_gift_logs" on public.vault_gift_logs for select to authenticated using (true);

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


-- 6. Reset Seating total session stars when user leaves the seat index
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
    
    -- Reset session indicators
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


-- 8. Refactor CENTRALIZED send_star_gift RPC to handle magic lottery triggers and dynamic logging
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
  
  -- Magic Gift Payout details
  v_magic_result jsonb := null;
  
  -- Leaderboard cycle keys
  v_daily_cycle text := to_char(current_date, 'YYYY-MM-DD');
  v_weekly_cycle text := to_char(current_date, 'YYYY-') || 'W' || to_char(current_date, 'IW');
  v_monthly_cycle text := to_char(current_date, 'YYYY-MM');
  v_lifetime_cycle text := 'lifetime';
  
  v_receivers_names_list text := '';
begin
  if v_sender_id is null then
    raise exception 'Not authenticated';
  end if;

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

  -- Process Magic Gift Lottery draw if applicable
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

    if v_sender_id <> v_receiver_id then
      if v_gift_record.currency = 'gold' then
        update public.wallets set coins_balance = coins_balance + (v_cost_coins * p_quantity) where id = v_receiver_id;
      else
        update public.wallets set silver_coins_balance = silver_coins_balance + (v_cost_coins * p_quantity) where id = v_receiver_id;
      end if;
      
      insert into public.gift_wallet_logs (user_id, amount, currency, direction, reason)
      values (v_receiver_id, v_cost_coins * p_quantity, v_gift_record.currency, 'Credit', 'Received ' || v_gift_record.name || ' gift in room ' || p_room_id);
    end if;

    insert into public.gift_transactions (sender_id, receiver_id, room_id, gift_id, stars_value, quantity, combo_count)
    values (v_sender_id, v_receiver_id, p_room_id, p_gift_id, v_cost_stars * p_quantity, p_quantity, p_combo_count)
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

  update public.rooms
  set total_room_gifts = total_room_gifts + (p_quantity * v_receivers_count),
      today_room_gifts = today_room_gifts + (p_quantity * v_receivers_count),
      total_room_stars = total_room_stars + v_total_stars_cost,
      today_room_stars = today_room_stars + v_total_stars_cost,
      updated_at = now()
  where id = p_room_id;

  -- Create clean formatted message body
  declare
    v_message_content text;
  begin
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
        'receiver_ids', p_receiver_ids
      )
    );
  end;

  begin
    perform public.process_xp_event('gift_sent', jsonb_build_object('recipient_id', p_receiver_ids[1], 'gift_id', p_gift_id::text));
  exception when others then
    null;
  end;

  return jsonb_build_object(
    'success', true,
    'remaining_balance', v_sender_balance - v_total_coins_cost,
    'total_stars_cost', v_total_stars_cost,
    'magic_result', v_magic_result
  );
end;
$$ language plpgsql security definer;


-- 9. Create Room Gifting & Contribution Stats RPC View helper
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

  -- Fetch top 5 contributors
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

  -- Fetch top 5 receivers
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


-- 10. Create User Contribution Center helper
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
  v_favorite_receiver_name text;
begin
  -- Sentinel totals
  select coalesce(sum(stars_value), 0) into v_lifetime_sent from public.gift_transactions where sender_id = p_user_id;
  select coalesce(sum(stars_value), 0) into v_today_sent from public.gift_transactions where sender_id = p_user_id and to_char(created_at, 'YYYY-MM-DD') = v_daily_key;
  select coalesce(sum(stars_value), 0) into v_month_sent from public.gift_transactions where sender_id = p_user_id and to_char(created_at, 'YYYY-MM') = v_monthly_key;
  select coalesce(sum(stars_value), 0) into v_year_sent from public.gift_transactions where sender_id = p_user_id and to_char(created_at, 'YYYY') = v_yearly_key;

  -- Top Friend (receiver user who user has sent most stars to)
  select p.username into v_top_friend_name
  from public.gift_transactions t
  join public.profiles p on p.id = t.receiver_id
  where t.sender_id = p_user_id
  group by p.username
  order by sum(t.stars_value) desc
  limit 1;

  -- Favorite Gift
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


-- 11. Create User Gifting History list views
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
