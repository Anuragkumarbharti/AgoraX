-- 202607230009_add_career_level_to_profiles.sql
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS career_level integer DEFAULT 1;
