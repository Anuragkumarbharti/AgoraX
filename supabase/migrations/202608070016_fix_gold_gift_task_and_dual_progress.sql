-- Migration: 202608070016_fix_gold_gift_task_and_dual_progress.sql
-- Description: Fix gold coin gift task progression, room dual progress updates, and atomic daily task synchronization.

-- 1. Function to update user daily task progress atomically for all matching tasks
create or replace function public.update_user_daily_tasks_on_gift(
  p_user_id uuid,
  p_amount integer,
  p_currency text
) returns void as $$
declare
  v_today date := ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date;
  v_rec record;
begin
  if p_amount <= 0 then
    return;
  end if;

  if lower(p_currency) = 'gold' then
    -- Loop through all active gold tasks in catalog
    for v_rec in 
      select task_key, target_value from public.room_daily_task_catalog where category = 'gold' or task_key = 'normal_send_1_gold'
    loop
      insert into public.user_daily_task_progress (user_id, task_key, current_value, is_completed, task_date, updated_at)
      values (p_user_id, v_rec.task_key, p_amount, p_amount >= v_rec.target_value, v_today, now())
      on conflict (user_id, task_key, task_date) do update set
        current_value = user_daily_task_progress.current_value + p_amount,
        is_completed = (user_daily_task_progress.current_value + p_amount) >= v_rec.target_value,
        updated_at = now();
    end loop;
  else
    -- Silver tasks catalog update
    for v_rec in 
      select task_key, target_value from public.room_daily_task_catalog where task_key in ('normal_send_1_silver', 'normal_send_5_silver')
    loop
      insert into public.user_daily_task_progress (user_id, task_key, current_value, is_completed, task_date, updated_at)
      values (p_user_id, v_rec.task_key, 1, 1 >= v_rec.target_value, v_today, now())
      on conflict (user_id, task_key, task_date) do update set
        current_value = user_daily_task_progress.current_value + 1,
        is_completed = (user_daily_task_progress.current_value + 1) >= v_rec.target_value,
        updated_at = now();
    end loop;
  end if;
end;
$$ language plpgsql security definer;

