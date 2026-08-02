-- 202607250006_permanent_inventory_and_entitlements_rpc.sql
-- Unified single-call RPC for StarMaker-style permanent entitlement & inventory loading

create or replace function public.get_user_full_inventory_and_entitlements_rpc(
  p_user_id uuid
)
returns jsonb as $$
declare
  v_vip_sub      record;
  v_novel_sub    record;
  v_profile      record;
  v_inventory    jsonb;
  v_equipped     jsonb;
  v_result       jsonb;
begin
  if p_user_id is null then
    raise exception 'get_user_full_inventory_and_entitlements_rpc: missing p_user_id';
  end if;

  -- 1. Fetch profile state
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

  -- 2. Fetch active VIP subscription
  select level, expiry_date, status
  into v_vip_sub
  from public.subscriptions
  where user_id = p_user_id
    and membership_type = 'VIP'
    and status = 'Active'
    and expiry_date > now()
  order by level desc
  limit 1;

  -- 3. Fetch active Novel subscription
  select level, expiry_date, status
  into v_novel_sub
  from public.subscriptions
  where user_id = p_user_id
    and membership_type = 'Novel'
    and status = 'Active'
    and expiry_date > now()
  order by level desc
  limit 1;

  -- 4. Aggregate full user inventory list
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

  -- 5. Aggregate equipped items
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

  -- 6. Construct final JSON response payload
  v_result := jsonb_build_object(
    'user_id', p_user_id,
    'vip', jsonb_build_object(
      'level', coalesce(v_vip_sub.level, v_profile.vip_level, 0),
      'expiry_date', coalesce(v_vip_sub.expiry_date, v_profile.vip_expiry),
      'is_active', (coalesce(v_vip_sub.level, v_profile.vip_level, 0) > 0 and coalesce(v_vip_sub.expiry_date, v_profile.vip_expiry, now()) > now())
    ),
    'novel', jsonb_build_object(
      'level', coalesce(v_novel_sub.level, v_profile.novel_level, 0),
      'expiry_date', coalesce(v_novel_sub.expiry_date, v_profile.novel_expiry),
      'is_active', (coalesce(v_novel_sub.level, v_profile.novel_level, 0) > 0 and coalesce(v_novel_sub.expiry_date, v_profile.novel_expiry, now()) > now())
    ),
    'profile_frame', v_profile.avatar_frame,
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

grant execute on function public.get_user_full_inventory_and_entitlements_rpc(uuid) to authenticated;
