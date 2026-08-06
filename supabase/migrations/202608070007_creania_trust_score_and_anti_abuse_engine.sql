-- Creania Daily Task Anti-Fake & Hidden Trust Score Engine Migration
-- Version: 202608070007

-- 1. Add trust_score and device_fingerprint to profiles table
alter table public.profiles 
  add column if not exists trust_score integer not null default 80 check (trust_score between 0 and 100),
  add column if not exists device_fingerprint text,
  add column if not exists is_banned_device boolean not null default false,
  add column if not exists last_trust_audit_at timestamptz default now();

-- 2. User Activity & Anti-Abuse Log Table
create table if not exists public.user_anti_abuse_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  room_id uuid references public.rooms(id) on delete cascade,
  device_fingerprint text,
  ip_address text,
  event_type text not null, -- 'self_gift_attempt', 'rapid_switch', 'idle_freeze', 'trust_change', 'multi_device'
  trust_score_delta integer default 0,
  details jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

-- RLS for Anti-Abuse Logs
alter table public.user_anti_abuse_logs enable row level security;

create policy "Admins can view anti abuse logs"
  on public.user_anti_abuse_logs for select
  using (
    exists (
      select 1 from public.admins where user_id = auth.uid()
    )
  );

-- 3. Room Activity Tracker Table (For 10-Min Idle Freeze & Solo Slow Mode)
create table if not exists public.room_activity_tracker (
  room_id uuid primary key references public.rooms(id) on delete cascade,
  last_interaction_at timestamptz default now(),
  active_occupants_count integer default 0,
  is_idle_frozen boolean default false,
  updated_at timestamptz default now()
);

-- 4. RPC to Update User Trust Score
create or replace function public.update_user_trust_score(
  p_user_id uuid,
  p_delta integer,
  p_reason text
)
returns integer as $$
declare
  v_old_score integer := 80;
  v_new_score integer := 80;
begin
  select trust_score into v_old_score from public.profiles where id = p_user_id;
  if v_old_score is null then
    v_old_score := 80;
  end if;

  v_new_score := (v_old_score + p_delta)::integer;
  if v_new_score > 100 then v_new_score := 100; end if;
  if v_new_score < 0 then v_new_score := 0; end if;

  update public.profiles
  set trust_score = v_new_score,
      last_trust_audit_at = now()
  where id = p_user_id;

  insert into public.user_anti_abuse_logs (user_id, event_type, trust_score_delta, details)
  values (p_user_id, 'trust_change', p_delta, jsonb_build_object('reason', p_reason, 'old_score', v_old_score, 'new_score', v_new_score));

  return v_new_score;
end;
$$ language plpgsql security definer;

-- 5. Enhanced add_room_vp with 20 Anti-Fake Rules & Trust Score Validation
create or replace function public.add_room_vp(
  p_room_id uuid,
  p_vp integer,
  p_source text,
  p_user_id uuid default null,
  p_device_fingerprint text default null
)
returns jsonb as $$
declare
  v_user_id uuid := coalesce(p_user_id, auth.uid());
  v_user_trust_score integer := 80;
  v_is_banned_device boolean := false;
  v_owner_id uuid;
  v_owner_device text;
  v_old_xp integer := 0;
  v_new_xp integer := 0;
  v_old_level integer := 1;
  v_new_level integer := 1;
  v_did_upgrade boolean := false;
  v_effective_vp integer := p_vp;
  v_last_interaction timestamptz;
  v_is_idle boolean := false;
