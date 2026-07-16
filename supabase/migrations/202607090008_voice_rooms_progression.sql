-- 202607090008_voice_rooms_progression.sql
-- Room progression tables, heartbeats, XP metrics, triggers, RLS, and realtime channels

create table public.room_level_progress (
  room_id text primary key references public.rooms(id) on delete cascade not null,
  current_level integer default 1 not null,
  current_xp integer default 0 not null,
  consecutive_days_completed integer default 0 not null,
  last_completed_date date
);

create table public.room_statistics (
  room_id text primary key references public.rooms(id) on delete cascade not null,
  total_visitors integer default 0 not null,
  today_visitors integer default 0 not null,
  total_silver_coins integer default 0 not null,
  today_silver_coins integer default 0 not null,
  total_gold_coins integer default 0 not null,
  today_gold_coins integer default 0 not null,
  total_task_points integer default 0 not null,
  today_task_points integer default 0 not null,
  total_extra_xp_points integer default 0 not null,
  today_extra_xp_points integer default 0 not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.room_reputation (
  room_id text primary key references public.rooms(id) on delete cascade not null,
  reputation_points integer default 0 not null,
  positive_feedback integer default 0 not null,
  negative_feedback integer default 0 not null
);

create table public.room_member_heartbeats (
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  last_seen_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, user_id)
);

create table public.room_daily_tasks (
  task_id text primary key,
  task_name text not null,
  description text,
  target_value integer not null,
  points_reward integer not null,
  xp_reward integer not null
);

create table public.room_daily_task_progress (
  room_id text references public.rooms(id) on delete cascade not null,
  task_id text references public.room_daily_tasks(task_id) on delete cascade not null,
  current_value integer default 0 not null,
  is_completed boolean default false not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, task_id)
);

-- Triggers
create or replace function public.handle_new_room_progression()
returns trigger as $$
begin
  insert into public.room_level_progress (room_id, current_level, current_xp)
  values (new.id, 1, 0);

  insert into public.room_statistics (room_id)
  values (new.id);

  insert into public.room_reputation (room_id)
  values (new.id);

  insert into public.room_gift_statistics (room_id)
  values (new.id);

  for i in 0..9 loop
    insert into public.room_seats (room_id, seat_index, role)
    values (new.id, i, case when i = 0 then 'Host' else 'Listener' end);
    
    insert into public.room_seat_gifts (room_id, seat_index, silver_gift_count)
    values (new.id, i, 0);
  end loop;

  return new;
end;
$$ language plpgsql security definer;

create trigger on_room_created_progression
  after insert on public.rooms
  for each row execute procedure public.handle_new_room_progression();

-- RPC Functions
create or replace function public.heartbeat_room_member(
  p_room_id text,
  p_is_speaking boolean
)
returns void as $$
declare
  v_user_id uuid := auth.uid();
  v_last_seen timestamp with time zone;
  v_elapsed integer;
  v_stay_added integer := 0;
  v_speak_added integer := 0;
begin
  if v_user_id is null then
    raise exception 'Unauthenticated user';
  end if;

  if not exists (select 1 from public.room_members where room_id = p_room_id and user_id = v_user_id) then
    return;
  end if;

  select last_seen_at into v_last_seen
  from public.room_member_heartbeats
  where room_id = p_room_id and user_id = v_user_id;

  if v_last_seen is not null then
    v_elapsed := extract(epoch from (now() - v_last_seen))::integer;
    if v_elapsed >= 2 and v_elapsed <= 45 then
      v_stay_added := v_elapsed;
      if p_is_speaking then
        v_speak_added := v_elapsed;
      end if;
    end if;
  end if;

  insert into public.room_member_heartbeats (room_id, user_id, last_seen_at)
  values (p_room_id, v_user_id, now())
  on conflict (room_id, user_id) do update set last_seen_at = EXCLUDED.last_seen_at;

  if v_stay_added > 0 then
    perform public.add_room_xp(p_room_id, greatest(1, v_stay_added / 5));
  end if;
end;
$$ language plpgsql security definer;

create or replace function public.increment_room_task_progress(
  p_room_id text,
  p_task_id text,
  p_amount integer
)
returns void as $$
begin
  insert into public.room_daily_task_progress (room_id, task_id, current_value)
  values (p_room_id, p_task_id, p_amount)
  on conflict (room_id, task_id) do update
  set current_value = room_daily_task_progress.current_value + p_amount;
end;
$$ language plpgsql security definer;

create or replace function public.add_room_xp(
  p_room_id text,
  p_xp integer
)
returns void as $$
begin
  update public.rooms
  set room_xp = room_xp + p_xp,
      today_room_xp = today_room_xp + p_xp
  where id = p_room_id;
end;
$$ language plpgsql security definer;

create or replace function public.reset_room_daily_progress()
returns void as $$
begin
  update public.room_level_progress p
  set consecutive_days_completed = case 
        when (select today_task_points from public.room_statistics s where s.room_id = p.room_id) >= 1200 then consecutive_days_completed + 1
        else 0
      end,
      last_completed_date = case 
        when (select today_task_points from public.room_statistics s where s.room_id = p.room_id) >= 1200 then now()::date
        else last_completed_date
      end;

  update public.room_statistics
  set today_visitors = 0,
      today_silver_coins = 0,
      today_gold_coins = 0,
      today_task_points = 0,
      today_extra_xp_points = 0,
      updated_at = now();

  update public.room_daily_task_progress
  set current_value = 0,
      is_completed = false,
      updated_at = now();
end;
$$ language plpgsql security definer;

-- Realtime registrations
do $$
begin
  alter publication supabase_realtime add table public.room_level_progress;
exception when others then
  raise notice 'Table room_level_progress already in supabase_realtime publication';
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.room_daily_task_progress;
exception when others then
  raise notice 'Table room_daily_task_progress already in supabase_realtime publication';
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.room_statistics;
exception when others then
  raise notice 'Table room_statistics already in supabase_realtime publication';
end;
$$;
