-- 202607170008_community_identity_tag.sql
-- Add identity_tag to communities, enforce uniqueness, and use it in rebuild_user_tag_system.

-- 1. Add column and unique constraint
alter table public.communities add column if not exists identity_tag text;
alter table public.communities drop constraint if exists unique_community_identity_tag;
alter table public.communities add constraint unique_community_identity_tag unique (identity_tag);

-- 2. Update create_community_rpc to accept and store p_identity_tag
create or replace function public.create_community_rpc(
  p_id text,
  p_name text,
  p_description text,
  p_category text,
  p_language text,
  p_country text,
  p_rules text,
  p_join_mode text,
  p_min_id_level integer,
  p_preferred_languages text[],
  p_preferred_countries text[],
  p_preferred_interests text[],
  p_tags text[],
  p_visibility text,
  p_image text,
  p_banner text,
  p_creation_method text,
  p_identity_tag text default null
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_user_level integer;
  v_wallet_record record;
  v_ticket_id uuid;
  v_comm_exists boolean;
  v_already_member boolean;
begin
  -- Authentication check
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  -- Check if already in a community (One Community Rule)
  select exists (
    select 1 from public.community_memberships where user_id = v_user_id
  ) into v_already_member;
  if v_already_member then
    return jsonb_build_object('success', false, 'error', 'You are already a member of a community. You must leave your current community first.');
  end if;

  -- Check if community ID (username) is unique
  select exists (
    select 1 from public.communities where id = p_id
  ) into v_comm_exists;
  if v_comm_exists then
    return jsonb_build_object('success', false, 'error', 'Community Username is already taken.');
  end if;

  -- Validate Identity Tag uniqueness
  if p_identity_tag is not null and p_identity_tag <> '' then
    if exists (
      select 1 from public.communities where lower(identity_tag) = lower(p_identity_tag)
    ) then
      return jsonb_build_object('success', false, 'error', 'Identity Tag is already taken.');
    end if;
  end if;

  -- Validation and deduction based on creation method
  if p_creation_method = 'level' then
    select level into v_user_level from public.profiles where id = v_user_id;
    if v_user_level is null or v_user_level < 25 then
      return jsonb_build_object('success', false, 'error', 'Minimum ID level of 25 is required to create via Level progression.');
    end if;

  elsif p_creation_method = 'ticket' then
    select id into v_ticket_id 
    from public.inventory 
    where user_id = v_user_id 
      and (asset_id = 'community_creation_ticket' or asset_id = 'creation_ticket')
      and status = 'Active' 
    limit 1;

    if v_ticket_id is null then
      return jsonb_build_object('success', false, 'error', 'You do not have a Community Creation Ticket.');
    end if;

    update public.inventory set status = 'Used' where id = v_ticket_id;

  elsif p_creation_method = 'coins' then
    select coins_balance, gold_coins into v_wallet_record from public.wallets where id = v_user_id;
    if v_wallet_record is null or (coalesce(v_wallet_record.gold_coins, 0) < 699 and coalesce(v_wallet_record.coins_balance, 0) < 699) then
      return jsonb_build_object('success', false, 'error', 'Insufficient Gold Coins. 699 Coins are required.');
    end if;

    -- Deduct 699 coins
    update public.wallets 
    set coins_balance = greatest(0, coins_balance - 699),
        gold_coins = greatest(0, gold_coins - 699)
    where id = v_user_id;

    insert into public.wallet_transactions (
      wallet_id, transaction_type, amount, category, description, transaction_date
    ) values (
      v_user_id, 'Debit', 699.00, 'Purchase', 'Community Creation Cost', now()
    );

  else
    return jsonb_build_object('success', false, 'error', 'Invalid creation method. Must be level, coins, or ticket.');
  end if;

  -- Insert community
  insert into public.communities (
    id, name, description, image, banner, category, language, country, rules, 
    join_mode, min_id_level, preferred_languages, preferred_countries, 
    preferred_interests, tags, visibility, owner, is_official, is_verified, 
    level, xp, member_count, created_at, identity_tag
  ) values (
    p_id, p_name, p_description, p_image, p_banner, p_category, p_language, p_country, p_rules,
    p_join_mode, p_min_id_level, p_preferred_languages, p_preferred_countries,
    p_preferred_interests, p_tags, p_visibility, v_user_id, false, false,
    1, 0, 1, now(), p_identity_tag
  );

  -- Insert creator membership
  insert into public.community_memberships (
    community_id, user_id, role, join_method, joined_by
  ) values (
    p_id, v_user_id, 'owner', 'creator', v_user_id
  );

  return jsonb_build_object('success', true, 'community_id', p_id);
end;
$$ language plpgsql security definer set search_path = public;


-- 3. Update rebuild_user_tag_system to use c.identity_tag instead of c.name
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
  v_comm_id text;
  v_comm_name text;
  v_comm_level integer;
  v_comm_is_official boolean;
  v_comm_is_verified boolean;
  v_comm_role text;

  -- Custom tag parameters
  v_tag_color text := '#64748B'; -- default Slate
  v_tag_border text := 'none';
  v_tag_glow text := 'none';
  v_tag_animation text := 'none';
  v_tag_effects text := 'none';
  v_tag_icon text := '🏷️';

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

  -- 2. Community Tag (from memberships, prioritizing c.identity_tag)
  select m.community_id, coalesce(c.identity_tag, c.name), c.level, c.is_official, c.is_verified, m.role
  into v_comm_id, v_comm_name, v_comm_level, v_comm_is_official, v_comm_is_verified, v_comm_role
  from public.community_memberships m
  join public.communities c on m.community_id = c.id
  where m.user_id = p_user_id
  limit 1;

  if v_comm_id is not null then
    -- Backend assigns tag attributes dynamically
    if v_comm_is_official then
      v_tag_color := '#818CF8'; -- Indigo
      v_tag_border := 'rainbow_neon';
      v_tag_glow := 'neon';
      v_tag_animation := 'rotating';
      v_tag_effects := 'stars';
      v_tag_icon := '👑';
    elsif v_comm_level >= 15 then
      v_tag_color := '#FFD700'; -- Gold
      v_tag_border := 'gold_glow';
      v_tag_glow := 'gold';
      v_tag_animation := 'breathing';
      v_tag_effects := 'sparkles';
      v_tag_icon := '🏆';
    elsif v_comm_level >= 10 then
      v_tag_color := '#E2E8F0'; -- Silver
      v_tag_border := 'silver_glow';
      v_tag_glow := 'silver';
      v_tag_animation := 'pulse';
      v_tag_icon := '⭐';
    elsif v_comm_level >= 5 then
      v_tag_color := '#B45309'; -- Bronze
      v_tag_border := 'bronze_glow';
      v_tag_glow := 'bronze';
      v_tag_icon := '🔥';
    else
      v_tag_color := '#64748B'; -- Slate
      v_tag_border := 'none';
      v_tag_glow := 'none';
      v_tag_icon := '🏷️';
    end if;

    v_identity_tags := array_append(v_identity_tags, jsonb_build_object(
      'type', 'community',
      'value', v_comm_name,
      'color', v_tag_color,
      'border', v_tag_border,
      'glow', v_tag_glow,
      'animation', v_tag_animation,
      'effects', v_tag_effects,
      'icon', v_tag_icon
    ));
    v_tag_lights := array_append(v_tag_lights, v_comm_name);
  end if;

  -- 3. VIP Identity Tag
  if v_vip_level > 0 and (v_vip_expiry is null or v_vip_expiry > v_now) then
    select cdn_url into v_vip_tag_url
    from public.cosmetic_assets
    where required_membership = 'VIP'
      and type = 'identity_tag'
    limit 1;

    v_identity_tags := array_append(v_identity_tags, jsonb_build_object(
      'type', 'vip',
      'value', 'VIP ' || v_vip_level,
      'image_url', v_vip_tag_url
    ));
    v_tag_lights := array_append(v_tag_lights, 'VIP ' || v_vip_level);
  end if;

  -- 4. Novel Identity Tag
  if v_novel_level > 0 and (v_novel_expiry is null or v_novel_expiry > v_now) then
    select cdn_url into v_novel_tag_url
    from public.cosmetic_assets
    where required_membership = 'Novel'
      and type = 'identity_tag'
    limit 1;

    v_identity_tags := array_append(v_identity_tags, jsonb_build_object(
      'type', 'novel',
      'value', 'Novel ' || v_novel_level,
      'image_url', v_novel_tag_url
    ));
    v_tag_lights := array_append(v_tag_lights, 'Novel ' || v_novel_level);
  end if;

  -- Build final JSON structure
  v_tag_system := jsonb_build_object(
    'identity_tags', v_identity_tags,
    'tag_lights', v_tag_lights
  );

  update public.profiles
  set tag_system = v_tag_system
  where id = p_user_id;

end;
$$ language plpgsql security definer;
