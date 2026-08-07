-- 202608070013_init_vault_secrets.sql
-- ─────────────────────────────────────────────────────────────────────────────
-- One-time Vault initialization migration.
-- This migration stores the Razorpay webhook signing secret in Supabase Vault
-- so it is encrypted at rest via pgsodium and never appears in SQL function bodies.
--
-- IMPORTANT: After applying this migration, rotate your Razorpay key:
--   1. Go to Razorpay Dashboard → Settings → API Keys → Regenerate Secret
--   2. Update this Vault secret via:
--        select vault.update_secret(<id>, '<new_secret>', 'razorpay_webhook_secret');
--      or from the Supabase Dashboard → Vault → click secret → Edit
--
-- This migration is idempotent: safe to apply multiple times.
-- ─────────────────────────────────────────────────────────────────────────────

do $$
declare
  v_existing_id uuid;
begin
  -- Check whether the secret is already stored (prevents duplicate on re-run)
  select id into v_existing_id
  from   vault.secrets
  where  name = 'razorpay_webhook_secret'
  limit  1;

  if v_existing_id is null then
    -- vault.create_secret encrypts the value with pgsodium automatically.
    -- The raw value is never stored in plaintext in pg_catalog or pg_toast.
    perform vault.create_secret(
      'ehrQ4edUdNzEZqtTE334Lcsf',
      'razorpay_webhook_secret',
      'Razorpay webhook HMAC-SHA256 signing secret — rotate after first deploy'
    );

    raise notice '[Vault] Secret ''razorpay_webhook_secret'' created and encrypted at rest.';
  else
    raise notice '[Vault] Secret ''razorpay_webhook_secret'' already present (id: %). No action taken.', v_existing_id;
  end if;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Verify the secret is readable through the decrypted view
-- (The RPC function reads it from here at call-time)
-- ─────────────────────────────────────────────────────────────────────────────
do $$
declare
  v_check text;
begin
  select decrypted_secret into v_check
  from   vault.decrypted_secrets
  where  name = 'razorpay_webhook_secret'
  limit  1;

  if v_check is null then
    raise exception '[Vault] CRITICAL: Secret ''razorpay_webhook_secret'' was inserted but cannot be read back from vault.decrypted_secrets. Check pgsodium configuration.';
  else
    raise notice '[Vault] Verification passed: secret is readable through vault.decrypted_secrets.';
  end if;
end;
$$;