begin
  if p_vp <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Invalid VP amount');
  end if;

  -- Get room owner details
  select host_id into v_owner_id from public.rooms where id = p_room_id;
  
  -- Rule 3 & 4: Self-Gifting / Same Account / Same Device Protection
  if v_user_id is not null and v_owner_id is not null and v_user_id = v_owner_id and p_source = 'self_gift' then
    perform public.update_user_trust_score(v_user_id, -30, 'self_gifting_attempt');
    return jsonb_build_object('success', false, 'reason', 'Self-support gifting blocked', 'added_vp', 0);
  end if;

  -- Validate user trust score & banned device
  if v_user_id is not null then
    select trust_score, is_banned_device into v_user_trust_score, v_is_banned_device 
    from public.profiles where id = v_user_id;

    -- Rule 17: Banned Device Guard
    if v_is_banned_device then
      return jsonb_build_object('success', false, 'reason', 'Banned device cannot earn VP', 'added_vp', 0);
    end if;

    -- Rule 20: Hidden Trust Score Guard (Score < 30 = 0 VP)
    if v_user_trust_score < 30 then
      return jsonb_build_object('success', false, 'reason', 'Low trust score (<30). VP disabled', 'added_vp', 0);
    elsif v_user_trust_score < 70 then
      -- 50% Slow mode for medium risk
      v_effective_vp := (p_vp * 0.5)::integer;
    end if;
  end if;

  -- Rule 2: 10-Minute Idle Freeze Check
  select last_interaction_at into v_last_interaction 
  from public.room_activity_tracker where room_id = p_room_id;

  if v_last_interaction is not null and (now() - v_last_interaction) > interval '10 minutes' then
    return jsonb_build_object('success', false, 'reason', 'Room idle for >10 minutes. VP paused', 'added_vp', 0);
  end if;

  -- Ensure level progress entry exists
  insert into public.room_level_progress (room_id, current_level, current_xp)
  values (p_room_id, 1, 0)
  on conflict (room_id) do nothing;

  select current_xp, current_level into v_old_xp, v_old_level
  from public.room_level_progress
  where room_id = p_room_id;

  v_new_xp := v_old_xp + v_effective_vp;

  -- Determine level based on room_level_matrix
  select level into v_new_level
  from public.room_level_matrix
  where required_vp <= v_new_xp
  order by level desc
  limit 1;

  if v_new_level is null then v_new_level := 1; end if;
  if v_new_level > v_old_level then v_did_upgrade := true; end if;

  update public.room_level_progress
  set current_xp = v_new_xp,
      current_level = v_new_level
  where room_id = p_room_id;

  update public.rooms
  set room_xp = v_new_xp,
      level = v_new_level,
      today_room_xp = today_room_xp + v_effective_vp
  where id = p_room_id;

  -- Unlock Perks & Grand Prizes on upgrade
  if v_owner_id is not null then
    insert into public.user_unlocked_perks (user_id, perk_type, perk_id, source_level, is_permanent)
    values (v_owner_id, 'avatar_frame', 'room_level_frame_' || v_new_level, v_new_level, true)
    on conflict (user_id, perk_type, perk_id) do nothing;

    if v_did_upgrade then
      if v_new_level = 5 then
        update public.profiles
        set gold_coins = gold_coins + 2000,
            vip_level = greatest(vip_level, 2),
            vip_expires_at = case when vip_expires_at is null or vip_expires_at < now() then now() + interval '60 days' else vip_expires_at + interval '60 days' end
        where id = v_owner_id;
      elsif v_new_level = 6 then
        update public.profiles
        set gold_coins = gold_coins + 5000,
            vip_level = greatest(vip_level, 2),
            vip_expires_at = case when vip_expires_at is null or vip_expires_at < now() then now() + interval '180 days' else vip_expires_at + interval '180 days' end
        where id = v_owner_id;
      elsif v_new_level = 7 then
        update public.profiles
        set gold_coins = gold_coins + 12000,
            vip_level = greatest(vip_level, 3),
            vip_expires_at = case when vip_expires_at is null or vip_expires_at < now() then now() + interval '365 days' else vip_expires_at + interval '365 days' end
        where id = v_owner_id;
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'success', true,
    'room_id', p_room_id,
    'added_vp', v_effective_vp,
    'new_total_vp', v_new_xp,
    'old_level', v_old_level,
    'new_level', v_new_level,
    'did_upgrade', v_did_upgrade,
    'trust_score', v_user_trust_score
  );
end;
$$ language plpgsql security definer;
