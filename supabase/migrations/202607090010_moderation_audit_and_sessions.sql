-- ==========================================================================
-- Consolidated Supabase Migration Module 10: 202607090010_moderation_audit_and_sessions.sql
-- Authoritative baseline schema, functions, triggers, policies, and seeds.
-- ==========================================================================

create table public.moderation_logs (
  id uuid default gen_random_uuid() primary key,
  admin_id uuid references public.admins(id) on delete set null,
  target_id text not null,
  target_type text not null,
  action text not null,
  reason text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create index if not exists idx_user_sessions_user_id on public.user_sessions(user_id);

create index if not exists idx_user_sessions_status on public.user_sessions(user_id, online_status);

do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'user_sessions' and policyname = 'Allow select for self') then
    create policy "Allow select for self" on public.user_sessions
      for select using (auth.uid() = user_id);
  end if;
  
  if not exists (select 1 from pg_policies where tablename = 'user_sessions' and policyname = 'Allow insert/update for self') then
    create policy "Allow insert/update for self" on public.user_sessions
      for all using (auth.uid() = user_id);
  end if;
end
$$;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'tr_session_insert') then
    create trigger tr_session_insert
      before insert on public.user_sessions
      for each row execute function public.on_session_insert();
  end if;
end
$$;

ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS attachment_urls text[] DEFAULT '{}';

-- Functions
create or replace function public.is_admin(user_id uuid)
returns boolean
security definer
stable
language sql
as $$
  select exists (
    select 1 from public.admins where id = user_id
  );
$$;

-- =========================================================================
-- SECURE ADMIN PORTAL RPC FUNCTIONS
-- =========================================================================

-- Adjust user XP (Add/subtract/set)
create or replace function public.admin_adjust_user_xp(
  p_target_user_id uuid,
  p_xp_amount integer,
  p_is_absolute boolean default false
)
returns jsonb as $$
declare
  v_admin_id uuid := auth.uid();
  v_current_level integer;
  v_current_xp integer;
  v_total_xp integer;
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'UNAUTHORIZED: Admin access only.';
  end if;

  select level, xp, total_xp into v_current_level, v_current_xp, v_total_xp
  from public.user_levels
  where id = p_target_user_id;

  if v_current_level is null then
    raise exception 'USER_NOT_FOUND: User progression row not found.';
  end if;

  if p_is_absolute then
    v_current_xp := p_xp_amount;
    v_total_xp := p_xp_amount;
  else
    v_current_xp := v_current_xp + p_xp_amount;
    v_total_xp := v_total_xp + p_xp_amount;
  end if;

  update public.user_levels
  set xp = greatest(v_current_xp, 0),
      total_xp = greatest(v_total_xp, 0),
      updated_at = now()
  where id = p_target_user_id;

  -- Run Level Up checks
  perform public.add_direct_xp(p_target_user_id, 0, 'admin_adjust');

  -- Log action
  insert into public.audit_logs (actor_id, action, details)
  values (v_admin_id, 'admin_adjust_xp', jsonb_build_object('target', p_target_user_id, 'xp_added', p_xp_amount, 'is_absolute', p_is_absolute));

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

-- Set user Level
create or replace function public.admin_adjust_user_level(
  p_target_user_id uuid,
  p_level integer
)
returns jsonb as $$
declare
  v_admin_id uuid := auth.uid();
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'UNAUTHORIZED: Admin access only.';
  end if;

  if p_level < 1 or p_level > 60 then
    raise exception 'INVALID_LEVEL: Level must be between 1 and 60.';
  end if;

  update public.user_levels
  set level = p_level,
      xp = 0, -- resets current level XP
      updated_at = now()
  where id = p_target_user_id;

  -- Log action
  insert into public.audit_logs (actor_id, action, details)
  values (v_admin_id, 'admin_adjust_level', jsonb_build_object('target', p_target_user_id, 'new_level', p_level));

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

-- View abuse / anti-cheat reports
create or replace function public.admin_get_abuse_reports()
returns jsonb as $$
declare
  v_admin_id uuid := auth.uid();
  v_logs jsonb;
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'UNAUTHORIZED: Admin access only.';
  end if;

  select jsonb_agg(to_jsonb(l)) into v_logs
  from (
    select id, user_id, source_type, source_id, reward_type, amount, status, reason, created_at
    from public.reward_logs
    where status = 'Blocked'
    order by created_at desc
    limit 100
  ) l;

  return coalesce(v_logs, '[]'::jsonb);
end;
$$ language plpgsql security definer;

-- Reset user progression
create or replace function public.admin_reset_user_progression(
  p_target_user_id uuid
)
returns jsonb as $$
declare
  v_admin_id uuid := auth.uid();
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'UNAUTHORIZED: Admin access only.';
  end if;

  update public.user_levels
  set level = 1,
      xp = 0,
      total_xp = 0,
      today_earned_xp = 0,
      today_bonus_xp = 0,
      weekly_xp = 0,
      monthly_xp = 0,
      last_xp_update = now(),
      updated_at = now()
  where id = p_target_user_id;

  -- Clear claims and history
  delete from public.reward_claims where user_id = p_target_user_id;
  delete from public.xp_history where user_id = p_target_user_id;
  delete from public.task_progress where user_id = p_target_user_id;
  delete from public.checkin_history where user_id = p_target_user_id;
  delete from public.achievement_progress where user_id = p_target_user_id;
  delete from public.spin_history where user_id = p_target_user_id;

  -- Log action
  insert into public.audit_logs (actor_id, action, details)
  values (v_admin_id, 'admin_reset_progression', jsonb_build_object('target', p_target_user_id));

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

-- RPC: Unblock User
CREATE OR REPLACE FUNCTION public.unblock_user(p_blocked_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_blocker_id uuid := auth.uid();
BEGIN
  IF v_blocker_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  DELETE FROM public.user_blocks
  WHERE blocker_id = v_blocker_id AND blocked_id = p_blocked_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- RPC: Log Login Activity
CREATE OR REPLACE FUNCTION public.log_user_login(
  p_device_name text,
  p_platform text,
  p_ip text DEFAULT '127.0.0.1',
  p_session_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  INSERT INTO public.user_login_activity (user_id, device_name, platform, ip_address, session_id, login_at)
  VALUES (v_user_id, p_device_name, p_platform, p_ip, p_session_id, timezone('utc'::text, now()));

  RETURN jsonb_build_object('success', true);
END;
$$;

-- 2. RPC: Check Bidirectional User Block Status
CREATE OR REPLACE FUNCTION public.is_user_blocked(p_user1_id uuid, p_user2_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_exists boolean := false;
BEGIN
  IF p_user1_id IS NULL OR p_user2_id IS NULL THEN
    RETURN false;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.user_blocks
    WHERE (blocker_id = p_user1_id AND blocked_id = p_user2_id)
       OR (blocker_id = p_user2_id AND blocked_id = p_user1_id)
  ) INTO v_exists;

  RETURN v_exists;
END;
$$;

