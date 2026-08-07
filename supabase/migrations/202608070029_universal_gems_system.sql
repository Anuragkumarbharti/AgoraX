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

insert into public.gift_catalog (id, category_id, name, icon, cost_stars, currency, gold_price, silver_price, gem_value, rarity, is_active, is_magic, is_volt, gift_type) values
-- Gold Gifts (1 Gold = 1 Gem value)
('a2000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'Like', '👍', 2, 'gold', 2, null, 2, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001', 'Flower', '🌼', 5, 'gold', 5, null, 5, 'Common', true, true, false, 'normal'),
('a2000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000001', 'Rose', '🌹', 10, 'gold', 10, null, 10, 'Common', true, true, false, 'normal'),
('a2000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000001', 'Heart', '❤️', 15, 'gold', 15, null, 15, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000001', 'Coffee', '☕', 20, 'gold', 20, null, 20, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000006', 'c1000000-0000-0000-0000-000000000001', 'Chocolate', '🍫', 25, 'gold', 25, null, 25, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000007', 'c1000000-0000-0000-0000-000000000001', 'Cake', '🎂', 30, 'gold', 30, null, 30, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000008', 'c1000000-0000-0000-0000-000000000001', 'Balloon', '🎈', 35, 'gold', 35, null, 35, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000009', 'c1000000-0000-0000-0000-000000000001', 'Gift Box', '🎁', 40, 'gold', 40, null, 40, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000010', 'c1000000-0000-0000-0000-000000000001', 'Diamond', '💎', 50, 'gold', 50, null, 50, 'Common', true, true, false, 'normal'),
('a2000000-0000-0000-0000-000000000011', 'c1000000-0000-0000-0000-000000000001', 'Crown', '👑', 99, 'gold', 99, null, 99, 'Epic', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000012', 'c1000000-0000-0000-0000-000000000001', 'Butterfly', '🦋', 99, 'gold', 99, null, 99, 'Epic', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000013', 'c1000000-0000-0000-0000-000000000001', 'Sports Car', '🏎️', 499, 'gold', 499, null, 499, 'Legendary', true, true, false, 'normal'),
('a2000000-0000-0000-0000-000000000014', 'c1000000-0000-0000-0000-000000000001', 'Private Jet', '✈️', 499, 'gold', 499, null, 499, 'Mythic', true, true, false, 'normal'),

