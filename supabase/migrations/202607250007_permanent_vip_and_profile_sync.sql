-- 202607250007_permanent_vip_and_profile_sync.sql
-- Comprehensive Permanent VIP Persistence, Audit Logging, Single Transaction RPCs, and Entitlement Synchronization

-- 1. Create audit log table for purchase and equipment actions
create table if not exists public.vip_audit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  action text not null, -- 'VIP_PURCHASE', 'VIP_RENEWAL', 'VIP_UPGRADE', 'VIP_EXPIRED', 'EQUIP_ITEM', 'UNEQUIP_ITEM'
  category text not null,
  item_name text,
  details jsonb,
  created_at timestamp with time zone default now() not null
);

create index if not exists idx_vip_audit_logs_user_id on public.vip_audit_logs(user_id);
create index if not exists idx_vip_audit_logs_action on public.vip_audit_logs(action);

-- Enable RLS on vip_audit_logs
alter table public.vip_audit_logs enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'vip_audit_logs' and policyname = 'Users can view own audit logs'
  ) then
    create policy "Users can view own audit logs" on public.vip_audit_logs
      for select using (auth.uid() = user_id);
  end if;
end $$;

-- 2. Database Constraint: Ensure only one active equipped item per category per user
do $$
begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'user_customizations' and c.relkind = 'r') then
    if not exists (
      select 1 from pg_index i join pg_class c on c.oid = i.indexrelid where c.relname = 'idx_user_customizations_single_equipped'
    ) then
      create unique index idx_user_customizations_single_equipped on public.user_customizations (user_id, type) where is_equipped = true;
    end if;
  end if;
end $$;

-- 3. Server Expiry Guard: Check and clean expired memberships using server time now()
create or replace function public.check_and_clean_expired_memberships()
returns void as $$
declare
  r record;
begin
  -- 1. Check expired VIP subscriptions
  for r in
    select id, user_id, level, expiry_date
    from public.subscriptions
    where membership_type = 'VIP'
      and status = 'Active'
      and expiry_date <= now()
  loop
    -- Update subscription status
    update public.subscriptions
    set status = 'Expired'
    where id = r.id;

    -- Update profile VIP level if current expiry is past
    update public.profiles
    set vip_level = 0
    where id = r.user_id
      and (vip_expiry is null or vip_expiry <= now());

    -- Unequip VIP avatar frames if expired
    update public.user_customizations
    set is_equipped = false
    where user_id = r.user_id
      and type = 'Avatar Frame'
      and name ilike 'VIP%';

    -- Audit log
    insert into public.vip_audit_logs (user_id, action, category, item_name, details)
    values (r.user_id, 'VIP_EXPIRED', 'VIP', 'VIP Level ' || r.level, jsonb_build_object('expired_at', r.expiry_date, 'server_time', now()));

    -- Rebuild identity tags
    perform public.rebuild_user_tag_system(r.user_id);
  end loop;

  -- 2. Check expired Novel subscriptions
  for r in
    select id, user_id, level, expiry_date
    from public.subscriptions
    where membership_type = 'Novel'
      and status = 'Active'
      and expiry_date <= now()
  loop
    update public.subscriptions
    set status = 'Expired'
    where id = r.id;

    update public.profiles
    set novel_level = 0
    where id = r.user_id
      and (novel_expiry is null or novel_expiry <= now());

    insert into public.vip_audit_logs (user_id, action, category, item_name, details)
    values (r.user_id, 'NOVEL_EXPIRED', 'Novel', 'Novel Level ' || r.level, jsonb_build_object('expired_at', r.expiry_date, 'server_time', now()));

    perform public.rebuild_user_tag_system(r.user_id);
  end loop;
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function public.check_and_clean_expired_memberships() to authenticated, service_role;

-- 4. Single-Transaction Membership Purchase RPC
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
  v_old_level     integer := 0;
  v_action        text := 'VIP_PURCHASE';
  v_frame_name    text;
