-- Migration 202607170011_adjust_progression_rules.sql
-- Adjust XP curve, activate tasks, configure rewarded ad rewards, and implement 7-day rolling streak check-in system.

-- 1. Increase XP curve requirements up to Level 60 (Base 200, 1.11 multiplier)
do $$
declare
  v_lvl integer;
  v_xp integer;
  v_total_xp integer := 0;
begin
  -- Update level 1
  insert into public.level_requirements (level, xp_required, total_xp_required)
  values (1, 0, 0)
  on conflict (level) do update set xp_required = 0, total_xp_required = 0;

  for v_lvl in 2..60 loop
    v_xp := round(200.0 * power(1.11, v_lvl - 1))::integer;
    v_total_xp := v_total_xp + v_xp;
    insert into public.level_requirements (level, xp_required, total_xp_required)
    values (v_lvl, v_xp, v_total_xp)
    on conflict (level) do update set xp_required = excluded.xp_required, total_xp_required = excluded.total_xp_required;
  end loop;
end;
$$;

-- 2. Ensure all Daily Tasks are active
update public.daily_tasks set is_active = true;

-- 3. Configure join_room task to require 5 minutes of participation
update public.daily_tasks 
set required_action = 'room_joined_minute', 
    required_count = 5 
where task_id = 'join_room';

-- Add room_joined_minute event to xp_config (5 XP, 50s cooldown to rate limit to 1 per minute)
insert into public.xp_config (event_type, xp_reward, cooldown_seconds)
values ('room_joined_minute', 5, 50)
on conflict (event_type) do update set xp_reward = 5, cooldown_seconds = 50;

-- 4. Configure host_room task to require 5 minutes on a microphone seat
update public.daily_tasks 
set required_action = 'room_hosted_minute', 
    required_count = 5 
where task_id = 'host_room';

-- Add room_hosted_minute event to xp_config (7 XP, 50s cooldown to rate limit to 1 per minute)
insert into public.xp_config (event_type, xp_reward, cooldown_seconds)
values ('room_hosted_minute', 7, 50)
on conflict (event_type) do update set xp_reward = 7, cooldown_seconds = 50;

-- 5. Update send_gift task reward to grant 200 Silver Coins
delete from public.task_rewards where task_id = 'send_gift' and task_type = 'daily' and reward_type = 'silver';
insert into public.task_rewards (task_id, task_type, reward_type, amount)
values ('send_gift', 'daily', 'silver', 200);

-- 6. Configure Silver Spin probabilities to user specifications:
-- 50 to 200 Silver has 95% total probability (50 Silver: 0.50, 100 Silver: 0.30, 200 Silver: 0.15)
-- Gold 1 to 5 (amount: 3) has 0.0091 probability
-- 200+ Silver (500 Silver) has 0.0098 probability
-- XP reward (50 XP) takes the remainder: 0.0311
delete from public.spin_rewards where spin_type = 'silver';
insert into public.spin_rewards (spin_type, reward_type, amount, cosmetic_id, probability) values
('silver', 'silver', 50, null, 0.50),
('silver', 'silver', 100, null, 0.30),
('silver', 'silver', 200, null, 0.15),
('silver', 'gold', 3, null, 0.0091),
('silver', 'silver', 500, null, 0.0098),
('silver', 'xp', 50, null, 0.0311);

-- 7. Recalculate checkin streak based on consecutive check-ins (resets on miss)
create or replace function public.calculate_checkin_streak(p_user_id uuid)
returns integer as $$
declare
  v_streak integer := 0;
  v_check_date date := current_date;
  v_has_checkin boolean;
