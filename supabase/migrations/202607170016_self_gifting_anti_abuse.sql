-- 202607170016_self_gifting_anti_abuse.sql

-- 1. Create gifting_settings table
create table if not exists public.gifting_settings (
  id text primary key,
  allow_self_gifting boolean default true,
  self_gift_payout_ratio numeric default 0.0 check (self_gift_payout_ratio >= 0.0 and self_gift_payout_ratio <= 1.0),
  exclude_self_gifts_from_leaderboards boolean default true,
  exclude_self_gifts_from_xp boolean default true,
  exclude_self_gifts_from_milestones boolean default true,
  updated_at timestamptz default now()
);

-- Seed default settings
insert into public.gifting_settings (id, allow_self_gifting, self_gift_payout_ratio, exclude_self_gifts_from_leaderboards, exclude_self_gifts_from_xp, exclude_self_gifts_from_milestones)
values ('global', true, 0.0, true, true, true)
on conflict (id) do nothing;

-- 2. Alter gift_transactions table to add is_self_gift flag
alter table public.gift_transactions add column if not exists is_self_gift boolean default false;

-- Enable RLS for settings
alter table public.gifting_settings enable row level security;
create policy "Allow read access to gifting_settings" on public.gifting_settings for select to authenticated using (true);


-- 3. Refactor send_star_gift RPC to handle self-gifting anti-abuse policies and settings
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
  v_is_self_gift boolean := false;
  
  -- Settings
  v_allow_self_gifting boolean;
  v_self_gift_payout_ratio numeric;
  v_exclude_self_gifts_from_leaderboards boolean;
  v_exclude_self_gifts_from_xp boolean;
  
  -- Magic Gift Payout details
  v_magic_result jsonb := null;
  
  -- Leaderboard cycle keys
  v_daily_cycle text := to_char(current_date, 'YYYY-MM-DD');
  v_weekly_cycle text := to_char(current_date, 'YYYY-') || 'W' || to_char(current_date, 'IW');
  v_monthly_cycle text := to_char(current_date, 'YYYY-MM');
  v_lifetime_cycle text := 'lifetime';
  
  v_receivers_names_list text := '';
