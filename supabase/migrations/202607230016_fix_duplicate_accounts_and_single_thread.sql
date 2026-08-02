-- 202607230016_fix_duplicate_accounts_and_single_thread.sql
-- Single-Thread Deterministic Conversation & One User One Profile Architecture

-- 1. Ensure public.profiles ID uniqueness constraint
do $$ 
begin
  alter table public.profiles add constraint unique_profile_user_id unique (id);
exception when others then
  null;
end $$;

-- 2. Create Conversations Table with deterministic participant ordering
create table if not exists public.conversations (
  id text primary key, -- deterministic string: e.g. u1_u2 (where u1 < u2)
  participant_a uuid references public.profiles(id) on delete cascade not null,
  participant_b uuid references public.profiles(id) on delete cascade not null,
  last_message text,
  last_message_time timestamp with time zone default timezone('utc'::text, now()),
  last_message_sender_id uuid references public.profiles(id),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  constraint check_participants_order check (participant_a < participant_b),
  constraint unique_participant_pair unique (participant_a, participant_b)
);

-- 3. Ensure messages table has conversation_id column & index
alter table public.messages 
  add column if not exists conversation_id text;

create index if not exists idx_messages_conversation_id 
  on public.messages (conversation_id, created_at asc);

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

-- 7. RLS Policies for conversations table
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
