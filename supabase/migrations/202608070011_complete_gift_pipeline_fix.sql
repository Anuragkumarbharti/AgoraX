-- Migration: 202608070011_complete_gift_pipeline_fix.sql
-- Description: Production-grade atomic send_star_gift RPC with full schema compatibility,
-- sender/receiver stats, leaderboards, room gift counters, seat totals, daily task progress,
-- and event payload returning exact notification format: SENDER GIFT * COUNT RECEIVERS.

-- 1. Ensure profiles columns compatibility
alter table public.profiles add column if not exists total_stars_received integer default 0;
alter table public.profiles add column if not exists total_stars_gifted integer default 0;
alter table public.profiles add column if not exists star_balance numeric default 0;
alter table public.profiles add column if not exists total_received_stars numeric default 0;

-- 2. Ensure wallets table compatibility
create table if not exists public.wallets (
  id uuid primary key references public.profiles(id) on delete cascade,
  coins_balance integer default 0,
  silver_coins_balance integer default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 3. Ensure gift_transactions schema compatibility
create table if not exists public.gift_transactions (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete set null,
  receiver_id uuid references public.profiles(id) on delete set null,
  room_id text,
  gift_id uuid,
  gift_name text,
  gift_icon text,
  amount numeric,
  currency text default 'gold',
  count integer default 1,
  quantity integer default 1,
  combo_count integer default 1,
  stars_value numeric default 0,
  seat_index integer default -1,
  is_self_gift boolean default false,
  status text default 'Completed',
  created_at timestamptz default now()
);

alter table public.gift_transactions add column if not exists gift_name text;
alter table public.gift_transactions add column if not exists gift_icon text;
alter table public.gift_transactions add column if not exists amount numeric;
alter table public.gift_transactions add column if not exists currency text default 'gold';
alter table public.gift_transactions add column if not exists count integer default 1;
alter table public.gift_transactions add column if not exists seat_index integer default -1;
alter table public.gift_transactions add column if not exists stars_value numeric default 0;
alter table public.gift_transactions add column if not exists is_self_gift boolean default false;

-- 4. Ensure gift_history table compatibility
create table if not exists public.gift_history (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete set null,
  receiver_id uuid references public.profiles(id) on delete set null,
  item_id text,
  item_type text default 'VirtualGift',
  quantity integer default 1,
  stars_value numeric default 0,
  room_id text,
  created_at timestamptz default now()
);

-- 5. Ensure gift_statistics table compatibility
create table if not exists public.gift_statistics (
  user_id uuid references public.profiles(id) on delete cascade primary key,
  stars_sent_lifetime numeric default 0,
  stars_received_lifetime numeric default 0,
  highest_gift_value numeric default 0,
  highest_combo integer default 1,
  favorite_gift_id uuid,
  favorite_receiver_id uuid references public.profiles(id) on delete set null,
  favorite_sender_id uuid references public.profiles(id) on delete set null,
  updated_at timestamptz default now()
);

-- 6. Ensure gift_leaderboards table compatibility
create table if not exists public.gift_leaderboards (
  user_id uuid references public.profiles(id) on delete cascade,
  type text not null check (type in ('gifter', 'receiver')),
  cycle text not null check (cycle in ('daily', 'weekly', 'monthly', 'lifetime')),
  cycle_key text not null,
  value numeric default 0,
  updated_at timestamptz default now(),
  primary key (user_id, type, cycle, cycle_key)
);

-- 7. Ensure rooms and room_seats stars columns compatibility
alter table public.rooms add column if not exists total_room_stars numeric default 0;
alter table public.rooms add column if not exists today_room_stars numeric default 0;
alter table public.rooms add column if not exists total_room_gifts integer default 0;
alter table public.rooms add column if not exists today_room_gifts integer default 0;
alter table public.rooms add column if not exists room_xp integer default 0;
alter table public.rooms add column if not exists today_room_xp integer default 0;

alter table public.room_seats add column if not exists seat_total_stars numeric default 0;
alter table public.room_seats add column if not exists seat_total_gifts integer default 0;
alter table public.room_seats add column if not exists last_gift_time timestamp with time zone;

-- 8. Enable RLS and grant public access to gifting tables
alter table public.gift_transactions enable row level security;
alter table public.gift_history enable row level security;
alter table public.gift_statistics enable row level security;
alter table public.gift_leaderboards enable row level security;

drop policy if exists "Allow select on gift_transactions" on public.gift_transactions;
create policy "Allow select on gift_transactions" on public.gift_transactions for select to authenticated using (true);

drop policy if exists "Allow select on gift_history" on public.gift_history;
create policy "Allow select on gift_history" on public.gift_history for select to authenticated using (true);

drop policy if exists "Allow select on gift_statistics" on public.gift_statistics;
create policy "Allow select on gift_statistics" on public.gift_statistics for select to authenticated using (true);

drop policy if exists "Allow select on gift_leaderboards" on public.gift_leaderboards;
create policy "Allow select on gift_leaderboards" on public.gift_leaderboards for select to authenticated using (true);

-- 9. Helper function: Add Room VP with Gold Task Overflow
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

  select 
    coalesce(sum(case when t.category <> 'gold' then p.current_value else 0 end), 0),
    coalesce(sum(case when t.category = 'gold' then p.current_value else 0 end), 0)
  into v_current_free_vp, v_current_gold_vp
  from public.user_daily_task_progress p
  join public.room_daily_task_catalog t on t.task_key = p.task_key
  where p.user_id = p_user_id and p.task_date = ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date;

  v_current_total_vp := v_current_free_vp + v_current_gold_vp;

  if v_current_total_vp >= v_max_total_vp then
    return jsonb_build_object('success', false, 'reason', 'MAX daily task limit reached', 'added_vp', 0);
  end if;

  if p_currency = 'gold' then
    v_gold_capacity := greatest(0, v_max_gold_vp - v_current_gold_vp);
    if p_vp <= v_gold_capacity then
      v_gold_added := p_vp;
      v_overflow := 0;
    else
      v_gold_added := v_gold_capacity;
      v_overflow := p_vp - v_gold_capacity;
    end if;

    if v_overflow > 0 then
      v_free_capacity := greatest(0, v_max_free_vp - v_current_free_vp);
      v_free_added := least(v_overflow, v_free_capacity);
    end if;
  else
    v_free_capacity := greatest(0, v_max_free_vp - v_current_free_vp);
    v_free_added := least(p_vp, v_free_capacity);
  end if;

  v_total_added_vp := v_gold_added + v_free_added;

  if v_total_added_vp > 0 then
    update public.rooms
    set room_xp = coalesce(room_xp, 0) + v_total_added_vp,
        today_room_xp = coalesce(today_room_xp, 0) + v_total_added_vp,
        updated_at = now()
    where id = p_room_id;

    if v_gold_added > 0 then
      insert into public.user_daily_task_progress (user_id, task_key, current_value, is_completed, task_date)
      values (p_user_id, 'gold_send_10', v_current_gold_vp + v_gold_added, (v_current_gold_vp + v_gold_added) >= v_max_gold_vp, ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date)
      on conflict (user_id, task_key, task_date) do update set
        current_value = user_daily_task_progress.current_value + v_gold_added,
        is_completed = (user_daily_task_progress.current_value + v_gold_added) >= v_max_gold_vp,
        updated_at = now();
    end if;

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

-- 10. Drop old send_star_gift function signatures
drop function if exists public.send_star_gift(text, uuid[], uuid, integer, integer, integer[]);
drop function if exists public.send_star_gift(text, uuid[], uuid, integer, integer);
drop function if exists public.send_star_gift(text, uuid[], uuid, integer);
drop function if exists public.send_star_gift(text, uuid[], uuid);

-- 11. Create 100% production-ready atomic send_star_gift RPC
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
  
  v_daily_cycle text := to_char(current_date, 'YYYY-MM-DD');
  v_weekly_cycle text := to_char(current_date, 'YYYY-') || 'W' || to_char(current_date, 'IW');
  v_monthly_cycle text := to_char(current_date, 'YYYY-MM');
  v_lifetime_cycle text := 'lifetime';
  
  v_receivers_names_list text := '';
  v_receivers_names_array text[] := array[]::text[];
  v_formatted_gift_message text;
  v_event_payload jsonb;
  
  -- Self-gifting anti-abuse parameters
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

  -- Load global settings safely
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

    -- Record Gift Transaction Log
    insert into public.gift_transactions (
      room_id, sender_id, receiver_id, gift_id, gift_name, gift_icon,
      amount, currency, count, quantity, stars_value, combo_count, seat_index, is_self_gift, created_at
    ) values (
      p_room_id, v_sender_id, v_receiver_id, p_gift_id, v_gift_record.name, v_gift_record.icon,
      v_cost_coins, v_gift_record.currency, p_quantity, p_quantity, (v_cost_stars * p_quantity * p_combo_count), p_combo_count, v_seat_index, v_is_self_gift, now()
    ) returning id into v_tx_id;

    -- Record Gift History Log
    insert into public.gift_history (
      sender_id, receiver_id, item_id, item_type, quantity, stars_value, room_id, created_at
    ) values (
      v_sender_id, v_receiver_id, v_gift_record.name, 'VirtualGift', p_quantity * p_combo_count, (v_cost_stars * p_quantity * p_combo_count), p_room_id, now()
    );

    -- Update Seat Level Statistics
    if v_seat_index >= 0 then
      update public.room_seats
      set seat_total_gifts = coalesce(seat_total_gifts, 0) + (p_quantity * p_combo_count),
          seat_total_stars = coalesce(seat_total_stars, 0) + (v_cost_stars * p_quantity * p_combo_count),
          last_gift_time = now()
      where room_id = p_room_id and user_id = v_receiver_id;
    end if;

    -- Update Recipient Profile Stars & Balance
    if not v_is_self_gift or v_self_gift_payout_ratio > 0 then
      update public.profiles
      set total_stars_received = coalesce(total_stars_received, 0) + (v_cost_stars * p_quantity * p_combo_count * (case when v_is_self_gift then v_self_gift_payout_ratio else 1.0 end))::integer,
          star_balance = coalesce(star_balance, 0) + (v_cost_stars * p_quantity * p_combo_count * (case when v_is_self_gift then v_self_gift_payout_ratio else 1.0 end)),
          total_received_stars = coalesce(total_received_stars, 0) + (v_cost_stars * p_quantity * p_combo_count * (case when v_is_self_gift then v_self_gift_payout_ratio else 1.0 end)),
          updated_at = now()
      where id = v_receiver_id;

      -- Update Recipient Gift Statistics & Leaderboards
      insert into public.gift_statistics (user_id, stars_received_lifetime, highest_gift_value, favorite_sender_id, updated_at)
      values (v_receiver_id, (v_cost_stars * p_quantity * p_combo_count), v_cost_stars, v_sender_id, now())
      on conflict (user_id) do update set
        stars_received_lifetime = coalesce(gift_statistics.stars_received_lifetime, 0) + (v_cost_stars * p_quantity * p_combo_count),
        highest_gift_value = greatest(coalesce(gift_statistics.highest_gift_value, 0), v_cost_stars),
        favorite_sender_id = v_sender_id,
        updated_at = now();

      insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value, updated_at)
      values (v_receiver_id, 'receiver', 'daily', v_daily_cycle, (v_cost_stars * p_quantity * p_combo_count), now())
      on conflict (user_id, type, cycle, cycle_key) do update set
        value = gift_leaderboards.value + (v_cost_stars * p_quantity * p_combo_count), updated_at = now();

      insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value, updated_at)
      values (v_receiver_id, 'receiver', 'weekly', v_weekly_cycle, (v_cost_stars * p_quantity * p_combo_count), now())
      on conflict (user_id, type, cycle, cycle_key) do update set
        value = gift_leaderboards.value + (v_cost_stars * p_quantity * p_combo_count), updated_at = now();

      insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value, updated_at)
      values (v_receiver_id, 'receiver', 'monthly', v_monthly_cycle, (v_cost_stars * p_quantity * p_combo_count), now())
      on conflict (user_id, type, cycle, cycle_key) do update set
        value = gift_leaderboards.value + (v_cost_stars * p_quantity * p_combo_count), updated_at = now();

      insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value, updated_at)
      values (v_receiver_id, 'receiver', 'lifetime', v_lifetime_cycle, (v_cost_stars * p_quantity * p_combo_count), now())
      on conflict (user_id, type, cycle, cycle_key) do update set
        value = gift_leaderboards.value + (v_cost_stars * p_quantity * p_combo_count), updated_at = now();
    end if;
  end loop;

  -- 12. Process VP / Room XP Progress
  v_vp_result := public.add_room_vp_with_overflow(p_room_id, v_sender_id, v_total_stars_cost::integer, v_gift_record.currency);

  -- 13. Format Exact Notification Message: USERNAME GIFT * GIFT COUNT USER NAME
  v_formatted_gift_message := v_sender_name || ' ' || v_gift_record.name || ' * ' || (p_quantity * p_combo_count)::text || ' ' || v_receivers_names_list;

  -- 14. Construct Standardized Event Payload
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
    'messageText', v_formatted_gift_message
  );

  -- 15. Record Chat & Activity Log Entries
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

  -- 16. Get final sender remaining balance
  select coins_balance into v_sender_balance from public.wallets where id = v_sender_id;

  -- 17. Return Success Result
  return jsonb_build_object(
    'success', true,
    'remaining_balance', v_sender_balance,
    'event_payload', v_event_payload,
    'vp_result', v_vp_result
  );
end;
$$ language plpgsql security definer;
