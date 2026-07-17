-- 202607170002_community_system.sql
-- StarMaker-inspired Community System backend migrations

-- 1. Alter communities table to include additional preferences and settings
alter table public.communities add column if not exists is_official boolean default false;
alter table public.communities add column if not exists join_mode text default 'auto_join'; -- 'auto_join' or 'approval_required'
alter table public.communities add column if not exists language text default 'en';
alter table public.communities add column if not exists country text default 'IN';
alter table public.communities add column if not exists min_id_level integer default 1;
alter table public.communities add column if not exists preferred_languages text[] default '{}';
alter table public.communities add column if not exists preferred_countries text[] default '{}';
alter table public.communities add column if not exists preferred_interests text[] default '{}';
alter table public.communities add column if not exists tags text[] default '{}';
alter table public.communities add column if not exists visibility text default 'public'; -- 'public' or 'private'

-- Update seeded official communities to be marked is_official = true
update public.communities
set is_official = true,
    is_verified = true
where id in ('comm-official-001','comm-creators-002','comm-gamers-003','comm-campus-004','comm-connect-005') or type = 'Official';

-- 2. Alter profiles table to add community leave time and next rejoin time (cooldown)
alter table public.profiles add column if not exists community_leave_time timestamp with time zone;
alter table public.profiles add column if not exists community_next_join_time timestamp with time zone;

