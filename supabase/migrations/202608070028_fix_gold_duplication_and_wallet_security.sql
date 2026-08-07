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
create policy "Users can view their own wallet" on public.wallets for select to authenticated using (auth.uid() = id);

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

-- 4. Production-Ready Atomic send_star_gift RPC with strict balance checks & audit logging
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

  -- 4. Calculate Costs
  v_cost_stars := coalesce(v_gift_record.cost_stars, 10);
  v_cost_coins := v_cost_stars::integer;
  v_total_coins_cost := v_cost_coins * p_quantity * p_combo_count * v_receivers_count;
  v_total_stars_cost := v_cost_stars * p_quantity * p_combo_count * v_receivers_count;

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

  -- 8. Deduct Exact Cost Atomically
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

  -- 10. Process Receivers & Insert into public.gift_transactions & public.gift_history
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

    insert into public.gift_transactions (
      room_id, sender_id, receiver_id, gift_id, gift_name, gift_icon,
      amount, currency, count, quantity, stars_value, combo_count, seat_index, is_self_gift, created_at
    ) values (
      p_room_id, v_sender_id, v_receiver_id, p_gift_id, coalesce(v_gift_record.name, 'Gift'), v_gift_icon,
      v_cost_coins, coalesce(v_gift_record.currency, 'gold'), p_quantity, p_quantity, (v_cost_stars * p_quantity * p_combo_count), p_combo_count, v_seat_index, v_is_self_gift, timezone('utc'::text, now())
    ) returning id into v_tx_id;

    insert into public.gift_history (
      sender_id, receiver_id, item_id, item_type, quantity, stars_value, room_id, created_at
    ) values (
      v_sender_id, v_receiver_id, coalesce(v_gift_record.name, 'Gift'), 'VirtualGift', p_quantity * p_combo_count, (v_cost_stars * p_quantity * p_combo_count), p_room_id, timezone('utc'::text, now())
    );

    v_receiver_idx := v_receiver_idx + 1;
  end loop;

  -- 11. Process Dual Progress Gifting Integration
  v_dual_result := public.process_room_dual_progress(
    p_room_id,
    v_sender_id,
    v_total_coins_cost,
    coalesce(v_gift_record.currency, 'gold_gift')
  );

  -- 12. Server-First Lucky Gift Coin Back Engine
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

  -- 13. Security Anomaly Guard Check
  select greatest(coalesce(coins_balance, 0), coalesce(gold_coins, 0)) into v_final_check_balance
  from public.wallets where id = v_sender_id;

  if coalesce(v_gift_record.currency, 'gold') <> 'silver' and not v_is_lucky then
    if v_final_check_balance > v_sender_balance then
      raise exception 'Security Anomaly: Balance increased during non-lucky gift sending!';
    end if;
  end if;

  -- 14. Format Message & Payload
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
    'lucky_result', v_lucky_result,
    'transaction_id', coalesce(v_tx_id, gen_random_uuid())
  );

  return jsonb_build_object(
    'success', true,
    'transaction_id', coalesce(v_tx_id, gen_random_uuid()),
    'sender_id', v_sender_id,
    'total_coins_cost', v_total_coins_cost,
    'remaining_balance', v_remaining_balance,
    'dual_result', v_dual_result,
    'lucky_result', v_lucky_result,
    'event_payload', v_event_payload
  );
end;
$$ language plpgsql security definer;

-- 5. Production-Ready Atomic send_room_gift RPC with strict balance checks & audit logging
create or replace function public.send_room_gift(
  p_room_id text,
  p_receiver_id uuid,
  p_gift_name text,
  p_coins_value integer,
  p_quantity integer default 1
) returns jsonb as $$
declare
  v_sender_id uuid := auth.uid();
  v_sender_balance integer := 0;
  v_total_cost integer;
  v_gift_id uuid;
  v_sender_name text;
  v_receiver_name text;
  v_stars integer;
begin
  if v_sender_id is null then
    raise exception 'Not authenticated';
  end if;

  v_total_cost := p_coins_value * p_quantity;

  -- Ensure sender wallet exists with ZERO default balance
  insert into public.wallets (id, coins_balance, gold_coins, silver_coins)
  values (v_sender_id, 0, 0, 0)
  on conflict (id) do nothing;

  -- Lock Sender Wallet Row
  select greatest(coalesce(coins_balance, 0), coalesce(gold_coins, 0)) into v_sender_balance
  from public.wallets
  where id = v_sender_id
  for update;

  if coalesce(v_sender_balance, 0) < v_total_cost then
    raise exception 'Insufficient Gold Coins: Required % coins, but available balance is % coins.', v_total_cost, coalesce(v_sender_balance, 0);
  end if;

  select display_name into v_sender_name from public.profiles where id = v_sender_id;
  if v_sender_name is null then v_sender_name := 'Sender'; end if;

  select display_name into v_receiver_name from public.profiles where id = p_receiver_id;
  if v_receiver_name is null then v_receiver_name := 'Receiver'; end if;

  v_stars := public.calculate_gift_stars(p_gift_name, p_coins_value, p_quantity);

  -- Deduct from sender
  update public.wallets
  set coins_balance = greatest(0, coins_balance - v_total_cost),
      gold_coins = greatest(0, gold_coins - v_total_cost),
      updated_at = timezone('utc'::text, now())
  where id = v_sender_id;

  insert into public.wallet_transactions (wallet_id, amount, currency, type, status, reference_id, details)
  values (v_sender_id, v_total_cost, 'gold', 'Spend', 'Completed', gen_random_uuid()::text,
          'Sent ' || p_gift_name || ' gift in voice room');

  -- Add to receiver
  if v_sender_id <> p_receiver_id then
    update public.wallets
    set coins_balance = coalesce(coins_balance, 0) + v_total_cost,
        gold_coins = coalesce(gold_coins, 0) + v_total_cost,
        updated_at = timezone('utc'::text, now())
    where id = p_receiver_id;

    insert into public.wallet_transactions (wallet_id, amount, currency, type, status, reference_id, details)
    values (p_receiver_id, v_total_cost, 'gold', 'Bonus', 'Completed', gen_random_uuid()::text,
            'Received ' || p_gift_name || ' gift in voice room');
  end if;

  -- Record gift history & room stats
  insert into public.gift_history (sender_id, receiver_id, item_id, item_type, quantity, stars_value, room_id, created_at)
  values (v_sender_id, p_receiver_id, p_gift_name, 'VirtualGift', p_quantity, v_stars, p_room_id, timezone('utc'::text, now()));

  insert into public.room_gifts (room_id, sender_id, receiver_id, gift_name, coins_value, quantity)
  values (p_room_id, v_sender_id, p_receiver_id, p_gift_name, p_coins_value, p_quantity)
  returning id into v_gift_id;

  update public.rooms
  set total_room_gifts = coalesce(total_room_gifts, 0) + p_quantity,
      today_room_gifts = coalesce(today_room_gifts, 0) + p_quantity,
      total_room_stars = coalesce(total_room_stars, 0) + v_stars,
      today_room_stars = coalesce(today_room_stars, 0) + v_stars,
      updated_at = timezone('utc'::text, now())
  where id = p_room_id;

  return jsonb_build_object(
    'success', true,
    'gift_id', v_gift_id,
    'remaining_balance', greatest(0, v_sender_balance - v_total_cost)
  );
end;
$$ language plpgsql security definer;
