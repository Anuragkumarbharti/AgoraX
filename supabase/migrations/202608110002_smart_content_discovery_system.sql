-- Migration 202608110002_smart_content_discovery_system.sql
-- Creania Smart Content Discovery, Hashtag, Music Catalog, Anti-Bot & Multi-Factor Trending Engine

-- 1. Extend posts table with unified entity columns
alter table public.posts 
  add column if not exists title text default '',
  add column if not exists description text default '',
  add column if not exists audio_id uuid default null,
  add column if not exists category_id text default 'general',
  add column if not exists language text default 'en',
  add column if not exists hashtags text[] default '{}',
  add column if not exists mentions text[] default '{}',
  add column if not exists moderation_status text default 'approved',
  add column if not exists quality_score numeric default 1.0,
  add column if not exists engagement_score numeric default 0.0,
  add column if not exists trend_score numeric default 0.0,
  add column if not exists relevance_score numeric default 1.0,
  add column if not exists freshness_score numeric default 1.0,
  add column if not exists safety_score numeric default 1.0,
  add column if not exists spam_score numeric default 0.0;

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

-- 3. Mentions System Table
create table if not exists public.post_mentions (
  post_id text not null references public.posts(id) on delete cascade,
  mentioned_user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamp with time zone default now(),
  primary key (post_id, mentioned_user_id)
);

-- 4. Audio / Music Catalog Tables
create table if not exists public.audio_tracks (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  artist text not null default 'Unknown Artist',
  cover_url text default '',
  audio_url text not null,
  license_type text default 'platform', -- 'licensed', 'platform', 'user_owned'
  territory text[] default '{"ALL"}',
  duration integer default 30, -- seconds
  start_offset integer default 0,
  end_offset integer default 30,
  rights_status text default 'approved', -- 'approved', 'flagged', 'pending'
  creator_id uuid references public.profiles(id) on delete set null,
  is_original_audio boolean default false,
  audio_usage_count integer default 0,
  unique_creators integer default 0,
  recent_usage integer default 0,
  trend_score numeric default 0.0,
  created_at timestamp with time zone default now()
);

create table if not exists public.audio_usages (
  id uuid default gen_random_uuid() primary key,
  audio_id uuid not null references public.audio_tracks(id) on delete cascade,
  post_id text not null references public.posts(id) on delete cascade,
  creator_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamp with time zone default now()
);

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

