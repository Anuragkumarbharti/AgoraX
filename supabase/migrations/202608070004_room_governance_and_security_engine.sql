-- Migration: Enterprise Voice Room Governance, Security & Moderation Engine (AgoraX v2.0)
-- Date: 2026-08-07

-- 1. Create Room Permission History Table (Permanent Immutable Log)
CREATE TABLE IF NOT EXISTS public.room_permission_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id text NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  actor_id uuid NOT NULL,
  actor_role text NOT NULL,
  target_user_id uuid NOT NULL,
  action_type text NOT NULL, -- 'PROMOTED', 'DEMOTED', 'PERMISSION_CHANGED', 'REMOVED'
  old_role text,
  new_role text,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 2. Create Admin Activity Logs Table
CREATE TABLE IF NOT EXISTS public.room_admin_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id text NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  admin_id uuid NOT NULL,
  action_type text NOT NULL, -- 'MUTE', 'UNMUTE', 'KICK', 'BAN', 'SEAT_LOCK', 'SEAT_UNLOCK', 'SPEAKER_ACCEPT', 'SPEAKER_REJECT', 'BG_CHANGE', 'EMERGENCY_TOGGLE', 'WARNING_ISSUED'
  target_user_id uuid,
  details jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 3. Create Room User Warnings Escalation Table
CREATE TABLE IF NOT EXISTS public.room_user_warnings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id text NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  issued_by uuid NOT NULL,
  warning_level int NOT NULL DEFAULT 1, -- 1, 2, 3
  reason text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 4. Extend Rooms Table with Governance & Security Columns
ALTER TABLE public.rooms 
ADD COLUMN IF NOT EXISTS security_score numeric(3,2) DEFAULT 5.00,
ADD COLUMN IF NOT EXISTS health_score int DEFAULT 100,
ADD COLUMN IF NOT EXISTS governance_level int DEFAULT 1,
ADD COLUMN IF NOT EXISTS is_emergency_mode boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS backup_owner_id uuid,
ADD COLUMN IF NOT EXISTS backup_owner_activated_at timestamptz,
ADD COLUMN IF NOT EXISTS admin_cooldown_hours int DEFAULT 0;

-- 5. Extend Room Members Table with Expiry and Custom Permissions
ALTER TABLE public.room_members 
ADD COLUMN IF NOT EXISTS custom_permissions jsonb DEFAULT '{"kick":true,"mute":true,"seat_lock":true,"background_change":true,"room_info_edit":true,"pk_start":true,"ban":false,"announcement":false}'::jsonb,
ADD COLUMN IF NOT EXISTS expires_at timestamptz,
ADD COLUMN IF NOT EXISTS admin_cooldown_expires_at timestamptz;

-- Enable RLS and define policies
ALTER TABLE public.room_permission_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_admin_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_user_warnings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow members to view permission history" ON public.room_permission_history;
CREATE POLICY "Allow members to view permission history" 
ON public.room_permission_history FOR SELECT 
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Allow members to view admin activity logs" ON public.room_admin_activity_logs;
CREATE POLICY "Allow members to view admin activity logs" 
ON public.room_admin_activity_logs FOR SELECT 
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Allow members to view room warnings" ON public.room_user_warnings;
CREATE POLICY "Allow members to view room warnings" 
ON public.room_user_warnings FOR SELECT 
USING (auth.uid() IS NOT NULL);

