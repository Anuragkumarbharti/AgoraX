-- Create room_seat_applications table
create table if not exists public.room_seat_applications (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  applicant_id uuid references public.profiles(id) on delete cascade not null,
  status text default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (room_id, applicant_id)
);

-- Enable RLS
alter table public.room_seat_applications enable row level security;

-- Policies
create policy "Users can view applications for rooms they are in"
  on public.room_seat_applications for select
  using (true);

create policy "Users can insert their own application"
  on public.room_seat_applications for insert
  with check (auth.uid() = applicant_id);

create policy "Users can update/delete their own application or room managers can update/delete"
  on public.room_seat_applications for all
  using (
    auth.uid() = applicant_id or
    exists (
      select 1 from public.rooms
      where rooms.id = room_seat_applications.room_id
      and (rooms.host_id = auth.uid() or rooms.founder_id = auth.uid())
    ) or
    exists (
      select 1 from public.room_members
      where room_members.room_id = room_seat_applications.room_id
      and room_members.user_id = auth.uid()
      and room_members.role in ('Host', 'Co-Host')
    )
  );
