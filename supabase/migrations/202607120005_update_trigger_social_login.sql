-- supabase/migrations/202607120005_update_trigger_social_login.sql
-- Update handle_new_user trigger to recognize provider from user metadata for simulated logins

create or replace function public.handle_new_user()
returns trigger as $$
declare
  provider_name text;
  provider_id text;
  existing_canonical_id uuid;
  generated_uid bigint;
begin
  -- Check user metadata first to support simulated oauth testing, fallback to app metadata
  provider_name := coalesce(new.raw_user_meta_data->>'provider', new.raw_app_meta_data->>'provider', '');
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
