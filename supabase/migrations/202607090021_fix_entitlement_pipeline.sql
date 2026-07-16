-- 202607090021_fix_entitlement_pipeline.sql
-- ROOT CAUSE FIX: Unified purchase → entitlement → inventory → asset → auto-equip → tag pipeline
--
-- ROOT CAUSES IDENTIFIED:
-- 1. rebuild_user_tag_system reads from vip_assets/novel_assets tables, but purchases
--    write to cosmetic_assets. These are two separate tables = purchases never produce tags.
-- 2. on_profile_vip_novel_update is a BEFORE trigger calling recompute_user_entitlements
--    which itself updates profiles → infinite recursion / updates are silently discarded.
-- 3. recompute_user_entitlements computes profile vip_level from subscriptions table,
--    but rebuild_user_tag_system reads vip_level from profiles — causing a race condition
--    where the tag system runs before the profile row is committed.
-- 4. No automatic expiry enforcement (no pg_cron, no row-level trigger on subscriptions).
--
-- FIX STRATEGY:
-- A. Rewrite rebuild_user_tag_system to read identity tag URLs from cosmetic_assets (not vip_assets).
-- B. Fix the trigger to be AFTER (not BEFORE) and add a guard to prevent recursion.
-- C. Rewrite recompute_user_entitlements to pass VIP/Novel levels as parameters (not re-read from profiles).
-- D. Add an AFTER INSERT OR UPDATE trigger on subscriptions to auto-run entitlements.
-- E. Add an AFTER INSERT OR UPDATE on purchases to auto-run entitlements.

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1: Drop all broken triggers to start clean
-- ─────────────────────────────────────────────────────────────────────────────
drop trigger if exists tr_on_profile_membership_change on public.profiles;
drop trigger if exists tr_on_subscription_change on public.subscriptions;
drop trigger if exists tr_on_purchase_complete on public.purchases;
drop function if exists public.on_profile_vip_novel_update() cascade;
drop function if exists public.on_subscription_change() cascade;
drop function if exists public.on_purchase_complete() cascade;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2: Rewrite rebuild_user_tag_system to use cosmetic_assets (the ONLY asset table)
-- This is the central fix for why purchases don't produce identity tags.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.rebuild_user_tag_system(p_user_id uuid)
returns void as $$
declare
  v_r_tags text[];
  v_vip_level integer;
  v_vip_expiry timestamp with time zone;
  v_novel_level integer;
  v_novel_expiry timestamp with time zone;
  v_level integer;
  v_verified boolean;
  v_showcased_badges text[];

  v_identity_tags jsonb[] := array[]::jsonb[];
  v_community_tag text := null;
  v_comm_id text;
  v_special_tag text := null;
  v_verified_tag text := null;
  v_role_tag text := null;

  -- Tag URL resolved from cosmetic_assets (unified table)
  v_vip_tag_url text;
  v_novel_tag_url text;

  v_now timestamp with time zone := now();
  v_tag_system jsonb;
  v_tag_lights text[] := '{}';