begin
  if p_user_id is null or p_product_name is null or p_category is null then
    raise exception 'record_membership_purchase: missing input parameters';
  end if;
  if p_category not in ('VIP','Novel') then
    raise exception 'record_membership_purchase: unsupported category %', p_category;
  end if;

  -- Idempotency check: return success if payment_id already processed
  if p_payment_id is not null then
    if exists (select 1 from public.purchases where payment_id = p_payment_id and status = 'Success') then
      return true;
    end if;
  end if;

  -- Parse target level
  v_level := coalesce(substring(p_product_name from '[0-9]+')::integer, 1);

  -- Get current VIP level and expiry
  if p_category = 'VIP' then
    select vip_level, vip_expiry into v_old_level, v_old_expiry
    from public.profiles where id = p_user_id;
  elsif p_category = 'Novel' then
    select novel_level, novel_expiry into v_old_level, v_old_expiry
    from public.profiles where id = p_user_id;
  end if;

  v_old_level := coalesce(v_old_level, 0);

  if v_old_level > 0 and v_old_expiry is not null and v_old_expiry > now() then
    if v_level > v_old_level then
      v_action := 'VIP_UPGRADE';
    else
      v_action := 'VIP_RENEWAL';
    end if;
  end if;

  -- Calculate expiry date
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

    if v_old_expiry is not null and v_old_expiry > now() then
      v_expiry := v_old_expiry + (v_days || ' days')::interval;
    else
      v_expiry := now() + (v_days || ' days')::interval;
    end if;
  end if;

  -- Gold Coins deduction if paying via wallet coins
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

  -- Update or insert into subscriptions
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

  -- Determine VIP avatar frame name
  if p_category = 'VIP' then
    if v_level = 1 then v_frame_name := 'Royal Frame';
    elsif v_level = 2 then v_frame_name := 'Neon Frame (Animated)';
    elsif v_level = 3 then v_frame_name := 'Gold Glow Frame';
    elsif v_level = 4 then v_frame_name := 'Diamond Frame';
    elsif v_level = 5 then v_frame_name := 'Crystal Cyan Frame';
    elsif v_level = 6 then v_frame_name := 'Rainbow Frame (Animated)';
    elsif v_level = 7 then v_frame_name := 'Royal Crown (Animated)';
    else v_frame_name := 'Royal Frame';
    end if;

    update public.profiles
    set vip_level = greatest(coalesce(vip_level, 0), v_level),
        vip_expiry = greatest(coalesce(vip_expiry, now()), v_expiry),
        avatar_frame = v_frame_name
    where id = p_user_id;

    -- Equip VIP Avatar Frame in user_customizations
    update public.user_customizations
    set is_equipped = false
    where user_id = p_user_id and type = 'Avatar Frame';

    insert into public.user_customizations (user_id, type, name, is_equipped)
    values (p_user_id, 'Avatar Frame', v_frame_name, true)
    on conflict (user_id, type, name) do update set is_equipped = true;

  elsif p_category = 'Novel' then
    update public.profiles
    set novel_level = greatest(coalesce(novel_level, 0), v_level),
        novel_expiry = greatest(coalesce(novel_expiry, now()), v_expiry)
    where id = p_user_id;
  end if;

  -- Record audit log
  insert into public.vip_audit_logs (user_id, action, category, item_name, details)
  values (
    p_user_id,
    v_action,
    p_category,
    p_product_name,
    jsonb_build_object(
      'level', v_level,
      'amount', p_amount,
      'duration', p_duration,
      'expiry', v_expiry,
      'payment_id', p_payment_id
    )
  );

  -- Rebuild identity tags
  perform public.rebuild_user_tag_system(p_user_id);

  return true;
exception
  when others then
    raise;
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function public.record_membership_purchase(uuid, text, text, numeric, numeric, text, text, timestamp with time zone, text) to authenticated, service_role;

-- 5. Upgraded Single-Call Inventory, Entitlements & Wallet RPC
create or replace function public.get_user_full_inventory_and_entitlements_rpc(
  p_user_id uuid
)
returns jsonb as $$
declare
  v_vip_sub      record;
  v_novel_sub    record;
  v_profile      record;
  v_wallet       record;
  v_inventory    jsonb;
  v_equipped     jsonb;
  v_result       jsonb;
  v_is_vip       boolean := false;
  v_is_novel     boolean := false;
