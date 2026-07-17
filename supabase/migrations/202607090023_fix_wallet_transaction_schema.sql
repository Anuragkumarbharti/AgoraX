-- 202607090023_fix_wallet_transaction_schema.sql
-- Fixes broken RPCs that use the old wallet_transactions schema.
-- Migration 202607090020 dropped and recreated wallet_transactions without
-- the 'transaction_type' column. This patch rewrites all affected functions
-- to use the correct columns: currency, type, status, details.
-- Also adds the missing generate_unique_room_id() helper function.

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. Create missing helper: generate_unique_room_id()
--    Generates a short unique 6-char alphanumeric room ID (e.g. "A3K9ZX").
--    Called by create_room() but was never defined in any earlier migration.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.generate_unique_room_id()
returns text
language plpgsql
as $$
declare
  v_id text;
begin
  loop
    -- Generate a random 8-digit number (10000000–99999999)
    v_id := (floor(random() * 90000000) + 10000000)::bigint::text;
    exit when not exists (select 1 from public.rooms where id = v_id);
  end loop;
  return v_id;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 0b. Patch rooms.username check constraint: require at least 4 chars (was 3)
-- ─────────────────────────────────────────────────────────────────────────────
do $$
begin
  -- Drop old constraint if it exists
  if exists (
    select 1 from information_schema.table_constraints
    where table_name = 'rooms'
      and constraint_name = 'check_room_username'
  ) then
    alter table public.rooms drop constraint check_room_username;
  end if;

  -- Re-add with min 4 chars
  alter table public.rooms
    add constraint check_room_username
    check (username ~ '^@[a-z0-9_]{4,30}$');
end;
$$;

create or replace function public.create_room(
  p_name text,
  p_username text,
  p_description text,
  p_category text,
  p_country text,
  p_language text,
  p_tags text[],
  p_rules text[],
  p_entry_permission text,
  p_avatar text,
  p_banner text,
  p_is_permanent boolean
) returns text as $$
declare
  v_user_id uuid := auth.uid();
  v_room_id text;
  v_room_name text;
  v_balance integer;
begin
  if v_user_id is null then
    raise exception 'Unauthenticated';
  end if;

  if p_username is not null and p_username <> '' then
    p_username := lower(trim(p_username));
    if left(p_username, 1) <> '@' then
      p_username := '@' || p_username;
    end if;
  end if;

  if p_is_permanent and exists (
    select 1 from public.rooms
    where host_id = v_user_id
      and is_permanent = true
      and status in ('live', 'scheduled')
  ) then
    raise exception 'You can only own one active permanent voice room at a time';
  end if;

  if p_is_permanent then
    select coins_balance into v_balance from public.wallets where id = v_user_id;
    if coalesce(v_balance, 0) < 599 then
      raise exception 'Insufficient balance: permanent rooms cost 599 gold coins';
    end if;

    update public.wallets set coins_balance = coins_balance - 599 where id = v_user_id;

    -- Fixed: removed transaction_type (old column), added currency/type/status
    insert into public.wallet_transactions (wallet_id, amount, currency, type, status, details)
    values (v_user_id, 599, 'Gold Coins', 'Purchase', 'Completed', 'Unlocked permanent voice room');
  end if;

  v_room_id := public.generate_unique_room_id();
  v_room_name := 'room_' || encode(gen_random_bytes(6), 'hex');

  insert into public.rooms (
    id, name, username, description, category, language, tags, rules, host_id, status,
    visibility, recording_status, level_requirement, vip_requirement,
    verification_requirement, livekit_room_name, avatar, banner, is_permanent
  ) values (
    v_room_id, p_name, p_username, p_description, p_category, p_language, p_tags, p_rules, v_user_id, 'live',
    p_entry_permission, 'inactive', 1, 0, false, v_room_name, p_avatar, p_banner, p_is_permanent
  );

  return v_room_id;
