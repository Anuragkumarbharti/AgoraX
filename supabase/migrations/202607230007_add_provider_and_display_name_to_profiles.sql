-- 202607230007_add_provider_and_display_name_to_profiles.sql
-- Add display_name and facebook_provider_id columns to public.profiles table

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS display_name text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS facebook_provider_id text UNIQUE;
