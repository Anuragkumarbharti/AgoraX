-- ============================================================================
-- MIGRATION: 202608120005_auto_leave_seat_on_member_exit.sql
-- DESCRIPTION: Automatic Seat Release Engine on Room Member Exit.
--              Ensures anyone who leaves room_members is immediately removed
--              from room_seats via DB Trigger and presence grace cleanup.
-- ============================================================================

-- 1. Trigger Function: Automatically clear seat when user is deleted from room_members
CREATE OR REPLACE FUNCTION public.auto_leave_seat_on_member_exit()
RETURNS TRIGGER AS $$
BEGIN
  -- Reset occupied seat for the user who left room_members
  UPDATE public.room_seats
  SET user_id = NULL,
      mic_status = 'muted',
      is_speaking = FALSE,
      is_reconnecting = FALSE,
      session_id = NULL
  WHERE room_id = OLD.room_id AND user_id = OLD.user_id;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS trg_auto_leave_seat_on_member_exit ON public.room_members;

CREATE TRIGGER trg_auto_leave_seat_on_member_exit
  AFTER DELETE ON public.room_members
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_leave_seat_on_member_exit();

-- 2. Enhanced Presence Grace Period & Orphan Cleanup Function
CREATE OR REPLACE FUNCTION public.process_presence_grace_period_and_cleanup()
RETURNS void AS $$
DECLARE
  v_rec record;
  v_username text;
  v_has_members boolean;
  v_new_host_id uuid;
BEGIN
  -- Phase 1: Transition users who missed 10s heartbeat into Grace Period (is_reconnecting = true)
  UPDATE public.room_members
  SET is_reconnecting = TRUE
  WHERE last_heartbeat_at < (now() - interval '10 seconds')
    AND is_reconnecting = FALSE;

  -- Update corresponding seats during grace period
  UPDATE public.room_seats s
  SET is_speaking = FALSE,
      mic_status = 'muted',
      is_reconnecting = TRUE
  FROM public.room_members m
  WHERE s.room_id = m.room_id 
    AND s.user_id = m.user_id 
    AND m.is_reconnecting = TRUE
    AND s.is_reconnecting = FALSE;

  -- Phase 2: Permanently remove users whose 30-second grace period has expired
  FOR v_rec IN 
    SELECT room_id, user_id, role, session_id 
    FROM public.room_members 
    WHERE is_reconnecting = TRUE 
      AND last_heartbeat_at < (now() - interval '30 seconds')
  LOOP
    SELECT username INTO v_username FROM public.profiles WHERE id = v_rec.user_id;

    -- A. Free seat
    UPDATE public.room_seats
    SET user_id = NULL,
        mic_status = 'muted',
        is_speaking = FALSE,
        is_reconnecting = FALSE,
        session_id = NULL
    WHERE room_id = v_rec.room_id AND user_id = v_rec.user_id;

    -- B. Delete requests
    DELETE FROM public.room_requests
    WHERE room_id = v_rec.room_id AND user_id = v_rec.user_id;

    -- C. Delete from room_members
    DELETE FROM public.room_members 
    WHERE room_id = v_rec.room_id AND user_id = v_rec.user_id;

    -- D. Delete heartbeats
    DELETE FROM public.room_member_heartbeats
    WHERE room_id = v_rec.room_id AND user_id = v_rec.user_id;

    -- E. Broadcast leave event
    INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
    VALUES (v_rec.room_id, 'leave', v_rec.user_id, v_username, COALESCE(v_username, 'Someone') || ' left the room (grace period expired)');

    -- F. Host transfer check
    IF EXISTS (SELECT 1 FROM public.rooms WHERE id = v_rec.room_id AND host_id = v_rec.user_id) THEN
      SELECT EXISTS(SELECT 1 FROM public.room_members WHERE room_id = v_rec.room_id) INTO v_has_members;

      IF v_has_members THEN
        SELECT user_id INTO v_new_host_id
        FROM public.room_members
        WHERE room_id = v_rec.room_id
        ORDER BY 
          CASE role
            WHEN 'Co-Host' THEN 1
            WHEN 'Moderator' THEN 2
            WHEN 'Speaker' THEN 3
            WHEN 'Listener' THEN 4
            ELSE 5
          END,
          joined_at ASC
        LIMIT 1;

        IF v_new_host_id IS NOT NULL THEN
          UPDATE public.rooms SET host_id = v_new_host_id WHERE id = v_rec.room_id;
          UPDATE public.room_members SET role = 'Host' WHERE room_id = v_rec.room_id AND user_id = v_new_host_id;
          SELECT username INTO v_username FROM public.profiles WHERE id = v_new_host_id;

          INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
          VALUES (v_rec.room_id, 'system', v_new_host_id, v_username, 'Ownership transferred to ' || COALESCE(v_username, 'new host') || ' because owner disconnected.');
        END IF;
      ELSE
        IF NOT EXISTS (SELECT 1 FROM public.rooms WHERE id = v_rec.room_id AND is_permanent = TRUE) THEN
          DELETE FROM public.rooms WHERE id = v_rec.room_id;
        END IF;
      END IF;
    END IF;
  END LOOP;

  -- Phase 3: Clean up any orphaned seats (seats where user_id is not null but user is missing from room_members)
  UPDATE public.room_seats s
  SET user_id = NULL,
      mic_status = 'muted',
      is_speaking = FALSE,
      is_reconnecting = FALSE,
      session_id = NULL
  WHERE s.user_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.room_members m
      WHERE m.room_id = s.room_id AND m.user_id = s.user_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
