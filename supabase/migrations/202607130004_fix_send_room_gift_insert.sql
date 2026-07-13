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
begin
  v_sender_id := auth.uid();
  if v_sender_id is null then
    raise exception 'Not authenticated';
  end if;

  v_total_cost := p_coins_value * p_quantity;

  -- Fetch sender balance
  select coins_balance into v_sender_balance from public.wallets where id = v_sender_id;
  if coalesce(v_sender_balance, 0) < v_total_cost then
    raise exception 'Insufficient Gold Coins (Requires % coins)', v_total_cost;
  end if;

  -- Deduct from sender
  update public.wallets set coins_balance = coins_balance - v_total_cost where id = v_sender_id;
  insert into public.wallet_transactions (wallet_id, amount, transaction_type, details)
  values (v_sender_id, -v_total_cost, 'Purchase', 'Sent ' || p_gift_name || ' gift in voice room');

  -- Add to receiver (Host or creator)
  update public.wallets set coins_balance = coins_balance + v_total_cost where id = p_receiver_id;
  insert into public.wallet_transactions (wallet_id, amount, transaction_type, details)
  values (p_receiver_id, v_total_cost, 'Reward', 'Received ' || p_gift_name || ' gift in voice room');

  -- Record Gift (Removed created_at target column as it defaults automatically)
  insert into public.room_gifts (room_id, sender_id, receiver_id, gift_name, coins_value, quantity)
  values (p_room_id, v_sender_id, p_receiver_id, p_gift_name, p_coins_value, p_quantity)
  returning id into v_gift_id;

  -- Insert a system/gift message to room chat
  insert into public.room_messages (
    room_id, sender_id, content, message_type, metadata
  ) values (
    p_room_id, v_sender_id, 'gifted ' || p_gift_name || ' to ' || (select username from public.profiles where id = p_receiver_id), 'gift',
    jsonb_build_object('gift_name', p_gift_name, 'coins_value', p_coins_value, 'quantity', p_quantity, 'receiver_id', p_receiver_id)
  );

  return jsonb_build_object(
    'success', true,
    'gift_id', v_gift_id,
    'remaining_balance', v_sender_balance - v_total_cost
  );
end;
$$ language plpgsql security definer;
