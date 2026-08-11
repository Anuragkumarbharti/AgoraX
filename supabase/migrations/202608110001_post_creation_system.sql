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
create index if not exists idx_posts_community_id on public.posts (community_id);
create index if not exists idx_posts_post_type on public.posts (post_type);

-- 2. MCQ / Quiz Data Table
create table if not exists public.post_mcqs (
  post_id text primary key references public.posts(id) on delete cascade,
  question text not null,
  options jsonb not null default '[]'::jsonb, -- Array of {id: string, text: string, is_correct: bool}
  explanation text default '',
  timer_seconds integer default 0,
  difficulty text default 'Medium',
  category text default 'General',
  xp_reward integer default 10,
  created_at timestamp with time zone default now()
);

create table if not exists public.post_mcq_votes (
  id uuid default gen_random_uuid() primary key,
  post_id text not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  option_id text not null,
  created_at timestamp with time zone default now(),
  unique (post_id, user_id)
);

-- 3. Poll Data Table
create table if not exists public.post_polls (
  post_id text primary key references public.posts(id) on delete cascade,
  question text not null,
  options jsonb not null default '[]'::jsonb, -- Array of {id: string, text: string}
  duration_hours integer default 24,
  expires_at timestamp with time zone default (now() + interval '24 hours'),
  created_at timestamp with time zone default now()
);

create table if not exists public.post_poll_votes (
  id uuid default gen_random_uuid() primary key,
  post_id text not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  option_id text not null,
  created_at timestamp with time zone default now(),
  unique (post_id, user_id)
);

-- 4. Question Data Table
create table if not exists public.post_questions (
  post_id text primary key references public.posts(id) on delete cascade,
  question text not null,
  context text default '',
  optional_media_url text default '',
  created_at timestamp with time zone default now()
);

-- 5. Post Reports Table
create table if not exists public.post_reports (
  id uuid default gen_random_uuid() primary key,
  post_id text not null references public.posts(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null,
  created_at timestamp with time zone default now()
);

-- Enable RLS
alter table public.post_mcqs enable row level security;
alter table public.post_mcq_votes enable row level security;
alter table public.post_polls enable row level security;
alter table public.post_poll_votes enable row level security;
alter table public.post_questions enable row level security;
alter table public.post_reports enable row level security;

-- Policies
create policy "Allow read access to all post_mcqs" on public.post_mcqs for select using (true);
create policy "Allow insert access to own post_mcqs" on public.post_mcqs for insert with check (
  exists (select 1 from public.posts where id = post_id and user_id = auth.uid())
);

create policy "Allow read access to all post_mcq_votes" on public.post_mcq_votes for select using (true);
create policy "Allow insert access to own post_mcq_votes" on public.post_mcq_votes for insert with check (auth.uid() = user_id);

create policy "Allow read access to all post_polls" on public.post_polls for select using (true);
create policy "Allow insert access to own post_polls" on public.post_polls for insert with check (
  exists (select 1 from public.posts where id = post_id and user_id = auth.uid())
);

create policy "Allow read access to all post_poll_votes" on public.post_poll_votes for select using (true);
create policy "Allow insert access to own post_poll_votes" on public.post_poll_votes for insert with check (auth.uid() = user_id);

create policy "Allow read access to all post_questions" on public.post_questions for select using (true);
create policy "Allow insert access to own post_questions" on public.post_questions for insert with check (
  exists (select 1 from public.posts where id = post_id and user_id = auth.uid())
);

create policy "Allow insert access to reports" on public.post_reports for insert with check (auth.uid() = reporter_id);

-- 6. RPC Function for Atomic MCQ Voting
create or replace function public.submit_mcq_vote(
  p_post_id text,
  p_user_id uuid,
  p_option_id text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_result jsonb;
  v_is_correct bool := false;
  v_explanation text := '';
  v_correct_option_id text := '';
begin
  -- Record vote
  insert into public.post_mcq_votes (post_id, user_id, option_id)
  values (p_post_id, p_user_id, p_option_id)
  on conflict (post_id, user_id) 
  do update set option_id = p_option_id, created_at = now();

  -- Get correct details
  select 
    (elem->>'is_correct')::boolean,
    m.explanation,
    (select elem2->>'id' from jsonb_array_elements(m.options) elem2 where (elem2->>'is_correct')::boolean is true limit 1)
  into v_is_correct, v_explanation, v_correct_option_id
  from public.post_mcqs m,
  jsonb_array_elements(m.options) elem
  where m.post_id = p_post_id and elem->>'id' = p_option_id;

  select jsonb_build_object(
    'success', true,
    'selected_option_id', p_option_id,
    'correct_option_id', coalesce(v_correct_option_id, ''),
    'is_correct', coalesce(v_is_correct, false),
    'explanation', coalesce(v_explanation, '')
  ) into v_result;

  return v_result;
end;
$$;

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

-- 8. Optimized RPC Feed Function (Returns Lightweight Previews ONLY)
create or replace function public.get_feed_posts(
  p_user_id uuid default null,
  p_community_id text default null,
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
      p.likes,
      p.comments,
      p.shares,
      p.created_at,
      p.visibility,
      p.comments_enabled,
      p.shares_enabled,
      p.status,
      -- Author details
      jsonb_build_object(
        'username', coalesce(prof.username, 'Anonymous'),
        'avatar_url', coalesce(prof.avatar_url, prof.profile_photo, '')
      ) as author_profile,
      -- Check if current user liked/bookmarked
      case when p_user_id is not null then
        exists(select 1 from public.post_likes pl where pl.post_id = p.id and pl.user_id = p_user_id)
      else false end as is_liked,
      case when p_user_id is not null then
        exists(select 1 from public.post_bookmarks pb where pb.post_id = p.id and pb.user_id = p_user_id)
      else false end as is_bookmarked,
      -- MCQ Data if applicable
      case when p.post_type = 'mcq' then
        (
          select jsonb_build_object(
            'question', m.question,
            'options', m.options,
            'explanation', m.explanation,
            'timer_seconds', m.timer_seconds,
            'difficulty', m.difficulty,
            'category', m.category,
            'xp_reward', m.xp_reward,
            'user_selected_option_id', (select mv.option_id from public.post_mcq_votes mv where mv.post_id = p.id and mv.user_id = p_user_id limit 1)
          )
          from public.post_mcqs m where m.post_id = p.id
        )
      else null end as mcq_data,
      -- Poll Data if applicable
      case when p.post_type = 'poll' then
        (
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
          )
          from public.post_polls pol where pol.post_id = p.id
        )
      else null end as poll_data,
      -- Question Data if applicable
      case when p.post_type = 'question' then
        (
          select jsonb_build_object(
            'question', q.question,
            'context', q.context,
            'optional_media_url', q.optional_media_url
          )
          from public.post_questions q where q.post_id = p.id
        )
      else null end as question_data
    from public.posts p
    left join public.profiles prof on prof.id = p.user_id
    where (p_community_id is null or p.community_id = p_community_id)
      and p.status = 'published'
    order by p.created_at desc
    limit p_limit offset p_offset
  ) post_item;

  return coalesce(v_posts, '[]'::jsonb);
end;
$$;
