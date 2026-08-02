-- 202607250003_add_payment_id_and_idempotency.sql

-- 1. Add columns to public.purchases
alter table public.purchases
  add column if not exists payment_id text;

-- 2. Add columns to public.subscriptions
alter table public.subscriptions
  add column if not exists payment_id text;

-- 3. Add columns to public.user_vip
alter table public.user_vip
  add column if not exists is_vip boolean default true,
  add column if not exists vip_level integer,
  add column if not exists purchase_date timestamp with time zone default now(),
  add column if not exists payment_id text,
  add column if not exists status text default 'active';

-- 4. Re-declare recompute_user_entitlements to propagate these new columns
create or replace function public.recompute_user_entitlements(p_user_id uuid)
returns void as $$
declare
  v_vip_sub record;
  v_novel_sub record;
  v_asset record;
  v_equip_row record;
  v_vip_level integer := 0;
  v_novel_level integer := 0;
  v_vip_expiry timestamp with time zone := null;
  v_novel_expiry timestamp with time zone := null;
  v_vip_payment_id text := null;
  v_vip_purchase_date timestamp with time zone := null;
  v_membership_assets jsonb := '{}'::jsonb;
  v_asset_type text;
begin
  -- 1. Authoritative subscription state
  select level, expiry_date, payment_id, purchase_date into v_vip_sub
  from public.subscriptions
  where user_id = p_user_id and membership_type = 'VIP' and status = 'Active' and expiry_date > now()
  order by level desc limit 1;
  if found then
    v_vip_level        := v_vip_sub.level;
    v_vip_expiry       := v_vip_sub.expiry_date;
    v_vip_payment_id   := v_vip_sub.payment_id;
    v_vip_purchase_date := v_vip_sub.purchase_date;
  end if;

  select level, expiry_date into v_novel_sub
  from public.subscriptions
  where user_id = p_user_id and membership_type = 'Novel' and status = 'Active' and expiry_date > now()
  order by level desc limit 1;
  if found then
    v_novel_level  := v_novel_sub.level;
    v_novel_expiry := v_novel_sub.expiry_date;
  end if;

  -- 2. Expire stale inventory items
  update public.inventory
  set status = 'Expired', is_equipped = false
  where user_id = p_user_id and expires_at is not null and expires_at <= now() and status = 'Active';

  -- 3. Revoke membership inventory when subscription is gone
  if v_vip_level = 0 then
    update public.inventory set status = 'Expired', is_equipped = false
    where user_id = p_user_id and purchase_source = 'VIP Membership' and status = 'Active';
  end if;

  if v_novel_level = 0 then
    update public.inventory set status = 'Expired', is_equipped = false
    where user_id = p_user_id and purchase_source = 'Novel Membership' and status = 'Active';
  end if;

  -- 4. Grant VIP entitlements
  if v_vip_level > 0 then
    for v_asset in
      select asset_id from public.cosmetic_assets
      where required_membership = 'VIP' and required_level <= v_vip_level and enabled = true
    loop
      insert into public.inventory (user_id, asset_id, purchase_source, purchase_date, expires_at, status)
      values (p_user_id, v_asset.asset_id, 'VIP Membership', now(), v_vip_expiry, 'Active')
      on conflict (user_id, asset_id) do update set expires_at = v_vip_expiry, status = 'Active';
    end loop;
  end if;

  -- 5. Grant Novel entitlements
  if v_novel_level > 0 then
    for v_asset in
      select asset_id from public.cosmetic_assets
      where required_membership = 'Novel' and required_level <= v_novel_level and enabled = true
    loop
      insert into public.inventory (user_id, asset_id, purchase_source, purchase_date, expires_at, status)
      values (p_user_id, v_asset.asset_id, 'Novel Membership', now(), v_novel_expiry, 'Active')
      on conflict (user_id, asset_id) do update set expires_at = v_novel_expiry, status = 'Active';
    end loop;
  end if;

  -- 6. Auto-Equip highest priority active asset per type
  for v_asset_type in
    select distinct type from public.cosmetic_assets where enabled = true
  loop
    select inv.id, ca.cdn_url into v_equip_row
    from public.inventory inv
    join public.cosmetic_assets ca on inv.asset_id = ca.asset_id
    where inv.user_id = p_user_id and ca.type = v_asset_type
      and inv.status = 'Active' and ca.enabled = true
    order by ca.priority desc, inv.purchase_date desc
    limit 1;

    if found then
      update public.inventory set is_equipped = true, last_equipped_at = now()
      where id = v_equip_row.id;
      update public.inventory set is_equipped = false
      where user_id = p_user_id and id <> v_equip_row.id
        and asset_id in (select asset_id from public.cosmetic_assets where type = v_asset_type);
      v_membership_assets := jsonb_set(v_membership_assets, array[v_asset_type], to_jsonb(v_equip_row.cdn_url));
    else
      update public.inventory set is_equipped = false
      where user_id = p_user_id
        and asset_id in (select asset_id from public.cosmetic_assets where type = v_asset_type);
    end if;
  end loop;

  -- 7. Write authoritative profile row
  update public.profiles
  set vip_level          = v_vip_level,
      vip_expiry         = v_vip_expiry,
      novel_level        = v_novel_level,
      novel_expiry       = v_novel_expiry,
      membership_assets  = v_membership_assets
  where id = p_user_id;

  -- 8. Sync compatibility tables
  if v_vip_level > 0 then
    insert into public.user_vip (user_id, level, start_date, expiry_date, is_active, is_vip, vip_level, purchase_date, payment_id, status)
    values (p_user_id, v_vip_level, coalesce(v_vip_purchase_date, now()), v_vip_expiry, true, true, v_vip_level, coalesce(v_vip_purchase_date, now()), v_vip_payment_id, 'active')
    on conflict (user_id) do update
    set level = greatest(user_vip.level, v_vip_level), expiry_date = greatest(user_vip.expiry_date, v_vip_expiry), is_active = true, is_vip = true, vip_level = greatest(user_vip.vip_level, v_vip_level), purchase_date = coalesce(v_vip_purchase_date, now()), payment_id = v_vip_payment_id, status = 'active';
  else
    update public.user_vip set is_active = false, is_vip = false, status = 'inactive' where user_id = p_user_id;
  end if;

  if v_novel_level > 0 then
    insert into public.user_novel (user_id, level, start_date, expiry_date, is_active)
    values (p_user_id, v_novel_level, now(), v_novel_expiry, true)
    on conflict (user_id) do update
    set level = greatest(user_novel.level, v_novel_level), expiry_date = greatest(user_novel.expiry_date, v_novel_expiry), is_active = true;
  else
    update public.user_novel set is_active = false where user_id = p_user_id;
  end if;

  -- 9. Rebuild tag system AFTER profiles.vip_level is committed
  perform public.rebuild_user_tag_system(p_user_id);
