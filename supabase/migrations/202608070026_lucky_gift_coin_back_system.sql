-- Migration: 202608070026_lucky_gift_coin_back_system.sql
-- Description: Backend-driven Lucky Gift Coin Back engine with exact 1-in-1,000,000 probability distribution table and room event broadcasting.

-- 1. Ensure gift_catalog has is_lucky column
alter table public.gift_catalog add column if not exists is_lucky boolean default false;
alter table public.gift_catalog add column if not exists is_magic boolean default false;

-- 2. Update existing gift_catalog entries to set is_lucky = true for lucky gifts
update public.gift_catalog
set is_lucky = true
where name in ('Flower', 'Rose', 'Cake', 'Gift Box', 'Diamond', 'Sports Car', 'Private Jet')
   or is_magic = true;

-- 3. Create Lucky Reward Logs Table for auditability
create table if not exists public.lucky_reward_logs (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete set null,
  room_id text,
  gift_id uuid references public.gift_catalog(id) on delete set null,
  gift_name text,
  cost_coins integer,
  quantity integer default 1,
  combo_count integer default 1,
  total_cost integer,
  multiplier numeric,
  coins_back integer,
  currency text default 'gold',
  created_at timestamptz default now()
);

-- Enable RLS
alter table public.lucky_reward_logs enable row level security;

-- Setup RLS Policies
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'lucky_reward_logs' and policyname = 'Allow read access to lucky_reward_logs') then
    create policy "Allow read access to lucky_reward_logs" on public.lucky_reward_logs for select to authenticated using (true);
  end if;
end $$;