-- Silver Gifts (100 Silver = 1 Gem value)
('a2000000-0000-0000-0000-000000000021', 'c1000000-0000-0000-0000-000000000002', 'Like', '👍', 200, 'silver', null, 200, 2, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000022', 'c1000000-0000-0000-0000-000000000002', 'Flower', '🌼', 500, 'silver', null, 500, 5, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000023', 'c1000000-0000-0000-0000-000000000002', 'Rose', '🌹', 1000, 'silver', null, 1000, 10, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000024', 'c1000000-0000-0000-0000-000000000002', 'Heart', '❤️', 1500, 'silver', null, 1500, 15, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000025', 'c1000000-0000-0000-0000-000000000002', 'Coffee', '☕', 2000, 'silver', null, 2000, 20, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000026', 'c1000000-0000-0000-0000-000000000002', 'Chocolate', '🍫', 2500, 'silver', null, 2500, 25, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000027', 'c1000000-0000-0000-0000-000000000002', 'Cake', '🎂', 3000, 'silver', null, 3000, 30, 'Rare', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000028', 'c1000000-0000-0000-0000-000000000002', 'Balloon', '🎈', 3500, 'silver', null, 3500, 35, 'Rare', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000029', 'c1000000-0000-0000-0000-000000000002', 'Gift Box', '🎁', 4000, 'silver', null, 4000, 40, 'Rare', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000030', 'c1000000-0000-0000-0000-000000000002', 'Diamond', '💎', 5000, 'silver', null, 5000, 50, 'Rare', true, false, false, 'normal'),

-- Volt Gifts (Gems are primary identity)
('a2000000-0000-0000-0000-000000000041', 'c1000000-0000-0000-0000-000000000003', 'Volt Star', '⚡', 250, 'volt', 250, null, 250, 'Epic', true, false, true, 'volt'),
('a2000000-0000-0000-0000-000000000042', 'c1000000-0000-0000-0000-000000000003', 'Volt Dragon', '🐲', 1000, 'volt', 1000, null, 1000, 'Legendary', true, true, true, 'volt'),
('a2000000-0000-0000-0000-000000000043', 'c1000000-0000-0000-0000-000000000003', 'Volt Thunder', '🌩️', 2500, 'volt', 2500, null, 2500, 'Mythic', true, true, true, 'volt');

-- 4. Transaction Ledger & Statistics Schema Compatibility
alter table public.gift_transactions add column if not exists gems_value numeric default 0;
alter table public.gift_history add column if not exists gems_value numeric default 0;

alter table public.gift_statistics add column if not exists gems_sent_lifetime numeric default 0;
alter table public.gift_statistics add column if not exists gems_received_lifetime numeric default 0;

alter table public.profiles add column if not exists total_gems_received numeric default 0;
alter table public.profiles add column if not exists total_gems_sent numeric default 0;

alter table public.rooms add column if not exists total_room_gems numeric default 0;
alter table public.rooms add column if not exists today_room_gems numeric default 0;

alter table public.room_seats add column if not exists seat_total_gems numeric default 0;

-- 5. Production-Ready Atomic send_star_gift RPC with Universal Gems Engine
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
  v_sender_avatar text;
  v_coins_bal integer := 0;
  v_gold_bal integer := 0;
  v_silver_bal integer := 0;
  v_sender_balance integer := 0;
  v_gift_record record;
  v_gift_icon text := '';
  v_receivers_count integer;
  
  -- Price vs Gems
  v_cost_coins integer;
  v_total_coins_cost integer;
  v_gem_unit_value integer;
  v_single_receiver_gems integer;
  v_total_gems integer;

  v_receiver_id uuid;
  v_receiver_name text;
  v_receiver_idx integer := 1;
  v_seat_index integer := -1;
  v_tx_id uuid;
  v_dual_result jsonb;

  v_daily_cycle text := to_char(current_date, 'YYYY-MM-DD');
  v_weekly_cycle text := to_char(current_date, 'YYYY-') || 'W' || to_char(current_date, 'IW');
  v_monthly_cycle text := to_char(current_date, 'YYYY-MM');
  v_lifetime_cycle text := 'lifetime';

  v_receivers_names_list text := '';
  v_receivers_names_array text[] := array[]::text[];
  v_formatted_gift_message text;
  v_event_payload jsonb;

  v_allow_self_gifting boolean := true;
  v_self_gift_payout_ratio numeric := 0.70;
  v_exclude_self_gifts_from_leaderboards boolean := true;
  v_exclude_self_gifts_from_xp boolean := true;
  v_is_self_gift boolean := false;

  -- Lucky Gift Coin Back Variables
  v_is_lucky boolean := false;
  v_rng_roll integer;
  v_multiplier numeric := 0;
  v_coins_back integer := 0;
  v_remaining_balance integer := 0;
  v_tier text := 'no_reward';
  v_lucky_result jsonb := null;
  v_lucky_msg_text text := '';
  v_final_check_balance integer := 0;
begin
  -- 1. Validate Auth
  if v_sender_id is null then
    raise exception 'Not authenticated';
  end if;

  begin
    select allow_self_gifting, self_gift_payout_ratio, exclude_self_gifts_from_leaderboards, exclude_self_gifts_from_xp
    into v_allow_self_gifting, v_self_gift_payout_ratio, v_exclude_self_gifts_from_leaderboards, v_exclude_self_gifts_from_xp
    from public.gifting_settings where id = 'global';
  exception when others then
    v_allow_self_gifting := true;
  end;

  -- 2. Validate Receiver List
  v_receivers_count := array_length(p_receiver_ids, 1);
  if v_receivers_count is null or v_receivers_count = 0 then
    raise exception 'Recipient list cannot be empty.';
  end if;

  -- 3. Lookup Gift Catalog Item
  select * into v_gift_record from public.gift_catalog where id = p_gift_id and is_active = true;
  if v_gift_record.id is null then
    select * into v_gift_record from public.gift_catalog where id = p_gift_id limit 1;
    if v_gift_record.id is null then
      raise exception 'Selected gift is inactive or does not exist.';
    end if;
  end if;

  -- Extract icon safely
  v_gift_icon := coalesce(
    to_jsonb(v_gift_record)->>'icon',
    to_jsonb(v_gift_record)->>'icon_url',
    ''
  );

  -- 4. Calculate Currency Price vs Universal Gem Value
  v_cost_coins := coalesce(v_gift_record.cost_stars, 10);
  v_total_coins_cost := v_cost_coins * p_quantity * p_combo_count * v_receivers_count;

  v_gem_unit_value := coalesce(v_gift_record.gem_value, 0);
  if v_gem_unit_value <= 0 then
    if coalesce(v_gift_record.currency, 'gold') = 'silver' then
      v_gem_unit_value := greatest(1, floor(v_cost_coins / 100.0)::integer);
    else
      v_gem_unit_value := v_cost_coins;
    end if;
  end if;

  v_single_receiver_gems := v_gem_unit_value * p_quantity * p_combo_count;
  v_total_gems := v_single_receiver_gems * v_receivers_count;

  -- 5. Ensure sender wallet exists with ZERO default balance
  insert into public.wallets (id, coins_balance, gold_coins, silver_coins)
  values (v_sender_id, 0, 0, 0)
  on conflict (id) do nothing;

  -- 6. Lock Sender Wallet Row & Fetch Balance
  select coalesce(coins_balance, 0), coalesce(gold_coins, 0), coalesce(silver_coins, 0)
  into v_coins_bal, v_gold_bal, v_silver_bal
  from public.wallets
  where id = v_sender_id
  for update;

  if coalesce(v_gift_record.currency, 'gold') = 'silver' then
    v_sender_balance := v_silver_bal;
  else
    v_sender_balance := greatest(v_coins_bal, v_gold_bal);
  end if;

  -- 7. Strict Balance Validation (NO auto top-up!)
  if v_sender_balance < v_total_coins_cost then
    raise exception 'Insufficient balance: Required % coins, but your balance is % coins.', v_total_coins_cost, v_sender_balance;
  end if;

  -- 8. Deduct Exact Currency Cost Atomically
  if coalesce(v_gift_record.currency, 'gold') = 'silver' then
    update public.wallets
    set silver_coins = greatest(0, silver_coins - v_total_coins_cost),
        updated_at = timezone('utc'::text, now())
    where id = v_sender_id;
  else
    update public.wallets
    set coins_balance = greatest(0, coins_balance - v_total_coins_cost),
        gold_coins = greatest(0, gold_coins - v_total_coins_cost),
        updated_at = timezone('utc'::text, now())
    where id = v_sender_id;
  end if;

  v_remaining_balance := v_sender_balance - v_total_coins_cost;

  -- Audit log into public.wallet_transactions
  insert into public.wallet_transactions (
    wallet_id, amount, currency, type, status, reference_id, details
  ) values (
    v_sender_id, v_total_coins_cost, coalesce(v_gift_record.currency, 'gold'), 'Spend', 'Completed',
    gen_random_uuid()::text,
    'Sent ' || p_quantity::text || 'x ' || coalesce(v_gift_record.name, 'Gift') || ' in room ' || p_room_id
  );

  -- 9. Fetch Sender Details
  select display_name, avatar_url into v_sender_name, v_sender_avatar
  from public.profiles where id = v_sender_id;
  if v_sender_name is null or v_sender_name = '' then
    v_sender_name := 'Creania Student';
  end if;

  -- 10. Update Sender Gems Stats & Leaderboards
  update public.profiles
  set total_gems_sent = coalesce(total_gems_sent, 0) + v_total_gems,
      total_stars_gifted = coalesce(total_stars_gifted, 0) + v_total_gems,
      updated_at = timezone('utc'::text, now())
  where id = v_sender_id;

  insert into public.gift_statistics (user_id, gems_sent_lifetime, stars_sent_lifetime, highest_gift_value, highest_combo, updated_at)
  values (v_sender_id, v_total_gems, v_total_gems, v_gem_unit_value, p_combo_count, timezone('utc'::text, now()))
  on conflict (user_id) do update set
    gems_sent_lifetime = coalesce(gift_statistics.gems_sent_lifetime, 0) + v_total_gems,
    stars_sent_lifetime = coalesce(gift_statistics.stars_sent_lifetime, 0) + v_total_gems,
    highest_gift_value = greatest(coalesce(gift_statistics.highest_gift_value, 0), v_gem_unit_value),
    highest_combo = greatest(coalesce(gift_statistics.highest_combo, 1), p_combo_count),
    updated_at = timezone('utc'::text, now());

  -- Update Universal Gems Leaderboards (Daily, Weekly, Monthly, Lifetime)
  insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value, updated_at)
  values (v_sender_id, 'gifter', 'daily', v_daily_cycle, v_total_gems, timezone('utc'::text, now()))
  on conflict (user_id, type, cycle, cycle_key) do update set
    value = gift_leaderboards.value + v_total_gems, updated_at = timezone('utc'::text, now());

  insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value, updated_at)
  values (v_sender_id, 'gifter', 'weekly', v_weekly_cycle, v_total_gems, timezone('utc'::text, now()))
  on conflict (user_id, type, cycle, cycle_key) do update set
    value = gift_leaderboards.value + v_total_gems, updated_at = timezone('utc'::text, now());

  insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value, updated_at)
  values (v_sender_id, 'gifter', 'monthly', v_monthly_cycle, v_total_gems, timezone('utc'::text, now()))
  on conflict (user_id, type, cycle, cycle_key) do update set
    value = gift_leaderboards.value + v_total_gems, updated_at = timezone('utc'::text, now());

  insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value, updated_at)
  values (v_sender_id, 'gifter', 'lifetime', v_lifetime_cycle, v_total_gems, timezone('utc'::text, now()))
  on conflict (user_id, type, cycle, cycle_key) do update set
    value = gift_leaderboards.value + v_total_gems, updated_at = timezone('utc'::text, now());

  -- 11. Update Room Stats & Room XP (1 Gem = 1 Room XP!)
  update public.rooms
  set total_room_gems = coalesce(total_room_gems, 0) + v_total_gems,
      today_room_gems = coalesce(today_room_gems, 0) + v_total_gems,
      total_room_stars = coalesce(total_room_stars, 0) + v_total_gems,
      today_room_stars = coalesce(today_room_stars, 0) + v_total_gems,
      total_room_gifts = coalesce(total_room_gifts, 0) + (p_quantity * p_combo_count * v_receivers_count),
      today_room_gifts = coalesce(today_room_gifts, 0) + (p_quantity * p_combo_count * v_receivers_count),
      room_xp = coalesce(room_xp, 0) + v_total_gems, -- 1 Gem = 1 Room XP
      today_room_xp = coalesce(today_room_xp, 0) + v_total_gems,
      updated_at = timezone('utc'::text, now())
  where id = p_room_id;

  -- 12. Process Receivers & Insert into Ledger Tables
  v_receiver_idx := 1;
  foreach v_receiver_id in array p_receiver_ids loop
    v_is_self_gift := (v_sender_id = v_receiver_id);
    v_seat_index := -1;
    if p_seat_indices is not null and array_length(p_seat_indices, 1) >= v_receiver_idx then
      v_seat_index := p_seat_indices[v_receiver_idx];
    end if;

    select display_name into v_receiver_name from public.profiles where id = v_receiver_id;
    if v_receiver_name is null or v_receiver_name = '' then
      v_receiver_name := 'User';
    end if;
    v_receivers_names_array := array_append(v_receivers_names_array, v_receiver_name);

    -- Record Gift Transaction Log with Gems Value
    insert into public.gift_transactions (
      room_id, sender_id, receiver_id, gift_id, gift_name, gift_icon,
      amount, currency, count, quantity, gems_value, stars_value, combo_count, seat_index, is_self_gift, created_at
    ) values (
      p_room_id, v_sender_id, v_receiver_id, p_gift_id, coalesce(v_gift_record.name, 'Gift'), v_gift_icon,
      v_cost_coins, coalesce(v_gift_record.currency, 'gold'), p_quantity, p_quantity, v_single_receiver_gems, v_single_receiver_gems, p_combo_count, v_seat_index, v_is_self_gift, timezone('utc'::text, now())
    ) returning id into v_tx_id;

    -- Record Gift History Log with Gems Value
    insert into public.gift_history (
      sender_id, receiver_id, item_id, item_type, quantity, gems_value, stars_value, room_id, created_at
    ) values (
      v_sender_id, v_receiver_id, coalesce(v_gift_record.name, 'Gift'), 'VirtualGift', p_quantity * p_combo_count, v_single_receiver_gems, v_single_receiver_gems, p_room_id, timezone('utc'::text, now())
    );

    -- Update Seat Level Gems
    if v_seat_index >= 0 then
      update public.room_seats
      set seat_total_gifts = coalesce(seat_total_gifts, 0) + (p_quantity * p_combo_count),
          seat_total_gems = coalesce(seat_total_gems, 0) + v_single_receiver_gems,
          seat_total_stars = coalesce(seat_total_stars, 0) + v_single_receiver_gems,
          last_gift_time = timezone('utc'::text, now())
      where room_id = p_room_id and user_id = v_receiver_id;
    end if;

    -- Update Recipient Profile Gems & Leaderboards
    if not v_is_self_gift or v_self_gift_payout_ratio > 0 then
      update public.profiles
      set total_gems_received = coalesce(total_gems_received, 0) + (v_single_receiver_gems * (case when v_is_self_gift then v_self_gift_payout_ratio else 1.0 end)),
          total_stars_received = coalesce(total_stars_received, 0) + (v_single_receiver_gems * (case when v_is_self_gift then v_self_gift_payout_ratio else 1.0 end))::integer,
          updated_at = timezone('utc'::text, now())
      where id = v_receiver_id;

      insert into public.gift_statistics (user_id, gems_received_lifetime, stars_received_lifetime, highest_gift_value, favorite_sender_id, updated_at)
      values (v_receiver_id, v_single_receiver_gems, v_single_receiver_gems, v_gem_unit_value, v_sender_id, timezone('utc'::text, now()))
      on conflict (user_id) do update set
        gems_received_lifetime = coalesce(gift_statistics.gems_received_lifetime, 0) + v_single_receiver_gems,
        stars_received_lifetime = coalesce(gift_statistics.stars_received_lifetime, 0) + v_single_receiver_gems,
        highest_gift_value = greatest(coalesce(gift_statistics.highest_gift_value, 0), v_gem_unit_value),
        favorite_sender_id = v_sender_id,
        updated_at = timezone('utc'::text, now());

      insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value, updated_at)
      values (v_receiver_id, 'receiver', 'daily', v_daily_cycle, v_single_receiver_gems, timezone('utc'::text, now()))
      on conflict (user_id, type, cycle, cycle_key) do update set
        value = gift_leaderboards.value + v_single_receiver_gems, updated_at = timezone('utc'::text, now());

      insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value, updated_at)
      values (v_receiver_id, 'receiver', 'weekly', v_weekly_cycle, v_single_receiver_gems, timezone('utc'::text, now()))
      on conflict (user_id, type, cycle, cycle_key) do update set
        value = gift_leaderboards.value + v_single_receiver_gems, updated_at = timezone('utc'::text, now());

      insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value, updated_at)
      values (v_receiver_id, 'receiver', 'monthly', v_monthly_cycle, v_single_receiver_gems, timezone('utc'::text, now()))
      on conflict (user_id, type, cycle, cycle_key) do update set
        value = gift_leaderboards.value + v_single_receiver_gems, updated_at = timezone('utc'::text, now());

      insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value, updated_at)
      values (v_receiver_id, 'receiver', 'lifetime', v_lifetime_cycle, v_single_receiver_gems, timezone('utc'::text, now()))
      on conflict (user_id, type, cycle, cycle_key) do update set
        value = gift_leaderboards.value + v_single_receiver_gems, updated_at = timezone('utc'::text, now());
    end if;

    v_receiver_idx := v_receiver_idx + 1;
  end loop;

  -- 13. Process Dual Progress Gifting Integration
  v_dual_result := public.process_room_dual_progress(
    p_room_id,
    v_sender_id,
    v_total_coins_cost,
    coalesce(v_gift_record.currency, 'gold_gift')
  );

  -- 14. Server-First Lucky Gift Coin Back Engine
  v_is_lucky := coalesce(v_gift_record.is_lucky, false) or coalesce(v_gift_record.is_magic, false);

  if v_is_lucky then
    v_rng_roll := floor(random() * 1000000) + 1;

    if v_rng_roll <= 150000 then v_multiplier := 0;
    elsif v_rng_roll <= 300000 then v_multiplier := 0.1;
    elsif v_rng_roll <= 410000 then v_multiplier := 0.2;
    elsif v_rng_roll <= 500000 then v_multiplier := 0.3;
    elsif v_rng_roll <= 580000 then v_multiplier := 0.4;
    elsif v_rng_roll <= 650000 then v_multiplier := 0.5;
    elsif v_rng_roll <= 730000 then v_multiplier := 0.6;
    elsif v_rng_roll <= 780000 then v_multiplier := 0.7;
    elsif v_rng_roll <= 830000 then v_multiplier := 0.8;
    elsif v_rng_roll <= 980000 then v_multiplier := 1.0;
    elsif v_rng_roll <= 992000 then v_multiplier := 1.5;
    elsif v_rng_roll <= 997000 then v_multiplier := 2.0;
    elsif v_rng_roll <= 999000 then v_multiplier := 3.0;
    elsif v_rng_roll <= 999800 then v_multiplier := 5.0;
    elsif v_rng_roll <= 999950 then v_multiplier := 10.0;
    elsif v_rng_roll <= 999990 then v_multiplier := 20.0;
    elsif v_rng_roll <= 999999 then v_multiplier := 50.0;
    else v_multiplier := 100.0;
    end if;

    v_coins_back := round(v_total_coins_cost * v_multiplier);

    if v_coins_back > 0 then
      if coalesce(v_gift_record.currency, 'gold') = 'silver' then
        update public.wallets
        set silver_coins = coalesce(silver_coins, 0) + v_coins_back,
            updated_at = timezone('utc'::text, now())
        where id = v_sender_id;
      else
        update public.wallets
        set coins_balance = coalesce(coins_balance, 0) + v_coins_back,
            gold_coins = coalesce(gold_coins, 0) + v_coins_back,
            updated_at = timezone('utc'::text, now())
        where id = v_sender_id;
      end if;

      v_remaining_balance := v_remaining_balance + v_coins_back;

      insert into public.wallet_transactions (
        wallet_id, amount, currency, type, status, reference_id, details
      ) values (
        v_sender_id, v_coins_back, coalesce(v_gift_record.currency, 'gold'), 'Reward', 'Completed',
        coalesce(v_tx_id::text, gen_random_uuid()::text),
        'Lucky Gift Coin Return (' || v_multiplier::text || 'x) for ' || coalesce(v_gift_record.name, 'Gift')
      );
    end if;

    insert into public.lucky_reward_logs (
      sender_id, room_id, gift_id, gift_name, cost_coins, quantity, combo_count, total_cost, multiplier, coins_back, currency, created_at
    ) values (
      v_sender_id, p_room_id, p_gift_id, coalesce(v_gift_record.name, 'Lucky Gift'), v_cost_coins, p_quantity, p_combo_count, v_total_coins_cost, v_multiplier, v_coins_back, coalesce(v_gift_record.currency, 'gold'), timezone('utc'::text, now())
    );

    if v_multiplier = 0 then
      v_tier := 'no_reward';
      v_lucky_msg_text := '';
    elsif v_multiplier < 1.0 then
      v_tier := 'partial';
      v_lucky_msg_text := '🎰 ' || v_sender_name || ' received ' || v_coins_back::text || ' Gold back (' || v_multiplier::text || '×).';
    elsif v_multiplier = 1.0 then
      v_tier := 'full';
      v_lucky_msg_text := '🎉 ' || v_sender_name || ' got 100% Lucky Coin Back! (' || v_coins_back::text || ' Gold).';
    elsif v_multiplier < 5.0 then
      v_tier := 'bonus';
      v_lucky_msg_text := '🔥 ' || v_sender_name || ' triggered ' || v_multiplier::text || '× Lucky Coin Back! (' || v_coins_back::text || ' Gold).';
    else
      v_tier := 'jackpot';
      v_lucky_msg_text := '✨ JACKPOT! ' || v_sender_name || ' hit ' || v_multiplier::text || '× Lucky Coin Back! (' || v_coins_back::text || ' Gold) 🎉';
    end if;

    v_lucky_result := jsonb_build_object(
      'is_lucky_gift', true,
      'transaction_id', coalesce(v_tx_id, gen_random_uuid()),
      'sender_name', v_sender_name,
      'gift_name', coalesce(v_gift_record.name, 'Gift'),
      'gift_gold', v_total_coins_cost,
      'multiplier', v_multiplier,
      'cashback_gold', v_coins_back,
      'currency', coalesce(v_gift_record.currency, 'gold'),
      'tier', v_tier,
      'message_text', v_lucky_msg_text
    );
  end if;

  -- 15. Security Anomaly Guard Check
  select greatest(coalesce(coins_balance, 0), coalesce(gold_coins, 0)) into v_final_check_balance
  from public.wallets where id = v_sender_id;

  if coalesce(v_gift_record.currency, 'gold') <> 'silver' and not v_is_lucky then
    if v_final_check_balance > v_sender_balance then
      raise exception 'Security Anomaly: Balance increased during non-lucky gift sending!';
    end if;
  end if;

  -- 16. Format Message & Payload
  v_receivers_names_list := array_to_string(v_receivers_names_array, ', ');
  v_formatted_gift_message := coalesce(v_sender_name, 'Someone') || ' sent ' ||
    p_quantity::text || 'x ' || coalesce(v_gift_record.name, 'Gift') ||
    ' (Combo ' || p_combo_count::text || 'x) to ' || v_receivers_names_list;

  v_event_payload := jsonb_build_object(
    'gift_id', p_gift_id,
    'gift_name', v_gift_record.name,
    'gift_icon', v_gift_icon,
    'sender_id', v_sender_id,
    'sender_name', v_sender_name,
    'sender_avatar', v_sender_avatar,
    'receiver_ids', p_receiver_ids,
    'receivers_names', v_receivers_names_list,
    'quantity', p_quantity,
    'combo_count', p_combo_count,
    'total_coins_cost', v_total_coins_cost,
    'gems_value', v_total_gems,
    'message', v_formatted_gift_message,
    'dual_result', v_dual_result,
    'lucky_result', v_lucky_result,
    'transaction_id', coalesce(v_tx_id, gen_random_uuid())
  );

  return jsonb_build_object(
    'success', true,
    'transaction_id', coalesce(v_tx_id, gen_random_uuid()),
    'sender_id', v_sender_id,
    'total_coins_cost', v_total_coins_cost,
    'total_gems', v_total_gems,
    'remaining_balance', v_remaining_balance,
    'dual_result', v_dual_result,
    'lucky_result', v_lucky_result,
    'event_payload', v_event_payload
  );