-- 6. RPC: Promote room member role v2 (Supports Expiry, Protection Checks, Custom Permissions, Audit History)
CREATE OR REPLACE FUNCTION public.promote_room_member_role_v2(
  p_room_id text,
  p_target_user_id uuid,
  p_new_role text,
  p_expiry_hours int DEFAULT NULL,
  p_custom_permissions jsonb DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_caller_role text := 'Visitor';
  v_old_role text := 'Visitor';
  v_is_room_owner boolean := false;
  v_limits RECORD;
  v_current_count int := 0;
  v_expires_at timestamptz := NULL;
  v_cooldown_exp timestamptz := NULL;
  v_default_perms jsonb := '{"kick":true,"mute":true,"seat_lock":true,"background_change":true,"room_info_edit":true,"pk_start":true,"ban":false,"announcement":false}'::jsonb;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Resolve room ID
  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN
    v_room_id := p_room_id;
  END IF;

  -- Verify room owner (Creator & Owner are unified)
  SELECT (host_id = v_caller_id OR room_owner = v_caller_id) INTO v_is_room_owner FROM public.rooms WHERE id = v_room_id;
  SELECT role INTO v_caller_role FROM public.room_members WHERE room_id = v_room_id AND user_id = v_caller_id;
  SELECT role, admin_cooldown_expires_at INTO v_old_role, v_cooldown_exp FROM public.room_members WHERE room_id = v_room_id AND user_id = p_target_user_id;

  IF v_is_room_owner THEN v_caller_role := 'Owner'; END IF;

  -- Check Admin Cooldown
  IF v_cooldown_exp IS NOT NULL AND v_cooldown_exp > now() AND NOT v_is_room_owner THEN
    RAISE EXCEPTION 'User is under Admin promotion cooldown until %', v_cooldown_exp;
  END IF;

  -- Authority Validation
  IF v_caller_role IN ('Creator', 'Owner') THEN
    IF p_new_role NOT IN ('Co-Owner', 'Admin') THEN
      RAISE EXCEPTION 'Invalid target role promotion: %', p_new_role;
    END IF;
  ELSIF v_caller_role IN ('Co-Owner', 'Co Owner') THEN
    IF p_new_role NOT IN ('Admin') THEN
      RAISE EXCEPTION 'Co-Owners can only promote members to Admin.';
    END IF;
  ELSE
    RAISE EXCEPTION 'Insufficient permissions to promote members.';
  END IF;

  -- Check Room Level Capacity Limits
  SELECT * FROM public.get_room_role_limits(v_room_id) INTO v_limits;
  IF p_new_role IN ('Co-Owner', 'Co Owner') THEN
    SELECT COUNT(*) INTO v_current_count FROM public.room_members 
    WHERE room_id = v_room_id AND role IN ('Co-Owner', 'Co Owner') AND user_id != p_target_user_id;
    IF v_current_count >= v_limits.max_co_owners THEN
      RAISE EXCEPTION 'Maximum Co-Owners limit reached for this room level (Limit: %).', v_limits.max_co_owners;
    END IF;
  ELSIF p_new_role = 'Admin' THEN
    SELECT COUNT(*) INTO v_current_count FROM public.room_members 
    WHERE room_id = v_room_id AND role = 'Admin' AND user_id != p_target_user_id;
    IF v_current_count >= v_limits.max_admins THEN
      RAISE EXCEPTION 'Maximum Admins limit reached for this room level (Limit: %).', v_limits.max_admins;
    END IF;
  END IF;

  -- Calculate Expiry
  IF p_expiry_hours IS NOT NULL AND p_expiry_hours > 0 THEN
    v_expires_at := now() + (p_expiry_hours || ' hours')::interval;
  END IF;

  IF p_custom_permissions IS NOT NULL THEN
    v_default_perms := p_custom_permissions;
  END IF;

  -- Standardize Role Name
  IF p_new_role = 'Co Owner' THEN p_new_role := 'Co-Owner'; END IF;

  -- Insert/Update role in room_members
  INSERT INTO public.room_members (
    room_id, user_id, role, custom_permissions, expires_at, assigned_by, assigned_at, updated_at
  )
  VALUES (
    v_room_id, p_target_user_id, p_new_role, v_default_perms, v_expires_at, v_caller_id, now(), now()
  )
  ON CONFLICT (room_id, user_id) DO UPDATE 
  SET role = p_new_role, 
      custom_permissions = v_default_perms,
      expires_at = v_expires_at,
      admin_cooldown_expires_at = NULL,
      assigned_by = v_caller_id, 
      assigned_at = now(), 
      updated_at = now();

  -- Record Permanent History Audit
  INSERT INTO public.room_permission_history (
    room_id, actor_id, actor_role, target_user_id, action_type, old_role, new_role, expires_at
  ) VALUES (
    v_room_id, v_caller_id, v_caller_role, p_target_user_id, 'PROMOTED', v_old_role, p_new_role, v_expires_at
  );

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'target_user_id', p_target_user_id,
    'new_role', p_new_role,
    'expires_at', v_expires_at
  );
