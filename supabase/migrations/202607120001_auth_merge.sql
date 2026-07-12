-- supabase/migrations/202607120001_auth_merge.sql
-- Master Identity Merge & Email Verification System Database Layer

-- 1. Create mappings table
create table if not exists public.user_auth_mappings (
  auth_id uuid primary key,
  canonical_id uuid not null,
  created_at timestamp with time zone default now()
);

-- Enable RLS on mapping table
alter table public.user_auth_mappings enable row level security;
create policy "Allow public select on mappings" on public.user_auth_mappings for select using (true);

-- Populate mapping table with any existing profiles
insert into public.user_auth_mappings (auth_id, canonical_id)
select id, id from public.profiles
on conflict (auth_id) do nothing;

-- 2. Add provider ID and email validation columns to profiles
alter table public.profiles
  add column if not exists google_provider_id text,
  add column if not exists apple_provider_id text,
  add column if not exists email_verified boolean default false,
  add column if not exists verification_timestamp timestamp with time zone,
  add column if not exists verification_method text,
  add column if not exists last_verification_date timestamp with time zone;

-- Add unique constraints
alter table public.profiles
  drop constraint if exists profiles_email_key,
  drop constraint if exists profiles_phone_key,
  drop constraint if exists profiles_google_provider_id_key,
  drop constraint if exists profiles_apple_provider_id_key;

alter table public.profiles
  add constraint profiles_email_key unique (email),
  add constraint profiles_phone_key unique (phone),
  add constraint profiles_google_provider_id_key unique (google_provider_id),
  add constraint profiles_apple_provider_id_key unique (apple_provider_id);

-- 3. Create canonical UID resolution helper
create or replace function public.canonical_uid()
returns uuid as $$
  select coalesce(
    (select canonical_id from public.user_auth_mappings where auth_id = auth.uid()),
    auth.uid()
  );
$$ language sql stable security definer;

-- 4. Drop trigger first
drop trigger if exists on_auth_user_created on auth.users;

-- 5. Refactor signup trigger function to handle identity merges & verification
create or replace function public.handle_new_user()
returns trigger as $$
declare
  provider_name text;
  provider_id text;
  existing_canonical_id uuid;
  generated_uid bigint;
begin
  provider_name := coalesce(new.raw_app_meta_data->>'provider', '');
  provider_id := coalesce(new.raw_user_meta_data->>'sub', '');
  
  -- Scan existing profiles to prevent duplicates in specified priority order:
  -- 1. Existing Provider User ID
  if existing_canonical_id is null and provider_name = 'google' and provider_id <> '' then
    select id into existing_canonical_id from public.profiles where google_provider_id = provider_id;
  end if;

  if existing_canonical_id is null and provider_name = 'apple' and provider_id <> '' then
    select id into existing_canonical_id from public.profiles where apple_provider_id = provider_id;
  end if;

  -- 2. Existing Email
  if existing_canonical_id is null and new.email is not null and new.email <> '' then
    select id into existing_canonical_id from public.profiles where email = new.email;
  end if;

  -- 3. Existing Phone Number
  if existing_canonical_id is null and new.phone is not null and new.phone <> '' then
    select id into existing_canonical_id from public.profiles where phone = new.phone;
  end if;

  -- Insert/update mapping and profile record based on result
  if existing_canonical_id is not null then
    -- LINK IDENTITY: Map this new auth user to the existing canonical profile
    insert into public.user_auth_mappings (auth_id, canonical_id)
    values (new.id, existing_canonical_id)
    on conflict (auth_id) do update set canonical_id = excluded.canonical_id;

    -- Coalesce missing credentials and verify status on the existing profile
    update public.profiles
    set
      email = coalesce(profiles.email, new.email),
      phone = coalesce(profiles.phone, new.phone),
      google_provider_id = case when provider_name = 'google' then coalesce(profiles.google_provider_id, provider_id) else profiles.google_provider_id end,
      apple_provider_id = case when provider_name = 'apple' then coalesce(profiles.apple_provider_id, provider_id) else profiles.apple_provider_id end,
      email_verified = case when (new.email is not null and new.email <> '') then true else profiles.email_verified end,
      verification_timestamp = case when (new.email is not null and new.email <> '') then now() else profiles.verification_timestamp end,
      verification_method = case when (new.email is not null and new.email <> '') then 'OAuth' else profiles.verification_method end,
      last_verification_date = case when (new.email is not null and new.email <> '') then now() else profiles.last_verification_date end
    where id = existing_canonical_id;

  else
    -- NEW IDENTITY: Map new auth user to themselves as canonical
    insert into public.user_auth_mappings (auth_id, canonical_id)
    values (new.id, new.id)
    on conflict (auth_id) do nothing;

    generated_uid := public.generate_unique_uid();

    insert into public.profiles (
      id, 
      uid,
      username, 
      email,
      phone,
      display_name,
      avatar_url, 
      profile_photo,
      google_provider_id,
      apple_provider_id,
      email_verified,
      verification_timestamp,
      verification_method,
      last_verification_date,
      vip_level, 
      novel_level, 
      level, 
      experience,
      verified
    )
    values (
      new.id,
      generated_uid,
      coalesce(new.raw_user_meta_data->>'username', 'user_' || substr(new.id::text, 1, 8)),
      new.email,
      new.phone,
      coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'full_name', 'Creania Student'),
      new.raw_user_meta_data->>'avatar_url',
      new.raw_user_meta_data->>'avatar_url',
      case when provider_name = 'google' then provider_id else null end,
      case when provider_name = 'apple' then provider_id else null end,
      case when (provider_name = 'google' or provider_name = 'apple') then true else false end,
      case when (provider_name = 'google' or provider_name = 'apple') then now() else null end,
      case when (provider_name = 'google' or provider_name = 'apple') then 'OAuth' else null end,
      case when (provider_name = 'google' or provider_name = 'apple') then now() else null end,
      0,
      0,
      1,
      0,
      false
    )
    on conflict (id) do update
    set 
      uid = excluded.uid,
      email = coalesce(profiles.email, excluded.email),
      phone = coalesce(profiles.phone, excluded.phone);

    -- Create Wallet
    insert into public.wallets (id, coins_balance, inr_balance, withdrawable_balance)
    values (new.id, 0, 0.00, 0.00)
    on conflict (id) do nothing;
  end if;

  return new;
