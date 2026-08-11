-- Migration: 202608110009_production_2fa_system.sql
-- Description: Production-grade Two-Factor Authentication (2FA) Schema & RPCs

-- 1. Create user_security_settings table
CREATE TABLE IF NOT EXISTS public.user_security_settings (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  two_factor_enabled boolean NOT NULL DEFAULT false,
  two_factor_method text NOT NULL DEFAULT 'totp',
  totp_secret_encrypted text,
  last_verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.user_security_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own security settings"
  ON public.user_security_settings FOR SELECT
  USING (auth.uid() = user_id);

-- 2. Create recovery_codes table
CREATE TABLE IF NOT EXISTS public.recovery_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  code_hash text NOT NULL,
  used boolean NOT NULL DEFAULT false,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_recovery_codes_user ON public.recovery_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_recovery_codes_hash ON public.recovery_codes(code_hash);

ALTER TABLE public.recovery_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own recovery codes count"
  ON public.recovery_codes FOR SELECT
  USING (auth.uid() = user_id);

-- 3. Create trusted_devices table
CREATE TABLE IF NOT EXISTS public.trusted_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id text NOT NULL,
  device_name text NOT NULL,
  token_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  last_used_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_trusted_devices_user ON public.trusted_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_trusted_devices_token ON public.trusted_devices(token_hash);

ALTER TABLE public.trusted_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own trusted devices"
  ON public.trusted_devices FOR SELECT
  USING (auth.uid() = user_id);

-- 4. Create two_factor_attempts table for rate limiting
CREATE TABLE IF NOT EXISTS public.two_factor_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action text NOT NULL,
  success boolean NOT NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  ip_hash text,
  device_id text
);

CREATE INDEX IF NOT EXISTS idx_2fa_attempts_user_time ON public.two_factor_attempts(user_id, created_at DESC);

ALTER TABLE public.two_factor_attempts ENABLE ROW LEVEL SECURITY;

-- 5. Create security_events table for audit logging
CREATE TABLE IF NOT EXISTS public.security_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_security_events_user ON public.security_events(user_id, created_at DESC);

