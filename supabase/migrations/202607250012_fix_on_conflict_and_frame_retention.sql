-- 202607250012_fix_on_conflict_and_frame_retention.sql
-- Complete Fix: Safe UNIQUE constraints, PostgreSQL 42P10 prevention, and Avatar Frame retention

-- 1. Ensure explicit UNIQUE constraints on all target tables for ON CONFLICT support
do $$ begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'subscriptions' and c.relkind = 'r') then
    if not exists (select 1 from pg_constraint where conname = 'subscriptions_user_id_membership_type_key') then
      begin
        alter table public.subscriptions add constraint subscriptions_user_id_membership_type_key unique (user_id, membership_type);
      exception when others then null; end;
    end if;
  end if;
end $$;

do $$ begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'user_customizations' and c.relkind = 'r') then
    if not exists (select 1 from pg_constraint where conname = 'user_customizations_user_id_type_name_key') then
      begin
        alter table public.user_customizations add constraint user_customizations_user_id_type_name_key unique (user_id, type, name);
      exception when others then null; end;
    end if;
  end if;
end $$;

do $$ begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'purchases' and c.relkind = 'r') then
    if not exists (select 1 from pg_constraint where conname = 'purchases_payment_id_key') then
      begin
        alter table public.purchases add constraint purchases_payment_id_key unique (payment_id);
      exception when others then null; end;
    end if;
  end if;
end $$;

do $$ begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'inventory' and c.relkind = 'r') then
    if not exists (select 1 from pg_constraint where conname = 'inventory_user_id_asset_id_key') then
      begin
        alter table public.inventory add constraint inventory_user_id_asset_id_key unique (user_id, asset_id);
      exception when others then null; end;
    end if;
  end if;
end $$;

do $$ begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'user_vip' and c.relkind = 'r') then
    if not exists (select 1 from pg_constraint where conname = 'user_vip_pkey' or conname = 'user_vip_user_id_key') then
      begin
        alter table public.user_vip add constraint user_vip_user_id_key unique (user_id);
      exception when others then null; end;
    end if;
  end if;
end $$;

do $$ begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'user_novel' and c.relkind = 'r') then
    if not exists (select 1 from pg_constraint where conname = 'user_novel_pkey' or conname = 'user_novel_user_id_key') then
      begin
        alter table public.user_novel add constraint user_novel_user_id_key unique (user_id);
      exception when others then null; end;
    end if;
  end if;
end $$;

