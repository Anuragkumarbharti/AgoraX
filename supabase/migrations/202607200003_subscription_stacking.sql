-- 202607200003_subscription_stacking.sql
-- Adds server-side subscription stacking for VIP and Novel memberships.

create or replace function public.purchase_vip_subscription(
  p_user_id   uuid,
  p_level     int,
  p_days      int
)
returns timestamptz
language plpgsql
security definer
as $$
declare
  v_current_expiry timestamptz;
  v_base           timestamptz;
  v_new_expiry     timestamptz;
begin
  select vip_expiry into v_current_expiry from profiles where id = p_user_id;
  if v_current_expiry is not null and v_current_expiry > now() then
    v_base := v_current_expiry;
  else
    v_base := now();
  end if;
  v_new_expiry := v_base + (p_days || ' days')::interval;
  update profiles set vip_level = p_level, vip_expiry = v_new_expiry, updated_at = now() where id = p_user_id;
  return v_new_expiry;
end;
$$;

grant execute on function public.purchase_vip_subscription(uuid, int, int) to authenticated;

create or replace function public.purchase_novel_subscription(
  p_user_id   uuid,
  p_level     int,
  p_days      int
)
returns timestamptz
language plpgsql
security definer
as $$
declare
  v_current_expiry timestamptz;
  v_base           timestamptz;
  v_new_expiry     timestamptz;
begin
  select novel_expiry into v_current_expiry from profiles where id = p_user_id;
  if v_current_expiry is not null and v_current_expiry > now() then
    v_base := v_current_expiry;
  else
    v_base := now();
  end if;
  v_new_expiry := v_base + (p_days || ' days')::interval;
  update profiles set novel_level = p_level, novel_expiry = v_new_expiry, updated_at = now() where id = p_user_id;
  return v_new_expiry;
end;
$$;

grant execute on function public.purchase_novel_subscription(uuid, int, int) to authenticated;
