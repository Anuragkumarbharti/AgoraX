-- Migration 202608030007_purge_all_historical_room_messages.sql
-- Purge all historical room messages and notifications, and auto-purge when room becomes empty

-- 1. PURGE ALL HISTORICAL ROOM CHAT MESSAGES FROM DATABASE
truncate table public.room_messages;

-- 2. PURGE HISTORICAL ROOM & GIFT NOTIFICATIONS FROM NOTIFICATIONS TABLE
delete from public.notifications
where type in ('room', 'room_chat', 'gift', 'room_gift', 'mention', 'seat_change', 'mic_activity', 'room_event');

-- 3. AUTOMATIC TRIGGER TO PURGE MESSAGES WHEN A ROOM HAS 0 MEMBERS OR ENDS
create or replace function public.auto_purge_empty_room_messages()
returns trigger as $$
begin
  -- If total_members drops to 0 or room status is ended, delete all room chat messages
  if (new.total_members <= 0 or new.status = 'ended') then
    delete from public.room_messages
    where room_id = new.id;
  end if;

  return new;
end;
$$ language plpgsql security definer set search_path = public;

-- Attach trigger to public.rooms on total_members or status updates
drop trigger if exists tr_auto_purge_empty_room_messages on public.rooms;
create trigger tr_auto_purge_empty_room_messages
  after update of total_members, status on public.rooms
  for each row execute function public.auto_purge_empty_room_messages();

-- 4. RPC TO MANUALLY PURGE ALL ROOM CHATS AT ANY TIME
create or replace function public.purge_all_room_chats()
returns boolean as $$
begin
  truncate table public.room_messages;
  return true;
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function public.purge_all_room_chats() to authenticated, service_role;
