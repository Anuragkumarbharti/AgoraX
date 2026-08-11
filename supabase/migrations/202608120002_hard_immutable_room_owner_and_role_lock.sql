-- ============================================================
-- 202608120002_hard_immutable_room_owner_and_role_lock.sql
-- Creania Arena Room Owner Immutability + Role System Hard Lock
-- ============================================================

-- 1. Standardize owner_user_id column on public.rooms table
ALTER TABLE public.rooms 
ADD COLUMN IF NOT EXISTS owner_user_id uuid REFERENCES public.profiles(id);

-- Backfill owner_user_id for existing rooms if null
UPDATE public.rooms 
SET owner_user_id = coalesce(room_owner, host_id)
WHERE owner_user_id IS NULL;

-- 2. Database Protection Trigger: Absolute Unconditional Owner Immutability
CREATE OR REPLACE FUNCTION public.prevent_room_owner_change()
RETURNS trigger AS $$
BEGIN
  -- If owner_user_id, host_id, or room_owner is attempted to be changed under ANY condition
  IF (old.owner_user_id IS DISTINCT FROM new.owner_user_id OR 
      old.host_id IS DISTINCT FROM new.host_id OR 
      old.room_owner IS DISTINCT FROM new.room_owner) THEN
      
    -- Log security event
    BEGIN
      INSERT INTO public.security_events (user_id, event_type, metadata)
      VALUES (
        coalesce(auth.uid(), old.owner_user_id),
        'OWNER_CHANGE_ATTEMPT',
        jsonb_build_object(
          'room_id', old.id,
          'old_owner_user_id', old.owner_user_id,
          'requested_owner_user_id', new.owner_user_id,
          'timestamp', now(),
          'reason', 'Attempted unauthorized modification of permanent room owner'
        )
      );
    EXCEPTION WHEN OTHERS THEN
      -- Silence logging errors to ensure primary exception is raised
      NULL;
    END;

    RAISE EXCEPTION 'OWNER_IMMUTABLE: Room owner_user_id is permanently locked upon creation and CAN NEVER be modified under any condition.';
  END IF;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_prevent_auto_room_ownership_change ON public.rooms;
DROP TRIGGER IF EXISTS trigger_prevent_room_owner_change ON public.rooms;

CREATE TRIGGER trigger_prevent_room_owner_change
  BEFORE UPDATE ON public.rooms
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_room_owner_change();

