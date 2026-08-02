-- 202607250011_add_missing_unique_constraints.sql
-- Safe idempotent migration: adds all unique constraints needed for ON CONFLICT clauses
-- Apply via Supabase Dashboard > SQL Editor

-- 1. user_customizations (user_id, type, name) — needed for equip ON CONFLICT
do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'user_customizations_user_id_type_name_key'
      and conrelid = 'public.user_customizations'::regclass
  ) then
    alter table public.user_customizations
      add constraint user_customizations_user_id_type_name_key unique (user_id, type, name);
  end if;
exception when others then null;
end $$;

-- 2. subscriptions (user_id, membership_type) — needed for VIP/Novel upserts
do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conname in ('subscriptions_user_id_membership_type_key', 'subscriptions_user_membership_unique')
      and conrelid = 'public.subscriptions'::regclass
  ) then
    alter table public.subscriptions
      add constraint subscriptions_user_id_membership_type_key unique (user_id, membership_type);
  end if;
exception when others then null;
end $$;

-- 3. purchases (payment_id) — needed for idempotency check
do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'purchases_payment_id_key'
      and conrelid = 'public.purchases'::regclass
  ) then
    alter table public.purchases
      add constraint purchases_payment_id_key unique (payment_id);
  end if;
exception when others then null;
end $$;

select 'Constraints applied successfully' as result;
