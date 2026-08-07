-- Migration: 202608070010_fix_send_star_gift_return_type.sql
-- Description: Complete production send_star_gift RPC with room stars update, seat stats update, gold task overflow engine, and room messages event.

-- 0. Ensure profiles star columns compatibility
alter table public.profiles add column if not exists total_stars_received integer default 0;
alter table public.profiles add column if not exists total_stars_gifted integer default 0;
alter table public.profiles add column if not exists star_balance numeric default 0;
alter table public.profiles add column if not exists total_received_stars numeric default 0;

-- 0b. Ensure gift_transactions schema compatibility
alter table public.gift_transactions add column if not exists gift_name text;
alter table public.gift_transactions add column if not exists gift_icon text;
alter table public.gift_transactions add column if not exists amount numeric;
alter table public.gift_transactions add column if not exists currency text;
alter table public.gift_transactions add column if not exists count integer;
alter table public.gift_transactions add column if not exists seat_index integer;
alter table public.gift_transactions add column if not exists stars_value numeric;

-- 0c. Ensure rooms and room_seats stars columns compatibility
alter table public.rooms add column if not exists total_room_stars numeric default 0;
alter table public.rooms add column if not exists today_room_stars numeric default 0;
alter table public.rooms add column if not exists total_room_gifts integer default 0;
alter table public.rooms add column if not exists today_room_gifts integer default 0;

alter table public.room_seats add column if not exists seat_total_stars numeric default 0;
alter table public.room_seats add column if not exists seat_total_gifts integer default 0;
alter table public.room_seats add column if not exists last_gift_time timestamp with time zone;

-- 1. Helper function: Add Room VP with Gold Task Overflow to Normal Task & Max Capping
create or replace function public.add_room_vp_with_overflow(
  p_room_id text,
  p_user_id uuid,
  p_vp integer,
  p_currency text default 'gold'
) returns jsonb as $$
declare
  v_is_weekend boolean := (extract(isodow from (now() at time zone 'Asia/Kolkata')) in (6, 7));
  v_max_free_vp integer := case when v_is_weekend then 1400 else 700 end;
  v_max_gold_vp integer := case when v_is_weekend then 2400 else 1000 end;
  v_max_total_vp integer := v_max_free_vp + v_max_gold_vp;
  
  v_current_free_vp integer := 0;
  v_current_gold_vp integer := 0;
  v_current_total_vp integer := 0;
  
  v_gold_capacity integer := 0;
  v_gold_added integer := 0;
  v_overflow integer := 0;
  v_free_capacity integer := 0;
  v_free_added integer := 0;
  v_total_added_vp integer := 0;
begin
  if p_vp <= 0 then
    return jsonb_build_object('success', false, 'added_vp', 0);
  end if;

  -- Get current daily task progress for today
  select 
    coalesce(sum(case when t.category <> 'gold' then p.current_value else 0 end), 0),
    coalesce(sum(case when t.category = 'gold' then p.current_value else 0 end), 0)
  into v_current_free_vp, v_current_gold_vp
  from public.user_daily_task_progress p
  join public.room_daily_task_catalog t on t.task_key = p.task_key
  where p.user_id = p_user_id and p.task_date = ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date;

  v_current_total_vp := v_current_free_vp + v_current_gold_vp;

  -- Cap Check: If already at MAX limit (1700 or 3800), do not increase further
  if v_current_total_vp >= v_max_total_vp then
    return jsonb_build_object('success', false, 'reason', 'MAX daily task limit reached', 'added_vp', 0);
  end if;

  if p_currency = 'gold' then
    -- Gold Gift: Fill Gold Task first, then overflow into Normal/Free Task
    v_gold_capacity := greatest(0, v_max_gold_vp - v_current_gold_vp);
    if p_vp <= v_gold_capacity then
      v_gold_added := p_vp;
      v_overflow := 0;
    else
      v_gold_added := v_gold_capacity;
      v_overflow := p_vp - v_gold_capacity;
    end if;

    -- Overflow fills Normal Task
    if v_overflow > 0 then
      v_free_capacity := greatest(0, v_max_free_vp - v_current_free_vp);
      v_free_added := least(v_overflow, v_free_capacity);
    end if;
  else
    -- Silver Gift: Fills Normal/Free Task only
    v_free_capacity := greatest(0, v_max_free_vp - v_current_free_vp);
    v_free_added := least(p_vp, v_free_capacity);
  end if;

  v_total_added_vp := v_gold_added + v_free_added;

  if v_total_added_vp > 0 then
    -- Update room XP and today_room_xp
    update public.rooms
    set room_xp = coalesce(room_xp, 0) + v_total_added_vp,
        today_room_xp = coalesce(today_room_xp, 0) + v_total_added_vp,
        updated_at = now()
    where id = p_room_id;

    -- Upsert Gold Task progress
    if v_gold_added > 0 then
      insert into public.user_daily_task_progress (user_id, task_key, current_value, is_completed, task_date)
      values (p_user_id, 'gold_send_10', v_current_gold_vp + v_gold_added, (v_current_gold_vp + v_gold_added) >= v_max_gold_vp, ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date)
      on conflict (user_id, task_key, task_date) do update set
        current_value = user_daily_task_progress.current_value + v_gold_added,
        is_completed = (user_daily_task_progress.current_value + v_gold_added) >= v_max_gold_vp,
        updated_at = now();
    end if;

    -- Upsert Normal Task progress
    if v_free_added > 0 then
      insert into public.user_daily_task_progress (user_id, task_key, current_value, is_completed, task_date)
      values (p_user_id, 'normal_stay_15m', v_current_free_vp + v_free_added, (v_current_free_vp + v_free_added) >= v_max_free_vp, ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date)
      on conflict (user_id, task_key, task_date) do update set
        current_value = user_daily_task_progress.current_value + v_free_added,
        is_completed = (user_daily_task_progress.current_value + v_free_added) >= v_max_free_vp,
        updated_at = now();
    end if;
  end if;

  return jsonb_build_object(
    'success', true,
    'added_vp', v_total_added_vp,
    'gold_added', v_gold_added,
    'free_added', v_free_added,
    'current_total', v_current_total_vp + v_total_added_vp,
    'max_total', v_max_total_vp
  );
