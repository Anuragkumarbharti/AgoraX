-- 202607230014_fix_realtime_instant_pipeline.sql
-- Realtime Sub-Second Message Pipeline Optimization

-- 1. Set REPLICA IDENTITY FULL on messages table for full WAL payload replication in Supabase Realtime
alter table public.messages replica identity full;

-- 2. Add media & payload columns to messages table if not present
alter table public.messages add column if not exists file_name text;
alter table public.messages add column if not exists file_size bigint;
alter table public.messages add column if not exists location_lat double precision;
alter table public.messages add column if not exists location_lng double precision;
alter table public.messages add column if not exists location_name text;
alter table public.messages add column if not exists contact_name text;
alter table public.messages add column if not exists contact_phone text;

-- 3. Update media_type constraint to support expanded types
alter table public.messages drop constraint if exists messages_media_type_check;
alter table public.messages add constraint messages_media_type_check 
  check (media_type in ('text', 'image', 'video', 'audio', 'file', 'document', 'gif', 'sticker', 'location', 'contact', 'gift'));

-- 4. High performance indexes for ultra-fast query matching
create index if not exists idx_messages_receiver_sender_created 
  on public.messages (receiver_id, sender_id, created_at desc);

create index if not exists idx_messages_unread 
  on public.messages (receiver_id, message_status) 
  where message_status != 'seen';

-- 5. Ensure messages table is published to supabase_realtime
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
    ) then
      alter publication supabase_realtime add table public.messages;
    end if;
  end if;
exception when others then
  raise notice 'Publication subscription check bypassed: %', SQLERRM;
end;
$$;

-- 6. Direct Message Realtime Notification Trigger Function
create or replace function public.handle_direct_message_notifications()
returns trigger as $$
declare
  v_sender_name text;
  v_sender_avatar text;
  v_preview text;
  v_chat_id text;
begin
  if (new.receiver_id is null or new.receiver_id = new.sender_id) then
    return null;
  end if;

  select coalesce(display_name, username, 'Someone'), avatar
  into v_sender_name, v_sender_avatar
  from public.profiles
  where id = new.sender_id;

  if (v_sender_name is null) then
    v_sender_name := 'Creania Student';
  end if;

  if (new.media_type = 'image') then
    v_preview := '📷 Photo Message';
  elsif (new.media_type = 'video') then
    v_preview := '🎥 Video Message';
  elsif (new.media_type = 'audio') then
    v_preview := '🎤 Voice Message';
  elsif (new.media_type = 'document' or new.media_type = 'file') then
    v_preview := '📄 Document Attachment';
  elsif (new.media_type = 'location') then
    v_preview := '📍 Shared Location';
  elsif (new.media_type = 'contact') then
    v_preview := '👤 Shared Contact';
  else
    v_preview := substring(new.encrypted_content from 1 for 80);
  end if;

  v_chat_id := 'conv_' || new.sender_id;

  insert into public.notifications (
    user_id,
    title,
    body,
    type,
    payload,
    is_read,
    push_dispatched
  ) values (
    new.receiver_id,
    v_sender_name,
    v_preview,
    'chat',
    jsonb_build_object(
      'userId', new.sender_id,
      'senderName', v_sender_name,
      'senderAvatar', coalesce(v_sender_avatar, ''),
      'chatId', v_chat_id,
      'messageId', new.id,
      'action', 'direct_message'
    ),
    false,
    false
  );

  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists tr_handle_direct_message_notifications on public.messages;
create trigger tr_handle_direct_message_notifications
  after insert on public.messages
  for each row execute function public.handle_direct_message_notifications();
