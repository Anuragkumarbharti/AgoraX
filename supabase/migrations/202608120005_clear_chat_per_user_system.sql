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
