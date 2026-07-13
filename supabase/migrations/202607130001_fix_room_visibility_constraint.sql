-- supabase/migrations/202607130001_fix_room_visibility_constraint.sql
-- Drop the existing constraint
alter table public.rooms drop constraint if exists rooms_visibility_check;

-- Add the updated constraint to support all UI and category values
alter table public.rooms add constraint rooms_visibility_check check (
  visibility in ('everyone', 'followers_only', 'paid_members', 'vip_only', 'password_required', 'password', 'public', 'private', 'community', 'study', 'gaming', 'music', 'podcast', 'event')
);