end;
$$ language plpgsql security definer;

-- 6. Update get_room_contribution_stats RPC to summarize Gems
create or replace function public.get_room_contribution_stats(p_room_id text)
returns jsonb as $$
declare
  v_total_gems numeric := 0;
  v_total_gifts integer := 0;
  v_today_gems numeric := 0;
  v_today_gifts integer := 0;
  v_total_top_contributors jsonb;
  v_total_top_receivers jsonb;
  v_today_top_contributors jsonb;
  v_today_top_receivers jsonb;
begin
  select coalesce(total_room_gems, total_room_stars, 0), coalesce(total_room_gifts, 0), coalesce(today_room_gems, today_room_stars, 0), coalesce(today_room_gifts, 0)
  into v_total_gems, v_total_gifts, v_today_gems, v_today_gifts
  from public.rooms where id = p_room_id;

  -- Total Top Contributors (Lifetime Givers by Gems)
  select jsonb_agg(d) into v_total_top_contributors from (
    select 
      t.sender_id as user_id, 
      p.display_name as username, 
      p.avatar_url as avatar,
      sum(coalesce(t.gems_value, t.stars_value, 0)) as gems_value,
      sum(coalesce(t.gems_value, t.stars_value, 0)) as stars_value
    from public.gift_transactions t
    join public.profiles p on p.id = t.sender_id
    where t.room_id = p_room_id
    group by t.sender_id, p.display_name, p.avatar_url
    order by gems_value desc
    limit 30
  ) d;

  -- Total Top Receivers (Lifetime Receivers by Gems)
  select jsonb_agg(d) into v_total_top_receivers from (
    select 
      t.receiver_id as user_id, 
      p.display_name as username, 
      p.avatar_url as avatar,
      sum(coalesce(t.gems_value, t.stars_value, 0)) as gems_value,
      sum(coalesce(t.gems_value, t.stars_value, 0)) as stars_value
    from public.gift_transactions t
    join public.profiles p on p.id = t.receiver_id
    where t.room_id = p_room_id
    group by t.receiver_id, p.display_name, p.avatar_url
    order by gems_value desc
    limit 30
  ) d;

  -- Today's Top Contributors (Today Givers by Gems)
  select jsonb_agg(d) into v_today_top_contributors from (
    select 
      t.sender_id as user_id, 
      p.display_name as username, 
      p.avatar_url as avatar,
      sum(coalesce(t.gems_value, t.stars_value, 0)) as gems_value,
      sum(coalesce(t.gems_value, t.stars_value, 0)) as stars_value
    from public.gift_transactions t
    join public.profiles p on p.id = t.sender_id
    where t.room_id = p_room_id and t.created_at >= CURRENT_DATE
    group by t.sender_id, p.display_name, p.avatar_url
    order by gems_value desc
    limit 30
  ) d;

  -- Today's Top Receivers (Today Receivers by Gems)
  select jsonb_agg(d) into v_today_top_receivers from (
    select 
      t.receiver_id as user_id, 
      p.display_name as username, 
      p.avatar_url as avatar,
      sum(coalesce(t.gems_value, t.stars_value, 0)) as gems_value,
      sum(coalesce(t.gems_value, t.stars_value, 0)) as stars_value
    from public.gift_transactions t
    join public.profiles p on p.id = t.receiver_id
    where t.room_id = p_room_id and t.created_at >= CURRENT_DATE
    group by t.receiver_id, p.display_name, p.avatar_url
    order by gems_value desc
    limit 30
  ) d;

  return jsonb_build_object(
    'total_gems', v_total_gems,
    'today_gems', v_today_gems,
    'total_stars', v_total_gems,
    'today_stars', v_today_gems,
    'total_gifts', v_total_gifts,
    'today_gifts', v_today_gifts,
    'total_top_contributors', coalesce(v_total_top_contributors, '[]'::jsonb),
    'total_top_receivers', coalesce(v_total_top_receivers, '[]'::jsonb),
    'today_top_contributors', coalesce(v_today_top_contributors, '[]'::jsonb),
    'today_top_receivers', coalesce(v_today_top_receivers, '[]'::jsonb),
    'top_contributors', coalesce(v_total_top_contributors, '[]'::jsonb),
    'top_receivers', coalesce(v_today_top_receivers, '[]'::jsonb)
  );
