-- ============================================================================
-- CREANIA VOICE ROOM PASSWORD SYSTEM MIGRATION
-- Migration File: 202608070003_room_password_system.sql
-- Description: Adds room_password column, password update RPC, and verification functions
-- ============================================================================

-- 1. Add room_password & entry_permission columns to public.rooms table
ALTER TABLE public.rooms
ADD COLUMN IF NOT EXISTS room_password text DEFAULT NULL,
ADD COLUMN IF NOT EXISTS entry_permission text DEFAULT 'everyone',
ADD COLUMN IF NOT EXISTS who_can_join text DEFAULT 'Everyone';

-- 2. Update RPC Function to update room password securely
CREATE OR REPLACE FUNCTION public.update_room_password(
  p_room_id text,
  p_new_password text,
  p_user_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id uuid;
  v_room_id text;
  v_host_id uuid;
  v_co_owner_ids uuid[];
  v_admin_ids uuid[];
  v_is_authorized boolean := false;
BEGIN
  IF p_user_id IS NOT NULL AND length(trim(p_user_id)) > 0 THEN
    BEGIN
      v_caller_id := p_user_id::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_caller_id := auth.uid();
    END;
  ELSE
    v_caller_id := auth.uid();
  END IF;

  -- Resolve room ID
  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN
    v_room_id := p_room_id;
  END IF;

  -- Fetch room details
  SELECT host_id, co_owner_ids, admin_ids
  INTO v_host_id, v_co_owner_ids, v_admin_ids
  FROM public.rooms
  WHERE id = v_room_id;

  -- Check authority (Owner, Co-Owner, Admin, or fallback)
  IF v_caller_id IS NULL OR
     v_caller_id = v_host_id OR
     v_caller_id = ANY(COALESCE(v_co_owner_ids, '{}')) OR
     v_caller_id = ANY(COALESCE(v_admin_ids, '{}')) THEN
    v_is_authorized := true;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Only Room Owner, Co-Owners, and Admins can configure room password.';
  END IF;

  -- Update room password & entry permission in public.rooms and public.room_settings
  IF p_new_password IS NULL OR length(trim(p_new_password)) = 0 THEN
    UPDATE public.rooms
    SET room_password = NULL,
        entry_permission = 'everyone',
        visibility = 'everyone',
        who_can_join = 'Everyone',
        updated_at = timezone('utc'::text, now())
    WHERE id = v_room_id;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'room_settings' AND table_schema = 'public') THEN
      UPDATE public.room_settings
      SET room_password = NULL,
          password_protected = false
      WHERE room_id = v_room_id;
    END IF;
  ELSE
    UPDATE public.rooms
    SET room_password = trim(p_new_password),
        entry_permission = 'password',
        visibility = 'password_required',
        who_can_join = 'Password Required',
        updated_at = timezone('utc'::text, now())
    WHERE id = v_room_id;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'room_settings' AND table_schema = 'public') THEN
      INSERT INTO public.room_settings (room_id, room_password, password_protected)
      VALUES (v_room_id, trim(p_new_password), true)
      ON CONFLICT (room_id) DO UPDATE 
      SET room_password = EXCLUDED.room_password, password_protected = true;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'password', trim(COALESCE(p_new_password, '')),
    'has_password', (p_new_password IS NOT NULL AND length(trim(p_new_password)) > 0)
  );
END;
$$;

-- 3. RPC Function to verify room password
CREATE OR REPLACE FUNCTION public.verify_room_password(
  p_room_id text,
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
  WHERE id = p_room_id OR username = p_room_id LIMIT 1;

  IF v_stored_password IS NULL OR length(trim(v_stored_password)) = 0 THEN
    SELECT room_password INTO v_stored_password FROM public.room_settings WHERE room_id = p_room_id LIMIT 1;
  END IF;

  IF v_stored_password IS NULL OR length(trim(v_stored_password)) = 0 THEN
    RETURN true; -- No password set
  END IF;

  RETURN (trim(v_stored_password) = trim(p_password));
END;
$$;
