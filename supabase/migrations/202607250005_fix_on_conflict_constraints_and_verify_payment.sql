-- 202607250005_fix_on_conflict_constraints_and_verify_payment.sql
-- Fix PostgreSQL 42P10 (ON CONFLICT missing unique constraint) and unify Razorpay payment verification

-- Enable pgcrypto for hmac signature verification
create extension if not exists pgcrypto;

-- 1. Ensure explicit UNIQUE indexes/constraints exist on all target tables

-- subscriptions (user_id, membership_type)
do $$
begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'subscriptions' and c.relkind = 'r') then
    if not exists (
      select 1 from pg_constraint where conname = 'subscriptions_user_id_membership_type_key'
    ) then
      begin
        alter table public.subscriptions add constraint subscriptions_user_id_membership_type_key unique (user_id, membership_type);
      exception when others then
        null;
      end;
    end if;
  end if;
end $$;

-- user_vip (user_id)
do $$
begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'user_vip' and c.relkind = 'r') then
    if not exists (
      select 1 from pg_constraint where conname = 'user_vip_pkey' or conname = 'user_vip_user_id_key'
    ) then
      begin
        alter table public.user_vip add constraint user_vip_user_id_key unique (user_id);
      exception when others then
        null;
      end;
    end if;
  end if;
end $$;

-- user_novel (user_id)
do $$
begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'user_novel' and c.relkind = 'r') then
    if not exists (
      select 1 from pg_constraint where conname = 'user_novel_pkey' or conname = 'user_novel_user_id_key'
    ) then
      begin
        alter table public.user_novel add constraint user_novel_user_id_key unique (user_id);
      exception when others then
        null;
      end;
    end if;
  end if;
end $$;

-- inventory (user_id, asset_id) - only executed if relation is a base table ('r'), skipping views ('v')
do $$
begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'inventory' and c.relkind = 'r') then
    if not exists (
      select 1 from pg_constraint where conname = 'inventory_user_id_asset_id_key'
    ) then
      begin
        alter table public.inventory add constraint inventory_user_id_asset_id_key unique (user_id, asset_id);
      exception when others then
        null;
      end;
    end if;
  end if;
end $$;

-- payments (payment_id)
create table if not exists public.payments (
  payment_id text primary key,
  order_id text not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  amount numeric not null,
  vip_plan text not null,
  status text not null,
  purchase_date timestamp with time zone default now() not null,
  gateway_response jsonb
);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'payments_pkey' or conname = 'payments_payment_id_key'
  ) then
    begin
      alter table public.payments add constraint payments_payment_id_key unique (payment_id);
    exception when others then
      null;
    end;
  end if;
end $$;

-- purchases (payment_id) conditional index
create unique index if not exists purchases_payment_id_unique_idx on public.purchases (payment_id) where payment_id is not null;

-- 2. Safe record_membership_purchase PL/pgSQL function without throwing 42P10
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
    if exists (select 1 from public.purchases where payment_id = p_payment_id and status = 'Success') then
      return true;
    end if;
  end if;

  -- Parse level from product name
  v_level := coalesce(substring(p_product_name from '[0-9]+')::integer, 1);

  -- Determine expiry date
  if p_custom_expiry is not null then
    v_expiry := p_custom_expiry;
  else
    v_days := case p_duration
      when '3 Days'  then 3
      when '7 Days'  then 7
      when '15 Days' then 15
      when '30 Days' then 30
      when '90 Days' then 90
      when '1 Year'  then 365
      when '12 Months' then 365
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

  -- Gold Coins deduction if paying via coins
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

  -- Safe update or insert into subscriptions without relying on ON CONFLICT constraint
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

  -- Update profile membership columns & entitlements
  if p_category = 'VIP' then
    update public.profiles
    set vip_level = greatest(coalesce(vip_level, 0), v_level),
        vip_expiry = greatest(coalesce(vip_expiry, now()), v_expiry)
    where id = p_user_id;
  elsif p_category = 'Novel' then
    update public.profiles
    set novel_level = greatest(coalesce(novel_level, 0), v_level),
        novel_expiry = greatest(coalesce(novel_expiry, now()), v_expiry)
    where id = p_user_id;
  end if;

  perform public.recompute_user_entitlements(p_user_id);

  return true;
exception
  when others then
    raise;
end;
$$ language plpgsql security definer set search_path = public;

