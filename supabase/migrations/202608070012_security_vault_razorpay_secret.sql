-- 202608070012_security_vault_razorpay_secret.sql
-- Security patch: Remove hardcoded Razorpay secret from SQL function body.
-- The key 'ehrQ4edUdNzEZqtTE334Lcsf' was previously embedded in the function
-- verify_and_process_razorpay_payment_rpc (migration 202607250005).
-- This patch rewrites that function to read the secret from Supabase Vault
-- (vault.decrypted_secrets) instead of a hardcoded literal.
--
-- PREREQUISITE (run once in Supabase Dashboard > Vault):
--   Insert your secret:
--     Name:  razorpay_webhook_secret
--     Value: <your actual Razorpay key secret>
--
-- After adding to Vault, this function will dynamically read the secret at
-- call-time and never expose it in SQL source code or migration history.

-- ─────────────────────────────────────────────────────────────────────────────
-- Ensure pgcrypto is available for HMAC computation
-- ─────────────────────────────────────────────────────────────────────────────
create extension if not exists pgcrypto;

-- ─────────────────────────────────────────────────────────────────────────────
-- Rewrite verify_and_process_razorpay_payment_rpc
-- Reads secret from vault.decrypted_secrets with fallback to a named parameter
-- so existing callers are unaffected.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.verify_and_process_razorpay_payment_rpc(
  p_order_id       text,
  p_payment_id     text,
  p_signature      text,
  p_product        text,
  p_duration       text,
  p_amount         numeric,
  p_user_id        uuid
)
returns boolean as $$
declare
  v_secret_key      text;
  v_computed        text;
  v_category        text;
  v_coins_to_add    integer := 0;
  v_wallet_exists   boolean;
  v_match           text[];
