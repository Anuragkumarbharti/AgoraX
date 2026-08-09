-- 202608090003_add_coins_for_user_856262.sql
-- Add 2 Billion (2,000,000,000) Gold Coins and 1 Billion (1,000,000,000) Silver Coins for User ID 856262

DO $$
DECLARE
  target_user_id uuid;
BEGIN
  -- 1. Find user UUID by uid (numeric id), username, or UUID text string '856262'
  SELECT id INTO target_user_id
  FROM public.profiles
  WHERE uid::text = '856262'
     OR username = '856262'
     OR id::text = '856262'
  LIMIT 1;

  IF target_user_id IS NULL THEN
    -- Fallback: check if id exists directly in wallets or auth.users
    SELECT id INTO target_user_id
    FROM public.wallets
    WHERE id::text = '856262'
    LIMIT 1;
  END IF;

  IF target_user_id IS NOT NULL THEN
    -- 2. Upsert target user's wallet with +2 Billion Gold Coins & +1 Billion Silver Coins
    INSERT INTO public.wallets (
      id,
      coins_balance,
      gold_coins,
      silver_coins_balance,
      silver_coins,
      withdrawable_balance
    )
    VALUES (
      target_user_id,
      2000000000,
      2000000000,
      1000000000,
      1000000000,
      0.0
    )
    ON CONFLICT (id) DO UPDATE
    SET
      coins_balance        = COALESCE(public.wallets.coins_balance, 0) + 2000000000,
      gold_coins           = COALESCE(public.wallets.gold_coins, 0) + 2000000000,
      silver_coins_balance = COALESCE(public.wallets.silver_coins_balance, 0) + 1000000000,
      silver_coins         = COALESCE(public.wallets.silver_coins, 0) + 1000000000;

    -- 3. Insert transaction log into wallet_transactions
    INSERT INTO public.wallet_transactions (
      wallet_id,
      amount,
      currency,
      type,
      status,
      details
    )
    VALUES (
      target_user_id,
      2000000000,
      'Gold & Silver Coins',
      'Admin Credit',
      'Completed',
      'Admin added 2,000,000,000 Gold Coins and 1,000,000,000 Silver Coins'
    );

    RAISE NOTICE 'Successfully added 2B Gold Coins and 1B Silver Coins for User ID 856262 (UUID: %)', target_user_id;
  ELSE
    RAISE NOTICE 'User with ID/UID 856262 not found in database.';
  END IF;
END;
$$;