end;
$$ language plpgsql security definer;


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Patch public.send_room_gift
--    Old:  insert (..., transaction_type)  with invalid types 'Payout'/'Reward'
--    New:  insert (...) without transaction_type; use valid type 'Spend'/'Bonus'
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.send_room_gift(
  p_room_id text,
  p_receiver_id uuid,
  p_gift_name text,
  p_coins_value integer,
  p_quantity integer default 1
) returns jsonb as $$
declare
  v_sender_id uuid := auth.uid();
  v_sender_balance integer;
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

  select username, coins_balance into v_sender_name, v_sender_balance
  from public.profiles p
  join public.wallets w on w.id = p.id
  where p.id = v_sender_id;

  if coalesce(v_sender_balance, 0) < v_total_cost then
    raise exception 'Insufficient Gold Coins (Requires % coins)', v_total_cost;
  end if;

  select username into v_receiver_name from public.profiles where id = p_receiver_id;
  if v_receiver_name is null then
    v_receiver_name := 'Receiver';
  end if;

  v_stars := public.calculate_gift_stars(p_gift_name, p_coins_value, p_quantity);

  -- Deduct from sender (fixed: no transaction_type, valid type = 'Spend')
  update public.wallets set coins_balance = coins_balance - v_total_cost where id = v_sender_id;
  insert into public.wallet_transactions (wallet_id, amount, currency, type, status, details)
  values (v_sender_id, v_total_cost, 'Gold Coins', 'Spend', 'Completed',
          'Sent ' || p_gift_name || ' gift in voice room');

  -- Add to receiver (fixed: valid type = 'Bonus')
  if v_sender_id <> p_receiver_id then
    update public.wallets set coins_balance = coins_balance + v_total_cost where id = p_receiver_id;
    insert into public.wallet_transactions (wallet_id, amount, currency, type, status, details)
    values (p_receiver_id, v_total_cost, 'Gold Coins', 'Bonus', 'Completed',
            'Received ' || p_gift_name || ' gift in voice room');
  end if;

  -- General gift history log
  insert into public.gift_history (sender_id, receiver_id, item_id, item_type, quantity, coins_value)
  values (v_sender_id, p_receiver_id, p_gift_name, 'VirtualGift', p_quantity, p_coins_value);

  -- Record Room Gift
  insert into public.room_gifts (room_id, sender_id, receiver_id, gift_name, coins_value, quantity)
  values (p_room_id, v_sender_id, p_receiver_id, p_gift_name, p_coins_value, p_quantity)
  returning id into v_gift_id;

  -- Update room-wide star & gift stats
  update public.rooms
  set total_room_gifts = total_room_gifts + p_quantity,
      today_room_gifts = today_room_gifts + p_quantity,
      total_room_stars = total_room_stars + (v_stars),
      today_room_stars = today_room_stars + (v_stars),
      updated_at = now()
  where id = p_room_id;

  -- Update seat-specific star & gift stats if receiver is seated
  update public.room_seats
  set seat_total_gifts = seat_total_gifts + p_quantity,
      seat_total_stars = seat_total_stars + (v_stars),
      last_gift_time = now()
  where room_id = p_room_id and user_id = p_receiver_id;

  update public.room_gift_statistics
  set total_gold_received = total_gold_received + v_total_cost
  where room_id = p_room_id;

  insert into public.room_messages (
    room_id, sender_id, content, message_type, metadata
  ) values (
    p_room_id, v_sender_id,
    v_sender_name || ' sent ' || p_gift_name || ' to ' || v_receiver_name,
    'gift',
    jsonb_build_object(
      'gift_name', p_gift_name,
      'coins_value', p_coins_value,
      'quantity', p_quantity,
      'receiver_id', p_receiver_id
    )
  );

  return jsonb_build_object(
    'success', true,
    'gift_id', v_gift_id,
    'remaining_balance', v_sender_balance - v_total_cost
  );
end;
$$ language plpgsql security definer;
