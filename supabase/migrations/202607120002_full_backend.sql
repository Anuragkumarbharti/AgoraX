-- supabase/migrations/202607120002_full_backend.sql
-- Complete Backend Integration Migration Script

-- Alter profiles table to add missing categories & career metrics
alter table public.profiles
  add column if not exists selected_study_category text,
  add column if not exists category_lock_expiry timestamp with time zone,
  add column if not exists career_name text,
  add column if not exists career_xp integer default 0;

-- 1. Create Storage Buckets
insert into storage.buckets (id, name, public)
values 
  ('avatars', 'avatars', true),
  ('banners', 'banners', true),
  ('room-covers', 'room-covers', true),
  ('community-covers', 'community-covers', true),
  ('event-banners', 'event-banners', true),
  ('post-images', 'post-images', true),
  ('post-videos', 'post-videos', true),
  ('reels', 'reels', true),
  ('stories', 'stories', true),
  ('chat-media', 'chat-media', true),
  ('gifts', 'gifts', true),
  ('stickers', 'stickers', true),
  ('badges', 'badges', true),
  ('frames', 'frames', true),
  ('entry-effects', 'entry-effects', true),
  ('thumbnails', 'thumbnails', true),
  ('study-files', 'study-files', false),
  ('study-covers', 'study-covers', true)
on conflict (id) do nothing;

