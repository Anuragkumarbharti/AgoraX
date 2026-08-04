-- Migration 202608030006_fix_room_username_constraint.sql
-- Fix rooms.username check constraint to accept 3 to 30 characters after @ symbol

do $$
begin
  -- Drop existing constraint if present
  if exists (
    select 1 from information_schema.table_constraints
    where table_name = 'rooms'
      and constraint_name = 'check_room_username'
  ) then
    alter table public.rooms drop constraint check_room_username;
  end if;

  -- Allow 3 to 30 alphanumeric/underscore characters following the @ prefix
  alter table public.rooms
    add constraint check_room_username
    check (username ~ '^@[a-z0-9_]{3,30}$');
end;
$$;
