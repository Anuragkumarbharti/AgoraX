-- 202607090005_communities.sql
-- Communities table, constraints, member sync triggers, system user & official communities seed, RLS, and realtime channel

create table public.communities (
  id text primary key,
  name text not null,
  description text not null,
  image text,
  banner text,
  category text not null,
  type text not null default 'public',
  owner uuid not null references public.profiles(id) on delete cascade,
  co_owner_ids text[] default '{}',
  admins text[] default '{}',
  members text[] default '{}',
  member_count integer default 0,
  is_verified boolean default false,
  created_at timestamp with time zone default now(),
  level integer default 1,
  xp integer default 0,
  creation_type text default 'coins',
  is_approved boolean default true,
  is_logo_unlocked boolean default true,
  rules text default 'Be respectful. No spamming or self-promotion.',
  tasks jsonb default '[]'
);

-- Triggers
create or replace function public.sync_community_member_count()
returns trigger as $$
begin
  new.member_count := coalesce(cardinality(new.members), 0);
  return new;
end;
$$ language plpgsql;

create trigger trigger_sync_community_member_count
before insert or update on public.communities
for each row execute procedure public.sync_community_member_count();

create or replace function public.enforce_single_official_community()
returns trigger as $$
declare
  v_user_id text;
  v_comm_row record;
begin
  if new.type = 'Official' and new.members is distinct from old.members then
    select val into v_user_id
    from unnest(new.members) as val
    except
    select val from unnest(old.members) as val
    limit 1;

    if v_user_id is not null then
      if pg_trigger_depth() < 2 then
        for v_comm_row in 
          select id, members 
          from public.communities 
          where type = 'Official' and id <> new.id and v_user_id = any(members)
        loop
          update public.communities
          set members = array_remove(members, v_user_id),
              member_count = greatest(0, member_count - 1)
          where id = v_comm_row.id;
        end loop;
      end if;
    end if;
  end if;
  return new;
end;
$$ language plpgsql;

create trigger trigger_enforce_single_official_community
before update on public.communities
for each row execute procedure public.enforce_single_official_community();

create or replace function public.prevent_official_communities_deletion()
returns trigger as $$
begin
  if old.type = 'Official' then
    raise exception 'Permanent official system communities cannot be deleted.';
  end if;
  return old;
end;
$$ language plpgsql;

create trigger trigger_prevent_official_communities_deletion
before delete on public.communities
for each row execute procedure public.prevent_official_communities_deletion();

-- Seed System User & Official Communities
insert into auth.users (id, email)
values ('00000000-0000-0000-0000-000000000000', 'system@creaniaa.com')
on conflict (id) do nothing;

insert into public.profiles (id, uid, username, level)
values ('00000000-0000-0000-0000-000000000000', 0, 'creania_system', 1)
on conflict (id) do nothing;

insert into public.communities (
  id, name, description, category, type, owner, image, banner, is_verified, member_count, members
)
values 
  (
    'comm-connect-005', 
    'Creaniaa Connect', 
    'Meet new people, make friends, chat, voice rooms, and social networking.', 
    'Social', 
    'Official', 
    '00000000-0000-0000-0000-000000000000', 
    '🤝', 
    'https://images.unsplash.com/photo-1522071820081-009f0129c71c', 
    true, 
    0, 
    '{}'
  ),
  (
    'comm-creators-002', 
    'Creaniaa Creators', 
    'Content creators, artists, designers, writers, and creators.', 
    'Education', 
    'Official', 
    '00000000-0000-0000-0000-000000000000', 
    '🎨', 
    'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe', 
    true, 
    0, 
    '{}'
  ),
  (
    'comm-gamers-003', 
    'Creaniaa Gamers', 
    'Gaming, esports, tournaments, and live gaming rooms.', 
    'Gaming', 
    'Official', 
    '00000000-0000-0000-0000-000000000000', 
    '🎮', 
    'https://images.unsplash.com/photo-1538481199705-c710c4e965fc', 
    true, 
    0, 
    '{}'
  ),
  (
    'comm-campus-004', 
    'Creaniaa Campus', 
    'Students, education, study groups, notes, and discussions.', 
    'College', 
    'Official', 
    '00000000-0000-0000-0000-000000000000', 
    '🏫', 
    'https://images.unsplash.com/photo-1523050854058-8df90110c9f1', 
    true, 
    0, 
    '{}'
  ),
  (
    'comm-official-001', 
    'Creaniaa Official', 
    'Official announcements, platform events, updates, and verified activities.', 
    'General', 
    'Official', 
    '00000000-0000-0000-0000-000000000000', 
    '📢', 
    'https://images.unsplash.com/photo-1579546929518-9e396f3cc809', 
    true, 
    0, 
    '{}'
  )
on conflict (id) do update set 
  name = excluded.name, 
  description = excluded.description, 
  type = excluded.type;

-- Row Level Security (RLS) Policies
alter table public.communities enable row level security;
create policy "Allow read access to all communities" on public.communities for select using (true);
create policy "Allow write access to own communities" on public.communities for all using (auth.uid() = owner);

-- Realtime registration
do $$
begin
  alter publication supabase_realtime add table public.communities;
exception when others then
  raise notice 'Table communities already in supabase_realtime publication';
end;
$$;
