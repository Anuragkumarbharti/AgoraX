-- 202607090019_vip_novel_system.sql
-- Backend Driven VIP & Novel Membership, Plans, Assets, and Purchases

-- 1. Create tables
drop table if exists public.vip_plans cascade;
drop table if exists public.novel_plans cascade;

create table public.vip_plans (
  id serial primary key,
  level int unique not null,
  name text not null,
  base_price_inr numeric not null,
  benefits text[] not null
);

create table public.novel_plans (
  id serial primary key,
  level int unique not null,
  name text not null,
  base_price_inr numeric not null,
  benefits text[] not null
);

create table if not exists public.vip_assets (
  asset_id uuid default gen_random_uuid() primary key,
  asset_type text not null,
  asset_url text not null,
  animation_type text,
  rarity text,
  level_required int references public.vip_plans(level) on delete cascade not null,
  enabled boolean default true not null,
  display_priority int default 0 not null
);

create table if not exists public.novel_assets (
  asset_id uuid default gen_random_uuid() primary key,
  asset_type text not null,
  asset_url text not null,
  animation_type text,
  rarity text,
  level_required int references public.novel_plans(level) on delete cascade not null,
  enabled boolean default true not null,
  display_priority int default 0 not null
);

create table if not exists public.user_vip (
  user_id uuid references public.profiles(id) on delete cascade primary key,
  level int references public.vip_plans(level) not null,
  start_date timestamp with time zone default now() not null,
  expiry_date timestamp with time zone not null,
  is_active boolean default true not null
);

create table if not exists public.user_novel (
  user_id uuid references public.profiles(id) on delete cascade primary key,
  level int references public.novel_plans(level) not null,
  start_date timestamp with time zone default now() not null,
  expiry_date timestamp with time zone not null,
  is_active boolean default true not null
);

create table if not exists public.purchases (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  product_name text not null,
  category text not null, -- 'VIP', 'Novel', 'Coins'
  amount numeric not null,
  final_amount numeric not null,
  payment_method text not null,
  status text not null, -- 'Success', 'Failed', 'Refunded'
  duration text not null,
  created_at timestamp with time zone default now() not null,
  expiry_date timestamp with time zone
);

-- Enable RLS on all tables
alter table public.vip_plans enable row level security;
alter table public.novel_plans enable row level security;
alter table public.vip_assets enable row level security;
alter table public.novel_assets enable row level security;
alter table public.user_vip enable row level security;
alter table public.user_novel enable row level security;
alter table public.purchases enable row level security;

-- Setup RLS policies
create policy "Allow select plans for authenticated users" on public.vip_plans for select using (auth.role() = 'authenticated');
create policy "Allow select plans for authenticated users" on public.novel_plans for select using (auth.role() = 'authenticated');

create policy "Allow select assets for authenticated users" on public.vip_assets for select using (auth.role() = 'authenticated');
create policy "Allow select assets for authenticated users" on public.novel_assets for select using (auth.role() = 'authenticated');

create policy "Allow select user_vip for self and admins" on public.user_vip for select using (auth.uid() = user_id or exists (select 1 from public.admins where id = auth.uid()));
create policy "Allow select user_novel for self and admins" on public.user_novel for select using (auth.uid() = user_id or exists (select 1 from public.admins where id = auth.uid()));

create policy "Allow select purchases for self and admins" on public.purchases for select using (auth.uid() = user_id or exists (select 1 from public.admins where id = auth.uid()));

-- 2. Add columns to profiles for compiled assets
alter table public.profiles add column if not exists membership_assets jsonb default '{}'::jsonb;

-- 3. Function to compile and rebuild active cosmetic assets
create or replace function public.rebuild_user_membership_assets(p_user_id uuid)
returns jsonb as $$
declare
  v_vip_level int;
  v_novel_level int;
  v_assets jsonb := '{}'::jsonb;
  v_asset record;
begin
  -- Get user active levels from user_vip / user_novel tables
  select level into v_vip_level 
  from public.user_vip 
  where user_id = p_user_id and is_active = true and expiry_date > now();
  
  select level into v_novel_level 
  from public.user_novel 
  where user_id = p_user_id and is_active = true and expiry_date > now();

  v_vip_level := coalesce(v_vip_level, 0);
  v_novel_level := coalesce(v_novel_level, 0);

  -- Compile VIP assets
  if v_vip_level > 0 then
    for v_asset in 
      select asset_type, asset_url
      from public.vip_assets
      where level_required = v_vip_level and enabled = true
      order by display_priority asc
    loop
      v_assets := jsonb_set(v_assets, array[v_asset.asset_type], to_jsonb(v_asset.asset_url));
    end loop;
  end if;

  -- Compile Novel assets (merge/override if higher priority)
  if v_novel_level > 0 then
    for v_asset in 
      select asset_type, asset_url
      from public.novel_assets
      where level_required = v_novel_level and enabled = true
      order by display_priority asc
    loop
      v_assets := jsonb_set(v_assets, array[v_asset.asset_type], to_jsonb(v_asset.asset_url));
    end loop;
  end if;

  return v_assets;
