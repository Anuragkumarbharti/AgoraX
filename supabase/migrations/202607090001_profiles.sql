-- 202607090001_profiles.sql
-- Profiles schema, UID generator, signup triggers, updated_at triggers, and RLS policies

-- 1. UID generator (Defined first to be used as default)
create or replace function public.generate_unique_uid()
returns bigint as $$
declare
  new_uid bigint;
  exists_uid boolean;
begin
  loop
    new_uid := floor(random() * (999999999999 - 1000000000 + 1) + 1000000000)::bigint;
    select exists(select 1 from public.profiles where uid = new_uid) into exists_uid;
    if not exists_uid then
      return new_uid;
    end if;
  end loop;
end;
$$ language plpgsql;

-- 2. Profiles table
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  uid bigint unique not null default public.generate_unique_uid(),
  username text unique not null,
  email text unique,
  phone text unique,
  avatar_url text,
  profile_photo text,
  cover_photo text,
  dob date,
  age integer,
  gender text,
  state text,
  city text,
  profession text,
  education text,
  website text,
  instagram text,
  youtube text,
  twitter text,
  interests text[] default '{}',
  level integer default 1 check (level >= 1),
  experience integer default 0 check (experience >= 0),
  followers integer default 0 check (followers >= 0),
  following integer default 0 check (following >= 0),
  followers_count integer default 0 check (followers_count >= 0),
  following_count integer default 0 check (following_count >= 0),
  friends_count integer default 0 check (friends_count >= 0),
  rooms_joined integer default 0 check (rooms_joined >= 0),
  events_joined integer default 0 check (events_joined >= 0),
  bio text,
  country text,
  language text default 'en',
  avatar_frame text default 'Normal',
  profile_theme text default 'Default',
  vip_level integer default 0 check (vip_level between 0 and 7),
  novel_level integer default 0 check (novel_level between 0 and 7),
  vip_expiry timestamp with time zone,
  novel_expiry timestamp with time zone,
  badges text[] default '{}',
  progress_metadata jsonb default '{}'::jsonb,
  google_provider_id text unique,
  apple_provider_id text unique,
  email_verified boolean default false,
  verification_timestamp timestamp with time zone,
  verification_method text,
  last_verification_date timestamp with time zone,
  selected_study_category text,
  category_lock_expiry timestamp with time zone,
  career_name text,
  career_xp integer default 0,
  theme_preference text default 'dark',
  tag_lights text[] default '{}',
  r_tags text[] default '{}',
  showcased_badges text[] default '{}',
  tag_system jsonb default '{}'::jsonb,
  official_community_cooldown_until timestamp with time zone,
  total_stars_received integer default 0 check (total_stars_received >= 0),
  total_stars_gifted integer default 0 check (total_stars_gifted >= 0),
  verified boolean default false not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- handle_new_user signup trigger
create or replace function public.handle_new_user()
returns trigger as $$
declare
  generated_uid bigint;
begin
  generated_uid := public.generate_unique_uid();

  begin
    insert into public.profiles (
      id, 
      uid,
      username, 
      email,
      phone,
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
      new.raw_user_meta_data->>'avatar_url',
      new.raw_user_meta_data->>'avatar_url',
      0,
      0,
      1,
      0,
      false
    )
    on conflict (id) do update set
      email = coalesce(profiles.email, excluded.email),
      phone = coalesce(profiles.phone, excluded.phone),
      avatar_url = coalesce(profiles.avatar_url, excluded.avatar_url),
      profile_photo = coalesce(profiles.profile_photo, excluded.profile_photo);
  exception 
    when unique_violation then
      begin
        insert into public.profiles (
          id, 
          uid,
          username, 
          email,
          phone,
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
          'user_' || substr(new.id::text, 1, 8) || '_' || (random() * 1000)::int::text,
          null,
          null,
          new.raw_user_meta_data->>'avatar_url',
          new.raw_user_meta_data->>'avatar_url',
          0,
          0,
          1,
          0,
          false
        );
      exception when others then
        raise notice 'Failed to insert profile: %', SQLERRM;
      end;
    when others then
      raise notice 'Failed to insert profile: %', SQLERRM;
  end;

  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Trigger to auto-update updated_at column on profiles
create or replace function public.update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger set_updated_at
before update on public.profiles
for each row execute function public.update_updated_at_column();

-- Row Level Security (RLS) Policies
alter table public.profiles enable row level security;
create policy "Allow read access to everyone" on public.profiles for select using (true);
create policy "Allow insert access to owner" on public.profiles for insert with check (auth.uid() = id);
create policy "Allow update access to owner" on public.profiles for update using (auth.uid() = id);
create policy "Allow delete access to owner" on public.profiles for delete using (auth.uid() = id);

-- Realtime registration
do $$
begin
  alter publication supabase_realtime add table public.profiles;
exception when others then
  raise notice 'Table profiles already in supabase_realtime publication';
end;
$$;