begin
  -- Check if they checked in today or yesterday. If neither, streak is broken (0).
  select exists (
    select 1 from public.checkin_history
    where user_id = p_user_id and claimed_at::date in (current_date, current_date - 1)
  ) into v_has_checkin;

  if not v_has_checkin then
    return 0;
  end if;

  -- Start checking backwards from the last check-in date
  if exists (select 1 from public.checkin_history where user_id = p_user_id and claimed_at::date = current_date) then
    v_check_date := current_date;
  else
    v_check_date := current_date - 1;
  end if;

  loop
    select exists (
      select 1 from public.checkin_history
      where user_id = p_user_id and claimed_at::date = v_check_date
    ) into v_has_checkin;

    exit when not v_has_checkin;

    v_streak := v_streak + 1;
    v_check_date := v_check_date - 1;
  end loop;

  return v_streak;
end;
$$ language plpgsql security definer;

-- 8. Rebuild checkin calendar APIs to support the 7-day rolling check-in system
create or replace function public.get_checkin_status()
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_streak_count integer := 0;
  v_can_claim_today boolean := true;
  v_next_day_to_claim integer := 1;
  v_current_week_start integer := 1;
  v_current_week_end integer := 7;
  v_claimed_days integer[] := '{}';
  v_history_record record;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  -- Calculate current active consecutive streak
  v_streak_count := public.calculate_checkin_streak(v_user_id);

  -- Check if already claimed today
  if exists (
    select 1 from public.checkin_history
    where user_id = v_user_id
      and claimed_at::date = current_date
  ) then
    v_can_claim_today := false;
    v_next_day_to_claim := v_streak_count;
  else
    v_can_claim_today := true;
    v_next_day_to_claim := v_streak_count + 1;
  end if;

  -- Calculate current 7-day rolling window
  -- Week 1: 1-7, Week 2: 8-14, Week 3: 15-21, etc.
  v_current_week_start := (((v_next_day_to_claim - 1) / 7) * 7) + 1;
  v_current_week_end := v_current_week_start + 6;

  -- Get which days in the current 7-day block have been claimed
  -- Find matches from checkin_history using day numbers in that range
  -- Because of streak resets, we only look at the most recent checkins matching the streak days
  for v_history_record in 
    select day_number 
    from (
      select day_number, claimed_at 
      from public.checkin_history 
      where user_id = v_user_id
      order by claimed_at desc 
      limit v_streak_count
    ) h
    where h.day_number between v_current_week_start and v_current_week_end
  loop
    v_claimed_days := array_append(v_claimed_days, v_history_record.day_number);
  end loop;

  return jsonb_build_object(
    'streak_count', v_streak_count,
    'can_claim_today', v_can_claim_today,
    'next_day_to_claim', v_next_day_to_claim,
    'week_start', v_current_week_start,
    'week_end', v_current_week_end,
    'claimed_days', coalesce(to_jsonb(v_claimed_days), '[]'::jsonb)
  );
end;
$$ language plpgsql security definer;