end;
$$ language plpgsql security definer;

-- 7. Update get_user_gift_stats_v2 RPC to summarize Gems
create or replace function public.get_user_gift_stats_v2(p_user_id uuid)
returns jsonb as $$
declare
  v_lifetime_received numeric := 0;
  v_lifetime_sent numeric := 0;
  v_monthly_received numeric := 0;
  v_monthly_sent numeric := 0;
  v_monthly_key text := to_char(current_date, 'YYYY-MM');
  v_received_avatars text[] := '{}';
  v_sent_avatars text[] := '{}';
begin
  -- Lifetime received Gems
  select coalesce(sum(coalesce(gems_value, stars_value, 0)), 0) into v_lifetime_received 
  from public.gift_transactions 
  where receiver_id = p_user_id;

  -- Lifetime sent Gems
  select coalesce(sum(coalesce(gems_value, stars_value, 0)), 0) into v_lifetime_sent 
  from public.gift_transactions 
  where sender_id = p_user_id;

  -- Monthly received Gems
  select coalesce(sum(coalesce(gems_value, stars_value, 0)), 0) into v_monthly_received 
  from public.gift_transactions 
  where receiver_id = p_user_id 
    and to_char(created_at, 'YYYY-MM') = v_monthly_key;

  -- Monthly sent Gems
  select coalesce(sum(coalesce(gems_value, stars_value, 0)), 0) into v_monthly_sent 
  from public.gift_transactions 
  where sender_id = p_user_id 
    and to_char(created_at, 'YYYY-MM') = v_monthly_key;

  -- Recent received avatars
  select array_agg(avatar_url) into v_received_avatars
  from (
    select distinct on (t.sender_id) p.avatar_url, max(t.created_at) as max_time
    from public.gift_transactions t
    join public.profiles p on p.id = t.sender_id
    where t.receiver_id = p_user_id and p.avatar_url is not null and p.avatar_url <> ''
    group by t.sender_id, p.avatar_url
    order by t.sender_id, max_time desc
    limit 4
  ) tmp;

  -- Recent sent avatars
  select array_agg(avatar_url) into v_sent_avatars
  from (
    select distinct on (t.receiver_id) p.avatar_url, max(t.created_at) as max_time
    from public.gift_transactions t
    join public.profiles p on p.id = t.receiver_id
    where t.sender_id = p_user_id and p.avatar_url is not null and p.avatar_url <> ''
    group by t.receiver_id, p.avatar_url
    order by t.receiver_id, max_time desc
    limit 4
  ) tmp;

  return jsonb_build_object(
    'lifetime_gems_received', v_lifetime_received,
    'lifetime_gems_sent', v_lifetime_sent,
    'monthly_gems_received', v_monthly_received,
    'monthly_gems_sent', v_monthly_sent,
    'lifetime_received', v_lifetime_received,
    'lifetime_sent', v_lifetime_sent,
    'monthly_received', v_monthly_received,
    'monthly_sent', v_monthly_sent,
    'received_avatars', coalesce(v_received_avatars, array[]::text[]),
    'sent_avatars', coalesce(v_sent_avatars, array[]::text[])
  );
end;
$$ language plpgsql security definer;
