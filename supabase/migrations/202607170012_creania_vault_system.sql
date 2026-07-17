-- 202607170012_creania_vault_system.sql

-- 1. Create asset_definitions table first
create table if not exists public.asset_definitions (
  id uuid default gen_random_uuid() primary key,
  category text not null check (category in ('Premium', 'Cosmetics', 'Effects', 'Tickets', 'Coupons', 'Boxes', 'Currency Packs', 'Collectibles', 'General', 'VIP', 'Novel', 'Community')),
  sub_category text not null,
  display_name text not null,
  short_description text,
  long_description text,
  thumbnail_url text,
  animation_url text,
  preview_url text,
  rarity text default 'Common' not null check (rarity in ('Common', 'Rare', 'Epic', 'Legendary', 'Mythic')),
  level_requirement integer default 0 not null,
  vip_requirement integer default 0 not null,
  creator_requirement boolean default false not null,
  tradable boolean default false not null,
  giftable boolean default true not null,
  marketable boolean default false not null,
  stackable boolean default true not null,
  consumable boolean default false not null,
  permanent boolean default true not null,
  duration_seconds bigint,
  auto_activate boolean default false not null,
  cooldown_seconds integer,
  custom_properties jsonb default '{}'::jsonb not null,
  enabled boolean default true not null,
  priority integer default 0 not null,
  visibility text default 'Public' not null check (visibility in ('Public', 'Hidden')),
  created_at timestamp with time zone default now() not null
);

-- Enable RLS on asset_definitions
alter table public.asset_definitions enable row level security;
create policy "Anyone can select active asset definitions" on public.asset_definitions for select using (enabled = true);

-- 2. Populate asset_definitions from legacy cosmetic_assets if it exists
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'cosmetic_assets') then
    insert into public.asset_definitions (
      id, display_name, category, sub_category, thumbnail_url, preview_url, animation_url,
      level_requirement, vip_requirement, enabled, priority, visibility, permanent, created_at
    )
    select
      asset_id,
      name,
      category,
      type,
      thumbnail_url,
      preview_url,
      animation_url,
      required_level,
      case when required_membership = 'VIP' then 1 else 0 end,
      enabled,
      priority,
      visibility,
      case when expiry_rule = 'Permanent' then true else false end,
      created_at
    from public.cosmetic_assets
    on conflict (id) do nothing;
  end if;
end;
$$;

-- 3. Create vault_items table
create table if not exists public.vault_items (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  asset_id uuid references public.asset_definitions(id) on delete cascade not null,
  quantity integer default 1 not null,
  status text default 'Unlocked' not null check (status in ('Locked', 'Unlocked', 'Activated', 'Expired', 'Consumed', 'Gifted', 'Transferred', 'Sold')),
  purchase_source text,
  purchase_date timestamp with time zone default now() not null,
  expires_at timestamp with time zone,
  activated_at timestamp with time zone,
  is_equipped boolean default false not null,
  last_equipped_at timestamp with time zone,
  custom_metadata jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  unique (user_id, asset_id)
);

-- Enable RLS on vault_items
alter table public.vault_items enable row level security;
create policy "Users can select their own vault items" on public.vault_items for select using (auth.uid() = user_id);
create policy "Users can update their own vault items" on public.vault_items for update using (auth.uid() = user_id);

-- 4. Populate vault_items from legacy inventory if it exists
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'inventory') then
    insert into public.vault_items (
      id, user_id, asset_id, quantity, status, purchase_source, purchase_date, expires_at, is_equipped, last_equipped_at
    )
    select
      id,
      user_id,
      asset_id,
      1,
      case when status = 'Active' then 'Activated'::text else 'Expired'::text end,
      purchase_source,
      purchase_date,
      expires_at,
      is_equipped,
      last_equipped_at
    from public.inventory
    on conflict (user_id, asset_id) do update set
      status = EXCLUDED.status,
      expires_at = EXCLUDED.expires_at,
      is_equipped = EXCLUDED.is_equipped,
      last_equipped_at = EXCLUDED.last_equipped_at;
  end if;
end;
$$;

