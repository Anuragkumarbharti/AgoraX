-- Migration: 202608110010_2fa_server_security_keys.sql
-- Description: High-Security 32-bit / 64-bit Server-Generated Security Keys schema & RPCs for Creania 2FA.

-- 1. Create server_security_keys table
CREATE TABLE IF NOT EXISTS public.server_security_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  key_hash text NOT NULL,
  used boolean NOT NULL DEFAULT false,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_server_keys_user ON public.server_security_keys(user_id);
CREATE INDEX IF NOT EXISTS idx_server_keys_hash ON public.server_security_keys(key_hash);

ALTER TABLE public.server_security_keys ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own server security keys count"
  ON public.server_security_keys FOR SELECT
  USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- RPC: Save Server Security Key Hashes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.save_server_security_key_hashes(
  p_key_hashes text[],
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

  -- Remove existing server security keys for user
  DELETE FROM public.server_security_keys WHERE user_id = v_uid;

  -- Insert new key hashes
  IF p_key_hashes IS NOT NULL THEN
    FOREACH v_hash IN ARRAY p_key_hashes LOOP
      INSERT INTO public.server_security_keys (user_id, key_hash, used)
      VALUES (v_uid, v_hash, false);
    END LOOP;
  END IF;

  INSERT INTO public.security_events (user_id, event_type, metadata)
  VALUES (v_uid, 'SERVER_SECURITY_KEYS_GENERATED', jsonb_build_object('count', array_length(p_key_hashes, 1)));

  RETURN jsonb_build_object('success', true, 'count', array_length(p_key_hashes, 1));
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC: Verify Server Security Key Login
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.verify_server_security_key_login(
  p_user_id uuid,
  p_key_hash text,
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
  v_key_row record;
  v_rate_check jsonb;
  v_remaining_count int;
  v_expires_at timestamptz;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User ID is required');
  END IF;

  -- Rate limit check
  v_rate_check := public.check_2fa_rate_limit(p_user_id);
  IF (v_rate_check->>'allowed')::boolean = false THEN
    RETURN v_rate_check;
  END IF;

  -- Find matching unused server security key
  SELECT * INTO v_key_row
  FROM public.server_security_keys
  WHERE user_id = p_user_id
    AND key_hash = p_key_hash
    AND used = false;

  IF v_key_row.id IS NULL THEN
    PERFORM public.record_2fa_attempt(p_user_id, 'server_key_verify', false, p_device_id);
    INSERT INTO public.security_events (user_id, event_type, metadata)
    VALUES (p_user_id, '2FA_LOGIN_FAILED', jsonb_build_object('reason', 'invalid_server_key', 'device_id', p_device_id));

    RETURN jsonb_build_object('success', false, 'error', 'Invalid server security key. Please try again.');
  END IF;

  -- Mark key as used
  UPDATE public.server_security_keys
  SET used = true,
      used_at = timezone('utc'::text, now())
  WHERE id = v_key_row.id;

  -- Count remaining
  SELECT count(*) INTO v_remaining_count
  FROM public.server_security_keys
  WHERE user_id = p_user_id AND used = false;

  -- Record attempt success & update last verified
  PERFORM public.record_2fa_attempt(p_user_id, 'server_key_verify', true, p_device_id);

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
  VALUES (p_user_id, 'SERVER_SECURITY_KEY_USED', jsonb_build_object('remaining_keys', v_remaining_count, 'device_id', p_device_id));

  RETURN jsonb_build_object(
    'success', true,
    'key_used', true,
    'remaining_keys', v_remaining_count
  );
END;
$$;
