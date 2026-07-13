-- supabase/migrations/202607130002_fix_rooms_rls_recursion.sql
-- Drop the problematic "for all" policy on room_members
drop policy if exists "Modify members" on public.room_members;
drop policy if exists "Insert members" on public.room_members;
drop policy if exists "Update members" on public.room_members;
drop policy if exists "Delete members" on public.room_members;

-- Create separate insert/update/delete policies to avoid select query recursion
create policy "Insert members" on public.room_members for insert with check (
  auth.uid() = user_id 
  or exists (
    select 1 from public.rooms 
    where rooms.id = room_members.room_id and rooms.host_id = auth.uid()
  )
);

create policy "Update members" on public.room_members for update using (
  auth.uid() = user_id 
  or exists (
    select 1 from public.rooms 
    where rooms.id = room_members.room_id and rooms.host_id = auth.uid()
  )
);

create policy "Delete members" on public.room_members for delete using (
  auth.uid() = user_id 
  or exists (
    select 1 from public.rooms 
    where rooms.id = room_members.room_id and rooms.host_id = auth.uid()
  )
);