end;
$$ language plpgsql security definer set search_path = public;

-- 5. Update record_membership_purchase to support p_payment_id
create or replace function public.record_membership_purchase(
  p_user_id        uuid,
  p_product_name   text,
  p_category       text,
  p_amount         numeric,
  p_final_amount   numeric,
  p_payment_method text,
  p_duration       text,
  p_custom_expiry  timestamp with time zone default null,
  p_payment_id     text default null
)
returns boolean as $$
declare
  v_level         integer;
  v_days          integer;
  v_expiry        timestamp with time zone;
  v_wallet_coins  integer;
  v_price_coins   integer;
  v_old_expiry    timestamp with time zone;
begin
  -- Validate inputs
  if p_user_id is null or p_product_name is null or p_category is null then
    raise exception 'record_membership_purchase: invalid input params';
  end if;
  if p_category not in ('VIP','Novel') then
    raise exception 'record_membership_purchase: unsupported category %', p_category;
  end if;

  -- Idempotency check: if payment_id is provided, check if it already exists in purchases
  if p_payment_id is not null then
    if exists (select 1 from public.purchases where payment_id = p_payment_id) then
      return true;
    end if;
  end if;

  -- Parse level from product name
  v_level := coalesce(substring(p_product_name from '[0-9]+')::integer, 1);

  -- Determine expiry date (use custom if provided, otherwise calculate from duration)
  if p_custom_expiry is not null then
    v_expiry := p_custom_expiry;
  else
    v_days := case p_duration
      when '3 Days'  then 3
      when '7 Days'  then 7
      when '15 Days' then 15
      when '90 Days' then 90
      when '1 Year'  then 365
      else 30
    end;

    -- Extend existing expiry if active in subscriptions
    select expiry_date into v_old_expiry
    from public.subscriptions
    where user_id = p_user_id and membership_type = p_category and status = 'Active' and expiry_date > now();

    if v_old_expiry is not null then
      v_expiry := v_old_expiry + (v_days || ' days')::interval;
    else
      v_expiry := now() + (v_days || ' days')::interval;
    end if;
  end if;

  -- Gold Coins deduction
  if p_payment_method = 'Gold Coins Wallet' then
    v_price_coins := p_final_amount::integer;

    select coins_balance into v_wallet_coins
    from public.wallets
    where id = p_user_id
    for update;

    if v_wallet_coins is null then
      raise exception 'Wallet not found for user %', p_user_id;
    end if;
    if v_wallet_coins < v_price_coins then
      raise exception 'Insufficient Gold Coins: have %, need %', v_wallet_coins, v_price_coins;
    end if;

    update public.wallets
    set gold_coins    = gold_coins    - v_price_coins,
        coins_balance = coins_balance - v_price_coins
    where id = p_user_id;

    insert into public.wallet_transactions
      (wallet_id, amount, currency, type, status, details)
    values
      (p_user_id, v_price_coins, 'Gold Coins', 'Spend', 'Completed',
       'Purchased ' || p_product_name);
  end if;

  -- Record in purchase ledger
  insert into public.purchases
    (user_id, product_name, category, amount, final_amount, payment_method, status, duration, expiry_date, payment_id)
  values
    (p_user_id, p_product_name, p_category, p_amount, p_final_amount,
     p_payment_method, 'Success', p_duration, v_expiry, p_payment_id);

  -- Insert/update subscriptions table (never downgrade level, extend expiry date)
  if exists (select 1 from public.subscriptions where user_id = p_user_id and membership_type = p_category) then
    update public.subscriptions
    set level           = greatest(subscriptions.level, v_level),
        activation_date = now(),
        expiry_date     = greatest(subscriptions.expiry_date, v_expiry),
        status          = 'Active',
        payment_id      = p_payment_id
    where user_id = p_user_id and membership_type = p_category;
  else
    insert into public.subscriptions
      (user_id, membership_type, level, purchase_date, activation_date, expiry_date, auto_renewal, status, payment_id)
    values
      (p_user_id, p_category, v_level, now(), now(), v_expiry, true, 'Active', p_payment_id);
  end if;

  return true;
exception
  when others then
    raise;
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function public.record_membership_purchase(uuid, text, text, numeric, numeric, text, text, timestamp with time zone, text) to authenticated;
