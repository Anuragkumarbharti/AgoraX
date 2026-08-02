-- 202607250004_create_payments_and_verify_rpc.sql

-- Enable pgcrypto for hmac signature verification
create extension if not exists pgcrypto;

-- 1. Create payments table
create table if not exists public.payments (
  payment_id text primary key,
  order_id text not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  amount numeric not null,
  vip_plan text not null,
  status text not null, -- 'Success', 'Failed'
  purchase_date timestamp with time zone default now() not null,
  gateway_response jsonb
);

-- Enable RLS on payments
alter table public.payments enable row level security;

-- Setup RLS policy for select
create policy "Allow select payments for self and admins" on public.payments
  for select using (auth.uid() = user_id or exists (select 1 from public.admins where id = auth.uid()));

-- 2. Create verify_and_activate_vip_rpc function
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
declare
  v_secret_key      text := 'ehrQ4edUdNzEZqtTE334Lcsf'; -- razorpay test secret key
  v_computed        text;
  v_success         boolean;
begin
  -- Validate inputs
  if p_order_id is null or p_payment_id is null or p_signature is null or p_user_id is null then
    raise exception 'verify_and_activate_vip_rpc: missing required inputs';
  end if;

  -- Compute expected signature using extensions.hmac (HMAC-SHA256) with schema-resilient fallbacks
  begin
    v_computed := encode(extensions.hmac((p_order_id || '|' || p_payment_id)::bytea, v_secret_key::bytea, 'sha256'), 'hex');
  exception when others then
    begin
      v_computed := encode(public.hmac((p_order_id || '|' || p_payment_id)::bytea, v_secret_key::bytea, 'sha256'), 'hex');
    exception when others then
      v_computed := encode(hmac((p_order_id || '|' || p_payment_id)::bytea, v_secret_key::bytea, 'sha256'), 'hex');
    end;
  end;

  -- Compare signature (case-insensitive for safety)
  if lower(v_computed) <> lower(p_signature) then
    raise exception 'Razorpay signature mismatch: computed %, got %', v_computed, p_signature;
  end if;

  -- Record the purchase and update subscription inside this single transaction
  v_success := public.record_membership_purchase(
    p_user_id,
    p_product,
    'VIP',
    p_amount,
    p_amount,
    'Razorpay Gateway',
    p_duration,
    null,
    p_payment_id
  );

  -- Insert payment record into payments table
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
  )
  on conflict (payment_id) do nothing;

  return true;
exception
  when others then
    raise;
end;
$$ language plpgsql security definer set search_path = public, extensions;

-- 3. Create purchase_item_with_coins_rpc function
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

  -- 1. Lock user's wallet row to prevent double spending
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

  -- 3. Auto-sync gold_coins if it is out of sync/less than coins_balance
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

-- Grants
grant execute on function public.verify_and_activate_vip_rpc(text, text, text, text, text, numeric, uuid) to authenticated;
grant execute on function public.purchase_item_with_coins_rpc(uuid, text, text, int, text) to authenticated;

-- 4. Rebuild on_profile_vip_novel_update trigger function to avoid ON CONFLICT on subscriptions
create or replace function public.on_profile_vip_novel_update()
returns trigger as $$
begin
  -- Guard: only fire when admin/backend directly sets vip_level or novel_level
  -- (purchases go through subscriptions trigger, not here)
  if (old.vip_level is distinct from new.vip_level) or (old.novel_level is distinct from new.novel_level) then

    -- Sync subscription table so the engine reads the right level
    if new.vip_level > 0 then
      if exists (select 1 from public.subscriptions where user_id = new.id and membership_type = 'VIP') then
        update public.subscriptions
        set level       = new.vip_level,
            expiry_date = coalesce(new.vip_expiry, now() + interval '30 days'),
            status      = 'Active'
        where user_id = new.id and membership_type = 'VIP';
      else
        insert into public.subscriptions (user_id, membership_type, level, expiry_date, status)
        values (new.id, 'VIP', new.vip_level, coalesce(new.vip_expiry, now() + interval '30 days'), 'Active');
      end if;
    else
      update public.subscriptions
      set status = 'Expired'
      where user_id = new.id and membership_type = 'VIP';
    end if;

    if new.novel_level > 0 then
      if exists (select 1 from public.subscriptions where user_id = new.id and membership_type = 'Novel') then
        update public.subscriptions
        set level       = new.novel_level,
            expiry_date = coalesce(new.novel_expiry, now() + interval '30 days'),
            status      = 'Active'
        where user_id = new.id and membership_type = 'Novel';
      else
        insert into public.subscriptions (user_id, membership_type, level, expiry_date, status)
        values (new.id, 'Novel', new.novel_level, coalesce(new.novel_expiry, now() + interval '30 days'), 'Active');
      end if;
    else
      update public.subscriptions
      set status = 'Expired'
      where user_id = new.id and membership_type = 'Novel';
    end if;

    -- Run entitlements AFTER the profile row is committed (AFTER trigger)
    perform public.recompute_user_entitlements(new.id);
  end if;
  return new;
end;
$$ language plpgsql security definer;
