-- ==========================================================================
-- Consolidated Supabase Migration Module 09: 202607090009_feed_posts_and_discovery.sql
-- Authoritative baseline schema, functions, triggers, policies, and seeds.
-- ==========================================================================

create trigger on_connections_insert
before insert on public.connections
for each row execute procedure public.handle_connections_change();

create trigger on_connections_delete
after delete on public.connections
for each row execute procedure public.handle_connections_change();

-- Migration 202608110001_post_creation_system.sql
-- Unified Creania Post Creation System & Optimized Post/Media Schema

-- 1. Upgrade posts table with flexible post types and media metadata
alter table public.posts 
  add column if not exists post_type text not null default 'text',
  add column if not exists caption text default '',
  add column if not exists media_url text default '',
  add column if not exists thumbnail_url text default '',
  add column if not exists aspect_ratio numeric default 1.0,
  add column if not exists media_metadata jsonb default '{}'::jsonb,
  add column if not exists visibility text default 'public',
  add column if not exists comments_enabled boolean default true,
  add column if not exists shares_enabled boolean default true,
  add column if not exists status text default 'published';

-- Check constraint for valid post types
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'posts_post_type_check'
  ) then
    alter table public.posts 
      add constraint posts_post_type_check 
      check (post_type in ('text', 'photo', 'video', 'audio', 'pdf', 'question', 'mcq', 'poll', 'link'));
  end if;
end $$;

-- Indexes for lightning fast feed queries
create index if not exists idx_posts_created_at on public.posts (created_at desc);

create index if not exists idx_posts_user_id on public.posts (user_id);

create index if not exists idx_posts_post_type on public.posts (post_type);

-- 3. Poll Data Table
create table if not exists public.post_polls (
  post_id text primary key references public.posts(id) on delete cascade,
  question text not null,
  options jsonb not null default '[]'::jsonb, -- Array of {id: string, text: string}
  duration_hours integer default 24,
  expires_at timestamp with time zone default (now() + interval '24 hours'),
  created_at timestamp with time zone default now()
);

-- 4. Question Data Table
create table if not exists public.post_questions (
  post_id text primary key references public.posts(id) on delete cascade,
  question text not null,
  context text default '',
  optional_media_url text default '',
  created_at timestamp with time zone default now()
);

-- Policies
create policy "Allow read access to all post_mcqs" on public.post_mcqs for select using (true);

-- Indexes for performance
create index if not exists idx_posts_trend_score on public.posts (trend_score desc);

create index if not exists idx_posts_category_id on public.posts (category_id);

create index if not exists idx_posts_hashtags on public.posts using gin (hashtags);

create index if not exists idx_posts_mentions on public.posts using gin (mentions);

-- 2. Hashtags System Tables
create table if not exists public.hashtags (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  normalized_name text not null unique,
  usage_count integer default 0,
  recent_usage integer default 0,
  trend_score numeric default 0.0,
  content_count integer default 0,
  active_creators integer default 0,
  spam_score numeric default 0.0,
  created_at timestamp with time zone default now()
);

create table if not exists public.post_hashtags (
  post_id text not null references public.posts(id) on delete cascade,
  hashtag_id uuid not null references public.hashtags(id) on delete cascade,
  created_at timestamp with time zone default now(),
  primary key (post_id, hashtag_id)
);

create index if not exists idx_hashtags_normalized on public.hashtags (normalized_name);

create index if not exists idx_hashtags_trend_score on public.hashtags (trend_score desc);

create index if not exists idx_audio_tracks_trend_score on public.audio_tracks (trend_score desc);

create index if not exists idx_audio_usages_audio_id on public.audio_usages (audio_id);

-- Add Foreign Key to posts for audio_id
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'posts_audio_id_fkey'
  ) then
    alter table public.posts 
      add constraint posts_audio_id_fkey 
      foreign key (audio_id) references public.audio_tracks(id) on delete set null;
  end if;
end $$;

create index if not exists idx_content_views_post_user on public.content_views (post_id, user_id, created_at desc);

-- Policies
create policy "Allow public read access to hashtags" on public.hashtags for select using (true);