-- 3. Permanently Disable Ownership Transfer RPCs
CREATE OR REPLACE FUNCTION public.transfer_room_ownership(
  p_room_id text,
  p_new_owner_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  -- Log attempt in security events
  BEGIN
    INSERT INTO public.security_events (user_id, event_type, metadata)
    VALUES (
      auth.uid(),
      'OWNER_CHANGE_ATTEMPT',
      jsonb_build_object(
        'room_id', p_room_id,
        'requested_new_owner', p_new_owner_id,
        'timestamp', now(),
        'reason', 'Call to transfer_room_ownership RPC'
      )
    );
  EXCEPTION WHEN OTHERS THEN NULL; END;

  RAISE EXCEPTION 'OWNERSHIP_TRANSFER_DISABLED: Arena Room ownership transfer is permanently disabled in Creania Arena.';
END;
$$;

CREATE OR REPLACE FUNCTION public.transfer_room_host(
  p_room_id text,
  p_new_host_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RAISE EXCEPTION 'OWNERSHIP_TRANSFER_DISABLED: Arena Room ownership transfer is permanently disabled in Creania Arena.';
END;
$$;

-- 4. Update create_arena RPC to ensure owner_user_id, host_id, and room_owner are initialized identically
CREATE OR REPLACE FUNCTION public.create_arena(
  p_name             text,
  p_username         text,
  p_description      text     DEFAULT '',
  p_category         text     DEFAULT 'Education',
  p_language         text     DEFAULT 'English',
  p_tags             text[]   DEFAULT '{}',
  p_rules            text[]   DEFAULT '{}',
  p_creation_method  text     DEFAULT 'ticket',
  p_entry_permission text     DEFAULT 'everyone',
  p_avatar           text     DEFAULT NULL,
  p_banner           text     DEFAULT NULL
) RETURNS text AS $$
DECLARE
  v_user_id      uuid := auth.uid();
  v_room_id      text;
  v_livekit_name text;
  v_ticket_id    uuid;
  v_balance      integer;
  v_user_level   integer;
  v_coins_spent  integer := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Must be logged in to create an Arena.';
  END IF;

  -- ── Check Username Format & Availability ─────────────────────────────
  IF p_username !~ '^@[a-z0-9_]{3,30}$' THEN
    RAISE EXCEPTION 'INVALID_USERNAME: Username must start with @ and contain 3-30 lowercase letters, numbers, or underscores.';
  END IF;

  IF EXISTS (SELECT 1 FROM public.rooms WHERE username = p_username) THEN
    RAISE EXCEPTION 'USERNAME_TAKEN: Room handle % is already in use.', p_username;
  END IF;

  -- ── Validate Creation Method ──────────────────────────────────────────
  IF p_creation_method NOT IN ('ticket', 'coins', 'level') THEN
    RAISE EXCEPTION 'INVALID_METHOD: Creation method must be ticket, coins, or level.';
  END IF;

  -- ── Method: TICKET ──────────────────────────────────────────────────
  IF p_creation_method = 'ticket' THEN
    SELECT id INTO v_ticket_id
    FROM public.arena_tickets
    WHERE user_id = v_user_id AND is_consumed = false
    ORDER BY granted_at ASC
    LIMIT 1
    FOR UPDATE;

    IF v_ticket_id IS NULL THEN
      RAISE EXCEPTION 'NO_TICKET: You do not have an active Arena Ticket. Earn one via progression or purchase with Gold Coins.';
    END IF;

    UPDATE public.arena_tickets
    SET is_consumed = true, consumed_at = now()
    WHERE id = v_ticket_id;

    v_coins_spent := 0;

  -- ── Method: COINS ────────────────────────────────────────────────────
  ELSIF p_creation_method = 'coins' THEN
    SELECT coins_balance INTO v_balance
    FROM public.wallets
    WHERE id = v_user_id
    FOR UPDATE;

    IF coalesce(v_balance, 0) < 499 THEN
      RAISE EXCEPTION 'INSUFFICIENT_COINS: Creating an Arena costs 499 Gold Coins. Your balance: % coins.', coalesce(v_balance, 0);
    END IF;

    UPDATE public.wallets
    SET coins_balance = coins_balance - 499
    WHERE id = v_user_id;

    INSERT INTO public.wallet_transactions
      (wallet_id, amount, currency, type, status, details)
    VALUES
      (v_user_id, 499, 'Coins', 'Withdrawal', 'Completed', 'Created permanent Arena: ' || p_name);

    v_coins_spent := 499;

  -- ── Method: LEVEL ────────────────────────────────────────────────────
  ELSIF p_creation_method = 'level' THEN
    SELECT level INTO v_user_level
    FROM public.profiles
    WHERE id = v_user_id;

    IF coalesce(v_user_level, 1) < 15 THEN
      RAISE EXCEPTION 'LEVEL_REQUIRED: Arena creation via ID Level requires Level 15 or above. Your current level: %.', coalesce(v_user_level, 1);
    END IF;

    v_coins_spent := 0;
  END IF;

  -- ── Generate unique IDs ───────────────────────────────────────────────
  v_room_id      := public.generate_unique_room_id();
  v_livekit_name := 'arena_' || encode(gen_random_bytes(8), 'hex');

  -- ── Insert the permanent Arena ────────────────────────────────────────
  INSERT INTO public.rooms (
    id, name, username, description, category, language, tags, rules,
    host_id, room_owner, owner_user_id, status, visibility, recording_status, level_requirement,
    vip_requirement, verification_requirement, livekit_room_name,
    avatar, banner, is_permanent
  ) VALUES (
    v_room_id,
    p_name,
    p_username,
    p_description,
    p_category,
    p_language,
    p_tags,
    p_rules,
    v_user_id,
    v_user_id,
    v_user_id,
    'live',
    p_entry_permission,
    'inactive',
    1,
    0,
    false,
    v_livekit_name,
    p_avatar,
    p_banner,
    true
  );

  -- ── Write audit log ───────────────────────────────────────────────────
  INSERT INTO public.arena_creation_logs
    (arena_id, user_id, creation_method, ticket_id, coins_spent)
  VALUES
    (v_room_id, v_user_id, p_creation_method, v_ticket_id, v_coins_spent);

  RETURN v_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Promote Room Member Role RPC with Owner Protection & Role Hierarchy Lock
CREATE OR REPLACE FUNCTION public.promote_room_member_role(
  p_room_id text,
  p_target_user_id uuid,
  p_new_role text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_canonical_owner uuid;
  v_caller_role text := 'Audience';
  v_is_room_owner boolean := false;
  v_target_role text := p_new_role;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Resolve Room ID
  IF EXISTS (SELECT 1 FROM public.rooms WHERE id = p_room_id) THEN
    v_room_id := p_room_id;
  ELSE
    SELECT id INTO v_room_id FROM public.rooms WHERE username = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      RAISE EXCEPTION 'Room not found for ID: %', p_room_id;
    END IF;
  END IF;

  -- Fetch Canonical Permanent Room Owner
  SELECT coalesce(owner_user_id, room_owner, host_id) INTO v_canonical_owner 
  FROM public.rooms WHERE id = v_room_id;

  -- ABSOLUTE PROTECTION: Permanent Owner can NEVER be the target of role modification
  IF p_target_user_id = v_canonical_owner THEN
    RAISE EXCEPTION 'OWNER_PROTECTED: Cannot modify role of the permanent Room Owner.';
  END IF;

  -- Standardize Target Role
  IF v_target_role IN ('Co Owner', 'co-owner', 'coowner') THEN v_target_role := 'Co-Owner'; END IF;
  IF v_target_role IN ('admin', 'Moderator') THEN v_target_role := 'Admin'; END IF;
  IF v_target_role IN ('host', 'Host Member') THEN v_target_role := 'Host'; END IF;

  -- Determine Caller Authority
  IF v_caller_id = v_canonical_owner THEN
    v_is_room_owner := true;
    v_caller_role := 'Creator';
  ELSE
    SELECT role INTO v_caller_role FROM public.room_members WHERE room_id = v_room_id AND user_id = v_caller_id;
    IF v_caller_role IS NULL OR v_caller_role = '' THEN
      SELECT 
        CASE 
          WHEN v_caller_id::text = any(coalesce(co_owner_ids, '{}')) THEN 'Co-Owner'
          WHEN v_caller_id::text = any(coalesce(admin_ids, '{}')) THEN 'Admin'
          WHEN v_caller_id::text = any(coalesce(host_ids, '{}')) THEN 'Host'
          ELSE 'Audience'
        END INTO v_caller_role
      FROM public.rooms WHERE id = v_room_id;
    END IF;
  END IF;

  -- Strict Role Hierarchy Enforcement:
  -- Owner (Creator): Can assign Co-Owner, Admin, Host
  -- Co-Owner: Can assign Admin, Host (CANNOT assign Co-Owner or Owner)
  -- Admin: Can assign Host (CANNOT assign Admin, Co-Owner, or Owner)
  -- Host / Audience: Cannot manage roles
  IF v_caller_role IN ('Creator', 'Owner') THEN
    IF v_target_role NOT IN ('Co-Owner', 'Admin', 'Host', 'Star Member') THEN
      RAISE EXCEPTION 'Invalid target role: %', v_target_role;
    END IF;
  ELSIF v_caller_role IN ('Co-Owner', 'Co Owner') THEN
    IF v_target_role NOT IN ('Admin', 'Host', 'Star Member') THEN
      RAISE EXCEPTION 'Co-Owners can only assign Admin or Host roles.';
    END IF;
  ELSIF v_caller_role IN ('Admin', 'Moderator') THEN
    IF v_target_role NOT IN ('Host') THEN
      RAISE EXCEPTION 'Admins can only assign Host role.';
    END IF;
  ELSE
    RAISE EXCEPTION 'Insufficient permissions to assign room roles.';
  END IF;

  -- 1. Insert or Update in room_assigned_roles
  INSERT INTO public.room_assigned_roles (room_id, user_id, role, assigned_by, assigned_at)
  VALUES (v_room_id, p_target_user_id, v_target_role, v_caller_id, now())
  ON CONFLICT (room_id, user_id) DO UPDATE 
  SET role = v_target_role, assigned_by = v_caller_id, assigned_at = now();

  -- 2. Update role arrays on public.rooms (WITHOUT EVER TOUCHING owner_user_id / host_id / room_owner)
  IF v_target_role = 'Co-Owner' THEN
    UPDATE public.rooms 
    SET co_owner_ids = array_distinct(array_append(co_owner_ids, p_target_user_id::text)),
        admin_ids = array_remove(admin_ids, p_target_user_id::text),
        host_ids = array_remove(host_ids, p_target_user_id::text)
    WHERE id = v_room_id;
  ELSIF v_target_role = 'Admin' THEN
    UPDATE public.rooms 
    SET admin_ids = array_distinct(array_append(admin_ids, p_target_user_id::text)),
        co_owner_ids = array_remove(co_owner_ids, p_target_user_id::text),
        host_ids = array_remove(host_ids, p_target_user_id::text)
    WHERE id = v_room_id;
  ELSIF v_target_role = 'Host' THEN
    UPDATE public.rooms 
    SET host_ids = array_distinct(array_append(host_ids, p_target_user_id::text)),
        co_owner_ids = array_remove(co_owner_ids, p_target_user_id::text),
        admin_ids = array_remove(admin_ids, p_target_user_id::text)
    WHERE id = v_room_id;
  END IF;

  -- 3. Update room_members table
  INSERT INTO public.room_members (room_id, user_id, role, assigned_by, assigned_at, updated_at)
  VALUES (v_room_id, p_target_user_id, v_target_role, v_caller_id, now(), now())
  ON CONFLICT (room_id, user_id) DO UPDATE 
  SET role = v_target_role, assigned_by = v_caller_id, assigned_at = now(), updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'new_role', v_target_role
  );
END;
$$;

-- 6. Demote Room Member Role RPC with Owner Protection & Role Hierarchy Lock
CREATE OR REPLACE FUNCTION public.demote_room_member_role(
  p_room_id text,
  p_target_user_id uuid,
  p_role_to_remove text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_canonical_owner uuid;
  v_caller_role text := 'Audience';
  v_is_room_owner boolean := false;
  v_target_role text := p_role_to_remove;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  IF EXISTS (SELECT 1 FROM public.rooms WHERE id = p_room_id) THEN
    v_room_id := p_room_id;
  ELSE
    SELECT id INTO v_room_id FROM public.rooms WHERE username = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      RAISE EXCEPTION 'Room not found for ID: %', p_room_id;
    END IF;
  END IF;

  -- Fetch Canonical Permanent Room Owner
  SELECT coalesce(owner_user_id, room_owner, host_id) INTO v_canonical_owner 
  FROM public.rooms WHERE id = v_room_id;

  -- ABSOLUTE PROTECTION: Permanent Owner can NEVER be demoted or removed
  IF p_target_user_id = v_canonical_owner THEN
    RAISE EXCEPTION 'OWNER_PROTECTED: Permanent Room Owner role cannot be demoted or removed.';
  END IF;

  -- Determine Caller Authority
  IF v_caller_id = v_canonical_owner THEN
    v_is_room_owner := true;
    v_caller_role := 'Creator';
  ELSE
    SELECT 
      CASE 
        WHEN v_caller_id::text = any(coalesce(co_owner_ids, '{}')) THEN 'Co-Owner'
        WHEN v_caller_id::text = any(coalesce(admin_ids, '{}')) THEN 'Admin'
        ELSE 'Audience'
      END INTO v_caller_role
    FROM public.rooms WHERE id = v_room_id;
  END IF;

  IF v_target_role IS NULL OR v_target_role = '' THEN
    SELECT role INTO v_target_role FROM public.room_assigned_roles WHERE room_id = v_room_id AND user_id = p_target_user_id;
  END IF;

  IF v_target_role IN ('Co Owner', 'co-owner', 'coowner') THEN v_target_role := 'Co-Owner'; END IF;
  IF v_target_role IN ('admin', 'Moderator') THEN v_target_role := 'Admin'; END IF;
  IF v_target_role IN ('host', 'Host Member') THEN v_target_role := 'Host'; END IF;

  -- Strict Role Hierarchy Enforcement:
  -- Owner: Can remove Co-Owner, Admin, Host
  -- Co-Owner: Can remove Admin, Host (CANNOT remove Co-Owner or Owner)
  -- Admin: Can remove Host (CANNOT remove Admin or Co-Owner)
  IF v_caller_role IN ('Creator', 'Owner') THEN
    NULL;
  ELSIF v_caller_role IN ('Co-Owner', 'Co Owner') THEN
    IF v_target_role IN ('Creator', 'Owner', 'Co-Owner', 'Co Owner') THEN
      RAISE EXCEPTION 'Co-Owners cannot remove Co-Owner or Owner roles.';
    END IF;
  ELSIF v_caller_role IN ('Admin', 'Moderator') THEN
    IF v_target_role IN ('Creator', 'Owner', 'Co-Owner', 'Co Owner', 'Admin', 'Moderator') THEN
      RAISE EXCEPTION 'Admins can only remove Host role.';
    END IF;
  ELSE
    RAISE EXCEPTION 'Insufficient permissions to remove room roles.';
  END IF;

  -- 1. Remove from room_assigned_roles
  DELETE FROM public.room_assigned_roles WHERE room_id = v_room_id AND user_id = p_target_user_id;

  -- 2. Remove from co_owner_ids, admin_ids, host_ids arrays on rooms table
  IF v_target_role = 'Co-Owner' THEN
    UPDATE public.rooms SET co_owner_ids = array_remove(co_owner_ids, p_target_user_id::text) WHERE id = v_room_id;
  ELSIF v_target_role = 'Admin' THEN
    UPDATE public.rooms SET admin_ids = array_remove(admin_ids, p_target_user_id::text) WHERE id = v_room_id;
  ELSIF v_target_role = 'Host' THEN
    UPDATE public.rooms SET host_ids = array_remove(host_ids, p_target_user_id::text) WHERE id = v_room_id;
  ELSE
    UPDATE public.rooms 
    SET co_owner_ids = array_remove(co_owner_ids, p_target_user_id::text),
        admin_ids = array_remove(admin_ids, p_target_user_id::text),
        host_ids = array_remove(host_ids, p_target_user_id::text)
    WHERE id = v_room_id;
  END IF;

  -- 3. Update room_members role to Audience
  UPDATE public.room_members 
  SET role = 'Audience', assigned_by = v_caller_id, updated_at = now()
  WHERE room_id = v_room_id AND user_id = p_target_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'removed_role', coalesce(v_target_role, 'All')
  );
END;
$$;

-- 7. Update promote_room_member_role_v2 RPC with Owner Protection
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
  v_canonical_owner uuid;
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

  -- Fetch Canonical Permanent Room Owner
  SELECT coalesce(owner_user_id, room_owner, host_id) INTO v_canonical_owner 
  FROM public.rooms WHERE id = v_room_id;

  -- ABSOLUTE PROTECTION: Permanent Owner can NEVER be modified or target of role change
  IF p_target_user_id = v_canonical_owner THEN
    RAISE EXCEPTION 'OWNER_PROTECTED: Permanent Room Owner role cannot be modified or replaced.';
  END IF;

  -- Verify caller
  IF v_caller_id = v_canonical_owner THEN v_is_room_owner := true; END IF;
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

  -- Delegate to promote_room_member_role
  RETURN public.promote_room_member_role(v_room_id, p_target_user_id, p_new_role);
END;
$$;

-- 8. Moderate Kick User RPC with Owner Protection
CREATE OR REPLACE FUNCTION public.moderate_kick_user(
  p_room_id text,
  p_target_user_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_canonical_owner uuid;
  v_caller_role text := 'Audience';
  v_is_room_owner boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  IF EXISTS (SELECT 1 FROM public.rooms WHERE id = p_room_id) THEN
    v_room_id := p_room_id;
  ELSE
    SELECT id INTO v_room_id FROM public.rooms WHERE username = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      RAISE EXCEPTION 'Room not found for ID: %', p_room_id;
    END IF;
  END IF;

  -- Fetch Canonical Owner
  SELECT coalesce(owner_user_id, room_owner, host_id) INTO v_canonical_owner FROM public.rooms WHERE id = v_room_id;

  -- ABSOLUTE PROTECTION: Permanent Owner CANNOT be kicked
  IF p_target_user_id = v_canonical_owner THEN
    RAISE EXCEPTION 'OWNER_PROTECTED: Permanent Room Owner cannot be kicked.';
  END IF;

  -- Determine Caller Authority
  IF v_caller_id = v_canonical_owner THEN
    v_is_room_owner := true;
    v_caller_role := 'Creator';
  ELSE
    SELECT 
      CASE 
        WHEN v_caller_id::text = any(coalesce(co_owner_ids, '{}')) THEN 'Co-Owner'
        WHEN v_caller_id::text = any(coalesce(admin_ids, '{}')) THEN 'Admin'
        WHEN v_caller_id::text = any(coalesce(host_ids, '{}')) THEN 'Host'
        ELSE 'Audience'
      END INTO v_caller_role
    FROM public.rooms WHERE id = v_room_id;
  END IF;

  IF v_caller_role NOT IN ('Creator', 'Owner', 'Co-Owner', 'Co Owner', 'Admin', 'Moderator', 'Host') THEN
    RAISE EXCEPTION 'Insufficient permissions to kick members.';
  END IF;

  -- Remove from room_members
  DELETE FROM public.room_members WHERE room_id = v_room_id AND user_id = p_target_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'action', 'KICKED'
  );
END;
$$;

-- 9. Moderate Ban User RPC with Owner Protection
CREATE OR REPLACE FUNCTION public.moderate_ban_user(
  p_room_id text,
  p_target_user_id uuid,
  p_reason text DEFAULT NULL,
  p_duration text DEFAULT '24_hours'
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_canonical_owner uuid;
  v_caller_role text := 'Audience';
  v_is_room_owner boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  IF EXISTS (SELECT 1 FROM public.rooms WHERE id = p_room_id) THEN
    v_room_id := p_room_id;
  ELSE
    SELECT id INTO v_room_id FROM public.rooms WHERE username = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      RAISE EXCEPTION 'Room not found for ID: %', p_room_id;
    END IF;
  END IF;

  -- Fetch Canonical Owner
  SELECT coalesce(owner_user_id, room_owner, host_id) INTO v_canonical_owner FROM public.rooms WHERE id = v_room_id;

  -- ABSOLUTE PROTECTION: Permanent Owner CANNOT be banned
  IF p_target_user_id = v_canonical_owner THEN
    RAISE EXCEPTION 'OWNER_PROTECTED: Permanent Room Owner cannot be banned.';
  END IF;

  -- Determine Caller Authority
  IF v_caller_id = v_canonical_owner THEN
    v_is_room_owner := true;
    v_caller_role := 'Creator';
  ELSE
    SELECT 
      CASE 
        WHEN v_caller_id::text = any(coalesce(co_owner_ids, '{}')) THEN 'Co-Owner'
        WHEN v_caller_id::text = any(coalesce(admin_ids, '{}')) THEN 'Admin'
        WHEN v_caller_id::text = any(coalesce(host_ids, '{}')) THEN 'Host'
        ELSE 'Audience'
      END INTO v_caller_role
    FROM public.rooms WHERE id = v_room_id;
  END IF;

  IF v_caller_role NOT IN ('Creator', 'Owner', 'Co-Owner', 'Co Owner', 'Admin', 'Moderator', 'Host') THEN
    RAISE EXCEPTION 'Insufficient permissions to ban members.';
  END IF;

  -- Add to block_list array on public.rooms
  UPDATE public.rooms 
  SET block_list = array_distinct(array_append(block_list, p_target_user_id::text))
  WHERE id = v_room_id;

  -- Remove from room_members
  DELETE FROM public.room_members WHERE room_id = v_room_id AND user_id = p_target_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'action', 'BANNED'
  );
END;
$$;
