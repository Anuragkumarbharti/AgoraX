-- ============================================================================
-- MIGRATION: 202608120010_permanent_immutable_room_owner.sql
-- DESCRIPTION: Permanent & Immutable Room Ownership Security Engine.
--              - Room ownership is permanently locked to the original creator.
--              - NO automatic or manual ownership transfer can ever occur.
--              - BEFORE UPDATE trigger strictly rejects changing owner_user_id / host_id / room_owner.
--              - Rewrite process_presence_grace_period_and_cleanup() to NEVER reassign ownership on disconnect.
--              - Permanently disable transfer_room_ownership and transfer_room_host RPCs.
--              - Promote RPCs strictly block promoting any user to Owner role.
-- ============================================================================

-- 1. Database Trigger: Strictly Block any change to room ownership columns
CREATE OR REPLACE FUNCTION public.prevent_room_owner_change()
RETURNS TRIGGER AS $$
BEGIN
  IF (OLD.owner_user_id IS NOT NULL AND NEW.owner_user_id IS DISTINCT FROM OLD.owner_user_id) OR
     (OLD.host_id IS NOT NULL AND NEW.host_id IS DISTINCT FROM OLD.host_id) OR
     (OLD.room_owner IS NOT NULL AND NEW.room_owner IS DISTINCT FROM OLD.room_owner) THEN
    -- Audit security event
    BEGIN
      INSERT INTO public.security_events (user_id, event_type, metadata)
      VALUES (
        auth.uid(),
        'OWNER_CHANGE_ATTEMPT',
        jsonb_build_object(
          'room_id', OLD.id,
          'old_owner', OLD.owner_user_id,
          'attempted_owner', NEW.owner_user_id,
          'timestamp', now(),
          'reason', 'Attempted modification of immutable room ownership'
        )
      );
    EXCEPTION WHEN OTHERS THEN NULL; END;

    RAISE EXCEPTION 'OWNER_IMMUTABLE: Room owner_user_id and host_id are permanently locked upon creation and CAN NEVER be modified under any condition.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_prevent_room_owner_change ON public.rooms;
CREATE TRIGGER trigger_prevent_room_owner_change
  BEFORE UPDATE ON public.rooms
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_room_owner_change();

