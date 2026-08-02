-- 202607250001_update_record_membership_purchase_custom_expiry.sql
-- Update record_membership_purchase to support p_custom_expiry for client-calculated stacked expiry dates

create or replace function public.record_membership_purchase(
  p_user_id       uuid,
  p_product_name  text,
  p_category      text,
  p_amount        numeric,
  p_final_amount  numeric,
  p_payment_method text,
  p_duration      text,
  p_custom_expiry  timestamp with time zone default null
)
returns boolean as $$
declare
  v_level         integer;
  v_days          integer;
  v_expiry        timestamp with time zone;
  v_wallet_coins  integer;
  v_price_coins   integer;
begin
  -- Validate inputs
  if p_user_id is null or p_product_name is null or p_category is null then
    raise exception 'record_membership_purchase: invalid input params';
  end if;
  if p_category not in ('VIP','Novel') then
    raise exception 'record_membership_purchase: unsupported category %', p_category;
  end if;

  -- Parse level from product name (e.g. "VIP Level 2" → 2)
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
    v_expiry := now() + (v_days || ' days')::interval;
  end if;

  -- Gold Coins deduction (atomic, inside this transaction)
  if p_payment_method = 'Gold Coins Wallet' then
    v_price_coins := p_final_amount::integer;

    select gold_coins into v_wallet_coins
    from public.wallets
    where id = p_user_id
    for update;                             -- row-lock prevents double-spend

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
      (p_user_id, v_price_coins, 'Gold Coins', 'Purchase', 'Completed',
       'Purchased ' || p_product_name);
  end if;

  -- Record in purchase ledger
  insert into public.purchases
    (user_id, product_name, category, amount, final_amount, payment_method, status, duration, expiry_date)
  values
    (p_user_id, p_product_name, p_category, p_amount, p_final_amount,
     p_payment_method, 'Success', p_duration, v_expiry);

  -- Insert/update subscriptions table
  insert into public.subscriptions
    (user_id, membership_type, level, purchase_date, activation_date, expiry_date, auto_renewal, status)
  values
    (p_user_id, p_category, v_level, now(), now(), v_expiry, true, 'Active')
  on conflict (user_id, membership_type) do update
  set level           = v_level,
      activation_date = now(),
      expiry_date     = v_expiry,
      status          = 'Active';

  return true;
exception
  when others then
    raise; -- bubble up → full transaction rollback, no partial purchase
end;
$$ language plpgsql security definer;

grant execute on function public.record_membership_purchase(uuid, text, text, numeric, numeric, text, text, timestamp with time zone) to authenticated;