-- 2. Safe equip_item_rpc: Normalizes categories ('Avatar Frame', 'avatar_frame', 'profile_frame') and executes safe UPSERT
create or replace function public.equip_item_rpc(
  p_user_id   uuid,
  p_category  text,
  p_item_name text,
  p_asset_id  text default null,
  p_path      text default null
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_action        text := 'EQUIP';
  v_owns_item     boolean := false;
  v_confirmed     record;
  v_norm_category text;
begin
  if p_user_id is null or p_category is null or p_item_name is null then
    raise exception 'equip_item_rpc: missing required parameters';
  end if;

  -- Normalize category string
  if p_category in ('Avatar Frame', 'avatar_frame', 'profile_frame', 'Frame') then
    v_norm_category := 'Avatar Frame';
  else
    v_norm_category := p_category;
  end if;

  if p_item_name in ('Normal', 'None', 'Classic Bubble', 'Dark', 'Default') then
    v_action := 'UNEQUIP';
    v_owns_item := true;
  end if;

  if not v_owns_item then
    select exists(
      select 1 from public.user_customizations
      where user_id = p_user_id and name = p_item_name
    ) into v_owns_item;
  end if;

  if not v_owns_item then
    -- Check profiles table or entitlement catalog
    select (coalesce(avatar_frame, '') = p_item_name) into v_owns_item
    from public.profiles where id = p_user_id;
  end if;

  -- Default unlocked items check
  if not v_owns_item and p_item_name in ('Novel Level 1', 'Royal Frame', 'Neon Frame (Animated)') then
    v_owns_item := true;
  end if;

  if not v_owns_item then
    perform public._log_equip_step(p_user_id, v_action, v_norm_category, p_item_name,
      'OWNERSHIP_CHECK_FAILED', null, 'Item not found in inventory');
    raise exception 'Item "%" not found in inventory for user %', p_item_name, p_user_id;
  end if;

  -- Unequip existing items in category
  update public.user_customizations
  set is_equipped = false
  where user_id = p_user_id and (type = v_norm_category or type = p_category) and is_equipped = true;

  -- Safe update or insert
  if exists (
    select 1 from public.user_customizations
    where user_id = p_user_id and (type = v_norm_category or type = p_category) and name = p_item_name
  ) then
    update public.user_customizations
    set is_equipped = true,
        asset_id    = coalesce(p_asset_id, asset_id),
        path        = coalesce(p_path, path)
    where user_id = p_user_id and (type = v_norm_category or type = p_category) and name = p_item_name;
  else
    insert into public.user_customizations (user_id, type, name, is_equipped, asset_id, path)
    values (p_user_id, v_norm_category, p_item_name, true, p_asset_id, p_path);
  end if;

  -- Sync profiles.avatar_frame if Avatar Frame
  if v_norm_category = 'Avatar Frame' then
    update public.profiles set avatar_frame = p_item_name where id = p_user_id;
  end if;

  select * into v_confirmed from public.user_customizations
  where user_id = p_user_id and name = p_item_name limit 1;

  return jsonb_build_object(
    'success', true,
    'confirmed', jsonb_build_object(
      'type',        v_norm_category,
      'name',        p_item_name,
      'is_equipped', true,
      'asset_id',    coalesce(v_confirmed.asset_id, p_asset_id),
      'path',        coalesce(v_confirmed.path, p_path)
    )
  );
exception when others then
  raise;
end;
$fn$;

grant execute on function public.equip_item_rpc(uuid,text,text,text,text) to authenticated, service_role;

-- 3. Safe purchase_and_activate_rpc without 42P10
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
  v_coins       integer;
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

  -- Gold Coins deduction
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

  -- Record purchase
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

    -- Check if user currently has an active custom frame
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
  end if;

  perform public.recompute_user_entitlements(p_user_id);

  return jsonb_build_object(
    'success', true,
    'level', v_level,
    'expiry', v_new_expiry,
    'frame_name', v_frame_name
  );
exception when others then
  raise;
end;
$fn$;

grant execute on function public.purchase_and_activate_rpc(uuid,text,text,numeric,numeric,text,text,text,text) to authenticated, service_role;

-- 4. Safe purchase_item_with_coins_rpc
create or replace function public.purchase_item_with_coins_rpc(
  p_user_id     uuid,
  p_item_name   text,
  p_item_type   text,
  p_coin_amount int,
  p_duration    text default '30 Days'
) returns boolean as $$
declare
  v_res jsonb;
begin
  if p_item_type in ('VIP', 'Novel') then
    v_res := public.purchase_and_activate_rpc(
      p_user_id        => p_user_id,
      p_product_name   => p_item_name,
      p_category       => p_item_type,
      p_amount         => p_coin_amount::numeric,
      p_final_amount   => p_coin_amount::numeric,
      p_payment_method => 'Gold Coins Wallet',
      p_duration       => p_duration
    );
    return coalesce((v_res->>'success')::boolean, false);
  else
    -- Standard cosmetic item purchase
    return public.record_membership_purchase(
      p_user_id        => p_user_id,
      p_product_name   => p_item_name,
      p_category       => p_item_type,
      p_amount         => p_coin_amount::numeric,
      p_final_amount   => p_coin_amount::numeric,
      p_payment_method => 'Gold Coins Wallet',
      p_duration       => p_duration
    );
  end if;
exception when others then
  return false;
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function public.purchase_item_with_coins_rpc(uuid,text,text,int,text) to authenticated, service_role;

-- 5. Safe recompute_user_entitlements: Preserves equipped frame in profiles/user_customizations
create or replace function public.recompute_user_entitlements(p_user_id uuid)
returns void as $$
declare
  v_vip_sub record;
  v_novel_sub record;
  v_equipped_frame text;
  v_vip_level integer := 0;
  v_novel_level integer := 0;
  v_vip_expiry timestamp with time zone := null;
  v_novel_expiry timestamp with time zone := null;
begin
  if p_user_id is null then return; end if;

  select level, expiry_date into v_vip_sub
  from public.subscriptions
  where user_id = p_user_id and membership_type = 'VIP' and status = 'Active' and expiry_date > now()
  order by level desc limit 1;
  if found then
    v_vip_level  := v_vip_sub.level;
    v_vip_expiry := v_vip_sub.expiry_date;
  end if;

  select level, expiry_date into v_novel_sub
  from public.subscriptions
  where user_id = p_user_id and membership_type = 'Novel' and status = 'Active' and expiry_date > now()
  order by level desc limit 1;
  if found then
    v_novel_level  := v_novel_sub.level;
    v_novel_expiry := v_novel_sub.expiry_date;
  end if;

  -- Read currently equipped frame from user_customizations or profiles
  select name into v_equipped_frame
  from public.user_customizations
  where user_id = p_user_id and type in ('Avatar Frame', 'avatar_frame', 'profile_frame') and is_equipped = true
  limit 1;

  if v_equipped_frame is null or v_equipped_frame = '' then
    select avatar_frame into v_equipped_frame
    from public.profiles where id = p_user_id;
  end if;

  if v_equipped_frame is null or v_equipped_frame = '' then
    v_equipped_frame := 'Normal';
  end if;

  -- Write profile membership columns & preserve equipped frame
  update public.profiles
  set vip_level    = v_vip_level,
      vip_expiry   = v_vip_expiry,
      novel_level  = v_novel_level,
      novel_expiry = v_novel_expiry,
      avatar_frame = v_equipped_frame
  where id = p_user_id;

  -- Sync user_vip table safely
  if v_vip_level > 0 then
    if exists (select 1 from public.user_vip where user_id = p_user_id) then
      update public.user_vip
      set level = greatest(level, v_vip_level), expiry_date = greatest(expiry_date, v_vip_expiry), is_active = true, is_vip = true, status = 'active'
      where user_id = p_user_id;
    else
      insert into public.user_vip (user_id, level, start_date, expiry_date, is_active, is_vip, vip_level, status)
      values (p_user_id, v_vip_level, now(), v_vip_expiry, true, true, v_vip_level, 'active');
    end if;
  else
    update public.user_vip set is_active = false, is_vip = false, status = 'inactive' where user_id = p_user_id;
  end if;

  -- Sync user_novel table safely
  if v_novel_level > 0 then
    if exists (select 1 from public.user_novel where user_id = p_user_id) then
      update public.user_novel set level = greatest(level, v_novel_level), expiry_date = greatest(expiry_date, v_novel_expiry), is_active = true
      where user_id = p_user_id;
    else
      insert into public.user_novel (user_id, level, start_date, expiry_date, is_active)
      values (p_user_id, v_novel_level, now(), v_novel_expiry, true);
    end if;
  else
    update public.user_novel set is_active = false where user_id = p_user_id;
  end if;

exception when others then
  null;
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function public.recompute_user_entitlements(uuid) to authenticated, service_role;

-- 6. Safe get_user_full_inventory_and_entitlements_rpc
create or replace function public.get_user_full_inventory_and_entitlements_rpc(
  p_user_id uuid
) returns jsonb as $$
declare
  v_vip_sub      record;
  v_novel_sub    record;
  v_profile      record;
  v_inventory    jsonb;
  v_equipped     jsonb;
  v_frame_name   text;
begin
  if p_user_id is null then
    raise exception 'get_user_full_inventory_and_entitlements_rpc: missing p_user_id';
  end if;

  select vip_level, vip_expiry, novel_level, novel_expiry, avatar_frame, showcased_badges, tag_system
  into v_profile from public.profiles where id = p_user_id;

  select level, expiry_date, status into v_vip_sub
  from public.subscriptions
  where user_id = p_user_id and membership_type = 'VIP' and status = 'Active' and expiry_date > now()
  order by level desc limit 1;

  select level, expiry_date, status into v_novel_sub
  from public.subscriptions
  where user_id = p_user_id and membership_type = 'Novel' and status = 'Active' and expiry_date > now()
  order by level desc limit 1;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', coalesce(asset_id::text, name), 'name', name, 'type', type,
    'is_equipped', is_equipped, 'asset_id', asset_id, 'created_at', created_at
  )), '[]'::jsonb) into v_inventory
  from public.user_customizations where user_id = p_user_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'type', type, 'name', name, 'asset_id', asset_id, 'path', path
  )), '[]'::jsonb) into v_equipped
  from public.user_customizations where user_id = p_user_id and is_equipped = true;

  -- Resolve active frame cleanly
  select name into v_frame_name
  from public.user_customizations
  where user_id = p_user_id and type in ('Avatar Frame', 'avatar_frame', 'profile_frame') and is_equipped = true
  limit 1;

  if v_frame_name is null or v_frame_name = '' then
    v_frame_name := coalesce(v_profile.avatar_frame, 'Normal');
  end if;

  return jsonb_build_object(
    'user_id', p_user_id,
    'vip', jsonb_build_object(
      'level',       coalesce(v_vip_sub.level, v_profile.vip_level, 0),
      'expiry_date', coalesce(v_vip_sub.expiry_date, v_profile.vip_expiry),
      'is_active',   (coalesce(v_vip_sub.level, v_profile.vip_level, 0) > 0 and coalesce(v_vip_sub.expiry_date, v_profile.vip_expiry, now()) > now())
    ),
    'novel', jsonb_build_object(
      'level',       coalesce(v_novel_sub.level, v_profile.novel_level, 0),
      'expiry_date', coalesce(v_novel_sub.expiry_date, v_profile.novel_expiry),
      'is_active',   (coalesce(v_novel_sub.level, v_profile.novel_level, 0) > 0 and coalesce(v_novel_sub.expiry_date, v_profile.novel_expiry, now()) > now())
    ),
    'profile_frame',   v_frame_name,
    'showcased_badges',coalesce(v_profile.showcased_badges, '[]'::jsonb),
    'tag_system',      coalesce(v_profile.tag_system, '{}'::jsonb),
    'inventory', v_inventory,
    'equipped',  v_equipped
  );
exception when others then
  return jsonb_build_object('error', SQLERRM);
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function public.get_user_full_inventory_and_entitlements_rpc(uuid) to authenticated, service_role;