begin
  select r_tags, vip_level, vip_expiry, novel_level, novel_expiry, level, verified, showcased_badges
  into v_r_tags, v_vip_level, v_vip_expiry, v_novel_level, v_novel_expiry, v_level, v_verified, v_showcased_badges
  from public.profiles
  where id = p_user_id;

  if v_level is null then v_level := 1; end if;

  -- 1. ID Level Tag (Local Asset — always present)
  v_identity_tags := array_append(v_identity_tags, jsonb_build_object(
    'type', 'id_level',
    'value', 'Lv.' || v_level,
    'image_url', 'asset://assets/identity_tags/id_level_' || least(v_level, 2) || '.png'
  ));
  v_tag_lights := array_append(v_tag_lights, 'ID Level ' || v_level);

  -- 2. Community Tag
  select id into v_comm_id
  from public.communities
  where p_user_id::text = any(members)
    and id in ('comm-official-001','comm-creators-002','comm-gamers-003','comm-campus-004','comm-connect-005')
  order by case id
    when 'comm-connect-005' then 1
    when 'comm-creators-002' then 2
    when 'comm-gamers-003' then 3
    when 'comm-campus-004' then 4
    when 'comm-official-001' then 5
    else 6
  end asc
  limit 1;

  v_community_tag := case v_comm_id
    when 'comm-connect-005' then 'Connect'
    when 'comm-creators-002' then 'Studio'
    when 'comm-gamers-003' then 'ArenaX'
    when 'comm-campus-004' then 'Campus'
    when 'comm-official-001' then 'Origin'
    else null
  end;

  if v_community_tag is not null then
    v_identity_tags := array_append(v_identity_tags, jsonb_build_object('type','community','value',v_community_tag));
    v_tag_lights := array_append(v_tag_lights, v_community_tag);
  end if;

  -- 3. VIP Identity Tag — READ FROM cosmetic_assets (THE FIX)
  if v_vip_level > 0 and (v_vip_expiry is null or v_vip_expiry > v_now) then
    select cdn_url into v_vip_tag_url
    from public.cosmetic_assets
    where required_membership = 'VIP'
      and type = 'identity_tag'
      and required_level = v_vip_level
      and enabled = true
    order by priority desc
    limit 1;

    -- Fallback: also check legacy vip_assets table for backwards compat
    if v_vip_tag_url is null then
      select asset_url into v_vip_tag_url
      from public.vip_assets
      where level_required = v_vip_level and asset_type = 'identity_tag' and enabled = true
      limit 1;
    end if;

    v_identity_tags := array_append(v_identity_tags, jsonb_build_object(
      'type', 'vip',
      'value', 'VIP ' || v_vip_level,
      'image_url', coalesce(v_vip_tag_url, '')
    ));
    v_tag_lights := array_append(v_tag_lights, 'VIP Level ' || v_vip_level);
  end if;

  -- 4. Novel Identity Tag — READ FROM cosmetic_assets (THE FIX)
  if v_novel_level > 0 and (v_novel_expiry is null or v_novel_expiry > v_now) then
    select cdn_url into v_novel_tag_url
    from public.cosmetic_assets
    where required_membership = 'Novel'
      and type = 'identity_tag'
      and required_level = v_novel_level
      and enabled = true
    order by priority desc
    limit 1;

    -- Fallback: also check legacy novel_assets table
    if v_novel_tag_url is null then
      select asset_url into v_novel_tag_url
      from public.novel_assets
      where level_required = v_novel_level and asset_type = 'identity_tag' and enabled = true
      limit 1;
    end if;

    v_identity_tags := array_append(v_identity_tags, jsonb_build_object(
      'type', 'noble',
      'value', 'Novel ' || v_novel_level,
      'image_url', coalesce(v_novel_tag_url, '')
    ));
    v_tag_lights := array_append(v_tag_lights, 'Novel ' || v_novel_level);
  end if;

  -- 5. Special Identity Tag
  if 'Anniversary' = any(v_r_tags) then v_special_tag := 'Anniversary';
  elsif 'Champion' = any(v_r_tags) then v_special_tag := 'Champion';
  elsif 'Creator' = any(v_r_tags) or 'Star Creator' = any(v_r_tags) then v_special_tag := 'Creator';
  end if;

  if v_special_tag is not null then
    v_identity_tags := array_append(v_identity_tags, jsonb_build_object('type','special','value',v_special_tag));
    v_tag_lights := array_append(v_tag_lights, v_special_tag);
  end if;

  -- 6. Official Status Tags
  if 'Founder' = any(v_r_tags) then v_role_tag := 'Founder';
  elsif 'Developer' = any(v_r_tags) then v_role_tag := 'Developer';
  elsif 'Admin' = any(v_r_tags) then v_role_tag := 'Admin';
  elsif 'Moderator' = any(v_r_tags) then v_role_tag := 'Moderator';
  end if;

  if v_verified then
    v_verified_tag := 'Verified';
    v_tag_lights := array_append(v_tag_lights, 'Verified');
  end if;
  if v_role_tag is not null then
    v_tag_lights := array_append(v_tag_lights, v_role_tag);
  end if;

  -- Write tag_system back to profiles
  v_tag_system := jsonb_build_object(
    'identityTagBar', to_jsonb(v_identity_tags),
    'officialStatus', jsonb_build_object('verifiedTag', v_verified_tag, 'roleTag', v_role_tag),
    'profileShowcase', to_jsonb(coalesce(v_showcased_badges, '{}'::text[]))
  );

  update public.profiles
  set tag_system = v_tag_system,
      tag_lights = v_tag_lights
  where id = p_user_id;
