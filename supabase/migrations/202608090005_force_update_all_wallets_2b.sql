-- 202608090005_force_update_all_wallets_2b.sql
-- Force update all wallets to 2 Billion Gold Coins & 1 Billion Silver Coins and return results

ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS gold_coins bigint DEFAULT 0;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS silver_coins bigint DEFAULT 0;

-- 1. Update all wallets in the database directly
UPDATE public.wallets
SET 
  coins_balance = 2000000000,
  gold_coins    = 2000000000,
  silver_coins  = 1000000000;

-- 2. Return updated rows to confirm in Supabase SQL Editor
SELECT 
  w.id,
  p.username,
  p.uid,
  w.coins_balance,
  w.gold_coins,
  w.silver_coins
FROM public.wallets w
LEFT JOIN public.profiles p ON p.id = w.id;