begin
  if v_sender_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Load global gifting controls
  select allow_self_gifting, self_gift_payout_ratio, exclude_self_gifts_from_leaderboards, exclude_self_gifts_from_xp
  into v_allow_self_gifting, v_self_gift_payout_ratio, v_exclude_self_gifts_from_leaderboards, v_exclude_self_gifts_from_xp
  from public.gifting_settings where id = 'global';

  v_receivers_count := array_length(p_receiver_ids, 1);
  if v_receivers_count is null or v_receivers_count = 0 then
    raise exception 'Recipient list cannot be empty.';
  end if;

  select * into v_gift_record from public.gift_catalog where id = p_gift_id and is_active = true;
  if v_gift_record.id is null then
    raise exception 'Selected gift is inactive or does not exist.';
  end if;

  v_cost_stars := v_gift_record.cost_stars;
  if v_gift_record.currency = 'gold' then
    v_cost_coins := v_cost_stars::integer; 
  else
    v_cost_coins := (v_cost_stars * 100)::integer; 
  end if;

  v_total_coins_cost := v_cost_coins * p_quantity * v_receivers_count;
  v_total_stars_cost := v_cost_stars * p_quantity * v_receivers_count;

  select username into v_sender_name from public.profiles where id = v_sender_id;
  if v_gift_record.currency = 'gold' then
    select coins_balance into v_sender_balance from public.wallets where id = v_sender_id;
    if coalesce(v_sender_balance, 0) < v_total_coins_cost then
      raise exception 'Insufficient Gold Coins (Requires % coins)', v_total_coins_cost;
    end if;
    update public.wallets set coins_balance = coins_balance - v_total_coins_cost where id = v_sender_id;
  else
    select silver_coins_balance into v_sender_balance from public.wallets where id = v_sender_id;
    if coalesce(v_sender_balance, 0) < v_total_coins_cost then
      raise exception 'Insufficient Silver Coins (Requires % coins)', v_total_coins_cost;
    end if;
    update public.wallets set silver_coins_balance = silver_coins_balance - v_total_coins_cost where id = v_sender_id;
  end if;

  insert into public.gift_wallet_logs (user_id, amount, currency, direction, reason)
  values (v_sender_id, v_total_coins_cost, v_gift_record.currency, 'Debit', 'Sent ' || v_gift_record.name || ' gift in room ' || p_room_id);

  -- Process Magic Gift Lottery draw if applicable
  if v_gift_record.is_magic = true and v_gift_record.currency = 'gold' then
    begin
      v_magic_result := public.draw_magic_gift_reward(v_sender_id, p_gift_id, v_cost_coins * p_quantity);
    exception when others then
      v_magic_result := null;
    end;
  end if;

  for v_receiver_idx in 1..v_receivers_count loop
    v_receiver_id := p_receiver_ids[v_receiver_idx];
    
    select username into v_receiver_name from public.profiles where id = v_receiver_id;
    if v_receiver_name is null then
      v_receiver_name := 'Receiver';
    end if;

    if v_receiver_idx = 1 then
      v_receivers_names_list := v_receiver_name;
    elsif v_receiver_idx = v_receivers_count then
      v_receivers_names_list := v_receivers_names_list || ' and ' || v_receiver_name;
    else
      v_receivers_names_list := v_receivers_names_list || ', ' || v_receiver_name;
    end if;

    -- Self-gifting anti-abuse validation
    if v_sender_id = v_receiver_id then
      if coalesce(v_allow_self_gifting, true) = false then
        raise exception 'Self-gifting is disabled by administrator.';
      end if;
      v_is_self_gift := true;
    end if;

    -- Transfer coins to recipient (taking payout ratio into account for self gifts)
    declare
      v_payout_amount integer;
    begin
      if v_is_self_gift then
        v_payout_amount := ((v_cost_coins * p_quantity) * coalesce(v_self_gift_payout_ratio, 0.0))::integer;
      else
        v_payout_amount := v_cost_coins * p_quantity;
      end if;

      if v_payout_amount > 0 then
        if v_gift_record.currency = 'gold' then
          update public.wallets set coins_balance = coins_balance + v_payout_amount where id = v_receiver_id;
        else
          update public.wallets set silver_coins_balance = silver_coins_balance + v_payout_amount where id = v_receiver_id;
        end if;

        insert into public.gift_wallet_logs (user_id, amount, currency, direction, reason)
        values (v_receiver_id, v_payout_amount, v_gift_record.currency, 'Credit', 'Received ' || v_gift_record.name || ' gift in room ' || p_room_id);
      end if;
    end;

    insert into public.gift_transactions (sender_id, receiver_id, room_id, gift_id, stars_value, quantity, combo_count, is_self_gift)
    values (v_sender_id, v_receiver_id, p_room_id, p_gift_id, v_cost_stars * p_quantity, p_quantity, p_combo_count, v_is_self_gift)
    returning id into v_tx_id;

    if p_seat_indices is not null and array_length(p_seat_indices, 1) >= v_receiver_idx then
      v_seat_index := p_seat_indices[v_receiver_idx];
      insert into public.gift_seat_logs (transaction_id, seat_index, receiver_id)
      values (v_tx_id, v_seat_index, v_receiver_id);
      
      update public.room_seats
      set seat_total_gifts = seat_total_gifts + p_quantity,
          seat_total_stars = seat_total_stars + (v_cost_stars * p_quantity),
          last_gift_time = now()
      where room_id = p_room_id and user_id = v_receiver_id;
    end if;

    insert into public.gift_history (sender_id, receiver_id, item_id, item_type, quantity, stars_value, room_id)
    values (v_sender_id, v_receiver_id, v_gift_record.name, 'VirtualGift', p_quantity, v_cost_stars * p_quantity, p_room_id);

    insert into public.gift_statistics (user_id, stars_received_lifetime, highest_gift_value, favorite_sender_id)
    values (v_receiver_id, v_cost_stars * p_quantity, v_cost_stars * p_quantity, v_sender_id)
    on conflict (user_id) do update set
      stars_received_lifetime = gift_statistics.stars_received_lifetime + (v_cost_stars * p_quantity),
      highest_gift_value = greatest(gift_statistics.highest_gift_value, v_cost_stars * p_quantity),
      favorite_sender_id = EXCLUDED.favorite_sender_id,
      updated_at = now();

    -- Anti-abuse leaderboard checks
    if not (v_is_self_gift and coalesce(v_exclude_self_gifts_from_leaderboards, true)) then
      insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value)
      values (v_receiver_id, 'receiver', 'daily', v_daily_cycle, v_cost_stars * p_quantity)
      on conflict (user_id, type, cycle, cycle_key) do update set value = gift_leaderboards.value + (v_cost_stars * p_quantity), updated_at = now();
      
      insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value)
      values (v_receiver_id, 'receiver', 'weekly', v_weekly_cycle, v_cost_stars * p_quantity)
      on conflict (user_id, type, cycle, cycle_key) do update set value = gift_leaderboards.value + (v_cost_stars * p_quantity), updated_at = now();

      insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value)
      values (v_receiver_id, 'receiver', 'monthly', v_monthly_cycle, v_cost_stars * p_quantity)
      on conflict (user_id, type, cycle, cycle_key) do update set value = gift_leaderboards.value + (v_cost_stars * p_quantity), updated_at = now();

      insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value)
      values (v_receiver_id, 'receiver', 'lifetime', v_lifetime_cycle, v_cost_stars * p_quantity)
      on conflict (user_id, type, cycle, cycle_key) do update set value = gift_leaderboards.value + (v_cost_stars * p_quantity), updated_at = now();
    end if;

    insert into public.gift_notifications (user_id, title, content)
    values (v_receiver_id, 'Received Gift! 🎁', v_sender_name || ' sent you ' || p_quantity || 'x ' || v_gift_record.name || ' (' || (v_cost_stars * p_quantity) || '★)');
  end loop;

  insert into public.gift_statistics (user_id, stars_sent_lifetime, highest_combo, favorite_gift_id)
  values (v_sender_id, v_total_stars_cost, p_combo_count, p_gift_id)
  on conflict (user_id) do update set
    stars_sent_lifetime = gift_statistics.stars_sent_lifetime + v_total_stars_cost,
    highest_combo = greatest(gift_statistics.highest_combo, p_combo_count),
    favorite_gift_id = EXCLUDED.favorite_gift_id,
    updated_at = now();

  -- Anti-abuse sender leaderboard checks
  if not (v_is_self_gift and coalesce(v_exclude_self_gifts_from_leaderboards, true)) then
    insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value)
    values (v_sender_id, 'gifter', 'daily', v_daily_cycle, v_total_stars_cost)
    on conflict (user_id, type, cycle, cycle_key) do update set value = gift_leaderboards.value + v_total_stars_cost, updated_at = now();

    insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value)
    values (v_sender_id, 'gifter', 'weekly', v_weekly_cycle, v_total_stars_cost)
    on conflict (user_id, type, cycle, cycle_key) do update set value = gift_leaderboards.value + v_total_stars_cost, updated_at = now();

    insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value)
    values (v_sender_id, 'gifter', 'monthly', v_monthly_cycle, v_total_stars_cost)
    on conflict (user_id, type, cycle, cycle_key) do update set value = gift_leaderboards.value + v_total_stars_cost, updated_at = now();

    insert into public.gift_leaderboards (user_id, type, cycle, cycle_key, value)
    values (v_sender_id, 'gifter', 'lifetime', v_lifetime_cycle, v_total_stars_cost)
    on conflict (user_id, type, cycle, cycle_key) do update set value = gift_leaderboards.value + v_total_stars_cost, updated_at = now();
  end if;

  update public.rooms
  set total_room_gifts = total_room_gifts + (p_quantity * v_receivers_count),
      today_room_gifts = today_room_gifts + (p_quantity * v_receivers_count),
      total_room_stars = total_room_stars + v_total_stars_cost,
      today_room_stars = today_room_stars + v_total_stars_cost,
      updated_at = now()
  where id = p_room_id;

  -- Create clean formatted message body
  declare
    v_message_content text;
  begin
    if v_is_self_gift then
      if p_quantity > 1 then
        v_message_content := v_sender_name || ' self-gifted ' || p_quantity || '× ' || v_gift_record.icon || ' ' || v_gift_record.name || ' to themselves';
      else
        v_message_content := v_sender_name || ' self-gifted ' || v_gift_record.icon || ' ' || v_gift_record.name || ' to themselves';
      end if;
    else
      if v_receivers_count = 1 then
        if p_quantity > 1 then
          v_message_content := v_sender_name || ' sent ' || p_quantity || '× ' || v_gift_record.icon || ' ' || v_gift_record.name || ' to ' || v_receivers_names_list;
        else
          v_message_content := v_sender_name || ' sent ' || v_gift_record.icon || ' ' || v_gift_record.name || ' to ' || v_receivers_names_list;
        end if;
      elsif v_receivers_count >= 10 then 
        v_message_content := v_sender_name || ' gifted everyone with ' || v_gift_record.icon || ' ' || v_gift_record.name;
      else
        v_message_content := v_sender_name || ' sent ' || v_gift_record.icon || ' ' || v_gift_record.name || ' to ' || v_receivers_count || ' selected users';
      end if;
    end if;

    insert into public.room_messages (
      room_id, sender_id, content, message_type, metadata
    ) values (
      p_room_id, v_sender_id,
      v_message_content,
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
        'is_self_gift', v_is_self_gift
      )
    );
  end;

  -- Anti-abuse XP milestone check
  if not (v_is_self_gift and coalesce(v_exclude_self_gifts_from_xp, true)) then
    begin
      perform public.process_xp_event('gift_sent', jsonb_build_object('recipient_id', p_receiver_ids[1], 'gift_id', p_gift_id::text));
    exception when others then
      null;
    end;
  end if;

  return jsonb_build_object(
    'success', true,
    'remaining_balance', v_sender_balance - v_total_coins_cost,
    'total_stars_cost', v_total_stars_cost,
    'magic_result', v_magic_result
  );