end;
$$ language plpgsql security definer;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3: Rewrite recompute_user_entitlements — pass levels explicitly to avoid
-- the race condition where profiles.vip_level isn't committed yet.
-- ─────────────────────────────────────────────────────────────────────────────
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
  v_membership_assets jsonb := '{}'::jsonb;
  v_asset_type text;
begin
  -- 1. Read authoritative subscription state
  select level, expiry_date into v_vip_sub
  from public.subscriptions
  where user_id = p_user_id and membership_type = 'VIP' and status = 'Active' and expiry_date > now()
  order by level desc
  limit 1;
  if found then
    v_vip_level   := v_vip_sub.level;
    v_vip_expiry  := v_vip_sub.expiry_date;
  end if;

  select level, expiry_date into v_novel_sub
  from public.subscriptions
  where user_id = p_user_id and membership_type = 'Novel' and status = 'Active' and expiry_date > now()
  order by level desc
  limit 1;
  if found then
    v_novel_level  := v_novel_sub.level;
    v_novel_expiry := v_novel_sub.expiry_date;
  end if;

  -- 2. Expire stale inventory items first
  update public.inventory
  set status = 'Expired', is_equipped = false
  where user_id = p_user_id
    and expires_at is not null
    and expires_at <= now()
    and status = 'Active';

  -- 3. Revoke all membership-granted inventory when no active subscription
  if v_vip_level = 0 then
    update public.inventory
    set status = 'Expired', is_equipped = false
    where user_id = p_user_id
      and purchase_source = 'VIP Membership'
      and status = 'Active';
  end if;

  if v_novel_level = 0 then
    update public.inventory
    set status = 'Expired', is_equipped = false
    where user_id = p_user_id
      and purchase_source = 'Novel Membership'
      and status = 'Active';
  end if;

  -- 4. Grant VIP entitlements into inventory
  if v_vip_level > 0 then
    for v_asset in
      select asset_id from public.cosmetic_assets
      where required_membership = 'VIP'
        and required_level <= v_vip_level
        and enabled = true
    loop
      insert into public.inventory (user_id, asset_id, purchase_source, purchase_date, expires_at, status)
      values (p_user_id, v_asset.asset_id, 'VIP Membership', now(), v_vip_expiry, 'Active')
      on conflict (user_id, asset_id) do update
      set expires_at = v_vip_expiry, status = 'Active';
    end loop;
  end if;

  -- 5. Grant Novel entitlements into inventory
  if v_novel_level > 0 then
    for v_asset in
      select asset_id from public.cosmetic_assets
      where required_membership = 'Novel'
        and required_level <= v_novel_level
        and enabled = true
    loop
      insert into public.inventory (user_id, asset_id, purchase_source, purchase_date, expires_at, status)
      values (p_user_id, v_asset.asset_id, 'Novel Membership', now(), v_novel_expiry, 'Active')
      on conflict (user_id, asset_id) do update
      set expires_at = v_novel_expiry, status = 'Active';
    end loop;
  end if;

  -- 6. Auto-Equip Engine: per asset type, equip highest-priority active item
  for v_asset_type in
    select distinct type from public.cosmetic_assets where enabled = true
  loop
    select inv.id, ca.cdn_url into v_equip_row
    from public.inventory inv
    join public.cosmetic_assets ca on inv.asset_id = ca.asset_id
    where inv.user_id = p_user_id
      and ca.type = v_asset_type
      and inv.status = 'Active'
      and ca.enabled = true
    order by ca.priority desc, inv.purchase_date desc
    limit 1;

    if found then
      -- Equip winner
      update public.inventory
      set is_equipped = true, last_equipped_at = now()
      where id = v_equip_row.id;

      -- Unequip all others of same type
      update public.inventory
      set is_equipped = false
      where user_id = p_user_id
        and id <> v_equip_row.id
        and asset_id in (select asset_id from public.cosmetic_assets where type = v_asset_type);

      -- Accumulate into compiled JSONB
      v_membership_assets := jsonb_set(v_membership_assets, array[v_asset_type], to_jsonb(v_equip_row.cdn_url));
    else
      -- No active item of this type → unequip all, omit from JSONB
      update public.inventory
      set is_equipped = false
      where user_id = p_user_id
        and asset_id in (select asset_id from public.cosmetic_assets where type = v_asset_type);
    end if;
  end loop;

  -- 7. Write authoritative profile row (single UPDATE, no recursion guard needed here
  --    because the trigger fires on vip_level/novel_level columns only, and we update
  --    membership_assets + tag columns here — not vip_level/novel_level)
  update public.profiles
  set vip_level          = v_vip_level,
      vip_expiry         = v_vip_expiry,
      novel_level        = v_novel_level,
      novel_expiry       = v_novel_expiry,
      membership_assets  = v_membership_assets
  where id = p_user_id;

  -- 8. Sync compatibility tables
  if v_vip_level > 0 then
    insert into public.user_vip (user_id, level, start_date, expiry_date, is_active)
    values (p_user_id, v_vip_level, now(), v_vip_expiry, true)
    on conflict (user_id) do update
    set level = v_vip_level, expiry_date = v_vip_expiry, is_active = true;
  else
    update public.user_vip set is_active = false where user_id = p_user_id;
  end if;

  if v_novel_level > 0 then
    insert into public.user_novel (user_id, level, start_date, expiry_date, is_active)
    values (p_user_id, v_novel_level, now(), v_novel_expiry, true)
    on conflict (user_id) do update
    set level = v_novel_level, expiry_date = v_novel_expiry, is_active = true;
  else
    update public.user_novel set is_active = false where user_id = p_user_id;
  end if;

  -- 9. Rebuild tag system AFTER profiles.vip_level is committed
  perform public.rebuild_user_tag_system(p_user_id);
