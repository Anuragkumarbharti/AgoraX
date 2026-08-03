-- Migration: 202608030004_realtime_room_pipeline_fix.sql
-- Enables REPLICA IDENTITY FULL for all voice room tables and registers them in supabase_realtime publication

-- 1. Enable REPLICA IDENTITY FULL on all room tables
alter table public.rooms replica identity full;
alter table public.room_seats replica identity full;
alter table public.room_members replica identity full;
alter table public.room_messages replica identity full;
alter table public.room_requests replica identity full;
alter table public.room_activity_events replica identity full;
alter table public.room_seat_gifts replica identity full;

-- 2. Add all room tables to supabase_realtime publication safely
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_seats'
    ) then
      alter publication supabase_realtime add table public.room_seats;
    end if;

    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_members'
    ) then
      alter publication supabase_realtime add table public.room_members;
    end if;

    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_messages'
    ) then
      alter publication supabase_realtime add table public.room_messages;
    end if;

    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_requests'
    ) then
      alter publication supabase_realtime add table public.room_requests;
    end if;

    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_activity_events'
    ) then
      alter publication supabase_realtime add table public.room_activity_events;
    end if;
  end if;
end
$$;

-- 3. Enhance join_room_seat to sync role and insert activity event
create or replace function public.join_room_seat(
  p_room_id text,
  p_seat_index integer
)
returns void as $$
declare
  v_user_id uuid := auth.uid();
  v_username text;
  v_new_role text;
begin
  if v_user_id is null then
    raise exception 'Unauthenticated';
  end if;

  select username into v_username from public.profiles where id = v_user_id;

  -- Remove user from any previous seat in this room
  update public.room_seats
  set user_id = null, mic_status = 'muted', is_speaking = false
  where room_id = p_room_id and user_id = v_user_id;

  -- Occupy new seat
  update public.room_seats
  set user_id = v_user_id,
      username = v_username,
      mic_status = 'unmuted',
      is_speaking = false
  where room_id = p_room_id and seat_index = p_seat_index;

  -- Determine role based on seat index
  if p_seat_index = 0 then
    v_new_role := 'Host';
  elsif p_seat_index = 1 then
    v_new_role := 'Co-Host';
  else
    v_new_role := 'Speaker';
  end if;

  -- Update member role
  update public.room_members
  set role = v_new_role, last_heartbeat_at = now()
  where room_id = p_room_id and user_id = v_user_id;

  -- Broadcast activity event
  insert into public.room_activity_events (room_id, event_type, user_id, username, seat_number, message)
  values (p_room_id, 'seat_join', v_user_id, v_username, p_seat_index + 1, coalesce(v_username, 'Member') || ' took Seat #' || (p_seat_index + 1));
end;
$$ language plpgsql security definer set search_path = public;

-- 4. Enhance leave_room_seat to update member role to Listener
create or replace function public.leave_room_seat(
  p_room_id text,
  p_seat_index integer
)
returns void as $$
declare
  v_user_id uuid := auth.uid();
  v_username text;
begin
  select username into v_username from public.profiles where id = v_user_id;

  update public.room_seats
  set user_id = null, mic_status = 'muted', is_speaking = false
  where room_id = p_room_id and seat_index = p_seat_index;

  if v_user_id is not null then
    update public.room_members
    set role = 'Listener'
    where room_id = p_room_id and user_id = v_user_id;
  end if;

  insert into public.room_activity_events (room_id, event_type, user_id, username, seat_number, message)
  values (p_room_id, 'seat_leave', v_user_id, v_username, p_seat_index + 1, coalesce(v_username, 'Member') || ' left Seat #' || (p_seat_index + 1));
end;
$$ language plpgsql security definer set search_path = public;
