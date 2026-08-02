-- 202607230010_robust_audit_logs.sql
-- Wrap the insertion into public.account_audit_logs inside an EXCEPTION block.
-- This ensures that any audit log serialization or insertion failures (e.g. JSON cast errors,
-- permission issues, search path resolver errors) do not fail the core transaction (like sign up or update).

CREATE OR REPLACE FUNCTION public.log_profile_changes()
RETURNS TRIGGER AS $$
DECLARE
  v_actor_id uuid;
BEGIN
  -- Safely extract user ID from auth session
  BEGIN
    v_actor_id := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_actor_id := null;
  END;

  -- Attempt to insert audit log without throwing exceptions to the main transaction
  BEGIN
    INSERT INTO public.account_audit_logs (
      target_table,
      operation,
      actor_id,
      record_id,
      old_data,
      new_data,
      reason
    )
    VALUES (
      TG_TABLE_NAME,
      TG_OP,
      v_actor_id,
      COALESCE(new.id, old.id),
      CASE WHEN TG_OP = 'INSERT' THEN null ELSE to_jsonb(old) END,
      CASE WHEN TG_OP = 'DELETE' THEN null ELSE to_jsonb(new) END,
      'Database automatic log for ' || TG_OP || ' on ' || TG_TABLE_NAME
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Audit log failed: %', SQLERRM;
  END;
  
  IF TG_OP = 'DELETE' THEN
    RETURN old;
  ELSE
    RETURN new;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
