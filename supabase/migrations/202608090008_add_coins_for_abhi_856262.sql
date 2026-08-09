-- 202608090008_add_coins_for_abhi_856262.sql
-- Credit 2 Billion Gold Coins and 1 Billion Silver Coins ONLY for User 'abhi' (ID: 856262)

-- 1. Upgrade wallets table columns to BIGINT (prevents integer overflow error)
ALTER TABLE public.wallets ALTER COLUMN coins_balance TYPE bigint;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS gold_coins bigint DEFAULT 0;
ALTER TABLE public.wallets ALTER COLUMN gold_coins TYPE bigint;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS silver_coins bigint DEFAULT 0;
ALTER TABLE public.wallets ALTER COLUMN silver_coins TYPE bigint;

-- 2. Upsert / update ONLY user 'abhi' (ID: 856262)
DO $$
DECLARE
  target_user_id uuid;
BEGIN
  -- Search for user 'abhi' / 856262 in profiles table
  SELECT id INTO target_user_id
  FROM public.profiles
  WHERE username ILIKE 'abhi'
     OR username ILIKE '%abhi%'
     OR uid::text = '856262'
     OR id::text = '856262'
  LIMIT 1;

  -- Fallback: check wallets table directly
  IF target_user_id IS NULL THEN
    SELECT id INTO target_user_id FROM public.wallets WHERE id::text = '856262' LIMIT 1;
  END IF;

  -- Fallback: check auth.users table directly for email/username 'abhi'
  IF target_user_id IS NULL THEN
    SELECT id INTO target_user_id FROM auth.users WHERE email ILIKE '%abhi%' LIMIT 1;
  END IF;

  IF target_user_id IS NOT NULL THEN
    INSERT INTO public.wallets (id, coins_balance, gold_coins, silver_coins)
    VALUES (target_user_id, 2000000000, 2000000000, 1000000000)
    ON CONFLICT (id) DO UPDATE
    SET 
      coins_balance = 2000000000,
      gold_coins    = 2000000000,
      silver_coins  = 1000000000;

    INSERT INTO public.wallet_transactions (wallet_id, amount, currency, type, status, details)
    VALUES (target_user_id, 2000000000, 'Gold Coins', 'Admin Grant', 'Completed', 'Admin granted 2B Gold Coins to @abhi');

    INSERT INTO public.wallet_transactions (wallet_id, amount, currency, type, status, details)
    VALUES (target_user_id, 1000000000, 'Silver Coins', 'Admin Grant', 'Completed', 'Admin granted 1B Silver Coins to @abhi');

    RAISE NOTICE 'SUCCESS: Added 2B Gold & 1B Silver Coins to user @abhi (ID: 856262, UUID: %)', target_user_id;
  ELSE
    RAISE NOTICE 'WARNING: User @abhi (ID: 856262) not found in database.';
  END IF;
END;
$$;

-- 3. Verification table output
SELECT 
  p.id,
  p.username,
  p.uid,
  p.email,
  w.coins_balance,
  w.gold_coins,
  w.silver_coins
FROM public.wallets w
LEFT JOIN public.profiles p ON p.id = w.id
WHERE p.username ILIKE '%abhi%'
   OR p.uid::text = '856262'
   OR w.id::text = '856262';