END;
$$;

-- 7. RPC: Demote room member role v2 (Enforces Owner/Co-Owner Protection & Cooldown)
CREATE OR REPLACE FUNCTION public.demote_room_member_role_v2(
  p_room_id text,
  p_target_user_id uuid,
  p_apply_cooldown boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_caller_role text := 'Visitor';
  v_target_role text := 'Visitor';
  v_is_room_owner boolean := false;
  v_cooldown_hours int := 24;
  v_cooldown_exp timestamptz := NULL;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN
    v_room_id := p_room_id;
  END IF;

  SELECT (host_id = v_caller_id OR room_owner = v_caller_id), admin_cooldown_hours 
  INTO v_is_room_owner, v_cooldown_hours FROM public.rooms WHERE id = v_room_id;
  
  SELECT role INTO v_caller_role FROM public.room_members WHERE room_id = v_room_id AND user_id = v_caller_id;
  SELECT role INTO v_target_role FROM public.room_members WHERE room_id = v_room_id AND user_id = p_target_user_id;

  IF v_is_room_owner THEN v_caller_role := 'Owner'; END IF;

  -- OWNER PROTECTION: Owner cannot be demoted, kicked, or removed by anyone!
  IF p_target_user_id IN (SELECT host_id FROM public.rooms WHERE id = v_room_id) OR
     p_target_user_id IN (SELECT room_owner FROM public.rooms WHERE id = v_room_id) THEN
    RAISE EXCEPTION 'PROTECTION VIOLATION: Room Creator/Owner cannot be demoted or removed.';
  END IF;

  -- CO-OWNER PROTECTION: Admins CANNOT demote or remove Co-Owners!
  IF v_target_role IN ('Co-Owner', 'Co Owner') AND v_caller_role NOT IN ('Creator', 'Owner') THEN
    RAISE EXCEPTION 'PROTECTION VIOLATION: Co-Owners can only be demoted by the Room Owner.';
  END IF;

  IF v_caller_role NOT IN ('Creator', 'Owner', 'Co-Owner', 'Co Owner') THEN
    RAISE EXCEPTION 'Insufficient permissions to demote members.';
  END IF;

  IF p_apply_cooldown AND v_cooldown_hours > 0 THEN
    v_cooldown_exp := now() + (v_cooldown_hours || ' hours')::interval;
  END IF;

  UPDATE public.room_members 
  SET role = 'Listener', 
      custom_permissions = NULL,
      expires_at = NULL,
      admin_cooldown_expires_at = v_cooldown_exp,
      assigned_by = v_caller_id, 
      updated_at = now()
  WHERE room_id = v_room_id AND user_id = p_target_user_id;

  -- Record Permanent History Audit
  INSERT INTO public.room_permission_history (
    room_id, actor_id, actor_role, target_user_id, action_type, old_role, new_role
  ) VALUES (
    v_room_id, v_caller_id, v_caller_role, p_target_user_id, 'DEMOTED', v_target_role, 'Listener'
  );

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'target_user_id', p_target_user_id,
    'new_role', 'Listener',
    'cooldown_expires_at', v_cooldown_exp
  );
END;
$$;

