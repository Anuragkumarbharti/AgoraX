-- 202608110008_user_block_unfollow_and_advanced_reports.sql
-- User Block side-effects (auto-unfollow/unfriend) and Advanced Reports with file/chat attachments

-- 1. Enhanced RPC: Block User with Automatic Social Connection Removal (Unfollow / Unfriend)
CREATE OR REPLACE FUNCTION public.block_user(p_blocked_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_blocker_id uuid := auth.uid();
BEGIN
  IF v_blocker_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  IF v_blocker_id = p_blocked_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot block yourself');
  END IF;

  -- 1. Insert into user_blocks table
  INSERT INTO public.user_blocks (blocker_id, blocked_id)
  VALUES (v_blocker_id, p_blocked_id)
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

  -- 2. Remove mutual follow & friend relationships on profiles
  -- Decrement followers/following counts if greater than 0
  UPDATE public.profiles
  SET 
    following_count = GREATEST(0, COALESCE(following_count, 0) - 1),
    friends_count = GREATEST(0, COALESCE(friends_count, 0) - 1)
  WHERE id = v_blocker_id;

  UPDATE public.profiles
  SET 
    followers_count = GREATEST(0, COALESCE(followers_count, 0) - 1),
    friends_count = GREATEST(0, COALESCE(friends_count, 0) - 1)
  WHERE id = p_blocked_id;

  -- 3. If community_members table exists, cleanup any direct follows
  BEGIN
    DELETE FROM public.user_followers
    WHERE (follower_id = v_blocker_id AND following_id = p_blocked_id)
       OR (follower_id = p_blocked_id AND following_id = v_blocker_id);
  EXCEPTION WHEN undefined_table THEN
    -- Ignore if table does not exist
  END;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- 2. RPC: Check Bidirectional User Block Status
CREATE OR REPLACE FUNCTION public.is_user_blocked(p_user1_id uuid, p_user2_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_exists boolean := false;
BEGIN
  IF p_user1_id IS NULL OR p_user2_id IS NULL THEN
    RETURN false;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.user_blocks
    WHERE (blocker_id = p_user1_id AND blocked_id = p_user2_id)
       OR (blocker_id = p_user2_id AND blocked_id = p_user1_id)
  ) INTO v_exists;

  RETURN v_exists;
END;
$$;

-- 3. Extend reports & support_tickets tables for attachments & chat transcripts
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS attachment_urls text[] DEFAULT '{}';
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS chat_transcript jsonb DEFAULT NULL;

ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS attachment_urls text[] DEFAULT '{}';
ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS chat_transcript jsonb DEFAULT NULL;

-- 4. Create storage bucket for report attachments if not exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('report-attachments', 'report-attachments', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage policies for report-attachments
CREATE POLICY "Allow public read access to report attachments"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'report-attachments');

CREATE POLICY "Allow authenticated users to upload report attachments"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'report-attachments' AND auth.role() = 'authenticated');
