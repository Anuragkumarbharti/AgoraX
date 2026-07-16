-- 202607090011_messaging_and_notifications.sql
-- Private messaging (E2EE), push notification logs, mention triggers, and RLS policies

create table public.messages (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  receiver_id uuid references public.profiles(id) on delete cascade,
  room_id uuid,
  encrypted_content text not null,
  nonce text,
  is_private boolean default false,
  message_status text default 'sent' check (message_status in ('sent', 'delivered', 'seen')),
  delivered_at timestamp with time zone,
  seen_at timestamp with time zone,
  reply_to uuid references public.messages(id) on delete set null,
  edited_at timestamp with time zone,
  deleted_for_me uuid[] default '{}',
  deleted_for_everyone boolean default false,
  expires_at timestamp with time zone,
  media_type text default 'text' check (media_type in ('text', 'image', 'video', 'audio', 'document')),
  media_url text,
  thumbnail text,
  reactions jsonb default '[]'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.notifications (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  title text not null,
  body text not null,
  type text not null,
  is_read boolean default false,
  payload jsonb default '{}'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Triggers
create or replace function public.handle_room_message_mentions()
returns trigger as $$
declare
  v_match text[];
  v_target_id uuid;
  v_sender_username text;
  v_room_name text;
begin
  select username into v_sender_username from public.profiles where id = new.sender_id;
  if v_sender_username is null then
    v_sender_username := 'Someone';
  end if;

  select name into v_room_name from public.rooms where id = new.room_id;
  if v_room_name is null then
    v_room_name := 'Arena Room';
  end if;

  for v_match in select regexp_matches(new.content, '@([a-zA-Z0-9_]+)', 'g') loop
    select id into v_target_id 
    from public.profiles 
    where lower(username) = lower(v_match[1]);

    if v_target_id is not null and v_target_id <> new.sender_id then
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        v_target_id,
        'Mentioned in ' || v_room_name,
        v_sender_username || ' mentioned you: "' || substring(new.content from 1 for 60) || '"',
        'mention',
        jsonb_build_object(
          'room_id', new.room_id,
          'message_id', new.id,
          'sender_id', new.sender_id,
          'sender_username', v_sender_username
        )
      );
    end if;
  end loop;

  return new;
end;
$$ language plpgsql security definer;

create trigger tr_handle_room_message_mentions
after insert on public.room_messages
for each row execute function public.handle_room_message_mentions();

-- Row Level Security (RLS) Policies
alter table public.messages enable row level security;
create policy "Users can view messages" on public.messages for select using (
  not is_private or auth.uid() = sender_id or auth.uid() = receiver_id
);
create policy "Users can insert messages" on public.messages for insert with check (auth.uid() = sender_id);

alter table public.notifications enable row level security;
create policy "Users can view their notifications" on public.notifications for select using (auth.uid() = user_id);
create policy "Allow everyone to insert notifications" on public.notifications for insert with check (true);