ALTER TABLE public.security_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own security events"
  ON public.security_events FOR SELECT
  USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- RPC 1: Get 2FA Status
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_2fa_status(p_user_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := COALESCE(p_user_id, auth.uid());
  v_rec record;
  v_profile_2fa boolean := false;
  v_recovery_count int := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  SELECT * INTO v_rec FROM public.user_security_settings WHERE user_id = v_uid;
  SELECT two_factor_enabled INTO v_profile_2fa FROM public.profiles WHERE id = v_uid;
  SELECT count(*) INTO v_recovery_count FROM public.recovery_codes WHERE user_id = v_uid AND used = false;

  RETURN jsonb_build_object(
    'success', true,
    'two_factor_enabled', COALESCE(v_rec.two_factor_enabled, v_profile_2fa, false),
    'two_factor_method', COALESCE(v_rec.two_factor_method, 'totp'),
    'has_totp_secret', (v_rec.totp_secret_encrypted IS NOT NULL AND length(v_rec.totp_secret_encrypted) > 0),
    'recovery_codes_remaining', v_recovery_count,
    'last_verified_at', v_rec.last_verified_at
  );
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 2: Generate TOTP Setup Secret
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_totp_setup_secret(p_user_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := COALESCE(p_user_id, auth.uid());
  v_chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  v_secret text := '';
  v_i int;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  -- Generate 16-character random Base32 string
  FOR v_i IN 1..16 LOOP
    v_secret := v_secret || substr(v_chars, floor(random() * 32 + 1)::int, 1);
  END LOOP;

  -- Ensure user_security_settings row exists
  INSERT INTO public.user_security_settings (user_id, two_factor_enabled, totp_secret_encrypted, updated_at)
  VALUES (v_uid, false, v_secret, timezone('utc'::text, now()))
  ON CONFLICT (user_id) DO UPDATE
  SET totp_secret_encrypted = EXCLUDED.totp_secret_encrypted,
      updated_at = timezone('utc'::text, now());

  RETURN jsonb_build_object(
    'success', true,
    'secret', v_secret
  );
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 3: Verify and Enable 2FA
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.verify_and_enable_2fa(
  p_totp_secret text,
  p_recovery_code_hashes text[],
  p_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := COALESCE(p_user_id, auth.uid());
  v_hash text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  IF p_totp_secret IS NULL OR length(p_totp_secret) < 16 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid TOTP secret key');
  END IF;

  -- Enable 2FA in user_security_settings
  INSERT INTO public.user_security_settings (user_id, two_factor_enabled, two_factor_method, totp_secret_encrypted, last_verified_at, updated_at)
  VALUES (v_uid, true, 'totp', p_totp_secret, timezone('utc'::text, now()), timezone('utc'::text, now()))
  ON CONFLICT (user_id) DO UPDATE
  SET two_factor_enabled = true,
      two_factor_method = 'totp',
      totp_secret_encrypted = EXCLUDED.totp_secret_encrypted,
      last_verified_at = timezone('utc'::text, now()),
      updated_at = timezone('utc'::text, now());

  -- Update profiles table
  UPDATE public.profiles
  SET two_factor_enabled = true,
      updated_at = timezone('utc'::text, now())
  WHERE id = v_uid;

  -- Insert recovery code hashes
  DELETE FROM public.recovery_codes WHERE user_id = v_uid;
  IF p_recovery_code_hashes IS NOT NULL THEN
    FOREACH v_hash IN ARRAY p_recovery_code_hashes LOOP
      INSERT INTO public.recovery_codes (user_id, code_hash, used)
      VALUES (v_uid, v_hash, false);
    END LOOP;
  END IF;

  -- Log security event
  INSERT INTO public.security_events (user_id, event_type, metadata)
  VALUES (v_uid, '2FA_ENABLED', jsonb_build_object('method', 'totp', 'recovery_codes_count', array_length(p_recovery_code_hashes, 1)));

  RETURN jsonb_build_object('success', true);
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 4: Check Rate Limit for 2FA Attempts
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_2fa_rate_limit(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_failed_count int;
  v_lockout_until timestamptz;
BEGIN
  -- Count failed attempts in the last 15 minutes
  SELECT count(*) INTO v_failed_count
  FROM public.two_factor_attempts
  WHERE user_id = p_user_id
    AND success = false
    AND created_at > (timezone('utc'::text, now()) - interval '15 minutes');

  IF v_failed_count >= 5 THEN
    -- Get time of 5th recent failure
    SELECT (created_at + interval '15 minutes') INTO v_lockout_until
    FROM public.two_factor_attempts
    WHERE user_id = p_user_id AND success = false
    ORDER BY created_at DESC
    LIMIT 1 OFFSET 4;

    RETURN jsonb_build_object(
      'allowed', false,
      'error', 'Too many failed verification attempts. Please wait before trying again.',
      'lockout_until', v_lockout_until,
      'failed_count', v_failed_count
    );
  END IF;

  RETURN jsonb_build_object('allowed', true, 'failed_count', v_failed_count);
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 5: Record 2FA Attempt
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_2fa_attempt(
  p_user_id uuid,
  p_action text,
  p_success boolean,
  p_device_id text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.two_factor_attempts (user_id, action, success, device_id)
  VALUES (p_user_id, p_action, p_success, p_device_id);
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 6: Verify Recovery Code Login
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.verify_recovery_code_login(
  p_user_id uuid,
  p_code_hash text,
  p_device_id text DEFAULT NULL,
  p_device_name text DEFAULT NULL,
  p_trust_device boolean DEFAULT false,
  p_device_token_hash text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_code_row record;
  v_rate_check jsonb;
  v_remaining_count int;
  v_expires_at timestamptz;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User ID is required');
  END IF;

  -- Check rate limiting
  v_rate_check := public.check_2fa_rate_limit(p_user_id);
  IF (v_rate_check->>'allowed')::boolean = false THEN
    RETURN v_rate_check;
  END IF;

  -- Find matching unused recovery code hash
  SELECT * INTO v_code_row
  FROM public.recovery_codes
  WHERE user_id = p_user_id
    AND code_hash = p_code_hash
    AND used = false;

  IF v_code_row.id IS NULL THEN
    PERFORM public.record_2fa_attempt(p_user_id, 'recovery_code_verify', false, p_device_id);
    INSERT INTO public.security_events (user_id, event_type, metadata)
    VALUES (p_user_id, '2FA_LOGIN_FAILED', jsonb_build_object('reason', 'invalid_recovery_code', 'device_id', p_device_id));

    RETURN jsonb_build_object('success', false, 'error', 'Invalid verification code. Please try again.');
  END IF;

  -- Mark recovery code as used
  UPDATE public.recovery_codes
  SET used = true,
      used_at = timezone('utc'::text, now())
  WHERE id = v_code_row.id;

  -- Count remaining
  SELECT count(*) INTO v_remaining_count
  FROM public.recovery_codes
  WHERE user_id = p_user_id AND used = false;

  -- Record attempt success & update last verified
  PERFORM public.record_2fa_attempt(p_user_id, 'recovery_code_verify', true, p_device_id);

  UPDATE public.user_security_settings
  SET last_verified_at = timezone('utc'::text, now()),
      updated_at = timezone('utc'::text, now())
  WHERE user_id = p_user_id;

  -- Handle Trust Device if requested
  IF p_trust_device = true AND p_device_token_hash IS NOT NULL AND length(p_device_token_hash) > 0 THEN
    v_expires_at := timezone('utc'::text, now()) + interval '30 days';

    INSERT INTO public.trusted_devices (user_id, device_id, device_name, token_hash, expires_at)
    VALUES (p_user_id, COALESCE(p_device_id, 'unknown_device'), COALESCE(p_device_name, 'Trusted Device'), p_device_token_hash, v_expires_at);

    INSERT INTO public.security_events (user_id, event_type, metadata)
    VALUES (p_user_id, 'TRUSTED_DEVICE_CREATED', jsonb_build_object('device_name', p_device_name, 'expires_at', v_expires_at));
  END IF;

  INSERT INTO public.security_events (user_id, event_type, metadata)
  VALUES (p_user_id, 'RECOVERY_CODE_USED', jsonb_build_object('remaining_codes', v_remaining_count, 'device_id', p_device_id));

  RETURN jsonb_build_object(
    'success', true,
    'recovery_code_used', true,
    'remaining_codes', v_remaining_count
  );
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 7: Record Successful TOTP Verification
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_successful_totp_login(
  p_user_id uuid,
  p_device_id text DEFAULT NULL,
  p_device_name text DEFAULT NULL,
  p_trust_device boolean DEFAULT false,
  p_device_token_hash text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_expires_at timestamptz;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User ID is required');
  END IF;

  PERFORM public.record_2fa_attempt(p_user_id, 'totp_verify', true, p_device_id);

  UPDATE public.user_security_settings
  SET last_verified_at = timezone('utc'::text, now()),
      updated_at = timezone('utc'::text, now())
  WHERE user_id = p_user_id;

  IF p_trust_device = true AND p_device_token_hash IS NOT NULL AND length(p_device_token_hash) > 0 THEN
    v_expires_at := timezone('utc'::text, now()) + interval '30 days';

    INSERT INTO public.trusted_devices (user_id, device_id, device_name, token_hash, expires_at)
    VALUES (p_user_id, COALESCE(p_device_id, 'unknown_device'), COALESCE(p_device_name, 'Trusted Device'), p_device_token_hash, v_expires_at);

    INSERT INTO public.security_events (user_id, event_type, metadata)
    VALUES (p_user_id, 'TRUSTED_DEVICE_CREATED', jsonb_build_object('device_name', p_device_name, 'expires_at', v_expires_at));
  END IF;

  INSERT INTO public.security_events (user_id, event_type, metadata)
  VALUES (p_user_id, '2FA_LOGIN_SUCCESS', jsonb_build_object('method', 'totp', 'device_id', p_device_id));

  RETURN jsonb_build_object('success', true);
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 8: Check Device Trust Status
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_device_trust(
  p_user_id uuid,
  p_token_hash text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_row record;
BEGIN
  IF p_user_id IS NULL OR p_token_hash IS NULL THEN
    RETURN jsonb_build_object('trusted', false);
  END IF;

  SELECT * INTO v_row
  FROM public.trusted_devices
  WHERE user_id = p_user_id
    AND token_hash = p_token_hash
    AND revoked_at IS NULL
    AND expires_at > timezone('utc'::text, now())
  LIMIT 1;

  IF v_row.id IS NOT NULL THEN
    UPDATE public.trusted_devices
    SET last_used_at = timezone('utc'::text, now())
    WHERE id = v_row.id;

    RETURN jsonb_build_object(
      'trusted', true,
      'device_name', v_row.device_name,
      'expires_at', v_row.expires_at
    );
  END IF;

  RETURN jsonb_build_object('trusted', false);
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 9: Disable 2FA
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.disable_2fa_rpc(p_user_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := COALESCE(p_user_id, auth.uid());
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  UPDATE public.user_security_settings
  SET two_factor_enabled = false,
      totp_secret_encrypted = NULL,
      updated_at = timezone('utc'::text, now())
  WHERE user_id = v_uid;

  UPDATE public.profiles
  SET two_factor_enabled = false,
      two_factor_secret = NULL,
      updated_at = timezone('utc'::text, now())
  WHERE id = v_uid;

  -- Invalidate recovery codes & revoke trusted devices
  DELETE FROM public.recovery_codes WHERE user_id = v_uid;
  
  UPDATE public.trusted_devices
  SET revoked_at = timezone('utc'::text, now())
  WHERE user_id = v_uid AND revoked_at IS NULL;

  INSERT INTO public.security_events (user_id, event_type)
  VALUES (v_uid, '2FA_DISABLED');

  RETURN jsonb_build_object('success', true);
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 10: Regenerate Recovery Codes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.regenerate_recovery_codes_rpc(
  p_new_hashes text[],
  p_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := COALESCE(p_user_id, auth.uid());
  v_hash text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  -- Delete all existing recovery codes
  DELETE FROM public.recovery_codes WHERE user_id = v_uid;

  -- Insert new code hashes
  IF p_new_hashes IS NOT NULL THEN
    FOREACH v_hash IN ARRAY p_new_hashes LOOP
      INSERT INTO public.recovery_codes (user_id, code_hash, used)
      VALUES (v_uid, v_hash, false);
    END LOOP;
  END IF;

  INSERT INTO public.security_events (user_id, event_type, metadata)
  VALUES (v_uid, 'RECOVERY_CODES_REGENERATED', jsonb_build_object('count', array_length(p_new_hashes, 1)));

  RETURN jsonb_build_object('success', true, 'count', array_length(p_new_hashes, 1));
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 11: Revoke Trusted Device
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.revoke_trusted_device_rpc(
  p_device_id text,
  p_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := COALESCE(p_user_id, auth.uid());
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  UPDATE public.trusted_devices
  SET revoked_at = timezone('utc'::text, now())
  WHERE user_id = v_uid
    AND (device_id = p_device_id OR id::text = p_device_id)
    AND revoked_at IS NULL;

  INSERT INTO public.security_events (user_id, event_type, metadata)
  VALUES (v_uid, 'TRUSTED_DEVICE_REVOKED', jsonb_build_object('device_id', p_device_id));

  RETURN jsonb_build_object('success', true);
END;
$$;
