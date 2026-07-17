-- ============================================================
-- 202607170001_arena_creation_system.sql
-- Arena Creation System v2
--
-- Changes:
--   1. Create arena_tickets table (admin-granted tickets consumed on Arena creation)
--   2. Create arena_creation_logs table (audit trail for every Arena creation)
--   3. Introduce create_arena() RPC supporting 3 methods:
--        'ticket'  -> consumes 1 arena_ticket atomically
--        'coins'   -> deducts 499 Gold Coins atomically
--        'level'   -> verifies user ID Level >= 15, no cost
--   4. Remove temporary room auto-delete from update_room_member_counts trigger
--      (all Arenas are permanent going forward — is_permanent = true always)
--   5. The old create_room() RPC is kept for backward compatibility but now
--      always creates permanent Arenas and delegates to create_arena().
-- ============================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- 1. arena_tickets table
--    Admin grants tickets. Users consume one per Arena creation.
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.arena_tickets (
  id             uuid default gen_random_uuid() primary key,
  user_id        uuid references public.profiles(id) on delete cascade not null,
  granted_by     uuid references public.profiles(id) on delete set null,
  reason         text,
  is_consumed    boolean default false not null,
  consumed_at    timestamp with time zone,
  granted_at     timestamp with time zone default timezone('utc'::text, now()) not null
);

create index if not exists idx_arena_tickets_user_id
  on public.arena_tickets (user_id)
  where is_consumed = false;

-- RLS
alter table public.arena_tickets enable row level security;

-- Users can see only their own tickets
create policy "Users can view their own arena tickets"
  on public.arena_tickets for select
  using (auth.uid() = user_id);

-- Only service_role / admin functions can insert (no direct client inserts)
create policy "Service role can insert arena tickets"
  on public.arena_tickets for insert
  with check (
    -- Only allow if current user is an admin (check admins table) or service role
    exists (
      select 1 from public.admins where id = auth.uid()
    )
  );