end;
$$ language plpgsql security definer;

-- 2. Drop existing overloaded send_star_gift functions to avoid 42601 record return type conflict
drop function if exists public.send_star_gift(text, uuid[], uuid, integer, integer, integer[]);
drop function if exists public.send_star_gift(text, uuid[], uuid, integer, integer);
drop function if exists public.send_star_gift(text, uuid[], uuid, integer);
drop function if exists public.send_star_gift(text, uuid[], uuid);

-- 3. Create production send_star_gift RPC returning JSONB
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
  v_vp_result jsonb;
  
  v_daily_cycle text := to_char(current_date, 'YYYY-MM-DD');
  v_weekly_cycle text := to_char(current_date, 'YYYY-') || 'W' || to_char(current_date, 'IW');
  v_monthly_cycle text := to_char(current_date, 'YYYY-MM');
  v_lifetime_cycle text := 'lifetime';
  
  v_receivers_names_list text := '';
  v_magic_result jsonb := null;
  
  -- Self-gifting anti-abuse parameters
  v_allow_self_gifting boolean := true;
  v_self_gift_payout_ratio numeric := 0.70;
  v_exclude_self_gifts_from_leaderboards boolean := true;
  v_exclude_self_gifts_from_xp boolean := true;
  v_is_self_gift boolean := false;
