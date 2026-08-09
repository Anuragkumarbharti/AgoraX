-- 202608090007_add_coins_my_account_only.sql
-- Credit 2 Billion Gold Coins & 1 Billion Silver Coins ONLY to the active/current logged in user account

-- 1. Upgrade wallets table columns to BIGINT to support billions without integer overflow
ALTER TABLE public.wallets ALTER COLUMN coins_balance TYPE bigint;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS gold_coins bigint DEFAULT 0;
ALTER TABLE public.wallets ALTER COLUMN gold_coins TYPE bigint;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS silver_coins bigint DEFAULT 0;
ALTER TABLE public.wallets ALTER COLUMN silver_coins TYPE bigint;

-- 2. Update ONLY the active account (auth.uid() or latest active profile)
DO $$
DECLARE
  my_user_id uuid;
BEGIN
  my_user_id := auth.uid();
  
  IF my_user_id IS NULL THEN
    SELECT id INTO my_user_id 
    FROM public.profiles 
    ORDER BY updated_at DESC NULLS LAST 
    LIMIT 1;
  END IF;

  IF my_user_id IS NOT NULL THEN
    INSERT INTO public.wallets (id, coins_balance, gold_coins, silver_coins)
    VALUES (my_user_id, 2000000000, 2000000000, 1000000000)
    ON CONFLICT (id) DO UPDATE
    SET 
      coins_balance = 2000000000,
      gold_coins    = 2000000000,
      silver_coins  = 1000000000;

    RAISE NOTICE 'Successfully updated wallet for active user ID: %', my_user_id;
  ELSE
    RAISE NOTICE 'No profile row found in database.';
  END IF;
END;
$$;

-- 3. Return verification result for active user
SELECT 
  p.id,
  p.username,
  p.uid,
  p.email,
  w.coins_balance,
  w.gold_coins,
  w.silver_coins
FROM public.wallets w
JOIN public.profiles p ON p.id = w.id
ORDER BY p.updated_at DESC NULLS LAST
LIMIT 1;