-- 5. Create vault_item_history table (Audit Log Ledger)
create table if not exists public.vault_item_history (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  vault_item_id uuid references public.vault_items(id) on delete cascade not null,
  action_type text not null check (action_type in ('Received', 'Activated', 'Equipped', 'Unequipped', 'Expired', 'Consumed', 'Gifted', 'Transferred', 'Sold')),
  quantity integer default 1 not null,
  details jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null
);

-- Enable RLS on vault_item_history
alter table public.vault_item_history enable row level security;
create policy "Users can view their own vault history" on public.vault_item_history for select using (auth.uid() = user_id);

-- 6. Setup Backward Compatibility views
-- Drop old tables and recreate them as views
drop table if exists public.inventory cascade;
drop table if exists public.cosmetic_assets cascade;

-- A. cosmetic_assets View
create or replace view public.cosmetic_assets as
select
  id as asset_id,
  display_name as name,
  sub_category as type,
  category,
  1 as version,
  coalesce(thumbnail_url, '') as cdn_url,
  preview_url,
  thumbnail_url,
  animation_url,
  case when vip_requirement > 0 then 'VIP'::text else 'None'::text end as required_membership,
  level_requirement as required_level,
  enabled,
  priority,
  visibility,
  case when permanent then 'Permanent'::text else 'Rental'::text end as expiry_rule,
  created_at
from public.asset_definitions;

-- B. cosmetic_assets View Trigger for writes (achievements, inserts)
create or replace function public.sync_cosmetic_assets_view_to_definitions()
returns trigger as $$
begin
  if TG_OP = 'INSERT' then
    insert into public.asset_definitions (
      id, display_name, category, sub_category, thumbnail_url, preview_url, animation_url, 
      vip_requirement, level_requirement, enabled, priority, visibility, permanent
    ) values (
      coalesce(NEW.asset_id, gen_random_uuid()),
      NEW.name,
      coalesce(NEW.category, 'Cosmetics'),
      NEW.type,
      NEW.thumbnail_url,
      NEW.preview_url,
      NEW.animation_url,
      case when NEW.required_membership = 'VIP' then 1 else 0 end,
      coalesce(NEW.required_level, 0),
      coalesce(NEW.enabled, true),
      coalesce(NEW.priority, 0),
      coalesce(NEW.visibility, 'Public'),
      case when NEW.expiry_rule = 'Permanent' then true else false end
    );
    return NEW;
  elsif TG_OP = 'UPDATE' then
    update public.asset_definitions set
      display_name = NEW.name,
      sub_category = NEW.type,
      category = NEW.category,
      thumbnail_url = NEW.thumbnail_url,
      preview_url = NEW.preview_url,
      animation_url = NEW.animation_url,
      vip_requirement = case when NEW.required_membership = 'VIP' then 1 else 0 end,
      level_requirement = coalesce(NEW.required_level, 0),
      enabled = coalesce(NEW.enabled, true),
      priority = coalesce(NEW.priority, 0),
      visibility = coalesce(NEW.visibility, 'Public'),
      permanent = case when NEW.expiry_rule = 'Permanent' then true else false end
    where id = OLD.asset_id;
    return NEW;
  elsif TG_OP = 'DELETE' then
    delete from public.asset_definitions where id = OLD.asset_id;
    return OLD;
  end if;
  return null;
end;
$$ language plpgsql;

create trigger cosmetic_assets_view_trigger
instead of insert or update or delete on public.cosmetic_assets
for each row execute function public.sync_cosmetic_assets_view_to_definitions();

-- C. inventory View
create or replace view public.inventory as
select 
  id,
  user_id,
  asset_id,
  coalesce(purchase_source, 'Purchase') as purchase_source,
  purchase_date,
  expires_at,
  case when status in ('Activated', 'Unlocked') then 'Active'::text else 'Expired'::text end as status,
  is_equipped,
  last_equipped_at
from public.vault_items;

