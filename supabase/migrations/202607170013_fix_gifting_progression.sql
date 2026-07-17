-- 202607170013_fix_gifting_progression.sql

-- 1. Patch public.send_room_gift to invoke progression triggers
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

  -- Deduct from sender
  update public.wallets set coins_balance = coins_balance - v_total_cost where id = v_sender_id;
  insert into public.wallet_transactions (wallet_id, amount, currency, type, status, details)
  values (v_sender_id, v_total_cost, 'Gold Coins', 'Spend', 'Completed',
          'Sent ' || p_gift_name || ' gift in voice room');

  -- Add to receiver
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

  -- Record Chat message
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

  -- Trigger progression event (gifting task completion)
  begin
    perform public.process_xp_event('gift_sent', jsonb_build_object('recipient_id', p_receiver_id, 'gift_id', v_gift_id::text));
  exception when others then
    -- Fail-safe: don't block gifting if progression triggers fail
    null;
  end;

  return jsonb_build_object(
    'success', true,
    'gift_id', v_gift_id,
    'remaining_balance', v_sender_balance - v_total_cost
  );
end;
$$ language plpgsql security definer;


-- 2. Patch public.gift_vault_item to invoke progression triggers
create or replace function public.gift_vault_item(p_item_id uuid, p_receiver_id uuid)
returns jsonb as $$
declare
  v_item record;
  v_asset record;
begin
  -- Validate receiver exists
  if not exists (select 1 from public.profiles where id = p_receiver_id) then
    return jsonb_build_object('success', false, 'reason', 'Receiver profile not found.');
  end if;

  -- Block gifting to self
  if p_receiver_id = auth.uid() then
    return jsonb_build_object('success', false, 'reason', 'Cannot gift items to yourself.');
  end if;

  -- Fetch vault item
  select * into v_item from public.vault_items where id = p_item_id and user_id = auth.uid();
  if not found then
    return jsonb_build_object('success', false, 'reason', 'Item not found in your vault.');
  end if;

  -- Fetch asset definition
  select * into v_asset from public.asset_definitions where id = v_item.asset_id;

  -- Validate item is giftable
  if not v_asset.giftable then
    return jsonb_build_object('success', false, 'reason', 'This item is not giftable.');
  end if;

  -- Enforce quantity logic
  if v_item.quantity <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Insufficient item quantity.');
  end if;

  -- 1. Deduct quantity from Sender
  update public.vault_items 
  set quantity = quantity - 1,
      status = case when quantity - 1 = 0 then 'Gifted'::text else status end
  where id = p_item_id;

  -- Log sender history
  insert into public.vault_item_history (user_id, vault_item_id, action_type, quantity, details)
  values (auth.uid(), p_item_id, 'Gifted', 1, jsonb_build_object('receiver_id', p_receiver_id, 'asset_name', v_asset.display_name));

  -- 2. Insert or Stack into Receiver Vault
  insert into public.vault_items (
    user_id, asset_id, quantity, status, purchase_source, purchase_date, expires_at
  ) values (
    p_receiver_id,
    v_item.asset_id,
    1,
    'Unlocked',
    'Gifted',
    now(),
    v_item.expires_at
  )
  on conflict (user_id, asset_id) do update set
    quantity = vault_items.quantity + 1,
    status = 'Unlocked',
    expires_at = EXCLUDED.expires_at;

  -- Log receiver history
  declare
    v_receiver_item_id uuid;
  begin
    select id into v_receiver_item_id from public.vault_items where user_id = p_receiver_id and asset_id = v_item.asset_id;
    insert into public.vault_item_history (user_id, vault_item_id, action_type, quantity, details)
    values (p_receiver_id, v_receiver_item_id, 'Received', 1, jsonb_build_object('sender_id', auth.uid(), 'asset_name', v_asset.display_name));
  end;

  -- Trigger progression event (gifting task completion)
  begin
    perform public.process_xp_event('gift_sent', jsonb_build_object('recipient_id', p_receiver_id, 'gift_id', p_item_id::text));
  exception when others then
    -- Fail-safe: don't block gifting if progression triggers fail
    null;
  end;

  return jsonb_build_object('success', true, 'reason', 'Item successfully gifted!');
end;
$$ language plpgsql security definer;
