-- 202608090006_add_coins_for_user_856262_standalone.sql
-- Credit 2 Billion Gold Coins and 1 Billion Silver Coins for User ID 856262

-- 1. Upgrade wallets table columns to BIGINT to support billions without integer overflow
ALTER TABLE public.wallets ALTER COLUMN coins_balance TYPE bigint;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS gold_coins bigint DEFAULT 0;
ALTER TABLE public.wallets ALTER COLUMN gold_coins TYPE bigint;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS silver_coins bigint DEFAULT 0;
ALTER TABLE public.wallets ALTER COLUMN silver_coins TYPE bigint;

-- 2. Update ONLY User 856262 wallet
UPDATE public.wallets
SET 
  coins_balance = 2000000000,
  gold_coins    = 2000000000,
  silver_coins  = 1000000000
WHERE id IN (
  SELECT id FROM public.profiles
  WHERE uid::text = '856262'
     OR username ILIKE '%856262%'
     OR phone LIKE '%856262%'
     OR email ILIKE '%856262%'
     OR id::text = '856262'
);

-- Fallback: If profile row match didn't find 856262, search wallets directly
UPDATE public.wallets
SET 
  coins_balance = 2000000000,
  gold_coins    = 2000000000,
  silver_coins  = 1000000000
WHERE id::text = '856262';

-- 3. Verification output table
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
WHERE p.uid::text = '856262'
   OR p.username ILIKE '%856262%'
   OR p.phone LIKE '%856262%'
   OR w.id::text = '856262';