-- 3. Create community_memberships table
create table if not exists public.community_memberships (
  id uuid primary key default gen_random_uuid(),
  community_id text references public.communities(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  role text not null default 'member', -- 'owner', 'co_owner', 'admin', 'member'
  joined_at timestamp with time zone default now() not null,
  joined_by uuid references public.profiles(id),
  join_method text not null default 'auto_join', -- 'auto_join', 'approved', 'creator'
  contribution integer default 0 not null,
  exp_contribution integer default 0 not null,
  activity_score integer default 0 not null,
  last_active_at timestamp with time zone default now() not null,
  constraint unique_user_membership unique (user_id) -- ONE COMMUNITY RULE!
);

-- Indexing for quick lookups
create index if not exists idx_community_memberships_comm on public.community_memberships(community_id);

-- Enable RLS on memberships
alter table public.community_memberships enable row level security;
create policy "Allow read access to memberships" on public.community_memberships for select using (true);
create policy "Allow all actions for service_role/postgres" on public.community_memberships for all using (true);

-- 4. Create community_applications table
create table if not exists public.community_applications (
  id uuid primary key default gen_random_uuid(),
  community_id text references public.communities(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  status text not null default 'pending', -- 'pending', 'approved', 'rejected', 'blocked'
  introduction text,
  reason text,
  preferred_language text,
  optional_message text,
  created_at timestamp with time zone default now() not null,
  processed_at timestamp with time zone,
  processed_by uuid references public.profiles(id),
  constraint unique_pending_app unique (community_id, user_id)
);

-- Enable RLS on applications
alter table public.community_applications enable row level security;
create policy "Allow read applications to managers and applicant" on public.community_applications for select
  using (
    auth.uid() = user_id or 
    exists (
      select 1 from public.community_memberships
      where community_id = community_applications.community_id
        and user_id = auth.uid()
        and role in ('owner', 'co_owner', 'admin')
    )
  );
create policy "Allow insert application to applicant" on public.community_applications for insert
  with check (auth.uid() = user_id);
create policy "Allow update application to managers" on public.community_applications for update
  using (
    exists (
      select 1 from public.community_memberships
      where community_id = community_applications.community_id
        and user_id = auth.uid()
        and role in ('owner', 'co_owner')
    )
  );

-- 5. Seed memberships for existing communities to maintain backwards compatibility
insert into public.community_memberships (community_id, user_id, role, join_method)
select c.id, p.id, 'member', 'auto_join'
from public.communities c
cross join lateral unnest(c.members) as mem_id
join public.profiles p on p.id::text = mem_id
on conflict (user_id) do nothing;

-- Ensure owners have a membership entry
insert into public.community_memberships (community_id, user_id, role, join_method)
select c.id, c.owner, 'owner', 'creator'
from public.communities c
on conflict (user_id) do nothing;

-- 6. Rewrite rebuild_user_tag_system to support dynamic community tags
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

  -- 2. Community Tag (from memberships)
  select m.community_id, c.name, c.level, c.is_official, c.is_verified, m.role
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
      and required_level = v_vip_level
      and enabled = true
    order by priority desc
    limit 1;

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

  -- 4. Novel Identity Tag
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

  update public.profiles
  set tag_system  = v_tag_system,
      tag_lights  = v_tag_lights
  where id = p_user_id;
end;
$$ language plpgsql security definer set search_path = public;

-- 7. Trigger to auto-rebuild tag system on community membership change
create or replace function public.tr_on_community_membership_change()
returns trigger as $$
begin
  if tg_op = 'INSERT' or tg_op = 'UPDATE' then
    perform public.rebuild_user_tag_system(new.user_id);
    -- Sync user profile communities column if needed (backward compat)
    update public.profiles
    set communities = array(
      select name from public.communities c
      join public.community_memberships m on m.community_id = c.id
      where m.user_id = new.user_id
    )
    where id = new.user_id;
  elsif tg_op = 'DELETE' then
    perform public.rebuild_user_tag_system(old.user_id);
    update public.profiles
    set communities = '{}'
    where id = old.user_id;
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists trigger_on_community_membership_change on public.community_memberships;
create trigger trigger_on_community_membership_change
after insert or update or delete on public.community_memberships
for each row execute procedure public.tr_on_community_membership_change();


-- 8. Create Community RPC Function
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
  p_creation_method text -- 'coins' or 'ticket'
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

  -- Verify level >= 25
  select level into v_user_level from public.profiles where id = v_user_id;
  if v_user_level is null or v_user_level < 25 then
    return jsonb_build_object('success', false, 'error', 'Minimum ID level of 25 is required to create a community.');
  end if;

  -- Check if already in a community (One Community Rule)
  select exists (
    select 1 from public.community_memberships where user_id = v_user_id
  ) into v_already_member;
  if v_already_member then
    return jsonb_build_object('success', false, 'error', 'You are already a member of a community. You must leave your current community first.');
  end if;

  -- Check if community ID is unique
  select exists (
    select 1 from public.communities where id = p_id
  ) into v_comm_exists;
  if v_comm_exists then
    return jsonb_build_object('success', false, 'error', 'Community ID is already taken.');
  end if;

  -- Cost validation and deduction
  if p_creation_method = 'ticket' then
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
      return jsonb_build_object('success', false, 'error', 'Insufficient balance. 699 Gold Coins are required.');
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
    return jsonb_build_object('success', false, 'error', 'Invalid creation method. Must be coins or ticket.');
  end if;

  -- Insert community
  insert into public.communities (
    id, name, description, image, banner, category, language, country, rules, 
    join_mode, min_id_level, preferred_languages, preferred_countries, 
    preferred_interests, tags, visibility, owner, is_official, is_verified, 
    level, xp, member_count, created_at
  ) values (
    p_id, p_name, p_description, p_image, p_banner, p_category, p_language, p_country, p_rules,
    p_join_mode, p_min_id_level, p_preferred_languages, p_preferred_countries,
    p_preferred_interests, p_tags, p_visibility, v_user_id, false, false,
    1, 0, 1, now()
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


-- 9. Join Community RPC Function
create or replace function public.join_community_rpc(
  p_community_id text,
  p_introduction text default null,
  p_reason text default null,
  p_preferred_language text default null,
  p_optional_message text default null
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_profile record;
  v_comm record;
  v_cooldown_active boolean;
  v_already_member boolean;
  v_is_blocked boolean;
  v_members_count integer;
  v_capacity_limit integer;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  select level, community_next_join_time into v_profile from public.profiles where id = v_user_id;
  if v_profile is null then
    return jsonb_build_object('success', false, 'error', 'Profile not found.');
  end if;

  if v_profile.community_next_join_time is not null and v_profile.community_next_join_time > now() then
    return jsonb_build_object('success', false, 'error', 'You are in a 24-hour cooldown period after leaving your previous community.');
  end if;

  select exists (
    select 1 from public.community_memberships where user_id = v_user_id
  ) into v_already_member;
  if v_already_member then
    return jsonb_build_object('success', false, 'error', 'You are already a member of another community. You must leave it first.');
  end if;

  select * into v_comm from public.communities where id = p_community_id;
  if v_comm is null then
    return jsonb_build_object('success', false, 'error', 'Community not found.');
  end if;

  if v_profile.level < v_comm.min_id_level then
    return jsonb_build_object('success', false, 'error', 'Your ID level (' || v_profile.level || ') is lower than the community requirement (' || v_comm.min_id_level || ').');
  end if;

  -- Check capacity limits for non-official communities
  if not v_comm.is_official then
    select count(*) into v_members_count from public.community_memberships where community_id = p_community_id;
    v_capacity_limit := case 
      when v_comm.level >= 15 then 500
      when v_comm.level >= 10 then 250
      when v_comm.level >= 5 then 150
      else 100
    end;

    if v_members_count >= v_capacity_limit then
      return jsonb_build_object('success', false, 'error', 'Community is full. Capacity reached.');
    end if;
  end if;

  if v_comm.join_mode = 'auto_join' then
    insert into public.community_memberships (
      community_id, user_id, role, join_method, joined_by
    ) values (
      p_community_id, v_user_id, 'member', 'auto_join', v_user_id
    );

    update public.communities
    set member_count = coalesce(member_count, 0) + 1
    where id = p_community_id;

    return jsonb_build_object('success', true, 'status', 'joined');
  else
    select exists (
      select 1 from public.community_applications
      where community_id = p_community_id and user_id = v_user_id and status = 'pending'
    ) into v_already_member;
    if v_already_member then
      return jsonb_build_object('success', false, 'error', 'You already have a pending application for this community.');
    end if;

    select exists (
      select 1 from public.community_applications
      where community_id = p_community_id and user_id = v_user_id and status = 'blocked'
    ) into v_is_blocked;
    if v_is_blocked then
      return jsonb_build_object('success', false, 'error', 'Your applications to this community have been blocked.');
    end if;

    insert into public.community_applications (
      community_id, user_id, status, introduction, reason, preferred_language, optional_message, created_at
    ) values (
      p_community_id, v_user_id, 'pending', p_introduction, p_reason, p_preferred_language, p_optional_message, now()
    );

    return jsonb_build_object('success', true, 'status', 'applied');
  end if;
end;
$$ language plpgsql security definer set search_path = public;


-- 10. Leave Community RPC Function
create or replace function public.leave_community_rpc(
  p_community_id text
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_role text;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  select role into v_role from public.community_memberships where community_id = p_community_id and user_id = v_user_id;
  if v_role is null then
    return jsonb_build_object('success', false, 'error', 'You are not a member of this community.');
  end if;

  if v_role = 'owner' then
    return jsonb_build_object('success', false, 'error', 'Owners cannot leave the community. Transfer ownership or delete the community first.');
  end if;

  -- Remove membership
  delete from public.community_memberships where community_id = p_community_id and user_id = v_user_id;

  -- Update community member count
  update public.communities
  set member_count = greatest(0, member_count - 1)
  where id = p_community_id;

  -- Apply 24-hour cooldown on profiles
  update public.profiles
  set community_leave_time = now(),
      community_next_join_time = now() + interval '24 hours'
  where id = v_user_id;

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer set search_path = public;


-- 11. Process Application RPC Function
create or replace function public.process_application_rpc(
  p_application_id uuid,
  p_action text -- 'approve', 'reject', 'block'
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_app record;
  v_my_role text;
  v_applicant_already_member boolean;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  select * into v_app from public.community_applications where id = p_application_id;
  if v_app is null then
    return jsonb_build_object('success', false, 'error', 'Application not found.');
  end if;

  select role into v_my_role from public.community_memberships where community_id = v_app.community_id and user_id = v_user_id;
  if v_my_role is null or v_my_role not in ('owner', 'co_owner') then
    return jsonb_build_object('success', false, 'error', 'Only owners or co-owners can process applications.');
  end if;

  if p_action = 'approve' then
    -- Check if applicant is already in a community
    select exists (
      select 1 from public.community_memberships where user_id = v_app.user_id
    ) into v_applicant_already_member;
    if v_applicant_already_member then
      update public.community_applications set status = 'rejected', processed_at = now(), processed_by = v_user_id where id = p_application_id;
      return jsonb_build_object('success', false, 'error', 'Applicant is already a member of another community.');
    end if;

    update public.community_applications set status = 'approved', processed_at = now(), processed_by = v_user_id where id = p_application_id;

    insert into public.community_memberships (
      community_id, user_id, role, join_method, joined_by
    ) values (
      v_app.community_id, v_app.user_id, 'member', 'approved', v_user_id
    );

    update public.communities set member_count = coalesce(member_count, 0) + 1 where id = v_app.community_id;

  elsif p_action = 'reject' then
    update public.community_applications set status = 'rejected', processed_at = now(), processed_by = v_user_id where id = p_application_id;

  elsif p_action = 'block' then
    update public.community_applications set status = 'blocked', processed_at = now(), processed_by = v_user_id where id = p_application_id;

  else
    return jsonb_build_object('success', false, 'error', 'Invalid action. Must be approve, reject, or block.');
  end if;

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer set search_path = public;


-- 12. Manage Member Role RPC Function
create or replace function public.manage_member_role_rpc(
  p_community_id text,
  p_target_user_id uuid,
  p_role text -- 'co_owner', 'admin', 'member', 'kick'
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_my_role text;
  v_target_role text;
  v_comm record;
  v_co_owner_count integer;
  v_admin_count integer;
  v_co_owner_limit integer;
  v_admin_limit integer;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  select role into v_my_role from public.community_memberships where community_id = p_community_id and user_id = v_user_id;
  if v_my_role is null or v_my_role not in ('owner', 'co_owner') then
    return jsonb_build_object('success', false, 'error', 'Only owners or co-owners can manage member roles.');
  end if;

  select role into v_target_role from public.community_memberships where community_id = p_community_id and user_id = p_target_user_id;
  if v_target_role is null then
    return jsonb_build_object('success', false, 'error', 'Target user is not a member of this community.');
  end if;

  if v_target_role = 'owner' then
    return jsonb_build_object('success', false, 'error', 'Cannot change the role of the community owner.');
  end if;

  if v_my_role = 'co_owner' and v_target_role in ('co_owner', 'admin') then
    return jsonb_build_object('success', false, 'error', 'Co-owners cannot change roles of other co-owners or admins.');
  end if;

  select * into v_comm from public.communities where id = p_community_id;

  if p_role = 'kick' then
    delete from public.community_memberships where community_id = p_community_id and user_id = p_target_user_id;
    update public.communities set member_count = greatest(0, member_count - 1) where id = p_community_id;
    return jsonb_build_object('success', true);
  end if;

  -- Limit validations for non-official communities
  if not v_comm.is_official then
    v_co_owner_limit := case when v_comm.level >= 5 then 2 else 1 end;
    v_admin_limit := case when v_comm.level >= 5 then 5 else 2 end;

    if p_role = 'co_owner' then
      select count(*) into v_co_owner_count from public.community_memberships where community_id = p_community_id and role = 'co_owner';
      if v_co_owner_count >= v_co_owner_limit then
        return jsonb_build_object('success', false, 'error', 'Co-owner limit reached for this community level (' || v_co_owner_limit || ').');
      end if;
    elsif p_role = 'admin' then
      select count(*) into v_admin_count from public.community_memberships where community_id = p_community_id and role = 'admin';
      if v_admin_count >= v_admin_limit then
        return jsonb_build_object('success', false, 'error', 'Admin limit reached for this community level (' || v_admin_limit || ').');
      end if;
    end if;
  end if;

  update public.community_memberships
  set role = p_role
  where community_id = p_community_id and user_id = p_target_user_id;

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer set search_path = public;


-- 13. Transfer Ownership RPC Function
create or replace function public.transfer_community_ownership_rpc(
  p_community_id text,
  p_target_user_id uuid
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_target_role text;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  -- Must be current owner
  if not exists (
    select 1 from public.community_memberships where community_id = p_community_id and user_id = v_user_id and role = 'owner'
  ) then
    return jsonb_build_object('success', false, 'error', 'Only the owner can transfer ownership.');
  end if;

  select role into v_target_role from public.community_memberships where community_id = p_community_id and user_id = p_target_user_id;
  if v_target_role is null then
    return jsonb_build_object('success', false, 'error', 'Target user is not a member of this community.');
  end if;

  -- Perform transfer
  update public.community_memberships set role = 'member' where community_id = p_community_id and user_id = v_user_id;
  update public.community_memberships set role = 'owner' where community_id = p_community_id and user_id = p_target_user_id;
  update public.communities set owner = p_target_user_id where id = p_community_id;

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer set search_path = public;
