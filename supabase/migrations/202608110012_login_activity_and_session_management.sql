-- 202608110012_login_activity_and_session_management.sql
-- Production Login Activity & Device Session Management System

-- 1. Create or upgrade user_sessions table
CREATE TABLE IF NOT EXISTS public.user_sessions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  session_id text NOT NULL UNIQUE,
  device_id text NOT NULL,
  device_name text NOT NULL,
  device_model text DEFAULT '',
  platform text NOT NULL,
  os_version text DEFAULT '',
  app_version text DEFAULT '',
  browser text DEFAULT '',
  ip_address text DEFAULT '127.0.0.1',
  country text DEFAULT 'India',
  city text DEFAULT '',
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  last_active_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  expires_at timestamp with time zone DEFAULT (timezone('utc'::text, now()) + interval '90 days') NOT NULL,
  revoked_at timestamp with time zone DEFAULT NULL
);

-- Ensure all required columns exist on pre-existing user_sessions table
ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS session_id text;
ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS device_id text;
ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS device_name text DEFAULT 'Unknown Device';
ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS device_model text DEFAULT '';
ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS platform text DEFAULT 'Mobile';
ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS os_version text DEFAULT '';
ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS app_version text DEFAULT '';
ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS browser text DEFAULT '';
ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS ip_address text DEFAULT '127.0.0.1';
ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS country text DEFAULT 'India';
ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS city text DEFAULT '';
ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS created_at timestamp with time zone DEFAULT timezone('utc'::text, now());
ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS last_active_at timestamp with time zone DEFAULT timezone('utc'::text, now());
ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS expires_at timestamp with time zone DEFAULT (timezone('utc'::text, now()) + interval '90 days');
ALTER TABLE public.user_sessions ADD COLUMN IF NOT EXISTS revoked_at timestamp with time zone DEFAULT NULL;

-- Ensure session_id has unique constraint if table was altered
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'user_sessions_session_id_key'
  ) THEN
    BEGIN
      ALTER TABLE public.user_sessions ADD CONSTRAINT user_sessions_session_id_key UNIQUE (session_id);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;
END $$;