-- Claim checkin reward under rolling streak calendar rules
create or replace function public.claim_checkin()
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_streak_count integer := 0;
  v_next_day integer := 1;
  v_reward_type text;
  v_amount integer;
  v_cosmetic_id text;
  v_week_factor integer;
  v_day_of_week integer;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  perform pg_advisory_xact_lock(('x' || substr(md5(v_user_id::text), 1, 15))::bit(60)::bigint);

  -- 1. Check if already claimed today
  if exists (
    select 1 from public.checkin_history
    where user_id = v_user_id
      and claimed_at::date = current_date
  ) then
    raise exception 'ALREADY_CLAIMED: You have already checked in today.';
  end if;

  -- 2. Calculate next day in sequence based on consecutive days
  v_streak_count := public.calculate_checkin_streak(v_user_id);
  v_next_day := v_streak_count + 1;

  -- 3. Determine rolling rewards sequence
  -- Week multiplier factor: 1 for Week 1 (Days 1-7), 2 for Week 2 (Days 8-14), etc.
  v_week_factor := ((v_next_day - 1) / 7) + 1;
  v_day_of_week := ((v_next_day - 1) % 7) + 1;

  if v_day_of_week = 1 then
    v_reward_type := 'silver'; v_amount := 200 * v_week_factor; v_cosmetic_id := null;
  elsif v_day_of_week = 2 then
    v_reward_type := 'silver'; v_amount := 300 * v_week_factor; v_cosmetic_id := null;
  elsif v_day_of_week = 3 then
    v_reward_type := 'xp'; v_amount := 100; v_cosmetic_id := null;
  elsif v_day_of_week = 4 then
    v_reward_type := 'gold'; v_amount := 1 * v_week_factor; v_cosmetic_id := null;
  elsif v_day_of_week = 5 then
    v_reward_type := 'silver'; v_amount := 600 * v_week_factor; v_cosmetic_id := null;
  elsif v_day_of_week = 6 then
    v_reward_type := 'spin_ticket'; v_amount := 1; v_cosmetic_id := null;
  else -- Day 7 (Jackpot)
    v_reward_type := 'gold'; v_amount := 15 * v_week_factor; v_cosmetic_id := null;
  end if;

  -- Record checkin in database history
  insert into public.checkin_history (user_id, month_key, day_number)
  values (v_user_id, to_char(current_date, 'YYYY-MM'), v_next_day);

  -- Record claim
  insert into public.reward_claims (user_id, source_type, source_id)
  values (v_user_id, 'checkin', to_char(current_date, 'YYYY-MM') || ':' || v_next_day)
  on conflict (user_id, source_type, source_id) do nothing;

  -- Dispense rewards
  perform public.dispense_reward(
    v_user_id,
    'checkin',
    v_next_day::text,
    v_reward_type,
    v_amount,
    v_cosmetic_id
  );

  return jsonb_build_object(
    'success', true,
    'day_claimed', v_next_day,
    'reward_type', v_reward_type,
    'amount', v_amount,
    'cosmetic_id', v_cosmetic_id
  );
end;
$$ language plpgsql security definer;