-- 2. Permanently Disable Ownership Transfer RPCs
CREATE OR REPLACE FUNCTION public.transfer_room_ownership(
  p_room_id text,
  p_new_owner_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RAISE EXCEPTION 'OWNERSHIP_TRANSFER_DISABLED: Room ownership transfer is permanently disabled in Creania Arena.';
END;
$$;

CREATE OR REPLACE FUNCTION public.transfer_room_host(
  p_room_id text,
  p_new_host_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RAISE EXCEPTION 'OWNERSHIP_TRANSFER_DISABLED: Room ownership transfer is permanently disabled in Creania Arena.';
END;
$$;

-- 3. Rewrite Presence Grace Period Cleanup: NO Ownership Transfer on Disconnect/Leave
CREATE OR REPLACE FUNCTION public.process_presence_grace_period_and_cleanup()
RETURNS void AS $$
DECLARE
  v_rec record;
  v_username text;
  v_has_members boolean;
BEGIN
  -- Phase 1: Transition users who missed 10s heartbeat into Grace Period (is_reconnecting = true)
  UPDATE public.room_members
  SET is_reconnecting = TRUE
  WHERE last_heartbeat_at < (now() - interval '10 seconds')
    AND is_reconnecting = FALSE;

  -- Update corresponding seats during grace period
  UPDATE public.room_seats s
  SET is_speaking = FALSE,
      mic_status = 'muted',
      is_reconnecting = TRUE
  FROM public.room_members m
  WHERE s.room_id = m.room_id 
    AND s.user_id = m.user_id 
    AND m.is_reconnecting = TRUE
    AND s.is_reconnecting = FALSE;

  -- Phase 2: Permanently remove users whose 30-second grace period has expired
  FOR v_rec IN 
    SELECT room_id, user_id, role, session_id 
    FROM public.room_members 
    WHERE is_reconnecting = TRUE 
      AND last_heartbeat_at < (now() - interval '30 seconds')
  LOOP
    SELECT username INTO v_username FROM public.profiles WHERE id = v_rec.user_id;

    -- A. Free seat
    UPDATE public.room_seats
    SET user_id = NULL,
        mic_status = 'muted',
        is_speaking = FALSE,
        is_reconnecting = FALSE,
        session_id = NULL
    WHERE room_id = v_rec.room_id AND user_id = v_rec.user_id;

    -- B. Delete requests
    DELETE FROM public.room_requests
    WHERE room_id = v_rec.room_id AND user_id = v_rec.user_id;

    -- C. Delete from room_members
    DELETE FROM public.room_members 
    WHERE room_id = v_rec.room_id AND user_id = v_rec.user_id;

    -- D. Delete heartbeats
    DELETE FROM public.room_member_heartbeats
    WHERE room_id = v_rec.room_id AND user_id = v_rec.user_id;

    -- E. Broadcast leave event
    INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
    VALUES (v_rec.room_id, 'leave', v_rec.user_id, v_username, COALESCE(v_username, 'Someone') || ' left the room (grace period expired)');

    -- F. Empty Room Cleanup Check (NO ownership transfer!)
    SELECT EXISTS(SELECT 1 FROM public.room_members WHERE room_id = v_rec.room_id) INTO v_has_members;
    IF NOT v_has_members THEN
      -- If room is non-permanent and empty, close room.
      IF NOT EXISTS (SELECT 1 FROM public.rooms WHERE id = v_rec.room_id AND is_permanent = TRUE) THEN
        DELETE FROM public.rooms WHERE id = v_rec.room_id;
      END IF;
    END IF;
  END LOOP;

  -- Phase 3: Clean up any orphaned seats
  UPDATE public.room_seats s
  SET user_id = NULL,
      mic_status = 'muted',
      is_speaking = FALSE,
      is_reconnecting = FALSE,
      session_id = NULL
  WHERE s.user_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.room_members m
      WHERE m.room_id = s.room_id AND m.user_id = s.user_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. Secure promote_room_member_role to strictly prevent promotion to Owner
CREATE OR REPLACE FUNCTION public.promote_room_member_role(
  p_room_id text,
  p_target_user_id uuid,
  p_new_role text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_canonical_owner uuid;
  v_standard_role text;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN
    v_room_id := p_room_id;
  END IF;

  SELECT COALESCE(owner_user_id, room_owner, host_id) INTO v_canonical_owner 
  FROM public.rooms WHERE id = v_room_id;

  -- STRICT PROTECTION: Permanent Owner role CANNOT be modified or assigned
  IF p_target_user_id = v_canonical_owner THEN
    RAISE EXCEPTION 'OWNER_PROTECTED: Permanent Room Owner role cannot be modified.';
  END IF;

  IF p_new_role IN ('Owner', 'owner', 'Creator', 'creator', 'Founder', 'founder') THEN
    RAISE EXCEPTION 'OWNER_IMMUTABLE: Room ownership is permanent and cannot be assigned to another user.';
  END IF;

  -- Standardize Target Role to strict assigned roles: Co-Owner, Admin, Mod
  IF p_new_role IN ('Co-Owner', 'Co Owner', 'coowner', 'co-owner') THEN
    v_standard_role := 'Co-Owner';
  ELSIF p_new_role IN ('Admin', 'admin') THEN
    v_standard_role := 'Admin';
  ELSIF p_new_role IN ('Mod', 'mod', 'Moderator', 'moderator', 'Host', 'host') THEN
    v_standard_role := 'Mod';
  ELSE
    RAISE EXCEPTION 'Invalid room role: %. Allowed roles are: Co-Owner, Admin, Mod.', p_new_role;
  END IF;

  -- Update role on room_members
  UPDATE public.room_members
  SET role = v_standard_role,
      updated_at = now()
  WHERE room_id = v_room_id AND user_id = p_target_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'target_user_id', p_target_user_id,
    'role', v_standard_role
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.promote_room_member_role_v2(
  p_room_id text,
  p_target_user_id uuid,
  p_new_role text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN public.promote_room_member_role(p_room_id, p_target_user_id, p_new_role);
END;
$$;