begin
  if p_user_id is null then
    raise exception 'get_user_full_inventory_and_entitlements_rpc: missing p_user_id';
  end if;

  -- 1. Perform server time cleanup of expired subscriptions
  perform public.check_and_clean_expired_memberships();

  -- 2. Fetch profile state
  select
    vip_level,
    vip_expiry,
    novel_level,
    novel_expiry,
    avatar_frame,
    showcased_badges,
    identity_tags
  into v_profile
  from public.profiles
  where id = p_user_id;

  -- 3. Fetch active VIP subscription
  select level, expiry_date, status
  into v_vip_sub
  from public.subscriptions
  where user_id = p_user_id
    and membership_type = 'VIP'
    and status = 'Active'
    and expiry_date > now()
  order by level desc
  limit 1;

  -- 4. Fetch active Novel subscription
  select level, expiry_date, status
  into v_novel_sub
  from public.subscriptions
  where user_id = p_user_id
    and membership_type = 'Novel'
    and status = 'Active'
    and expiry_date > now()
  order by level desc
  limit 1;

  -- 5. Fetch wallet balances
  select gold_coins, coins_balance, silver_coins, diamonds
  into v_wallet
  from public.wallets
  where id = p_user_id;

  -- Compute VIP active state using server time
  if (v_vip_sub.level is not null and v_vip_sub.level > 0 and v_vip_sub.expiry_date > now()) or
     (v_profile.vip_level is not null and v_profile.vip_level > 0 and v_profile.vip_expiry is not null and v_profile.vip_expiry > now()) then
    v_is_vip := true;
  end if;

  -- Compute Novel active state using server time
  if (v_novel_sub.level is not null and v_novel_sub.level > 0 and v_novel_sub.expiry_date > now()) or
     (v_profile.novel_level is not null and v_profile.novel_level > 0 and v_profile.novel_expiry is not null and v_profile.novel_expiry > now()) then
    v_is_novel := true;
  end if;

  -- 6. Aggregate full user inventory list
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', coalesce(asset_id::text, name),
      'name', name,
      'type', type,
      'is_equipped', is_equipped,
      'asset_id', asset_id,
      'created_at', created_at
    )
  ), '[]'::jsonb)
  into v_inventory
  from public.user_customizations
  where user_id = p_user_id;

  -- 7. Aggregate equipped items
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'type', type,
      'name', name,
      'asset_id', asset_id,
      'path', path
    )
  ), '[]'::jsonb)
  into v_equipped
  from public.user_customizations
  where user_id = p_user_id and is_equipped = true;

  -- 8. Construct final JSON response payload
  v_result := jsonb_build_object(
    'user_id', p_user_id,
    'vip', jsonb_build_object(
      'level', case when v_is_vip then coalesce(v_vip_sub.level, v_profile.vip_level, 0) else 0 end,
      'expiry_date', coalesce(v_vip_sub.expiry_date, v_profile.vip_expiry),
      'is_active', v_is_vip
    ),
    'novel', jsonb_build_object(
      'level', case when v_is_novel then coalesce(v_novel_sub.level, v_profile.novel_level, 0) else 0 end,
      'expiry_date', coalesce(v_novel_sub.expiry_date, v_profile.novel_expiry),
      'is_active', v_is_novel
    ),
    'wallet', jsonb_build_object(
      'gold_coins', coalesce(v_wallet.gold_coins, 0),
      'coins_balance', coalesce(v_wallet.coins_balance, 0),
      'silver_coins', coalesce(v_wallet.silver_coins, 0),
      'diamonds', coalesce(v_wallet.diamonds, 0)
    ),
    'profile_frame', case when v_is_vip or v_is_novel or v_profile.avatar_frame is not null then coalesce(v_profile.avatar_frame, 'Normal') else 'Normal' end,
    'showcased_badges', coalesce(v_profile.showcased_badges, '[]'::jsonb),
    'identity_tags', coalesce(v_profile.identity_tags, '[]'::jsonb),
    'inventory', v_inventory,
    'equipped', v_equipped
  );

  return v_result;
exception
  when others then
    return jsonb_build_object('error', SQLERRM);
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function public.get_user_full_inventory_and_entitlements_rpc(uuid) to authenticated, service_role;