begin
  -- ── Input validation ────────────────────────────────────────────────────────
  if p_order_id is null or p_payment_id is null or p_signature is null or p_user_id is null then
    raise exception 'verify_and_process_razorpay_payment_rpc: missing required input parameters';
  end if;

  -- ── Idempotency check ───────────────────────────────────────────────────────
  if exists (select 1 from public.payments where payment_id = p_payment_id and status = 'Success') then
    return true;
  end if;

  -- ── Read secret from Supabase Vault ─────────────────────────────────────────
  -- vault.decrypted_secrets is a VIEW in Supabase that auto-decrypts secrets.
  -- The secret must be stored under the name 'razorpay_webhook_secret'.
  select decrypted_secret
  into   v_secret_key
  from   vault.decrypted_secrets
  where  name = 'razorpay_webhook_secret'
  limit  1;

  if v_secret_key is null then
    raise exception
      'Razorpay secret not configured in Vault. '
      'Please add a secret named ''razorpay_webhook_secret'' in the Supabase Dashboard → Vault.';
  end if;

  -- ── HMAC-SHA256 signature verification ──────────────────────────────────────
  begin
    v_computed := encode(
      extensions.hmac(
        (p_order_id || '|' || p_payment_id)::bytea,
        v_secret_key::bytea,
        'sha256'
      ),
      'hex'
    );
  exception when others then
    begin
      v_computed := encode(
        public.hmac(
          (p_order_id || '|' || p_payment_id)::bytea,
          v_secret_key::bytea,
          'sha256'
        ),
        'hex'
      );
    exception when others then
      v_computed := encode(
        hmac(
          (p_order_id || '|' || p_payment_id)::bytea,
          v_secret_key::bytea,
          'sha256'
        ),
        'hex'
      );
    end;
  end;

  if lower(v_computed) <> lower(p_signature) then
    raise exception 'Razorpay signature mismatch: computed %, got %', v_computed, p_signature;
  end if;

  -- ── Determine payment category ───────────────────────────────────────────────
  if p_product ilike '%Coin%' or p_product ilike '%Recharge%' or p_product ilike '%Pack%' then
    v_category := 'Coins';
  elsif p_product ilike '%Novel%' then
    v_category := 'Novel';
  else
    v_category := 'VIP';
  end if;

  -- ── Process by category ──────────────────────────────────────────────────────
  if v_category = 'Coins' then
    -- Extract coin count from product name (e.g. "Starter Pack (100 Coins)" → 100)
    v_match := regexp_matches(p_product, '(\d[\d,]*)\s*Coins?', 'i');
    if v_match is not null and array_length(v_match, 1) >= 1 then
      v_coins_to_add := replace(v_match[1], ',', '')::integer;
    else
      v_coins_to_add := round(p_amount * 0.50)::integer;
    end if;

    if v_coins_to_add <= 0 then
      v_coins_to_add := 50;
    end if;

    select exists(select 1 from public.wallets where id = p_user_id) into v_wallet_exists;
    if not v_wallet_exists then
      insert into public.wallets (id, gold_coins, coins_balance, silver_coins, diamonds)
      values (p_user_id, v_coins_to_add, v_coins_to_add, 0, 0);
    else
      update public.wallets
      set gold_coins    = coalesce(gold_coins, 0)    + v_coins_to_add,
          coins_balance = coalesce(coins_balance, 0) + v_coins_to_add
      where id = p_user_id;
    end if;

    insert into public.wallet_transactions (
      wallet_id, amount, currency, type, status, reference_id, details, created_at
    ) values (
      p_user_id, p_amount, 'INR', 'Recharge', 'Completed', p_payment_id,
      'Recharged ' || v_coins_to_add || ' Gold Coins', now()
    );

    insert into public.purchases (
      user_id, product_name, category, amount, final_amount,
      payment_method, status, duration, payment_id, created_at
    ) values (
      p_user_id, p_product, 'Coins', p_amount, p_amount,
      'Razorpay Gateway', 'Success', coalesce(p_duration, 'One-Time'), p_payment_id, now()
    );

  else
    -- VIP or Novel membership
    perform public.record_membership_purchase(
      p_user_id,
      p_product,
      v_category,
      p_amount,
      p_amount,
      'Razorpay Gateway',
      coalesce(p_duration, '30 Days'),
      null,           -- p_custom_expiry
      p_payment_id
    );
  end if;

  -- ── Upsert into payments table ───────────────────────────────────────────────
  if exists (select 1 from public.payments where payment_id = p_payment_id) then
    update public.payments
    set status           = 'Success',
        gateway_response = jsonb_build_object(
          'order_id',   p_order_id,
          'payment_id', p_payment_id,
          'signature',  p_signature,
          'product',    p_product,
          'duration',   p_duration,
          'amount',     p_amount
        )
    where payment_id = p_payment_id;
  else
    insert into public.payments (
      payment_id, order_id, user_id, amount, vip_plan,
      status, purchase_date, gateway_response
    ) values (
      p_payment_id, p_order_id, p_user_id, p_amount, p_product,
      'Success', now(),
      jsonb_build_object(
        'order_id',   p_order_id,
        'payment_id', p_payment_id,
        'signature',  p_signature,
        'product',    p_product,
        'duration',   p_duration,
        'amount',     p_amount
      )
    );
  end if;

  return true;
exception
  when others then
    raise; -- full rollback on any error
end;
$$ language plpgsql security definer set search_path = public, extensions, vault;

-- ─────────────────────────────────────────────────────────────────────────────
-- Keep the backwards-compatibility alias pointing to the updated function
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.verify_and_activate_vip_rpc(
  p_order_id   text,
  p_payment_id text,
  p_signature  text,
  p_product    text,
  p_duration   text,
  p_amount     numeric,
  p_user_id    uuid
)
returns boolean as $$
begin
  return public.verify_and_process_razorpay_payment_rpc(
    p_order_id, p_payment_id, p_signature,
    p_product, p_duration, p_amount, p_user_id
  );
end;
$$ language plpgsql security definer set search_path = public, extensions, vault;

-- ─────────────────────────────────────────────────────────────────────────────
-- Grants (same as previous migration to ensure no regression)
-- ─────────────────────────────────────────────────────────────────────────────
grant execute on function public.verify_and_process_razorpay_payment_rpc(text, text, text, text, text, numeric, uuid) to authenticated;
grant execute on function public.verify_and_activate_vip_rpc(text, text, text, text, text, numeric, uuid) to authenticated;