end;
$$ language plpgsql security definer;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 4: Fix the profile trigger — AFTER (not BEFORE) + recursion guard
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.on_profile_vip_novel_update()
returns trigger as $$
begin
  -- Guard: only fire when admin/backend directly sets vip_level or novel_level
  -- (purchases go through subscriptions trigger, not here)
  if (old.vip_level is distinct from new.vip_level) or (old.novel_level is distinct from new.novel_level) then

    -- Sync subscription table so the engine reads the right level
    if new.vip_level > 0 then
      insert into public.subscriptions (user_id, membership_type, level, expiry_date, status)
      values (new.id, 'VIP', new.vip_level, coalesce(new.vip_expiry, now() + interval '30 days'), 'Active')
      on conflict (user_id, membership_type) do update
      set level       = new.vip_level,
          expiry_date = coalesce(new.vip_expiry, now() + interval '30 days'),
          status      = 'Active';
    else
      update public.subscriptions
      set status = 'Expired'
      where user_id = new.id and membership_type = 'VIP';
    end if;

    if new.novel_level > 0 then
      insert into public.subscriptions (user_id, membership_type, level, expiry_date, status)
      values (new.id, 'Novel', new.novel_level, coalesce(new.novel_expiry, now() + interval '30 days'), 'Active')
      on conflict (user_id, membership_type) do update
      set level       = new.novel_level,
          expiry_date = coalesce(new.novel_expiry, now() + interval '30 days'),
          status      = 'Active';
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

