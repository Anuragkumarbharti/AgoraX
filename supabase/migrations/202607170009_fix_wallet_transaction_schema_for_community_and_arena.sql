-- 202607170009_fix_wallet_transaction_schema_for_community_and_arena.sql
-- Fix check constraint violations and column mismatches in wallet_transactions insertions.

-- 1. Redefine create_arena to use correct columns: currency, type, status, details and correct value: 'Gold Coins'
create or replace function public.create_arena(
  p_name             text,
  p_username         text,
  p_description      text,
  p_category         text,
  p_country          text,
  p_language         text,
  p_tags             text[],
  p_rules            text[],
  p_entry_permission text,
  p_avatar           text,
  p_banner           text,
  p_creation_method  text  -- 'ticket' | 'coins' | 'level'
) returns text as $$
declare
  v_user_id       uuid := auth.uid();
  v_room_id       text;
  v_livekit_name  text;
  v_balance       integer;
  v_user_level    integer;
  v_ticket_id     uuid;
  v_coins_spent   integer := 0;
begin
  -- ── Authentication guard ─────────────────────────────────────────────────
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: You must be logged in to create an Arena.';
  end if;

  -- ── Validate creation method ─────────────────────────────────────────────
  if p_creation_method not in ('ticket', 'coins', 'level') then
    raise exception 'INVALID_METHOD: Creation method must be ticket, coins, or level.';
  end if;

  -- ── Normalize username ───────────────────────────────────────────────────
  if p_username is not null and p_username <> '' then
    p_username := lower(trim(p_username));
    if left(p_username, 1) <> '@' then
      p_username := '@' || p_username;
    end if;
  end if;

  -- ── Acquire advisory lock to prevent race conditions ─────────────────────
  perform pg_advisory_xact_lock(('x' || substr(md5(v_user_id::text), 1, 15))::bit(60)::bigint);

  -- ── Re-check: user must not already own an active Arena ──────────────────
  if exists (
    select 1 from public.rooms
    where host_id = v_user_id
      and is_permanent = true
      and status in ('live', 'scheduled')
  ) then
    raise exception 'ARENA_LIMIT: You already own an active Arena. Only one active Arena is allowed per account.';
  end if;

  -- ── Method: TICKET ───────────────────────────────────────────────────────
  if p_creation_method = 'ticket' then
    select id into v_ticket_id
    from public.arena_tickets
    where user_id = v_user_id
      and is_consumed = false
    order by granted_at asc
    limit 1
    for update skip locked;

    if v_ticket_id is null then
      raise exception 'NO_TICKET: You do not have any Arena Tickets.';
    end if;

    update public.arena_tickets
    set is_consumed = true,
        consumed_at = now()
    where id = v_ticket_id;

    v_coins_spent := 0;

  -- ── Method: COINS ────────────────────────────────────────────────────────
  elsif p_creation_method = 'coins' then
    select coins_balance into v_balance
    from public.wallets
    where id = v_user_id
    for update;

    if coalesce(v_balance, 0) < 499 then
      raise exception 'INSUFFICIENT_COINS: Creating an Arena costs 499 Gold Coins. Your balance: % coins.', coalesce(v_balance, 0);
    end if;

    -- Deduct 499 Gold Coins atomically
    update public.wallets
    set coins_balance = coins_balance - 499
    where id = v_user_id;

    -- Corrected insert statement using redesigned schema columns and 'Gold Coins' currency
    insert into public.wallet_transactions
      (wallet_id, amount, currency, type, status, details)
    values
      (v_user_id, 499, 'Gold Coins', 'Withdrawal', 'Completed', 'Created permanent Arena: ' || p_name);

    v_coins_spent := 499;

  -- ── Method: LEVEL ────────────────────────────────────────────────────────
  elsif p_creation_method = 'level' then
    select level into v_user_level
    from public.profiles
    where id = v_user_id;

    if coalesce(v_user_level, 1) < 15 then
      raise exception 'LEVEL_REQUIRED: Arena creation via ID Level requires Level 15 or above. Your current level: %.', coalesce(v_user_level, 1);
    end if;

    v_coins_spent := 0;
  end if;

  -- ── Generate unique IDs ───────────────────────────────────────────────────
  v_room_id      := public.generate_unique_room_id();
  v_livekit_name := 'arena_' || encode(gen_random_bytes(8), 'hex');

  -- ── Insert the permanent Arena ────────────────────────────────────────────
  insert into public.rooms (
    id, name, username, description, category, language, tags, rules,
    host_id, status, visibility, recording_status, level_requirement,
    vip_requirement, verification_requirement, livekit_room_name,
    avatar, banner, is_permanent
  ) values (
    v_room_id,
    p_name,
    p_username,
    p_description,
    p_category,
    p_language,
    p_tags,
    p_rules,
    v_user_id,
    'live',
    p_entry_permission,
    'inactive',
    1, -- Fix: level_requirement >= 1 check constraint
    0,
    false,
    v_livekit_name,
    p_avatar,
    p_banner,
    true
  );

  -- ── Log creation event ────────────────────────────────────────────────────
  insert into public.arena_creation_logs (
    room_id, creator_id, creation_method, coins_spent, ticket_id
  ) values (
    v_room_id,
    v_user_id,
    p_creation_method,
    v_coins_spent,
    v_ticket_id
  );

  return v_room_id;
end;
$$ language plpgsql security definer;


-- 2. Redefine create_community_rpc to use correct columns: currency, type, status, details and correct value: 'Gold Coins'
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

    -- Corrected insert statement using redesigned schema columns and 'Gold Coins' currency
    insert into public.wallet_transactions (
      wallet_id, amount, currency, type, status, details
    ) values (
      v_user_id, 699.00, 'Gold Coins', 'Spend', 'Completed', 'Community Creation Cost'
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
