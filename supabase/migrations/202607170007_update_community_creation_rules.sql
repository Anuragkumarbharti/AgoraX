-- 202607170007_update_community_creation_rules.sql
-- Update create_community_rpc to allow creation if any of the three criteria is met: Level >= 25, 699 Coins, or 1 Ticket.

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
  p_creation_method text -- 'level', 'coins', 'ticket'
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

  -- Check if community ID is unique
  select exists (
    select 1 from public.communities where id = p_id
  ) into v_comm_exists;
  if v_comm_exists then
    return jsonb_build_object('success', false, 'error', 'Community ID is already taken.');
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
