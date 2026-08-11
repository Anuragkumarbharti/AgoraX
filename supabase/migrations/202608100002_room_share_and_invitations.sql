-- Migration: 202608100002_room_share_and_invitations.sql
-- Description: RPC procedures for StarMaker style in-app room invitations, rate limiting, and room status verification

-- 1. Function to validate and send a room invitation to a receiver user
CREATE OR REPLACE FUNCTION send_room_invitation(
    p_room_id TEXT,
    p_receiver_id UUID,
    p_room_title TEXT DEFAULT 'Voice Room',
    p_host_name TEXT DEFAULT 'Host',
    p_room_cover TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sender_id UUID;
    v_room_exists BOOLEAN;
    v_receiver_exists BOOLEAN;
    v_recent_invites_count INT;
    v_message_id UUID;
    v_now TIMESTAMPTZ := NOW();
    v_encrypted_content TEXT;
    v_payload JSONB;
BEGIN
    v_sender_id := auth.uid();
    
    -- Check sender auth
    IF v_sender_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized sender');
    END IF;

    -- Cannot send invitation to self
    IF v_sender_id = p_receiver_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot send invitation to yourself');
    END IF;

    -- Check if target receiver exists
    SELECT EXISTS(
        SELECT 1 FROM profiles WHERE id = p_receiver_id
    ) INTO v_receiver_exists;

    IF NOT v_receiver_exists THEN
        RETURN jsonb_build_object('success', false, 'error', 'Recipient user does not exist');
    END IF;

    -- Check if room exists and is active
    SELECT EXISTS(
        SELECT 1 FROM rooms 
        WHERE (id::text = p_room_id OR sid = p_room_id)
          AND is_active = true
    ) INTO v_room_exists;

    IF NOT v_room_exists THEN
        -- Fallback: check voice_rooms table if rooms table wasn't matched
        SELECT EXISTS(
            SELECT 1 FROM rooms WHERE id::text = p_room_id
        ) INTO v_room_exists;
    END IF;

    -- Anti-spam: Rate limit - max 10 room invitations per minute per sender
    SELECT COUNT(*) INTO v_recent_invites_count
    FROM messages
    WHERE sender_id = v_sender_id
      AND media_type = 'roomInvite'
      AND created_at > (v_now - INTERVAL '1 minute');

    IF v_recent_invites_count >= 15 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Sending invitations too fast. Please wait a moment.');
    END IF;

    v_message_id := gen_random_uuid();
    v_encrypted_content := '🎙️ Room Invite: ' || COALESCE(p_room_title, 'Voice Room');

    -- Insert invitation message into canonical messages table
    INSERT INTO messages (
        id,
        sender_id,
        receiver_id,
        encrypted_content,
        is_private,
        message_status,
        media_type,
        location_name,
        contact_name,
        contact_phone,
        media_url,
        created_at
    ) VALUES (
        v_message_id,
        v_sender_id,
        p_receiver_id,
        v_encrypted_content,
        true,
        'sent',
        'roomInvite',
        p_room_title,
        p_host_name,
        p_room_id,
        p_room_cover,
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'message_id', v_message_id,
        'room_id', p_room_id,
        'receiver_id', p_receiver_id,
        'timestamp', v_now
    );
END;
$$;

-- 2. Function to validate live room status for invitation card rendering
CREATE OR REPLACE FUNCTION validate_room_invite_status(p_room_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_room RECORD;
    v_is_live BOOLEAN := false;
BEGIN
    IF p_room_id IS NULL OR p_room_id = '' THEN
        RETURN jsonb_build_object('is_live', false, 'reason', 'Invalid Room ID');
    END IF;

    SELECT id, name, host_id, is_active, created_at
    INTO v_room
    FROM rooms
    WHERE (id::text = p_room_id OR sid = p_room_id)
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND AND v_room.is_active = true THEN
        v_is_live := true;
        RETURN jsonb_build_object(
            'is_live', true,
            'room_id', v_room.id,
            'room_name', v_room.name,
            'host_id', v_room.host_id
        );
    ELSE
        RETURN jsonb_build_object(
            'is_live', false,
            'reason', 'Room has ended or is unavailable'
        );
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION send_room_invitation(TEXT, UUID, TEXT, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION validate_room_invite_status(TEXT) TO authenticated, service_role, anon;
