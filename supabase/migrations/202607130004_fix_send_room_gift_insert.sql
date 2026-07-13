-- supabase/migrations/202607130004_fix_send_room_gift_insert.sql

create or replace function public.send_room_gift(
  p_room_id text,
  p_receiver_id uuid,
  p_gift_name text,
  p_coins_value integer,
  p_quantity integer default 1
) returns jsonb as $$
declare
  v_sender_id uuid;
  v_sender_balance integer;
  v_total_cost integer;
  v_gift_id uuid;
  v_sender_name text;
  v_receiver_name text;
  v_stars integer;
begin
  v_sender_id := auth.uid();
  if v_sender_id is null then
    raise exception 'Not authenticated';
  end if;

  v_total_cost := p_coins_value * p_quantity;

  -- Fetch sender details
  select username, coins_balance into v_sender_name, v_sender_balance 
  from public.profiles p
  join public.wallets w on w.id = p.id
  where p.id = v_sender_id;

  if coalesce(v_sender_balance, 0) < v_total_cost then
    raise exception 'Insufficient Gold Coins (Requires % coins)', v_total_cost;
  end if;

  -- Fetch receiver name
  select username into v_receiver_name from public.profiles where id = p_receiver_id;
  if v_receiver_name is null then
    v_receiver_name := 'Receiver';
  end if;

  -- Compute stars: 2-Star Gift = 2, 1-Star Gift = 1, otherwise 1 star per 10 coins (minimum 1 star)
  if p_gift_name = '2-Star Gift' then
    v_stars := 2;
  elseif p_gift_name = '1-Star Gift' then
    v_stars := 1;
  else
    v_stars := greatest(1, coalesce((p_coins_value / 10)::int, 0));
  end if;

  -- Deduct from sender
  update public.wallets set coins_balance = coins_balance - v_total_cost where id = v_sender_id;
  insert into public.wallet_transactions (wallet_id, amount, currency, type, status, details, transaction_type)
  values (v_sender_id, -v_total_cost, 'Coins', 'Payout', 'Completed', 'Sent ' || p_gift_name || ' gift in voice room', 'Purchase');

  -- Add to receiver (if not self)
  if v_sender_id <> p_receiver_id then
    update public.wallets set coins_balance = coins_balance + v_total_cost where id = p_receiver_id;
    insert into public.wallet_transactions (wallet_id, amount, currency, type, status, details, transaction_type)
    values (p_receiver_id, v_total_cost, 'Coins', 'Reward', 'Completed', 'Received ' || p_gift_name || ' gift in voice room', 'Reward');
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
      total_room_stars = total_room_stars + (v_stars * p_quantity),
      today_room_stars = today_room_stars + (v_stars * p_quantity),
      updated_at = now()
  where id = p_room_id;

  -- Update seat-specific star & gift stats if receiver is seated
  update public.room_seats
  set seat_total_gifts = seat_total_gifts + p_quantity,
      seat_total_stars = seat_total_stars + (v_stars * p_quantity),
      last_gift_time = now()
  where room_id = p_room_id and user_id = p_receiver_id;

  -- Update gift stats (daily, weekly, monthly gold totals in room_gift_statistics)
  update public.room_gift_statistics
  set total_gold_received = total_gold_received + v_total_cost
  where room_id = p_room_id;

  -- Insert system/gift message to room chat
  insert into public.room_messages (
    room_id, sender_id, content, message_type, metadata
  ) values (
    p_room_id, v_sender_id, v_sender_name || ' sent ' || p_gift_name || ' to ' || v_receiver_name, 'gift',
    jsonb_build_object('gift_name', p_gift_name, 'coins_value', p_coins_value, 'quantity', p_quantity, 'receiver_id', p_receiver_id)
  );

  return jsonb_build_object(
    'success', true,
    'gift_id', v_gift_id,
    'remaining_balance', v_sender_balance - v_total_cost
  );
end;
$$ language plpgsql security definer;
