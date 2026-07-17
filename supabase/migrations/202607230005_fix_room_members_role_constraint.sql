-- 202607230005_fix_room_members_role_constraint.sql
-- Fix room_members role check constraint to allow new roles (Owner, Co Owner, Admin, Member)

alter table public.room_members drop constraint if exists room_members_role_check;
alter table public.room_members add constraint room_members_role_check check (role in ('Host', 'Co-Host', 'Moderator', 'Speaker', 'Listener', 'Guest', 'Owner', 'Co Owner', 'Admin', 'Member'));
