-- 202607090020_enterprise_entitlement_system.sql
-- Enterprise Supabase Backend Driven VIP, Novel, Asset, Purchase & Entitlement System

-- 1. Drop existing triggers & functions that will be replaced
drop trigger if exists profile_membership_change_trigger on public.profiles;
drop trigger if exists sync_vip_to_profile_trigger on public.user_vip;
drop trigger if exists sync_novel_to_profile_trigger on public.user_novel;
drop function if exists public.on_profile_membership_change() cascade;
drop function if exists public.sync_user_membership_tables_to_profile() cascade;

-- 2. Redesign wallets table to support Gold/Silver coins, Diamonds, Coupons, Rewards, and Cashback
alter table public.wallets add column if not exists gold_coins integer default 0 check (gold_coins >= 0);
alter table public.wallets add column if not exists silver_coins integer default 0 check (silver_coins >= 0);
alter table public.wallets add column if not exists diamonds integer default 0 check (diamonds >= 0);
alter table public.wallets add column if not exists coupons integer default 0 check (coupons >= 0);
alter table public.wallets add column if not exists rewards numeric(10, 2) default 0.00 check (rewards >= 0.00);
alter table public.wallets add column if not exists cashback numeric(10, 2) default 0.00 check (cashback >= 0.00);

-- Sync existing coins_balance to gold_coins
update public.wallets set gold_coins = coalesce(coins_balance, 0) where gold_coins = 0;

-- 3. Redesign wallet_transactions table
drop table if exists public.wallet_transactions cascade;
create table public.wallet_transactions (
  id uuid default gen_random_uuid() primary key,
  wallet_id uuid references public.wallets(id) on delete cascade not null,
  amount numeric not null,
  currency text not null check (currency in ('Gold Coins', 'Silver Coins', 'Diamonds', 'Coupons', 'Rewards', 'Cashback', 'INR')),
  type text not null check (type in ('Recharge', 'Spend', 'Gift', 'Refund', 'Bonus', 'Admin Grant', 'Purchase', 'Withdrawal')),
  status text default 'Completed' not null check (status in ('Completed', 'Pending', 'Failed')),
  reference_id text,
  details text,
  created_at timestamp with time zone default now() not null
);

alter table public.wallet_transactions enable row level security;
create policy "Users can view their transactions" on public.wallet_transactions for select using (auth.uid() = wallet_id);

-- 4. Create Unified Cosmetic Assets Table
drop table if exists public.cosmetic_assets cascade;
create table public.cosmetic_assets (
  asset_id uuid default gen_random_uuid() primary key,
  name text not null,
  type text not null check (type in ('avatar_frame', 'profile_frame', 'entry_effect', 'exit_effect', 'chat_bubble', 'profile_theme', 'name_glow', 'identity_tag', 'showcase_badge', 'profile_background')),
  category text not null check (category in ('VIP', 'Novel', 'General', 'Community')),
  version integer default 1 not null,
  cdn_url text not null,
  preview_url text,
  thumbnail_url text,
  animation_url text,
  required_membership text not null check (required_membership in ('VIP', 'Novel', 'None')),
  required_level integer default 0,
  enabled boolean default true not null,
  priority integer default 0 not null,
  visibility text default 'Public' not null check (visibility in ('Public', 'Hidden')),
  expiry_rule text default 'Permanent' not null check (expiry_rule in ('Permanent', 'Rental', 'Limited')),
  created_at timestamp with time zone default now() not null
);

alter table public.cosmetic_assets enable row level security;
create policy "Anyone can select active cosmetic assets" on public.cosmetic_assets for select using (enabled = true);

-- 5. Create Unified Inventory Table
drop table if exists public.inventory cascade;
create table public.inventory (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  asset_id uuid references public.cosmetic_assets(asset_id) on delete cascade not null,
  purchase_source text not null check (purchase_source in ('Purchase', 'VIP Membership', 'Novel Membership', 'Admin Grant')),
  purchase_date timestamp with time zone default now() not null,
  expires_at timestamp with time zone,
  status text default 'Active' not null check (status in ('Active', 'Expired')),
  is_equipped boolean default false not null,
  last_equipped_at timestamp with time zone,
  unique(user_id, asset_id)
);

alter table public.inventory enable row level security;
create policy "Users can select their own inventory" on public.inventory for select using (auth.uid() = user_id);

-- 6. Create Subscriptions Table
drop table if exists public.subscriptions cascade;
create table public.subscriptions (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  membership_type text not null check (membership_type in ('VIP', 'Novel')),
  level integer not null,
  purchase_date timestamp with time zone default now() not null,
  activation_date timestamp with time zone default now() not null,
  expiry_date timestamp with time zone not null,
  auto_renewal boolean default true not null,
  status text default 'Active' not null check (status in ('Active', 'Expired')),
  unique(user_id, membership_type)
);

