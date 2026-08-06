-- ============================================================================
-- CREANIA VOICE ROOM PASSWORD SYSTEM MIGRATION
-- Migration File: 202608070003_room_password_system.sql
-- Description: Adds room_password column, password update RPC, and verification functions
-- ============================================================================

-- 1. Add room_password column to public.rooms table
ALTER TABLE public.rooms
ADD COLUMN IF NOT EXISTS room_password text DEFAULT NULL;

-- 2. Update RPC Function to update room password securely
CREATE OR REPLACE FUNCTION public.update_room_password(
  p_room_id uuid,
  p_new_password text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id uuid;
  v_host_id uuid;
  v_co_owner_ids uuid[];
  v_admin_ids uuid[];
  v_is_authorized boolean := false;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Fetch room details
  SELECT host_id, co_owner_ids, admin_ids
  INTO v_host_id, v_co_owner_ids, v_admin_ids
  FROM public.rooms
  WHERE id = p_room_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found.';
  END IF;

  -- Check authority (Owner, Co-Owner, Admin)
  IF v_caller_id = v_host_id OR
     v_caller_id = ANY(COALESCE(v_co_owner_ids, '{}')) OR
     v_caller_id = ANY(COALESCE(v_admin_ids, '{}')) THEN
    v_is_authorized := true;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Only Room Owner, Co-Owners, and Admins can configure room password.';
  END IF;

  -- Update room password & entry permission
  IF p_new_password IS NULL OR length(trim(p_new_password)) = 0 THEN
    UPDATE public.rooms
    SET room_password = NULL,
        entry_permission = 'everyone',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_room_id;
  ELSE
    UPDATE public.rooms
    SET room_password = trim(p_new_password),
        entry_permission = 'password',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_room_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'room_id', p_room_id,
    'has_password', (p_new_password IS NOT NULL AND length(trim(p_new_password)) > 0)
  );
END;
$$;

-- 3. RPC Function to verify room password
CREATE OR REPLACE FUNCTION public.verify_room_password(
  p_room_id uuid,
  p_password text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_stored_password text;
BEGIN
  SELECT room_password
  INTO v_stored_password
  FROM public.rooms
  WHERE id = p_room_id;

  IF v_stored_password IS NULL OR length(trim(v_stored_password)) = 0 THEN
    RETURN true; -- No password set
  END IF;

  RETURN (v_stored_password = trim(p_password));
END;
$$;

-- Grant execution privileges
GRANT EXECUTE ON FUNCTION public.update_room_password(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verify_room_password(uuid, text) TO authenticated, service_role;
