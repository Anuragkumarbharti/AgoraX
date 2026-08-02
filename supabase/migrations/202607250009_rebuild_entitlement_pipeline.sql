-- 202607250009_rebuild_entitlement_pipeline.sql
-- ROOT-CAUSE FIX: Unified payment -> subscription -> inventory -> equip pipeline
-- ALL timestamps use server now(). Client-provided expiry is NEVER trusted.
-- equip_item_rpc  : verifies ownership before equipping, returns confirmed DB row.
-- purchase_and_activate_rpc: single atomic entry point for all purchases.

-- ============================================================
-- 1. Extend vip_audit_logs with per-step detail columns
-- ============================================================
alter table public.vip_audit_logs
  add column if not exists step         text,
  add column if not exists error_detail text;

-- ============================================================
-- 2. Unique partial index: one equipped item per (user_id, category)
-- ============================================================
do $body$
begin
  if not exists (
    select 1 from pg_index i join pg_class c on c.oid = i.indexrelid
    where c.relname = 'idx_uc_single_equipped_v2'
  ) then
    drop index if exists public.idx_user_customizations_single_equipped;
    create unique index idx_uc_single_equipped_v2
      on public.user_customizations (user_id, type)
      where is_equipped = true;
  end if;
end $body$;

-- ============================================================
-- 3. Helper: silent per-step audit logger (never raises)
-- ============================================================
create or replace function public._log_equip_step(
  p_user_id   uuid,
  p_action    text,
  p_category  text,
  p_item_name text,
  p_step      text,
  p_detail    jsonb default null,
  p_error     text  default null
) returns void language plpgsql security definer set search_path = public as $fn$
begin
  insert into public.vip_audit_logs
    (user_id, action, category, item_name, step, details, error_detail, created_at)
  values (p_user_id, p_action, p_category, p_item_name, p_step,
          coalesce(p_detail, '{}'::jsonb), p_error, now());
exception when others then null;
end;
$fn$;

grant execute on function public._log_equip_step(uuid,text,text,text,text,jsonb,text)
  to authenticated, service_role;

