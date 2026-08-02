-- 202607250008_atomic_equip_item_rpc.sql
-- Atomic equip/unequip item RPC (prevents race conditions from separate update + upsert)
-- Also adds missing index for fast equipped-item lookups

-- Ensure unique constraint for equipped item per category per user exists
do $$
begin
  if not exists (
    select 1 from pg_index i join pg_class c on c.oid = i.indexrelid
    where c.relname = 'idx_user_customizations_single_equipped'
  ) then
    create unique index idx_user_customizations_single_equipped
      on public.user_customizations (user_id, type) where is_equipped = true;
  end if;
end $$;

-- Atomic equip_item_rpc: unequip old + upsert new in one transaction
create or replace function public.equip_item_rpc(
  p_user_id   uuid,
  p_category  text,
  p_item_name text,
  p_asset_id  text default null,
  p_path      text default null
)
returns jsonb as $$
declare
  v_vip_level    integer;
  v_novel_level  integer;
  v_vip_expiry   timestamp with time zone;
  v_novel_expiry timestamp with time zone;
begin
  if p_user_id is null or p_category is null or p_item_name is null then
    raise exception 'equip_item_rpc: missing required parameters';
  end if;

  -- Validate VIP/Novel subscription status for premium items before equipping
  select vip_level, vip_expiry, novel_level, novel_expiry
  into v_vip_level, v_vip_expiry, v_novel_level, v_novel_expiry
  from public.profiles
  where id = p_user_id;

  -- Note: Free/default items don't need VIP/Novel check — they can always be equipped.
  -- Frontend validates access; here we only block if item is categorically VIP-gated
  -- and the user's VIP has expired according to server time.
  if p_item_name ilike 'VIP%' or p_item_name ilike 'Royal%' or p_item_name ilike 'Neon%' or
     p_item_name ilike 'Gold Glow%' or p_item_name ilike 'Diamond%' or p_item_name ilike 'Crystal%' or
     p_item_name ilike 'Rainbow%' or p_item_name ilike 'Royal Crown%' then
    -- VIP item check
    if v_vip_level is null or v_vip_level <= 0 or v_vip_expiry is null or v_vip_expiry <= now() then
      -- Allow only if the item exists in inventory (already owned / purchased before)
      if not exists (
        select 1 from public.user_customizations
        where user_id = p_user_id and name = p_item_name
      ) then
        raise exception 'equip_item_rpc: VIP subscription required or expired for item %', p_item_name;
      end if;
    end if;
  end if;

  -- ATOMIC: Unequip all items of this category for this user, then equip the new one
  update public.user_customizations
  set is_equipped = false
  where user_id = p_user_id and type = p_category and is_equipped = true;

  -- Upsert the new item as equipped
  insert into public.user_customizations (user_id, type, name, is_equipped, asset_id, path)
  values (p_user_id, p_category, p_item_name, true,
          p_asset_id, p_path)
  on conflict (user_id, type, name)
  do update set
    is_equipped = true,
    asset_id    = coalesce(excluded.asset_id, user_customizations.asset_id),
    path        = coalesce(excluded.path, user_customizations.path);

  -- If Avatar Frame, also update profiles.avatar_frame
  if p_category = 'Avatar Frame' then
    update public.profiles
    set avatar_frame = p_item_name
    where id = p_user_id;
  end if;

  -- Audit log
  insert into public.vip_audit_logs (user_id, action, category, item_name, details)
  values (p_user_id, 'EQUIP_ITEM', p_category, p_item_name,
    jsonb_build_object('asset_id', p_asset_id, 'path', p_path, 'server_time', now()));

  return jsonb_build_object('success', true, 'category', p_category, 'item', p_item_name);
exception
  when others then
    raise;
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function public.equip_item_rpc(uuid, text, text, text, text) to authenticated, service_role;

-- Atomic unequip_item_rpc: unequip all items of a category
create or replace function public.unequip_item_rpc(
  p_user_id  uuid,
  p_category text
)
returns jsonb as $$
begin
  if p_user_id is null or p_category is null then
    raise exception 'unequip_item_rpc: missing required parameters';
  end if;

  update public.user_customizations
  set is_equipped = false
  where user_id = p_user_id and type = p_category;

  -- If Avatar Frame, also reset profiles.avatar_frame
  if p_category = 'Avatar Frame' then
    update public.profiles
    set avatar_frame = 'Normal'
    where id = p_user_id;
  end if;

  return jsonb_build_object('success', true, 'category', p_category);
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function public.unequip_item_rpc(uuid, text) to authenticated, service_role;
