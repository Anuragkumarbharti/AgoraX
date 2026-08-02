-- 202607200001_chat_pipeline_hotfix.sql
-- Fixes: BUG#15 (encrypted notification preview), conversation auto-update trigger,
-- and performance indexes.

-- ══════════════════════════════════════════════════════════════
-- 1. BUG #15 FIX: Fix notification trigger — encrypted content
--    must NOT appear in push notification body. Use generic preview.
-- ══════════════════════════════════════════════════════════════

create or replace function public.handle_direct_message_notifications()
returns trigger as $$
declare
  v_sender_name text;
  v_sender_avatar text;
  v_preview text;
  v_chat_id text;
begin
  -- Only process private direct messages with a valid receiver
  if (new.receiver_id is null or new.receiver_id = new.sender_id) then
    return null;
  end if;

  -- Fetch sender profile
  select coalesce(display_name, username, 'Someone'), coalesce(avatar, '')
  into v_sender_name, v_sender_avatar
  from public.profiles
  where id = new.sender_id;

  if v_sender_name is null then
    v_sender_name := 'Creania Student';
  end if;

  -- ✅ BUG #15 FIX: Build a human-readable preview based on media_type ONLY.
  -- NEVER expose encrypted_content in notifications (it shows AES ciphertext).
  if new.media_type = 'image' then
    v_preview := '📷 Sent you a photo';
  elsif new.media_type = 'video' then
    v_preview := '🎥 Sent you a video';
  elsif new.media_type = 'audio' then
    v_preview := '🎤 Sent you a voice message';
  elsif new.media_type = 'document' or new.media_type = 'file' then
    v_preview := '📄 Sent you a document';
  elsif new.media_type = 'location' then
    v_preview := '📍 Shared a location with you';
  elsif new.media_type = 'contact' then
    v_preview := '👤 Shared a contact with you';
  elsif new.media_type = 'gift' then
    v_preview := '🎁 Sent you a gift!';
  else
    -- Text message — use a generic preview (E2EE means we can't show actual content)
    v_preview := 'Sent you a message';
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
      'senderAvatar', v_sender_avatar,
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

-- Recreate trigger
drop trigger if exists tr_handle_direct_message_notifications on public.messages;
create trigger tr_handle_direct_message_notifications
  after insert on public.messages
  for each row execute function public.handle_direct_message_notifications();

-- ══════════════════════════════════════════════════════════════
-- 2. Auto-update conversations table on every new message insert
--    This keeps last_message, last_message_time, sender consistent
--    in the database so any client or dashboard can query it.
-- ══════════════════════════════════════════════════════════════

create or replace function public.update_conversation_on_new_message()
returns trigger as $$
declare
  v_conv_id text;
  v_part_a uuid;
  v_part_b uuid;
begin
  -- Only handle private direct messages
  if new.receiver_id is null or new.receiver_id = new.sender_id then
    return new;
  end if;

  -- Determine deterministic conversation ID (smaller UUID first)
  if new.sender_id < new.receiver_id then
    v_part_a := new.sender_id;
    v_part_b := new.receiver_id;
  else
    v_part_a := new.receiver_id;
    v_part_b := new.sender_id;
  end if;

  v_conv_id := v_part_a::text || '_' || v_part_b::text;

  -- Upsert conversation metadata atomically
  insert into public.conversations (
    id,
    participant_a,
    participant_b,
    last_message,
    last_message_time,
    last_message_sender_id,
    created_at
  ) values (
    v_conv_id,
    v_part_a,
    v_part_b,
    -- Store generic preview in conversations table (not encrypted_content)
    case new.media_type
      when 'image' then '📷 Photo'
      when 'video' then '🎥 Video'
      when 'audio' then '🎤 Voice message'
      when 'document' then '📄 Document'
      when 'file' then '📄 File'
      when 'location' then '📍 Location'
      when 'contact' then '👤 Contact'
      when 'gift' then '🎁 Gift'
      else '💬 Message'
    end,
    new.created_at,
    new.sender_id,
    timezone('utc'::text, now())
  )
  on conflict (participant_a, participant_b) do update
  set
    last_message = excluded.last_message,
    last_message_time = excluded.last_message_time,
    last_message_sender_id = excluded.last_message_sender_id;

  -- Also update conversation_id on the message itself if not set
  if new.conversation_id is null or new.conversation_id = '' then
    update public.messages
    set conversation_id = v_conv_id
    where id = new.id;
  end if;

  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists tr_update_conversation_on_new_message on public.messages;
create trigger tr_update_conversation_on_new_message
  after insert on public.messages
  for each row execute function public.update_conversation_on_new_message();

-- ══════════════════════════════════════════════════════════════
-- 3. Performance Index: conversations.last_message_time
--    Needed for fast ordering of conversation lists by recency
-- ══════════════════════════════════════════════════════════════

create index if not exists idx_conversations_last_message_time
  on public.conversations (last_message_time desc);

create index if not exists idx_conversations_participant_a
  on public.conversations (participant_a, last_message_time desc);

create index if not exists idx_conversations_participant_b
  on public.conversations (participant_b, last_message_time desc);

-- ══════════════════════════════════════════════════════════════
-- 4. Performance: Add GIN index on messages for status+receiver
--    for ultra-fast unread count queries
-- ══════════════════════════════════════════════════════════════

create index if not exists idx_messages_receiver_status_created
  on public.messages (receiver_id, message_status, created_at desc);

-- ══════════════════════════════════════════════════════════════
-- 5. Ensure Realtime is enabled on conversations table
-- ══════════════════════════════════════════════════════════════

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'conversations'
    ) then
      alter publication supabase_realtime add table public.conversations;
    end if;
  end if;
exception when others then
  raise notice 'conversations realtime publication check bypassed: %', SQLERRM;
end;
$$;

-- ══════════════════════════════════════════════════════════════
-- 6. RLS policy for conversations table — ensure it exists
-- ══════════════════════════════════════════════════════════════

alter table public.conversations enable row level security;

drop policy if exists "Users can view their conversations" on public.conversations;
create policy "Users can view their conversations" on public.conversations
  for select using (auth.uid() = participant_a or auth.uid() = participant_b);

drop policy if exists "Users can insert their conversations" on public.conversations;
create policy "Users can insert their conversations" on public.conversations
  for insert with check (auth.uid() = participant_a or auth.uid() = participant_b);

drop policy if exists "Users can update their conversations" on public.conversations;
create policy "Users can update their conversations" on public.conversations
  for update using (auth.uid() = participant_a or auth.uid() = participant_b);

-- Allow service role (backend) to update conversations freely
drop policy if exists "Service role can manage conversations" on public.conversations;
create policy "Service role can manage conversations" on public.conversations
  for all using (auth.role() = 'service_role');
