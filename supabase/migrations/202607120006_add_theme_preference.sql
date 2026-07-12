-- supabase/migrations/202607120006_add_theme_preference.sql
-- Add user theme preference column to the profiles table to synchronize user selection across devices.

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS theme_preference text DEFAULT 'system';
