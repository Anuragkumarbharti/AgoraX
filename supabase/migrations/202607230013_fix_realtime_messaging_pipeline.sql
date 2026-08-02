-- 202607230013_fix_realtime_messaging_pipeline.sql
-- Realtime Chat & Message Delivery backend pipeline fix

-- 1. Enable Realtime Replication for messages table
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
  raise notice 'Table messages subscription check bypassed: %', SQLERRM;
end;
$$;

-- 2. Performance Indexes for Messaging
create index if not exists idx_messages_sender_receiver on public.messages (sender_id, receiver_id);
create index if not exists idx_messages_receiver_id on public.messages (receiver_id);
create index if not exists idx_messages_created_at on public.messages (created_at desc);
create index if not exists idx_messages_status on public.messages (message_status);

-- 3. Automatic Direct Message Notification Trigger
create or replace function public.handle_direct_message_notifications()
returns trigger as $$
declare
  v_sender_name text;
  v_sender_avatar text;
  v_preview text;
  v_chat_id text;
begin
  -- Only trigger for private/direct messages with a valid receiver
  if (new.receiver_id is null or new.receiver_id = new.sender_id) then
    return null;
  end if;

  -- Fetch sender details
  select coalesce(display_name, username, 'Someone'), avatar
  into v_sender_name, v_sender_avatar
  from public.profiles
  where id = new.sender_id;

  if (v_sender_name is null) then
    v_sender_name := 'Creania Student';
  end if;

  -- Format message body preview
  if (new.media_type is not null and new.media_type <> 'text') then
    v_preview := '📷 Media Attachment';
  else
    v_preview := substring(new.encrypted_content from 1 for 80);
  end if;

  v_chat_id := 'conv_' || new.sender_id;

  -- Insert notification row for receiver
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

-- 4. RLS Security Policies on messages table
alter table public.messages enable row level security;

drop policy if exists "Users can view messages" on public.messages;
drop policy if exists "Users can insert messages" on public.messages;
drop policy if exists "Users can update messages" on public.messages;
drop policy if exists "Users can delete messages" on public.messages;

create policy "Users can view messages" on public.messages 
  for select using (
    not is_private or auth.uid() = sender_id or auth.uid() = receiver_id
  );

create policy "Users can insert messages" on public.messages 
  for insert with check (
    auth.uid() = sender_id
  );

create policy "Users can update messages" on public.messages 
  for update using (
    auth.uid() = sender_id or auth.uid() = receiver_id
  ) with check (
    auth.uid() = sender_id or auth.uid() = receiver_id
  );

create policy "Users can delete messages" on public.messages 
  for delete using (
    auth.uid() = sender_id
  );
