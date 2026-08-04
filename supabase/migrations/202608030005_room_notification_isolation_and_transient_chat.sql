-- Migration 202608030005_room_notification_isolation_and_transient_chat.sql
-- Room Chat, Notification Isolation, Gift Isolation & Transient Session Maintenance

-- Ensure notifications schema compatibility
alter table public.notifications add column if not exists content text;

-- 1. DROP NOTIFICATION TRIGGERS FOR ROOM MESSAGES AND GIFTS
-- Room messages, room mentions, and room gifts MUST NEVER insert rows into public.notifications
drop trigger if exists tr_handle_room_message_mentions on public.room_messages;
drop trigger if exists tr_gift_received_notifications on public.gift_transactions;
drop trigger if exists tr_gift_received_notifications on public.gift_history;
drop trigger if exists tr_room_invites_notifications on public.room_invites;

-- Replace handle_room_message_mentions to be a no-op or drop function
create or replace function public.handle_room_message_mentions()
returns trigger as $$
begin
  -- Room message mentions are session-only inside the room and generate NO database/push notifications
  return new;
end;
$$ language plpgsql security definer;

-- Replace handle_gift_received_notifications to be a no-op
create or replace function public.handle_gift_received_notifications()
returns trigger as $$
begin
  -- Gifts belong exclusively to active room sessions or direct transfers and generate NO system notifications
  return null;
end;
$$ language plpgsql security definer;

-- 2. ENSURE DIRECT MESSAGES TRIGGER (DM ONLY) DOES NOT FIRE FOR ROOM/GROUP MESSAGES
create or replace function public.handle_direct_message_notifications()
returns trigger as $$
declare
  v_sender_username text;
begin
  -- Strictly require is_private = true and a valid receiver_id (DMs only)
  if (new.is_private = true and new.receiver_id is not null and new.receiver_id <> new.sender_id) then
    select username into v_sender_username from public.profiles where id = new.sender_id;

    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.receiver_id,
      'New Message from @' || coalesce(v_sender_username, 'User'),
      substring(coalesce(new.encrypted_content, 'Sent you a private message') from 1 for 60),
      'dm',
      jsonb_build_object(
        'sender_id', new.sender_id,
        'message_id', new.id,
        'is_private', true
      )
    );
  end if;

  return new;
end;
$$ language plpgsql security definer set search_path = public;

-- Re-attach DM notification trigger cleanly on public.messages
drop trigger if exists tr_handle_direct_message_notifications on public.messages;
create trigger tr_handle_direct_message_notifications
  after insert on public.messages
  for each row execute function public.handle_direct_message_notifications();

-- 3. HEARTBEAT & STALE MEMBER CLEANUP (8-SECOND TIMEOUT)
create or replace function public.clean_stale_room_members()
returns integer as $$
declare
  v_cleaned_count integer := 0;
  r_stale record;
begin
  -- Find all room members whose last heartbeat exceeds 8 seconds
  for r_stale in
    select room_id, user_id, seat_number
    from public.room_members
    where last_seen < (now() - interval '8 seconds')
  loop
    -- Free seat if assigned
    if r_stale.seat_number is not null then
      update public.room_seats
      set user_id = null,
          is_locked = false,
          is_muted = false,
          joined_at = null
      where room_id = r_stale.room_id and seat_number = r_stale.seat_number and user_id = r_stale.user_id;
    end if;

    -- Delete stale room member entry
    delete from public.room_members
    where room_id = r_stale.room_id and user_id = r_stale.user_id;

    -- Update active profile active_room_id if matches
    update public.profiles
    set active_room_id = null
    where id = r_stale.user_id and active_room_id = r_stale.room_id;

    v_cleaned_count := v_cleaned_count + 1;
  end loop;

  -- Recalculate room member counts for affected rooms
  update public.rooms r
  set total_members = (
    select count(*) from public.room_members rm where rm.room_id = r.id
  )
  where r.status = 'live';

  return v_cleaned_count;
end;
$$ language plpgsql security definer set search_path = public;

-- 4. TRANSIENT ROOM CHAT PURGE RPC
create or replace function public.purge_room_transient_messages(p_room_id text)
returns boolean as $$
begin
  if p_room_id is null or p_room_id = '' then
    return false;
  end if;

  delete from public.room_messages
  where room_id = p_room_id;

  return true;
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function public.clean_stale_room_members() to authenticated, service_role;
grant execute on function public.purge_room_transient_messages(text) to authenticated, service_role;
