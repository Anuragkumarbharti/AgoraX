-- 202607090022_fix_tag_system_guard_and_pipeline.sql
-- FINAL FIX: Two remaining issues blocking identity tag from appearing after purchase
--
-- Issue 1: check_profile_restricted_columns uses current_setting('role') which returns
--   the SESSION role ('authenticated'), not the FUNCTION execution role.
--   So even SECURITY DEFINER functions that run as 'postgres' get blocked.
--   Fix: use current_user (the effective user during function execution) instead.
--
-- Issue 2: rebuild_user_tag_system is missing "set search_path = public" and
--   "security definer" is declared but the check_profile_restricted_columns BEFORE
--   trigger still fires for the internal UPDATE, blocking tag_system writes.
--
-- Issue 3: recompute_user_entitlements updates profiles.vip_level → fires
--   trigger_profile_rebuild_tag_system (from migration 012) which calls rebuild_user_tag_system.
--   That function runs correctly. BUT tr_on_profile_membership_change also fires,
--   calling recompute_user_entitlements again. The second run does another
--   UPDATE profiles SET membership_assets = ... which fires check_profile_restricted_columns
--   again. All fine as long as the guard uses current_user.
--   Fix: guard must allow 'postgres' (supabase_admin) and function execution contexts.

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1: Fix the restricted-columns guard to use current_user (execution role)
--         instead of current_setting('role') (session role).
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.check_profile_restricted_columns_update()
returns trigger as $$
begin
  if old.tag_lights is distinct from new.tag_lights or
     old.r_tags is distinct from new.r_tags or
     old.badges is distinct from new.badges or
     old.tag_system is distinct from new.tag_system then

    -- Allow only internal backend functions (postgres / supabase_admin / service_role).
    -- Block direct client mutations from 'authenticated' or 'anon' session users.
    -- current_user = the effective role during execution (postgres for SECURITY DEFINER).
    -- current_setting('role') = session role (always 'authenticated' for logged-in users).
    if current_user in ('authenticated', 'anon') then
      raise exception 'You do not have permission to modify restricted profile columns (tag_system, tag_lights, r_tags, badges).';
    end if;
  end if;
  return new;
end;
$$ language plpgsql;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2: Rewrite rebuild_user_tag_system with correct security context
--         + set search_path = public (required for SECURITY DEFINER)
--         + reads identity tags from cosmetic_assets (the unified table)
--         + falls back to vip_assets/novel_assets for backwards compat
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

  if not found then return; end if;
  if v_level is null then v_level := 1; end if;

  -- 1. ID Level Tag
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

  -- 3. VIP Identity Tag — cosmetic_assets first, fall back to vip_assets
  if v_vip_level > 0 and (v_vip_expiry is null or v_vip_expiry > v_now) then
    -- Primary: unified cosmetic_assets table (populated by purchases)
    select cdn_url into v_vip_tag_url
    from public.cosmetic_assets
    where required_membership = 'VIP'
      and type = 'identity_tag'
      and required_level = v_vip_level
      and enabled = true
    order by priority desc
    limit 1;

    -- Fallback: legacy vip_assets (populated by admin SQL grants)
    if v_vip_tag_url is null then
      select asset_url into v_vip_tag_url
      from public.vip_assets
      where level_required = v_vip_level
        and asset_type = 'identity_tag'
        and enabled = true
      limit 1;
    end if;

    v_identity_tags := array_append(v_identity_tags, jsonb_build_object(
      'type', 'vip',
      'value', 'VIP ' || v_vip_level,
      'image_url', coalesce(v_vip_tag_url, '')
    ));
    v_tag_lights := array_append(v_tag_lights, 'VIP Level ' || v_vip_level);
  end if;

  -- 4. Novel Identity Tag — cosmetic_assets first, fall back to novel_assets
  if v_novel_level > 0 and (v_novel_expiry is null or v_novel_expiry > v_now) then
    select cdn_url into v_novel_tag_url
    from public.cosmetic_assets
    where required_membership = 'Novel'
      and type = 'identity_tag'
      and required_level = v_novel_level
      and enabled = true
    order by priority desc
    limit 1;

    if v_novel_tag_url is null then
      select asset_url into v_novel_tag_url
      from public.novel_assets
      where level_required = v_novel_level
        and asset_type = 'identity_tag'
        and enabled = true
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

  -- 6. Official Status Tags (from r_tags)
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

  -- Build and write tag_system
  v_tag_system := jsonb_build_object(
    'identityTagBar', to_jsonb(v_identity_tags),
    'officialStatus', jsonb_build_object('verifiedTag', v_verified_tag, 'roleTag', v_role_tag),
    'profileShowcase', to_jsonb(coalesce(v_showcased_badges, '{}'::text[]))
  );

  -- This UPDATE is safe: function runs as postgres (SECURITY DEFINER),
  -- and the guard now correctly checks current_user, not current_setting('role').
  update public.profiles
  set tag_system  = v_tag_system,
      tag_lights  = v_tag_lights
  where id = p_user_id;
end;
$$ language plpgsql security definer set search_path = public;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3: Fix recompute_user_entitlements to also set search_path correctly
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
  -- 1. Authoritative subscription state
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

  -- 7. Write profiles (only membership_assets + levels here; tag_system written by rebuild_user_tag_system)
  update public.profiles
  set vip_level         = v_vip_level,
      vip_expiry        = v_vip_expiry,
      novel_level       = v_novel_level,
      novel_expiry      = v_novel_expiry,
      membership_assets = v_membership_assets
  where id = p_user_id;

  -- 8. Sync compatibility tables
  if v_vip_level > 0 then
    insert into public.user_vip (user_id, level, start_date, expiry_date, is_active)
    values (p_user_id, v_vip_level, now(), v_vip_expiry, true)
    on conflict (user_id) do update set level = v_vip_level, expiry_date = v_vip_expiry, is_active = true;
  else
    update public.user_vip set is_active = false where user_id = p_user_id;
  end if;

  if v_novel_level > 0 then
    insert into public.user_novel (user_id, level, start_date, expiry_date, is_active)
    values (p_user_id, v_novel_level, now(), v_novel_expiry, true)
    on conflict (user_id) do update set level = v_novel_level, expiry_date = v_novel_expiry, is_active = true;
  else
    update public.user_novel set is_active = false where user_id = p_user_id;
  end if;

  -- 9. Rebuild tag system (tag_system + tag_lights) — called AFTER profiles.vip_level is committed
  --    Note: trigger_profile_rebuild_tag_system also fires from step 7's UPDATE on vip_level.
  --    This explicit call ensures it runs even when vip_level didn't change (e.g. renewal).
  perform public.rebuild_user_tag_system(p_user_id);
end;
$$ language plpgsql security definer set search_path = public;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 4: Backfill — run rebuild_user_tag_system for all existing users so
--         their tag_system reflects the current vip_level/novel_level immediately.
-- ─────────────────────────────────────────────────────────────────────────────
do $$
declare v_user record;
begin
  for v_user in select id from public.profiles loop
    begin
      perform public.rebuild_user_tag_system(v_user.id);
    exception when others then
      raise notice 'rebuild_user_tag_system failed for %: %', v_user.id, sqlerrm;
    end;
  end loop;
end $$;