-- 2. Update send_star_gift RPC to integrate process_room_dual_progress & update_user_daily_tasks_on_gift
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

  -- 5. Ensure sender wallet exists
  insert into public.wallets (id, coins_balance)
  values (v_sender_id, 40000)
  on conflict (id) do nothing;

  -- 6. Lock and Check Sender Balance
  select coins_balance into v_sender_balance
  from public.wallets
  where id = v_sender_id
  for update;

  if coalesce(v_sender_balance, 0) < v_total_coins_cost then
    raise exception 'Insufficient Gold Coins balance (Requires % coins, you have %)', v_total_coins_cost, coalesce(v_sender_balance, 0);
  end if;

  -- 7. Deduct Coins
  update public.wallets
  set coins_balance = coins_balance - v_total_coins_cost,
      updated_at = now()
  where id = v_sender_id;

  -- 8. Fetch Sender Profile Details
  select username, avatar into v_sender_name, v_sender_avatar
  from public.profiles where id = v_sender_id;
  
  if v_sender_name is null or v_sender_name = '' then
    v_sender_name := 'Creania Student';
  end if;

  -- 9. Update Sender Total Stars Gifted & Statistics & Leaderboards
  update public.profiles
  set total_stars_gifted = coalesce(total_stars_gifted, 0) + v_total_stars_cost::integer,
      updated_at = now()
  where id = v_sender_id;

  insert into public.gift_statistics (user_id, stars_sent_lifetime, highest_gift_value, highest_combo, updated_at)
  values (v_sender_id, v_total_stars_cost, v_cost_stars, p_combo_count, now())
  on conflict (user_id) do update set
    stars_sent_lifetime = coalesce(gift_statistics.stars_sent_lifetime, 0) + v_total_stars_cost,
    highest_gift_value = greatest(coalesce(gift_statistics.highest_gift_value, 0), v_cost_stars),
    highest_combo = greatest(coalesce(gift_statistics.highest_combo, 1), p_combo_count),
    updated_at = now();

  insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value, updated_at)
  values (v_sender_id, 'gifter', 'daily', v_daily_cycle, v_total_stars_cost, now())
  on conflict (user_id, type, cycle, cycle_key) do update set
    value = gift_leaderboards.value + v_total_stars_cost, updated_at = now();

  insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value, updated_at)
  values (v_sender_id, 'gifter', 'weekly', v_weekly_cycle, v_total_stars_cost, now())
  on conflict (user_id, type, cycle, cycle_key) do update set
    value = gift_leaderboards.value + v_total_stars_cost, updated_at = now();

  insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value, updated_at)
  values (v_sender_id, 'gifter', 'monthly', v_monthly_cycle, v_total_stars_cost, now())
  on conflict (user_id, type, cycle, cycle_key) do update set
    value = gift_leaderboards.value + v_total_stars_cost, updated_at = now();

  insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value, updated_at)
  values (v_sender_id, 'gifter', 'lifetime', v_lifetime_cycle, v_total_stars_cost, now())
  on conflict (user_id, type, cycle, cycle_key) do update set
    value = gift_leaderboards.value + v_total_stars_cost, updated_at = now();

  -- 10. Update Room Total Stars & Gifts
  update public.rooms
  set total_room_stars = coalesce(total_room_stars, 0) + v_total_stars_cost,
      today_room_stars = coalesce(today_room_stars, 0) + v_total_stars_cost,
      total_room_gifts = coalesce(total_room_gifts, 0) + (p_quantity * p_combo_count * v_receivers_count),
      today_room_gifts = coalesce(today_room_gifts, 0) + (p_quantity * p_combo_count * v_receivers_count),
      updated_at = now()
  where id = p_room_id;

  -- 11. Process Each Receiver
  for v_receiver_idx in 1..v_receivers_count loop
    v_receiver_id := p_receiver_ids[v_receiver_idx];
    if p_seat_indices is not null and array_length(p_seat_indices, 1) >= v_receiver_idx then
      v_seat_index := p_seat_indices[v_receiver_idx];
    else
      v_seat_index := -1;
    end if;

    v_is_self_gift := (v_sender_id = v_receiver_id);
    if v_is_self_gift and not v_allow_self_gifting then
      raise exception 'Self gifting is currently disabled by system policy.';
    end if;

    select username into v_receiver_name from public.profiles where id = v_receiver_id;
    if v_receiver_name is null or v_receiver_name = '' then
      v_receiver_name := 'User';
    end if;

    v_receivers_names_array := array_append(v_receivers_names_array, v_receiver_name);

    if v_receivers_names_list = '' then
      v_receivers_names_list := v_receiver_name;
    else
      v_receivers_names_list := v_receivers_names_list || ', ' || v_receiver_name;
    end if;

    insert into public.gift_transactions (
      room_id, sender_id, receiver_id, gift_id, gift_name, gift_icon,
      amount, currency, count, quantity, stars_value, combo_count, seat_index, is_self_gift, created_at
    ) values (
      p_room_id, v_sender_id, v_receiver_id, p_gift_id, v_gift_record.name, v_gift_record.icon,
      v_cost_coins, v_gift_record.currency, p_quantity, p_quantity, (v_cost_stars * p_quantity * p_combo_count), p_combo_count, v_seat_index, v_is_self_gift, now()
    ) returning id into v_tx_id;

    insert into public.gift_history (
      sender_id, receiver_id, item_id, item_type, quantity, stars_value, room_id, created_at
    ) values (
      v_sender_id, v_receiver_id, v_gift_record.name, 'VirtualGift', p_quantity * p_combo_count, (v_cost_stars * p_quantity * p_combo_count), p_room_id, now()
    );

    if v_seat_index >= 0 then
      update public.room_seats
      set seat_total_gifts = coalesce(seat_total_gifts, 0) + (p_quantity * p_combo_count),
          seat_total_stars = coalesce(seat_total_stars, 0) + (v_cost_stars * p_quantity * p_combo_count),
          last_gift_time = now()
      where room_id = p_room_id and user_id = v_receiver_id;
    end if;

    if not v_is_self_gift or v_self_gift_payout_ratio > 0 then
      update public.profiles
      set total_stars_received = coalesce(total_stars_received, 0) + (v_cost_stars * p_quantity * p_combo_count * (case when v_is_self_gift then v_self_gift_payout_ratio else 1.0 end))::integer,
          star_balance = coalesce(star_balance, 0) + (v_cost_stars * p_quantity * p_combo_count * (case when v_is_self_gift then v_self_gift_payout_ratio else 1.0 end)),
          total_received_stars = coalesce(total_received_stars, 0) + (v_cost_stars * p_quantity * p_combo_count * (case when v_is_self_gift then v_self_gift_payout_ratio else 1.0 end)),
          updated_at = now()
      where id = v_receiver_id;
    end if;
  end loop;

  -- 12. Process Dual Progress System (Gold Progress + Normal Progress Overflow)
  v_dual_result := public.process_room_dual_progress(
    p_room_id,
    v_sender_id,
    v_total_coins_cost,
    case when lower(v_gift_record.currency) = 'gold' then 'gold_gift' else 'silver_gift' end
  );

  -- 13. Update User Daily Task Progress Catalog (All gold and silver tasks)
  perform public.update_user_daily_tasks_on_gift(v_sender_id, v_total_coins_cost, v_gift_record.currency);

  -- 14. Format Exact Notification Message
  v_formatted_gift_message := v_sender_name || ' ' || v_gift_record.name || ' * ' || (p_quantity * p_combo_count)::text || ' ' || v_receivers_names_list;

  -- 15. Construct Standardized Event Payload with Dual Progress Snapshot
  v_event_payload := jsonb_build_object(
    'giftId', p_gift_id::text,
    'senderId', v_sender_id::text,
    'senderName', v_sender_name,
    'senderAvatar', v_sender_avatar,
    'senderSeat', coalesce(p_seat_indices[1], -1),
    'receiverIds', p_receiver_ids,
    'receiverNames', v_receivers_names_array,
    'receiverSeats', p_seat_indices,
    'roomId', p_room_id,
    'giftType', v_gift_record.currency,
    'giftName', v_gift_record.name,
    'giftIcon', v_gift_record.icon,
    'giftValue', v_cost_stars,
    'quantity', (p_quantity * p_combo_count),
    'timestamp', (extract(epoch from now()) * 1000)::bigint,
    'messageText', v_formatted_gift_message,
    'dualProgress', v_dual_result
  );

  -- 16. Record Chat & Activity Log Entries
  insert into public.room_messages (
    room_id, sender_id, content, message_type, metadata
  ) values (
    p_room_id, v_sender_id,
    v_formatted_gift_message,
    'gift',
    v_event_payload
  );

  insert into public.room_activity_events (
    room_id, event_type, user_id, username, message, metadata
  ) values (
    p_room_id, 'gift_sent', v_sender_id, v_sender_name,
    v_formatted_gift_message,
    v_event_payload
  );

  -- 17. Get final sender remaining balance
  select coins_balance into v_sender_balance from public.wallets where id = v_sender_id;

  -- 18. Return Success Result
  return jsonb_build_object(
    'success', true,
    'remaining_balance', v_sender_balance,
    'event_payload', v_event_payload,
    'dual_result', v_dual_result,
    'vp_result', v_dual_result
  );
end;
$$ language plpgsql security definer;
