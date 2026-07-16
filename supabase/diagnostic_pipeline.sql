-- ============================================================================
-- DIAGNOSTIC QUERIES — Run these in Supabase SQL Editor to verify the pipeline
-- ============================================================================

-- ── STEP 1: Apply the fix migration ─────────────────────────────────────────
-- Run the file: supabase/migrations/202607090021_fix_entitlement_pipeline.sql
-- in your Supabase project SQL editor.

-- ── STEP 2: Verify cosmetic_assets are seeded ───────────────────────────────
select type, required_membership, required_level, name, cdn_url, priority
from public.cosmetic_assets
order by required_membership, required_level, type;

-- ── STEP 3: Test purchase → entitlement pipeline for a user ─────────────────
-- Replace <YOUR_USER_ID> with a real UUID from auth.users
do $$
declare
  v_uid uuid := '<YOUR_USER_ID>';
begin
  -- Simulate a VIP 1 purchase (30 days)
  perform public.record_membership_purchase(
    v_uid, 'VIP Level 1', 'VIP', 499, 499, 'Gold Coins Wallet', '1 Month'
  );
  raise notice 'Purchase recorded, checking results...';
end $$;

-- ── STEP 4: Verify subscription was created ──────────────────────────────────
select user_id, membership_type, level, status, expiry_date
from public.subscriptions
where user_id = '<YOUR_USER_ID>';

-- ── STEP 5: Verify inventory was granted ─────────────────────────────────────
select inv.user_id, ca.name, ca.type, ca.required_membership, ca.required_level,
       inv.status, inv.is_equipped, inv.expires_at
from public.inventory inv
join public.cosmetic_assets ca on inv.asset_id = ca.asset_id
where inv.user_id = '<YOUR_USER_ID>'
order by ca.required_membership, ca.type;

-- ── STEP 6: Verify profiles.membership_assets and tag_system ─────────────────
select id, vip_level, novel_level, vip_expiry, novel_expiry,
       membership_assets, tag_system
from public.profiles
where id = '<YOUR_USER_ID>';

-- ── STEP 7: Check tag_system identity tags specifically ──────────────────────
select id,
       tag_system->'identityTagBar' as identity_tags,
       tag_system->'officialStatus' as official_status
from public.profiles
where id = '<YOUR_USER_ID>';

-- ── STEP 8: Test expiry revocation ───────────────────────────────────────────
-- Manually expire the subscription and verify all assets are revoked
update public.subscriptions
set expiry_date = now() - interval '1 second'
where user_id = '<YOUR_USER_ID>' and membership_type = 'VIP';

-- This should auto-run via tr_on_subscription_change → recompute_user_entitlements
-- Verify: inventory items should now be Expired, is_equipped = false
select inv.user_id, ca.name, ca.type, inv.status, inv.is_equipped
from public.inventory inv
join public.cosmetic_assets ca on inv.asset_id = ca.asset_id
where inv.user_id = '<YOUR_USER_ID>';

-- Verify: profiles.membership_assets should be '{}', vip_level = 0
select id, vip_level, novel_level, membership_assets, tag_system->'identityTagBar'
from public.profiles
where id = '<YOUR_USER_ID>';

-- ── STEP 9: Verify triggers are in place ─────────────────────────────────────
select trigger_name, event_manipulation, event_object_table, action_timing
from information_schema.triggers
where trigger_schema = 'public'
  and trigger_name in (
    'tr_on_profile_membership_change',
    'tr_on_subscription_change'
  );