-- 9. Redefine process_xp_event to grant 500 silver and 1-5 gold on ad watch
create or replace function public.process_xp_event(
  p_event_type text,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_xp_reward integer;
  v_cooldown_seconds integer;
  v_ip text;
  v_device_id text;
  v_recipient_id uuid;
  v_recipient_ip text;
  v_recipient_device_id text;
  v_daily_free_limit integer := 250;
  v_daily_bonus_limit integer := 250;
  v_limit_record record;
  v_xp_gained integer;
  v_is_gift_bonus boolean := false;
  v_current_level integer;
  v_current_xp integer;
  v_total_xp integer;
  v_next_xp_required integer;
  v_reward_record record;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in to trigger progression.';
  end if;

  -- advisory lock to prevent concurrent races
  perform pg_advisory_xact_lock(('x' || substr(md5(v_user_id::text), 1, 15))::bit(60)::bigint);

  -- Fetch configuration
  select xp_reward, cooldown_seconds into v_xp_reward, v_cooldown_seconds
  from public.xp_config
  where event_type = p_event_type;

  if v_xp_reward is null then
    v_xp_reward := 10; -- default fallback
    v_cooldown_seconds := 0;
  end if;

  -- ── Cooldown Check ────────────────────────────────────────────────────────
  if v_cooldown_seconds > 0 then
    if exists (
      select 1 from public.xp_history
      where user_id = v_user_id
        and event_type = p_event_type
        and created_at > now() - (v_cooldown_seconds * interval '1 second')
    ) then
      return jsonb_build_object('success', false, 'reason', 'Cooldown active', 'cooldown_active', true);
    end if;
  end if;

  -- ── Anti-Cheat Engine ─────────────────────────────────────────────────────
  v_ip := p_metadata->>'ip';
  v_device_id := p_metadata->>'device_id';
  
  if p_event_type in ('gift_sent', 'gift_received') then
    v_recipient_id := (p_metadata->>'recipient_id')::uuid;
    v_recipient_ip := p_metadata->>'recipient_ip';
    v_recipient_device_id := p_metadata->>'recipient_device_id';
    v_is_gift_bonus := true;

    -- Self-gifting block
    if v_user_id = v_recipient_id then
      insert into public.reward_logs (user_id, source_type, source_id, reward_type, amount, cosmetic_id, status, reason)
      values (v_user_id, 'xp_engine', p_event_type, 'xp', v_xp_reward, null, 'Blocked', 'Self Gifting detected');
      return jsonb_build_object('success', false, 'reason', 'Anti-cheat: Self gifting is blocked');
    end if;

    -- Alternate accounts block (IP or device ID check)
    if (v_device_id is not null and v_device_id = v_recipient_device_id) or (v_ip is not null and v_ip = v_recipient_ip) then
      insert into public.reward_logs (user_id, source_type, source_id, reward_type, amount, cosmetic_id, status, reason)
      values (v_user_id, 'xp_engine', p_event_type, 'xp', v_xp_reward, null, 'Blocked', 'Alternate account exploitation detected');
      return jsonb_build_object('success', false, 'reason', 'Anti-cheat: Alternate account exploitation detected');
    end if;

    -- Rapid repeated gifting check
    if exists (
      select 1 from public.gift_xp_logs
      where sender_id = v_user_id
        and receiver_id = v_recipient_id
        and created_at > now() - interval '5 seconds'
    ) then
      -- Rate limited gift XP
      return jsonb_build_object('success', false, 'reason', 'Spam protection: Gifting too fast');
    end if;

    -- Log gift transaction
    insert into public.gift_xp_logs (sender_id, receiver_id, gift_id, xp_value)
    values (v_user_id, v_recipient_id, coalesce(p_metadata->>'gift_id', 'unknown'), v_xp_reward);
  end if;

  -- ── Daily XP Limit Validation ─────────────────────────────────────────────
  -- Fetch or create daily limit record
  select * into v_limit_record
  from public.daily_limits
  where user_id = v_user_id and date = current_date;

  if v_limit_record.id is null then
    insert into public.daily_limits (user_id, date, free_xp, bonus_xp)
    values (v_user_id, current_date, 0, 0)
    returning * into v_limit_record;
  end if;

  v_xp_gained := v_xp_reward;

  if v_is_gift_bonus then
    if v_limit_record.bonus_xp >= v_daily_bonus_limit then
      return jsonb_build_object('success', false, 'reason', 'Daily gift bonus XP limit reached');
    end if;
    if v_limit_record.bonus_xp + v_xp_gained > v_daily_bonus_limit then
      v_xp_gained := v_daily_bonus_limit - v_limit_record.bonus_xp;
    end if;
  else
    if p_event_type = 'ad_watched' then
      -- Ad count check (max 5 per day)
      if v_limit_record.ad_count >= 5 then
        return jsonb_build_object('success', false, 'reason', 'Daily rewarded ad limit (5) reached');
      end if;
      update public.daily_limits set ad_count = ad_count + 1 where id = v_limit_record.id;
    end if;

    if v_limit_record.free_xp >= v_daily_free_limit then
      return jsonb_build_object('success', false, 'reason', 'Daily free XP limit reached');
    end if;
    if v_limit_record.free_xp + v_xp_gained > v_daily_free_limit then
      v_xp_gained := v_daily_free_limit - v_limit_record.free_xp;
    end if;
  end if;

  if v_xp_gained <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Daily limit reached');
  end if;

  -- ── Apply XP updates ──────────────────────────────────────────────────────
  -- Update daily limit count
  if v_is_gift_bonus then
    update public.daily_limits set bonus_xp = bonus_xp + v_xp_gained where id = v_limit_record.id;
  else
    update public.daily_limits set free_xp = free_xp + v_xp_gained where id = v_limit_record.id;
  end if;

  -- Update user_levels
  select level, xp, total_xp into v_current_level, v_current_xp, v_total_xp
  from public.user_levels
  where id = v_user_id;

  v_current_xp := v_current_xp + v_xp_gained;
  v_total_xp := v_total_xp + v_xp_gained;

  insert into public.xp_history (user_id, event_type, xp_gained, metadata)
  values (v_user_id, p_event_type, v_xp_gained, p_metadata);

  -- ── Event-Specific Extra Currency Drops ───────────────────────────────────
  if p_event_type = 'ad_watched' then
    -- Watch ad grants 500 silver and 1 to 5 gold
    perform public.dispense_reward(v_user_id, 'ad_watched', 'ad_session', 'silver', 500, null);
    declare
      v_random_gold integer := floor(random() * (5 - 1 + 1) + 1)::integer;
    begin
      perform public.dispense_reward(v_user_id, 'ad_watched', 'ad_session', 'gold', v_random_gold, null);
    end;
  elsif p_event_type = 'room_joined_minute' then
    -- Join room grants 20 silver per minute
    perform public.dispense_reward(v_user_id, 'progression', 'room_minute', 'silver', 20, null);
  elsif p_event_type = 'room_hosted_minute' then
    -- Host room (microphone seat) grants 50 silver per minute
    perform public.dispense_reward(v_user_id, 'progression', 'host_minute', 'silver', 50, null);
  end if;

  -- ── Level Up Check ────────────────────────────────────────────────────────
  declare
    v_level_up_occurred boolean := false;
    v_start_level integer := v_current_level;
  begin
    loop
      select xp_required into v_next_xp_required
      from public.level_requirements
      where level = v_current_level + 1;

      exit when v_next_xp_required is null or v_current_xp < v_next_xp_required or v_current_level >= 60;

      v_current_xp := v_current_xp - v_next_xp_required;
      v_current_level := v_current_level + 1;
      v_level_up_occurred := true;

      -- Log level up history
      insert into public.xp_history (user_id, event_type, xp_gained, metadata)
      values (v_user_id, 'level_up', 0, jsonb_build_object('reached_level', v_current_level));

      -- Dispense Level Rewards
      for v_reward_record in 
        select reward_type, amount, cosmetic_id 
        from public.level_rewards 
        where level = v_current_level
      loop
        perform public.dispense_reward(
          v_user_id, 
          'level_up', 
          v_current_level::text, 
          v_reward_record.reward_type, 
          v_reward_record.amount, 
          v_reward_record.cosmetic_id
        );
      end loop;

      -- Send level up app notification
      insert into public.notifications (user_id, title, content, type)
      values (
        v_user_id,
        '🎉 Level Up!',
        'Congratulations! You reached Level ' || v_current_level || '! Check your Progression Hub for unlocked features and rewards.',
        'System'
      );
    end loop;

    -- Reset daily/weekly/monthly sums on date changes (managed on XP update)
    update public.user_levels
    set level = v_current_level,
        xp = v_current_xp,
        total_xp = v_total_xp,
        today_earned_xp = case when last_xp_update::date = current_date then today_earned_xp + v_xp_gained else v_xp_gained end,
        today_bonus_xp = case when last_xp_update::date = current_date then today_bonus_xp + (case when v_is_gift_bonus then v_xp_gained else 0 end) else (case when v_is_gift_bonus then v_xp_gained else 0 end) end,
        weekly_xp = case when date_trunc('week', last_xp_update) = date_trunc('week', now()) then weekly_xp + v_xp_gained else v_xp_gained end,
        monthly_xp = case when date_trunc('month', last_xp_update) = date_trunc('month', now()) then monthly_xp + v_xp_gained else v_xp_gained end,
        last_xp_update = now(),
        updated_at = now()
    where id = v_user_id;

    -- Increment progress on running tasks matching this event type
    perform public.increment_task_progress(v_user_id, p_event_type, 1);

    -- Return progression feedback JSON
    return jsonb_build_object(
      'success', true,
      'xp_gained', v_xp_gained,
      'current_level', v_current_level,
      'current_xp', v_current_xp,
      'level_up_occurred', v_level_up_occurred,
      'levels_gained', v_current_level - v_start_level
    );
  end;
end;
$$ language plpgsql security definer;
