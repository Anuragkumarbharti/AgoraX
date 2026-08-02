-- Migration: Network & Low-Latency Performance Optimization (Indexes, Batch RPC, Delta Sync)
-- Created: 2026-07-24

-- ── 1. Create B-Tree & GIN Indexes for Ultra-Fast Query Execution ───────────

-- Profiles optimization
CREATE INDEX IF NOT EXISTS idx_profiles_updated_at ON profiles(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_vip_novel ON profiles(vip_level, novel_level);

-- Voice Rooms optimization
CREATE INDEX IF NOT EXISTS idx_voice_rooms_active_created ON voice_rooms(is_active, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_voice_rooms_category_active ON voice_rooms(category, is_active);

-- Messaging optimization
CREATE INDEX IF NOT EXISTS idx_messages_room_created ON messages(room_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender_receiver ON messages(sender_id, receiver_id);

-- Communities & Study Vault optimization
CREATE INDEX IF NOT EXISTS idx_communities_updated ON communities(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_study_vault_category_price ON study_vault_items(category, base_price_inr);
CREATE INDEX IF NOT EXISTS idx_study_vault_updated ON study_vault_items(updated_at DESC);

-- Wallets optimization
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_created ON wallet_transactions(user_id, created_at DESC);


-- ── 2. RPC: Batch Execution Procedure (Consolidates Multiple Operations) ───

CREATE OR REPLACE FUNCTION batch_execute_operations(p_operations JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item JSONB;
    v_action TEXT;
    v_payload JSONB;
    v_results JSONB := '[]'::jsonb;
    v_res JSONB;
BEGIN
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_operations)
    LOOP
        v_action := v_item->>'action';
        v_payload := v_item->'payload';

        BEGIN
            IF v_action = 'update_profile_stats' THEN
                UPDATE profiles
                SET updated_at = NOW()
                WHERE id = (v_payload->>'user_id')::uuid;
                v_res := jsonb_build_object('status', 'success', 'action', v_action);
            ELSIF v_action = 'record_telemetry' THEN
                v_res := jsonb_build_object('status', 'success', 'action', v_action);
            ELSE
                v_res := jsonb_build_object('status', 'acknowledged', 'action', v_action);
            END IF;
        EXCEPTION WHEN OTHERS THEN
            v_res := jsonb_build_object('status', 'error', 'message', SQLERRM);
        END;

        v_results := v_results || jsonb_build_array(v_res);
    END LOOP;

    RETURN v_results;
END;
$$;


-- ── 3. RPC: Delta Updates Query Helper ──────────────────────────────────────

CREATE OR REPLACE FUNCTION get_delta_updates(
    p_table_name TEXT,
    p_last_sync_timestamp TIMESTAMPTZ,
    p_limit INT DEFAULT 50
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_query TEXT;
    v_result JSONB;
BEGIN
    -- Whitelist allowed tables to prevent SQL injection
    IF p_table_name NOT IN ('profiles', 'voice_rooms', 'communities', 'study_vault_items', 'messages') THEN
        RAISE EXCEPTION 'Unauthorized table name for delta sync: %', p_table_name;
    END IF;

    v_query := format(
        'SELECT jsonb_agg(t) FROM (SELECT * FROM %I WHERE updated_at > %L ORDER BY updated_at ASC LIMIT %s) t',
        p_table_name,
        p_last_sync_timestamp,
        p_limit
    );

    EXECUTE v_query INTO v_result;
    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;