end;
$$ language plpgsql security definer;

-- 4. Redefine rebuild_user_tag_system to retrieve dynamic tag URLs from assets
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
  
  v_role text;
  v_now timestamp with time zone := now();
  v_tag_system jsonb;
  v_tag_lights text[] := '{}';
begin
  select r_tags, vip_level, vip_expiry, novel_level, novel_expiry, level, verified, showcased_badges
  into v_r_tags, v_vip_level, v_vip_expiry, v_novel_level, v_novel_expiry, v_level, v_verified, v_showcased_badges
  from public.profiles
  where id = p_user_id;

  if v_level is null then
    v_level := 1;
  end if;

  -- 1. ID Level Tag (Fixed)
  v_identity_tags := array_append(v_identity_tags, jsonb_build_object(
    'type', 'id_level',
    'value', 'Lv.' || v_level,
    'image_url', 'asset://assets/identity_tags/id_level_' || v_level || '.png'
  ));
  v_tag_lights := array_append(v_tag_lights, 'ID Level ' || v_level);

  -- 2. Community Tag
  select id into v_comm_id
  from public.communities
  where p_user_id::text = any(members) and id in ('comm-official-001', 'comm-creators-002', 'comm-gamers-003', 'comm-campus-004', 'comm-connect-005')
  order by case id
    when 'comm-connect-005' then 1
    when 'comm-creators-002' then 2
    when 'comm-gamers-003' then 3
    when 'comm-campus-004' then 4
    when 'comm-official-001' then 5
    else 6
  end asc
  limit 1;

  if v_comm_id = 'comm-connect-005' then
    v_community_tag := 'Connect';
  elsif v_comm_id = 'comm-creators-002' then
    v_community_tag := 'Studio';
  elsif v_comm_id = 'comm-gamers-003' then
    v_community_tag := 'ArenaX';
  elsif v_comm_id = 'comm-campus-004' then
    v_community_tag := 'Campus';
  elsif v_comm_id = 'comm-official-001' then
    v_community_tag := 'Origin';
  end if;

  if v_community_tag is not null then
    v_identity_tags := array_append(v_identity_tags, jsonb_build_object('type', 'community', 'value', v_community_tag));
    v_tag_lights := array_append(v_tag_lights, v_community_tag);
  end if;

  -- 3. VIP Tag (Backend-Driven from assets)
  if (v_vip_level > 0 and (v_vip_expiry is null or v_vip_expiry > v_now)) then
    select asset_url into v_vip_tag_url
    from public.vip_assets
    where level_required = v_vip_level and asset_type = 'identity_tag' and enabled = true
    limit 1;

    v_identity_tags := array_append(v_identity_tags, jsonb_build_object(
      'type', 'vip',
      'value', 'VIP ' || v_vip_level,
      'image_url', coalesce(v_vip_tag_url, '')
    ));
    v_tag_lights := array_append(v_tag_lights, 'VIP Level ' || v_vip_level);
  end if;

  -- 4. Noble Tag (Backend-Driven from assets)
  if (v_novel_level > 0 and (v_novel_expiry is null or v_novel_expiry > v_now)) then
    select asset_url into v_novel_tag_url
    from public.novel_assets
    where level_required = v_novel_level and asset_type = 'identity_tag' and enabled = true
    limit 1;

    v_identity_tags := array_append(v_identity_tags, jsonb_build_object(
      'type', 'noble',
      'value', 'Novel ' || v_novel_level,
      'image_url', coalesce(v_novel_tag_url, '')
    ));
    v_tag_lights := array_append(v_tag_lights, 'Novel ' || v_novel_level);
  end if;

  -- 5. Special Identity Tag
  if 'Anniversary' = any(v_r_tags) then
    v_special_tag := 'Anniversary';
  elsif 'Champion' = any(v_r_tags) then
    v_special_tag := 'Champion';
  elsif 'Creator' = any(v_r_tags) or 'Star Creator' = any(v_r_tags) then
    v_special_tag := 'Creator';
  end if;

  if v_special_tag is not null then
    v_identity_tags := array_append(v_identity_tags, jsonb_build_object('type', 'special', 'value', v_special_tag));
    v_tag_lights := array_append(v_tag_lights, v_special_tag);
  end if;

  -- 6. Official Status Tags
  if 'Founder' = any(v_r_tags) then
    v_role_tag := 'Founder';
  elsif 'Developer' = any(v_r_tags) then
    v_role_tag := 'Developer';
  elsif 'Admin' = any(v_r_tags) then
    v_role_tag := 'Admin';
  elsif 'Moderator' = any(v_r_tags) then
    v_role_tag := 'Moderator';
  end if;

  if v_verified then
    v_verified_tag := 'Verified';
    v_tag_lights := array_append(v_tag_lights, 'Verified');
  end if;
  if v_role_tag is not null then
    v_tag_lights := array_append(v_tag_lights, v_role_tag);
  end if;

  v_tag_system := jsonb_build_object(
    'identityTagBar', to_jsonb(v_identity_tags),
    'officialStatus', jsonb_build_object(
      'verifiedTag', v_verified_tag,
      'roleTag', v_role_tag
    ),
    'profileShowcase', to_jsonb(coalesce(v_showcased_badges, '{}'::text[]))
  );

  update public.profiles
  set tag_system = v_tag_system,
      tag_lights = v_tag_lights
  where id = p_user_id;