-- 5. Views, Engagements & Anti-Bot Tables
create table if not exists public.content_views (
  id uuid default gen_random_uuid() primary key,
  post_id text not null references public.posts(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  watch_time_seconds integer default 0,
  completion_rate numeric default 0.0,
  device_fingerprint text default '',
  created_at timestamp with time zone default now()
);

create index if not exists idx_content_views_post_user on public.content_views (post_id, user_id, created_at desc);

create table if not exists public.content_engagements (
  id uuid default gen_random_uuid() primary key,
  post_id text not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  engagement_type text not null, -- 'like', 'comment', 'share', 'save', 'answer', 'poll_vote', 'mcq_vote', 'repay', 'skip'
  weight numeric default 1.0,
  created_at timestamp with time zone default now()
);

create index if not exists idx_content_engagements_post_id on public.content_engagements (post_id, created_at desc);

create table if not exists public.post_saves (
  id uuid default gen_random_uuid() primary key,
  post_id text not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamp with time zone default now(),
  unique (post_id, user_id)
);

create table if not exists public.user_feed_feedback (
  id uuid default gen_random_uuid() primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id text references public.posts(id) on delete cascade,
  creator_id uuid references public.profiles(id) on delete cascade,
  feedback_type text not null, -- 'not_interested', 'mute_creator', 'mute_topic', 'report'
  reason text default '',
  created_at timestamp with time zone default now()
);

create table if not exists public.post_answers (
  id uuid default gen_random_uuid() primary key,
  post_id text not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  answer_text text not null,
  quality_score numeric default 1.0,
  upvotes integer default 0,
  created_at timestamp with time zone default now()
);

-- Enable RLS
alter table public.hashtags enable row level security;
alter table public.post_hashtags enable row level security;
alter table public.post_mentions enable row level security;
alter table public.audio_tracks enable row level security;
alter table public.audio_usages enable row level security;
alter table public.content_views enable row level security;
alter table public.content_engagements enable row level security;
alter table public.post_saves enable row level security;
alter table public.user_feed_feedback enable row level security;
alter table public.post_answers enable row level security;

-- Policies
create policy "Allow public read access to hashtags" on public.hashtags for select using (true);
create policy "Allow public read access to post_hashtags" on public.post_hashtags for select using (true);
create policy "Allow public read access to post_mentions" on public.post_mentions for select using (true);
create policy "Allow public read access to audio_tracks" on public.audio_tracks for select using (true);
create policy "Allow insert access to user_owned audio_tracks" on public.audio_tracks for insert with check (auth.uid() = creator_id);
create policy "Allow public read access to audio_usages" on public.audio_usages for select using (true);
create policy "Allow insert access to audio_usages" on public.audio_usages for insert with check (auth.uid() = creator_id);
create policy "Allow read/write access to own saves" on public.post_saves for all using (auth.uid() = user_id);
create policy "Allow read/write access to own feed feedback" on public.user_feed_feedback for all using (auth.uid() = user_id);
create policy "Allow public read access to post_answers" on public.post_answers for select using (true);
create policy "Allow insert access to own post_answers" on public.post_answers for insert with check (auth.uid() = author_id);
create policy "Allow authenticated users to view content" on public.content_views for insert with check (true);
create policy "Allow authenticated users to engage" on public.content_engagements for insert with check (auth.uid() = user_id);

-- Seed initial trending & licensed music audio catalog items if empty
insert into public.audio_tracks (title, artist, cover_url, audio_url, license_type, duration, is_original_audio, trend_score)
values 
  ('Creania Synthwave Beat', 'Creania Originals', 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4', 'https://cdn.freesound.org/previews/560/560824_11861866-lq.mp3', 'platform', 30, true, 95.0),
  ('Lofi Chill Coding', 'Study Vibes', 'https://images.unsplash.com/photo-1494232410401-ad00d5433cfa', 'https://cdn.freesound.org/previews/558/558312_11861866-lq.mp3', 'platform', 45, false, 88.0),
  ('Flutter High Motivation', 'Code Masters', 'https://images.unsplash.com/photo-1518770660439-4636190af475', 'https://cdn.freesound.org/previews/555/555901_11861866-lq.mp3', 'licensed', 60, false, 76.0),
  ('Acoustic Sunset', 'Aura Sound', 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745', 'https://cdn.freesound.org/previews/540/540112_11861866-lq.mp3', 'platform', 30, false, 65.0)
on conflict do nothing;

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

-- 7. RPC: Mention Autocomplete Suggestions
create or replace function public.get_mention_suggestions(
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

  select jsonb_agg(u_item)
  into v_results
  from (
    select 
      id,
      username,
      display_name,
      coalesce(avatar_url, profile_photo, '') as avatar_url,
      career_level
    from public.profiles
    where (v_norm = '' or lower(username) like '%' || v_norm || '%' or lower(coalesce(display_name, '')) like '%' || v_norm || '%')
    order by username asc
    limit p_limit
  ) u_item;

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

-- 9. RPC: Music Catalog Search
create or replace function public.search_audio_tracks(
  p_query text default '',
  p_category text default '',
  p_limit integer default 20
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_results jsonb;
begin
  select jsonb_agg(track_item)
  into v_results
  from (
    select 
      id,
      title,
      artist,
      cover_url,
      audio_url,
      license_type,
      duration,
      start_offset,
      end_offset,
      is_original_audio,
      audio_usage_count,
      trend_score
    from public.audio_tracks
    where rights_status = 'approved'
      and (p_query = '' or lower(title) like '%' || lower(p_query) || '%' or lower(artist) like '%' || lower(p_query) || '%')
    order by trend_score desc, audio_usage_count desc
    limit p_limit
  ) track_item;

  return coalesce(v_results, '[]'::jsonb);
end;
$$;

-- 10. RPC: Duplicate Question Detection
create or replace function public.check_duplicate_question(
  p_question_text text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_matches jsonb;
  v_norm_q text;
begin
  v_norm_q := lower(trim(p_question_text));

  select jsonb_agg(q_item)
  into v_matches
  from (
    select 
      p.id as post_id,
      pq.question,
      p.created_at,
      prof.username as author_name
    from public.post_questions pq
    join public.posts p on p.id = pq.post_id
    left join public.profiles prof on prof.id = p.user_id
    where lower(pq.question) like '%' || substring(v_norm_q, 1, 20) || '%'
    order by p.created_at desc
    limit 5
  ) q_item;

  return jsonb_build_object(
    'is_duplicate_suspected', coalesce(jsonb_array_length(v_matches), 0) > 0,
    'similar_questions', coalesce(v_matches, '[]'::jsonb)
  );
end;
$$;

-- 11. RPC: Dynamic Smart Multi-Factor Trending Score Calculation
create or replace function public.calculate_smart_trending_score(
  p_post_id text
)
returns numeric
language plpgsql
security definer
as $$
declare
  v_post record;
  v_age_hours numeric;
  v_freshness_decay numeric;
  v_unique_viewers integer;
  v_unique_engagers integer;
  v_likes_velocity numeric;
  v_shares_count integer;
  v_saves_count integer;
  v_answers_count integer;
  v_reports_count integer;
  v_creator_post_count integer;
  v_creator_penalty numeric := 1.0;
  v_trend_score numeric := 0.0;
begin
  select * into v_post from public.posts where id = p_post_id;
  if not found then
    return 0.0;
  end if;

  -- Age in hours
  v_age_hours := greatest(0.1, extract(epoch from (now() - v_post.created_at)) / 3600.0);
  
  -- Content type specific freshness decay (Reels decay faster, educational slower)
  if v_post.post_type in ('reel', 'video') then
    v_freshness_decay := exp(-0.15 * v_age_hours);
  elsif v_post.post_type in ('pdf', 'question', 'mcq') then
    v_freshness_decay := exp(-0.03 * v_age_hours); -- Educational lasts longer
  else
    v_freshness_decay := exp(-0.08 * v_age_hours);
  end if;

  -- Unique Viewers & Engagers
  select count(distinct user_id) into v_unique_viewers from public.content_views where post_id = p_post_id;
  select count(distinct user_id) into v_unique_engagers from public.content_engagements where post_id = p_post_id;
  
  -- Saves & Shares
  select count(*) into v_saves_count from public.post_saves where post_id = p_post_id;
  select count(*) into v_shares_count from public.content_engagements where post_id = p_post_id and engagement_type = 'share';
  select count(*) into v_answers_count from public.post_answers where post_id = p_post_id;
  select count(*) into v_reports_count from public.user_feed_feedback where post_id = p_post_id and feedback_type = 'report';

  -- Anti-dominance penalty (Max 2-3 posts per creator in top feed window)
  select count(*) into v_creator_post_count 
  from public.posts 
  where user_id = v_post.user_id 
    and created_at > (now() - interval '24 hours');

  if v_creator_post_count > 3 then
    v_creator_penalty := 0.6;
  end if;

  -- Multi-Factor Formula
  v_trend_score := (
    (coalesce(v_post.likes, 0) * 1.0) +
    (coalesce(v_post.comments, 0) * 2.0) +
    (v_shares_count * 4.0) +           -- Shares weighted heavily
    (v_saves_count * 5.0) +            -- Saves weighted heavily for educational utility
    (v_answers_count * 3.5) +          -- Question answers
    (v_unique_engagers * 2.5) +        -- Unique engagers over bot repetitive clicks
    (v_unique_viewers * 0.5)
  ) * v_freshness_decay * v_creator_penalty;

  -- Subtract report/spam penalty
  if v_reports_count > 0 then
    v_trend_score := v_trend_score * (1.0 / (1.0 + (v_reports_count * 0.5)));
  end if;

  -- Update score in posts table
  update public.posts set trend_score = round(v_trend_score::numeric, 2) where id = p_post_id;

  return round(v_trend_score::numeric, 2);
end;
$$;

-- 12. RPC: Dynamic Smart Unified Feed Engine
create or replace function public.get_smart_feed(
  p_user_id uuid default null,
  p_feed_type text default 'trending_now', -- 'for_you', 'trending_now', 'rising_fast', 'reels', 'questions', 'mcq', 'audio', 'hashtags', 'educational'
  p_category text default null,
  p_content_type text default null,
  p_hashtag text default null,
  p_limit integer default 15,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_posts jsonb;
begin
  select jsonb_agg(post_item)
  into v_posts
  from (
    select 
      p.id,
      p.user_id,
      p.community_id,
      p.content,
      p.post_type,
      p.caption,
      p.media_url,
      p.thumbnail_url,
      p.aspect_ratio,
      p.media_metadata,
      p.title,
      p.description,
      p.audio_id,
      p.category_id,
      p.hashtags,
      p.mentions,
      p.likes,
      p.comments,
      p.shares,
      p.created_at,
      p.trend_score,
      p.visibility,
      p.comments_enabled,
      p.shares_enabled,
      p.status,
      -- Author details
      jsonb_build_object(
        'username', coalesce(prof.username, 'Anonymous'),
        'display_name', coalesce(prof.display_name, prof.username, 'User'),
        'avatar_url', coalesce(prof.avatar_url, prof.profile_photo, '')
      ) as author_profile,
      -- Attached Audio info if present
      case when p.audio_id is not null then (
        select jsonb_build_object(
          'id', a.id,
          'title', a.title,
          'artist', a.artist,
          'cover_url', a.cover_url,
          'audio_url', a.audio_url,
          'duration', a.duration
        )
        from public.audio_tracks a where a.id = p.audio_id
      ) else null end as audio_track,
      -- User interaction flags
      case when p_user_id is not null then
        exists(select 1 from public.post_likes pl where pl.post_id = p.id and pl.user_id = p_user_id)
      else false end as is_liked,
      case when p_user_id is not null then
        exists(select 1 from public.post_saves ps where ps.post_id = p.id and ps.user_id = p_user_id)
      else false end as is_saved,
      -- MCQ details
      case when p.post_type = 'mcq' then (
        select jsonb_build_object(
          'question', m.question,
          'options', m.options,
          'explanation', m.explanation,
          'timer_seconds', m.timer_seconds,
          'difficulty', m.difficulty,
          'category', m.category,
          'xp_reward', m.xp_reward,
          'user_selected_option_id', (select mv.option_id from public.post_mcq_votes mv where mv.post_id = p.id and mv.user_id = p_user_id limit 1)
        ) from public.post_mcqs m where m.post_id = p.id
      ) else null end as mcq_data,
      -- Poll details
      case when p.post_type = 'poll' then (
        select jsonb_build_object(
          'question', pol.question,
          'options', pol.options,
          'duration_hours', pol.duration_hours,
          'expires_at', pol.expires_at,
          'total_votes', (select count(*) from public.post_poll_votes pv where pv.post_id = p.id),
          'user_selected_option_id', (select pv.option_id from public.post_poll_votes pv where pv.post_id = p.id and pv.user_id = p_user_id limit 1),
          'option_counts', coalesce((
            select jsonb_object_agg(pv.option_id, cnt)
            from (
              select option_id, count(*) as cnt
              from public.post_poll_votes
              where post_id = p.id
              group by option_id
            ) pv
          ), '{}'::jsonb)
        ) from public.post_polls pol where pol.post_id = p.id
      ) else null end as poll_data,
      -- Question details
      case when p.post_type = 'question' then (
        select jsonb_build_object(
          'question', q.question,
          'context', q.context,
          'optional_media_url', q.optional_media_url,
          'answers_count', (select count(*) from public.post_answers pa where pa.post_id = p.id)
        ) from public.post_questions q where q.post_id = p.id
      ) else null end as question_data
    from public.posts p
    left join public.profiles prof on prof.id = p.user_id
    where p.status = 'published'
      and (p_category is null or p.category_id = p_category)
      and (p_content_type is null or p.post_type = p_content_type)
      and (p_hashtag is null or p.hashtags @> array[lower(regexp_replace(p_hashtag, '[^a-zA-Z0-9_]', '', 'g'))])
      -- Exclude feedback muted creators / not interested posts
      and not exists (
        select 1 from public.user_feed_feedback uff 
        where uff.user_id = p_user_id 
          and (uff.post_id = p.id or uff.creator_id = p.user_id)
          and uff.feedback_type in ('not_interested', 'mute_creator')
      )
    order by 
      case when p_feed_type = 'trending_now' then p.trend_score end desc,
      case when p_feed_type = 'rising_fast' then (p.likes + p.comments * 2.0) / greatest(0.1, extract(epoch from (now() - p.created_at)) / 3600.0) end desc,
      case when p_feed_type = 'reels' then case when p.post_type = 'reel' then p.trend_score else 0 end end desc,
      case when p_feed_type = 'educational' then case when p.post_type in ('pdf', 'question', 'mcq') then p.trend_score else 0 end end desc,
      p.created_at desc
    limit p_limit offset p_offset
  ) post_item;

  return coalesce(v_posts, '[]'::jsonb);
end;
$$;
