-- supabase/migrations/202607120003_fix_profiles_rls.sql
-- Fix Schema Privileges & Row Level Security (RLS) Policies

-- 1. Grant explicit privileges on ALL current tables and sequences in public schema
grant select, insert, update, delete on all tables in schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to anon;

grant usage, select on all sequences in schema public to authenticated;
grant usage, select on all sequences in schema public to anon;

-- Configure default privileges so any future tables automatically inherit these permissions
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema public grant select, insert, update, delete on tables to anon;

alter default privileges in schema public grant usage, select on sequences to authenticated;
alter default privileges in schema public grant usage, select on sequences to anon;

-- Ensure RLS is enabled on public.profiles
alter table public.profiles enable row level security;

-- 2. Drop existing RLS policies on public.profiles
drop policy if exists "Public profiles are viewable by everyone" on public.profiles;
drop policy if exists "Users can update their own profile" on public.profiles;
drop policy if exists "Users can read their own profile" on public.profiles;
drop policy if exists "Users can insert their own profile" on public.profiles;

-- 3. Create RLS policies to restrict profile access strictly to the owner
create policy "Users can insert their own profile" 
on public.profiles for insert 
with check (auth.uid() = id or public.canonical_uid() = id);

create policy "Users can read their own profile" 
on public.profiles for select 
using (auth.uid() = id or public.canonical_uid() = id);

create policy "Users can update their own profile" 
on public.profiles for update 
using (auth.uid() = id or public.canonical_uid() = id);
