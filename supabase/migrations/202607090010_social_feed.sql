-- 202607090010_social_feed.sql
-- Social feed posts, likes, comments, bookmarks, story views, user connections, RLS, and follower triggers

create table public.posts (
  id text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  community_id text,
  content text not null,
  images text[] default '{}',
  videos text[] default '{}',
  pdfs text[] default '{}',
  doc_urls text[] default '{}',
  likes integer default 0,
  comments integer default 0,
  shares integer default 0,
  created_at timestamp with time zone default now()
);

create table public.post_likes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id text not null references public.posts(id) on delete cascade,
  created_at timestamp with time zone default now(),
  primary key (user_id, post_id)
);

create table public.post_bookmarks (
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id text not null references public.posts(id) on delete cascade,
  created_at timestamp with time zone default now(),
  primary key (user_id, post_id)
);

create table public.post_comments (
  id uuid default gen_random_uuid() primary key,
  post_id text not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  created_at timestamp with time zone default now()
);

create table public.stories (
  id uuid default gen_random_uuid() primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  media_url text not null,
  type text not null default 'image',
  created_at timestamp with time zone default now(),
  expires_at timestamp with time zone default (now() + interval '24 hours')
);

create table public.story_views (
  story_id uuid not null references public.stories(id) on delete cascade,
  viewer_id uuid not null references public.profiles(id) on delete cascade,
  viewed_at timestamp with time zone default now(),
  primary key (story_id, viewer_id)
);

create table public.connections (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'following',
  created_at timestamp with time zone default now(),
  primary key (follower_id, following_id)
);

create table public.user_customizations (
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  name text not null,
  is_equipped boolean default false,
  created_at timestamp with time zone default now(),
  primary key (user_id, type, name)
);

-- Triggers
create or replace function public.handle_connections_change()
returns trigger as $$
declare
  reverse_exists boolean;
begin
  if (tg_op = 'INSERT') then
    update public.profiles
    set following_count = following_count + 1
    where id = new.follower_id;

    update public.profiles
    set followers_count = followers_count + 1
    where id = new.following_id;

    select exists (
      select 1 from public.connections
      where follower_id = new.following_id and following_id = new.follower_id
    ) into reverse_exists;

    if reverse_exists then
      new.status := 'friends';
      
      update public.connections
      set status = 'friends'
      where follower_id = new.following_id and following_id = new.follower_id;

      update public.profiles
      set friends_count = friends_count + 1
      where id in (new.follower_id, new.following_id);
    end if;

    return new;

  elsif (tg_op = 'DELETE') then
    update public.profiles
    set following_count = greatest(0, following_count - 1)
    where id = old.follower_id;

    update public.profiles
    set followers_count = greatest(0, followers_count - 1)
    where id = old.following_id;

    if old.status = 'friends' then
      update public.connections
      set status = 'following'
      where follower_id = old.following_id and following_id = old.follower_id;

      update public.profiles
      set friends_count = greatest(0, friends_count - 1)
      where id in (old.follower_id, old.following_id);
    end if;

    return old;
  end if;
  return null;
end;
$$ language plpgsql security definer;

create trigger on_connections_insert
before insert on public.connections
for each row execute procedure public.handle_connections_change();

create trigger on_connections_delete
after delete on public.connections
for each row execute procedure public.handle_connections_change();

-- Row Level Security (RLS) Policies
alter table public.posts enable row level security;
create policy "Allow read access to all posts" on public.posts for select using (true);
create policy "Allow write access to own posts" on public.posts for all using (auth.uid() = user_id);

alter table public.post_likes enable row level security;
create policy "Allow read access to all likes" on public.post_likes for select using (true);
create policy "Allow write access to own likes" on public.post_likes for all using (auth.uid() = user_id);

alter table public.post_bookmarks enable row level security;
create policy "Allow read access to all bookmarks" on public.post_bookmarks for select using (true);
create policy "Allow write access to own bookmarks" on public.post_bookmarks for all using (auth.uid() = user_id);

alter table public.post_comments enable row level security;
create policy "Allow read access to all comments" on public.post_comments for select using (true);
create policy "Allow write access to own comments" on public.post_comments for all using (auth.uid() = user_id);

alter table public.stories enable row level security;
create policy "Allow read access to stories" on public.stories for select using (true);
create policy "Allow write access to own stories" on public.stories for all using (auth.uid() = user_id);

alter table public.story_views enable row level security;
create policy "Allow read access to story views" on public.story_views for select using (true);
create policy "Allow write access to own views" on public.story_views for all using (auth.uid() = viewer_id);

alter table public.connections enable row level security;
create policy "Allow read access to all connections" on public.connections for select using (true);
create policy "Allow write access to own connections" on public.connections for all using (auth.uid() = follower_id or auth.uid() = following_id);

alter table public.user_customizations enable row level security;
create policy "Allow read access to customizations" on public.user_customizations for select using (true);
create policy "Allow write access to own customizations" on public.user_customizations for all using (auth.uid() = user_id);