end;
$$ language plpgsql security definer;


-- 4. Patch public.gift_vault_item to permit self-gifting based on config
create or replace function public.gift_vault_item(p_item_id uuid, p_receiver_id uuid)
returns jsonb as $$
declare
  v_item record;
  v_asset record;
  v_allow_self_gifting boolean;
  v_exclude_self_gifts_from_xp boolean;
begin
  -- Load settings
  select allow_self_gifting, exclude_self_gifts_from_xp
  into v_allow_self_gifting, v_exclude_self_gifts_from_xp
  from public.gifting_settings where id = 'global';

  -- Validate receiver exists
  if not exists (select 1 from public.profiles where id = p_receiver_id) then
    return jsonb_build_object('success', false, 'reason', 'Receiver profile not found.');
  end if;

  -- Block gifting to self if disabled
  if p_receiver_id = auth.uid() and coalesce(v_allow_self_gifting, true) = false then
    return jsonb_build_object('success', false, 'reason', 'Self-gifting is disabled by administrator.');
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
  values (auth.uid(), p_item_id, 'Gifted', 1, 'Gifted ' || v_asset.display_name || ' to user ' || p_receiver_id);

  -- 2. Add quantity to Receiver
  insert into public.vault_items (user_id, asset_id, quantity, status)
  values (p_receiver_id, v_asset.id, 1, 'Active')
  on conflict (user_id, asset_id) do update set 
    quantity = vault_items.quantity + 1,
    status = 'Active';

  -- Log receiver history
  insert into public.vault_item_history (user_id, vault_item_id, action_type, quantity, details)
  values (p_receiver_id, p_item_id, 'Received', 1, 'Received ' || v_asset.display_name || ' as a gift from user ' || auth.uid());

  -- 3. Trigger progression points if NOT self gift
  if not (p_receiver_id = auth.uid() and coalesce(v_exclude_self_gifts_from_xp, true)) then
    begin
      perform public.process_xp_event('gift_sent', jsonb_build_object('recipient_id', p_receiver_id, 'gift_id', p_item_id::text));
    exception when others then
      null;
    end;
  end if;

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;