alter table public.subscriptions enable row level security;
create policy "Users can select their own subscriptions" on public.subscriptions for select using (auth.uid() = user_id or exists (select 1 from public.admins where id = auth.uid()));

-- Helper function to calculate remaining days
create or replace function public.get_membership_remaining_days(p_expiry timestamp with time zone)
returns integer as $$
begin
  return coalesce(greatest(0, date_part('day', p_expiry - now())::integer), 0);
end;
$$ language plpgsql stable;

-- 7. Atomic Entitlement & Auto-Equip Engine
create or replace function public.recompute_user_entitlements(p_user_id uuid)
returns void as $$
declare
  v_vip_sub record;
  v_novel_sub record;
  v_asset record;
  v_user_asset record;
  v_highest_active_vip_level integer := 0;
  v_highest_active_novel_level integer := 0;
  v_vip_expiry timestamp with time zone := null;
  v_novel_expiry timestamp with time zone := null;
  v_membership_assets jsonb := '{}'::jsonb;
begin
  -- 1. Get highest active VIP subscription
  select level, expiry_date into v_vip_sub
  from public.subscriptions
  where user_id = p_user_id and membership_type = 'VIP' and status = 'Active' and expiry_date > now()
  limit 1;
  if found then
    v_highest_active_vip_level := v_vip_sub.level;
    v_vip_expiry := v_vip_sub.expiry_date;
  end if;

  -- 2. Get highest active Novel subscription
  select level, expiry_date into v_novel_sub
  from public.subscriptions
  where user_id = p_user_id and membership_type = 'Novel' and status = 'Active' and expiry_date > now()
  limit 1;
  if found then
    v_highest_active_novel_level := v_novel_sub.level;
    v_novel_expiry := v_novel_sub.expiry_date;
  end if;

  -- 3. Grant entitlement assets to inventory (VIP)
  if v_highest_active_vip_level > 0 then
    for v_asset in 
      select asset_id from public.cosmetic_assets
      where required_membership = 'VIP' and required_level <= v_highest_active_vip_level and enabled = true
    loop
      insert into public.inventory (user_id, asset_id, purchase_source, purchase_date, expires_at, status)
      values (p_user_id, v_asset.asset_id, 'VIP Membership', now(), v_vip_expiry, 'Active')
      on conflict (user_id, asset_id) do update
      set expires_at = v_vip_expiry, status = 'Active';
    end loop;
  end if;

  -- Grant entitlement assets to inventory (Novel)
  if v_highest_active_novel_level > 0 then
    for v_asset in 
      select asset_id from public.cosmetic_assets
      where required_membership = 'Novel' and required_level <= v_highest_active_novel_level and enabled = true
    loop
      insert into public.inventory (user_id, asset_id, purchase_source, purchase_date, expires_at, status)
      values (p_user_id, v_asset.asset_id, 'Novel Membership', now(), v_novel_expiry, 'Active')
      on conflict (user_id, asset_id) do update
      set expires_at = v_novel_expiry, status = 'Active';
    end loop;
  end if;

  -- 4. Expiry checks on inventory items (deactivate expired rentals/limited benefits)
  update public.inventory
  set status = 'Expired', is_equipped = false
  where user_id = p_user_id and expires_at is not null and expires_at <= now() and status = 'Active';

  -- 5. Auto Equip Engine (Highest Priority Wins per Type)
  for v_asset in 
    select distinct type from public.cosmetic_assets
  loop
    -- Find highest priority active unexpired asset of this type in inventory
    select inv.id, ca.cdn_url, ca.asset_id into v_user_asset
    from public.inventory inv
    join public.cosmetic_assets ca on inv.asset_id = ca.asset_id
    where inv.user_id = p_user_id and ca.type = v_asset.type and inv.status = 'Active' and ca.enabled = true
    order by ca.priority desc, inv.purchase_date desc
    limit 1;

    if found then
      -- Equip it
      update public.inventory
      set is_equipped = true, last_equipped_at = now()
      where id = v_user_asset.id;

      -- Unequip other assets of the same type
      update public.inventory
      set is_equipped = false
      where user_id = p_user_id and asset_id in (
        select asset_id from public.cosmetic_assets where type = v_asset.type
      ) and id <> v_user_asset.id;

      -- Set in membership_assets JSONB
      v_membership_assets := jsonb_set(v_membership_assets, array[v_asset.type], to_jsonb(v_user_asset.cdn_url));
    else
      -- Unequip all of this type
      update public.inventory
      set is_equipped = false
      where user_id = p_user_id and asset_id in (
        select asset_id from public.cosmetic_assets where type = v_asset.type
      );
    end if;
  end loop;

  -- 6. Update profiles record with active levels and compiled assets
  update public.profiles
  set vip_level = v_highest_active_vip_level,
      vip_expiry = v_vip_expiry,
      novel_level = v_highest_active_novel_level,
      novel_expiry = v_novel_expiry,
      membership_assets = v_membership_assets
  where id = p_user_id;

  -- 7. Sync compatibility tables (user_vip and user_novel)
  if v_highest_active_vip_level > 0 then
    insert into public.user_vip (user_id, level, start_date, expiry_date, is_active)
    values (p_user_id, v_highest_active_vip_level, now(), v_vip_expiry, true)
    on conflict (user_id) do update
    set level = v_highest_active_vip_level, expiry_date = v_vip_expiry, is_active = true;
  else
    update public.user_vip set is_active = false where user_id = p_user_id;
  end if;

  if v_highest_active_novel_level > 0 then
    insert into public.user_novel (user_id, level, start_date, expiry_date, is_active)
    values (p_user_id, v_highest_active_novel_level, now(), v_novel_expiry, true)
    on conflict (user_id) do update
    set level = v_highest_active_novel_level, expiry_date = v_novel_expiry, is_active = true;
  else
    update public.user_novel set is_active = false where user_id = p_user_id;
  end if;

  -- 8. Rebuild tag system bar (verified flags, etc.)
  perform public.rebuild_user_tag_system(p_user_id);