-- 8. RPC: Issue Room Warning (3-Strike Escalation System)
CREATE OR REPLACE FUNCTION public.issue_room_warning(
  p_room_id text,
  p_target_user_id uuid,
  p_reason text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_caller_role text := 'Visitor';
  v_target_role text := 'Visitor';
  v_is_room_owner boolean := false;
  v_active_warnings int := 0;
  v_next_level int := 1;
  v_auto_kicked boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;

  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN v_room_id := p_room_id; END IF;

  SELECT (host_id = v_caller_id OR room_owner = v_caller_id) INTO v_is_room_owner FROM public.rooms WHERE id = v_room_id;
  SELECT role INTO v_caller_role FROM public.room_members WHERE room_id = v_room_id AND user_id = v_caller_id;
  SELECT role INTO v_target_role FROM public.room_members WHERE room_id = v_room_id AND user_id = p_target_user_id;

  IF v_is_room_owner THEN v_caller_role := 'Owner'; END IF;

  -- Protection Check: Cannot warn Owner or Co-Owner if caller is lower role
  IF v_target_role IN ('Creator', 'Owner') OR p_target_user_id IN (SELECT host_id FROM public.rooms WHERE id = v_room_id) THEN
    RAISE EXCEPTION 'PROTECTION VIOLATION: Cannot issue warnings to Room Owner.';
  END IF;
  IF v_target_role IN ('Co-Owner', 'Co Owner') AND v_caller_role NOT IN ('Owner', 'Creator') THEN
    RAISE EXCEPTION 'PROTECTION VIOLATION: Only Room Owner can warn Co-Owners.';
  END IF;

  -- Calculate Active Warning Count
  SELECT COUNT(*) INTO v_active_warnings FROM public.room_user_warnings 
  WHERE room_id = v_room_id AND user_id = p_target_user_id AND is_active = true;

  v_next_level := v_active_warnings + 1;

  INSERT INTO public.room_user_warnings (room_id, user_id, issued_by, warning_level, reason)
  VALUES (v_room_id, p_target_user_id, v_caller_id, v_next_level, p_reason);

  -- Log Admin Activity
  INSERT INTO public.room_admin_activity_logs (room_id, admin_id, action_type, target_user_id, details)
  VALUES (v_room_id, v_caller_id, 'WARNING_ISSUED', p_target_user_id, jsonb_build_object('level', v_next_level, 'reason', p_reason));

  -- 3rd Warning Escalation: Auto-Kick User from room_members!
  IF v_next_level >= 3 THEN
    v_auto_kicked := true;
    DELETE FROM public.room_members WHERE room_id = v_room_id AND user_id = p_target_user_id;
    
    INSERT INTO public.room_admin_activity_logs (room_id, admin_id, action_type, target_user_id, details)
    VALUES (v_room_id, v_caller_id, 'KICK', p_target_user_id, jsonb_build_object('auto_kick', true, 'reason', '3-Strike Warning Threshold Reached'));
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'warning_level', v_next_level,
    'auto_kicked', v_auto_kicked
  );
END;
$$;

