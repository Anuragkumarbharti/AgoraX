-- 202607090015_study_vault.sql
-- Study Vault notes, books, student reviews, progress tracking, and RLS policies

create table public.study_vault_items (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  subtitle text not null,
  description text not null,
  cover_image text not null,
  category text not null,
  course text not null,
  semester text not null,
  branch text not null,
  university text not null,
  language text not null,
  tags text[] not null default '{}',
  author_name text not null,
  publisher text not null,
  edition text not null,
  isbn text,
  pages integer not null check (pages > 0),
  file_type text not null,
  pdf_url text not null,
  thumbnail text not null,
  preview_pages_count integer not null default 3 check (preview_pages_count >= 0),
  selling_price numeric(10, 2) not null default 0.00 check (selling_price >= 0.00),
  license text not null,
  copyright_declaration boolean not null default false,
  is_official boolean not null default false,
  required_vip_level integer not null default 0 check (required_vip_level between 0 and 7),
  seller_id uuid references public.profiles(id) on delete cascade not null,
  seller_name text not null,
  seller_avatar text not null,
  rating numeric(3, 2) default 0.00 check (rating between 0.00 and 5.00),
  reviews_count integer default 0 check (reviews_count >= 0),
  views_count integer default 0 check (views_count >= 0),
  downloads_count integer default 0 check (downloads_count >= 0),
  purchases_count integer default 0 check (purchases_count >= 0),
  watermark_text text default 'Creaniaa',
  is_featured boolean default false,
  status text default 'Pending' check (status in ('Approved', 'Pending', 'Rejected')),
  admin_comment text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.study_reviews (
  id uuid default gen_random_uuid() primary key,
  book_id uuid references public.study_vault_items(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  user_name text not null,
  user_avatar text not null,
  rating integer not null check (rating between 1 and 5),
  review_text text not null,
  helpful_count integer default 0 check (helpful_count >= 0),
  is_reported boolean default false,
  review_images text[] default '{}',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.reading_history (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  book_id uuid references public.study_vault_items(id) on delete cascade not null,
  last_page_read integer default 1 check (last_page_read >= 1),
  reading_progress numeric(3, 2) default 0.00 check (reading_progress between 0.00 and 1.00),
  total_reading_duration_seconds numeric(10, 2) default 0.00,
  bookmarked_pages integer[] default '{}',
  highlights jsonb default '{}'::jsonb,
  personal_notes jsonb default '{}'::jsonb,
  last_read_time timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(user_id, book_id)
);

-- Row Level Security (RLS) Policies
alter table public.study_vault_items enable row level security;
create policy "Anyone can view approved items" on public.study_vault_items for select using (status = 'Approved');
create policy "Users can upload resources" on public.study_vault_items for insert with check (auth.uid() = seller_id);

alter table public.study_reviews enable row level security;
create policy "Anyone can view reviews" on public.study_reviews for select using (true);

alter table public.reading_history enable row level security;
create policy "Users can modify their own history" on public.reading_history for all using (auth.uid() = user_id);