end;
$$ language plpgsql security definer;

-- 8. Sync trigger for direct updates to profiles by admin
create or replace function public.on_profile_vip_novel_update()
returns trigger as $$
begin
  if (old.vip_level is distinct from new.vip_level) or (old.novel_level is distinct from new.novel_level) then
    -- Sync subscription tables
    if new.vip_level > 0 then
      insert into public.subscriptions (user_id, membership_type, level, expiry_date, status)
      values (new.id, 'VIP', new.vip_level, coalesce(new.vip_expiry, now() + interval '30 days'), 'Active')
      on conflict (user_id, membership_type) do update
      set level = new.vip_level, expiry_date = coalesce(new.vip_expiry, now() + interval '30 days'), status = 'Active';
    else
      update public.subscriptions set status = 'Expired' where user_id = new.id and membership_type = 'VIP';
    end if;

    if new.novel_level > 0 then
      insert into public.subscriptions (user_id, membership_type, level, expiry_date, status)
      values (new.id, 'Novel', new.novel_level, coalesce(new.novel_expiry, now() + interval '30 days'), 'Active')
      on conflict (user_id, membership_type) do update
      set level = new.novel_level, expiry_date = coalesce(new.novel_expiry, now() + interval '30 days'), status = 'Active';
    else
      update public.subscriptions set status = 'Expired' where user_id = new.id and membership_type = 'Novel';
    end if;

    -- Entitlements auto equip
    perform public.recompute_user_entitlements(new.id);
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists tr_on_profile_membership_change on public.profiles;
create trigger tr_on_profile_membership_change
before update of vip_level, novel_level on public.profiles
for each row execute function public.on_profile_vip_novel_update();

-- 9. Expiry Engine
create or replace function public.check_and_clean_expired_memberships()
returns void as $$
declare
  v_rec record;
begin
  for v_rec in 
    select user_id, membership_type from public.subscriptions
    where status = 'Active' and expiry_date <= now()
  loop
    update public.subscriptions
    set status = 'Expired'
    where user_id = v_rec.user_id and membership_type = v_rec.membership_type;

    perform public.recompute_user_entitlements(v_rec.user_id);
  end loop;
end;
$$ language plpgsql security definer;

-- 10. Unified Purchase Service RPC
create or replace function public.record_membership_purchase(
  p_user_id uuid,
  p_product_name text,
  p_category text,
  p_amount numeric,
  p_final_amount numeric,
  p_payment_method text,
  p_duration text
)
returns boolean as $$
declare
  v_level integer;
  v_days integer;
  v_expiry timestamp with time zone;
  v_wallet_balance integer;
  v_price_coins integer;