-- 2. Create Communities Table
create table if not exists public.communities (
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
  member_count integer default 1,
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

-- Enable RLS and setup policies
alter table public.communities enable row level security;
create policy "Allow read access to all communities" on public.communities for select using (true);
create policy "Allow write access to own communities" on public.communities for all using (public.canonical_uid() = owner);

-- 3. Create Events Table
create table if not exists public.events (
  id text primary key,
  title text not null,
  description text not null,
  banner_url text,
  category text not null,
  difficulty text not null,
  organizer text not null,
  is_official boolean default false,
  start_date timestamp with time zone not null,
  end_date timestamp with time zone not null,
  registration_deadline timestamp with time zone not null,
  result_date timestamp with time zone,
  max_participants integer default 100,
  is_unlimited boolean default false,
  entry_fee_type text not null,
  entry_fee_amount integer default 0,
  prize_pool text,
  rewards jsonb not null default '{}',
  status text not null,
  format text not null,
  rules text[] default '{}',
  required_level integer default 1,
  required_badge text,
  tags text[] default '{}',
  language text default 'English',
  is_public boolean default true,
  participants_count integer default 0,
  anti_cheat jsonb default '{}',
  negative_marking boolean default false,
  duration_minutes integer default 60,
  question_count integer default 30,
  passing_marks integer default 40,
  required_registration_fields text[] default '{"name", "email", "phone"}',
  terms_and_conditions text,
  is_paid boolean default false,
  min_participants integer default 10,
  winner_type text default 'top3',
  auto_prize_pool boolean default true,
  password_protected boolean default false,
  password text,
  co_owner_id text,
  admin_ids text[] default '{}',
  registered_user_ids text[] default '{}',
  sponsored_amount double precision default 0.0,
  coupon_codes jsonb default '{}',
  allow_admins_join boolean default false,
  creator_id uuid references public.profiles(id) on delete set null,
  duration_string text,
  allow_spectators boolean default true,
  allow_late_join boolean default false,
  auto_cancel_min_users boolean default true,
  auto_refund boolean default true,
  chat_enabled boolean default true,
  voice_room_enabled boolean default false,
  screen_share_enabled boolean default false,
  recording_enabled boolean default false,
  timeline_status text,
  winners jsonb default '[]',
  is_multi_round boolean default false,
  rounds jsonb default '[]',
  created_at timestamp with time zone default now()
);

alter table public.events enable row level security;
create policy "Allow read access to all events" on public.events for select using (true);
create policy "Allow write access to event creators" on public.events for all using (public.canonical_uid() = creator_id);

-- 4. Create Posts Tables
create table if not exists public.posts (
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

alter table public.posts enable row level security;
create policy "Allow read access to all posts" on public.posts for select using (true);
create policy "Allow write access to own posts" on public.posts for all using (public.canonical_uid() = user_id);

-- Likes
create table if not exists public.post_likes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id text not null references public.posts(id) on delete cascade,
  created_at timestamp with time zone default now(),
  primary key (user_id, post_id)
);

alter table public.post_likes enable row level security;
create policy "Allow read access to all likes" on public.post_likes for select using (true);
create policy "Allow write access to own likes" on public.post_likes for all using (public.canonical_uid() = user_id);

-- Bookmarks
create table if not exists public.post_bookmarks (
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id text not null references public.posts(id) on delete cascade,
  created_at timestamp with time zone default now(),
  primary key (user_id, post_id)
);

alter table public.post_bookmarks enable row level security;
create policy "Allow read access to all bookmarks" on public.post_bookmarks for select using (true);
create policy "Allow write access to own bookmarks" on public.post_bookmarks for all using (public.canonical_uid() = user_id);

-- Comments
create table if not exists public.post_comments (
  id uuid default gen_random_uuid() primary key,
  post_id text not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  created_at timestamp with time zone default now()
);

alter table public.post_comments enable row level security;
create policy "Allow read access to all comments" on public.post_comments for select using (true);
create policy "Allow write access to own comments" on public.post_comments for all using (public.canonical_uid() = user_id);

-- 5. Create Stories Table
create table if not exists public.stories (
  id uuid default gen_random_uuid() primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  media_url text not null,
  type text not null default 'image',
  created_at timestamp with time zone default now(),
  expires_at timestamp with time zone default (now() + interval '24 hours')
);

alter table public.stories enable row level security;
create policy "Allow read access to stories" on public.stories for select using (true);
create policy "Allow write access to own stories" on public.stories for all using (public.canonical_uid() = user_id);

-- Story Views
create table if not exists public.story_views (
  story_id uuid not null references public.stories(id) on delete cascade,
  viewer_id uuid not null references public.profiles(id) on delete cascade,
  viewed_at timestamp with time zone default now(),
  primary key (story_id, viewer_id)
);

alter table public.story_views enable row level security;
create policy "Allow read access to story views" on public.story_views for select using (true);
create policy "Allow write access to own views" on public.story_views for all using (public.canonical_uid() = viewer_id);

-- 6. Create Connections (Follows/Friends)
create table if not exists public.connections (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'following', -- 'following' or 'friends'
  created_at timestamp with time zone default now(),
  primary key (follower_id, following_id)
);

alter table public.connections enable row level security;
create policy "Allow read access to all connections" on public.connections for select using (true);
create policy "Allow write access to own connections" on public.connections for all using (public.canonical_uid() = follower_id or public.canonical_uid() = following_id);

-- 7. Create User Customizations
create table if not exists public.user_customizations (
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null, -- 'badge', 'frame', 'entry_effect'
  name text not null,
  is_equipped boolean default false,
  created_at timestamp with time zone default now(),
  primary key (user_id, type, name)
);

alter table public.user_customizations enable row level security;
create policy "Allow read access to customizations" on public.user_customizations for select using (true);
create policy "Allow write access to own customizations" on public.user_customizations for all using (public.canonical_uid() = user_id);

-- 8. Create Daily Tasks Progress
create table if not exists public.user_daily_tasks (
  user_id uuid not null references public.profiles(id) on delete cascade,
  task_id text not null,
  status text not null default 'pending', -- 'pending', 'completed', 'claimed'
  progress integer default 0,
  updated_at timestamp with time zone default now(),
  primary key (user_id, task_id)
);

alter table public.user_daily_tasks enable row level security;
create policy "Allow read access to daily tasks" on public.user_daily_tasks for select using (true);
create policy "Allow write access to own tasks" on public.user_daily_tasks for all using (public.canonical_uid() = user_id);

-- 9. Setup Storage Security RLS Policies
create policy "Allow public read on storage objects" on storage.objects for select using (true);
create policy "Allow authenticated upload on storage objects" on storage.objects for insert with check (auth.role() = 'authenticated');
create policy "Allow authenticated update on storage objects" on storage.objects for update using (auth.role() = 'authenticated');
create policy "Allow authenticated delete on storage objects" on storage.objects for delete using (auth.role() = 'authenticated');