-- D. inventory View Trigger for legacy writes (entitlements, updates)
create or replace function public.sync_inventory_view_to_vault()
returns trigger as $$
begin
  if TG_OP = 'INSERT' then
    insert into public.vault_items (
      id, user_id, asset_id, quantity, status, purchase_source, purchase_date, expires_at, is_equipped, last_equipped_at
    ) values (
      coalesce(NEW.id, gen_random_uuid()),
      NEW.user_id,
      NEW.asset_id,
      1,
      case when NEW.status = 'Active' then 'Activated'::text else 'Expired'::text end,
      NEW.purchase_source,
      coalesce(NEW.purchase_date, now()),
      NEW.expires_at,
      coalesce(NEW.is_equipped, false),
      NEW.last_equipped_at
    )
    on conflict (user_id, asset_id) do update set
      status = EXCLUDED.status,
      expires_at = EXCLUDED.expires_at,
      is_equipped = EXCLUDED.is_equipped,
      last_equipped_at = EXCLUDED.last_equipped_at;
    return NEW;
  elsif TG_OP = 'UPDATE' then
    update public.vault_items set
      status = case when NEW.status = 'Active' then 'Activated'::text else 'Expired'::text end,
      expires_at = NEW.expires_at,
      is_equipped = NEW.is_equipped,
      last_equipped_at = NEW.last_equipped_at,
      updated_at = now()
    where id = OLD.id;
    return NEW;
  elsif TG_OP = 'DELETE' then
    delete from public.vault_items where id = OLD.id;
    return OLD;
  end if;
  return null;
end;
$$ language plpgsql;

create trigger inventory_view_trigger
instead of insert or update or delete on public.inventory
for each row execute function public.sync_inventory_view_to_vault();


-- 7. Stored Procedures / RPC APIs for Vault Operations

-- A. Retrieve User Vault
create or replace function public.get_user_vault()
returns table (
  id uuid,
  asset_id uuid,
  category text,
  sub_category text,
  display_name text,
  short_description text,
  long_description text,
  thumbnail_url text,
  animation_url text,
  preview_url text,
  rarity text,
  quantity integer,
  status text,
  purchase_source text,
  purchase_date timestamp with time zone,
  expires_at timestamp with time zone,
  activated_at timestamp with time zone,
  is_equipped boolean,
  last_equipped_at timestamp with time zone,
  custom_metadata jsonb,
  tradable boolean,
  giftable boolean,
  stackable boolean,
  consumable boolean,
  permanent boolean,
  duration_seconds bigint
) as $$
begin
  return query
  select 
    vi.id,
    vi.asset_id,
    ad.category,
    ad.sub_category,
    ad.display_name,
    ad.short_description,
    ad.long_description,
    ad.thumbnail_url,
    ad.animation_url,
    ad.preview_url,
    ad.rarity,
    vi.quantity,
    vi.status,
    vi.purchase_source,
    vi.purchase_date,
    vi.expires_at,
    vi.activated_at,
    vi.is_equipped,
    vi.last_equipped_at,
    vi.custom_metadata,
    ad.tradable,
    ad.giftable,
    ad.stackable,
    ad.consumable,
    ad.permanent,
    ad.duration_seconds
  from public.vault_items vi
  join public.asset_definitions ad on vi.asset_id = ad.id
  where vi.user_id = auth.uid() and ad.enabled = true
  order by vi.created_at desc;
end;
$$ language plpgsql security definer;

-- B. Activate Vault Item (Equipping cosmetics, consumable items)
create or replace function public.activate_vault_item(p_item_id uuid)
returns jsonb as $$
declare
  v_item record;
  v_asset record;
  v_new_expiry timestamp with time zone;