-- No client-side deletes or updates (consumed via RPC with SECURITY DEFINER)


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. arena_creation_logs table
--    Immutable audit log of every Arena created, recording the method used.
--    After creation the method has NO effect on Arena features or permissions.
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.arena_creation_logs (
  id              uuid default gen_random_uuid() primary key,
  arena_id        text references public.rooms(id) on delete cascade not null,
  user_id         uuid references public.profiles(id) on delete cascade not null,
  creation_method text not null check (creation_method in ('ticket', 'coins', 'level')),
  ticket_id       uuid references public.arena_tickets(id) on delete set null,
  coins_spent     integer default 0 not null,
  created_at      timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.arena_creation_logs enable row level security;

-- Users can view their own creation logs
create policy "Users can view their own arena creation logs"
  on public.arena_creation_logs for select
  using (auth.uid() = user_id);

-- Admins can view all
create policy "Admins can view all arena creation logs"
  on public.arena_creation_logs for select
  using (
    exists (select 1 from public.admins where id = auth.uid())
  );


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Helper: count available arena tickets for a user
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.get_arena_ticket_count(p_user_id uuid default null)
returns integer as $$
declare
  v_user_id uuid;
begin
  v_user_id := coalesce(p_user_id, auth.uid());
  if v_user_id is null then
    return 0;
  end if;
  return (
    select count(*)::integer
    from public.arena_tickets
    where user_id = v_user_id
      and is_consumed = false
  );
end;
$$ language plpgsql stable security definer;


-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Main: create_arena() RPC
--    Validates eligibility, charges the chosen method atomically, then
--    inserts a permanent Arena (is_permanent = true always).
--    The creation_method is ONLY recorded in arena_creation_logs and has
--    absolutely no effect on Arena features, permissions, or behavior.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.create_arena(
  p_name             text,
  p_username         text,
  p_description      text,
  p_category         text,
  p_country          text,
  p_language         text,
  p_tags             text[],
  p_rules            text[],
  p_entry_permission text,
  p_avatar           text,
  p_banner           text,
  p_creation_method  text  -- 'ticket' | 'coins' | 'level'
) returns text as $$
declare
  v_user_id       uuid := auth.uid();
  v_room_id       text;
  v_livekit_name  text;
  v_balance       integer;
  v_user_level    integer;
  v_ticket_id     uuid;
  v_coins_spent   integer := 0;
begin
  -- ── Authentication guard ─────────────────────────────────────────────────
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: You must be logged in to create an Arena.';
  end if;

  -- ── Validate creation method ─────────────────────────────────────────────
  if p_creation_method not in ('ticket', 'coins', 'level') then
    raise exception 'INVALID_METHOD: Creation method must be ticket, coins, or level.';
  end if;

  -- ── Normalize username ───────────────────────────────────────────────────
  if p_username is not null and p_username <> '' then
    p_username := lower(trim(p_username));
    if left(p_username, 1) <> '@' then
      p_username := '@' || p_username;
    end if;
  end if;

  -- ── Acquire advisory lock to prevent race conditions ─────────────────────
  -- Lock is scoped to this user so concurrent requests by the same user are
  -- serialized. Different users do not block each other.
  perform pg_advisory_xact_lock(('x' || substr(md5(v_user_id::text), 1, 15))::bit(60)::bigint);

  -- ── Re-check: user must not already own an active Arena ──────────────────
  if exists (
    select 1 from public.rooms
    where host_id = v_user_id
      and is_permanent = true
      and status in ('live', 'scheduled')
  ) then
    raise exception 'ARENA_LIMIT: You already own an active Arena. Only one active Arena is allowed per account.';
  end if;

  -- ── Method: TICKET ───────────────────────────────────────────────────────
  if p_creation_method = 'ticket' then
    -- Lock and claim one unconsumed ticket
    select id into v_ticket_id
    from public.arena_tickets
    where user_id = v_user_id
      and is_consumed = false
    order by granted_at asc
    limit 1
    for update skip locked;

    if v_ticket_id is null then
      raise exception 'NO_TICKET: You do not have any Arena Tickets. Earn tickets through events, competitions, or platform rewards.';
    end if;

    -- Consume the ticket
    update public.arena_tickets
    set is_consumed = true,
        consumed_at = now()
    where id = v_ticket_id;

    v_coins_spent := 0;

  -- ── Method: COINS ────────────────────────────────────────────────────────
  elsif p_creation_method = 'coins' then
    select coins_balance into v_balance
    from public.wallets
    where id = v_user_id
    for update;

    if coalesce(v_balance, 0) < 499 then
      raise exception 'INSUFFICIENT_COINS: Creating an Arena costs 499 Gold Coins. Your balance: % coins.', coalesce(v_balance, 0);
    end if;

    -- Deduct 499 Gold Coins atomically
    update public.wallets
    set coins_balance = coins_balance - 499
    where id = v_user_id;

    insert into public.wallet_transactions
      (wallet_id, amount, currency, type, status, details)
    values
      (v_user_id, 499, 'Coins', 'Withdrawal', 'Completed', 'Created permanent Arena: ' || p_name);

    v_coins_spent := 499;

  -- ── Method: LEVEL ────────────────────────────────────────────────────────
  elsif p_creation_method = 'level' then
    select level into v_user_level
    from public.profiles
    where id = v_user_id;

    if coalesce(v_user_level, 1) < 15 then
      raise exception 'LEVEL_REQUIRED: Arena creation via ID Level requires Level 15 or above. Your current level: %.', coalesce(v_user_level, 1);
    end if;

    v_coins_spent := 0;
  end if;

  -- ── Generate unique IDs ───────────────────────────────────────────────────
  v_room_id      := public.generate_unique_room_id();
  v_livekit_name := 'arena_' || encode(gen_random_bytes(8), 'hex');

  -- ── Insert the permanent Arena ────────────────────────────────────────────
  insert into public.rooms (
    id, name, username, description, category, language, tags, rules,
    host_id, status, visibility, recording_status, level_requirement,
    vip_requirement, verification_requirement, livekit_room_name,
    avatar, banner, is_permanent
  ) values (
    v_room_id,
    p_name,
    p_username,
    p_description,
    p_category,
    p_language,
    p_tags,
    p_rules,
    v_user_id,
    'live',
    p_entry_permission,
    'inactive',
    1,
    0,
    false,
    v_livekit_name,
    p_avatar,
    p_banner,
    true   -- ALL Arenas are permanent, always
  );

  -- ── Write audit log ───────────────────────────────────────────────────────
  insert into public.arena_creation_logs
    (arena_id, user_id, creation_method, ticket_id, coins_spent)
  values
    (v_room_id, v_user_id, p_creation_method, v_ticket_id, v_coins_spent);

  return v_room_id;

end;
$$ language plpgsql security definer;


-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Grant arena ticket (admin-only RPC)
--    Allows admins to grant Arena Tickets to any user.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.grant_arena_ticket(
  p_target_user_id uuid,
  p_reason         text default null
) returns uuid as $$
declare
  v_admin_id uuid := auth.uid();
  v_ticket_id uuid;
begin
  if v_admin_id is null then
    raise exception 'UNAUTHENTICATED';
  end if;

  if not exists (select 1 from public.admins where id = v_admin_id) then
    raise exception 'UNAUTHORIZED: Only administrators can grant Arena Tickets.';
  end if;

  if not exists (select 1 from public.profiles where id = p_target_user_id) then
    raise exception 'USER_NOT_FOUND: Target user does not exist.';
  end if;

  insert into public.arena_tickets (user_id, granted_by, reason)
  values (p_target_user_id, v_admin_id, p_reason)
  returning id into v_ticket_id;

  return v_ticket_id;
end;
$$ language plpgsql security definer;


-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Update update_room_member_counts trigger
--    Remove the temporary-room auto-delete branch.
--    Going forward all Arenas are permanent (is_permanent = true).
--    Permanent Arenas persist even when member count drops to zero.
-- ─────────────────────────────────────────────────────────────────────────────

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

  -- All Arenas are permanent. Never auto-delete based on member count.
  -- (Temporary room auto-delete has been removed as part of the Arena v2 migration.)
  update public.rooms
  set
    total_members   = v_count,
    total_speakers  = (select count(*) from public.room_members
                       where room_id = v_room_id
                         and role in ('Host', 'Co-Host', 'Speaker')),
    total_listeners = (select count(*) from public.room_members
                       where room_id = v_room_id
                         and role in ('Moderator', 'Listener', 'Guest')),
    peak_members    = greatest(peak_members, v_count)
  where id = v_room_id;

  return null;
end;
$$ language plpgsql security definer;


-- ─────────────────────────────────────────────────────────────────────────────
-- 7. Backward-compat shim: update old create_room() to always be permanent
--    and delegate to create_arena() using 'coins' method when p_is_permanent=true
--    or 'level' as a fallback for legacy callers that pass false.
--    This ensures no existing code breaks while we migrate the Flutter client.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.create_room(
  p_name             text,
  p_username         text,
  p_description      text,
  p_category         text,
  p_country          text,
  p_language         text,
  p_tags             text[],
  p_rules            text[],
  p_entry_permission text,
  p_avatar           text,
  p_banner           text,
  p_is_permanent     boolean
) returns text as $$
begin
  -- All rooms are now permanent Arenas.
  -- Legacy callers that requested temporary (p_is_permanent=false) are
  -- upgraded to permanent using the 'level' method (free if eligible,
  -- otherwise will surface an appropriate error to upgrade the client).
  -- Callers that already passed true use 'coins' for backward compat.
  if p_is_permanent then
    return public.create_arena(
      p_name, p_username, p_description, p_category, p_country, p_language,
      p_tags, p_rules, p_entry_permission, p_avatar, p_banner,
      'coins'
    );
  else
    return public.create_arena(
      p_name, p_username, p_description, p_category, p_country, p_language,
      p_tags, p_rules, p_entry_permission, p_avatar, p_banner,
      'level'
    );
  end if;
end;
$$ language plpgsql security definer;
