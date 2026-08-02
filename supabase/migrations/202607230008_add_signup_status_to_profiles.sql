-- 202607230008_add_signup_status_to_profiles.sql
-- Add signup_status column to profiles table

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS signup_status text;
UPDATE public.profiles SET signup_status = 'completed' WHERE signup_status IS NULL;
ALTER TABLE public.profiles ALTER COLUMN signup_status SET DEFAULT 'pending_verification';
