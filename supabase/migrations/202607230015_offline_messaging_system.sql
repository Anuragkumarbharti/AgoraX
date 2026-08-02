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

-- Grant execution permissions on fetch_and_mark_undelivered_messages
grant execute on function public.fetch_and_mark_undelivered_messages(uuid) to authenticated;
grant execute on function public.fetch_and_mark_undelivered_messages(uuid) to service_role;

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

-- Grant execution permissions on mark_messages_read
grant execute on function public.mark_messages_read(uuid, uuid) to authenticated;
grant execute on function public.mark_messages_read(uuid, uuid) to service_role;
