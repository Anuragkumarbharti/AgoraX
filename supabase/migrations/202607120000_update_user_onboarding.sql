-- supabase/migrations/202607120000_update_user_onboarding.sql
-- Database updates for Creania Onboarding & Authentication System

-- Generate a unique 10-12 digit numeric ID for each user
create or replace function public.generate_unique_uid()
returns bigint as $$
declare
  new_uid bigint;
  exists_uid boolean;
begin
  loop
    -- Generate random 10 to 12 digit number
    new_uid := floor(random() * (999999999999 - 1000000000 + 1) + 1000000000)::bigint;
    select exists(select 1 from public.profiles where uid = new_uid) into exists_uid;
    if not exists_uid then
      return new_uid;
    end if;
  end loop;
end;
$$ language plpgsql;

-- Alter profiles table to add new onboarding and authentication fields
alter table public.profiles
  add column if not exists uid bigint unique,
  add column if not exists email text,
  add column if not exists phone text,
  add column if not exists display_name text,
  add column if not exists full_name text,
  add column if not exists profile_photo text,
  add column if not exists cover_photo text,
  add column if not exists dob date,
  add column if not exists age integer,
  add column if not exists gender text,
  add column if not exists state text,
  add column if not exists city text,
  add column if not exists profession text,
  add column if not exists education text,
  add column if not exists website text,
  add column if not exists instagram text,
  add column if not exists youtube text,
  add column if not exists twitter text,
  add column if not exists interests text[] default '{}',
  add column if not exists verified boolean default false,
  add column if not exists coins integer default 0,
  add column if not exists diamonds integer default 0,
  add column if not exists followers_count integer default 0,
  add column if not exists following_count integer default 0,
  add column if not exists friends_count integer default 0,
  add column if not exists rooms_joined integer default 0,
  add column if not exists events_joined integer default 0,
  add column if not exists online_status boolean default false,
  add column if not exists last_seen timestamp with time zone,
  add column if not exists updated_at timestamp with time zone default now();

-- Update trigger function for handle_new_user to populate new fields
create or replace function public.handle_new_user()
returns trigger as $$
declare
  generated_uid bigint;
begin
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

  insert into public.wallets (id, coins_balance, inr_balance, withdrawable_balance)
  values (new.id, 0, 0.00, 0.00)
  on conflict (id) do nothing;

  return new;
end;
$$ language plpgsql security definer;
