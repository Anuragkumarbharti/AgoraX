-- Migration: Room Background Theme Realtime & Persistence System
-- Date: 2026-08-06

-- 1. Ensure room_theme column exists on public.rooms table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'rooms' 
    AND column_name = 'room_theme'
  ) THEN
    ALTER TABLE public.rooms ADD COLUMN room_theme text DEFAULT 'theme_1';
  END IF;
END $$;

-- 2. Add rooms table to Supabase Realtime publication for CDC updates
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.rooms;
    EXCEPTION WHEN OTHERS THEN
      -- Table already in publication or publication configured via dashboard
      NULL;
    END;
  END IF;
END $$;

-- 3. RPC function to update room background theme cleanly
CREATE OR REPLACE FUNCTION public.update_room_background_theme(
  p_room_id text,
  p_theme_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id uuid;
BEGIN
  -- Resolve Room UUID
  IF p_room_id ~* '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    v_room_id := p_room_id::uuid;
  ELSE
    SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
    IF v_room_id IS NULL THEN
      BEGIN v_room_id := p_room_id::uuid; EXCEPTION WHEN OTHERS THEN v_room_id := NULL; END;
    END IF;
  END IF;

  IF v_room_id IS NULL THEN
    RAISE EXCEPTION 'Room not found.';
  END IF;

  -- Update room_theme in database
  UPDATE public.rooms
  SET room_theme = p_theme_id
  WHERE id = v_room_id;

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'room_theme', p_theme_id
  );
END;
$$;
