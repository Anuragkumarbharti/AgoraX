-- Migration: 202608110011_2fa_selectable_methods.sql
-- Description: Supports method-selectable 2FA setup (TOTP, Server Key, or Recovery Code).

-- Update verify_and_enable_2fa RPC to support optional TOTP secret and method parameter
CREATE OR REPLACE FUNCTION public.verify_and_enable_2fa(
  p_totp_secret text DEFAULT NULL,
  p_recovery_code_hashes text[] DEFAULT NULL,
  p_user_id uuid DEFAULT NULL,
  p_method text DEFAULT 'totp'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := COALESCE(p_user_id, auth.uid());
  v_hash text;
  v_method text := COALESCE(p_method, 'totp');
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  -- Enable 2FA in user_security_settings
  INSERT INTO public.user_security_settings (user_id, two_factor_enabled, two_factor_method, totp_secret_encrypted, last_verified_at, updated_at)
  VALUES (v_uid, true, v_method, p_totp_secret, timezone('utc'::text, now()), timezone('utc'::text, now()))
  ON CONFLICT (user_id) DO UPDATE
  SET two_factor_enabled = true,
      two_factor_method = v_method,
      totp_secret_encrypted = COALESCE(EXCLUDED.totp_secret_encrypted, user_security_settings.totp_secret_encrypted),
      last_verified_at = timezone('utc'::text, now()),
      updated_at = timezone('utc'::text, now());

  -- Update profiles table
  UPDATE public.profiles
  SET two_factor_enabled = true,
      updated_at = timezone('utc'::text, now())
  WHERE id = v_uid;

  -- Insert recovery code hashes if provided
  IF p_recovery_code_hashes IS NOT NULL AND array_length(p_recovery_code_hashes, 1) > 0 THEN
    DELETE FROM public.recovery_codes WHERE user_id = v_uid;
    FOREACH v_hash IN ARRAY p_recovery_code_hashes LOOP
      INSERT INTO public.recovery_codes (user_id, code_hash, used)
      VALUES (v_uid, v_hash, false);
    END LOOP;
  END IF;

  INSERT INTO public.security_events (user_id, event_type, metadata)
  VALUES (v_uid, '2FA_ENABLED', jsonb_build_object('method', v_method));

  RETURN jsonb_build_object('success', true, 'method', v_method);
END;
$$;