-- 9. RPC: Toggle Emergency Mode (1-Click Lock)
CREATE OR REPLACE FUNCTION public.toggle_room_emergency_mode(
  p_room_id text,
  p_enabled boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_is_room_owner boolean := false;
  v_caller_role text := 'Visitor';
BEGIN
  IF v_caller_id IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;

  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN v_room_id := p_room_id; END IF;

  SELECT (host_id = v_caller_id OR room_owner = v_caller_id) INTO v_is_room_owner FROM public.rooms WHERE id = v_room_id;
  SELECT role INTO v_caller_role FROM public.room_members WHERE room_id = v_room_id AND user_id = v_caller_id;

  IF NOT v_is_room_owner AND v_caller_role NOT IN ('Co-Owner', 'Co Owner') THEN
    RAISE EXCEPTION 'Only Room Owner or Co-Owners can toggle Emergency Mode.';
  END IF;

  UPDATE public.rooms SET is_emergency_mode = p_enabled WHERE id = v_room_id;

  -- Log Activity
  INSERT INTO public.room_admin_activity_logs (room_id, admin_id, action_type, details)
  VALUES (v_room_id, v_caller_id, 'EMERGENCY_TOGGLE', jsonb_build_object('enabled', p_enabled));

  RETURN jsonb_build_object('success', true, 'is_emergency_mode', p_enabled);
END;
$$;

-- 10. RPC: Get Full Room Governance Overview (Role Counters, Security Score, Health Score, Governance Level)
CREATE OR REPLACE FUNCTION public.get_room_governance_overview(
  p_room_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_room_id text;
  v_room RECORD;
  v_owner_count int := 0;
  v_co_owner_count int := 0;
  v_admin_count int := 0;
  v_audience_count int := 0;
  v_limits RECORD;
  v_history jsonb;
  v_admin_logs jsonb;
  v_warnings jsonb;
BEGIN
  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN v_room_id := p_room_id; END IF;

  SELECT * INTO v_room FROM public.rooms WHERE id = v_room_id;
  IF v_room.id IS NULL THEN RAISE EXCEPTION 'Room not found.'; END IF;

  SELECT * FROM public.get_room_role_limits(v_room_id) INTO v_limits;

  -- Role Counts
  SELECT COUNT(*) INTO v_owner_count FROM public.room_members WHERE room_id = v_room_id AND role IN ('Owner', 'Creator');
  IF v_owner_count = 0 THEN v_owner_count := 1; END IF;

  SELECT COUNT(*) INTO v_co_owner_count FROM public.room_members WHERE room_id = v_room_id AND role IN ('Co-Owner', 'Co Owner');
  SELECT COUNT(*) INTO v_admin_count FROM public.room_members WHERE room_id = v_room_id AND role = 'Admin';
  SELECT COUNT(*) INTO v_audience_count FROM public.room_members WHERE room_id = v_room_id AND (role IS NULL OR role NOT IN ('Owner', 'Creator', 'Co-Owner', 'Co Owner', 'Admin'));

  -- History (Last 20)
  SELECT jsonb_agg(h) INTO v_history FROM (
    SELECT id, actor_id, actor_role, target_user_id, action_type, old_role, new_role, expires_at, created_at
    FROM public.room_permission_history
    WHERE room_id = v_room_id ORDER BY created_at DESC LIMIT 20
  ) h;

  -- Admin Activity Logs (Last 20)
  SELECT jsonb_agg(l) INTO v_admin_logs FROM (
    SELECT id, admin_id, action_type, target_user_id, details, created_at
    FROM public.room_admin_activity_logs
    WHERE room_id = v_room_id ORDER BY created_at DESC LIMIT 20
  ) l;

  -- User Warnings
  SELECT jsonb_agg(w) INTO v_warnings FROM (
    SELECT id, user_id, issued_by, warning_level, reason, is_active, created_at
    FROM public.room_user_warnings
    WHERE room_id = v_room_id AND is_active = true ORDER BY created_at DESC LIMIT 20
  ) w;

  RETURN jsonb_build_object(
    'room_id', v_room_id,
    'security_score', COALESCE(v_room.security_score, 5.00),
    'health_score', COALESCE(v_room.health_score, 100),
    'governance_level', COALESCE(v_room.governance_level, 1),
    'is_emergency_mode', COALESCE(v_room.is_emergency_mode, false),
    'backup_owner_id', v_room.backup_owner_id,
    'role_counters', jsonb_build_object(
      'owner', v_owner_count,
      'max_owners', 1,
      'co_owner', v_co_owner_count,
      'max_co_owners', v_limits.max_co_owners,
      'admin', v_admin_count,
      'max_admins', v_limits.max_admins,
      'audience', v_audience_count
    ),
    'permission_history', COALESCE(v_history, '[]'::jsonb),
    'admin_activity_logs', COALESCE(v_admin_logs, '[]'::jsonb),
    'active_warnings', COALESCE(v_warnings, '[]'::jsonb)
  );
END;
$$;
