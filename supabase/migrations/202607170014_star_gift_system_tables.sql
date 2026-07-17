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


-- 16. CENTRALIZED STORED PROCEDURE FOR STAR GIFT SENDING
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
  
  -- Leaderboard cycle keys
  v_daily_cycle text := to_char(current_date, 'YYYY-MM-DD');
  v_weekly_cycle text := to_char(current_date, 'YYYY-') || 'W' || to_char(current_date, 'IW');
  v_monthly_cycle text := to_char(current_date, 'YYYY-MM');
  v_lifetime_cycle text := 'lifetime';
  
  v_receivers_names_list text := '';
begin
  -- 1. Authentication Check
  if v_sender_id is null then
    raise exception 'Not authenticated';
  end if;

  -- 2. Validation Checks
  v_receivers_count := array_length(p_receiver_ids, 1);
  if v_receivers_count is null or v_receivers_count = 0 then
    raise exception 'Recipient list cannot be empty.';
  end if;

  select * into v_gift_record from public.gift_catalog where id = p_gift_id and is_active = true;
  if v_gift_record.id is null then
    raise exception 'Selected gift is inactive or does not exist.';
  end if;

  -- 3. Calculate Cost
  v_cost_stars := v_gift_record.cost_stars;
  if v_gift_record.currency = 'gold' then
    v_cost_coins := v_cost_stars::integer; -- 1 Star = 1 Gold
  else
    v_cost_coins := (v_cost_stars * 100)::integer; -- 1 Star = 100 Silver
  end if;

  v_total_coins_cost := v_cost_coins * p_quantity * v_receivers_count;
  v_total_stars_cost := v_cost_stars * p_quantity * v_receivers_count;

  -- Verify sender balance
  select username into v_sender_name from public.profiles where id = v_sender_id;
  if v_gift_record.currency = 'gold' then
    select coins_balance into v_sender_balance from public.wallets where id = v_sender_id;
    if coalesce(v_sender_balance, 0) < v_total_coins_cost then
      raise exception 'Insufficient Gold Coins (Requires % coins)', v_total_coins_cost;
    end if;
    -- Deduct sender balance
    update public.wallets set coins_balance = coins_balance - v_total_coins_cost where id = v_sender_id;
  else
    select silver_coins_balance into v_sender_balance from public.wallets where id = v_sender_id;
    if coalesce(v_sender_balance, 0) < v_total_coins_cost then
      raise exception 'Insufficient Silver Coins (Requires % coins)', v_total_coins_cost;
    end if;
    -- Deduct sender balance
    update public.wallets set silver_coins_balance = silver_coins_balance - v_total_coins_cost where id = v_sender_id;
  end if;

  -- Log sender wallet audit
  insert into public.gift_wallet_logs (user_id, amount, currency, direction, reason)
  values (v_sender_id, v_total_coins_cost, v_gift_record.currency, 'Debit', 'Sent ' || v_gift_record.name || ' gift in room ' || p_room_id);

  -- 4. Process each receiver
  for v_receiver_idx in 1..v_receivers_count loop
    v_receiver_id := p_receiver_ids[v_receiver_idx];
    
    select username into v_receiver_name from public.profiles where id = v_receiver_id;
    if v_receiver_name is null then
      v_receiver_name := 'Receiver';
    end if;

    -- Build receivers names text for chat box
    if v_receiver_idx = 1 then
      v_receivers_names_list := v_receiver_name;
    elsif v_receiver_idx = v_receivers_count then
      v_receivers_names_list := v_receivers_names_list || ' and ' || v_receiver_name;
    else
      v_receivers_names_list := v_receivers_names_list || ', ' || v_receiver_name;
    end if;

    -- Add coins to receiver wallet (standard gifting coin transfer)
    if v_sender_id <> v_receiver_id then
      if v_gift_record.currency = 'gold' then
        update public.wallets set coins_balance = coins_balance + (v_cost_coins * p_quantity) where id = v_receiver_id;
      else
        update public.wallets set silver_coins_balance = silver_coins_balance + (v_cost_coins * p_quantity) where id = v_receiver_id;
      end if;
      
      insert into public.gift_wallet_logs (user_id, amount, currency, direction, reason)
      values (v_receiver_id, v_cost_coins * p_quantity, v_gift_record.currency, 'Credit', 'Received ' || v_gift_record.name || ' gift in room ' || p_room_id);
    end if;

    -- Insert Transaction Ledger
    insert into public.gift_transactions (sender_id, receiver_id, room_id, gift_id, stars_value, quantity, combo_count)
    values (v_sender_id, v_receiver_id, p_room_id, p_gift_id, v_cost_stars * p_quantity, p_quantity, p_combo_count)
    returning id into v_tx_id;

    -- Insert Seat logs if applicable
    if p_seat_indices is not null and array_length(p_seat_indices, 1) >= v_receiver_idx then
      v_seat_index := p_seat_indices[v_receiver_idx];
      insert into public.gift_seat_logs (transaction_id, seat_index, receiver_id)
      values (v_tx_id, v_seat_index, v_receiver_id);
      
      -- Update room seats statistics
      update public.room_seats
      set seat_total_gifts = seat_total_gifts + p_quantity,
          seat_total_stars = seat_total_stars + (v_cost_stars * p_quantity),
          last_gift_time = now()
      where room_id = p_room_id and user_id = v_receiver_id;
    end if;

    -- Log transaction audit
    insert into public.gift_history (sender_id, receiver_id, item_id, item_type, quantity, stars_value, room_id)
    values (v_sender_id, v_receiver_id, v_gift_record.name, 'VirtualGift', p_quantity, v_cost_stars * p_quantity, p_room_id);

    -- Update Receiver statistics
    insert into public.gift_statistics (user_id, stars_received_lifetime, highest_gift_value, favorite_sender_id)
    values (v_receiver_id, v_cost_stars * p_quantity, v_cost_stars * p_quantity, v_sender_id)
    on conflict (user_id) do update set
      stars_received_lifetime = gift_statistics.stars_received_lifetime + (v_cost_stars * p_quantity),
      highest_gift_value = greatest(gift_statistics.highest_gift_value, v_cost_stars * p_quantity),
      favorite_sender_id = EXCLUDED.favorite_sender_id,
      updated_at = now();

    -- Update Gifter/Receiver Leaderboards
    -- Receiver Leaderboards (Daily, Weekly, Monthly, Lifetime)
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

    -- Add receiver notifications
    insert into public.gift_notifications (user_id, title, content)
    values (v_receiver_id, 'Received Gift! 🎁', v_sender_name || ' sent you ' || p_quantity || 'x ' || v_gift_record.name || ' (' || (v_cost_stars * p_quantity) || '★)');
  end loop;

  -- Update Sender statistics
  insert into public.gift_statistics (user_id, stars_sent_lifetime, highest_combo, favorite_gift_id)
  values (v_sender_id, v_total_stars_cost, p_combo_count, p_gift_id)
  on conflict (user_id) do update set
    stars_sent_lifetime = gift_statistics.stars_sent_lifetime + v_total_stars_cost,
    highest_combo = greatest(gift_statistics.highest_combo, p_combo_count),
    favorite_gift_id = EXCLUDED.favorite_gift_id,
    updated_at = now();

  -- Update Gifter Leaderboards (Daily, Weekly, Monthly, Lifetime)
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

  -- Update room-wide statistics
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
    elsif v_receivers_count = 10 then -- Assume gift all seats/everyone
      v_message_content := v_sender_name || ' gifted everyone with ' || v_gift_record.icon || ' ' || v_gift_record.name;
    else
      v_message_content := v_sender_name || ' sent ' || v_gift_record.icon || ' ' || v_gift_record.name || ' to ' || v_receivers_count || ' selected users';
    end if;

    -- Record Room messages chat log entry
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

  -- Trigger progression event (gifting task completion) once for the gifting activity
  begin
    perform public.process_xp_event('gift_sent', jsonb_build_object('recipient_id', p_receiver_ids[1], 'gift_id', p_gift_id::text));
  exception when others then
    null;
  end;

  -- Return sender remaining balance representation
  return jsonb_build_object(
    'success', true,
    'remaining_balance', v_sender_balance - v_total_coins_cost,
    'total_stars_cost', v_total_stars_cost
  );
end;
$$ language plpgsql security definer;