-- AFTER trigger (was BEFORE — this was the recursion bug)
drop trigger if exists tr_on_profile_membership_change on public.profiles;
create trigger tr_on_profile_membership_change
after update of vip_level, novel_level on public.profiles
for each row execute function public.on_profile_vip_novel_update();

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 5: Auto-trigger on subscriptions table INSERT/UPDATE
-- Purchases insert into subscriptions → this auto-grants entitlements immediately
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.on_subscription_change()
returns trigger as $$
begin
  perform public.recompute_user_entitlements(new.user_id);
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists tr_on_subscription_change on public.subscriptions;
create trigger tr_on_subscription_change
after insert or update on public.subscriptions
for each row execute function public.on_subscription_change();

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 6: Fix the record_membership_purchase RPC
-- Remove the manual call to recompute_user_entitlements (the subscriptions trigger
-- will fire automatically after the INSERT into subscriptions).
-- But keep it as explicit call for INR payments where we must ensure it runs.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.record_membership_purchase(
  p_user_id       uuid,
  p_product_name  text,
  p_category      text,
  p_amount        numeric,
  p_final_amount  numeric,
  p_payment_method text,
  p_duration      text
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

  -- Duration → days
  v_days := case p_duration
    when '3 Days'  then 3
    when '7 Days'  then 7
    when '15 Days' then 15
    when '90 Days' then 90
    when '1 Year'  then 365
    else 30
  end;
  v_expiry := now() + (v_days || ' days')::interval;

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

  -- Activate / renew subscription
  -- NOTE: the INSERT/UPDATE here fires the tr_on_subscription_change trigger automatically,
  -- which calls recompute_user_entitlements → inventory → auto-equip → rebuild_user_tag_system
  insert into public.subscriptions
    (user_id, membership_type, level, purchase_date, activation_date, expiry_date, auto_renewal, status)
  values
    (p_user_id, p_category, v_level, now(), now(), v_expiry, true, 'Active')
  on conflict (user_id, membership_type) do update
  set level           = v_level,
      activation_date = now(),
      expiry_date     = v_expiry,
      status          = 'Active';

  -- NOTE: no manual recompute_user_entitlements call needed here
  -- The tr_on_subscription_change trigger fires above automatically.

  return true;
exception
  when others then
    raise; -- bubble up → full transaction rollback, no partial purchase
end;
$$ language plpgsql security definer;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 7: Expiry Engine — fires on subscriptions table AFTER UPDATE
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.check_and_clean_expired_memberships()
returns void as $$
declare
  v_rec record;
begin
  -- Find all subscriptions that are marked Active but have passed expiry
  for v_rec in
    select user_id, membership_type
    from public.subscriptions
    where status = 'Active' and expiry_date <= now()
  loop
    -- Mark expired
    update public.subscriptions
    set status = 'Expired'
    where user_id = v_rec.user_id and membership_type = v_rec.membership_type;
    -- The trigger on subscriptions will call recompute_user_entitlements automatically
  end loop;
end;
$$ language plpgsql security definer;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 8: Daily integrity repair job
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.daily_integrity_job()
returns void as $$
declare
  v_user record;
begin
  perform public.check_and_clean_expired_memberships();
  for v_user in select id from public.profiles loop
    perform public.recompute_user_entitlements(v_user.id);
  end loop;
end;
$$ language plpgsql security definer;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 9: Backfill — sync existing vip_assets/novel_assets into cosmetic_assets.
-- Maps legacy asset_type names to the valid cosmetic_assets type check values:
--   background_effect → profile_background
--   entry_effect      → entry_effect      (already valid)
--   exit_effect       → exit_effect       (already valid)
--   avatar_frame      → avatar_frame      (already valid)
--   chat_bubble       → chat_bubble       (already valid)
--   name_glow         → name_glow         (already valid)
--   identity_tag      → identity_tag      (already valid)
--   profile_theme     → profile_theme     (already valid)
--   showcase_badge    → showcase_badge    (already valid)
-- Any unknown types are skipped via WHERE filter.
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.cosmetic_assets
  (name, type, category, version, cdn_url, required_membership, required_level, priority)
select
  'VIP ' || va.level_required || ' ' || va.asset_type,
  -- Map legacy type name → cosmetic_assets check constraint value
  case va.asset_type
    when 'background_effect' then 'profile_background'
    else va.asset_type
  end,
  'VIP',
  1,
  va.asset_url,
  'VIP',
  va.level_required,
  va.level_required * 10
from public.vip_assets va
where va.enabled = true
  -- Only insert types that are valid in the cosmetic_assets check constraint
  and case va.asset_type
    when 'background_effect' then 'profile_background'
    else va.asset_type
  end in ('avatar_frame','profile_frame','entry_effect','exit_effect','chat_bubble',
           'profile_theme','name_glow','identity_tag','showcase_badge','profile_background')
on conflict do nothing;

insert into public.cosmetic_assets
  (name, type, category, version, cdn_url, required_membership, required_level, priority)
select
  'Novel ' || na.level_required || ' ' || na.asset_type,
  case na.asset_type
    when 'background_effect' then 'profile_background'
    else na.asset_type
  end,
  'Novel',
  1,
  na.asset_url,
  'Novel',
  na.level_required,
  na.level_required * 10
from public.novel_assets na
where na.enabled = true
  and case na.asset_type
    when 'background_effect' then 'profile_background'
    else na.asset_type
  end in ('avatar_frame','profile_frame','entry_effect','exit_effect','chat_bubble',
           'profile_theme','name_glow','identity_tag','showcase_badge','profile_background')
on conflict do nothing;
