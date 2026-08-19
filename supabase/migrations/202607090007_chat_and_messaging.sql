-- ==========================================================================
-- Consolidated Supabase Migration Module 07: 202607090007_chat_and_messaging.sql
-- Authoritative baseline schema, functions, triggers, policies, and seeds.
-- ==========================================================================

-- Recreate trigger
drop trigger if exists tr_handle_direct_message_notifications on public.messages;

create trigger tr_handle_direct_message_notifications
  after insert on public.messages
  for each row execute function public.handle_direct_message_notifications();

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

drop policy if exists "Users can view their conversations" on public.conversations;

drop policy if exists "Users can insert their conversations" on public.conversations;

drop policy if exists "Users can update their conversations" on public.conversations;

-- Allow service role (backend) to update conversations freely
drop policy if exists "Service role can manage conversations" on public.conversations;

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

drop trigger if exists tr_handle_direct_message_notifications on public.messages;

drop policy if exists "Users can view messages" on public.messages;

drop policy if exists "Users can insert messages" on public.messages;

drop policy if exists "Users can update messages" on public.messages;

drop policy if exists "Users can delete messages" on public.messages;

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

-- 202607230015_offline_messaging_system.sql
-- Offline Messaging, Atomic Catch-Up Delivery, and Read Receipts Pipeline

-- 1. Index for fast undelivered message retrieval by receiver
create index if not exists idx_messages_undelivered_catchup 
  on public.messages (receiver_id, created_at asc) 
  where message_status = 'sent';

-- 2. Index for sender-receiver conversation read status updates
create index if not exists idx_messages_unread_by_sender
  on public.messages (receiver_id, sender_id, message_status)
  where message_status != 'seen';

-- Grant execution permissions on fetch_and_mark_undelivered_messages
grant execute on function public.fetch_and_mark_undelivered_messages(uuid) to authenticated;

grant execute on function public.fetch_and_mark_undelivered_messages(uuid) to service_role;

-- Grant execution permissions on mark_messages_read
grant execute on function public.mark_messages_read(uuid, uuid) to authenticated;

grant execute on function public.mark_messages_read(uuid, uuid) to service_role;

-- 3. Ensure messages table has conversation_id column & index
alter table public.messages 
  add column if not exists conversation_id text;

create index if not exists idx_messages_conversation_id 
  on public.messages (conversation_id, created_at asc);

-- Grant execution to authenticated & service_role
grant execute on function public.get_or_create_conversation(uuid, uuid) to authenticated;

grant execute on function public.get_or_create_conversation(uuid, uuid) to service_role;

-- 5. Data Migration: Update all existing private messages to deterministic conversation_id
update public.messages
set conversation_id = case 
  when sender_id < receiver_id then sender_id::text || '_' || receiver_id::text
  else receiver_id::text || '_' || sender_id::text
end
where receiver_id is not null 
  and sender_id <> receiver_id 
  and (conversation_id is null or conversation_id not like '%_%');

-- 6. Populate conversations table from existing private messages (excluding self-messages)
insert into public.conversations (id, participant_a, participant_b, last_message, last_message_time, last_message_sender_id)
select distinct on (c.conv_id)
  c.conv_id,
  c.part_a,
  c.part_b,
  m.encrypted_content,
  m.created_at,
  m.sender_id
from (
  select 
    case when sender_id < receiver_id then sender_id::text || '_' || receiver_id::text else receiver_id::text || '_' || sender_id::text end as conv_id,
    case when sender_id < receiver_id then sender_id else receiver_id end as part_a,
    case when sender_id < receiver_id then receiver_id else sender_id end as part_b
  from public.messages
  where receiver_id is not null and sender_id <> receiver_id
) c
join public.messages m on m.conversation_id = c.conv_id
order by c.conv_id, m.created_at desc
on conflict (participant_a, participant_b) do update
set 
  last_message = excluded.last_message,
  last_message_time = excluded.last_message_time,
  last_message_sender_id = excluded.last_message_sender_id;

CREATE INDEX IF NOT EXISTS idx_messages_sender_receiver ON messages(sender_id, receiver_id);

-- Index for fast lookup during sync
CREATE INDEX IF NOT EXISTS idx_message_tombstones_msg_id ON public.message_tombstones(message_id);

