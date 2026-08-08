-- ============================================================================
-- MIGRATION: 202608080005_30s_server_presence_grace.sql
-- DESCRIPTION: Enforce exact 30-second Server Presence Grace Period,
--              10s Heartbeat Check, and Instant Session Restoration RPC.
-- ============================================================================

-- 1. Update Production Smart Presence Cleanup Function
-- Phase 1: Heartbeat missing > 10s -> Mark as is_reconnecting = true (Grace Period)
-- Phase 2: Heartbeat missing > 30s & is_reconnecting = true -> Expire & Remove User
create or replace function public.process_presence_grace_period_and_cleanup()
returns void as $$
declare
  v_rec record;
  v_username text;
  v_has_members boolean;
  v_new_host_id uuid;
begin
  -- Phase 1: Transition users who missed 10s heartbeat into Grace Period (is_reconnecting = true)
  update public.room_members
  set is_reconnecting = true
  where last_heartbeat_at < (now() - interval '10 seconds')
    and is_reconnecting = false;

  -- Update corresponding seats during grace period
  update public.room_seats s
  set is_speaking = false,
      mic_status = 'muted',
      is_reconnecting = true
  from public.room_members m
  where s.room_id = m.room_id 
    and s.user_id = m.user_id 
    and m.is_reconnecting = true
    and s.is_reconnecting = false;

  -- Phase 2: Permanently remove users whose 30-second grace period has expired
  for v_rec in 
    select room_id, user_id, role, session_id 
    from public.room_members 
    where is_reconnecting = true 
      and last_heartbeat_at < (now() - interval '30 seconds')
  loop
    select username into v_username from public.profiles where id = v_rec.user_id;

    -- A. Free seat
    update public.room_seats
    set user_id = null,
        mic_status = 'muted',
        is_speaking = false,
        is_reconnecting = false,
        session_id = null
    where room_id = v_rec.room_id and user_id = v_rec.user_id;

    -- B. Delete requests
    delete from public.room_requests
    where room_id = v_rec.room_id and user_id = v_rec.user_id;

    -- C. Delete from room_members
    delete from public.room_members 
    where room_id = v_rec.room_id and user_id = v_rec.user_id;

    -- D. Delete heartbeats
    delete from public.room_member_heartbeats
    where room_id = v_rec.room_id and user_id = v_rec.user_id;

    -- E. Broadcast leave event (USER_LEFT)
    insert into public.room_activity_events (room_id, event_type, user_id, username, message)
    values (v_rec.room_id, 'leave', v_rec.user_id, v_username, coalesce(v_username, 'Someone') || ' left the room (30s grace period expired)');

    -- F. Host transfer check
    if exists (select 1 from public.rooms where id = v_rec.room_id and host_id = v_rec.user_id) then
      select exists(select 1 from public.room_members where room_id = v_rec.room_id) into v_has_members;

      if v_has_members then
        select user_id into v_new_host_id
        from public.room_members
        where room_id = v_rec.room_id
        order by 
          case role
            when 'Co-Host' then 1
            when 'Moderator' then 2
            when 'Speaker' then 3
            when 'Listener' then 4
            else 5
          end,
          joined_at asc
        limit 1;

        if v_new_host_id is not null then
          update public.rooms set host_id = v_new_host_id where id = v_rec.room_id;
          update public.room_members set role = 'Host' where room_id = v_rec.room_id and user_id = v_new_host_id;
          select username into v_username from public.profiles where id = v_new_host_id;

          insert into public.room_activity_events (room_id, event_type, user_id, username, message)
          values (v_rec.room_id, 'system', v_new_host_id, v_username, 'Ownership transferred to ' || coalesce(v_username, 'new host') || ' because owner disconnected.');
        end if;
      else
        if not exists (select 1 from public.rooms where id = v_rec.room_id and is_permanent = true) then
          delete from public.rooms where id = v_rec.room_id;
        end if;
      end if;
    end if;
  end loop;
end;
$$ language plpgsql security definer set search_path = public;

-- 2. Enhanced Heartbeat RPC with Instant Reconnection Restoration
create or replace function public.heartbeat_room_member(
  p_room_id text,
  p_session_id text default null,
  p_is_speaking boolean default false
) returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_was_reconnecting boolean := false;
begin
  if v_user_id is null then
    raise exception 'Unauthenticated user';
  end if;

  -- Run background cleanup
  perform public.process_presence_grace_period_and_cleanup();

  -- Verify membership
  select is_reconnecting into v_was_reconnecting
  from public.room_members
  where room_id = p_room_id and user_id = v_user_id;

  if v_was_reconnecting is null then
    return jsonb_build_object('success', false, 'reason', 'Not a member of this room');
  end if;

  -- Refresh heartbeat timestamp and restore active status
  update public.room_members
  set last_heartbeat_at = now(),
      is_reconnecting = false,
      session_id = coalesce(p_session_id, session_id)
  where room_id = p_room_id and user_id = v_user_id;

  -- Restore seat reconnecting status if user is seated
  update public.room_seats
  set is_reconnecting = false,
      is_speaking = p_is_speaking,
      session_id = coalesce(p_session_id, session_id)
  where room_id = p_room_id and user_id = v_user_id;

  -- Update session last_seen in user_sessions
  if p_session_id is not null then
    update public.user_sessions
    set last_seen = now(), online_status = 'In Room'
    where session_id = p_session_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'restored_from_grace_period', v_was_reconnecting
  );
end;
$$ language plpgsql security definer set search_path = public;