end;
$$ language plpgsql security definer;

-- 5. Trigger to automatically compile active cosmetic assets and tags when profiles levels change
create or replace function public.on_profile_membership_change()
returns trigger as $$
begin
  new.membership_assets := public.rebuild_user_membership_assets(new.id);
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists profile_membership_change_trigger on public.profiles;
create trigger profile_membership_change_trigger
before insert or update of vip_level, novel_level on public.profiles
for each row execute function public.on_profile_membership_change();

-- 6. Trigger to sync user_vip / user_novel table updates to profiles table
create or replace function public.sync_user_membership_tables_to_profile()
returns trigger as $$
begin
  if TG_TABLE_NAME = 'user_vip' then
    update public.profiles
    set vip_level = case when new.is_active and new.expiry_date > now() then new.level else 0 end,
        vip_expiry = case when new.is_active and new.expiry_date > now() then new.expiry_date else null end
    where id = new.user_id;
    
    -- Rebuild tags for user
    perform public.rebuild_user_tag_system(new.user_id);
    -- Rebuild assets
    update public.profiles
    set membership_assets = public.rebuild_user_membership_assets(new.user_id)
    where id = new.user_id;
  elsif TG_TABLE_NAME = 'user_novel' then
    update public.profiles
    set novel_level = case when new.is_active and new.expiry_date > now() then new.level else 0 end,
        novel_expiry = case when new.is_active and new.expiry_date > now() then new.expiry_date else null end
    where id = new.user_id;
    
    -- Rebuild tags for user
    perform public.rebuild_user_tag_system(new.user_id);
    -- Rebuild assets
    update public.profiles
    set membership_assets = public.rebuild_user_membership_assets(new.user_id)
    where id = new.user_id;
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists sync_vip_to_profile_trigger on public.user_vip;
create trigger sync_vip_to_profile_trigger
after insert or update on public.user_vip
for each row execute function public.sync_user_membership_tables_to_profile();

drop trigger if exists sync_novel_to_profile_trigger on public.user_novel;
create trigger sync_novel_to_profile_trigger
after insert or update on public.user_novel
for each row execute function public.sync_user_membership_tables_to_profile();

-- 7. Expiry checking function (can be run periodically or on login)
create or replace function public.check_and_clean_expired_memberships()
returns void as $$
declare
  v_rec record;
begin
  -- Expire VIPs
  for v_rec in 
    select user_id from public.user_vip
    where is_active = true and expiry_date <= now()
  loop
    update public.user_vip
    set is_active = false
    where user_id = v_rec.user_id;
    
    update public.profiles
    set vip_level = 0,
        vip_expiry = null
    where id = v_rec.user_id;
    
    perform public.rebuild_user_tag_system(v_rec.user_id);
    
    update public.profiles
    set membership_assets = public.rebuild_user_membership_assets(v_rec.user_id)
    where id = v_rec.user_id;
  end loop;

  -- Expire Novels
  for v_rec in 
    select user_id from public.user_novel
    where is_active = true and expiry_date <= now()
  loop
    update public.user_novel
    set is_active = false
    where user_id = v_rec.user_id;
    
    update public.profiles
    set novel_level = 0,
        novel_expiry = null
    where id = v_rec.user_id;
    
    perform public.rebuild_user_tag_system(v_rec.user_id);
    
    update public.profiles
    set membership_assets = public.rebuild_user_membership_assets(v_rec.user_id)
    where id = v_rec.user_id;
  end loop;
end;
$$ language plpgsql security definer;

-- 8. Purchase registration RPC (atomic, ledger logging, membership activation)
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
  v_level int;
  v_expiry timestamp with time zone;
  v_days int;
