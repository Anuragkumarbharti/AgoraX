-- 202608090004_add_coins_for_user_574382_riyu.sql
-- Fix: Upgrade columns to bigint and credit 2B Gold & 1B Silver Coins for target users

-- 1. Upgrade wallets table columns to bigint to support billions without integer overflow
ALTER TABLE public.wallets ALTER COLUMN coins_balance TYPE bigint;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS gold_coins bigint DEFAULT 0;
ALTER TABLE public.wallets ALTER COLUMN gold_coins TYPE bigint;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS silver_coins bigint DEFAULT 0;
ALTER TABLE public.wallets ALTER COLUMN silver_coins TYPE bigint;

-- 2. Update ONLY targeted accounts ('riyu', '574382', '856262')
UPDATE public.wallets
SET 
  coins_balance = 2000000000,
  gold_coins    = 2000000000,
  silver_coins  = 1000000000
WHERE id IN (
  SELECT id FROM public.profiles
  WHERE username ILIKE '%riyu%'
     OR email ILIKE '%riyu%'
     OR phone LIKE '%574382%'
     OR uid::text = '574382'
     OR uid::text = '856262'
     OR username ILIKE '%574382%'
     OR username ILIKE '%856262%'
);

-- 3. Return updated target user profiles for verification
SELECT 
  p.id,
  p.username,
  p.uid,
  p.email,
  w.coins_balance,
  w.gold_coins,
  w.silver_coins
FROM public.profiles p
JOIN public.wallets w ON w.id = p.id
WHERE p.username ILIKE '%riyu%'
   OR p.email ILIKE '%riyu%'
   OR p.phone LIKE '%574382%'
   OR p.uid::text IN ('574382', '856262')
   OR p.username ILIKE '%856262%';
