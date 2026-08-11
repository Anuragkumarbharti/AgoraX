-- 202608110007_settings_system_production_fix.sql
-- Creania Settings System Production Database Schema, Tables, RPCs, and Security Policies

-- 1. Extend profiles table with is_private and 2FA settings
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_private boolean DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS two_factor_enabled boolean DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS two_factor_secret text DEFAULT NULL;

-- 2. User Blocks Table (Blocked Users System)
CREATE TABLE IF NOT EXISTS public.user_blocks (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  blocker_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  blocked_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT unique_user_block UNIQUE (blocker_id, blocked_id)
);

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own blocks"
  ON public.user_blocks FOR SELECT
  USING (auth.uid() = blocker_id);

CREATE POLICY "Users can insert their own blocks"
  ON public.user_blocks FOR INSERT
  WITH CHECK (auth.uid() = blocker_id);

CREATE POLICY "Users can delete their own blocks"
  ON public.user_blocks FOR DELETE
  USING (auth.uid() = blocker_id);

-- RPC: Block User
CREATE OR REPLACE FUNCTION public.block_user(p_blocked_id uuid)
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

  IF v_blocker_id = p_blocked_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot block yourself');
  END IF;

  INSERT INTO public.user_blocks (blocker_id, blocked_id)
  VALUES (v_blocker_id, p_blocked_id)
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

  RETURN jsonb_build_object('success', true);
END;
$$;

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

-- RPC: Get Blocked Users
CREATE OR REPLACE FUNCTION public.get_blocked_users()
RETURNS TABLE (
  blocked_id uuid,
  username text,
  display_name text,
  avatar_url text,
  blocked_at timestamp with time zone
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ub.blocked_id,
    p.username,
    COALESCE(p.profession, p.username) as display_name,
    COALESCE(p.avatar_url, p.profile_photo) as avatar_url,
    ub.created_at as blocked_at
  FROM public.user_blocks ub
  JOIN public.profiles p ON ub.blocked_id = p.id
  WHERE ub.blocker_id = auth.uid()
  ORDER BY ub.created_at DESC;
END;
$$;

-- 3. User Devices / Authorized Sessions System
CREATE TABLE IF NOT EXISTS public.user_devices (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  device_id text NOT NULL,
  device_name text NOT NULL,
  platform text NOT NULL,
  ip_address text DEFAULT '127.0.0.1',
  is_current boolean DEFAULT false,
  revoked_at timestamp with time zone DEFAULT NULL,
  last_active timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT unique_user_device UNIQUE (user_id, device_id)
);

ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own devices"
  ON public.user_devices FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert/update their own devices"
  ON public.user_devices FOR ALL
  USING (auth.uid() = user_id);

-- RPC: Register Device
CREATE OR REPLACE FUNCTION public.register_user_device(
  p_device_id text,
  p_device_name text,
  p_platform text,
  p_ip text DEFAULT '127.0.0.1'
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

  -- Mark other devices as not current
  UPDATE public.user_devices
  SET is_current = false
  WHERE user_id = v_user_id;

  -- Upsert current device
  INSERT INTO public.user_devices (user_id, device_id, device_name, platform, ip_address, is_current, revoked_at, last_active)
  VALUES (v_user_id, p_device_id, p_device_name, p_platform, p_ip, true, NULL, timezone('utc'::text, now()))
  ON CONFLICT (user_id, device_id) DO UPDATE SET
    device_name = EXCLUDED.device_name,
    platform = EXCLUDED.platform,
    ip_address = EXCLUDED.ip_address,
    is_current = true,
    revoked_at = NULL,
    last_active = timezone('utc'::text, now());

  RETURN jsonb_build_object('success', true);
END;
$$;

-- RPC: Revoke Device Access
CREATE OR REPLACE FUNCTION public.revoke_user_device(p_device_id text)
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

  UPDATE public.user_devices
  SET revoked_at = timezone('utc'::text, now()), is_current = false
  WHERE user_id = v_user_id AND device_id = p_device_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- 4. Login Activity System
CREATE TABLE IF NOT EXISTS public.user_login_activity (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  device_name text NOT NULL,
  platform text NOT NULL,
  ip_address text DEFAULT '127.0.0.1',
  session_id text DEFAULT NULL,
  login_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.user_login_activity ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own login activity"
  ON public.user_login_activity FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert login activity"
  ON public.user_login_activity FOR INSERT
  WITH CHECK (auth.uid() = user_id);

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

-- 5. Support Tickets System
CREATE TABLE IF NOT EXISTS public.support_tickets (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  category text NOT NULL CHECK (category IN ('Report', 'Request', 'Account Recovery', 'Bug Report', 'General')),
  subject text NOT NULL,
  description text NOT NULL,
  status text DEFAULT 'Open' CHECK (status IN ('Open', 'In Review', 'Resolved', 'Closed')),
  admin_response text DEFAULT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own support tickets"
  ON public.support_tickets FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can submit support tickets"
  ON public.support_tickets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 6. Two-Factor Authentication (2FA) RPCs
CREATE OR REPLACE FUNCTION public.enable_2fa(p_pin text)
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

  IF length(p_pin) < 4 OR length(p_pin) > 6 THEN
    RETURN jsonb_build_object('success', false, 'error', 'PIN must be 4 to 6 digits');
  END IF;

  UPDATE public.profiles
  SET two_factor_enabled = true,
      two_factor_secret = crypt(p_pin, gen_salt('bf')),
      updated_at = timezone('utc'::text, now())
  WHERE id = v_user_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.disable_2fa(p_pin text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_stored_secret text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  SELECT two_factor_secret INTO v_stored_secret
  FROM public.profiles
  WHERE id = v_user_id;

  IF v_stored_secret IS NULL OR crypt(p_pin, v_stored_secret) != v_stored_secret THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid Security PIN');
  END IF;

  UPDATE public.profiles
  SET two_factor_enabled = false,
      two_factor_secret = NULL,
      updated_at = timezone('utc'::text, now())
  WHERE id = v_user_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.verify_2fa(p_pin text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_stored_secret text;
  v_enabled boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  SELECT two_factor_enabled, two_factor_secret 
  INTO v_enabled, v_stored_secret
  FROM public.profiles
  WHERE id = v_user_id;

  IF NOT COALESCE(v_enabled, false) THEN
    RETURN jsonb_build_object('success', true, 'required', false);
  END IF;

  IF v_stored_secret IS NOT NULL AND crypt(p_pin, v_stored_secret) = v_stored_secret THEN
    RETURN jsonb_build_object('success', true, 'required', true);
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Incorrect Security PIN');
  END IF;
END;
$$;