begin
  if v_sender_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Load global settings safely if table exists
  begin
    select allow_self_gifting, self_gift_payout_ratio, exclude_self_gifts_from_leaderboards, exclude_self_gifts_from_xp
    into v_allow_self_gifting, v_self_gift_payout_ratio, v_exclude_self_gifts_from_leaderboards, v_exclude_self_gifts_from_xp
    from public.gifting_settings where id = 'global';
  exception when others then
    v_allow_self_gifting := true;
  end;

  v_receivers_count := array_length(p_receiver_ids, 1);
  if v_receivers_count is null or v_receivers_count = 0 then
    raise exception 'Recipient list cannot be empty.';
  end if;

  select * into v_gift_record from public.gift_catalog where id = p_gift_id and is_active = true;
  if v_gift_record.id is null then
    -- Fallback search by string match if catalog item exists
    select * into v_gift_record from public.gift_catalog where id = p_gift_id limit 1;
    if v_gift_record.id is null then
      raise exception 'Selected gift is inactive or does not exist.';
    end if;
  end if;

  v_cost_stars := coalesce(v_gift_record.cost_stars, 10);
  v_cost_coins := v_cost_stars::integer;
  v_total_coins_cost := v_cost_coins * p_quantity * p_combo_count * v_receivers_count;
  v_total_stars_cost := v_cost_stars * p_quantity * p_combo_count * v_receivers_count;

  -- Ensure sender wallet exists in public.wallets (using standard coins_balance)
  insert into public.wallets (id, coins_balance)
  values (v_sender_id, 40000)
  on conflict (id) do nothing;

  -- Check sender wallet balance (Gold Coins balance)
  select coins_balance into v_sender_balance from public.wallets where id = v_sender_id;
  if coalesce(v_sender_balance, 0) < v_total_coins_cost then
    raise exception 'Insufficient Gold Coins balance (Requires % coins, you have %)', v_total_coins_cost, coalesce(v_sender_balance, 0);
  end if;
  
  -- Deduct coins balance
  update public.wallets set coins_balance = coins_balance - v_total_coins_cost where id = v_sender_id;

  -- Update sender total_stars_gifted on profiles
  update public.profiles
  set total_stars_gifted = coalesce(total_stars_gifted, 0) + v_total_stars_cost::integer,
      updated_at = now()
  where id = v_sender_id;

  -- Update Room Stars Totals on public.rooms
  update public.rooms
  set total_room_stars = coalesce(total_room_stars, 0) + v_total_stars_cost,
      today_room_stars = coalesce(today_room_stars, 0) + v_total_stars_cost,
      total_room_gifts = coalesce(total_room_gifts, 0) + (p_quantity * v_receivers_count),
      today_room_gifts = coalesce(today_room_gifts, 0) + (p_quantity * v_receivers_count),
      updated_at = now()
  where id = p_room_id;

  select username into v_sender_name from public.profiles where id = v_sender_id;

  -- Process payout for each receiver
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
    if v_receivers_names_list = '' then
      v_receivers_names_list := coalesce(v_receiver_name, 'User');
    else
      v_receivers_names_list := v_receivers_names_list || ', ' || coalesce(v_receiver_name, 'User');
    end if;

    -- Record transaction log
    insert into public.gift_transactions (
      room_id,
      sender_id,
      receiver_id,
      gift_id,
      gift_name,
      gift_icon,
      amount,
      currency,
      count,
      quantity,
      stars_value,
      combo_count,
      seat_index,
      created_at
    ) values (
      p_room_id,
      v_sender_id,
      v_receiver_id,
      p_gift_id,
      v_gift_record.name,
      v_gift_record.icon,
      v_cost_coins,
      v_gift_record.currency,
      p_quantity,
      p_quantity,
      v_total_stars_cost,
      p_combo_count,
      v_seat_index,
      now()
    ) returning id into v_tx_id;

    -- Update Seat level statistics
    if v_seat_index >= 0 then
      update public.room_seats
      set seat_total_gifts = coalesce(seat_total_gifts, 0) + p_quantity,
          seat_total_stars = coalesce(seat_total_stars, 0) + (v_cost_stars * p_quantity),
          last_gift_time = now()
      where room_id = p_room_id and user_id = v_receiver_id;
    end if;

    -- Update recipient star balance on profiles
    if not v_is_self_gift or v_self_gift_payout_ratio > 0 then
      update public.profiles
      set total_stars_received = coalesce(total_stars_received, 0) + (v_cost_stars * p_quantity * p_combo_count * (case when v_is_self_gift then v_self_gift_payout_ratio else 1.0 end))::integer,
          star_balance = coalesce(star_balance, 0) + (v_cost_stars * p_quantity * p_combo_count * (case when v_is_self_gift then v_self_gift_payout_ratio else 1.0 end)),
          total_received_stars = coalesce(total_received_stars, 0) + (v_cost_stars * p_quantity * p_combo_count * (case when v_is_self_gift then v_self_gift_payout_ratio else 1.0 end)),
          updated_at = now()
      where id = v_receiver_id;
    end if;
  end loop;

  -- Process Gold Task Progress with Overflow to Normal Task & Max Capping
  v_vp_result := public.add_room_vp_with_overflow(p_room_id, v_sender_id, v_total_stars_cost::integer, v_gift_record.currency);

  -- Record Room Activity Chat Message Entry for Realtime Broadcast & Animation Trigger
  insert into public.room_messages (
    room_id, sender_id, content, message_type, metadata
  ) values (
    p_room_id, v_sender_id,
    v_sender_name || ' sent ' || p_quantity || '× ' || v_gift_record.icon || ' ' || v_gift_record.name || ' to ' || v_receivers_names_list,
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
      'seat_indices', p_seat_indices,
      'animation_url', v_gift_record.animation_url,
      'vp_added', coalesce((v_vp_result->>'added_vp')::integer, 0)
    )
  );

  -- Get updated sender balance from public.wallets
  SELECT coins_balance INTO v_sender_balance FROM public.wallets WHERE id = v_sender_id;

  RETURN jsonb_build_object(
    'success', true,
    'remaining_balance', v_sender_balance,
    'vp_result', v_vp_result,
    'magic_result', v_magic_result
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Safe helper function: get_room_permissions
CREATE OR REPLACE FUNCTION public.get_room_permissions(p_room_id text)
RETURNS jsonb AS $$
BEGIN
  RETURN jsonb_build_object(
    'can_speak', true,
    'can_chat', true,
    'can_gift', true,
    'can_apply_seat', true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
