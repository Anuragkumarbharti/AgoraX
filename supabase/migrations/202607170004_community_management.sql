-- 202607170004_community_management.sql
-- StarMaker-inspired Community Management, Roles, Permissions, Events, Announcements, Logs, and Administration system migrations

-- 1. Create announcements table
create table if not exists public.community_announcements (
  id uuid primary key default gen_random_uuid(),
  community_id text references public.communities(id) on delete cascade not null,
  title text not null,
  content text not null,
  is_pinned boolean default false not null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

-- Indexing for quick retrieval
create index if not exists idx_comm_announcements_comm on public.community_announcements(community_id);

-- Enable RLS
alter table public.community_announcements enable row level security;
create policy "Allow read announcements to everyone" on public.community_announcements for select using (true);
create policy "Allow service_role full control on announcements" on public.community_announcements for all using (true);

-- 2. Create community events table
create table if not exists public.community_events (
  id uuid primary key default gen_random_uuid(),
  community_id text references public.communities(id) on delete cascade not null,
  name text not null,
  banner text,
  description text,
  start_time timestamp with time zone not null,
  end_time timestamp with time zone not null,
  host_id uuid references public.profiles(id) on delete set null,
  co_hosts uuid[] default '{}' not null,
  max_participants integer default 0,
  rewards text,
  rules text,
  status text not null default 'upcoming' check (status in ('upcoming', 'live', 'completed', 'cancelled')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamp with time zone default now() not null
);

-- Indexing
create index if not exists idx_comm_events_comm on public.community_events(community_id);

-- Enable RLS
alter table public.community_events enable row level security;
create policy "Allow read events to everyone" on public.community_events for select using (true);
create policy "Allow service_role full control on events" on public.community_events for all using (true);

-- 3. Create community event participants table
create table if not exists public.community_event_participants (
  event_id uuid references public.community_events(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  registered_at timestamp with time zone default now() not null,
  primary key (event_id, user_id)
);

-- Enable RLS
alter table public.community_event_participants enable row level security;
create policy "Allow read participants to everyone" on public.community_event_participants for select using (true);
create policy "Allow service_role full control on participants" on public.community_event_participants for all using (true);

-- 4. Create community logs table
create table if not exists public.community_logs (
  id uuid primary key default gen_random_uuid(),
  community_id text references public.communities(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete set null,
  action_type text not null,
  description text not null,
  created_at timestamp with time zone default now() not null
);

-- Indexing
create index if not exists idx_comm_logs_comm on public.community_logs(community_id);

-- Enable RLS
alter table public.community_logs enable row level security;
create policy "Allow read logs to managers" on public.community_logs for select
  using (
    exists (
      select 1 from public.community_memberships
      where community_id = community_logs.community_id
        and user_id = auth.uid()
        and role in ('owner', 'co_owner', 'admin')
    )
  );
create policy "Allow service_role full control on logs" on public.community_logs for all using (true);

-- 5. Permission Checking Helper Function
create or replace function public.check_community_permission(
  p_community_id text,
  p_user_id uuid,
  p_action text
)
returns boolean as $$
declare
  v_role text;
begin
  select role into v_role 
  from public.community_memberships 
  where community_id = p_community_id and user_id = p_user_id;

  if v_role is null then
    return false;
  end if;

  -- Owner can perform any action
  if v_role = 'owner' then
    return true;
  end if;

  -- Co-Owner permissions
  if v_role = 'co_owner' then
    return p_action in (
      'edit_settings',
      'manage_announcements',
      'manage_events',
      'invite_members',
      'remove_members',
      'view_logs',
      'view_analytics'
    );
  end if;

  -- Admin permissions
  if v_role = 'admin' then
    return p_action in (
      'manage_events',
      'invite_members',
      'remove_members',
      'view_members'
    );
  end if;

  -- Member permissions
  if v_role = 'member' then
    return p_action in (
      'participate_events',
      'chat'
    );
  end if;

  return false;
end;
$$ language plpgsql security definer;

-- 6. Announcements management RPCs
create or replace function public.create_announcement_rpc(
  p_community_id text,
  p_title text,
  p_content text,
  p_is_pinned boolean
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  if not public.check_community_permission(p_community_id, v_user_id, 'manage_announcements') then
    return jsonb_build_object('success', false, 'error', 'Unauthorized to manage announcements.');
  end if;

  -- Insert announcement
  insert into public.community_announcements (community_id, title, content, is_pinned, created_by)
  values (p_community_id, p_title, p_content, p_is_pinned, v_user_id);

  -- Log action
  insert into public.community_logs (community_id, user_id, action_type, description)
  values (p_community_id, v_user_id, 'announcement_created', 'Announcement created: ' || p_title);

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

create or replace function public.delete_announcement_rpc(
  p_community_id text,
  p_announcement_id uuid
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  if not public.check_community_permission(p_community_id, v_user_id, 'manage_announcements') then
    return jsonb_build_object('success', false, 'error', 'Unauthorized to manage announcements.');
  end if;

  delete from public.community_announcements 
  where community_id = p_community_id and id = p_announcement_id;

  -- Log action
  insert into public.community_logs (community_id, user_id, action_type, description)
  values (p_community_id, v_user_id, 'announcement_deleted', 'Announcement deleted.');

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

create or replace function public.pin_announcement_rpc(
  p_community_id text,
  p_announcement_id uuid,
  p_is_pinned boolean
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  if not public.check_community_permission(p_community_id, v_user_id, 'manage_announcements') then
    return jsonb_build_object('success', false, 'error', 'Unauthorized to manage announcements.');
  end if;

  update public.community_announcements
  set is_pinned = p_is_pinned
  where community_id = p_community_id and id = p_announcement_id;

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

-- 7. Community events management RPCs
create or replace function public.create_community_event_rpc(
  p_community_id text,
  p_name text,
  p_banner text,
  p_description text,
  p_start_time timestamp with time zone,
  p_end_time timestamp with time zone,
  p_host_id uuid,
  p_co_hosts uuid[],
  p_max_participants integer,
  p_rewards text,
  p_rules text
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  if not public.check_community_permission(p_community_id, v_user_id, 'manage_events') then
    return jsonb_build_object('success', false, 'error', 'Unauthorized to create events.');
  end if;

  insert into public.community_events (
    community_id, name, banner, description, start_time, end_time, host_id, co_hosts, max_participants, rewards, rules, created_by
  ) values (
    p_community_id, p_name, p_banner, p_description, p_start_time, p_end_time, p_host_id, p_co_hosts, p_max_participants, p_rewards, p_rules, v_user_id
  );

  insert into public.community_logs (community_id, user_id, action_type, description)
  values (p_community_id, v_user_id, 'event_created', 'Event created: ' || p_name);

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

create or replace function public.register_for_event_rpc(
  p_event_id uuid
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_event record;
  v_current_count integer;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  select * into v_event from public.community_events where id = p_event_id;
  if not found then
    return jsonb_build_object('success', false, 'error', 'Event not found.');
  end if;

  -- Ensure they belong to the community hosting the event
  if not exists (
    select 1 from public.community_memberships 
    where community_id = v_event.community_id and user_id = v_user_id
  ) then
    return jsonb_build_object('success', false, 'error', 'You must be a member of the community to register.');
  end if;

  -- Check max participants cap
  if v_event.max_participants > 0 then
    select count(*) into v_current_count from public.community_event_participants where event_id = p_event_id;
    if v_current_count >= v_event.max_participants then
      return jsonb_build_object('success', false, 'error', 'Event registration is full.');
    end if;
  end if;

  insert into public.community_event_participants (event_id, user_id)
  values (p_event_id, v_user_id)
  on conflict (event_id, user_id) do nothing;

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

create or replace function public.cancel_event_rpc(
  p_community_id text,
  p_event_id uuid
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  if not public.check_community_permission(p_community_id, v_user_id, 'manage_events') then
    return jsonb_build_object('success', false, 'error', 'Unauthorized to manage events.');
  end if;

  update public.community_events
  set status = 'cancelled'
  where community_id = p_community_id and id = p_event_id;

  insert into public.community_logs (community_id, user_id, action_type, description)
  values (p_community_id, v_user_id, 'event_updated', 'Event cancelled.');

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

-- 8. Community settings update RPC
create or replace function public.update_community_settings_rpc(
  p_community_id text,
  p_name text,
  p_banner text,
  p_avatar text,
  p_description text,
  p_rules text,
  p_join_mode text,
  p_min_id_level integer,
  p_language text,
  p_country text,
  p_category text,
  p_visibility text
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  if not public.check_community_permission(p_community_id, v_user_id, 'edit_settings') then
    return jsonb_build_object('success', false, 'error', 'Unauthorized to modify settings.');
  end if;

  update public.communities
  set name = p_name,
      banner = p_banner,
      image = p_avatar,
      description = p_description,
      rules = p_rules,
      join_mode = p_join_mode,
      min_id_level = p_min_id_level,
      language = p_language,
      country = p_country,
      category = p_category,
      visibility = p_visibility
  where id = p_community_id;

  insert into public.community_logs (community_id, user_id, action_type, description)
  values (p_community_id, v_user_id, 'settings_changed', 'Settings updated.');

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

-- 9. Analytics RPC Dashboard
create or replace function public.get_community_analytics_rpc(p_community_id text)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_total_members integer;
  v_daily_active integer;
  v_weekly_active integer;
  v_monthly_active integer;
  v_total_exp bigint;
  v_current_level integer;
  v_join_requests bigint;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  if not public.check_community_permission(p_community_id, v_user_id, 'view_analytics') then
    return jsonb_build_object('success', false, 'error', 'Unauthorized to view analytics.');
  end if;

  select count(*) into v_total_members from public.community_memberships where community_id = p_community_id;
  select count(*) into v_daily_active from public.community_memberships where community_id = p_community_id and last_active_at >= now() - interval '1 day';
  select count(*) into v_weekly_active from public.community_memberships where community_id = p_community_id and last_active_at >= now() - interval '7 days';
  select count(*) into v_monthly_active from public.community_memberships where community_id = p_community_id and last_active_at >= now() - interval '30 days';
  
  select xp, level into v_total_exp, v_current_level from public.communities where id = p_community_id;
  select count(*) into v_join_requests from public.community_applications where community_id = p_community_id and status = 'pending';

  return jsonb_build_object(
    'success', true,
    'total_members', v_total_members,
    'daily_active', v_daily_active,
    'weekly_active', v_weekly_active,
    'monthly_active', v_monthly_active,
    'total_exp', v_total_exp,
    'current_level', v_current_level,
    'pending_join_requests', v_join_requests
  );
end;
$$ language plpgsql security definer;

-- 10. Detailed Members List RPC
create or replace function public.get_community_members_detailed_rpc(p_community_id text)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_result jsonb;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  if not exists (
    select 1 from public.community_memberships where community_id = p_community_id and user_id = v_user_id
  ) then
    return jsonb_build_object('success', false, 'error', 'Unauthorized. Must be a member of the community.');
  end if;

  select json_agg(t) into v_result
  from (
    select m.user_id, p.display_name, p.username, p.avatar, m.role, m.joined_at, m.contribution, m.last_active_at, p.level as id_level
    from public.community_memberships m
    join public.profiles p on m.user_id = p.id
    where m.community_id = p_community_id
    order by 
      case m.role 
        when 'owner' then 1
        when 'co_owner' then 2
        when 'admin' then 3
        else 4
      end,
      m.joined_at asc
  ) t;

  return jsonb_build_object('success', true, 'data', coalesce(v_result, '[]'::jsonb));
end;
$$ language plpgsql security definer;
