-- 202608070007_creania_room_task_anti_fraud_and_trust_score.sql
-- Creania Arena Daily Task Anti-Fake Rules (1-20) Engine & Hidden Trust Score System (0-100)

-- 1. User Trust Scores Table
create table if not exists public.user_trust_scores (
  user_id uuid references public.profiles(id) on delete cascade primary key,
  trust_score integer default 80 not null check (trust_score between 0 and 100),
  activity_score integer default 50 not null check (activity_score between 0 and 100),
  risk_score integer default 0 not null check (risk_score between 0 and 100),
  is_verified boolean default false not null,
  is_emulator boolean default false not null,
  is_vpn boolean default false not null,
  is_device_banned boolean default false not null,
  last_ip text,
  device_fingerprint text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. User Device Fingerprints Table
create table if not exists public.user_device_fingerprints (
  device_fingerprint text not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  first_seen_at timestamp with time zone default timezone('utc'::text, now()) not null,
  last_seen_at timestamp with time zone default timezone('utc'::text, now()) not null,
  is_banned boolean default false not null,
  primary key (device_fingerprint, user_id)
);

-- 3. Room Anti Abuse Audit Logs
create table if not exists public.room_anti_abuse_logs (
  id uuid default gen_random_uuid() primary key,
  room_id text,
  user_id uuid references public.profiles(id) on delete cascade,
  violation_code text not null,
  details text,
  ip_address text,
  device_fingerprint text,
  trust_score_snapshot integer,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Indexing for high performance anti-fraud queries
create index if not exists idx_user_trust_scores_user_id on public.user_trust_scores(user_id);
create index if not exists idx_user_device_fingerprints_device on public.user_device_fingerprints(device_fingerprint);
create index if not exists idx_room_anti_abuse_logs_user_room on public.room_anti_abuse_logs(user_id, room_id);

-- 4. Calculate User Trust Score Function
create or replace function public.calculate_user_trust_score(
  p_user_id uuid
)
returns jsonb as $$
declare
  v_score integer := 80;
  v_activity_score integer := 50;
  v_risk_score integer := 0;
  v_is_verified boolean := false;
  v_is_emulator boolean := false;
  v_is_vpn boolean := false;
  v_is_device_banned boolean := false;
  v_account_age_days integer := 0;
  v_linked_accounts_count integer := 0;
  v_multiplier numeric := 1.0;
begin
  if p_user_id is null then
    return jsonb_build_object('trust_score', 0, 'multiplier', 0.0, 'status', 'unauthenticated');
  end if;

  -- Read profile parameters
  select 
    coalesce(extract(day from (now() - p.created_at)), 0)::integer,
    coalesce(uts.trust_score, 80),
    coalesce(uts.activity_score, 50),
    coalesce(uts.risk_score, 0),
    coalesce(uts.is_verified, false),
    coalesce(uts.is_emulator, false),
    coalesce(uts.is_vpn, false),
    coalesce(uts.is_device_banned, false)
  into 
    v_account_age_days, v_score, v_activity_score, v_risk_score,
    v_is_verified, v_is_emulator, v_is_vpn, v_is_device_banned
  from public.profiles p
  left join public.user_trust_scores uts on uts.user_id = p.id
  where p.id = p_user_id;

  -- Adjust trust score dynamically based on trust rules
  -- Verified account bonus (+15)
  if v_is_verified then
    v_score := v_score + 15;
  end if;

  -- Older account bonus (+10 for > 30 days)
  if v_account_age_days >= 30 then
    v_score := v_score + 10;
  end if;

  -- Emulator penalty (-30)
  if v_is_emulator then
    v_score := v_score - 30;
    v_risk_score := v_risk_score + 25;
  end if;

  -- VPN penalty (-20)
  if v_is_vpn then
    v_score := v_score - 20;
    v_risk_score := v_risk_score + 20;
  end if;

  -- Device ban penalty (-100)
  if v_is_device_banned then
    v_score := 0;
    v_risk_score := 100;
  end if;

  -- Clamp score range 0-100
  v_score := greatest(0, least(100, v_score));
  v_risk_score := greatest(0, least(100, v_risk_score));

  -- Determine VP payout multiplier based on score bracket
  if v_is_device_banned or v_score < 20 then
    v_multiplier := 0.0;
  elsif v_score < 50 then
    v_multiplier := 0.5;
  else
    v_multiplier := 1.0;
  end if;

  -- Ensure record exists in user_trust_scores
  insert into public.user_trust_scores (user_id, trust_score, activity_score, risk_score, is_verified, is_emulator, is_vpn, is_device_banned, updated_at)
  values (p_user_id, v_score, v_activity_score, v_risk_score, v_is_verified, v_is_emulator, v_is_vpn, v_is_device_banned, now())
  on conflict (user_id) do update set
    trust_score = excluded.trust_score,
    activity_score = excluded.activity_score,
    risk_score = excluded.risk_score,
    updated_at = now();

  return jsonb_build_object(
    'user_id', p_user_id,
    'trust_score', v_score,
    'activity_score', v_activity_score,
    'risk_score', v_risk_score,
    'multiplier', v_multiplier,
    'is_verified', v_is_verified,
    'is_emulator', v_is_emulator,
    'is_vpn', v_is_vpn,
    'is_device_banned', v_is_device_banned
  );
end;
$$ language plpgsql security definer;

-- 5. Validate & Add Room VP (Complete Server-Side Anti-Fake RPC)
create or replace function public.validate_and_add_room_vp(
  p_room_id text,
  p_user_id uuid,
  p_vp integer,
  p_source text,
  p_stay_seconds integer default 60,
  p_target_user_id uuid default null,
  p_device_fingerprint text default null,
  p_is_emulator boolean default false,
  p_is_vpn boolean default false
)
returns jsonb as $$
declare
  v_trust_data jsonb;
  v_trust_score integer := 80;
  v_multiplier numeric := 1.0;
  v_is_banned boolean := false;
  v_allowed_vp integer := 0;
  v_final_vp integer := 0;
  v_seat_count integer := 0;
  v_target_device text;
  v_rpc_res jsonb;
begin
  if p_vp <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Invalid VP input', 'added_vp', 0);
  end if;

  -- Evaluate user trust score (Rules 19, 20)
  v_trust_data := public.calculate_user_trust_score(p_user_id);
  v_trust_score := (v_trust_data->>'trust_score')::integer;
  v_multiplier := (v_trust_data->>'multiplier')::numeric;
  v_is_banned := (v_trust_data->>'is_device_banned')::boolean;

  -- Device Ban Check (Rule 17)
  if v_is_banned then
    insert into public.room_anti_abuse_logs (room_id, user_id, violation_code, details, device_fingerprint, trust_score_snapshot)
    values (p_room_id, p_user_id, 'DEVICE_BANNED', 'Banned device attempted VP action', p_device_fingerprint, v_trust_score);
    return jsonb_build_object('success', false, 'reason', 'Device is banned from earning VP', 'added_vp', 0);
  end if;

  -- Check if device fingerprint is banned in device table (Rule 17)
  if p_device_fingerprint is not null then
    if exists (select 1 from public.user_device_fingerprints where device_fingerprint = p_device_fingerprint and is_banned = true) then
      insert into public.room_anti_abuse_logs (room_id, user_id, violation_code, details, device_fingerprint, trust_score_snapshot)
      values (p_room_id, p_user_id, 'FINGERPRINT_BANNED', 'Banned device fingerprint detected', p_device_fingerprint, v_trust_score);
      return jsonb_build_object('success', false, 'reason', 'Device fingerprint is banned', 'added_vp', 0);
    end if;

    -- Upsert device linkage
    insert into public.user_device_fingerprints (device_fingerprint, user_id, last_seen_at)
    values (p_device_fingerprint, p_user_id, now())
    on conflict (device_fingerprint, user_id) do update set last_seen_at = now();
  end if;

  -- Self-Support Protection (Rule 4)
  if p_target_user_id is not null then
    if p_target_user_id = p_user_id then
      insert into public.room_anti_abuse_logs (room_id, user_id, violation_code, details, trust_score_snapshot)
      values (p_room_id, p_user_id, 'SELF_GIFT_BLOCKED', 'User attempted self-gifting VP', v_trust_score);
      return jsonb_build_object('success', false, 'reason', 'Self gifting VP not allowed', 'added_vp', 0);
    end if;

    -- Check if target user shares same device fingerprint (Rule 3 & 4)
    if p_device_fingerprint is not null then
      select device_fingerprint into v_target_device
      from public.user_trust_scores
      where user_id = p_target_user_id;

      if v_target_device is not null and v_target_device = p_device_fingerprint then
        insert into public.room_anti_abuse_logs (room_id, user_id, violation_code, details, device_fingerprint, trust_score_snapshot)
        values (p_room_id, p_user_id, 'SAME_DEVICE_SELF_SUPPORT', 'Self-support detected on same device fingerprint', p_device_fingerprint, v_trust_score);
        return jsonb_build_object('success', false, 'reason', 'Multi-account self support detected on same device', 'added_vp', 0);
      end if;
    end if;
  end if;

  -- Minimum Stay Requirement Validation (Rule 12)
  if p_source in ('user_stay_time', 'active_mic_time') and p_stay_seconds < 60 then
    return jsonb_build_object('success', false, 'reason', 'Minimum valid stay duration (60s) not met', 'added_vp', 0);
  end if;

  -- Apply base VP & trust multiplier
  v_allowed_vp := (p_vp * v_multiplier)::integer;

  -- Solo Seat Slow Mode Adjustment (Rule 1)
  select count(*) into v_seat_count
  from public.room_seats
  where room_id = p_room_id and user_id is not null;

  if v_seat_count = 1 and p_source = 'active_mic_time' then
    v_allowed_vp := (v_allowed_vp * 0.5)::integer;
  end if;

  if v_allowed_vp <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Low trust score or zero multiplier', 'added_vp', 0);
  end if;

  -- Execute add_room_vp RPC
  v_rpc_res := public.add_room_vp(p_room_id, v_allowed_vp, p_source);

  return jsonb_build_object(
    'success', coalesce((v_rpc_res->>'success')::boolean, true),
    'room_id', p_room_id,
    'user_id', p_user_id,
    'requested_vp', p_vp,
    'allowed_vp', v_allowed_vp,
    'added_vp', coalesce((v_rpc_res->>'added_vp')::integer, v_allowed_vp),
    'trust_score', v_trust_score,
    'multiplier', v_multiplier,
    'seat_count', v_seat_count
  );
end;
$$ language plpgsql security definer;