CREATE INDEX IF NOT EXISTS idx_message_tombstones_conv_id ON public.message_tombstones(conversation_id);

CREATE INDEX IF NOT EXISTS idx_message_tombstones_deleted_at ON public.message_tombstones(deleted_at);

DROP POLICY IF EXISTS "Users can read tombstones for their conversations" ON public.message_tombstones;

DROP POLICY IF EXISTS "Users can insert tombstones for own messages" ON public.message_tombstones;

DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'conversations') THEN
        -- Add participant_a & participant_b columns if missing
        IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'conversations' AND column_name = 'participant_a') THEN
            ALTER TABLE public.conversations ADD COLUMN participant_a UUID;
            ALTER TABLE public.conversations ADD COLUMN participant_b UUID;
        END IF;

        -- Enforce self-DM prohibition constraint
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_no_self_dm') THEN
            ALTER TABLE public.conversations ADD CONSTRAINT chk_no_self_dm CHECK (participant_a != participant_b);
        END IF;

        -- Enforce participant order constraint (participant_a < participant_b)
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_participant_order' OR conname = 'check_participants_order') THEN
            ALTER TABLE public.conversations ADD CONSTRAINT chk_participant_order CHECK (participant_a < participant_b);
        END IF;

        -- Add unique constraint on participant_a & participant_b
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'unique_canonical_conversation_pair' OR conname = 'unique_participant_pair') THEN
            ALTER TABLE public.conversations ADD CONSTRAINT unique_canonical_conversation_pair UNIQUE (participant_a, participant_b);
        END IF;
    END IF;
END $$;

-- 3. Add invite_id & client_message_id columns to messages table if not present
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'messages') THEN
        IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'invite_id') THEN
            ALTER TABLE public.messages ADD COLUMN invite_id TEXT;
        END IF;
        
        -- Add unique index for invite_id where invite_id is not null
        IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_messages_unique_invite_id') THEN
            CREATE UNIQUE INDEX idx_messages_unique_invite_id ON public.messages(invite_id) WHERE invite_id IS NOT NULL AND invite_id != '';
        END IF;

        IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'client_message_id') THEN
            ALTER TABLE public.messages ADD COLUMN client_message_id TEXT;
        END IF;
    END IF;
END $$;

-- 3. Extend reports & support_tickets tables for attachments & chat transcripts
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS attachment_urls text[] DEFAULT '{}';

ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS chat_transcript jsonb DEFAULT NULL;

ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS chat_transcript jsonb DEFAULT NULL;

-- Migration: 202608120005_clear_chat_per_user_system.sql
-- Description: Per-User Complete Conversation Clear System (Supabase Backend + Local State Isolation)

-- 1. Create table for tracking user cleared conversations
CREATE TABLE IF NOT EXISTS public.user_cleared_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    other_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    cleared_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT unique_user_cleared_pair UNIQUE (user_id, other_user_id)
);

ALTER TABLE public.user_cleared_conversations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own cleared conversations" ON public.user_cleared_conversations;

CREATE POLICY "Users can manage own cleared conversations"
ON public.user_cleared_conversations FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 3. Atomic RPC to fetch all undelivered messages for a user and mark them as 'delivered'
create or replace function public.fetch_and_mark_undelivered_messages(p_user_id uuid)
returns setof public.messages as $$
declare
  v_count integer;
begin
  -- Update all 'sent' messages where caller is receiver to 'delivered'
  return query
  with updated as (
    update public.messages
    set message_status = 'delivered',
        delivered_at = timezone('utc'::text, now())
    where receiver_id = p_user_id
      and message_status = 'sent'
    returning *
  )
  select * from updated order by created_at asc;
end;
$$ language plpgsql security definer set search_path = public;

-- 4. Atomic RPC to mark all unread messages from a specific sender as 'seen'
create or replace function public.mark_messages_read(p_user_id uuid, p_sender_id uuid)
returns integer as $$
declare
  v_updated_count integer;
begin
  update public.messages
  set message_status = 'seen',
      seen_at = timezone('utc'::text, now())
  where receiver_id = p_user_id
    and sender_id = p_sender_id
    and message_status != 'seen';
    
  get diagnostics v_updated_count = row_count;
  return v_updated_count;
