-- supabase/migrations/202607130010_mention_notifications.sql

-- Add policy to allow anyone to insert notifications
drop policy if exists "Allow everyone to insert notifications" on public.notifications;
create policy "Allow everyone to insert notifications" on public.notifications for insert with check (true);

create or replace function public.handle_room_message_mentions()
returns trigger as $$
declare
  v_match text[];
  v_target_id uuid;
  v_sender_username text;
  v_room_name text;
begin
  -- Fetch sender's username
  select username into v_sender_username from public.profiles where id = new.sender_id;
  if v_sender_username is null then
    v_sender_username := 'Someone';
  end if;

  -- Fetch room name
  select name into v_room_name from public.rooms where id = new.room_id;
  if v_room_name is null then
    v_room_name := 'Arena Room';
  end if;

  -- Match all occurrences of @username (case-insensitive, alphanumeric and underscore)
  for v_match in select regexp_matches(new.content, '@([a-zA-Z0-9_]+)', 'g') loop
    -- Resolve target profile ID
    select id into v_target_id 
    from public.profiles 
    where lower(username) = lower(v_match[1]);

    if v_target_id is not null and v_target_id <> new.sender_id then
      -- Insert notification log
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

drop trigger if exists tr_handle_room_message_mentions on public.room_messages;
create trigger tr_handle_room_message_mentions
after insert on public.room_messages
for each row execute function public.handle_room_message_mentions();