-- Indexes for ultra-fast session validation & queries
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON public.user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_session_id ON public.user_sessions(session_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_device_id ON public.user_sessions(device_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_revoked_at ON public.user_sessions(revoked_at);
CREATE INDEX IF NOT EXISTS idx_user_sessions_last_active_at ON public.user_sessions(last_active_at);

-- Row Level Security (RLS)
ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own sessions" ON public.user_sessions;
CREATE POLICY "Users can view their own sessions"
  ON public.user_sessions FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own sessions" ON public.user_sessions;
CREATE POLICY "Users can update their own sessions"
  ON public.user_sessions FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own sessions" ON public.user_sessions;
CREATE POLICY "Users can insert their own sessions"
  ON public.user_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 2. Upgrade user_login_activity table for detailed security event logs
CREATE TABLE IF NOT EXISTS public.user_login_activity (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  event_type text NOT NULL DEFAULT 'Successful Login',
  device_name text NOT NULL,
  platform text NOT NULL,
  ip_address text DEFAULT '127.0.0.1',
  country text DEFAULT 'India',
  session_id text DEFAULT NULL,
  status text DEFAULT 'success',
  failure_reason text DEFAULT NULL,
  auth_method text DEFAULT 'Password',
  login_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Ensure missing columns exist if table was previously defined
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_login_activity' AND column_name='event_type') THEN
    ALTER TABLE public.user_login_activity ADD COLUMN event_type text NOT NULL DEFAULT 'Successful Login';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_login_activity' AND column_name='status') THEN
    ALTER TABLE public.user_login_activity ADD COLUMN status text DEFAULT 'success';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_login_activity' AND column_name='failure_reason') THEN
    ALTER TABLE public.user_login_activity ADD COLUMN failure_reason text DEFAULT NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_login_activity' AND column_name='auth_method') THEN
    ALTER TABLE public.user_login_activity ADD COLUMN auth_method text DEFAULT 'Password';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_login_activity' AND column_name='country') THEN
    ALTER TABLE public.user_login_activity ADD COLUMN country text DEFAULT 'India';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_user_login_activity_user_id ON public.user_login_activity(user_id);
CREATE INDEX IF NOT EXISTS idx_user_login_activity_login_at ON public.user_login_activity(login_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_login_activity_event_type ON public.user_login_activity(event_type);

ALTER TABLE public.user_login_activity ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own login activity" ON public.user_login_activity;
CREATE POLICY "Users can view their own login activity"
  ON public.user_login_activity FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert login activity" ON public.user_login_activity;
CREATE POLICY "Users can insert login activity"
  ON public.user_login_activity FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 3. RPC: Register / Update User Session
CREATE OR REPLACE FUNCTION public.register_user_session(
  p_session_id text,
  p_device_id text,
  p_device_name text,
  p_platform text,
  p_device_model text DEFAULT '',
  p_os_version text DEFAULT '',
  p_app_version text DEFAULT '',
  p_browser text DEFAULT '',
  p_ip text DEFAULT '127.0.0.1',
  p_country text DEFAULT 'India'
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

  INSERT INTO public.user_sessions (
    user_id,
    session_id,
    device_id,
    device_name,
    device_model,
    platform,
    os_version,
    app_version,
    browser,
    ip_address,
    country,
    last_active_at,
    revoked_at
  )
  VALUES (
    v_user_id,
    p_session_id,
    p_device_id,
    p_device_name,
    p_device_model,
    p_platform,
    p_os_version,
    p_app_version,
    p_browser,
    p_ip,
    p_country,
    timezone('utc'::text, now()),
    NULL
  )
  ON CONFLICT (session_id) DO UPDATE SET
    device_name = EXCLUDED.device_name,
    device_model = EXCLUDED.device_model,
    platform = EXCLUDED.platform,
    os_version = EXCLUDED.os_version,
    app_version = EXCLUDED.app_version,
    browser = EXCLUDED.browser,
    ip_address = EXCLUDED.ip_address,
    country = EXCLUDED.country,
    last_active_at = timezone('utc'::text, now()),
    revoked_at = NULL;

  -- Maintain backward compatibility with user_devices table
  INSERT INTO public.user_devices (user_id, device_id, device_name, platform, ip_address, is_current, revoked_at, last_active)
  VALUES (v_user_id, p_device_id, p_device_name, p_platform, p_ip, true, NULL, timezone('utc'::text, now()))
  ON CONFLICT (user_id, device_id) DO UPDATE SET
    device_name = EXCLUDED.device_name,
    platform = EXCLUDED.platform,
    ip_address = EXCLUDED.ip_address,
    is_current = true,
    revoked_at = NULL,
    last_active = timezone('utc'::text, now());

  RETURN jsonb_build_object('success', true, 'session_id', p_session_id);
END;
$$;

-- 4. RPC: Validate Active Session
CREATE OR REPLACE FUNCTION public.validate_user_session(p_session_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_revoked_at timestamp with time zone;
  v_session_found boolean := false;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('valid', false, 'error', 'Unauthenticated');
  END IF;

  SELECT revoked_at, true INTO v_revoked_at, v_session_found
  FROM public.user_sessions
  WHERE user_id = v_user_id AND session_id = p_session_id;

  IF NOT v_session_found THEN
    RETURN jsonb_build_object('valid', false, 'reason', 'session_not_found');
  END IF;

  IF v_revoked_at IS NOT NULL THEN
    RETURN jsonb_build_object('valid', false, 'reason', 'session_revoked', 'revoked_at', v_revoked_at);
  END IF;

  -- Touch last active timestamp
  UPDATE public.user_sessions
  SET last_active_at = timezone('utc'::text, now())
  WHERE user_id = v_user_id AND session_id = p_session_id;

  RETURN jsonb_build_object('valid', true);
END;
$$;

-- 5. RPC: Revoke Single Session (Individual Device Logout)
CREATE OR REPLACE FUNCTION public.revoke_user_session(p_session_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_device_name text;
  v_platform text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  -- Get session metadata before revoking
  SELECT device_name, platform INTO v_device_name, v_platform
  FROM public.user_sessions
  WHERE user_id = v_user_id AND session_id = p_session_id;

  IF v_device_name IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Session not found');
  END IF;

  -- Perform revocation
  UPDATE public.user_sessions
  SET revoked_at = timezone('utc'::text, now())
  WHERE user_id = v_user_id AND session_id = p_session_id;

  -- Log security event
  INSERT INTO public.user_login_activity (
    user_id,
    event_type,
    device_name,
    platform,
    session_id,
    status,
    auth_method,
    login_at
  )
  VALUES (
    v_user_id,
    'Device Logout',
    v_device_name,
    v_platform,
    p_session_id,
    'success',
    'Session Revocation',
    timezone('utc'::text, now())
  );

  RETURN jsonb_build_object('success', true, 'session_id', p_session_id);
END;
$$;

-- 6. RPC: Revoke All Other Sessions (Logout From All Other Devices)
CREATE OR REPLACE FUNCTION public.revoke_all_other_user_sessions(p_current_session_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_revoked_count integer := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  -- Revoke all active sessions except current
  WITH updated AS (
    UPDATE public.user_sessions
    SET revoked_at = timezone('utc'::text, now())
    WHERE user_id = v_user_id
      AND session_id != p_current_session_id
      AND revoked_at IS NULL
    RETURNING id
  )
  SELECT count(*) INTO v_revoked_count FROM updated;

  -- Log security event
  INSERT INTO public.user_login_activity (
    user_id,
    event_type,
    device_name,
    platform,
    session_id,
    status,
    auth_method,
    login_at
  )
  VALUES (
    v_user_id,
    'All Devices Logout',
    'Current Device',
    'Multiple',
    p_current_session_id,
    'success',
    'Bulk Revocation',
    timezone('utc'::text, now())
  );

  RETURN jsonb_build_object(
    'success', true,
    'revoked_count', v_revoked_count,
    'current_session_id', p_current_session_id
  );
END;
$$;

-- 7. RPC: Log User Login Activity Event
CREATE OR REPLACE FUNCTION public.log_user_login_event(
  p_event_type text,
  p_device_name text,
  p_platform text,
  p_ip text DEFAULT '127.0.0.1',
  p_country text DEFAULT 'India',
  p_session_id text DEFAULT NULL,
  p_status text DEFAULT 'success',
  p_failure_reason text DEFAULT NULL,
  p_auth_method text DEFAULT 'Password'
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

  INSERT INTO public.user_login_activity (
    user_id,
    event_type,
    device_name,
    platform,
    ip_address,
    country,
    session_id,
    status,
    failure_reason,
    auth_method,
    login_at
  )
  VALUES (
    v_user_id,
    p_event_type,
    p_device_name,
    p_platform,
    p_ip,
    p_country,
    p_session_id,
    p_status,
    p_failure_reason,
    p_auth_method,
    timezone('utc'::text, now())
  );

  RETURN jsonb_build_object('success', true);
END;
$$;