end;
$$ language plpgsql security definer set search_path = public;

-- 4. Atomic RPC to get or create deterministic conversation between two users
create or replace function public.get_or_create_conversation(p_user1 uuid, p_user2 uuid)
returns jsonb as $$
declare
  v_part_a uuid;
  v_part_b uuid;
  v_conv_id text;
  v_conv record;
begin
  if p_user1 = p_user2 then
    return null;
  end if;

  if p_user1 < p_user2 then
    v_part_a := p_user1;
    v_part_b := p_user2;
  else
    v_part_a := p_user2;
    v_part_b := p_user1;
  end if;

  v_conv_id := v_part_a::text || '_' || v_part_b::text;

  insert into public.conversations (id, participant_a, participant_b, created_at)
  values (v_conv_id, v_part_a, v_part_b, timezone('utc'::text, now()))
  on conflict (participant_a, participant_b) do update
  set last_message_time = coalesce(public.conversations.last_message_time, excluded.created_at)
  returning * into v_conv;

  return to_jsonb(v_conv);
end;
$$ language plpgsql security definer set search_path = public;

-- 4. RPC: Count true pending message requests between user pair
CREATE OR REPLACE FUNCTION public.get_pending_message_request_count(
    p_user_id UUID,
    p_other_user_id UUID
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count INTEGER := 0;
    v_is_follower BOOLEAN := FALSE;
    v_is_following BOOLEAN := FALSE;
    v_has_replied BOOLEAN := FALSE;
BEGIN
    -- Check mutual follow state if followers table exists
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'followers') THEN
        SELECT EXISTS (
            SELECT 1 FROM public.followers 
            WHERE follower_id = p_other_user_id AND following_id = p_user_id
        ) INTO v_is_follower;

        SELECT EXISTS (
            SELECT 1 FROM public.followers 
            WHERE follower_id = p_user_id AND following_id = p_other_user_id
        ) INTO v_is_following;

        IF v_is_follower AND v_is_following THEN
            RETURN 0; -- Mutual followers have unlimited messaging
        END IF;
    END IF;

    -- Check if recipient has replied
    SELECT EXISTS (
        SELECT 1 FROM public.messages
        WHERE sender_id = p_other_user_id AND receiver_id = p_user_id
        LIMIT 1
    ) INTO v_has_replied;

    IF v_has_replied THEN
        RETURN 0;
    END IF;

    -- Count unaccepted messages sent by p_user_id to p_other_user_id
    SELECT COUNT(*)::INTEGER INTO v_count
    FROM public.messages
    WHERE sender_id = p_user_id 
      AND receiver_id = p_other_user_id;

    RETURN v_count;
END;
$$;

-- 2. RPC: Clear Conversation for Current User
CREATE OR REPLACE FUNCTION public.clear_user_conversation(p_other_user_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  -- A. Insert or update user_cleared_conversations timestamp for strict isolation
  INSERT INTO public.user_cleared_conversations (user_id, other_user_id, cleared_at)
  VALUES (v_user_id, p_other_user_id, v_now)
  ON CONFLICT (user_id, other_user_id) 
  DO UPDATE SET cleared_at = EXCLUDED.cleared_at;

  -- B. Hard delete outgoing messages sent by current user to target recipient
  DELETE FROM public.messages
  WHERE sender_id = v_user_id AND receiver_id = p_other_user_id;

  -- C. Insert tombstones for tracking deleted message UUIDs
  INSERT INTO public.message_tombstones (message_id, conversation_id, deleted_by, deletion_type)
  SELECT id::text, COALESCE(conversation_id, 'conv_' || LEAST(sender_id, receiver_id)::text || '_' || GREATEST(sender_id, receiver_id)::text), v_user_id, 'HARD_DELETE'
  FROM public.messages
  WHERE (sender_id = v_user_id AND receiver_id = p_other_user_id)
     OR (sender_id = p_other_user_id AND receiver_id = v_user_id)
  ON CONFLICT (message_id) DO NOTHING;

  RETURN jsonb_build_object('success', true, 'cleared_at', v_now);
END;
$$;

