-- Migration 202608030008_realtime_activity_and_chats.sql
-- Ensure REPLICA IDENTITY FULL and publication registration for voice room real-time features

-- 1. Set REPLICA IDENTITY FULL
alter table public.rooms replica identity full;
alter table public.room_seats replica identity full;
alter table public.room_members replica identity full;
alter table public.room_messages replica identity full;
alter table public.room_activity_events replica identity full;

-- 2. Register tables into supabase_realtime publication
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
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_activity_events'
    ) then
      alter publication supabase_realtime add table public.room_activity_events;
    end if;
  end if;
end
$$;