-- Seed initial trending & licensed music audio catalog items if empty
insert into public.audio_tracks (title, artist, cover_url, audio_url, license_type, duration, is_original_audio, trend_score)
values 
  ('Creania Synthwave Beat', 'Creania Originals', 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4', 'https://cdn.freesound.org/previews/560/560824_11861866-lq.mp3', 'platform', 30, true, 95.0),
  ('Lofi Chill Coding', 'Study Vibes', 'https://images.unsplash.com/photo-1494232410401-ad00d5433cfa', 'https://cdn.freesound.org/previews/558/558312_11861866-lq.mp3', 'platform', 45, false, 88.0),
  ('Flutter High Motivation', 'Code Masters', 'https://images.unsplash.com/photo-1518770660439-4636190af475', 'https://cdn.freesound.org/previews/555/555901_11861866-lq.mp3', 'licensed', 60, false, 76.0),
  ('Acoustic Sunset', 'Aura Sound', 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745', 'https://cdn.freesound.org/previews/540/540112_11861866-lq.mp3', 'platform', 30, false, 65.0)
on conflict do nothing;

-- 7. RPC Function for Atomic Poll Voting
create or replace function public.submit_poll_vote(
  p_post_id text,
  p_user_id uuid,
  p_option_id text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_total_votes integer;
  v_option_counts jsonb;
  v_result jsonb;
begin
  -- Record vote
  insert into public.post_poll_votes (post_id, user_id, option_id)
  values (p_post_id, p_user_id, p_option_id)
  on conflict (post_id, user_id) 
  do update set option_id = p_option_id, created_at = now();

  -- Calculate vote counts
  select count(*) into v_total_votes
  from public.post_poll_votes
  where post_id = p_post_id;

  select jsonb_object_agg(option_id, cnt) into v_option_counts
  from (
    select option_id, count(*) as cnt
    from public.post_poll_votes
    where post_id = p_post_id
    group by option_id
  ) t;

  select jsonb_build_object(
    'success', true,
    'total_votes', v_total_votes,
    'user_selected_option_id', p_option_id,
    'option_counts', coalesce(v_option_counts, '{}'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

-- 6. RPC: Hashtag Normalization and Autocomplete
create or replace function public.get_hashtag_suggestions(
  p_query text,
  p_limit integer default 10
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_norm text;
  v_results jsonb;
begin
  v_norm := lower(regexp_replace(coalesce(p_query, ''), '[^a-zA-Z0-9_]', '', 'g'));
  
  select jsonb_agg(h_item)
  into v_results
  from (
    select 
      id,
      name,
      normalized_name,
      usage_count,
      trend_score
    from public.hashtags
    where (v_norm = '' or normalized_name like '%' || v_norm || '%')
    order by trend_score desc, usage_count desc
    limit p_limit
  ) h_item;

  return coalesce(v_results, '[]'::jsonb);
end;
$$;

-- 8. RPC: Normalize & Save Post Hashtags
create or replace function public.normalize_and_attach_hashtags(
  p_post_id text,
  p_hashtags text[]
)
returns void
language plpgsql
security definer
as $$
declare
  v_raw_tag text;
  v_norm_tag text;
  v_tag_id uuid;
begin
  if p_hashtags is null or array_length(p_hashtags, 1) is null then
    return;
  end if;

  foreach v_raw_tag in array p_hashtags loop
    v_norm_tag := lower(regexp_replace(v_raw_tag, '[^a-zA-Z0-9_]', '', 'g'));
    if v_norm_tag <> '' then
      -- Insert or get hashtag
      insert into public.hashtags (name, normalized_name, usage_count, recent_usage)
      values ('#' || v_norm_tag, v_norm_tag, 1, 1)
      on conflict (normalized_name) 
      do update set usage_count = public.hashtags.usage_count + 1, recent_usage = public.hashtags.recent_usage + 1
      returning id into v_tag_id;

      if v_tag_id is null then
        select id into v_tag_id from public.hashtags where normalized_name = v_norm_tag;
      end if;

      -- Attach to post
      if v_tag_id is not null then
        insert into public.post_hashtags (post_id, hashtag_id)
        values (p_post_id, v_tag_id)
        on conflict do nothing;
      end if;
    end if;
  end loop;
end;
$$;