begin
  if p_user_id is null or p_product_name is null or p_category is null then
    raise exception 'Invalid input parameters';
  end if;

  v_level := coalesce(substring(p_product_name from '[0-9]+')::integer, 1);

  if p_duration = '90 Days' then
    v_days := 90;
  elsif p_duration = '1 Year' then
    v_days := 365;
  else
    v_days := 30;
  end if;
  v_expiry := now() + (v_days || ' days')::interval;

  if p_payment_method = 'Gold Coins Wallet' then
    v_price_coins := p_final_amount::integer;
    
    select gold_coins into v_wallet_balance
    from public.wallets
    where id = p_user_id
    for update;

    if v_wallet_balance is null or v_wallet_balance < v_price_coins then
      raise exception 'Insufficient Gold Coins balance';
    end if;

    update public.wallets
    set gold_coins = gold_coins - v_price_coins,
        coins_balance = coins_balance - v_price_coins
    where id = p_user_id;

    insert into public.wallet_transactions (wallet_id, amount, currency, type, status, details)
    values (p_user_id, v_price_coins, 'Gold Coins', 'Spend', 'Completed', 'Purchased ' || p_product_name);
  end if;

  insert into public.purchases (
    user_id, product_name, category, amount, final_amount, payment_method, status, duration, expiry_date
  )
  values (
    p_user_id, p_product_name, p_category, p_amount, p_final_amount, p_payment_method, 'Success', p_duration, v_expiry
  );

  insert into public.subscriptions (
    user_id, membership_type, level, purchase_date, activation_date, expiry_date, auto_renewal, status
  )
  values (
    p_user_id, p_category, v_level, now(), now(), v_expiry, true, 'Active'
  )
  on conflict (user_id, membership_type) do update
  set level = v_level, activation_date = now(), expiry_date = v_expiry, status = 'Active';

  perform public.recompute_user_entitlements(p_user_id);

  return true;
exception
  when others then
    raise;
end;
$$ language plpgsql security definer;

-- 11. Daily Integrity / Auto Repair Job
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

-- 12. Seed Cosmetic Assets
insert into public.cosmetic_assets (name, type, category, version, cdn_url, required_membership, required_level, priority)
values
  -- VIP 1 Assets
  ('VIP 1 Avatar Frame', 'avatar_frame', 'VIP', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_1_frame.png', 'VIP', 1, 10),
  ('VIP 1 Chat Bubble', 'chat_bubble', 'VIP', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_1_bubble.png', 'VIP', 1, 10),
  ('VIP 1 Name Glow', 'name_glow', 'VIP', 1, '#2563EB', 'VIP', 1, 10),
  ('VIP 1 Identity Tag', 'identity_tag', 'VIP', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/badges/vip_1_tag.png', 'VIP', 1, 10),
  ('VIP 1 Profile Theme', 'profile_theme', 'VIP', 1, 'royal_blue', 'VIP', 1, 10),
  ('VIP 1 Entry Effect', 'entry_effect', 'VIP', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/effects/vip_1_entry.mp4', 'VIP', 1, 10),

  -- VIP 2 Assets
  ('VIP 2 Avatar Frame', 'avatar_frame', 'VIP', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_frame.webp', 'VIP', 2, 20),
  ('VIP 2 Chat Bubble', 'chat_bubble', 'VIP', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_bubble.png', 'VIP', 2, 20),
  ('VIP 2 Name Glow', 'name_glow', 'VIP', 1, '#8B5CF6', 'VIP', 2, 20),
  ('VIP 2 Identity Tag', 'identity_tag', 'VIP', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/badges/vip_2_tag.png', 'VIP', 2, 20),
  ('VIP 2 Profile Theme', 'profile_theme', 'VIP', 1, 'amethyst_purple', 'VIP', 2, 20),
  ('VIP 2 Background Effect', 'profile_background', 'VIP', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_bg.jpg', 'VIP', 2, 20),
  ('VIP 2 Entry Effect', 'entry_effect', 'VIP', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/effects/vip_2_entry.mp4', 'VIP', 2, 20),

  -- Novel 1 Assets
  ('Novel 1 Avatar Frame', 'avatar_frame', 'Novel', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/novel_1_frame.webp', 'Novel', 1, 15),
  ('Novel 1 Chat Bubble', 'chat_bubble', 'Novel', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/novel_1_bubble.png', 'Novel', 1, 15),
  ('Novel 1 Name Glow', 'name_glow', 'Novel', 1, '#3B82F6', 'Novel', 1, 15),
  ('Novel 1 Identity Tag', 'identity_tag', 'Novel', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/badges/novel_1_tag.png', 'Novel', 1, 15),
  ('Novel 1 Profile Theme', 'profile_theme', 'Novel', 1, 'astral_blue', 'Novel', 1, 15),
  ('Novel 1 Entry Effect', 'entry_effect', 'Novel', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/effects/novel_1_entry.mp4', 'Novel', 1, 15)
on conflict do nothing;
