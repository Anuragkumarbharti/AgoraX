-- 202608090001_fix_coin_purchase_entitlement_rpc.sql
-- Fix: Support Coins category in purchase_and_activate_rpc & record_membership_purchase

create or replace function public.purchase_and_activate_rpc(
  p_user_id        uuid,
  p_product_name   text,
  p_category       text,
  p_amount         numeric,
  p_final_amount   numeric,
  p_payment_method text,
  p_duration       text,
  p_payment_id     text default null,
  p_order_id       text default null
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_level       integer := 0;
  v_target_days integer := 30;
  v_old_level   integer := 0;
  v_old_expiry  timestamptz;
  v_new_expiry  timestamptz;
  v_frame_name  text;
  v_has_frame   boolean := false;
  v_coins       integer := 0;
begin
  if p_user_id is null or p_product_name is null or p_category is null then
    raise exception 'purchase_and_activate_rpc: missing required parameters';
  end if;

  -- Idempotency check
  if p_payment_id is not null and exists(
    select 1 from public.purchases where payment_id = p_payment_id and status = 'Success'
  ) then
    return jsonb_build_object('success', true, 'idempotent', true, 'product', p_product_name, 'category', p_category);
  end if;

  v_level := coalesce((regexp_match(p_product_name, E'(\\d+)'))[1]::integer, 1);

  v_target_days := case p_duration
    when '3 Days'    then 3   when '7 Days'    then 7
    when '15 Days'   then 15  when '30 Days'   then 30
    when '1 Month'   then 30  when '90 Days'   then 90
    when '3 Months'  then 90  when '6 Months'  then 180
    when '6 Month'   then 180 when '12 Months' then 365
    when '1 Year'    then 365 when 'Yearly'    then 365
    else 30
  end;

  -- Gold Coins deduction (if buying VIP/Novel using Gold Coins)
  if p_payment_method in ('Gold Coins', 'Gold Coins Wallet', 'Gold') then
    select coalesce(coins_balance,0) into v_coins
    from public.wallets where id = p_user_id for update;
    if v_coins is null then
      raise exception 'Wallet not found for user %', p_user_id;
    end if;
    if v_coins < p_final_amount::integer then
      raise exception 'Insufficient Gold Coins: have %, need %', v_coins, p_final_amount::integer;
    end if;
    update public.wallets
    set gold_coins    = gold_coins    - p_final_amount::integer,
        coins_balance = coins_balance - p_final_amount::integer
    where id = p_user_id;

    insert into public.wallet_transactions (wallet_id, amount, currency, type, status, details)
    values (p_user_id, p_final_amount::integer, 'Gold Coins', 'Purchase', 'Completed', 'Purchased ' || p_product_name);
  end if;

  -- Record purchase log
  insert into public.purchases
    (user_id, product_name, category, amount, final_amount, payment_method, status, duration, payment_id)
  values (p_user_id, p_product_name, p_category, p_amount, p_final_amount,
          p_payment_method, 'Success', p_duration, p_payment_id);

  if p_category = 'VIP' then
    select level, expiry_date into v_old_level, v_old_expiry
    from public.subscriptions
    where user_id = p_user_id and membership_type = 'VIP' and status = 'Active'
    order by level desc limit 1;
    v_old_level := coalesce(v_old_level, 0);

    if v_old_expiry is not null and v_old_expiry > now() then
      v_new_expiry := v_old_expiry + (v_target_days || ' days')::interval;
    else
      v_new_expiry := now() + (v_target_days || ' days')::interval;
    end if;

    v_frame_name := case v_level
      when 1 then 'Royal Frame'            when 2 then 'Neon Frame (Animated)'
      when 3 then 'Gold Glow Frame'        when 4 then 'Diamond Frame'
      when 5 then 'Crystal Cyan Frame'     when 6 then 'Rainbow Frame (Animated)'
      when 7 then 'Royal Crown (Animated)' else 'Royal Frame' end;

    -- Safe update/insert subscriptions
    if exists (select 1 from public.subscriptions where user_id = p_user_id and membership_type = 'VIP') then
      update public.subscriptions
      set level           = greatest(subscriptions.level, v_level),
          activation_date = now(),
          expiry_date     = greatest(subscriptions.expiry_date, v_new_expiry),
          status          = 'Active',
          payment_id      = p_payment_id
      where user_id = p_user_id and membership_type = 'VIP';
    else
      insert into public.subscriptions
        (user_id, membership_type, level, purchase_date, activation_date, expiry_date, auto_renewal, status, payment_id)
      values (p_user_id, 'VIP', v_level, now(), now(), v_new_expiry, true, 'Active', p_payment_id);
    end if;

    -- Sync profile VIP level & expiry
    update public.profiles
    set vip_level  = greatest(coalesce(vip_level, 0), v_level),
        vip_expiry = greatest(coalesce(vip_expiry, now()), v_new_expiry)
    where id = p_user_id;

    -- Add frame to inventory safely
    if not exists (select 1 from public.user_customizations where user_id = p_user_id and type = 'Avatar Frame' and name = v_frame_name) then
      insert into public.user_customizations (user_id, type, name, is_equipped)
      values (p_user_id, 'Avatar Frame', v_frame_name, false);
    end if;

    select exists(
      select 1 from public.user_customizations
      where user_id = p_user_id and type = 'Avatar Frame'
        and is_equipped = true and name not in ('Normal','None')
    ) into v_has_frame;

    if not v_has_frame then
      update public.user_customizations set is_equipped = false where user_id = p_user_id and type = 'Avatar Frame';
      if exists (select 1 from public.user_customizations where user_id = p_user_id and type = 'Avatar Frame' and name = v_frame_name) then
        update public.user_customizations set is_equipped = true where user_id = p_user_id and type = 'Avatar Frame' and name = v_frame_name;
      else
        insert into public.user_customizations (user_id, type, name, is_equipped) values (p_user_id, 'Avatar Frame', v_frame_name, true);
      end if;
      update public.profiles set avatar_frame = v_frame_name where id = p_user_id;
    end if;

  elsif p_category = 'Novel' then
    select level, expiry_date into v_old_level, v_old_expiry
    from public.subscriptions
    where user_id = p_user_id and membership_type = 'Novel' and status = 'Active'
    order by level desc limit 1;

    if v_old_expiry is not null and v_old_expiry > now() then
      v_new_expiry := v_old_expiry + (v_target_days || ' days')::interval;
    else
      v_new_expiry := now() + (v_target_days || ' days')::interval;
    end if;

    if exists (select 1 from public.subscriptions where user_id = p_user_id and membership_type = 'Novel') then
      update public.subscriptions
      set level           = greatest(subscriptions.level, v_level),
          activation_date = now(),
          expiry_date     = greatest(subscriptions.expiry_date, v_new_expiry),
          status          = 'Active',
          payment_id      = p_payment_id
      where user_id = p_user_id and membership_type = 'Novel';
    else
      insert into public.subscriptions
        (user_id, membership_type, level, purchase_date, activation_date, expiry_date, auto_renewal, status, payment_id)
      values (p_user_id, 'Novel', v_level, now(), now(), v_new_expiry, true, 'Active', p_payment_id);
    end if;

    update public.profiles
    set novel_level  = greatest(coalesce(novel_level, 0), v_level),
        novel_expiry = greatest(coalesce(novel_expiry, now()), v_new_expiry)
    where id = p_user_id;

  elsif p_category = 'Coins' then
    -- Credit Gold Coins to user's wallet
    v_coins := coalesce((regexp_match(p_product_name, E'(\\d+)'))[1]::integer, (p_final_amount * 0.50)::integer);
    if v_coins <= 0 then
      v_coins := (p_final_amount * 0.50)::integer;
    end if;

    insert into public.wallets (id, gold_coins, coins_balance, silver_coins, withdrawable_balance)
    values (p_user_id, v_coins, v_coins, 0, 0.0)
    on conflict (id) do update
    set gold_coins = coalesce(public.wallets.gold_coins, 0) + v_coins,
        coins_balance = coalesce(public.wallets.coins_balance, 0) + v_coins;

    insert into public.wallet_transactions (wallet_id, amount, currency, type, status, details)
    values (p_user_id, v_coins, 'Gold Coins', 'Recharge', 'Completed', 'Purchased ' || p_product_name);
  end if;

  perform public.recompute_user_entitlements(p_user_id);

  return jsonb_build_object(
    'success', true,
    'level', v_level,
    'expiry', v_new_expiry,
    'frame_name', v_frame_name,
    'coins_added', v_coins
  );
exception when others then
  raise;
end;
$fn$;

grant execute on function public.purchase_and_activate_rpc(uuid,text,text,numeric,numeric,text,text,text,text) to authenticated, service_role;