begin
  -- Fetch vault item
  select * into v_item from public.vault_items where id = p_item_id and user_id = auth.uid();
  if not found then
    return jsonb_build_object('success', false, 'reason', 'Item not found in your vault.');
  end if;

  -- Fetch asset definition
  select * into v_asset from public.asset_definitions where id = v_item.asset_id;

  -- 1. Equipping Cosmetic Items (Avatar Frame, Bubble, Theme)
  if v_asset.category = 'Cosmetics' or v_asset.category = 'Effects' then
    -- Unequip all items of same sub_category
    update public.vault_items vi
    set is_equipped = false
    from public.asset_definitions ad
    where vi.asset_id = ad.id 
      and vi.user_id = auth.uid() 
      and ad.sub_category = v_asset.sub_category
      and vi.id != p_item_id;

    -- Toggle equip state
    update public.vault_items 
    set is_equipped = not is_equipped,
        last_equipped_at = case when not is_equipped then now() else null end,
        activated_at = coalesce(activated_at, now()),
        status = 'Activated',
        expires_at = case 
          when not is_equipped and not v_asset.permanent and expires_at is null then 
            now() + (v_asset.duration_seconds || ' seconds')::interval
          else expires_at
        end
    where id = p_item_id;

    -- Insert log
    insert into public.vault_item_history (user_id, vault_item_id, action_type, quantity, details)
    values (
      auth.uid(), 
      p_item_id, 
      case when not v_item.is_equipped then 'Equipped'::text else 'Unequipped'::text end, 
      1, 
      jsonb_build_object('asset_name', v_asset.display_name, 'sub_category', v_asset.sub_category)
    );

    -- Sync user profile tags/showcase system to update instantly
    if exists (select 1 from pg_proc where proname = 'rebuild_user_tag_system') then
      perform public.rebuild_user_tag_system(auth.uid());
    end if;

    return jsonb_build_object('success', true, 'action', 'equipped', 'is_equipped', not v_item.is_equipped);
  end if;

  -- 2. Consumable Items (Coupons, Mystery Boxes, Spin Tickets, Vouchers)
  if v_item.quantity <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Insufficient item quantity.');
  end if;

  -- Deduct quantity
  update public.vault_items 
  set quantity = quantity - 1,
      status = case when quantity - 1 = 0 then 'Consumed'::text else status end
  where id = p_item_id;

  -- Log consumption
  insert into public.vault_item_history (user_id, vault_item_id, action_type, quantity, details)
  values (auth.uid(), p_item_id, 'Consumed', 1, jsonb_build_object('asset_name', v_asset.display_name));

  -- Apply voucher benefits (e.g. VIP/Novel membership)
  if v_asset.category = 'Premium' then
    if v_asset.sub_category = 'VIP Voucher' then
      -- Add 30 Days of VIP membership
      insert into public.subscriptions (user_id, membership_type, level, expiry_date, status)
      values (
        auth.uid(), 
        'VIP', 
        coalesce((v_asset.custom_properties->>'vip_level')::int, 1), 
        now() + interval '30 days', 
        'Active'
      )
      on conflict (user_id, membership_type) do update set
        expiry_date = case when subscriptions.expiry_date > now() then subscriptions.expiry_date + interval '30 days' else now() + interval '30 days' end,
        status = 'Active';
        
      return jsonb_build_object('success', true, 'action', 'consumed', 'benefit', '30 Days VIP membership added');
    elsif v_asset.sub_category = 'Novel Voucher' then
      insert into public.subscriptions (user_id, membership_type, level, expiry_date, status)
      values (
        auth.uid(), 
        'Novel', 
        1, 
        now() + interval '30 days', 
        'Active'
      )
      on conflict (user_id, membership_type) do update set
        expiry_date = case when subscriptions.expiry_date > now() then subscriptions.expiry_date + interval '30 days' else now() + interval '30 days' end,
        status = 'Active';
        
      return jsonb_build_object('success', true, 'action', 'consumed', 'benefit', '30 Days Novel membership added');
    end if;
  end if;

  -- Mystery Box or Lucky Spin Ticket opens directly
  if v_asset.category = 'Boxes' then
    -- Randomly reward Silver or Gold to user
    declare
      v_silver_win integer := (floor(random() * 1000) + 100)::int;
      v_gold_win integer := (floor(random() * 5) + 1)::int;
    begin
      -- Deposit reward
      update public.wallets set silver_balance = silver_balance + v_silver_win where user_id = auth.uid();
      return jsonb_build_object(
        'success', true, 
        'action', 'consumed', 
        'reward_type', 'box_contents', 
        'silver', v_silver_win,
        'gold', v_gold_win,
        'benefit', 'Mystery Box opened!'
      );
    end;
  end if;

  return jsonb_build_object('success', true, 'action', 'consumed', 'benefit', 'Item consumed successfully');
end;
$$ language plpgsql security definer;

-- C. Gift Vault Item (Transfer ownership)
create or replace function public.gift_vault_item(p_item_id uuid, p_receiver_id uuid)
returns jsonb as $$
declare
  v_item record;
  v_asset record;
