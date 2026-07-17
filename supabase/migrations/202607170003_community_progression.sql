-- 202607170003_community_progression.sql
-- StarMaker-inspired Community Level, EXP, Contribution, and Reward system migrations

-- 1. Alter public.communities to add progression columns
alter table public.communities add column if not exists lifetime_exp bigint default 0 not null;
alter table public.communities add column if not exists daily_exp bigint default 0 not null;
alter table public.communities add column if not exists weekly_exp bigint default 0 not null;
alter table public.communities add column if not exists monthly_exp bigint default 0 not null;
alter table public.communities add column if not exists activity_score integer default 0 not null;
alter table public.communities add column if not exists last_exp_reset_at timestamp with time zone default now() not null;
alter table public.communities add column if not exists co_owner_limit integer default 2 not null;
alter table public.communities add column if not exists admin_limit integer default 5 not null;

-- 2. Create community daily limits table
create table if not exists public.community_member_daily_limits (
  community_id text references public.communities(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  day date default current_date not null,
  normal_exp integer default 0 not null,
  gold_gift_exp integer default 0 not null,
  star_gift_exp integer default 0 not null,
  primary key (community_id, user_id, day)
);

-- Indexing for daily limits
create index if not exists idx_comm_daily_limits_lookup on public.community_member_daily_limits(community_id, user_id, day);

-- Enable RLS
alter table public.community_member_daily_limits enable row level security;
create policy "Allow read daily limits" on public.community_member_daily_limits for select using (true);
create policy "Allow service_role full control daily limits" on public.community_member_daily_limits for all using (true);

-- 3. Create community EXP transactions audit log
create table if not exists public.community_exp_transactions (
  id uuid primary key default gen_random_uuid(),
  community_id text references public.communities(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  source_type text not null, -- 'normal', 'gold_gift', 'star_gift'
  amount integer not null,
  reference_id text,
  created_at timestamp with time zone default now() not null
);

-- Enable RLS
alter table public.community_exp_transactions enable row level security;
create policy "Allow read exp transactions" on public.community_exp_transactions for select using (true);
create policy "Allow service_role full control exp transactions" on public.community_exp_transactions for all using (true);

-- 4. Progression Helper Functions
create or replace function public.get_required_exp_for_level(p_level integer)
returns bigint as $$
begin
  case p_level
    when 1 then return 150000;
    when 2 then return 600000;
    when 3 then return 1600000;
    when 4 then return 3400000;
    when 5 then return 5400000;
    when 6 then return 7900000;
    else return 999999999999; -- Level 7 is max, infinite EXP required
  end case;
end;
$$ language plpgsql immutable;

-- 5. Lazy Reset Function
create or replace function public.check_and_reset_exp_stats(p_community_id text)
returns void as $$
declare
  v_last_reset timestamp with time zone;
  v_now timestamp with time zone := now();
begin
  select last_exp_reset_at into v_last_reset from public.communities where id = p_community_id;
  if v_last_reset is null then
    update public.communities set last_exp_reset_at = v_now where id = p_community_id;
    return;
  end if;

  -- Day change
  if date_trunc('day', v_last_reset) != date_trunc('day', v_now) then
    update public.communities set daily_exp = 0 where id = p_community_id;
  end if;

  -- Week change (ISO standard week)
  if date_trunc('week', v_last_reset) != date_trunc('week', v_now) then
    update public.communities set weekly_exp = 0 where id = p_community_id;
  end if;

  -- Month change
  if date_trunc('month', v_last_reset) != date_trunc('month', v_now) then
    update public.communities set monthly_exp = 0 where id = p_community_id;
  end if;

  update public.communities set last_exp_reset_at = v_now where id = p_community_id;
end;
$$ language plpgsql security definer;

-- 6. Core EXP adding procedure
create or replace function public.add_community_exp_rpc(
  p_community_id text,
  p_user_id uuid,
  p_source_type text, -- 'normal', 'gold_gift', 'star_gift'
  p_amount integer,
  p_reference_id text default null
)
returns jsonb as $$
declare
  v_is_member boolean;
  v_limit_record record;
  v_allowed_exp integer := 0;
  v_current_exp bigint;
  v_current_level integer;
  v_next_level_required bigint;
  v_new_level integer;
  v_new_xp bigint;
  v_co_limit integer;
  v_adm_limit integer;
begin
  -- Authentication check is not strictly needed for system triggers but good for RPC direct calls
  if p_user_id is null then
    return jsonb_build_object('success', false, 'error', 'User ID is required.');
  end if;

  -- Verify membership
  select exists (
    select 1 from public.community_memberships 
    where community_id = p_community_id and user_id = p_user_id
  ) into v_is_member;

  if not v_is_member then
    return jsonb_build_object('success', false, 'error', 'User is not a member of this community.');
  end if;

  -- Lazy Reset stats
  perform public.check_and_reset_exp_stats(p_community_id);

  -- Load/Create daily limits
  insert into public.community_member_daily_limits (community_id, user_id, day, normal_exp, gold_gift_exp, star_gift_exp)
  values (p_community_id, p_user_id, current_date, 0, 0, 0)
  on conflict (community_id, user_id, day) do nothing;

  select normal_exp, gold_gift_exp, star_gift_exp into v_limit_record
  from public.community_member_daily_limits
  where community_id = p_community_id and user_id = p_user_id and day = current_date;

  -- Calculate allowed EXP based on source type and caps
  if p_source_type = 'normal' then
    v_allowed_exp := least(p_amount, 250 - v_limit_record.normal_exp);
    if v_allowed_exp > 0 then
      update public.community_member_daily_limits
      set normal_exp = normal_exp + v_allowed_exp
      where community_id = p_community_id and user_id = p_user_id and day = current_date;
    end if;
  elsif p_source_type = 'gold_gift' then
    v_allowed_exp := least(p_amount, 2500 - v_limit_record.gold_gift_exp);
    if v_allowed_exp > 0 then
      update public.community_member_daily_limits
      set gold_gift_exp = gold_gift_exp + v_allowed_exp
      where community_id = p_community_id and user_id = p_user_id and day = current_date;
    end if;
  elsif p_source_type = 'star_gift' then
    v_allowed_exp := least(p_amount, 2000 - v_limit_record.star_gift_exp);
    if v_allowed_exp > 0 then
      update public.community_member_daily_limits
      set star_gift_exp = star_gift_exp + v_allowed_exp
      where community_id = p_community_id and user_id = p_user_id and day = current_date;
    end if;
  else
    return jsonb_build_object('success', false, 'error', 'Invalid source type.');
  end if;

  if v_allowed_exp <= 0 then
    return jsonb_build_object('success', true, 'exp_added', 0, 'reason', 'Daily limit reached for this source.');
  end if;

  -- Log transaction
  insert into public.community_exp_transactions (community_id, user_id, source_type, amount, reference_id)
  values (p_community_id, p_user_id, p_source_type, v_allowed_exp, p_reference_id);

  -- Fetch current level and xp
  select level, xp into v_current_level, v_current_exp from public.communities where id = p_community_id;
  if v_current_level is null then v_current_level := 1; end if;
  if v_current_exp is null then v_current_exp := 0; end if;

  -- Update community EXP stats
  update public.communities
  set xp = xp + v_allowed_exp,
      lifetime_exp = lifetime_exp + v_allowed_exp,
      daily_exp = daily_exp + v_allowed_exp,
      weekly_exp = weekly_exp + v_allowed_exp,
      monthly_exp = monthly_exp + v_allowed_exp,
      activity_score = activity_score + greatest(1, v_allowed_exp / 10)
  where id = p_community_id;

  -- Update user contribution in community memberships
  update public.community_memberships
  set contribution = contribution + v_allowed_exp,
      exp_contribution = exp_contribution + v_allowed_exp,
      activity_score = activity_score + greatest(1, v_allowed_exp / 10),
      last_active_at = now()
  where community_id = p_community_id and user_id = p_user_id;

  -- Evaluate progression / level up
  v_new_level := v_current_level;
  v_new_xp := v_current_exp + v_allowed_exp;

  loop
    exit when v_new_level >= 7;
    v_next_level_required := public.get_required_exp_for_level(v_new_level);
    if v_new_xp >= v_next_level_required then
      v_new_level := v_new_level + 1;
    else
      exit;
    end if;
  end loop;

  -- Update level if changed
  if v_new_level != v_current_level then
    -- Determine role limits for new level
    case v_new_level
      when 1 then v_co_limit := 2; v_adm_limit := 5;
      when 2 then v_co_limit := 3; v_adm_limit := 7;
      when 3 then v_co_limit := 4; v_adm_limit := 10;
      when 4 then v_co_limit := 5; v_adm_limit := 15;
      when 5 then v_co_limit := 6; v_adm_limit := 20;
      when 6 then v_co_limit := 8; v_adm_limit := 25;
      when 7 then v_co_limit := 10; v_adm_limit := 30;
      else v_co_limit := 2; v_adm_limit := 5;
    end case;

    update public.communities
    set level = v_new_level,
        co_owner_limit = v_co_limit,
        admin_limit = v_adm_limit
    where id = p_community_id;

    -- Sync community tag style properties
    perform public.sync_community_tags(p_community_id);
  end if;

  return jsonb_build_object(
    'success', true, 
    'exp_added', v_allowed_exp, 
    'new_level', v_new_level,
    'new_xp', v_new_xp
  );
end;
$$ language plpgsql security definer;

-- 7. Community Check-In RPC Function
create or replace function public.check_in_community_rpc(p_community_id text)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_res jsonb;
  v_already_checked boolean;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  -- Verify membership
  if not exists (
    select 1 from public.community_memberships
    where community_id = p_community_id and user_id = v_user_id
  ) then
    return jsonb_build_object('success', false, 'error', 'You must join this community first to check in.');
  end if;

  -- Verify they haven't checked in today yet
  select exists (
    select 1 from public.community_exp_transactions
    where community_id = p_community_id
      and user_id = v_user_id
      and source_type = 'normal'
      and reference_id = 'check_in_' || current_date::text
  ) into v_already_checked;

  if v_already_checked then
    return jsonb_build_object('success', false, 'error', 'You have already checked in today.');
  end if;

  -- Award 50 EXP (normal daily task EXP)
  select public.add_community_exp_rpc(p_community_id, v_user_id, 'normal', 50, 'check_in_' || current_date::text) into v_res;

  return v_res;
end;
$$ language plpgsql security definer;

-- 8. Gift Hook Trigger Function (Implements Gift rules 1 to 5)
create or replace function public.process_community_gift_exp_trigger_fn()
returns trigger as $$
declare
  v_gifter_comm_id text;
  v_receiver_comm_id text;
  v_gold_reward integer;
  v_star_reward integer;
begin
  -- Prevent self gifting abuse
  if NEW.sender_id = NEW.receiver_id then
    return NEW;
  end if;

  -- Fetch gifter community
  select community_id into v_gifter_comm_id from public.community_memberships where user_id = NEW.sender_id limit 1;

  -- Fetch receiver community
  select community_id into v_receiver_comm_id from public.community_memberships where user_id = NEW.receiver_id limit 1;

  -- Calculate rewards
  v_gold_reward := round(coalesce(NEW.coins_value, 0) * 1.25);
  v_star_reward := round(coalesce(NEW.coins_value, 0) / 3.0);

  if v_gifter_comm_id is not null and v_receiver_comm_id is not null then
    if v_gifter_comm_id = v_receiver_comm_id then
      -- Rule 4: Same community -> Grant Gold Gift Bonus once (no double counting)
      if v_gold_reward > 0 then
        perform public.add_community_exp_rpc(v_gifter_comm_id, NEW.sender_id, 'gold_gift', v_gold_reward, NEW.id::text);
      end if;
    else
      -- Rule 3: Different communities -> Both receive their own bonus
      if v_gold_reward > 0 then
        perform public.add_community_exp_rpc(v_gifter_comm_id, NEW.sender_id, 'gold_gift', v_gold_reward, NEW.id::text);
      end if;
      if v_star_reward > 0 then
        perform public.add_community_exp_rpc(v_receiver_comm_id, NEW.receiver_id, 'star_gift', v_star_reward, NEW.id::text);
      end if;
    end if;
  elsif v_gifter_comm_id is not null then
    -- Rule 1: Gifter community only
    if v_gold_reward > 0 then
      perform public.add_community_exp_rpc(v_gifter_comm_id, NEW.sender_id, 'gold_gift', v_gold_reward, NEW.id::text);
    end if;
  elsif v_receiver_comm_id is not null then
    -- Rule 2: Receiver community only
    if v_star_reward > 0 then
      perform public.add_community_exp_rpc(v_receiver_comm_id, NEW.receiver_id, 'star_gift', v_star_reward, NEW.id::text);
    end if;
  end if;

  return NEW;
end;
$$ language plpgsql security definer;

-- Create Gift history trigger
drop trigger if exists trg_community_gift_exp on public.gift_history;
create trigger trg_community_gift_exp
  after insert on public.gift_history
  for each row execute procedure public.process_community_gift_exp_trigger_fn();

-- 9. Rewrite manage_member_role_rpc with Level limits
create or replace function public.manage_member_role_rpc(
  p_community_id text,
  p_target_user_id uuid,
  p_role text -- 'owner', 'co_owner', 'admin', 'member', 'kick'
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

  -- Limit validations based on Level
  if not v_comm.is_official then
    v_co_owner_limit := case v_comm.level
      when 1 then 2
      when 2 then 3
      when 3 then 4
      when 4 then 5
      when 5 then 6
      when 6 then 8
      when 7 then 10
      else 2
    end;

    v_admin_limit := case v_comm.level
      when 1 then 5
      when 2 then 7
      when 3 then 10
      when 4 then 15
      when 5 then 20
      when 6 then 25
      when 7 then 30
      else 5
    end;

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

  -- Rebuild target tag
  perform public.rebuild_user_tag_system(p_target_user_id);

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer set search_path = public;

-- 10. Voice Room Heartbeat Integration Trigger
create or replace function public.heartbeat_room_member(
  p_room_id text,
  p_is_speaking boolean
)
returns void as $$
declare
  v_user_id uuid := auth.uid();
  v_last_seen timestamp with time zone;
  v_elapsed integer;
  v_stay_added integer := 0;
  v_speak_added integer := 0;
  v_comm_id text;
begin
  if v_user_id is null then
    raise exception 'Unauthenticated user';
  end if;

  if not exists (select 1 from public.room_members where room_id = p_room_id and user_id = v_user_id) then
    return;
  end if;

  select last_seen_at into v_last_seen
  from public.room_member_heartbeats
  where room_id = p_room_id and user_id = v_user_id;

  if v_last_seen is not null then
    v_elapsed := extract(epoch from (now() - v_last_seen))::integer;
    if v_elapsed >= 2 and v_elapsed <= 45 then
      v_stay_added := v_elapsed;
      if p_is_speaking then
        v_speak_added := v_elapsed;
      end if;
    end if;
  end if;

  insert into public.room_member_heartbeats (room_id, user_id, last_seen_at)
  values (p_room_id, v_user_id, now())
  on conflict (room_id, user_id) do update set last_seen_at = EXCLUDED.last_seen_at;

  -- 1. Add voice room reputation to room
  if v_stay_added > 0 then
    perform public.add_room_xp(p_room_id, greatest(1, v_stay_added / 5));
  end if;

  -- 2. Add normal daily EXP to the user's community if they have joined one
  select community_id into v_comm_id from public.community_memberships where user_id = v_user_id limit 1;
  if v_comm_id is not null and v_stay_added > 0 then
    -- Heartbeat stays are short, let's award 1 EXP per 10 stay seconds (up to 250 normal EXP daily)
    perform public.add_community_exp_rpc(v_comm_id, v_user_id, 'normal', greatest(1, v_stay_added / 10), 'voice_stay_' || p_room_id);
  end if;
end;
$$ language plpgsql security definer;

-- 11. Leaderboard RPC API
create or replace function public.get_community_leaderboard_rpc(
  p_community_id text,
  p_type text, -- 'top_contributors', 'top_gift_senders', 'top_gift_receivers', 'top_active_members'
  p_limit integer default 10
)
returns jsonb as $$
declare
  v_result jsonb;
begin
  case p_type
    when 'top_contributors' then
      select json_agg(t) into v_result
      from (
        select m.user_id, p.display_name, p.username, p.avatar, m.contribution
        from public.community_memberships m
        join public.profiles p on m.user_id = p.id
        where m.community_id = p_community_id
        order by m.contribution desc
        limit p_limit
      ) t;
    when 'top_gift_senders' then
      select json_agg(t) into v_result
      from (
        select m.user_id, p.display_name, p.username, p.avatar, coalesce(sum(g.coins_value), 0) as total_sent
        from public.community_memberships m
        join public.profiles p on m.user_id = p.id
        left join public.gift_history g on g.sender_id = m.user_id
        where m.community_id = p_community_id
        group by m.user_id, p.display_name, p.username, p.avatar
        order by total_sent desc
        limit p_limit
      ) t;
    when 'top_gift_receivers' then
      select json_agg(t) into v_result
      from (
        select m.user_id, p.display_name, p.username, p.avatar, coalesce(sum(g.coins_value), 0) as total_received
        from public.community_memberships m
        join public.profiles p on m.user_id = p.id
        left join public.gift_history g on g.receiver_id = m.user_id
        where m.community_id = p_community_id
        group by m.user_id, p.display_name, p.username, p.avatar
        order by total_received desc
        limit p_limit
      ) t;
    when 'top_active_members' then
      select json_agg(t) into v_result
      from (
        select m.user_id, p.display_name, p.username, p.avatar, m.activity_score
        from public.community_memberships m
        join public.profiles p on m.user_id = p.id
        where m.community_id = p_community_id
        order by m.activity_score desc
        limit p_limit
      ) t;
    else
      return jsonb_build_object('success', false, 'error', 'Invalid leaderboard type.');
  end case;

  return jsonb_build_object('success', true, 'data', coalesce(v_result, '[]'::jsonb));
end;
$$ language plpgsql security definer;