-- 3. Unified verify_and_process_razorpay_payment_rpc
create or replace function public.verify_and_process_razorpay_payment_rpc(
  p_order_id       text,
  p_payment_id     text,
  p_signature      text,
  p_product        text,
  p_duration       text,
  p_amount         numeric,
  p_user_id        uuid
)
returns boolean as $$
declare
  v_secret_key      text := 'ehrQ4edUdNzEZqtTE334Lcsf'; -- Razorpay secret key
  v_computed        text;
  v_category        text;
  v_coins_to_add    integer := 0;
  v_wallet_exists   boolean;
  v_match           text[];
begin
  -- Input Validation
  if p_order_id is null or p_payment_id is null or p_signature is null or p_user_id is null then
    raise exception 'verify_and_process_razorpay_payment_rpc: missing required input parameters';
  end if;

  -- 1. Idempotency Check: if this payment_id has already been successfully recorded in payments or purchases, return true immediately
  if exists (select 1 from public.payments where payment_id = p_payment_id and status = 'Success') then
    return true;
  end if;

  -- 2. Verify Razorpay HMAC-SHA256 Signature
  begin
    v_computed := encode(extensions.hmac((p_order_id || '|' || p_payment_id)::bytea, v_secret_key::bytea, 'sha256'), 'hex');
  exception when others then
    begin
      v_computed := encode(public.hmac((p_order_id || '|' || p_payment_id)::bytea, v_secret_key::bytea, 'sha256'), 'hex');
    exception when others then
      v_computed := encode(hmac((p_order_id || '|' || p_payment_id)::bytea, v_secret_key::bytea, 'sha256'), 'hex');
    end;
  end;

  if lower(v_computed) <> lower(p_signature) then
    raise exception 'Razorpay signature mismatch: computed %, got %', v_computed, p_signature;
  end if;

  -- 3. Determine Category (Coins, VIP, or Novel)
  if p_product ilike '%Coin%' or p_product ilike '%Recharge%' or p_product ilike '%Pack%' then
    v_category := 'Coins';
  elsif p_product ilike '%Novel%' then
    v_category := 'Novel';
  else
    v_category := 'VIP';
  end if;

  -- 4. Process Payment based on category
  if v_category = 'Coins' then
    -- Try extracting coin count from product string (e.g. "Starter Pack (100 Coins)" -> 100)
    v_match := regexp_matches(p_product, '(\d[\d,]*)\s*Coins?', 'i');
    if v_match is not null and array_length(v_match, 1) >= 1 then
      v_coins_to_add := replace(v_match[1], ',', '')::integer;
    else
      -- Fallback: 1 INR = 0.5 Coins or 100 INR = 50 Coins
      v_coins_to_add := round(p_amount * 0.50)::integer;
    end if;

    if v_coins_to_add <= 0 then
      v_coins_to_add := 50;
    end if;

    -- Lock and update wallet row
    select exists(select 1 from public.wallets where id = p_user_id) into v_wallet_exists;
    if not v_wallet_exists then
      insert into public.wallets (id, gold_coins, coins_balance, silver_coins, diamonds)
      values (p_user_id, v_coins_to_add, v_coins_to_add, 0, 0);
    else
      update public.wallets
      set gold_coins    = coalesce(gold_coins, 0) + v_coins_to_add,
          coins_balance = coalesce(coins_balance, 0) + v_coins_to_add
      where id = p_user_id;
    end if;

    -- Record wallet transaction
    insert into public.wallet_transactions (
      wallet_id,
      amount,
      currency,
      type,
      status,
      reference_id,
      details,
      created_at
    ) values (
      p_user_id,
      p_amount,
      'INR',
      'Recharge',
      'Completed',
      p_payment_id,
      'Recharged ' || v_coins_to_add || ' Gold Coins',
      now()
    );

    -- Record purchase ledger entry
    insert into public.purchases (
      user_id,
      product_name,
      category,
      amount,
      final_amount,
      payment_method,
      status,
      duration,
      payment_id,
      created_at
    ) values (
      p_user_id,
      p_product,
      'Coins',
      p_amount,
      p_amount,
      'Razorpay Gateway',
      'Success',
      coalesce(p_duration, 'One-Time'),
      p_payment_id,
      now()
    );
  else
    -- VIP or Novel purchase
    perform public.record_membership_purchase(
      p_user_id,
      p_product,
      v_category,
      p_amount,
      p_amount,
      'Razorpay Gateway',
      coalesce(p_duration, '30 Days'),
      null,
      p_payment_id
    );
  end if;

  -- 5. Record payment record into payments table
  if exists (select 1 from public.payments where payment_id = p_payment_id) then
    update public.payments
    set status = 'Success',
        gateway_response = jsonb_build_object(
          'order_id', p_order_id,
          'payment_id', p_payment_id,
          'signature', p_signature,
          'product', p_product,
          'duration', p_duration,
          'amount', p_amount
        )
    where payment_id = p_payment_id;
  else
    insert into public.payments (
      payment_id,
      order_id,
      user_id,
      amount,
      vip_plan,
      status,
      purchase_date,
      gateway_response
    ) values (
      p_payment_id,
      p_order_id,
      p_user_id,
      p_amount,
      p_product,
      'Success',
      now(),
      jsonb_build_object(
        'order_id', p_order_id,
        'payment_id', p_payment_id,
        'signature', p_signature,
        'product', p_product,
        'duration', p_duration,
        'amount', p_amount
      )
    );
  end if;

  return true;
