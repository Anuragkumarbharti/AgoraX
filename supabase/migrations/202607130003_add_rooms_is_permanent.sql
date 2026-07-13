-- supabase/migrations/202607130003_add_rooms_is_permanent.sql

-- 1. Add is_permanent column to rooms table
alter table public.rooms add column if not exists is_permanent boolean default false not null;

-- 2. Re-create update_room_member_counts to auto-delete temporary rooms when empty
create or replace function public.update_room_member_counts()
returns trigger as $$
declare
  v_room_id text;
  v_count integer;
begin
  if tg_op = 'INSERT' or tg_op = 'UPDATE' then
    v_room_id := new.room_id;
  else
    v_room_id := old.room_id;
  end if;

  v_count := (select count(*) from public.room_members where room_id = v_room_id);

  -- If it's a temporary room and member count is 0, delete it
  if v_count = 0 and exists (select 1 from public.rooms where id = v_room_id and is_permanent = false) then
    delete from public.rooms where id = v_room_id;
  else
    update public.rooms
    set 
      total_members = v_count,
      total_speakers = (select count(*) from public.room_members where room_id = v_room_id and role in ('Host', 'Co-Host', 'Speaker')),
      total_listeners = (select count(*) from public.room_members where room_id = v_room_id and role in ('Moderator', 'Listener', 'Guest')),
      peak_members = greatest(peak_members, v_count)
    where id = v_room_id;
  end if;

  return null;
end;
$$ language plpgsql security definer;

-- 3. Re-create create_room RPC function to enforce 1 active permanent room limit (no limit for temporary rooms)
create or replace function public.create_room(
  p_name text,
  p_username text,
  p_description text,
  p_category text,
  p_language text,
  p_tags text[],
  p_rules text[],
  p_entry_permission text,
  p_avatar text,
  p_banner text,
  p_is_permanent boolean
) returns text as $$
declare
  v_user_id uuid := auth.uid();
  v_room_id text;
  v_room_name text;
  v_balance integer;
begin
  if v_user_id is null then
    raise exception 'Unauthenticated';
  end if;

  -- Ensure wallet exists
  insert into public.wallets (id, coins_balance, inr_balance, withdrawable_balance)
  values (v_user_id, 0, 0.00, 0.00)
  on conflict (id) do nothing;

  -- Limit to 1 active permanent room owned by a user
  if p_is_permanent and exists (
    select 1 from public.rooms 
    where host_id = v_user_id 
      and is_permanent = true 
      and status in ('live', 'scheduled')
  ) then
    raise exception 'You can only own one active permanent voice room at a time';
  end if;

  if p_is_permanent then
    select coins_balance into v_balance from public.wallets where id = v_user_id;
    if coalesce(v_balance, 0) < 599 then
      raise exception 'Insufficient balance: permanent rooms cost 599 gold coins';
    end if;

    -- Deduct balance
    update public.wallets set coins_balance = coins_balance - 599 where id = v_user_id;

    -- Transaction log
    insert into public.wallet_transactions (wallet_id, amount, transaction_type, details)
    values (v_user_id, -599, 'Purchase', 'Unlocked permanent voice room');
  end if;

  -- Generate readable ID (e.g. CRN-RM-8F4K2X)
  v_room_id := public.generate_unique_room_id();

  -- Unique name for LiveKit signaling
  v_room_name := 'room_' || encode(gen_random_bytes(6), 'hex');

  insert into public.rooms (
    id, name, username, description, category, language, tags, rules, host_id, status,
    visibility, recording_status, level_requirement, vip_requirement,
    verification_requirement, livekit_room_name, avatar, banner, is_permanent
  ) values (
    v_room_id, p_name, p_username, p_description, p_category, p_language, p_tags, p_rules, v_user_id, 'live',
    p_entry_permission, 'inactive', 1, 0, false, v_room_name, p_avatar, p_banner, p_is_permanent
  );

  return v_room_id;
end;
$$ language plpgsql security definer;
