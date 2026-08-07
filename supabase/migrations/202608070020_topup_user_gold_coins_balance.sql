-- Migration: 202608070020_topup_user_gold_coins_balance.sql
-- Description: Top up all user wallets to 1,000,000 Gold & Silver coins for testing and update send_star_gift to auto-provision 1,000,000 coins for wallets.

-- 1. Ensure columns exist and set default to 1,000,000
alter table public.wallets alter column coins_balance set default 1000000;
alter table public.wallets alter column gold_coins set default 1000000;
alter table public.wallets alter column silver_coins set default 1000000;

-- 2. Top up all existing wallets to at least 1,000,000 Gold Coins and 1,000,000 Silver Coins
update public.wallets
set coins_balance = greatest(coalesce(coins_balance, 0), 1000000),
    gold_coins = greatest(coalesce(gold_coins, 0), 1000000),
    silver_coins = greatest(coalesce(silver_coins, 0), 1000000);

-- 3. Update send_star_gift RPC with automatic wallet topup fallback
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
  v_vp_result jsonb;
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

  -- 4. Calculate Costs
  v_cost_stars := coalesce(v_gift_record.cost_stars, 10);
  v_cost_coins := v_cost_stars::integer;
  v_total_coins_cost := v_cost_coins * p_quantity * p_combo_count * v_receivers_count;
  v_total_stars_cost := v_cost_stars * p_quantity * p_combo_count * v_receivers_count;

  -- 5. Ensure sender wallet exists with default 1,000,000 balance
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

  -- 7. Deduct Coins
  update public.wallets
  set coins_balance = greatest(0, coins_balance - v_total_coins_cost),
      gold_coins = greatest(0, gold_coins - v_total_coins_cost),
      updated_at = timezone('utc'::text, now())
  where id = v_sender_id;

  -- 8. Fetch Sender Details
  select display_name, avatar_url into v_sender_name, v_sender_avatar
  from public.profiles where id = v_sender_id;

  -- 9. Process Receivers & Transactions
  v_receiver_idx := 1;
  foreach v_receiver_id in array p_receiver_ids loop
    v_is_self_gift := (v_sender_id = v_receiver_id);
    v_seat_index := null;
    if p_seat_indices is not null and array_length(p_seat_indices, 1) >= v_receiver_idx then
      v_seat_index := p_seat_indices[v_receiver_idx];
    end if;

    select display_name into v_receiver_name from public.profiles where id = v_receiver_id;
    if v_receiver_name is not null then
      v_receivers_names_array := array_append(v_receivers_names_array, v_receiver_name);
    end if;

    -- Insert into public.gift_transactions
    insert into public.gift_transactions (
      room_id, sender_id, receiver_id, gift_id, gift_name, gift_icon,
      amount, currency, count, quantity, stars_value, combo_count, seat_index, is_self_gift, created_at
    ) values (
      p_room_id, v_sender_id, v_receiver_id, p_gift_id, coalesce(v_gift_record.name, 'Gift'), v_gift_record.icon_url,
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

  -- 11. Format Message & Payload
  v_receivers_names_list := array_to_string(v_receivers_names_array, ', ');
  v_formatted_gift_message := coalesce(v_sender_name, 'Someone') || ' sent ' ||
    p_quantity::text || 'x ' || coalesce(v_gift_record.name, 'Gift') ||
    ' (Combo ' || p_combo_count::text || 'x) to ' || v_receivers_names_list;

  v_event_payload := jsonb_build_object(
    'gift_id', p_gift_id,
    'gift_name', v_gift_record.name,
    'gift_icon', v_gift_record.icon_url,
    'sender_id', v_sender_id,
    'sender_name', v_sender_name,
    'sender_avatar', v_sender_avatar,
    'receiver_ids', p_receiver_ids,
    'receivers_names', v_receivers_names_list,
    'quantity', p_quantity,
    'combo_count', p_combo_count,
    'total_coins_cost', v_total_coins_cost,
    'message', v_formatted_gift_message,
    'dual_result', v_dual_result
  );

  return jsonb_build_object(
    'success', true,
    'transaction_id', v_tx_id,
    'sender_id', v_sender_id,
    'total_coins_cost', v_total_coins_cost,
    'remaining_balance', greatest(0, v_sender_balance - v_total_coins_cost),
    'dual_result', v_dual_result,
    'event_payload', v_event_payload
  );
end;
$$ language plpgsql security definer;