end;
$$ language plpgsql security definer;

-- 6. Recreate user creation trigger
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 7. Update RLS policies to use canonical_uid()

-- profiles
drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile" on public.profiles for update using (public.canonical_uid() = id);

-- wallets
drop policy if exists "Users can view their own wallet" on public.wallets;
drop policy if exists "Users can update their own wallet" on public.wallets;
create policy "Users can view their own wallet" on public.wallets for select using (public.canonical_uid() = id);
create policy "Users can update their own wallet" on public.wallets for update using (public.canonical_uid() = id);

-- wallet_transactions
drop policy if exists "Users can view their transactions" on public.wallet_transactions;
create policy "Users can view their transactions" on public.wallet_transactions for select using (public.canonical_uid() = wallet_id);

-- purchase_history
drop policy if exists "Users can view purchase history" on public.purchase_history;
create policy "Users can view purchase history" on public.purchase_history for select using (public.canonical_uid() = user_id);

-- gift_history
drop policy if exists "Users can view sent/received gifts" on public.gift_history;
create policy "Users can view sent/received gifts" on public.gift_history for select using (public.canonical_uid() = sender_id or public.canonical_uid() = receiver_id);

-- withdraw_history
drop policy if exists "Users can view withdrawal requests" on public.withdraw_history;
create policy "Users can view withdrawal requests" on public.withdraw_history for select using (public.canonical_uid() = user_id);

-- inventory
drop policy if exists "Users can view their inventory" on public.inventory;
create policy "Users can view their inventory" on public.inventory for select using (public.canonical_uid() = user_id);

-- study_vault_items
drop policy if exists "Users can upload resources" on public.study_vault_items;
create policy "Users can upload resources" on public.study_vault_items for insert with check (public.canonical_uid() = seller_id);

-- reading_history
drop policy if exists "Users can modify their own history" on public.reading_history;
create policy "Users can modify their own history" on public.reading_history for all using (public.canonical_uid() = user_id);

-- messages
drop policy if exists "Users can view messages" on public.messages;
drop policy if exists "Users can insert messages" on public.messages;
create policy "Users can view messages" on public.messages for select using (not is_private or public.canonical_uid() = sender_id or public.canonical_uid() = receiver_id);
create policy "Users can insert messages" on public.messages for insert with check (public.canonical_uid() = sender_id);

-- notifications
drop policy if exists "Users can view their notifications" on public.notifications;
create policy "Users can view their notifications" on public.notifications for select using (public.canonical_uid() = user_id);