-- 4. Create/Replace send_star_gift PostgreSQL function with Backend-Driven Lucky Coin Back calculation
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
  v_sender_balance integer;
  v_gift_record record;
  v_gift_icon text := '';
  v_receivers_count integer;
  v_cost_stars numeric;
  v_cost_coins integer;
  v_total_coins_cost integer;
  v_total_stars_cost numeric;
  v_receiver_id uuid;
  v_receiver_name text;
  v_receiver_idx integer := 1;
  v_seat_index integer := -1;
  v_tx_id uuid;
  v_dual_result jsonb;

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
  v_lucky_result jsonb := null;
  v_lucky_msg_text text := '';
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

  -- 4. Calculate Costs
  v_cost_stars := coalesce(v_gift_record.cost_stars, 10);
  v_cost_coins := v_cost_stars::integer;
  v_total_coins_cost := v_cost_coins * p_quantity * p_combo_count * v_receivers_count;
  v_total_stars_cost := v_cost_stars * p_quantity * p_combo_count * v_receivers_count;

  -- 5. Ensure sender wallet exists
  insert into public.wallets (id, coins_balance, gold_coins, silver_coins)
  values (v_sender_id, 1000000, 1000000, 1000000)
  on conflict (id) do nothing;

  -- 6. Lock and Check Sender Balance
  select greatest(coalesce(coins_balance, 0), coalesce(gold_coins, 0)) into v_sender_balance
  from public.wallets
  where id = v_sender_id
  for update;

  -- Auto top-up wallet if balance is lower than total cost
  if coalesce(v_sender_balance, 0) < v_total_coins_cost then
    update public.wallets
    set coins_balance = coalesce(coins_balance, 0) + v_total_coins_cost + 1000000,
        gold_coins = coalesce(gold_coins, 0) + v_total_coins_cost + 1000000
    where id = v_sender_id;

    v_sender_balance := v_sender_balance + v_total_coins_cost + 1000000;
  end if;

  -- 7. Deduct Coins First
  update public.wallets
  set coins_balance = greatest(0, coins_balance - v_total_coins_cost),
      gold_coins = greatest(0, gold_coins - v_total_coins_cost),
      updated_at = timezone('utc'::text, now())
  where id = v_sender_id;

  v_remaining_balance := greatest(0, v_sender_balance - v_total_coins_cost);

  -- 8. Fetch Sender Details
  select display_name, avatar_url into v_sender_name, v_sender_avatar
  from public.profiles where id = v_sender_id;

  -- 9. Process Receivers & Insert into public.gift_transactions & public.gift_history
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

    -- Insert into public.gift_transactions
    insert into public.gift_transactions (
      room_id, sender_id, receiver_id, gift_id, gift_name, gift_icon,
      amount, currency, count, quantity, stars_value, combo_count, seat_index, is_self_gift, created_at
    ) values (
      p_room_id, v_sender_id, v_receiver_id, p_gift_id, coalesce(v_gift_record.name, 'Gift'), v_gift_icon,
      v_cost_coins, coalesce(v_gift_record.currency, 'gold'), p_quantity, p_quantity, (v_cost_stars * p_quantity * p_combo_count), p_combo_count, v_seat_index, v_is_self_gift, timezone('utc'::text, now())
    ) returning id into v_tx_id;

    -- Insert into public.gift_history
    insert into public.gift_history (
      sender_id, receiver_id, item_id, item_type, quantity, stars_value, room_id, created_at
    ) values (
      v_sender_id, v_receiver_id, coalesce(v_gift_record.name, 'Gift'), 'VirtualGift', p_quantity * p_combo_count, (v_cost_stars * p_quantity * p_combo_count), p_room_id, timezone('utc'::text, now())
    );

    v_receiver_idx := v_receiver_idx + 1;
  end loop;

  -- 10. Process Dual Progress Gifting Integration
  v_dual_result := public.process_room_dual_progress(
    p_room_id,
    v_sender_id,
    v_total_coins_cost,
    coalesce(v_gift_record.currency, 'gold_gift')
  );

  -- 11. Backend-Driven Lucky Gift Coin Back Engine
  -- Check if gift is tagged as lucky or magic
  v_is_lucky := coalesce(v_gift_record.is_lucky, false) or coalesce(v_gift_record.is_magic, false);

  if v_is_lucky then
    -- Uniform RNG roll between 1 and 1,000,000
    v_rng_roll := floor(random() * 1000000) + 1;

    -- Cumulative Probability Lookup Table:
    -- 0x     (35.0%)    : 1 to 350,000
    -- 0.1x   (18.0%)    : 350,001 to 530,000
    -- 0.2x   (12.0%)    : 530,001 to 650,000
    -- 0.3x   (8.0%)     : 650,001 to 730,000
    -- 0.4x   (6.0%)     : 730,001 to 790,000
    -- 0.5x   (5.0%)     : 790,001 to 840,000
    -- 0.6x   (4.0%)     : 840,001 to 880,000
    -- 0.7x   (3.0%)     : 880,001 to 910,000
    -- 0.8x   (3.0%)     : 910,001 to 940,000
    -- 1.0x   (4.0%)     : 940,001 to 980,000
    -- 1.5x   (1.2%)     : 980,001 to 992,000
    -- 2.0x   (0.5%)     : 992,001 to 997,000
    -- 3.0x   (0.2%)     : 997,001 to 999,000
    -- 5.0x   (0.08%)    : 999,001 to 999,800
    -- 10.0x  (0.015%)   : 999,801 to 999,950
    -- 20.0x  (0.004%)   : 999,951 to 999,990
    -- 50.0x  (0.001%)   : 999,991 to 999,999
    -- 100.0x (0.0001%)  : 1,000,000
    if v_rng_roll <= 350000 then
      v_multiplier := 0;
    elsif v_rng_roll <= 530000 then
      v_multiplier := 0.1;
    elsif v_rng_roll <= 650000 then
      v_multiplier := 0.2;
    elsif v_rng_roll <= 730000 then
      v_multiplier := 0.3;
    elsif v_rng_roll <= 790000 then
      v_multiplier := 0.4;
    elsif v_rng_roll <= 840000 then
      v_multiplier := 0.5;
    elsif v_rng_roll <= 880000 then
      v_multiplier := 0.6;
    elsif v_rng_roll <= 910000 then
      v_multiplier := 0.7;
    elsif v_rng_roll <= 940000 then
      v_multiplier := 0.8;
    elsif v_rng_roll <= 980000 then
      v_multiplier := 1.0;
    elsif v_rng_roll <= 992000 then
      v_multiplier := 1.5;
    elsif v_rng_roll <= 997000 then
      v_multiplier := 2.0;
    elsif v_rng_roll <= 999000 then
      v_multiplier := 3.0;
    elsif v_rng_roll <= 999800 then
      v_multiplier := 5.0;
    elsif v_rng_roll <= 999950 then
      v_multiplier := 10.0;
    elsif v_rng_roll <= 999990 then
      v_multiplier := 20.0;
    elsif v_rng_roll <= 999999 then
      v_multiplier := 50.0;
    else
      v_multiplier := 100.0;
    end if;

    -- Calculate Coin Back Amount
    v_coins_back := round(v_total_coins_cost * v_multiplier);

    -- Credit coin back to sender wallet if > 0
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
    end if;

    -- Audit Log
    insert into public.lucky_reward_logs (
      sender_id, room_id, gift_id, gift_name, cost_coins, quantity, combo_count, total_cost, multiplier, coins_back, currency, created_at
    ) values (
      v_sender_id, p_room_id, p_gift_id, coalesce(v_gift_record.name, 'Lucky Gift'), v_cost_coins, p_quantity, p_combo_count, v_total_coins_cost, v_multiplier, v_coins_back, coalesce(v_gift_record.currency, 'gold'), timezone('utc'::text, now())
    );

    if v_coins_back > 0 then
      v_lucky_msg_text := '🎰 Lucky Gift Draw! ' || coalesce(v_sender_name, 'User') || ' sent ' || coalesce(v_gift_record.name, 'Gift') || ' and won ' || v_coins_back::text || ' Gold Coins Back (' || v_multiplier::text || 'x Multiplier)! 🎉';
    else
      v_lucky_msg_text := '🎰 Lucky Gift Draw! ' || coalesce(v_sender_name, 'User') || ' sent ' || coalesce(v_gift_record.name, 'Gift') || ' (0x Multiplier).';
    end if;

    v_lucky_result := jsonb_build_object(
      'is_lucky_gift', true,
      'multiplier', v_multiplier,
      'coins_back', v_coins_back,
      'total_coins_cost', v_total_coins_cost,
      'currency', coalesce(v_gift_record.currency, 'gold'),
      'message_text', v_lucky_msg_text
    );
  end if;

  -- 12. Format Message & Payload
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
    'message', v_formatted_gift_message,
    'dual_result', v_dual_result,
    'lucky_result', v_lucky_result
  );

  return jsonb_build_object(
    'success', true,
    'transaction_id', v_tx_id,
    'sender_id', v_sender_id,
    'total_coins_cost', v_total_coins_cost,
    'remaining_balance', v_remaining_balance,
    'dual_result', v_dual_result,
    'lucky_result', v_lucky_result,
    'event_payload', v_event_payload
  );
end;
$$ language plpgsql security definer;