begin
  -- Parse level from product name
  v_level := coalesce(substring(p_product_name from '[0-9]+')::int, 1);
  
  -- Calculate duration interval
  if p_duration = '90 Days' then
    v_days := 90;
  elsif p_duration = '1 Year' then
    v_days := 365;
  else
    v_days := 30; -- '30 Days' or fallback
  end if;

  v_expiry := now() + (v_days || ' days')::interval;

  -- 1. Insert Purchase Ledger Record
  insert into public.purchases (
    user_id,
    product_name,
    category,
    amount,
    final_amount,
    payment_method,
    status,
    duration,
    expiry_date
  )
  values (
    p_user_id,
    p_product_name,
    p_category,
    p_amount,
    p_final_amount,
    p_payment_method,
    'Success',
    p_duration,
    v_expiry
  );

  -- 2. Upsert Membership mapping
  if p_category = 'VIP' then
    insert into public.user_vip (user_id, level, start_date, expiry_date, is_active)
    values (p_user_id, v_level, now(), v_expiry, true)
    on conflict (user_id) do update
    set level = v_level,
        start_date = now(),
        expiry_date = v_expiry,
        is_active = true;
  elsif p_category = 'Novel' then
    insert into public.user_novel (user_id, level, start_date, expiry_date, is_active)
    values (p_user_id, v_level, now(), v_expiry, true)
    on conflict (user_id) do update
    set level = v_level,
        start_date = now(),
        expiry_date = v_expiry,
        is_active = true;
  end if;

  return true;
end;
$$ language plpgsql security definer;

-- 9. Seed base plans and assets (Levels: VIP 1, VIP 2, Novel 1)
insert into public.vip_plans (level, name, base_price_inr, benefits)
values 
  (1, 'VIP Level 1', 99.0, array['VIP Identity Tag', 'VIP Avatar Frame', 'VIP Name Glow', 'VIP Chat Bubble', 'VIP Entrance Effect']),
  (2, 'VIP Level 2', 199.0, array['Premium Animated Frame', 'Premium Entrance Animation', 'Premium Name Glow', 'Premium Chat Bubble'])
on conflict (level) do update
set name = excluded.name, base_price_inr = excluded.base_price_inr, benefits = excluded.benefits;

insert into public.novel_plans (level, name, base_price_inr, benefits)
values 
  (1, 'Novel Level 1', 199.0, array['Novel Identity Tag', 'Novel Avatar Frame', 'Novel Name Glow', 'Novel Chat Bubble'])
on conflict (level) do update
set name = excluded.name, base_price_inr = excluded.base_price_inr, benefits = excluded.benefits;

-- Seed assets for VIP 1
insert into public.vip_assets (asset_type, asset_url, animation_type, rarity, level_required, display_priority)
values
  ('avatar_frame', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_1_frame.png', 'pulse', 'Rare', 1, 10),
  ('chat_bubble', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_1_bubble.png', 'static', 'Rare', 1, 10),
  ('name_glow', '#2563EB', 'glow', 'Rare', 1, 10),
  ('identity_tag', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/badges/vip_1_tag.png', 'static', 'Rare', 1, 10),
  ('profile_theme', 'royal_blue', 'static', 'Rare', 1, 10)
on conflict do nothing;

-- Seed assets for VIP 2
insert into public.vip_assets (asset_type, asset_url, animation_type, rarity, level_required, display_priority)
values
  ('avatar_frame', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_frame.webp', 'lottie', 'Epic', 2, 20),
  ('chat_bubble', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_bubble.png', 'animated', 'Epic', 2, 20),
  ('name_glow', '#8B5CF6', 'glow_animated', 'Epic', 2, 20),
  ('identity_tag', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/badges/vip_2_tag.png', 'animated', 'Epic', 2, 20),
  ('profile_theme', 'amethyst_purple', 'animated', 'Epic', 2, 20),
  ('background_effect', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_bg.jpg', 'particle', 'Epic', 2, 20)
on conflict do nothing;

-- Seed assets for Novel 1
insert into public.novel_assets (asset_type, asset_url, animation_type, rarity, level_required, display_priority)
values
  ('avatar_frame', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/novel_1_frame.webp', 'static', 'Rare', 1, 15),
  ('chat_bubble', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/novel_1_bubble.png', 'static', 'Rare', 1, 15),
  ('name_glow', '#3B82F6', 'glow', 'Rare', 1, 15),
  ('identity_tag', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/badges/novel_1_tag.png', 'static', 'Rare', 1, 15),
  ('profile_theme', 'astral_blue', 'static', 'Rare', 1, 15)
on conflict do nothing;