-- ============================================================
-- 4. REWRITE: equip_item_rpc
--    - Verifies VIP/Novel ownership via subscriptions table (server now())
--    - Verifies non-VIP items exist in user_customizations
--    - Atomic: unequip old + equip new + sync profiles.avatar_frame
--    - Returns confirmed DB row (not just {success:true})
--    - Per-step audit log at every stage
-- ============================================================
create or replace function public.equip_item_rpc(
  p_user_id   uuid,
  p_category  text,
  p_item_name text,
  p_asset_id  text default null,
  p_path      text default null
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_vip_level     integer := 0;
  v_novel_level   integer := 0;
  v_vip_expiry    timestamptz;
  v_novel_expiry  timestamptz;
  v_is_vip_item   boolean := false;
  v_is_novel_item boolean := false;
  v_owns_item     boolean := false;
  v_confirmed     record;
  v_action        text := 'EQUIP_ITEM';
begin
  if p_user_id is null or p_category is null or p_item_name is null then
    raise exception 'equip_item_rpc: missing required parameters';
  end if;

  perform public._log_equip_step(p_user_id, v_action, p_category, p_item_name,
    'EQUIP_REQUESTED', jsonb_build_object('server_time', now(), 'asset_id', p_asset_id));

  -- Classify item type
  v_is_vip_item := (
    p_item_name ilike 'Royal Frame%'  or p_item_name ilike 'Neon Frame%'  or
    p_item_name ilike 'Gold Glow%'    or p_item_name ilike 'Diamond Frame%' or
    p_item_name ilike 'Crystal Cyan%' or p_item_name ilike 'Rainbow Frame%' or
    p_item_name ilike 'Royal Crown%'  or p_item_name ilike 'VIP%'
  );
  v_is_novel_item := p_item_name ilike 'Novel%';

  -- Read active subscriptions (server now() only — never device time)
  select
    coalesce(max(case when membership_type='VIP'   and status='Active' and expiry_date>now() then level else 0 end),0),
    coalesce(max(case when membership_type='Novel' and status='Active' and expiry_date>now() then level else 0 end),0),
    max(case when membership_type='VIP'   and status='Active' and expiry_date>now() then expiry_date end),
    max(case when membership_type='Novel' and status='Active' and expiry_date>now() then expiry_date end)
  into v_vip_level, v_novel_level, v_vip_expiry, v_novel_expiry
  from public.subscriptions where user_id = p_user_id;

  v_vip_level   := coalesce(v_vip_level, 0);
  v_novel_level := coalesce(v_novel_level, 0);

  -- VIP gated: check subscription
  if v_is_vip_item then
    if v_vip_level <= 0 or v_vip_expiry is null or v_vip_expiry <= now() then
      perform public._log_equip_step(p_user_id, v_action, p_category, p_item_name,
        'VIP_CHECK_FAILED',
        jsonb_build_object('vip_level', v_vip_level, 'vip_expiry', v_vip_expiry),
        'VIP subscription required or expired');
      raise exception 'Active VIP subscription required to equip "%"', p_item_name;
    end if;
    perform public._log_equip_step(p_user_id, v_action, p_category, p_item_name,
      'VIP_VERIFIED', jsonb_build_object('vip_level', v_vip_level));
  end if;

  -- Novel gated: check subscription
  if v_is_novel_item then
    if v_novel_level <= 0 or v_novel_expiry is null or v_novel_expiry <= now() then
      perform public._log_equip_step(p_user_id, v_action, p_category, p_item_name,
        'NOVEL_CHECK_FAILED',
        jsonb_build_object('novel_level', v_novel_level),
        'Novel subscription required or expired');
      raise exception 'Active Novel subscription required to equip "%"', p_item_name;
    end if;
    perform public._log_equip_step(p_user_id, v_action, p_category, p_item_name,
      'NOVEL_VERIFIED', jsonb_build_object('novel_level', v_novel_level));
  end if;

  -- Ownership check: free defaults always allowed
  v_owns_item := p_item_name = any(array[
    'Normal','None','Classic Bubble','Classic Emojis',
    'Dark','Default','Love Castle','Scholar','Legend','Explorer'
  ]);

  -- VIP/Novel item: ownership = active subscription
  if not v_owns_item and v_is_vip_item then
    v_owns_item := (v_vip_level > 0 and v_vip_expiry is not null and v_vip_expiry > now());
  end if;
  if not v_owns_item and v_is_novel_item then
    v_owns_item := (v_novel_level > 0 and v_novel_expiry is not null and v_novel_expiry > now());
  end if;

  -- Non-membership item: must exist in user_customizations
  if not v_owns_item then
    select exists(
      select 1 from public.user_customizations
      where user_id = p_user_id and name = p_item_name
    ) into v_owns_item;
  end if;

  if not v_owns_item then
    perform public._log_equip_step(p_user_id, v_action, p_category, p_item_name,
      'OWNERSHIP_CHECK_FAILED', null, 'Item not found in inventory');
    raise exception 'Item "%" not found in inventory for user %', p_item_name, p_user_id;
  end if;

  perform public._log_equip_step(p_user_id, v_action, p_category, p_item_name, 'OWNERSHIP_VERIFIED');

  -- Atomic: unequip old, equip new
  update public.user_customizations
  set is_equipped = false
  where user_id = p_user_id and type = p_category and is_equipped = true;

  insert into public.user_customizations (user_id, type, name, is_equipped, asset_id, path)
  values (p_user_id, p_category, p_item_name, true, p_asset_id, p_path)
  on conflict (user_id, type, name)
  do update set
    is_equipped = true,
    asset_id    = coalesce(excluded.asset_id, user_customizations.asset_id),
    path        = coalesce(excluded.path,     user_customizations.path);

  if p_category = 'Avatar Frame' then
    update public.profiles set avatar_frame = p_item_name where id = p_user_id;
  end if;

  perform public._log_equip_step(p_user_id, v_action, p_category, p_item_name,
    'DB_UPDATED', jsonb_build_object('server_time', now()));

  -- Read back the confirmed row from DB
  select * into v_confirmed from public.user_customizations
  where user_id = p_user_id and type = p_category and name = p_item_name;

  perform public._log_equip_step(p_user_id, v_action, p_category, p_item_name,
    'TRANSACTION_COMMITTED',
    jsonb_build_object('is_equipped', v_confirmed.is_equipped, 'server_time', now()));

  return jsonb_build_object(
    'success', true,
    'confirmed', jsonb_build_object(
      'type',        v_confirmed.type,
      'name',        v_confirmed.name,
      'is_equipped', v_confirmed.is_equipped,
      'asset_id',    v_confirmed.asset_id,
      'path',        v_confirmed.path
    )
  );

exception when others then
  perform public._log_equip_step(p_user_id, v_action, p_category, p_item_name,
    'FAILED', null, SQLERRM);
  raise;
end;
$fn$;

grant execute on function public.equip_item_rpc(uuid,text,text,text,text) to authenticated, service_role;

-- ============================================================
-- 5. NEW: purchase_and_activate_rpc
--    Single atomic server-side entry point for ALL purchases.
--    Steps logged: PAYMENT_RECEIVED -> IDEMPOTENCY_CHECK_PASSED ->
--      DB_TRANSACTION_STARTED -> ENTITLEMENT_CREATED ->
--      INVENTORY_UPDATED -> EQUIPMENT_SAVED ->
--      TRANSACTION_COMMITTED -> CLIENT_RESPONSE_SENT
--    On any failure: entire transaction rolls back, FAILED is logged.
-- ============================================================
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
  v_action_type text    := 'PURCHASE';
  v_frame_name  text;
  v_auto_equip  boolean := false;
  v_has_frame   boolean := false;
  v_result      jsonb;
  v_coins       integer;
begin
  if p_user_id is null or p_product_name is null or p_category is null then
    raise exception 'purchase_and_activate_rpc: missing required parameters';
  end if;
  if p_category not in ('VIP','Novel','Coins','Item') then
    raise exception 'purchase_and_activate_rpc: unsupported category "%"', p_category;
  end if;

  -- Step 1: PAYMENT_RECEIVED
  perform public._log_equip_step(p_user_id, 'PURCHASE', p_category, p_product_name,
    'PAYMENT_RECEIVED', jsonb_build_object(
      'payment_id', p_payment_id, 'order_id', p_order_id,
      'amount', p_final_amount, 'method', p_payment_method, 'server_time', now()));

  -- Idempotency: skip if payment_id already committed
  if p_payment_id is not null and exists(
    select 1 from public.purchases where payment_id = p_payment_id and status = 'Success'
  ) then
    perform public._log_equip_step(p_user_id, 'PURCHASE', p_category, p_product_name,
      'IDEMPOTENCY_HIT', jsonb_build_object('payment_id', p_payment_id));
    return jsonb_build_object('success', true, 'idempotent', true,
      'product', p_product_name, 'category', p_category);
  end if;

  -- Step 2: IDEMPOTENCY_CHECK_PASSED
  perform public._log_equip_step(p_user_id, 'PURCHASE', p_category, p_product_name,
    'IDEMPOTENCY_CHECK_PASSED');

  -- Parse level from product name
  v_level := coalesce((regexp_match(p_product_name, E'(\d+)'))[1]::integer, 1);

  -- Parse duration to days (server-side ONLY — never trusts client-provided expiry)
  v_target_days := case p_duration
    when '3 Days'    then 3   when '7 Days'    then 7
    when '15 Days'   then 15  when '30 Days'   then 30
    when '1 Month'   then 30  when '90 Days'   then 90
    when '3 Months'  then 90  when '6 Months'  then 180
    when '6 Month'   then 180 when '12 Months' then 365
    when '1 Year'    then 365 when 'Yearly'    then 365
    else 30
  end;

  -- Gold Coins wallet deduction (row-locked)
  if p_payment_method = 'Gold Coins Wallet' then
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
    insert into public.wallet_transactions (wallet_id,amount,currency,type,status,details)
    values (p_user_id, p_final_amount::integer, 'Gold Coins', 'Purchase', 'Completed',
      'Purchased ' || p_product_name);
  end if;

  -- Record in purchases ledger
  insert into public.purchases
    (user_id, product_name, category, amount, final_amount, payment_method, status, duration, payment_id)
  values (p_user_id, p_product_name, p_category, p_amount, p_final_amount,
          p_payment_method, 'Success', p_duration, p_payment_id);

  -- Step 3: DB_TRANSACTION_STARTED
  perform public._log_equip_step(p_user_id, 'PURCHASE', p_category, p_product_name,
    'DB_TRANSACTION_STARTED', jsonb_build_object('server_time', now()));

  -- ================================================================
  -- VIP ACTIVATION
  -- ================================================================
  if p_category = 'VIP' then

    select level, expiry_date into v_old_level, v_old_expiry
    from public.subscriptions
    where user_id = p_user_id and membership_type = 'VIP' and status = 'Active'
    order by level desc limit 1;
    v_old_level := coalesce(v_old_level, 0);

    v_action_type := case
      when v_old_level = 0       then 'VIP_PURCHASE'
      when v_level > v_old_level then 'VIP_UPGRADE'
      else 'VIP_RENEWAL' end;

    -- Expiry computed server-side with cascading 50% carry-forward
    if v_old_expiry is not null and v_old_expiry > now() then
      if v_level = v_old_level then
        -- Renewal: full stack
        v_new_expiry := v_old_expiry + (v_target_days || ' days')::interval;
      elsif v_level > v_old_level then
        -- Upgrade: 50% carry-forward per step
        v_new_expiry := now() + (
          v_target_days +
          floor(
            extract(epoch from (v_old_expiry - now())) / 86400.0 *
            power(0.5::float8, (v_level - v_old_level)::float8)
          )
        )::integer * interval '1 day';
      else
        v_new_expiry := v_old_expiry + (v_target_days || ' days')::interval;
      end if;
    else
      v_new_expiry := now() + (v_target_days || ' days')::interval;
    end if;

    v_frame_name := case v_level
      when 1 then 'Royal Frame'            when 2 then 'Neon Frame (Animated)'
      when 3 then 'Gold Glow Frame'        when 4 then 'Diamond Frame'
      when 5 then 'Crystal Cyan Frame'     when 6 then 'Rainbow Frame (Animated)'
      when 7 then 'Royal Crown (Animated)' else 'Royal Frame' end;

    -- Upsert subscription record
    insert into public.subscriptions
      (user_id, membership_type, level, purchase_date, activation_date, expiry_date, auto_renewal, status, payment_id)
    values (p_user_id,'VIP',v_level,now(),now(),v_new_expiry,true,'Active',p_payment_id)
    on conflict (user_id, membership_type)
    do update set
      level           = greatest(subscriptions.level, excluded.level),
      activation_date = now(),
      expiry_date     = greatest(subscriptions.expiry_date, excluded.expiry_date),
      status          = 'Active',
      payment_id      = excluded.payment_id;

    -- Step 4: ENTITLEMENT_CREATED
    perform public._log_equip_step(p_user_id, 'PURCHASE', p_category, p_product_name,
      'ENTITLEMENT_CREATED',
      jsonb_build_object('level', v_level, 'expiry', v_new_expiry, 'frame', v_frame_name));

    -- Sync to profiles
    update public.profiles
    set vip_level  = greatest(coalesce(vip_level,  0), v_level),
        vip_expiry = greatest(coalesce(vip_expiry, now()), v_new_expiry)
    where id = p_user_id;

    -- Step 5: Add frame to inventory
    insert into public.user_customizations (user_id, type, name, is_equipped)
    values (p_user_id, 'Avatar Frame', v_frame_name, false)
    on conflict (user_id, type, name) do nothing;

    perform public._log_equip_step(p_user_id, 'PURCHASE', p_category, p_product_name,
      'INVENTORY_UPDATED', jsonb_build_object('frame_added', v_frame_name));

    -- Step 6: Auto-equip if no premium frame currently equipped
    select exists(
      select 1 from public.user_customizations
      where user_id = p_user_id and type = 'Avatar Frame'
        and is_equipped = true and name not in ('Normal','None')
    ) into v_has_frame;

    if not v_has_frame then
      update public.user_customizations
        set is_equipped = false
        where user_id = p_user_id and type = 'Avatar Frame';
      update public.user_customizations
        set is_equipped = true
        where user_id = p_user_id and type = 'Avatar Frame' and name = v_frame_name;
      update public.profiles set avatar_frame = v_frame_name where id = p_user_id;
      v_auto_equip := true;
      perform public._log_equip_step(p_user_id, 'PURCHASE', p_category, p_product_name,
        'EQUIPMENT_SAVED', jsonb_build_object('auto_equipped', v_frame_name));
    end if;

  -- ================================================================
  -- NOVEL ACTIVATION
  -- ================================================================
  elsif p_category = 'Novel' then

    select level, expiry_date into v_old_level, v_old_expiry
    from public.subscriptions
    where user_id = p_user_id and membership_type = 'Novel' and status = 'Active'
    order by level desc limit 1;
    v_old_level := coalesce(v_old_level, 0);

    v_action_type := case
      when v_old_level = 0       then 'NOVEL_PURCHASE'
      when v_level > v_old_level then 'NOVEL_UPGRADE'
      else 'NOVEL_RENEWAL' end;

    if v_old_expiry is not null and v_old_expiry > now() then
      if v_level = v_old_level then
        v_new_expiry := v_old_expiry + (v_target_days || ' days')::interval;
      elsif v_level > v_old_level then
        v_new_expiry := now() + (
          v_target_days +
          floor(
            extract(epoch from (v_old_expiry - now())) / 86400.0 *
            power(0.5::float8, (v_level - v_old_level)::float8)
          )
        )::integer * interval '1 day';
      else
        v_new_expiry := v_old_expiry + (v_target_days || ' days')::interval;
      end if;
    else
      v_new_expiry := now() + (v_target_days || ' days')::interval;
    end if;

    v_frame_name := 'Novel Level ' || v_level;

    insert into public.subscriptions
      (user_id, membership_type, level, purchase_date, activation_date, expiry_date, auto_renewal, status, payment_id)
    values (p_user_id,'Novel',v_level,now(),now(),v_new_expiry,true,'Active',p_payment_id)
    on conflict (user_id, membership_type)
    do update set
      level           = greatest(subscriptions.level, excluded.level),
      activation_date = now(),
      expiry_date     = greatest(subscriptions.expiry_date, excluded.expiry_date),
      status          = 'Active',
      payment_id      = excluded.payment_id;

    perform public._log_equip_step(p_user_id, 'PURCHASE', p_category, p_product_name,
      'ENTITLEMENT_CREATED', jsonb_build_object('level', v_level, 'expiry', v_new_expiry));

    update public.profiles
    set novel_level  = greatest(coalesce(novel_level,  0), v_level),
        novel_expiry = greatest(coalesce(novel_expiry, now()), v_new_expiry)
    where id = p_user_id;

    insert into public.user_customizations (user_id, type, name, is_equipped)
    values (p_user_id, 'Avatar Frame', v_frame_name, false)
    on conflict (user_id, type, name) do nothing;

    perform public._log_equip_step(p_user_id, 'PURCHASE', p_category, p_product_name,
      'INVENTORY_UPDATED', jsonb_build_object('frame_added', v_frame_name));

  end if;

  -- Rebuild identity tags
  perform public.rebuild_user_tag_system(p_user_id);

  -- Step 7: TRANSACTION_COMMITTED
  insert into public.vip_audit_logs
    (user_id, action, category, item_name, step, details)
  values (p_user_id, v_action_type, p_category, p_product_name, 'TRANSACTION_COMMITTED',
    jsonb_build_object('level',v_level,'expiry',v_new_expiry,'frame',v_frame_name,
                       'auto_equipped',v_auto_equip,'payment_id',p_payment_id,
                       'server_time',now()));

  -- Build response
  v_result := jsonb_build_object(
    'success',       true,
    'product',       p_product_name,
    'category',      p_category,
    'level',         v_level,
    'expiry',        v_new_expiry,
    'frame_name',    v_frame_name,
    'auto_equipped', v_auto_equip,
    'server_time',   now()
  );

  -- Step 8: CLIENT_RESPONSE_SENT
  perform public._log_equip_step(p_user_id, 'PURCHASE', p_category, p_product_name,
    'CLIENT_RESPONSE_SENT', v_result);

  return v_result;

exception when others then
  -- On any failure: log and re-raise (PostgreSQL auto-rolls back entire transaction)
  insert into public.vip_audit_logs
    (user_id, action, category, item_name, step, error_detail)
  values (p_user_id, 'PURCHASE', p_category, p_product_name, 'FAILED', SQLERRM);
  raise exception 'purchase_and_activate_rpc failed: %', SQLERRM;
end;
$fn$;

grant execute on function public.purchase_and_activate_rpc(uuid,text,text,numeric,numeric,text,text,text,text)
  to authenticated, service_role;

-- ============================================================
-- 6. Ensure subscriptions unique constraint (needed for ON CONFLICT)
-- ============================================================
do $body$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'subscriptions_user_membership_unique'
      and conrelid = 'public.subscriptions'::regclass
  ) then
    alter table public.subscriptions
      add constraint subscriptions_user_membership_unique unique (user_id, membership_type);
  end if;
exception when others then null;
end $body$;