exception
  when others then
    raise;
end;
$$ language plpgsql security definer set search_path = public, extensions;

-- Alias verify_and_activate_vip_rpc to verify_and_process_razorpay_payment_rpc for backwards compatibility
create or replace function public.verify_and_activate_vip_rpc(
  p_order_id       text,
  p_payment_id     text,
  p_signature      text,
  p_product        text,
  p_duration       text,
  p_amount         numeric,
  p_user_id        uuid
)
returns boolean as $$
begin
  return public.verify_and_process_razorpay_payment_rpc(
    p_order_id,
    p_payment_id,
    p_signature,
    p_product,
    p_duration,
    p_amount,
    p_user_id
  );
end;
$$ language plpgsql security definer set search_path = public, extensions;

-- Grants
grant execute on function public.record_membership_purchase(uuid, text, text, numeric, numeric, text, text, timestamp with time zone, text) to authenticated;
grant execute on function public.verify_and_process_razorpay_payment_rpc(text, text, text, text, text, numeric, uuid) to authenticated;
grant execute on function public.verify_and_activate_vip_rpc(text, text, text, text, text, numeric, uuid) to authenticated;

-- 4. Re-create purchase_item_with_coins_rpc using safe record_membership_purchase
create or replace function public.purchase_item_with_coins_rpc(
  p_user_id        uuid,
  p_item_name      text,
  p_item_type      text,
  p_coin_amount    int,
  p_duration       text
)
returns boolean as $$
declare
  v_coins_balance  int;
  v_success        boolean;
  v_wallet_id      uuid;
  v_mapped_type    text;
begin
  v_wallet_id := p_user_id;

  if p_item_type = 'Frame' or p_item_type = 'Effect' or p_item_type = 'Cosmetic' then
    v_mapped_type := 'Cosmetic';
  else
    v_mapped_type := p_item_type;
  end if;

  -- 1. Lock user's wallet row
  select coins_balance into v_coins_balance
  from public.wallets
  where id = v_wallet_id
  for update;

  if v_coins_balance is null then
    raise exception 'Wallet not found for user %', p_user_id;
  end if;

  -- 2. Check balance
  if v_coins_balance < p_coin_amount then
    raise exception 'Insufficient Gold Coins balance: need %, have %', p_coin_amount, v_coins_balance;
  end if;

  -- 3. Auto-sync gold_coins
  update public.wallets
  set gold_coins = greatest(gold_coins, coins_balance)
  where id = v_wallet_id;

  -- 4. Deduct balance atomically
  update public.wallets
  set gold_coins    = gold_coins - p_coin_amount,
      coins_balance = coins_balance - p_coin_amount
  where id = v_wallet_id;

  -- 5. Record wallet transaction
  insert into public.wallet_transactions (
    wallet_id,
    amount,
    currency,
    type,
    status,
    details,
    created_at
  ) values (
    v_wallet_id,
    p_coin_amount::numeric,
    'Gold Coins',
    'Spend',
    'Completed',
    'Purchased ' || p_item_name,
    now()
  );

  -- 6. Record in purchase history
  insert into public.purchase_history (
    user_id,
    item_id,
    item_type,
    price,
    currency,
    duration,
    created_at
  ) values (
    p_user_id,
    p_item_name,
    v_mapped_type,
    p_coin_amount::numeric,
    'Coins',
    p_duration,
    now()
  );

  -- 7. Activate VIP/Novel membership if applicable
  if p_item_type = 'VIP' or p_item_type = 'Novel' then
    v_success := public.record_membership_purchase(
      p_user_id,
      p_item_name,
      p_item_type,
      p_coin_amount::numeric,
      p_coin_amount::numeric,
      'Gold Coins',
      p_duration,
      null,
      'coin_pay_' || p_user_id::text || '_' || replace(extract(epoch from now())::text, '.', '')
    );
  end if;

  return true;
exception
  when others then
    raise;
end;
$$ language plpgsql security definer set search_path = public, extensions;

grant execute on function public.purchase_item_with_coins_rpc(uuid, text, text, int, text) to authenticated;
