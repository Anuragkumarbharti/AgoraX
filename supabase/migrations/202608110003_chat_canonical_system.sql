-- Migration: Canonical Chat System & Unique Pair Constraints
-- Date: 2026-08-11
-- Author: Creania Engineering Team

-- 1. Create message_tombstones table for soft delete synchronization
CREATE TABLE IF NOT EXISTS public.message_tombstones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id TEXT NOT NULL UNIQUE,
    conversation_id TEXT NOT NULL,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    deleted_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deletion_type TEXT NOT NULL DEFAULT 'SOFT_DELETE' CHECK (deletion_type IN ('SOFT_DELETE', 'HARD_DELETE', 'ADMIN_PURGE'))
);

-- Index for fast lookup during sync
CREATE INDEX IF NOT EXISTS idx_message_tombstones_msg_id ON public.message_tombstones(message_id);
CREATE INDEX IF NOT EXISTS idx_message_tombstones_conv_id ON public.message_tombstones(conversation_id);
CREATE INDEX IF NOT EXISTS idx_message_tombstones_deleted_at ON public.message_tombstones(deleted_at);

-- RLS policies for message_tombstones
ALTER TABLE public.message_tombstones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read tombstones for their conversations" ON public.message_tombstones;
CREATE POLICY "Users can read tombstones for their conversations"
ON public.message_tombstones FOR SELECT
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Users can insert tombstones for own messages" ON public.message_tombstones;
CREATE POLICY "Users can insert tombstones for own messages"
ON public.message_tombstones FOR INSERT
WITH CHECK (auth.uid() = deleted_by);

-- 2. Create or ensure canonical conversations table with ordered participant constraints
CREATE TABLE IF NOT EXISTS public.conversations (
    id TEXT PRIMARY KEY,
    participant_a UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    participant_b UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    last_message TEXT,
    last_message_time TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    last_message_sender_id UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT check_participants_order CHECK (participant_a < participant_b),
    CONSTRAINT unique_participant_pair UNIQUE (participant_a, participant_b)
);

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
