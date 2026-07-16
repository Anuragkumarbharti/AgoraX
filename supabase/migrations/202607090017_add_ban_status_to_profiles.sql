-- 202607090017_add_ban_status_to_profiles.sql
-- Add status, is_banned, and ban_reason columns to public.profiles

alter table public.profiles 
add column if not exists status text default 'active' check (status in ('active', 'suspended', 'banned')),
add column if not exists is_banned boolean default false,
add column if not exists ban_reason text;