begin
  -- Validate receiver exists
  if not exists (select 1 from public.profiles where id = p_receiver_id) then
    return jsonb_build_object('success', false, 'reason', 'Receiver profile not found.');
  end if;

  -- Block gifting to self
  if p_receiver_id = auth.uid() then
    return jsonb_build_object('success', false, 'reason', 'Cannot gift items to yourself.');
  end if;

  -- Fetch vault item
  select * into v_item from public.vault_items where id = p_item_id and user_id = auth.uid();
  if not found then
    return jsonb_build_object('success', false, 'reason', 'Item not found in your vault.');
  end if;

  -- Fetch asset definition
  select * into v_asset from public.asset_definitions where id = v_item.asset_id;

  -- Validate item is giftable
  if not v_asset.giftable then
    return jsonb_build_object('success', false, 'reason', 'This item is not giftable.');
  end if;

  -- Enforce quantity logic
  if v_item.quantity <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Insufficient item quantity.');
  end if;

  -- 1. Deduct quantity from Sender
  update public.vault_items 
  set quantity = quantity - 1,
      status = case when quantity - 1 = 0 then 'Gifted'::text else status end
  where id = p_item_id;

  -- Log sender history
  insert into public.vault_item_history (user_id, vault_item_id, action_type, quantity, details)
  values (auth.uid(), p_item_id, 'Gifted', 1, jsonb_build_object('receiver_id', p_receiver_id, 'asset_name', v_asset.display_name));

  -- 2. Insert or Stack into Receiver Vault
  insert into public.vault_items (
    user_id, asset_id, quantity, status, purchase_source, purchase_date, expires_at
  ) values (
    p_receiver_id,
    v_item.asset_id,
    1,
    'Unlocked',
    'Gifted',
    now(),
    v_item.expires_at
  )
  on conflict (user_id, asset_id) do update set
    quantity = vault_items.quantity + 1,
    status = 'Unlocked',
    expires_at = EXCLUDED.expires_at;

  -- Log receiver history
  declare
    v_receiver_item_id uuid;
  begin
    select id into v_receiver_item_id from public.vault_items where user_id = p_receiver_id and asset_id = v_item.asset_id;
    insert into public.vault_item_history (user_id, vault_item_id, action_type, quantity, details)
    values (p_receiver_id, v_receiver_item_id, 'Received', 1, jsonb_build_object('sender_id', auth.uid(), 'asset_name', v_asset.display_name));
  end;

  return jsonb_build_object('success', true, 'reason', 'Item successfully gifted!');
end;
$$ language plpgsql security definer;

-- D. Retrieve User Vault History logs
create or replace function public.get_vault_history()
returns table (
  id uuid,
  action_type text,
  quantity integer,
  details jsonb,
  created_at timestamp with time zone,
  asset_name text,
  thumbnail_url text,
  rarity text
) as $$
begin
  return query
  select 
    vh.id,
    vh.action_type,
    vh.quantity,
    vh.details,
    vh.created_at,
    ad.display_name,
    ad.thumbnail_url,
    ad.rarity
  from public.vault_item_history vh
  join public.vault_items vi on vh.vault_item_id = vi.id
  join public.asset_definitions ad on vi.asset_id = ad.id
  where vh.user_id = auth.uid()
  order by vh.created_at desc;
end;
$$ language plpgsql security definer;


-- 8. Admin APIs for Vault Grants

-- A. Grant Asset to User
create or replace function public.admin_grant_vault_asset(p_user_id uuid, p_asset_id uuid, p_qty integer, p_duration_seconds bigint)
returns jsonb as $$
declare
  v_expiry timestamp with time zone := null;
begin
  -- Validate admin status
  if not exists (select 1 from public.admins where id = auth.uid()) then
    return jsonb_build_object('success', false, 'reason', 'Unauthorized admin action.');
  end if;

  if p_duration_seconds > 0 then
    v_expiry := now() + (p_duration_seconds || ' seconds')::interval;
  end if;

  insert into public.vault_items (
    user_id, asset_id, quantity, status, purchase_source, purchase_date, expires_at
  ) values (
    p_user_id,
    p_asset_id,
    p_qty,
    'Unlocked',
    'Admin Grant',
    now(),
    v_expiry
  )
  on conflict (user_id, asset_id) do update set
    quantity = vault_items.quantity + p_qty,
    expires_at = v_expiry;

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;
