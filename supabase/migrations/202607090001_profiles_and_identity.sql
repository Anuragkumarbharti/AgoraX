-- ==========================================================================
-- Consolidated Supabase Migration Module 01: 202607090001_profiles_and_identity.sql
-- Authoritative baseline schema, functions, triggers, policies, and seeds.
-- ==========================================================================

-- 2. Profiles table
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  uid bigint unique not null default public.generate_unique_uid(),
  username text unique not null,
  email text unique,
  phone text unique,
  avatar_url text,
  profile_photo text,
  cover_photo text,
  dob date,
  age integer,
  gender text,
  state text,
  city text,
  profession text,
  education text,
  website text,
  instagram text,
  youtube text,
  twitter text,
  interests text[] default '{}',
  level integer default 1 check (level >= 1),
  experience integer default 0 check (experience >= 0),
  followers integer default 0 check (followers >= 0),
  following integer default 0 check (following >= 0),
  followers_count integer default 0 check (followers_count >= 0),
  following_count integer default 0 check (following_count >= 0),
  friends_count integer default 0 check (friends_count >= 0),
  rooms_joined integer default 0 check (rooms_joined >= 0),
  events_joined integer default 0 check (events_joined >= 0),
  bio text,
  country text,
  language text default 'en',
  avatar_frame text default 'Normal',
  profile_theme text default 'Default',
  vip_level integer default 0 check (vip_level between 0 and 7),
  novel_level integer default 0 check (novel_level between 0 and 7),
  vip_expiry timestamp with time zone,
  novel_expiry timestamp with time zone,
  badges text[] default '{}',
  progress_metadata jsonb default '{}'::jsonb,
  google_provider_id text unique,
  apple_provider_id text unique,
  email_verified boolean default false,
  verification_timestamp timestamp with time zone,
  verification_method text,
  last_verification_date timestamp with time zone,
  selected_study_category text,
  category_lock_expiry timestamp with time zone,
  career_name text,
  career_xp integer default 0,
  theme_preference text default 'dark',
  tag_lights text[] default '{}',
  r_tags text[] default '{}',
  showcased_badges text[] default '{}',
  tag_system jsonb default '{}'::jsonb,
  official_community_cooldown_until timestamp with time zone,
  total_stars_received integer default 0 check (total_stars_received >= 0),
  total_stars_gifted integer default 0 check (total_stars_gifted >= 0),
  verified boolean default false not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create trigger set_updated_at
before update on public.profiles
for each row execute function public.update_updated_at_column();

-- Realtime registration
do $$
begin
  alter publication supabase_realtime add table public.profiles;
exception when others then
  raise notice 'Table profiles already in supabase_realtime publication';
end;
$$;

-- 202607090002_wallets_and_transactions.sql
-- Wallets, transactions ledgers, auto-wallet initializer trigger, and RLS policies

create table public.wallets (
  id uuid references public.profiles(id) on delete cascade primary key,
  coins_balance integer default 0 check (coins_balance >= 0),
  inr_balance numeric(10, 2) default 0.00 check (inr_balance >= 0.00),
  withdrawable_balance numeric(10, 2) default 0.00 check (withdrawable_balance >= 0.00),
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

create trigger tr_on_profile_created_wallet
after insert on public.profiles
for each row execute function public.initialize_user_wallet();

create table public.inventory (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  item_id text references public.store_items(id) on delete cascade,
  is_equipped boolean default false,
  unlocked_at timestamp with time zone default timezone('utc'::text, now()) not null,
  expires_at timestamp with time zone,
  unique(user_id, item_id)
);

create table public.purchase_history (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  item_id text not null,
  item_type text not null check (item_type in ('VIP', 'Novel', 'Book', 'Cosmetic')),
  price numeric(10, 2) not null,
  currency text not null check (currency in ('INR', 'Coins')),
  duration text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

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

insert into public.profiles (id, uid, username, level)
values ('00000000-0000-0000-0000-000000000000', 0, 'creania_system', 1)
on conflict (id) do nothing;

-- 202607090006_voice_rooms.sql
-- Voice rooms tables, settings, members, moderators, seats, sync triggers, RLS, and realtime channels

create table public.rooms (
  id text primary key,
  name text not null,
  room_name text,
  username text unique not null constraint check_room_username check (username ~ '^@[a-z0-9_]{3,30}$'),
  description text,
  category text not null,
  language text not null default 'English',
  tags text[] default '{}'::text[] not null,
  rules text[] default '{}'::text[] not null,
  host_id uuid references public.profiles(id) on delete cascade not null,
  room_owner uuid references public.profiles(id),
  status text default 'live' check (status in ('live', 'scheduled', 'ended')),
  start_time timestamp with time zone default timezone('utc'::text, now()) not null,
  end_time timestamp with time zone,
  total_members integer default 0 check (total_members >= 0),
  total_speakers integer default 0 check (total_speakers >= 0),
  total_listeners integer default 0 check (total_listeners >= 0),
  peak_members integer default 0 check (peak_members >= 0),
  visibility text default 'public' check (visibility in ('everyone', 'followers_only', 'paid_members', 'vip_only', 'password_required', 'password', 'public', 'private', 'community', 'study', 'gaming', 'music', 'podcast', 'event')),
  community_id text references public.communities(id) on delete cascade,
  recording_status text default 'inactive' check (recording_status in ('inactive', 'recording', 'paused', 'ready')),
  level_requirement integer default 1 check (level_requirement >= 1),
  vip_requirement integer default 0 check (vip_requirement >= 0),
  verification_requirement boolean default false not null,
  livekit_room_name text unique not null,
  avatar text,
  banner text,
  room_banner text,
  is_permanent boolean default false not null,
  room_cover_url text,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  co_host_can_edit_cover boolean default false not null,
  admin_can_edit_cover boolean default false not null,
  room_level integer default 1 not null,
  room_xp integer default 0 not null,
  today_room_xp integer default 0 not null,
  online_members integer default 0 not null,
  total_room_gifts integer default 0 not null,
  today_room_gifts integer default 0 not null,
  total_room_stars integer default 0 not null,
  today_room_stars integer default 0 not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.room_members (
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  role text default 'Listener' check (role in ('Host', 'Co-Host', 'Moderator', 'Speaker', 'Listener', 'Guest')),
  is_muted boolean default false not null,
  has_raised_hand boolean default false not null,
  joined_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, user_id)
);

create table public.room_moderators (
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  assigned_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, user_id)
);

create table public.room_messages (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  content text not null,
  message_type text default 'text' check (message_type in ('text', 'system', 'gift', 'banner')),
  metadata jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.room_seats (
  room_id text references public.rooms(id) on delete cascade not null,
  seat_index integer not null check (seat_index between 0 and 9),
  role text default 'Listener' check (role in ('Host', 'Co-Host', 'Speaker', 'Listener')),
  user_id uuid references public.profiles(id) on delete set null,
  seat_number integer,
  avatar text,
  avatar_frame text,
  username text,
  level integer,
  noble_level integer,
  vip_level integer,
  mic_status text default 'unmuted' not null,
  is_speaking boolean default false not null,
  seat_total_gifts integer default 0 not null,
  seat_total_stars integer default 0 not null,
  last_gift_time timestamp with time zone,
  primary key (room_id, seat_index)
);

create table public.room_seat_applications (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  applicant_id uuid references public.profiles(id) on delete cascade not null,
  status text default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (room_id, applicant_id)
);

create table public.room_activity_events (
  event_id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  event_type text not null,
  user_id uuid references public.profiles(id) on delete cascade,
  username text,
  seat_number integer,
  target_user_id uuid references public.profiles(id) on delete cascade,
  target_username text,
  message text not null,
  metadata jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.room_bans (
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  banned_by uuid references public.profiles(id) on delete set null,
  reason text,
  expires_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, user_id)
);

create table public.room_activity_logs (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade,
  action_type text not null,
  details text,
  moderator_id uuid references public.profiles(id) on delete set null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create trigger tr_sync_room_seats_user_profile
before insert or update of user_id on public.room_seats
for each row execute function public.sync_room_seats_user_profile();

create trigger tr_sync_profile_updates_to_seats
after update of username, avatar_url, level, avatar_frame, vip_level, novel_level on public.profiles
for each row execute function public.sync_profile_updates_to_seats();

create table public.room_member_heartbeats (
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  last_seen_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, user_id)
);

-- 202607090009_gifting_and_stars.sql
-- Gift logs, seat-specific gift items, stars calculations, send_room_gift RPC, RLS, and realtime channels

create table public.room_gifts (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  receiver_id uuid references public.profiles(id) on delete cascade not null,
  gift_name text not null,
  coins_value integer not null check (coins_value >= 0),
  quantity integer default 1 check (quantity >= 1),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.gift_history (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  receiver_id uuid references public.profiles(id) on delete cascade not null,
  item_id text not null,
  item_type text not null check (item_type in ('VIP', 'Novel', 'Book', 'Cosmetic', 'VirtualGift')),
  quantity integer default 1 check (quantity >= 1),
  coins_value integer default 0 check (coins_value >= 0),
  is_anonymous boolean default false,
  message text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

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

-- 202607090011_messaging_and_notifications.sql
-- Private messaging (E2EE), push notification logs, mention triggers, and RLS policies

create table public.messages (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  receiver_id uuid references public.profiles(id) on delete cascade,
  room_id uuid,
  encrypted_content text not null,
  nonce text,
  is_private boolean default false,
  message_status text default 'sent' check (message_status in ('sent', 'delivered', 'seen')),
  delivered_at timestamp with time zone,
  seen_at timestamp with time zone,
  reply_to uuid references public.messages(id) on delete set null,
  edited_at timestamp with time zone,
  deleted_for_me uuid[] default '{}',
  deleted_for_everyone boolean default false,
  expires_at timestamp with time zone,
  media_type text default 'text' check (media_type in ('text', 'image', 'video', 'audio', 'document')),
  media_url text,
  thumbnail text,
  reactions jsonb default '[]'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.notifications (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  title text not null,
  body text not null,
  type text not null,
  is_read boolean default false,
  payload jsonb default '{}'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create trigger check_profile_restricted_columns
before update on public.profiles
for each row execute function public.check_profile_restricted_columns_update();

create trigger trigger_profile_rebuild_tag_system
after insert or update of level, vip_level, vip_expiry, novel_level, novel_expiry, r_tags, verified, showcased_badges
on public.profiles
for each row execute procedure public.on_profile_rebuild_tag_system();

-- Rebuild all profiles
do $$
declare
  r record;
begin
  for r in select id from public.profiles loop
    perform public.rebuild_user_tag_system(r.id);
  end loop;
end;
$$;

-- 202607090013_moderation_and_auditing.sql
-- Administrative roles, user reports, bans ledger, security auditing, and is_admin helper

create table public.admins (
  id uuid references public.profiles(id) on delete cascade primary key,
  role text not null check (role in ('SuperAdmin', 'Moderator', 'Support')),
  assigned_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.reports (
  id uuid default gen_random_uuid() primary key,
  reporter_id uuid references public.profiles(id) on delete cascade not null,
  reported_user_id uuid references public.profiles(id) on delete cascade,
  resource_type text not null check (resource_type in ('user', 'book', 'message', 'room')),
  resource_id text not null,
  reason text not null,
  status text default 'Open' check (status in ('Open', 'Reviewed', 'Resolved')),
  admin_comment text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.bans (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  banned_by uuid references public.admins(id) on delete set null,
  reason text not null,
  expires_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.audit_logs (
  id uuid default gen_random_uuid() primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  details jsonb default '{}'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 202607090014_analytics_and_sessions.sql
-- Analytics, login metrics, active device sessions, and RLS policies

create table public.user_activity (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  activity_type text not null,
  duration_seconds integer,
  metadata jsonb default '{}'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.login_history (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  ip_address text,
  user_agent text,
  device_id text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.device_sessions (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  device_id text not null,
  device_name text,
  os_version text,
  push_token text,
  is_active boolean default true,
  last_active_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(user_id, device_id)
);

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

-- 202607090017_add_ban_status_to_profiles.sql
-- Add status, is_banned, and ban_reason columns to public.profiles

alter table public.profiles 
add column if not exists status text default 'active' check (status in ('active', 'suspended', 'banned')),
add column if not exists is_banned boolean default false,
add column if not exists ban_reason text;

-- 202607090018_prevent_profile_deletion.sql
-- Table-level audit logging, admin-only deletion, and unique constraints

-- 1. Create account audit logs table
create table if not exists public.account_audit_logs (
  id uuid default gen_random_uuid() primary key,
  event_time timestamp with time zone default now() not null,
  target_table text not null,
  operation text not null,
  actor_id uuid,
  record_id uuid not null,
  old_data jsonb,
  new_data jsonb,
  reason text
);

-- 3. Attach audit trigger to public.profiles
drop trigger if exists audit_profiles_trigger on public.profiles;

create trigger audit_profiles_trigger
after insert or update or delete on public.profiles
for each row execute function public.log_profile_changes();

-- 4. Attach audit trigger to auth.users
drop trigger if exists audit_users_trigger on auth.users;

create trigger audit_users_trigger
after insert or update or delete on auth.users
for each row execute function public.log_profile_changes();

-- 5. Drop owner-based profile delete policy and restrict to admin users only
drop policy if exists "Allow delete access to owner" on public.profiles;

drop policy if exists "Allow delete access to admins only" on public.profiles;

-- 6. Enforce unique constraint on profiles.id
alter table public.profiles drop constraint if exists profiles_id_key;

alter table public.profiles add constraint profiles_id_key unique (id);

create table if not exists public.user_vip (
  user_id uuid references public.profiles(id) on delete cascade primary key,
  level int references public.vip_plans(level) not null,
  start_date timestamp with time zone default now() not null,
  expiry_date timestamp with time zone not null,
  is_active boolean default true not null
);

create table if not exists public.user_novel (
  user_id uuid references public.profiles(id) on delete cascade primary key,
  level int references public.novel_plans(level) not null,
  start_date timestamp with time zone default now() not null,
  expiry_date timestamp with time zone not null,
  is_active boolean default true not null
);

create table if not exists public.purchases (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  product_name text not null,
  category text not null, -- 'VIP', 'Novel', 'Coins'
  amount numeric not null,
  final_amount numeric not null,
  payment_method text not null,
  status text not null, -- 'Success', 'Failed', 'Refunded'
  duration text not null,
  created_at timestamp with time zone default now() not null,
  expiry_date timestamp with time zone
);

-- 2. Add columns to profiles for compiled assets
alter table public.profiles add column if not exists membership_assets jsonb default '{}'::jsonb;

drop trigger if exists profile_membership_change_trigger on public.profiles;

create trigger profile_membership_change_trigger
before insert or update of vip_level, novel_level on public.profiles
for each row execute function public.on_profile_membership_change();

drop trigger if exists sync_vip_to_profile_trigger on public.user_vip;

create trigger sync_vip_to_profile_trigger
after insert or update on public.user_vip
for each row execute function public.sync_user_membership_tables_to_profile();

drop trigger if exists sync_novel_to_profile_trigger on public.user_novel;

create trigger sync_novel_to_profile_trigger
after insert or update on public.user_novel
for each row execute function public.sync_user_membership_tables_to_profile();

-- 9. Seed base plans and assets (Levels: VIP 1, VIP 2, Novel 1)
insert into public.vip_plans (level, name, base_price_inr, benefits)
values 
  (1, 'VIP Level 1', 99.0, array['VIP Identity Tag', 'VIP Avatar Frame', 'VIP Name Glow', 'VIP Chat Bubble', 'VIP Entrance Effect']),
  (2, 'VIP Level 2', 199.0, array['Premium Animated Frame', 'Premium Entrance Animation', 'Premium Name Glow', 'Premium Chat Bubble'])
on conflict (level) do update
set name = excluded.name, base_price_inr = excluded.base_price_inr, benefits = excluded.benefits;

insert into public.novel_plans (level, name, base_price_inr, benefits)
values 
  (1, 'Novel Level 1', 199.0, array['Novel Identity Tag', 'Novel Avatar Frame', 'Novel Name Glow', 'Novel Chat Bubble'])
on conflict (level) do update
set name = excluded.name, base_price_inr = excluded.base_price_inr, benefits = excluded.benefits;

-- Seed assets for VIP 1
insert into public.vip_assets (asset_type, asset_url, animation_type, rarity, level_required, display_priority)
values
  ('avatar_frame', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_1_frame.png', 'pulse', 'Rare', 1, 10),
  ('chat_bubble', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_1_bubble.png', 'static', 'Rare', 1, 10),
  ('name_glow', '#2563EB', 'glow', 'Rare', 1, 10),
  ('identity_tag', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/badges/vip_1_tag.png', 'static', 'Rare', 1, 10),
  ('profile_theme', 'royal_blue', 'static', 'Rare', 1, 10)
on conflict do nothing;

-- Seed assets for VIP 2
insert into public.vip_assets (asset_type, asset_url, animation_type, rarity, level_required, display_priority)
values
  ('avatar_frame', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_frame.webp', 'lottie', 'Epic', 2, 20),
  ('chat_bubble', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_bubble.png', 'animated', 'Epic', 2, 20),
  ('name_glow', '#8B5CF6', 'glow_animated', 'Epic', 2, 20),
  ('identity_tag', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/badges/vip_2_tag.png', 'animated', 'Epic', 2, 20),
  ('profile_theme', 'amethyst_purple', 'animated', 'Epic', 2, 20),
  ('background_effect', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_bg.jpg', 'particle', 'Epic', 2, 20)
on conflict do nothing;

-- Seed assets for Novel 1
insert into public.novel_assets (asset_type, asset_url, animation_type, rarity, level_required, display_priority)
values
  ('avatar_frame', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/novel_1_frame.webp', 'static', 'Rare', 1, 15),
  ('chat_bubble', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/novel_1_bubble.png', 'static', 'Rare', 1, 15),
  ('name_glow', '#3B82F6', 'glow', 'Rare', 1, 15),
  ('identity_tag', 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/badges/novel_1_tag.png', 'static', 'Rare', 1, 15),
  ('profile_theme', 'astral_blue', 'static', 'Rare', 1, 15)
on conflict do nothing;

-- 202607090020_enterprise_entitlement_system.sql
-- Enterprise Supabase Backend Driven VIP, Novel, Asset, Purchase & Entitlement System

-- 1. Drop existing triggers & functions that will be replaced
drop trigger if exists profile_membership_change_trigger on public.profiles;

drop function if exists public.on_profile_membership_change() cascade;

drop function if exists public.sync_user_membership_tables_to_profile() cascade;

create table public.cosmetic_assets (
  asset_id uuid default gen_random_uuid() primary key,
  name text not null,
  type text not null check (type in ('avatar_frame', 'profile_frame', 'entry_effect', 'exit_effect', 'chat_bubble', 'profile_theme', 'name_glow', 'identity_tag', 'showcase_badge', 'profile_background')),
  category text not null check (category in ('VIP', 'Novel', 'General', 'Community')),
  version integer default 1 not null,
  cdn_url text not null,
  preview_url text,
  thumbnail_url text,
  animation_url text,
  required_membership text not null check (required_membership in ('VIP', 'Novel', 'None')),
  required_level integer default 0,
  enabled boolean default true not null,
  priority integer default 0 not null,
  visibility text default 'Public' not null check (visibility in ('Public', 'Hidden')),
  expiry_rule text default 'Permanent' not null check (expiry_rule in ('Permanent', 'Rental', 'Limited')),
  created_at timestamp with time zone default now() not null
);

create table public.inventory (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  asset_id uuid references public.cosmetic_assets(asset_id) on delete cascade not null,
  purchase_source text not null check (purchase_source in ('Purchase', 'VIP Membership', 'Novel Membership', 'Admin Grant')),
  purchase_date timestamp with time zone default now() not null,
  expires_at timestamp with time zone,
  status text default 'Active' not null check (status in ('Active', 'Expired')),
  is_equipped boolean default false not null,
  last_equipped_at timestamp with time zone,
  unique(user_id, asset_id)
);

create table public.subscriptions (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  membership_type text not null check (membership_type in ('VIP', 'Novel')),
  level integer not null,
  purchase_date timestamp with time zone default now() not null,
  activation_date timestamp with time zone default now() not null,
  expiry_date timestamp with time zone not null,
  auto_renewal boolean default true not null,
  status text default 'Active' not null check (status in ('Active', 'Expired')),
  unique(user_id, membership_type)
);

drop trigger if exists tr_on_profile_membership_change on public.profiles;

create trigger tr_on_profile_membership_change
before update of vip_level, novel_level on public.profiles
for each row execute function public.on_profile_vip_novel_update();

-- 12. Seed Cosmetic Assets
insert into public.cosmetic_assets (name, type, category, version, cdn_url, required_membership, required_level, priority)
values
  -- VIP 1 Assets
  ('VIP 1 Avatar Frame', 'avatar_frame', 'VIP', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_1_frame.png', 'VIP', 1, 10),
  ('VIP 1 Chat Bubble', 'chat_bubble', 'VIP', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_1_bubble.png', 'VIP', 1, 10),
  ('VIP 1 Name Glow', 'name_glow', 'VIP', 1, '#2563EB', 'VIP', 1, 10),
  ('VIP 1 Identity Tag', 'identity_tag', 'VIP', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/badges/vip_1_tag.png', 'VIP', 1, 10),
  ('VIP 1 Profile Theme', 'profile_theme', 'VIP', 1, 'royal_blue', 'VIP', 1, 10),
  ('VIP 1 Entry Effect', 'entry_effect', 'VIP', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/effects/vip_1_entry.mp4', 'VIP', 1, 10),

  -- VIP 2 Assets
  ('VIP 2 Avatar Frame', 'avatar_frame', 'VIP', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_frame.webp', 'VIP', 2, 20),
  ('VIP 2 Chat Bubble', 'chat_bubble', 'VIP', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_bubble.png', 'VIP', 2, 20),
  ('VIP 2 Name Glow', 'name_glow', 'VIP', 1, '#8B5CF6', 'VIP', 2, 20),
  ('VIP 2 Identity Tag', 'identity_tag', 'VIP', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/badges/vip_2_tag.png', 'VIP', 2, 20),
  ('VIP 2 Profile Theme', 'profile_theme', 'VIP', 1, 'amethyst_purple', 'VIP', 2, 20),
  ('VIP 2 Background Effect', 'profile_background', 'VIP', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_bg.jpg', 'VIP', 2, 20),
  ('VIP 2 Entry Effect', 'entry_effect', 'VIP', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/effects/vip_2_entry.mp4', 'VIP', 2, 20),

  -- Novel 1 Assets
  ('Novel 1 Avatar Frame', 'avatar_frame', 'Novel', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/novel_1_frame.webp', 'Novel', 1, 15),
  ('Novel 1 Chat Bubble', 'chat_bubble', 'Novel', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/novel_1_bubble.png', 'Novel', 1, 15),
  ('Novel 1 Name Glow', 'name_glow', 'Novel', 1, '#3B82F6', 'Novel', 1, 15),
  ('Novel 1 Identity Tag', 'identity_tag', 'Novel', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/badges/novel_1_tag.png', 'Novel', 1, 15),
  ('Novel 1 Profile Theme', 'profile_theme', 'Novel', 1, 'astral_blue', 'Novel', 1, 15),
  ('Novel 1 Entry Effect', 'entry_effect', 'Novel', 1, 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/effects/novel_1_entry.mp4', 'Novel', 1, 15)
on conflict do nothing;

-- 202607090021_fix_entitlement_pipeline.sql
-- ROOT CAUSE FIX: Unified purchase → entitlement → inventory → asset → auto-equip → tag pipeline
--
-- ROOT CAUSES IDENTIFIED:
-- 1. rebuild_user_tag_system reads from vip_assets/novel_assets tables, but purchases
--    write to cosmetic_assets. These are two separate tables = purchases never produce tags.
-- 2. on_profile_vip_novel_update is a BEFORE trigger calling recompute_user_entitlements
--    which itself updates profiles → infinite recursion / updates are silently discarded.
-- 3. recompute_user_entitlements computes profile vip_level from subscriptions table,
--    but rebuild_user_tag_system reads vip_level from profiles — causing a race condition
--    where the tag system runs before the profile row is committed.
-- 4. No automatic expiry enforcement (no pg_cron, no row-level trigger on subscriptions).
--
-- FIX STRATEGY:
-- A. Rewrite rebuild_user_tag_system to read identity tag URLs from cosmetic_assets (not vip_assets).
-- B. Fix the trigger to be AFTER (not BEFORE) and add a guard to prevent recursion.
-- C. Rewrite recompute_user_entitlements to pass VIP/Novel levels as parameters (not re-read from profiles).
-- D. Add an AFTER INSERT OR UPDATE trigger on subscriptions to auto-run entitlements.
-- E. Add an AFTER INSERT OR UPDATE on purchases to auto-run entitlements.

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1: Drop all broken triggers to start clean
-- ─────────────────────────────────────────────────────────────────────────────
drop trigger if exists tr_on_profile_membership_change on public.profiles;

drop function if exists public.on_profile_vip_novel_update() cascade;

-- AFTER trigger (was BEFORE — this was the recursion bug)
drop trigger if exists tr_on_profile_membership_change on public.profiles;

create trigger tr_on_profile_membership_change
after update of vip_level, novel_level on public.profiles
for each row execute function public.on_profile_vip_novel_update();

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 9: Backfill — sync existing vip_assets/novel_assets into cosmetic_assets.
-- Maps legacy asset_type names to the valid cosmetic_assets type check values:
--   background_effect → profile_background
--   entry_effect      → entry_effect      (already valid)
--   exit_effect       → exit_effect       (already valid)
--   avatar_frame      → avatar_frame      (already valid)
--   chat_bubble       → chat_bubble       (already valid)
--   name_glow         → name_glow         (already valid)
--   identity_tag      → identity_tag      (already valid)
--   profile_theme     → profile_theme     (already valid)
--   showcase_badge    → showcase_badge    (already valid)
-- Any unknown types are skipped via WHERE filter.
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.cosmetic_assets
  (name, type, category, version, cdn_url, required_membership, required_level, priority)
select
  'VIP ' || va.level_required || ' ' || va.asset_type,
  -- Map legacy type name → cosmetic_assets check constraint value
  case va.asset_type
    when 'background_effect' then 'profile_background'
    else va.asset_type
  end,
  'VIP',
  1,
  va.asset_url,
  'VIP',
  va.level_required,
  va.level_required * 10
from public.vip_assets va
where va.enabled = true
  -- Only insert types that are valid in the cosmetic_assets check constraint
  and case va.asset_type
    when 'background_effect' then 'profile_background'
    else va.asset_type
  end in ('avatar_frame','profile_frame','entry_effect','exit_effect','chat_bubble',
           'profile_theme','name_glow','identity_tag','showcase_badge','profile_background')
on conflict do nothing;

insert into public.cosmetic_assets
  (name, type, category, version, cdn_url, required_membership, required_level, priority)
select
  'Novel ' || na.level_required || ' ' || na.asset_type,
  case na.asset_type
    when 'background_effect' then 'profile_background'
    else na.asset_type
  end,
  'Novel',
  1,
  na.asset_url,
  'Novel',
  na.level_required,
  na.level_required * 10
from public.novel_assets na
where na.enabled = true
  and case na.asset_type
    when 'background_effect' then 'profile_background'
    else na.asset_type
  end in ('avatar_frame','profile_frame','entry_effect','exit_effect','chat_bubble',
           'profile_theme','name_glow','identity_tag','showcase_badge','profile_background')
on conflict do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 4: Backfill — run rebuild_user_tag_system for all existing users so
--         their tag_system reflects the current vip_level/novel_level immediately.
-- ─────────────────────────────────────────────────────────────────────────────
do $$
declare v_user record;
begin
  for v_user in select id from public.profiles loop
    begin
      perform public.rebuild_user_tag_system(v_user.id);
    exception when others then
      raise notice 'rebuild_user_tag_system failed for %: %', v_user.id, sqlerrm;
    end;
  end loop;
end $$;

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

-- 2. Alter profiles table to add community leave time and next rejoin time (cooldown)
alter table public.profiles add column if not exists community_leave_time timestamp with time zone;

alter table public.profiles add column if not exists community_next_join_time timestamp with time zone;

-- 3. Create community_memberships table
create table if not exists public.community_memberships (
  id uuid primary key default gen_random_uuid(),
  community_id text references public.communities(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  role text not null default 'member', -- 'owner', 'co_owner', 'admin', 'member'
  joined_at timestamp with time zone default now() not null,
  joined_by uuid references public.profiles(id),
  join_method text not null default 'auto_join', -- 'auto_join', 'approved', 'creator'
  contribution integer default 0 not null,
  exp_contribution integer default 0 not null,
  activity_score integer default 0 not null,
  last_active_at timestamp with time zone default now() not null,
  constraint unique_user_membership unique (user_id) -- ONE COMMUNITY RULE!
);

-- 4. Create community_applications table
create table if not exists public.community_applications (
  id uuid primary key default gen_random_uuid(),
  community_id text references public.communities(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  status text not null default 'pending', -- 'pending', 'approved', 'rejected', 'blocked'
  introduction text,
  reason text,
  preferred_language text,
  optional_message text,
  created_at timestamp with time zone default now() not null,
  processed_at timestamp with time zone,
  processed_by uuid references public.profiles(id),
  constraint unique_pending_app unique (community_id, user_id)
);

-- 5. Seed memberships for existing communities to maintain backwards compatibility
insert into public.community_memberships (community_id, user_id, role, join_method)
select c.id, p.id, 'member', 'auto_join'
from public.communities c
cross join lateral unnest(c.members) as mem_id
join public.profiles p on p.id::text = mem_id
on conflict (user_id) do nothing;

-- 2. Create community daily limits table
create table if not exists public.community_member_daily_limits (
  community_id text references public.communities(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  day date default current_date not null,
  normal_exp integer default 0 not null,
  gold_gift_exp integer default 0 not null,
  star_gift_exp integer default 0 not null,
  primary key (community_id, user_id, day)
);

-- 3. Create community EXP transactions audit log
create table if not exists public.community_exp_transactions (
  id uuid primary key default gen_random_uuid(),
  community_id text references public.communities(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  source_type text not null, -- 'normal', 'gold_gift', 'star_gift'
  amount integer not null,
  reference_id text,
  created_at timestamp with time zone default now() not null
);

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

-- 3. Create community event participants table
create table if not exists public.community_event_participants (
  event_id uuid references public.community_events(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  registered_at timestamp with time zone default now() not null,
  primary key (event_id, user_id)
);

-- 4. Create community logs table
create table if not exists public.community_logs (
  id uuid primary key default gen_random_uuid(),
  community_id text references public.communities(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete set null,
  action_type text not null,
  description text not null,
  created_at timestamp with time zone default now() not null
);

-- 202607170008_community_identity_tag.sql
-- Add identity_tag to communities, enforce uniqueness, and use it in rebuild_user_tag_system.

-- 1. Add column and unique constraint
alter table public.communities add column if not exists identity_tag text;

alter table public.communities drop constraint if exists unique_community_identity_tag;

alter table public.communities add constraint unique_community_identity_tag unique (identity_tag);

-- Ensure public.communities.identity_tag column exists and is unique
alter table public.communities add column if not exists identity_tag text;

-- 2. Create user_levels table
create table if not exists public.user_levels (
  id uuid references public.profiles(id) on delete cascade primary key,
  level integer not null default 1 check (level >= 1 and level <= 60),
  xp integer not null default 0 check (xp >= 0),
  total_xp integer not null default 0 check (total_xp >= 0),
  today_earned_xp integer not null default 0 check (today_earned_xp >= 0),
  today_bonus_xp integer not null default 0 check (today_bonus_xp >= 0),
  weekly_xp integer not null default 0 check (weekly_xp >= 0),
  monthly_xp integer not null default 0 check (monthly_xp >= 0),
  last_xp_update timestamp with time zone default now(),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Backfill user_levels for existing profiles
insert into public.user_levels (id, level, xp, total_xp)
select id, level, experience, experience
from public.profiles
on conflict (id) do nothing;

-- 3. Create xp_history table
create table if not exists public.xp_history (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  event_type text not null,
  xp_gained integer not null check (xp_gained >= 0),
  metadata jsonb default '{}'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 5. Create task_progress table
create table if not exists public.task_progress (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  task_id text not null,
  task_type text not null check (task_type in ('daily', 'weekly', 'monthly', 'season')),
  cycle_key text not null, -- format: 'YYYY-MM-DD', 'YYYY-Wxx', 'YYYY-MM', or 'season_xx'
  current_count integer not null default 0 check (current_count >= 0),
  is_completed boolean not null default false,
  is_claimed boolean not null default false,
  completed_at timestamp with time zone,
  claimed_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (user_id, task_id, task_type, cycle_key)
);

-- 8. Create reward_claims table
create table if not exists public.reward_claims (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  source_type text not null check (source_type in ('level', 'task', 'checkin', 'achievement', 'loyalty', 'spin', 'community', 'event')),
  source_id text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (user_id, source_type, source_id)
);

-- 9. Create daily_limits table
create table if not exists public.daily_limits (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  date date not null default current_date,
  free_xp integer not null default 0 check (free_xp >= 0),
  bonus_xp integer not null default 0 check (bonus_xp >= 0),
  ad_count integer not null default 0 check (ad_count >= 0),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (user_id, date)
);

-- 10. Create checkin_history table
create table if not exists public.checkin_history (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  month_key text not null, -- YYYY-MM
  day_number integer not null check (day_number >= 1 and day_number <= 30),
  claimed_at timestamp with time zone default timezone('utc'::text, now()) not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (user_id, month_key, day_number)
);

create table if not exists public.achievement_progress (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  achievement_id text references public.achievements(achievement_id) on delete cascade not null,
  current_count integer not null default 0 check (current_count >= 0),
  is_completed boolean not null default false,
  is_claimed boolean not null default false,
  completed_at timestamp with time zone,
  claimed_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (user_id, achievement_id)
);

-- 14. Create spin_history log
create table if not exists public.spin_history (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  spin_type text not null check (spin_type in ('silver', 'gold', 'premium')),
  won_reward_id uuid references public.spin_rewards(id) on delete set null,
  won_reward_type text not null,
  won_amount integer not null default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 15. Create reward_logs table
create table if not exists public.reward_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  source_type text not null, -- task, level_up, spin, checkin, achievement, loyalty, community, event
  source_id text not null,
  reward_type text not null,
  amount integer not null default 0,
  cosmetic_id text,
  status text not null default 'Granted', -- Granted, Blocked, Failed
  reason text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 16. Create gift_xp_logs table
create table if not exists public.gift_xp_logs (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  receiver_id uuid references public.profiles(id) on delete cascade not null,
  gift_id text not null,
  xp_value integer not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create or replace trigger tr_sync_user_level_to_profile
after insert or update of level, xp on public.user_levels
for each row execute function public.sync_user_level_to_profile();

create or replace trigger tr_on_profile_created_levels
after insert on public.profiles
for each row execute function public.initialize_user_levels();

-- Premium Spin
insert into public.spin_rewards (spin_type, reward_type, amount, cosmetic_id, probability) values
('premium', 'silver', 5000, null, 0.30),
('premium', 'gold', 500, null, 0.20),
('premium', 'gold', 1000, null, 0.15),
('premium', 'frame', 1, 'Premium Avatar Frame', 0.10),
('premium', 'theme', 1, 'Premium Theme', 0.05),
('premium', 'xp', 500, null, 0.20)
on conflict do nothing;

-- 3. Create vault_items table
create table if not exists public.vault_items (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  asset_id uuid references public.asset_definitions(id) on delete cascade not null,
  quantity integer default 1 not null,
  status text default 'Unlocked' not null check (status in ('Locked', 'Unlocked', 'Activated', 'Expired', 'Consumed', 'Gifted', 'Transferred', 'Sold')),
  purchase_source text,
  purchase_date timestamp with time zone default now() not null,
  expires_at timestamp with time zone,
  activated_at timestamp with time zone,
  is_equipped boolean default false not null,
  last_equipped_at timestamp with time zone,
  custom_metadata jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  unique (user_id, asset_id)
);

-- 5. Create vault_item_history table (Audit Log Ledger)
create table if not exists public.vault_item_history (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  vault_item_id uuid references public.vault_items(id) on delete cascade not null,
  action_type text not null check (action_type in ('Received', 'Activated', 'Equipped', 'Unequipped', 'Expired', 'Consumed', 'Gifted', 'Transferred', 'Sold')),
  quantity integer default 1 not null,
  details jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null
);

-- 3. Create Gift Transactions Ledger Table
create table if not exists public.gift_transactions (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete set null,
  receiver_id uuid references public.profiles(id) on delete set null,
  room_id text,
  gift_id uuid references public.gift_catalog(id) on delete set null,
  stars_value numeric not null,
  quantity integer default 1,
  combo_count integer default 1,
  status text default 'Completed',
  created_at timestamptz default now()
);

-- 4. Create Gift Statistics Table
create table if not exists public.gift_statistics (
  user_id uuid references public.profiles(id) on delete cascade primary key,
  stars_sent_lifetime numeric default 0,
  stars_received_lifetime numeric default 0,
  highest_gift_value numeric default 0,
  highest_combo integer default 1,
  favorite_gift_id uuid references public.gift_catalog(id) on delete set null,
  favorite_receiver_id uuid references public.profiles(id) on delete set null,
  favorite_sender_id uuid references public.profiles(id) on delete set null,
  updated_at timestamptz default now()
);

-- 5. Create Gift Leaderboards Table
create table if not exists public.gift_leaderboards (
  user_id uuid references public.profiles(id) on delete cascade,
  type text not null check (type in ('gifter', 'receiver')),
  cycle text not null check (cycle in ('daily', 'weekly', 'monthly', 'lifetime')),
  cycle_key text not null,
  value numeric default 0,
  updated_at timestamptz default now(),
  primary key (user_id, type, cycle, cycle_key)
);

-- 9. Create Gift Notifications Table
create table if not exists public.gift_notifications (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade,
  title text not null,
  content text not null,
  status text default 'Unread',
  created_at timestamptz default now()
);

create table if not exists public.magic_reward_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete set null,
  gift_id uuid,
  cost_coins integer,
  payout_type text,
  multiplier integer,
  coins_back integer,
  silver_reward integer,
  vault_item_name text,
  created_at timestamptz default now()
);

-- 4. Create Vault Gift Logs Table
create table if not exists public.vault_gift_logs (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete set null,
  receiver_id uuid references public.profiles(id) on delete set null,
  room_id text,
  definition_id uuid,
  quantity integer default 1,
  created_at timestamptz default now()
);

-- 11. Create User Gifting History list views
create or replace view public.user_received_gifts as
select 
  t.id,
  t.sender_id,
  p_sender.username as sender_username,
  p_sender.avatar_url as sender_avatar,
  t.receiver_id,
  p_receiver.username as receiver_username,
  t.gift_id,
  c.name as gift_name,
  c.icon as gift_icon,
  t.stars_value,
  t.quantity,
  t.created_at
from public.gift_transactions t
join public.profiles p_sender on p_sender.id = t.sender_id
join public.profiles p_receiver on p_receiver.id = t.receiver_id
join public.gift_catalog c on c.id = t.gift_id;

create or replace view public.user_sent_gifts as
select 
  t.id,
  t.sender_id,
  p_sender.username as sender_username,
  t.receiver_id,
  p_receiver.username as receiver_username,
  p_receiver.avatar_url as receiver_avatar,
  t.gift_id,
  c.name as gift_name,
  c.icon as gift_icon,
  t.stars_value,
  t.quantity,
  t.created_at
from public.gift_transactions t
join public.profiles p_sender on p_sender.id = t.sender_id
join public.profiles p_receiver on p_receiver.id = t.receiver_id
join public.gift_catalog c on c.id = t.gift_id;

-- 202607200002_avatar_frames_novel_1_only.sql
-- Registers the avatar_frames table and sets Novel Level 1 as the
-- ONLY available frame. All other frames are marked isAvailable = false.
-- To restore later, UPDATE avatar_frames SET is_available = true WHERE id = '...';

-- ══════════════════════════════════════════════════════════════
-- 1. Create avatar_frames catalog table (if not exists)
-- ══════════════════════════════════════════════════════════════
create table if not exists public.avatar_frames (
  id            text        primary key,
  name          text        not null unique,
  type          text        not null default 'novel',   -- 'novel' | 'vip' | 'event' | 'free'
  level         int         not null default 1,
  asset_path    text        not null default '',
  rarity        text        not null default 'Common',
  is_available  boolean     not null default false,
  is_default    boolean     not null default false,
  created_at    timestamptz not null default now()
);

-- Create policies (safe — skips if already exists)
do $$ begin
  create policy "Read available frames"
    on public.avatar_frames for select
    using (is_available = true);
exception when duplicate_object then null;
end $$;

do $$ begin
  create policy "Admin manage frames"
    on public.avatar_frames for all
    using (auth.role() = 'service_role');
exception when duplicate_object then null;
end $$;

-- ══════════════════════════════════════════════════════════════
-- 2. Seed all frames — only Novel Level 1 is available
-- ══════════════════════════════════════════════════════════════
insert into public.avatar_frames (id, name, type, level, asset_path, rarity, is_available, is_default)
values
  -- ✅ ACTIVE
  ('novel_1',   'Novel Level 1',           'novel', 1, 'assets/avtarframes/novel/novel_1.png',  'Rare',      true,  false),

  -- ── DISABLED (restore by setting is_available = true) ──
  -- VIP Frames
  ('vip_1',     'Royal Frame',             'vip',   1, '',  'Rare',      false, false),
  ('vip_2',     'Neon Frame',              'vip',   2, '',  'Epic',      false, false),
  ('vip_3',     'Gold Glow Frame',         'vip',   3, '',  'Epic',      false, false),
  ('vip_4',     'Diamond Frame',           'vip',   4, '',  'Legendary', false, false),
  ('vip_5',     'Crystal Cyan Frame',      'vip',   5, '',  'Legendary', false, false),
  ('vip_6',     'Rainbow Frame',           'vip',   6, '',  'Mythic',    false, false),
  ('vip_7',     'Royal Crown',             'vip',   7, '',  'Mythic',    false, false),
  -- Novel Frames (2-7)
  ('novel_2',   'Galaxy Orbit',            'novel', 2, '',  'Mythic',    false, false),
  ('novel_3',   'Royal Gold Palace',       'novel', 3, '',  'Legendary', false, false),
  ('novel_4',   'Dragon Fire Frame',       'novel', 4, '',  'Limited',   false, false),
  ('novel_5',   'Phoenix Flame',           'novel', 5, '',  'Mythic',    false, false),
  ('novel_6',   'Celestial Sky Frame',     'novel', 6, '',  'Mythic',    false, false),
  ('novel_7',   'Cosmic Emperor',          'novel', 7, '',  'Mythic',    false, false),
  -- Free/Event
  ('free_none', 'Normal',                  'free',  0, '',  'Common',    true,  true ),
  ('free_explorer', 'Early Explorer Frame','free',  0, '',  'Rare',      false, false)
on conflict (id) do update set
  name         = excluded.name,
  is_available = excluded.is_available,
  asset_path   = excluded.asset_path,
  rarity       = excluded.rarity;

-- ══════════════════════════════════════════════════════════════
-- 3. Safety: disable any user_customizations that reference
--    frames that are no longer available (except Normal/Novel Level 1)
-- ══════════════════════════════════════════════════════════════
update public.user_customizations
set is_equipped = false
where type = 'Avatar Frame'
  and name not in ('Normal', 'Novel Level 1');

-- Create room_requests table if it doesn't exist
create table if not exists public.room_requests (
  id uuid default gen_random_uuid() primary key,
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  status text default 'pending' check (status in ('pending', 'accepted', 'rejected', 'demoted')),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (room_id, user_id)
);

-- Add active_room_id and presence_state to profiles if they do not exist
alter table public.profiles
  add column if not exists active_room_id text references public.rooms(id) on delete set null,
  add column if not exists presence_state text default 'Offline' check (presence_state in ('Online', 'In Room', 'Speaking', 'Idle', 'Background', 'Offline'));

-- Create user_sessions table
create table if not exists public.user_sessions (
  session_id text primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  device_id text not null,
  device_name text,
  os_version text,
  app_version text,
  platform text,
  ip text,
  login_time timestamp with time zone default timezone('utc'::text, now()) not null,
  last_seen timestamp with time zone default timezone('utc'::text, now()) not null,
  socket_id text,
  online_status text default 'Online' check (online_status in ('Online', 'In Room', 'Speaking', 'Idle', 'Background', 'Offline'))
);

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'tr_profile_active_room_change') then
    create trigger tr_profile_active_room_change
      after update of active_room_id on public.profiles
      for each row execute function public.on_profile_active_room_change();
  end if;
end
$$;

-- 3. Create persistent roles table
create table if not exists public.room_assigned_roles (
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  role text not null check (role in ('Co Owner', 'Admin')),
  assigned_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, user_id)
);

-- 4. Create invites table
create table if not exists public.room_invites (
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  invited_by uuid references public.profiles(id) on delete cascade not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, user_id)
);

-- 202607230006_get_user_gift_stats_v2.sql
-- Alter views user_received_gifts and user_sent_gifts to include room_id, and create get_user_gift_stats_v2 database function

create or replace view public.user_received_gifts as
select 
  t.id,
  t.sender_id,
  p_sender.username as sender_username,
  p_sender.avatar_url as sender_avatar,
  t.receiver_id,
  p_receiver.username as receiver_username,
  t.gift_id,
  c.name as gift_name,
  c.icon as gift_icon,
  t.stars_value,
  t.quantity,
  t.created_at,
  t.room_id
from public.gift_transactions t
join public.profiles p_sender on p_sender.id = t.sender_id
join public.profiles p_receiver on p_receiver.id = t.receiver_id
join public.gift_catalog c on c.id = t.gift_id;

create or replace view public.user_sent_gifts as
select 
  t.id,
  t.sender_id,
  p_sender.username as sender_username,
  t.receiver_id,
  p_receiver.username as receiver_username,
  p_receiver.avatar_url as receiver_avatar,
  t.gift_id,
  c.name as gift_name,
  c.icon as gift_icon,
  t.stars_value,
  t.quantity,
  t.created_at,
  t.room_id
from public.gift_transactions t
join public.profiles p_sender on p_sender.id = t.sender_id
join public.profiles p_receiver on p_receiver.id = t.receiver_id
join public.gift_catalog c on c.id = t.gift_id;

-- 202607230007_add_provider_and_display_name_to_profiles.sql
-- Add display_name and facebook_provider_id columns to public.profiles table

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS display_name text;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS facebook_provider_id text UNIQUE;

-- 202607230008_add_signup_status_to_profiles.sql
-- Add signup_status column to profiles table

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS signup_status text;

UPDATE public.profiles SET signup_status = 'completed' WHERE signup_status IS NULL;

ALTER TABLE public.profiles ALTER COLUMN signup_status SET DEFAULT 'pending_verification';

-- 202607230009_add_career_level_to_profiles.sql
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS career_level integer DEFAULT 1;

-- 202607230011_fcm_notifications.sql
-- Table for FCM device tokens
create table if not exists public.fcm_tokens (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  token text not null unique,
  device_id text,
  device_type text check (device_type in ('android', 'ios', 'web')),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Table for notification settings
create table if not exists public.notification_settings (
  user_id uuid references public.profiles(id) on delete cascade primary key,
  mute_all boolean default false not null,
  messages boolean default true not null,
  followers boolean default true not null,
  community boolean default true not null,
  voice_rooms boolean default true not null,
  quiz boolean default true not null,
  wallet boolean default true not null,
  security boolean default true not null,
  marketing boolean default true not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Table for tracking notification delivery and logs (analytics)
create table if not exists public.notification_logs (
  id uuid default gen_random_uuid() primary key,
  notification_id uuid references public.notifications(id) on delete cascade,
  receiver_id uuid references public.profiles(id) on delete cascade not null,
  fcm_token text,
  status text not null check (status in ('pending', 'delivered', 'failed', 'clicked', 'dismissed')),
  failure_reason text,
  delivered_at timestamp with time zone,
  clicked_at timestamp with time zone,
  dismissed_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Table for scheduled notifications
create table if not exists public.scheduled_notifications (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  type text not null,
  payload jsonb default '{}'::jsonb,
  scheduled_for timestamp with time zone not null,
  status text default 'pending' check (status in ('pending', 'sent', 'failed')),
  retry_count integer default 0 not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

drop trigger if exists tr_handle_new_profile_notification_settings on public.profiles;

create trigger tr_handle_new_profile_notification_settings
  after insert on public.profiles
  for each row execute function public.handle_new_profile_notification_settings();

-- Backfill existing profiles
insert into public.notification_settings(user_id)
select id from public.profiles
on conflict (user_id) do nothing;

drop trigger if exists tr_profile_activity_notifications on public.profiles;

create trigger tr_profile_activity_notifications
  after update of level, career_level, vip_level, verified on public.profiles
  for each row execute function public.handle_profile_activity_notifications();

-- 202607230014_fix_realtime_instant_pipeline.sql
-- Realtime Sub-Second Message Pipeline Optimization

-- 1. Set REPLICA IDENTITY FULL on messages table for full WAL payload replication in Supabase Realtime
alter table public.messages replica identity full;

-- 202607230016_fix_duplicate_accounts_and_single_thread.sql
-- Single-Thread Deterministic Conversation & One User One Profile Architecture

-- 1. Ensure public.profiles ID uniqueness constraint
do $$ 
begin
  alter table public.profiles add constraint unique_profile_user_id unique (id);
exception when others then
  null;
end $$;

-- 2. Create Conversations Table with deterministic participant ordering
create table if not exists public.conversations (
  id text primary key, -- deterministic string: e.g. u1_u2 (where u1 < u2)
  participant_a uuid references public.profiles(id) on delete cascade not null,
  participant_b uuid references public.profiles(id) on delete cascade not null,
  last_message text,
  last_message_time timestamp with time zone default timezone('utc'::text, now()),
  last_message_sender_id uuid references public.profiles(id),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  constraint check_participants_order check (participant_a < participant_b),
  constraint unique_participant_pair unique (participant_a, participant_b)
);

-- Migration: Network & Low-Latency Performance Optimization (Indexes, Batch RPC, Delta Sync)
-- Created: 2026-07-24

-- ── 1. Create B-Tree & GIN Indexes for Ultra-Fast Query Execution ───────────

-- Profiles optimization
CREATE INDEX IF NOT EXISTS idx_profiles_updated_at ON profiles(updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_profiles_vip_novel ON profiles(vip_level, novel_level);

-- 1. Create payments table
create table if not exists public.payments (
  payment_id text primary key,
  order_id text not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  amount numeric not null,
  vip_plan text not null,
  status text not null, -- 'Success', 'Failed'
  purchase_date timestamp with time zone default now() not null,
  gateway_response jsonb
);

-- payments (payment_id)
create table if not exists public.payments (
  payment_id text primary key,
  order_id text not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  amount numeric not null,
  vip_plan text not null,
  status text not null,
  purchase_date timestamp with time zone default now() not null,
  gateway_response jsonb
);

-- 202607250007_permanent_vip_and_profile_sync.sql
-- Comprehensive Permanent VIP Persistence, Audit Logging, Single Transaction RPCs, and Entitlement Synchronization

-- 1. Create audit log table for purchase and equipment actions
create table if not exists public.vip_audit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  action text not null, -- 'VIP_PURCHASE', 'VIP_RENEWAL', 'VIP_UPGRADE', 'VIP_EXPIRED', 'EQUIP_ITEM', 'UNEQUIP_ITEM'
  category text not null,
  item_name text,
  details jsonb,
  created_at timestamp with time zone default now() not null
);

create index if not exists idx_vip_audit_logs_user_id on public.vip_audit_logs(user_id);

create index if not exists idx_vip_audit_logs_action on public.vip_audit_logs(action);

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'vip_audit_logs' and policyname = 'Users can view own audit logs'
  ) then
    create policy "Users can view own audit logs" on public.vip_audit_logs
      for select using (auth.uid() = user_id);
  end if;
end $$;

-- 2. Database Constraint: Ensure only one active equipped item per category per user
do $$
begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'user_customizations' and c.relkind = 'r') then
    if not exists (
      select 1 from pg_index i join pg_class c on c.oid = i.indexrelid where c.relname = 'idx_user_customizations_single_equipped'
    ) then
      create unique index idx_user_customizations_single_equipped on public.user_customizations (user_id, type) where is_equipped = true;
    end if;
  end if;
end $$;

grant execute on function public.check_and_clean_expired_memberships() to authenticated, service_role;

grant execute on function public.record_membership_purchase(uuid, text, text, numeric, numeric, text, text, timestamp with time zone, text) to authenticated, service_role;

grant execute on function public.get_user_full_inventory_and_entitlements_rpc(uuid) to authenticated, service_role;

grant execute on function public.get_user_full_inventory_and_entitlements_rpc(uuid) to authenticated;

-- 202607250012_fix_on_conflict_and_frame_retention.sql
-- Complete Fix: Safe UNIQUE constraints, PostgreSQL 42P10 prevention, and Avatar Frame retention

-- 1. Ensure explicit UNIQUE constraints on all target tables for ON CONFLICT support
do $$ begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'subscriptions' and c.relkind = 'r') then
    if not exists (select 1 from pg_constraint where conname = 'subscriptions_user_id_membership_type_key') then
      begin
        alter table public.subscriptions add constraint subscriptions_user_id_membership_type_key unique (user_id, membership_type);
      exception when others then null; end;
    end if;
  end if;
end $$;

-- 20 Production Level Session & Room Security Rules Migration
-- Enables single device login, session validation, atomic gifts/purchases, equip validation, and kick cooldowns.

-- 1. Ensure user_sessions schema is complete
alter table public.profiles
  add column if not exists active_session_id text,
  add column if not exists device_fingerprint text;

create table if not exists public.user_sessions (
  session_id text primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  device_id text not null,
  device_name text,
  os_version text,
  app_version text,
  platform text,
  ip text,
  login_time timestamp with time zone default timezone('utc'::text, now()) not null,
  last_seen timestamp with time zone default timezone('utc'::text, now()) not null,
  socket_id text,
  online_status text default 'Online' check (online_status in ('Online', 'In Room', 'Speaking', 'Idle', 'Background', 'Offline'))
);

-- Realtime Publication for user_sessions and profiles
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables 
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'user_sessions'
    ) then
      alter publication supabase_realtime add table public.user_sessions;
    end if;
  end if;
end
$$;

-- 4. Idempotency Transactions Table for Gifts & Purchases
create table if not exists public.processed_transactions (
  transaction_id text primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  action_type text not null,
  payload jsonb,
  result jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Migration: 202608030004_realtime_room_pipeline_fix.sql
-- Enables REPLICA IDENTITY FULL for all voice room tables and registers them in supabase_realtime publication

-- 1. Enable REPLICA IDENTITY FULL on all room tables
alter table public.rooms replica identity full;

alter table public.room_seats replica identity full;

alter table public.room_members replica identity full;

alter table public.room_messages replica identity full;

alter table public.room_requests replica identity full;

alter table public.room_activity_events replica identity full;

alter table public.room_seat_gifts replica identity full;

-- Migration 202608030008_realtime_activity_and_chats.sql
-- Ensure REPLICA IDENTITY FULL and publication registration for voice room real-time features

-- 1. Set REPLICA IDENTITY FULL
alter table public.rooms replica identity full;

-- Migration: Complete Room Role & Permission System v3.1 (UUID & Numeric ID Resolution Fix)
-- Created At: 2026-08-04

-- 1. Ensure assigned_by and assigned_at columns exist in public.room_members
ALTER TABLE public.room_members 
ADD COLUMN IF NOT EXISTS assigned_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS assigned_at timestamptz DEFAULT now();

-- Migration: Complete Seat Lock System v3.1 (UUID & Numeric ID Resolution Fix)
-- Created At: 2026-08-04

-- 1. Ensure seat lock columns exist on public.room_seats
ALTER TABLE public.room_seats
ADD COLUMN IF NOT EXISTS is_locked boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS locked_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS locked_at timestamptz;

-- Attach trigger to profiles table for BEFORE INSERT OR UPDATE
DROP TRIGGER IF EXISTS trg_smart_default_avatar ON public.profiles;

CREATE TRIGGER trg_smart_default_avatar
BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.smart_assign_default_avatar();

-- Backfill existing profiles in DB that have missing/empty/dicebear avatars
DO $$
DECLARE
    r RECORD;
    v_gender text;
    v_random_num int;
    v_chosen_folder text;
    v_avatar_path text;
BEGIN
    FOR r IN 
        SELECT id, gender FROM public.profiles 
        WHERE avatar_url IS NULL 
           OR TRIM(avatar_url) = '' 
           OR avatar_url LIKE '%dicebear%'
    LOOP
        v_gender := LOWER(TRIM(COALESCE(r.gender, '')));
        v_random_num := floor(random() * 10 + 1)::int;

        IF v_gender IN ('male', 'm', 'boy', 'man') THEN
            v_avatar_path := 'assets/creaniaa_avtar_auto/male/' || v_random_num || '.jpeg';
        ELSIF v_gender IN ('female', 'f', 'girl', 'woman') THEN
            v_avatar_path := 'assets/creaniaa_avtar_auto/female/' || v_random_num || '.jpeg';
        ELSE
            IF random() < 0.5 THEN
                v_chosen_folder := 'male';
            ELSE
                v_chosen_folder := 'female';
            END IF;
            v_avatar_path := 'assets/creaniaa_avtar_auto/' || v_chosen_folder || '/' || v_random_num || '.jpeg';
        END IF;

        UPDATE public.profiles
        SET avatar_url = v_avatar_path,
            avatar = v_avatar_path,
            profile_photo = v_avatar_path
        WHERE id = r.id;
    END LOOP;
END;
$$;

-- 3. User Daily Task Progress Table
create table if not exists public.user_daily_task_progress (
  user_id uuid references public.profiles(id) on delete cascade not null,
  task_key text references public.room_daily_task_catalog(task_key) on delete cascade not null,
  current_value integer default 0 not null,
  is_completed boolean default false not null,
  is_claimed boolean default false not null,
  task_date date default ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (user_id, task_key, task_date)
);

-- 5. User Unlocked Perks Table (Avatar Frames, Showcase Badges, Chat Bubbles)
create table if not exists public.user_unlocked_perks (
  user_id uuid references public.profiles(id) on delete cascade not null,
  perk_type text not null check (perk_type in ('avatar_frame', 'showcase_badge', 'chat_bubble')),
  perk_id text not null,
  source_level integer default 1 not null,
  is_permanent boolean default true not null,
  unlocked_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (user_id, perk_type, perk_id)
);

-- 202608070007_creania_room_task_anti_fraud_and_trust_score.sql
-- Creania Arena Daily Task Anti-Fake Rules (1-20) Engine & Hidden Trust Score System (0-100)

-- 1. User Trust Scores Table
create table if not exists public.user_trust_scores (
  user_id uuid references public.profiles(id) on delete cascade primary key,
  trust_score integer default 80 not null check (trust_score between 0 and 100),
  activity_score integer default 50 not null check (activity_score between 0 and 100),
  risk_score integer default 0 not null check (risk_score between 0 and 100),
  is_verified boolean default false not null,
  is_emulator boolean default false not null,
  is_vpn boolean default false not null,
  is_device_banned boolean default false not null,
  last_ip text,
  device_fingerprint text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. User Device Fingerprints Table
create table if not exists public.user_device_fingerprints (
  device_fingerprint text not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  first_seen_at timestamp with time zone default timezone('utc'::text, now()) not null,
  last_seen_at timestamp with time zone default timezone('utc'::text, now()) not null,
  is_banned boolean default false not null,
  primary key (device_fingerprint, user_id)
);

-- 3. Room Anti Abuse Audit Logs
create table if not exists public.room_anti_abuse_logs (
  id uuid default gen_random_uuid() primary key,
  room_id text,
  user_id uuid references public.profiles(id) on delete cascade,
  violation_code text not null,
  details text,
  ip_address text,
  device_fingerprint text,
  trust_score_snapshot integer,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Creania Daily Task Anti-Fake & Hidden Trust Score Engine Migration
-- Version: 202608070007

-- 1. Add trust_score and device_fingerprint to profiles table
alter table public.profiles 
  add column if not exists trust_score integer not null default 80 check (trust_score between 0 and 100),
  add column if not exists device_fingerprint text,
  add column if not exists is_banned_device boolean not null default false,
  add column if not exists last_trust_audit_at timestamptz default now();

-- 2. User Activity & Anti-Abuse Log Table
create table if not exists public.user_anti_abuse_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  room_id text references public.rooms(id) on delete cascade,
  device_fingerprint text,
  ip_address text,
  event_type text not null, -- 'self_gift_attempt', 'rapid_switch', 'idle_freeze', 'trust_change', 'multi_device'
  trust_score_delta integer default 0,
  details jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

-- Migration: 202608070010_fix_send_star_gift_return_type.sql
-- Description: Complete production send_star_gift RPC with room stars update, seat stats update, gold task overflow engine, and room messages event.

-- 0. Ensure profiles star columns compatibility
alter table public.profiles add column if not exists total_stars_received integer default 0;

alter table public.profiles add column if not exists total_stars_gifted integer default 0;

alter table public.profiles add column if not exists star_balance numeric default 0;

alter table public.profiles add column if not exists total_received_stars numeric default 0;

-- Migration: 202608070011_complete_gift_pipeline_fix.sql
-- Description: Production-grade atomic send_star_gift RPC with full schema compatibility,
-- sender/receiver stats, leaderboards, room gift counters, seat totals, daily task progress,
-- and event payload returning exact notification format: SENDER GIFT * COUNT RECEIVERS.

-- 1. Ensure profiles columns compatibility
alter table public.profiles add column if not exists total_stars_received integer default 0;

-- 2. Ensure wallets table compatibility
create table if not exists public.wallets (
  id uuid primary key references public.profiles(id) on delete cascade,
  coins_balance integer default 0,
  silver_coins_balance integer default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 3. Ensure gift_transactions schema compatibility
create table if not exists public.gift_transactions (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete set null,
  receiver_id uuid references public.profiles(id) on delete set null,
  room_id text,
  gift_id uuid,
  gift_name text,
  gift_icon text,
  amount numeric,
  currency text default 'gold',
  count integer default 1,
  quantity integer default 1,
  combo_count integer default 1,
  stars_value numeric default 0,
  seat_index integer default -1,
  is_self_gift boolean default false,
  status text default 'Completed',
  created_at timestamptz default now()
);

-- 4. Ensure gift_history table compatibility
create table if not exists public.gift_history (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete set null,
  receiver_id uuid references public.profiles(id) on delete set null,
  item_id text,
  item_type text default 'VirtualGift',
  quantity integer default 1,
  stars_value numeric default 0,
  room_id text,
  created_at timestamptz default now()
);

-- 5. Ensure gift_statistics table compatibility
create table if not exists public.gift_statistics (
  user_id uuid references public.profiles(id) on delete cascade primary key,
  stars_sent_lifetime numeric default 0,
  stars_received_lifetime numeric default 0,
  highest_gift_value numeric default 0,
  highest_combo integer default 1,
  favorite_gift_id uuid,
  favorite_receiver_id uuid references public.profiles(id) on delete set null,
  favorite_sender_id uuid references public.profiles(id) on delete set null,
  updated_at timestamptz default now()
);

-- 6. Ensure gift_leaderboards table compatibility
create table if not exists public.gift_leaderboards (
  user_id uuid references public.profiles(id) on delete cascade,
  type text not null check (type in ('gifter', 'receiver')),
  cycle text not null check (cycle in ('daily', 'weekly', 'monthly', 'lifetime')),
  cycle_key text not null,
  value numeric default 0,
  updated_at timestamptz default now(),
  primary key (user_id, type, cycle, cycle_key)
);

-- 1. Create Room Daily User Bonuses Table (Tracks 1-time daily claims per user per room)
create table if not exists public.room_daily_user_bonuses (
  room_id text references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  task_date date default ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date not null,
  has_claimed_seat_bonus boolean default false not null,
  has_claimed_gift_bonus boolean default false not null,
  created_at timestamptz default timezone('utc'::text, now()) not null,
  primary key (room_id, user_id, task_date)
);

-- ============================================================
-- 202608070024_permanent_room_ownership_system.sql
-- Permanent Room Ownership System (StarMaker Model)
--
-- Rules:
-- 1. Permanent Owner: The creator of a room is permanently linked via host_id/room_owner.
-- 2. No Auto Transfer: Disconnecting, logging out, offline state, or app restarts NEVER auto-transfer ownership.
-- 3. One Account = One Room: User cannot create multiple active rooms. Returns existing room if attempted.
-- 4. Database Protection: Trigger prevents host_id updates unless app.allow_ownership_transfer is set.
-- 5. Manual Transfer Only: Ownership changes ONLY via explicit transfer_room_ownership() or Super Admin.
-- 6. Audit Logging: Record all transfers in room_ownership_logs.
-- ============================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. room_ownership_logs table
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.room_ownership_logs (
  id              uuid default gen_random_uuid() primary key,
  room_id         text references public.rooms(id) on delete cascade not null,
  old_owner_id    uuid references public.profiles(id) on delete set null,
  new_owner_id    uuid references public.profiles(id) on delete set null,
  transferred_by  uuid references public.profiles(id) on delete set null,
  reason          text default 'manual_transfer',
  created_at      timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. Create Lucky Reward Logs Table for auditability
create table if not exists public.lucky_reward_logs (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete set null,
  room_id text,
  gift_id uuid references public.gift_catalog(id) on delete set null,
  gift_name text,
  cost_coins integer,
  quantity integer default 1,
  combo_count integer default 1,
  total_cost integer,
  multiplier numeric,
  coins_back integer,
  currency text default 'gold',
  created_at timestamptz default now()
);

insert into public.gift_catalog (id, category_id, name, icon, cost_stars, currency, gold_price, silver_price, gem_value, rarity, is_active, is_magic, is_volt, gift_type) values
-- Gold Gifts (1 Gold = 1 Gem value)
('a2000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'Like', '👍', 2, 'gold', 2, null, 2, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001', 'Flower', '🌼', 5, 'gold', 5, null, 5, 'Common', true, true, false, 'normal'),
('a2000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000001', 'Rose', '🌹', 10, 'gold', 10, null, 10, 'Common', true, true, false, 'normal'),
('a2000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000001', 'Heart', '❤️', 15, 'gold', 15, null, 15, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000001', 'Coffee', '☕', 20, 'gold', 20, null, 20, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000006', 'c1000000-0000-0000-0000-000000000001', 'Chocolate', '🍫', 25, 'gold', 25, null, 25, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000007', 'c1000000-0000-0000-0000-000000000001', 'Cake', '🎂', 30, 'gold', 30, null, 30, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000008', 'c1000000-0000-0000-0000-000000000001', 'Balloon', '🎈', 35, 'gold', 35, null, 35, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000009', 'c1000000-0000-0000-0000-000000000001', 'Gift Box', '🎁', 40, 'gold', 40, null, 40, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000010', 'c1000000-0000-0000-0000-000000000001', 'Diamond', '💎', 50, 'gold', 50, null, 50, 'Common', true, true, false, 'normal'),
('a2000000-0000-0000-0000-000000000011', 'c1000000-0000-0000-0000-000000000001', 'Crown', '👑', 99, 'gold', 99, null, 99, 'Epic', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000012', 'c1000000-0000-0000-0000-000000000001', 'Butterfly', '🦋', 99, 'gold', 99, null, 99, 'Epic', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000013', 'c1000000-0000-0000-0000-000000000001', 'Sports Car', '🏎️', 499, 'gold', 499, null, 499, 'Legendary', true, true, false, 'normal'),
('a2000000-0000-0000-0000-000000000014', 'c1000000-0000-0000-0000-000000000001', 'Private Jet', '✈️', 499, 'gold', 499, null, 499, 'Mythic', true, true, false, 'normal'),

-- Silver Gifts (100 Silver = 1 Gem value)
('a2000000-0000-0000-0000-000000000021', 'c1000000-0000-0000-0000-000000000002', 'Like', '👍', 200, 'silver', null, 200, 2, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000022', 'c1000000-0000-0000-0000-000000000002', 'Flower', '🌼', 500, 'silver', null, 500, 5, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000023', 'c1000000-0000-0000-0000-000000000002', 'Rose', '🌹', 1000, 'silver', null, 1000, 10, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000024', 'c1000000-0000-0000-0000-000000000002', 'Heart', '❤️', 1500, 'silver', null, 1500, 15, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000025', 'c1000000-0000-0000-0000-000000000002', 'Coffee', '☕', 2000, 'silver', null, 2000, 20, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000026', 'c1000000-0000-0000-0000-000000000002', 'Chocolate', '🍫', 2500, 'silver', null, 2500, 25, 'Common', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000027', 'c1000000-0000-0000-0000-000000000002', 'Cake', '🎂', 3000, 'silver', null, 3000, 30, 'Rare', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000028', 'c1000000-0000-0000-0000-000000000002', 'Balloon', '🎈', 3500, 'silver', null, 3500, 35, 'Rare', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000029', 'c1000000-0000-0000-0000-000000000002', 'Gift Box', '🎁', 4000, 'silver', null, 4000, 40, 'Rare', true, false, false, 'normal'),
('a2000000-0000-0000-0000-000000000030', 'c1000000-0000-0000-0000-000000000002', 'Diamond', '💎', 5000, 'silver', null, 5000, 50, 'Rare', true, false, false, 'normal'),

-- Volt Gifts (Gems are primary identity)
('a2000000-0000-0000-0000-000000000041', 'c1000000-0000-0000-0000-000000000003', 'Volt Star', '⚡', 250, 'volt', 250, null, 250, 'Epic', true, false, true, 'volt'),
('a2000000-0000-0000-0000-000000000042', 'c1000000-0000-0000-0000-000000000003', 'Volt Dragon', '🐲', 1000, 'volt', 1000, null, 1000, 'Legendary', true, true, true, 'volt'),
('a2000000-0000-0000-0000-000000000043', 'c1000000-0000-0000-0000-000000000003', 'Volt Thunder', '🌩️', 2500, 'volt', 2500, null, 2500, 'Mythic', true, true, true, 'volt');

alter table public.profiles add column if not exists total_gems_received numeric default 0;

alter table public.profiles add column if not exists total_gems_sent numeric default 0;

create table if not exists public.events (
  id                          uuid default gen_random_uuid() primary key,
  title                       text not null,
  description                 text,
  banner_url                  text default '',
  category                    text,
  difficulty                  text,
  organizer                   text,
  is_official                 boolean default false,
  start_date                  timestamp with time zone not null,
  end_date                    timestamp with time zone not null,
  registration_deadline       timestamp with time zone,
  result_date                 timestamp with time zone,
  max_participants            integer default 100,
  is_unlimited                boolean default false,
  entry_fee_type              text default 'free' check (entry_fee_type in ('free', 'coins', 'cash')),
  entry_fee_amount            numeric default 0,
  prize_pool                  text default '',
  rewards                     jsonb default '{}'::jsonb,
  status                      text default 'registrationOpen'
                                check (status in ('registrationOpen','registrationClosed','ongoing','completed','cancelled','upcoming')),
  format                      text default 'quiz'
                                check (format in ('quiz','tournament','challenge','hackathon','creative','sports','gaming','debate','other')),
  rules                       text[] default '{}',
  required_level              integer default 1,
  required_badge              text,
  tags                        text[] default '{}',
  language                    text default 'English',
  is_public                   boolean default true,
  participants_count          integer default 0,
  anti_cheat                  jsonb default '{}'::jsonb,
  negative_marking            boolean default false,
  duration_minutes            integer default 60,
  question_count              integer default 30,
  passing_marks               integer default 40,
  required_registration_fields text[] default array['name','email','phone'],
  terms_and_conditions        text default '',
  is_paid                     boolean default false,
  winners                     jsonb default '[]'::jsonb,
  rounds                      jsonb default '[]'::jsonb,
  created_by                  uuid references public.profiles(id) on delete set null,
  created_at                  timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at                  timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ============================================================================
-- CREANIA COMPLETE RECHARGE, FIRST PURCHASE, VIP & NOVEL OFFER SYSTEM
-- Migration File: 202608090010_complete_recharge_store_offers_system.sql
-- Description:
--   1. Adds first purchase & signup reward tracking columns to profiles.
--   2. Creates store_configurations table for admin-configurable packages, offers, and bonus days.
--   3. Adds claim_signup_reward_rpc for idempotent coin wallet signup reward.
--   4. Updates purchase_and_activate_rpc with strict floor(INR / 2) coin rate, recharge bonuses,
--      idempotent first purchase offers, exact VIP/Novel duration mapping (+bonus extra days),
--      and detailed wallet transaction logging.
-- ============================================================================

-- 1. Profile Tracking Columns
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS first_purchase_completed boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS first_vip_purchase_completed boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS first_novel_purchase_completed boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS signup_reward_claimed boolean DEFAULT false;

create table if not exists public.post_mcq_votes (
  id uuid default gen_random_uuid() primary key,
  post_id text not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  option_id text not null,
  created_at timestamp with time zone default now(),
  unique (post_id, user_id)
);

create table if not exists public.post_poll_votes (
  id uuid default gen_random_uuid() primary key,
  post_id text not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  option_id text not null,
  created_at timestamp with time zone default now(),
  unique (post_id, user_id)
);

-- 5. Post Reports Table
create table if not exists public.post_reports (
  id uuid default gen_random_uuid() primary key,
  post_id text not null references public.posts(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null,
  created_at timestamp with time zone default now()
);

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

create table if not exists public.content_engagements (
  id uuid default gen_random_uuid() primary key,
  post_id text not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  engagement_type text not null, -- 'like', 'comment', 'share', 'save', 'answer', 'poll_vote', 'mcq_vote', 'repay', 'skip'
  weight numeric default 1.0,
  created_at timestamp with time zone default now()
);

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

-- Migration: Canonical Chat System & Unique Pair Constraints
-- Date: 2026-08-11
-- Author: Creania Engineering Team

-- 1. Create message_tombstones table for soft delete synchronization
CREATE TABLE IF NOT EXISTS public.message_tombstones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id TEXT NOT NULL UNIQUE,
    conversation_id TEXT NOT NULL,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    deleted_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deletion_type TEXT NOT NULL DEFAULT 'SOFT_DELETE' CHECK (deletion_type IN ('SOFT_DELETE', 'HARD_DELETE', 'ADMIN_PURGE'))
);

-- 2. Create or ensure canonical conversations table with ordered participant constraints
CREATE TABLE IF NOT EXISTS public.conversations (
    id TEXT PRIMARY KEY,
    participant_a UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    participant_b UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    last_message TEXT,
    last_message_time TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    last_message_sender_id UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT check_participants_order CHECK (participant_a < participant_b),
    CONSTRAINT unique_participant_pair UNIQUE (participant_a, participant_b)
);

-- 3. Immutable Audit Ledger for All Creania Balance Movements
CREATE TABLE IF NOT EXISTS public.cb_ledger_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount_cb BIGINT NOT NULL,
  inr_equivalent NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
  entry_type TEXT NOT NULL CHECK (entry_type IN (
    'GIFT_RECEIVER_REWARD',
    'GIFT_ROOM_OWNER_REWARD',
    'GIFT_COMMUNITY_REWARD',
    'FAMILY_GIFT_REWARD',
    'WEEKEND_FAMILY_SETTLEMENT',
    'EXCHANGE',
    'PROMOTIONAL_BONUS',
    'WITHDRAWAL_REQUEST',
    'WITHDRAWAL_COMPLETED',
    'WITHDRAWAL_REJECTED',
    'GIFT_REFUNDED',
    'FRAUD_REVERSAL',
    'ADMIN_ADJUSTMENT'
  )),
  reference_id TEXT,
  idempotency_key TEXT UNIQUE NOT NULL,
  status TEXT NOT NULL DEFAULT 'COMPLETED' CHECK (status IN ('PENDING', 'COMPLETED', 'REVERSED', 'REJECTED')),
  details JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4. Family Pending Rewards & Immutable Weekend Settlement Tables
CREATE TABLE IF NOT EXISTS public.family_pending_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL,
  family_owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  gift_transaction_id TEXT NOT NULL,
  amount_cb BIGINT NOT NULL,
  status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SETTLED', 'REVERSED_FRAUD')),
  idempotency_key TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.family_settlement_history (
  id TEXT PRIMARY KEY,
  family_id UUID NOT NULL,
  family_owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  previous_pending_cb BIGINT NOT NULL DEFAULT 0,
  eligible_added_cb BIGINT NOT NULL DEFAULT 0,
  fraud_adjustment_cb BIGINT NOT NULL DEFAULT 0,
  final_settled_cb BIGINT NOT NULL DEFAULT 0,
  inr_value NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
  settled_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  status TEXT NOT NULL DEFAULT 'COMPLETED'
);

-- 5. Creania Balance Withdrawal Tracking Table
CREATE TABLE IF NOT EXISTS public.cb_withdrawals (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount_cb BIGINT NOT NULL CHECK (amount_cb > 0),
  inr_value NUMERIC(10, 2) NOT NULL CHECK (inr_value > 0),
  fee_inr NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
  net_payout_inr NUMERIC(10, 2) NOT NULL CHECK (net_payout_inr >= 0),
  upi_id TEXT NOT NULL,
  account_name TEXT,
  status TEXT NOT NULL DEFAULT 'Withdrawal Requested' CHECK (status IN (
    'Available',
    'Withdrawal Requested',
    'Under Review',
    'Processing',
    'Completed',
    'Rejected',
    'Reversed'
  )),
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 3. Permanent Audit & Idempotency Ledger Table for Lucky Gift Rewards
CREATE TABLE IF NOT EXISTS public.lucky_gift_reward_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id text UNIQUE NOT NULL,
  sender_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  room_id text NOT NULL,
  gift_id uuid REFERENCES public.gift_catalog(id) ON DELETE SET NULL,
  gold_coins_spent integer NOT NULL,
  tier text NOT NULL,
  ap_credited integer NOT NULL,
  gem_credited integer NOT NULL,
  random_gift_payload jsonb DEFAULT '{}'::jsonb,
  is_self_gift boolean DEFAULT false,
  is_blocked boolean DEFAULT false,
  block_reason text DEFAULT NULL,
  created_at timestamptz DEFAULT NOW()
);

-- 202608110007_settings_system_production_fix.sql
-- Creania Settings System Production Database Schema, Tables, RPCs, and Security Policies

-- 1. Extend profiles table with is_private and 2FA settings
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_private boolean DEFAULT false;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS two_factor_enabled boolean DEFAULT false;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS two_factor_secret text DEFAULT NULL;

-- 2. User Blocks Table (Blocked Users System)
CREATE TABLE IF NOT EXISTS public.user_blocks (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  blocker_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  blocked_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT unique_user_block UNIQUE (blocker_id, blocked_id)
);

-- 3. User Devices / Authorized Sessions System
CREATE TABLE IF NOT EXISTS public.user_devices (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  device_id text NOT NULL,
  device_name text NOT NULL,
  platform text NOT NULL,
  ip_address text DEFAULT '127.0.0.1',
  is_current boolean DEFAULT false,
  revoked_at timestamp with time zone DEFAULT NULL,
  last_active timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT unique_user_device UNIQUE (user_id, device_id)
);

-- 4. Login Activity System
CREATE TABLE IF NOT EXISTS public.user_login_activity (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  device_name text NOT NULL,
  platform text NOT NULL,
  ip_address text DEFAULT '127.0.0.1',
  session_id text DEFAULT NULL,
  login_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Support Tickets System
CREATE TABLE IF NOT EXISTS public.support_tickets (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  category text NOT NULL CHECK (category IN ('Report', 'Request', 'Account Recovery', 'Bug Report', 'General')),
  subject text NOT NULL,
  description text NOT NULL,
  status text DEFAULT 'Open' CHECK (status IN ('Open', 'In Review', 'Resolved', 'Closed')),
  admin_response text DEFAULT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Migration: 202608110009_production_2fa_system.sql
-- Description: Production-grade Two-Factor Authentication (2FA) Schema & RPCs

-- 1. Create user_security_settings table
CREATE TABLE IF NOT EXISTS public.user_security_settings (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  two_factor_enabled boolean NOT NULL DEFAULT false,
  two_factor_method text NOT NULL DEFAULT 'totp',
  totp_secret_encrypted text,
  last_verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. Create recovery_codes table
CREATE TABLE IF NOT EXISTS public.recovery_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  code_hash text NOT NULL,
  used boolean NOT NULL DEFAULT false,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_recovery_codes_user ON public.recovery_codes(user_id);

CREATE INDEX IF NOT EXISTS idx_recovery_codes_hash ON public.recovery_codes(code_hash);

-- 3. Create trusted_devices table
CREATE TABLE IF NOT EXISTS public.trusted_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id text NOT NULL,
  device_name text NOT NULL,
  token_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  last_used_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_trusted_devices_user ON public.trusted_devices(user_id);

CREATE INDEX IF NOT EXISTS idx_trusted_devices_token ON public.trusted_devices(token_hash);

-- 4. Create two_factor_attempts table for rate limiting
CREATE TABLE IF NOT EXISTS public.two_factor_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action text NOT NULL,
  success boolean NOT NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  ip_hash text,
  device_id text
);

CREATE INDEX IF NOT EXISTS idx_2fa_attempts_user_time ON public.two_factor_attempts(user_id, created_at DESC);

-- 5. Create security_events table for audit logging
CREATE TABLE IF NOT EXISTS public.security_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_security_events_user ON public.security_events(user_id, created_at DESC);

-- Migration: 202608110010_2fa_server_security_keys.sql
-- Description: High-Security 32-bit / 64-bit Server-Generated Security Keys schema & RPCs for Creania 2FA.

-- 1. Create server_security_keys table
CREATE TABLE IF NOT EXISTS public.server_security_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  key_hash text NOT NULL,
  used boolean NOT NULL DEFAULT false,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_server_keys_user ON public.server_security_keys(user_id);

CREATE INDEX IF NOT EXISTS idx_server_keys_hash ON public.server_security_keys(key_hash);

-- 202608110012_login_activity_and_session_management.sql
-- Production Login Activity & Device Session Management System

-- 1. Create or upgrade user_sessions table
CREATE TABLE IF NOT EXISTS public.user_sessions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  session_id text NOT NULL UNIQUE,
  device_id text NOT NULL,
  device_name text NOT NULL,
  device_model text DEFAULT '',
  platform text NOT NULL,
  os_version text DEFAULT '',
  app_version text DEFAULT '',
  browser text DEFAULT '',
  ip_address text DEFAULT '127.0.0.1',
  country text DEFAULT 'India',
  city text DEFAULT '',
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  last_active_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  expires_at timestamp with time zone DEFAULT (timezone('utc'::text, now()) + interval '90 days') NOT NULL,
  revoked_at timestamp with time zone DEFAULT NULL
);

-- 2. Upgrade user_login_activity table for detailed security event logs
CREATE TABLE IF NOT EXISTS public.user_login_activity (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  event_type text NOT NULL DEFAULT 'Successful Login',
  device_name text NOT NULL,
  platform text NOT NULL,
  ip_address text DEFAULT '127.0.0.1',
  country text DEFAULT 'India',
  session_id text DEFAULT NULL,
  status text DEFAULT 'success',
  failure_reason text DEFAULT NULL,
  auth_method text DEFAULT 'Password',
  login_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================
-- 202608120002_hard_immutable_room_owner_and_role_lock.sql
-- Creania Arena Room Owner Immutability + Role System Hard Lock
-- ============================================================

-- 1. Standardize owner_user_id column on public.rooms table
ALTER TABLE public.rooms 
ADD COLUMN IF NOT EXISTS owner_user_id uuid REFERENCES public.profiles(id);

-- 2. Ensure wallet_transactions audit table and required columns exist
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  currency_type text NOT NULL DEFAULT 'Gold',
  currency text NOT NULL DEFAULT 'Gold',
  amount numeric(12,2) NOT NULL DEFAULT 0.00,
  previous_balance numeric(12,2) NOT NULL DEFAULT 0.00,
  new_balance numeric(12,2) NOT NULL DEFAULT 0.00,
  type text NOT NULL DEFAULT 'Reward',
  source text NOT NULL DEFAULT 'System',
  transaction_id text UNIQUE,
  reference_id text,
  details text,
  status text NOT NULL DEFAULT 'Completed',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Safely add missing columns to pre-existing wallet_transactions table if created in earlier migrations
ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS wallet_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 202608120004_payment_recharge_idempotency_and_security.sql
-- AUTHORITATIVE PAYMENT RECHARGE IDEMPOTENCY, SECURITY & PER-TRANSACTION CAP ENGINE

-- 1. Ensure public.payments table has all required columns and constraints
CREATE TABLE IF NOT EXISTS public.payments (
  payment_id text PRIMARY KEY,
  order_id text NOT NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  amount numeric NOT NULL,
  vip_plan text NOT NULL,
  status text NOT NULL DEFAULT 'Success',
  purchase_date timestamptz DEFAULT now() NOT NULL,
  gateway_response jsonb
);

-- 1. Create persistent room_roles table for permanent role storage (Separate from Presence)
CREATE TABLE IF NOT EXISTS public.room_roles (
  room_id text REFERENCES public.rooms(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  role text NOT NULL,
  assigned_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  assigned_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  PRIMARY KEY (room_id, user_id)
);

-- Ensure legacy room_assigned_roles table exists and drop any restricting legacy check constraints
CREATE TABLE IF NOT EXISTS public.room_assigned_roles (
  room_id text REFERENCES public.rooms(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  role text NOT NULL,
  assigned_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  PRIMARY KEY (room_id, user_id)
);

-- 202607090001_profiles.sql
-- Profiles schema, UID generator, signup triggers, updated_at triggers, and RLS policies

-- 1. UID generator (Defined first to be used as default)
create or replace function public.generate_unique_uid()
returns bigint as $$
declare
  new_uid bigint;
  exists_uid boolean;
begin
  loop
    new_uid := floor(random() * (999999999999 - 1000000000 + 1) + 1000000000)::bigint;
    select exists(select 1 from public.profiles where uid = new_uid) into exists_uid;
    if not exists_uid then
      return new_uid;
    end if;
  end loop;
end;
$$ language plpgsql;

-- handle_new_user signup trigger
create or replace function public.handle_new_user()
returns trigger as $$
declare
  generated_uid bigint;
begin
  generated_uid := public.generate_unique_uid();

  begin
    insert into public.profiles (
      id, 
      uid,
      username, 
      email,
      phone,
      avatar_url, 
      profile_photo,
      vip_level, 
      novel_level, 
      level, 
      experience,
      verified
    )
    values (
      new.id,
      generated_uid,
      coalesce(new.raw_user_meta_data->>'username', 'user_' || substr(new.id::text, 1, 8)),
      new.email,
      new.phone,
      new.raw_user_meta_data->>'avatar_url',
      new.raw_user_meta_data->>'avatar_url',
      0,
      0,
      1,
      0,
      false
    )
    on conflict (id) do update set
      email = coalesce(profiles.email, excluded.email),
      phone = coalesce(profiles.phone, excluded.phone),
      avatar_url = coalesce(profiles.avatar_url, excluded.avatar_url),
      profile_photo = coalesce(profiles.profile_photo, excluded.profile_photo);
  exception 
    when unique_violation then
      begin
        insert into public.profiles (
          id, 
          uid,
          username, 
          email,
          phone,
          avatar_url, 
          profile_photo,
          vip_level, 
          novel_level, 
          level, 
          experience,
          verified
        )
        values (
          new.id,
          generated_uid,
          'user_' || substr(new.id::text, 1, 8) || '_' || (random() * 1000)::int::text,
          null,
          null,
          new.raw_user_meta_data->>'avatar_url',
          new.raw_user_meta_data->>'avatar_url',
          0,
          0,
          1,
          0,
          false
        );
      exception when others then
        raise notice 'Failed to insert profile: %', SQLERRM;
      end;
    when others then
      raise notice 'Failed to insert profile: %', SQLERRM;
  end;

  return new;
end;
$$ language plpgsql security definer;

-- Trigger to auto-update updated_at column on profiles
create or replace function public.update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Triggers
create or replace function public.check_room_username()
returns trigger as $$
begin
  if exists (select 1 from public.profiles where username = new.username) then
    raise exception 'Username is already taken by a profile';
  end if;
  if exists (select 1 from public.rooms where username = new.username and id <> new.id) then
    raise exception 'Username is already taken by another voice room';
  end if;
  return new;
end;
$$ language plpgsql;

create or replace function public.check_room_update_permission()
returns trigger as $$
declare
  v_actor_id uuid;
  v_role text;
begin
  v_actor_id := auth.uid();
  if v_actor_id is null then
    return new;
  end if;

  if not (
    (new.name is distinct from old.name) or
    (new.username is distinct from old.username) or
    (new.description is distinct from old.description) or
    (new.category is distinct from old.category) or
    (new.language is distinct from old.language) or
    (new.visibility is distinct from old.visibility) or
    (new.level_requirement is distinct from old.level_requirement) or
    (new.vip_requirement is distinct from old.vip_requirement) or
    (new.verification_requirement is distinct from old.verification_requirement) or
    (new.avatar is distinct from old.avatar) or
    (new.banner is distinct from old.banner) or
    (new.room_cover_url is distinct from old.room_cover_url) or
    (new.co_host_can_edit_cover is distinct from old.co_host_can_edit_cover) or
    (new.admin_can_edit_cover is distinct from old.admin_can_edit_cover) or
    (new.is_permanent is distinct from old.is_permanent) or
    (new.host_id is distinct from old.host_id)
  ) then
    return new;
  end if;

  select role into v_role 
  from public.room_members 
  where room_id = old.id and user_id = v_actor_id;

  if old.host_id = v_actor_id then
    return new;
  end if;

  if (v_role = 'Co-Host' and old.co_host_can_edit_cover = true) or
     (v_role = 'Moderator' and old.admin_can_edit_cover = true) then
    if (new.id is distinct from old.id) or
       (new.name is distinct from old.name) or
       (new.username is distinct from old.username) or
       (new.description is distinct from old.description) or
       (new.category is distinct from old.category) or
       (new.language is distinct from old.language) or
       (new.visibility is distinct from old.visibility) or
       (new.level_requirement is distinct from old.level_requirement) or
       (new.vip_requirement is distinct from old.vip_requirement) or
       (new.verification_requirement is distinct from old.verification_requirement) or
       (new.banner is distinct from old.banner) or
       (new.co_host_can_edit_cover is distinct from old.co_host_can_edit_cover) or
       (new.admin_can_edit_cover is distinct from old.admin_can_edit_cover) or
       (new.is_permanent is distinct from old.is_permanent) or
       (new.host_id is distinct from old.host_id)
    then
      raise exception 'Unauthorized to modify these settings';
    end if;
    
    new.updated_by := v_actor_id;
    new.updated_at := now();
    return new;
  end if;

  raise exception 'Unauthorized to edit this room';
end;
$$ language plpgsql security definer;

-- 6. Reset Seating total session stars when user leaves the seat index
create or replace function public.sync_room_seats_user_profile()
returns trigger as $$
declare
  v_username text;
  v_avatar text;
  v_level integer;
  v_avatar_frame text;
  v_vip_level integer;
  v_noble_level integer;
begin
  new.seat_number := new.seat_index;
  
  if new.user_id is not null then
    select username, avatar_url, level, avatar_frame, vip_level, novel_level
    into v_username, v_avatar, v_level, v_avatar_frame, v_vip_level, v_noble_level
    from public.profiles where id = new.user_id;

    new.username := v_username;
    new.avatar := v_avatar;
    new.level := v_level;
    new.avatar_frame := v_avatar_frame;
    new.vip_level := v_vip_level;
    new.noble_level := v_noble_level;
  else
    new.username := null;
    new.avatar := null;
    new.level := null;
    new.avatar_frame := null;
    new.vip_level := null;
    new.noble_level := null;
    new.is_speaking := false;
    
    -- Reset session indicators
    new.seat_total_gifts := 0;
    new.seat_total_stars := 0;
  end if;

  if old.user_id is distinct from new.user_id then
    new.seat_total_gifts := 0;
    new.seat_total_stars := 0;
  end if;

  return new;
end;
$$ language plpgsql;

create or replace function public.sync_profile_updates_to_seats()
returns trigger as $$
begin
  update public.room_seats
  set 
    username = new.username,
    avatar = new.avatar_url,
    level = new.level,
    avatar_frame = new.avatar_frame,
    vip_level = new.vip_level,
    noble_level = new.novel_level
  where user_id = new.id;
  return new;
end;
$$ language plpgsql;

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

-- 2. Re-create single authoritative join_room RPC with defaulted parameters
CREATE OR REPLACE FUNCTION public.join_room(
  p_room_id text,
  p_password text DEFAULT NULL,
  p_session_id text DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_room public.rooms%ROWTYPE;
  v_user_profile public.profiles%ROWTYPE;
  v_current_count integer;
  v_role text;
  v_is_follower boolean;
  v_is_following boolean;
  v_is_community_member boolean;
  v_is_invited boolean;
  v_stored_password text;
BEGIN
  -- Run presence grace period & cleanup
  PERFORM public.process_presence_grace_period_and_cleanup();
  PERFORM public.leave_all_rooms(v_user_id, p_room_id);

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Resolve room by ID or Username
  SELECT * INTO v_room FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room.id IS NULL THEN
    RAISE EXCEPTION 'Room not found';
  END IF;

  IF v_room.status = 'ended' THEN
    RAISE EXCEPTION 'Room has already ended';
  END IF;

  -- Kick/Ban Check
  IF EXISTS (
    SELECT 1 FROM public.room_bans 
    WHERE room_id = v_room.id AND user_id = v_user_id AND (expires_at IS NULL OR expires_at > now())
  ) THEN
    RAISE EXCEPTION 'You are banned from this room';
  END IF;

  -- Room Capacity Check (Max 100)
  SELECT count(*) INTO v_current_count FROM public.room_members WHERE room_id = v_room.id;
  IF v_current_count >= 100 THEN
    RAISE EXCEPTION 'Room is full';
  END IF;

  -- Level & Global Ban Check
  SELECT * INTO v_user_profile FROM public.profiles WHERE id = v_user_id;
  IF v_user_profile.level < v_room.level_requirement THEN
    RAISE EXCEPTION 'Requires ID Level % or higher', v_room.level_requirement;
  END IF;

  IF v_user_profile.is_banned = true THEN
    RAISE EXCEPTION 'Your account is banned';
  END IF;

  -- Password & Policy Enforcement for non-host
  IF v_room.host_id <> v_user_id THEN
    -- Password check if room has password
    v_stored_password := COALESCE(v_room.room_password, (SELECT room_password FROM public.room_settings WHERE room_id = v_room.id LIMIT 1));
    IF v_stored_password IS NOT NULL AND length(trim(v_stored_password)) > 0 THEN
      IF p_password IS NULL OR trim(p_password) <> trim(v_stored_password) THEN
        RAISE EXCEPTION 'Incorrect room password';
      END IF;
    END IF;

    -- Join policy check
    IF v_room.join_policy = 'Followers Only' THEN
      SELECT EXISTS (SELECT 1 FROM public.connections WHERE follower_id = v_user_id AND following_id = v_room.host_id) INTO v_is_follower;
      IF NOT v_is_follower THEN
        RAISE EXCEPTION 'This room is Followers Only';
      END IF;
    ELSIF v_room.join_policy = 'VIP Members Only' THEN
      IF v_user_profile.vip_level = 0 THEN
        RAISE EXCEPTION 'This room is VIP Members Only';
      END IF;
    ELSIF v_room.join_policy = 'Community Members Only' THEN
      IF v_room.community_id IS NOT NULL THEN
        SELECT EXISTS (SELECT 1 FROM public.community_memberships WHERE community_id = v_room.community_id AND user_id = v_user_id) INTO v_is_community_member;
        IF NOT v_is_community_member THEN
          RAISE EXCEPTION 'This room is Community Members Only';
        END IF;
      END IF;
    ELSIF v_room.join_policy = 'Owner Following Only' THEN
      SELECT EXISTS (SELECT 1 FROM public.connections WHERE follower_id = v_room.host_id AND following_id = v_user_id) INTO v_is_following;
      IF NOT v_is_following THEN
        RAISE EXCEPTION 'This room is restricted to Owner Following only';
      END IF;
    ELSIF v_room.join_policy = 'Invite Only' THEN
      SELECT EXISTS (SELECT 1 FROM public.room_invites WHERE room_id = v_room.id AND user_id = v_user_id) INTO v_is_invited;
      IF NOT v_is_invited THEN
        RAISE EXCEPTION 'This room is Invite Only';
      END IF;
    END IF;
  END IF;

  -- Role Determination
  IF v_room.host_id = v_user_id THEN
    v_role := 'Host';
  ELSE
    SELECT role INTO v_role FROM public.room_assigned_roles WHERE room_id = v_room.id AND user_id = v_user_id;
    IF v_role IS NULL THEN
      v_role := 'Listener';
    END IF;
  END IF;

  -- Add to room members
  INSERT INTO public.room_members (room_id, user_id, role, last_heartbeat_at, session_id, is_reconnecting)
  VALUES (v_room.id, v_user_id, v_role, now(), p_session_id, false)
  ON CONFLICT (room_id, user_id) DO UPDATE 
  SET role = EXCLUDED.role, 
      last_heartbeat_at = now(), 
      session_id = EXCLUDED.session_id, 
      is_reconnecting = false;

  -- Clear any active seats so user enters as listener
  UPDATE public.room_seats
  SET user_id = NULL,
      mic_status = 'muted',
      is_speaking = false,
      is_reconnecting = false,
      session_id = NULL
  WHERE room_id = v_room.id AND user_id = v_user_id;

  -- Update active room ID in profiles
  UPDATE public.profiles
  SET active_room_id = v_room.id, presence_state = 'In Room'
  WHERE id = v_user_id;

  -- Activity event log
  INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
  VALUES (v_room.id, 'join', v_user_id, v_user_profile.username, COALESCE(v_user_profile.username, 'Someone') || ' joined the room');

  RETURN jsonb_build_object(
    'success', true,
    'role', v_role,
    'livekit_room_name', v_room.livekit_room_name
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 6. Instant Normal Disconnect leave_room RPC
create or replace function public.leave_room(
  p_room_id text
) returns boolean as $$
declare
  v_user_id uuid := auth.uid();
  v_username text;
begin
  if v_user_id is null then
    return false;
  end if;

  select username into v_username from public.profiles where id = v_user_id;

  update public.room_seats
  set user_id = null,
      mic_status = 'muted',
      is_speaking = false,
      is_reconnecting = false,
      session_id = null
  where room_id = p_room_id and user_id = v_user_id;

  delete from public.room_members where room_id = p_room_id and user_id = v_user_id;
  delete from public.room_requests where room_id = p_room_id and user_id = v_user_id;

  update public.profiles
  set active_room_id = null, presence_state = 'Online'
  where id = v_user_id;

  insert into public.room_activity_events (room_id, event_type, user_id, username, message)
  values (p_room_id, 'leave', v_user_id, v_username, coalesce(v_username, 'Someone') || ' left the room');

  return true;
end;
$$ language plpgsql security definer set search_path = public;

-- 2. Update join_room_seat to perform state updates without emitting raw duplicate strings
CREATE OR REPLACE FUNCTION public.join_room_seat(
  p_room_id text,
  p_seat_index integer
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_username text;
  v_new_role text;
  v_seat_session_id text;
  v_seat_session_gems integer;
  v_existing_session_id text;
  v_existing_session_gems integer;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated';
  END IF;

  SELECT username INTO v_username FROM public.profiles WHERE id = v_user_id;

  -- Check if user is ALREADY sitting on this exact seat in this room
  SELECT seat_session_id, COALESCE(seat_session_gems, 0)
  INTO v_existing_session_id, v_existing_session_gems
  FROM public.room_seats
  WHERE room_id = p_room_id AND seat_index = p_seat_index AND user_id = v_user_id;

  IF v_existing_session_id IS NOT NULL THEN
    -- User is re-asserting occupancy on the SAME seat
    v_seat_session_id := v_existing_session_id;
    v_seat_session_gems := v_existing_session_gems;

    UPDATE public.room_seats
    SET username = v_username,
        mic_status = 'unmuted',
        updated_at = NOW()
    WHERE room_id = p_room_id AND seat_index = p_seat_index;
  ELSE
    -- User is taking a NEW seat
    -- Clear user from any OTHER seat in this room
    UPDATE public.room_seats
    SET user_id = NULL,
        seat_session_id = NULL,
        seat_session_gems = 0,
        seat_total_gems = 0,
        seat_total_stars = 0,
        mic_status = 'muted',
        is_speaking = false
    WHERE room_id = p_room_id AND user_id = v_user_id AND seat_index != p_seat_index;

    -- Generate unique seat-session identifier
    v_seat_session_id := 'ss_' || replace(gen_random_uuid()::text, '-', '');
    v_seat_session_gems := 0;

    UPDATE public.room_seats
    SET user_id = v_user_id,
        username = v_username,
        seat_session_id = v_seat_session_id,
        seat_session_gems = 0,
        seat_total_gems = 0,
        seat_total_stars = 0,
        mic_status = 'unmuted',
        is_speaking = false,
        updated_at = NOW()
    WHERE room_id = p_room_id AND seat_index = p_seat_index;
  END IF;

  -- Determine role based on seat index
  IF p_seat_index = 0 THEN
    v_new_role := 'Host';
  ELSIF p_seat_index = 1 THEN
    v_new_role := 'Co-Host';
  ELSE
    v_new_role := 'Speaker';
  END IF;

  -- Update member role in room_members
  UPDATE public.room_members
  SET role = v_new_role,
      seat_number = p_seat_index + 1,
      last_heartbeat_at = NOW()
  WHERE room_id = p_room_id AND user_id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'seat_index', p_seat_index,
    'seat_session_id', v_seat_session_id,
    'seat_session_gems', v_seat_session_gems,
    'user_id', v_user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. Update leave_room_seat to perform state updates without emitting raw duplicate strings
CREATE OR REPLACE FUNCTION public.leave_room_seat(
  p_room_id text,
  p_seat_index integer
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_username text;
BEGIN
  IF v_user_id IS NOT NULL THEN
    SELECT username INTO v_username FROM public.profiles WHERE id = v_user_id;
  END IF;

  -- Reset ONLY the specific seat requested
  UPDATE public.room_seats
  SET user_id = NULL,
      seat_session_id = NULL,
      seat_session_gems = 0,
      seat_total_gems = 0,
      seat_total_stars = 0,
      mic_status = 'muted',
      is_speaking = false,
      updated_at = NOW()
  WHERE room_id = p_room_id AND seat_index = p_seat_index;

  -- Demote user to Listener in room_members
  IF v_user_id IS NOT NULL THEN
    UPDATE public.room_members
    SET role = 'Listener',
        seat_number = NULL
    WHERE room_id = p_room_id AND user_id = v_user_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'seat_index', p_seat_index,
    'seat_session_gems', 0
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

create or replace function public.handle_gift_history_insert()
returns trigger as $$
declare
  computed_stars integer;
begin
  computed_stars := public.calculate_gift_stars(new.item_id, new.coins_value, new.quantity);

  update public.profiles
  set total_stars_received = total_stars_received + computed_stars
  where id = new.receiver_id;

  update public.profiles
  set total_stars_gifted = total_stars_gifted + computed_stars
  where id = new.sender_id;

  return new;
end;
$$ language plpgsql security definer;

-- 5. Production-Ready Atomic send_room_gift RPC with strict balance checks & audit logging
create or replace function public.send_room_gift(
  p_room_id text,
  p_receiver_id uuid,
  p_gift_name text,
  p_coins_value integer,
  p_quantity integer default 1
) returns jsonb as $$
declare
  v_sender_id uuid := auth.uid();
  v_sender_balance integer := 0;
  v_total_cost integer;
  v_gift_id uuid;
  v_sender_name text;
  v_receiver_name text;
  v_stars integer;
begin
  if v_sender_id is null then
    raise exception 'Not authenticated';
  end if;

  v_total_cost := p_coins_value * p_quantity;

  -- Ensure sender wallet exists with ZERO default balance
  insert into public.wallets (id, coins_balance, gold_coins, silver_coins)
  values (v_sender_id, 0, 0, 0)
  on conflict (id) do nothing;

  -- Lock Sender Wallet Row
  select greatest(coalesce(coins_balance, 0), coalesce(gold_coins, 0)) into v_sender_balance
  from public.wallets
  where id = v_sender_id
  for update;

  if coalesce(v_sender_balance, 0) < v_total_cost then
    raise exception 'Insufficient Gold Coins: Required % coins, but available balance is % coins.', v_total_cost, coalesce(v_sender_balance, 0);
  end if;

  select display_name into v_sender_name from public.profiles where id = v_sender_id;
  if v_sender_name is null then v_sender_name := 'Sender'; end if;

  select display_name into v_receiver_name from public.profiles where id = p_receiver_id;
  if v_receiver_name is null then v_receiver_name := 'Receiver'; end if;

  v_stars := public.calculate_gift_stars(p_gift_name, p_coins_value, p_quantity);

  -- Deduct from sender
  update public.wallets
  set coins_balance = greatest(0, coins_balance - v_total_cost),
      gold_coins = greatest(0, gold_coins - v_total_cost),
      updated_at = timezone('utc'::text, now())
  where id = v_sender_id;

  insert into public.wallet_transactions (wallet_id, amount, currency, type, status, reference_id, details)
  values (v_sender_id, v_total_cost, 'gold', 'Spend', 'Completed', gen_random_uuid()::text,
          'Sent ' || p_gift_name || ' gift in voice room');

  -- Add to receiver
  if v_sender_id <> p_receiver_id then
    update public.wallets
    set coins_balance = coalesce(coins_balance, 0) + v_total_cost,
        gold_coins = coalesce(gold_coins, 0) + v_total_cost,
        updated_at = timezone('utc'::text, now())
    where id = p_receiver_id;

    insert into public.wallet_transactions (wallet_id, amount, currency, type, status, reference_id, details)
    values (p_receiver_id, v_total_cost, 'gold', 'Bonus', 'Completed', gen_random_uuid()::text,
            'Received ' || p_gift_name || ' gift in voice room');
  end if;

  -- Record gift history & room stats
  insert into public.gift_history (sender_id, receiver_id, item_id, item_type, quantity, stars_value, room_id, created_at)
  values (v_sender_id, p_receiver_id, p_gift_name, 'VirtualGift', p_quantity, v_stars, p_room_id, timezone('utc'::text, now()));

  insert into public.room_gifts (room_id, sender_id, receiver_id, gift_name, coins_value, quantity)
  values (p_room_id, v_sender_id, p_receiver_id, p_gift_name, p_coins_value, p_quantity)
  returning id into v_gift_id;

  update public.rooms
  set total_room_gifts = coalesce(total_room_gifts, 0) + p_quantity,
      today_room_gifts = coalesce(today_room_gifts, 0) + p_quantity,
      total_room_stars = coalesce(total_room_stars, 0) + v_stars,
      today_room_stars = coalesce(today_room_stars, 0) + v_stars,
      updated_at = timezone('utc'::text, now())
  where id = p_room_id;

  return jsonb_build_object(
    'success', true,
    'gift_id', v_gift_id,
    'remaining_balance', greatest(0, v_sender_balance - v_total_cost)
  );
end;
$$ language plpgsql security definer;

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

-- 202607090022_fix_tag_system_guard_and_pipeline.sql
-- FINAL FIX: Two remaining issues blocking identity tag from appearing after purchase
--
-- Issue 1: check_profile_restricted_columns uses current_setting('role') which returns
--   the SESSION role ('authenticated'), not the FUNCTION execution role.
--   So even SECURITY DEFINER functions that run as 'postgres' get blocked.
--   Fix: use current_user (the effective user during function execution) instead.
--
-- Issue 2: rebuild_user_tag_system is missing "set search_path = public" and
--   "security definer" is declared but the check_profile_restricted_columns BEFORE
--   trigger still fires for the internal UPDATE, blocking tag_system writes.
--
-- Issue 3: recompute_user_entitlements updates profiles.vip_level → fires
--   trigger_profile_rebuild_tag_system (from migration 012) which calls rebuild_user_tag_system.
--   That function runs correctly. BUT tr_on_profile_membership_change also fires,
--   calling recompute_user_entitlements again. The second run does another
--   UPDATE profiles SET membership_assets = ... which fires check_profile_restricted_columns
--   again. All fine as long as the guard uses current_user.
--   Fix: guard must allow 'postgres' (supabase_admin) and function execution contexts.

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1: Fix the restricted-columns guard to use current_user (execution role)
--         instead of current_setting('role') (session role).
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.check_profile_restricted_columns_update()
returns trigger as $$
begin
  if old.tag_lights is distinct from new.tag_lights or
     old.r_tags is distinct from new.r_tags or
     old.badges is distinct from new.badges or
     old.tag_system is distinct from new.tag_system then

    -- Allow only internal backend functions (postgres / supabase_admin / service_role).
    -- Block direct client mutations from 'authenticated' or 'anon' session users.
    -- current_user = the effective role during execution (postgres for SECURITY DEFINER).
    -- current_setting('role') = session role (always 'authenticated' for logged-in users).
    if current_user in ('authenticated', 'anon') then
      raise exception 'You do not have permission to modify restricted profile columns (tag_system, tag_lights, r_tags, badges).';
    end if;
  end if;
  return new;
end;
$$ language plpgsql;

-- 3. Update rebuild_user_tag_system to use c.identity_tag instead of c.name
create or replace function public.rebuild_user_tag_system(p_user_id uuid)
returns void as $$
declare
  v_r_tags text[];
  v_vip_level integer;
  v_vip_expiry timestamp with time zone;
  v_novel_level integer;
  v_novel_expiry timestamp with time zone;
  v_level integer;
  v_verified boolean;
  v_showcased_badges text[];

  v_identity_tags jsonb[] := array[]::jsonb[];
  v_comm_id text;
  v_comm_name text;
  v_comm_level integer;
  v_comm_is_official boolean;
  v_comm_is_verified boolean;
  v_comm_role text;

  -- Custom tag parameters
  v_tag_color text := '#64748B'; -- default Slate
  v_tag_border text := 'none';
  v_tag_glow text := 'none';
  v_tag_animation text := 'none';
  v_tag_effects text := 'none';
  v_tag_icon text := '🏷️';

  v_special_tag text := null;
  v_verified_tag text := null;
  v_role_tag text := null;

  v_vip_tag_url text;
  v_novel_tag_url text;

  v_now timestamp with time zone := now();
  v_tag_system jsonb;
  v_tag_lights text[] := '{}';
begin
  select r_tags, vip_level, vip_expiry, novel_level, novel_expiry, level, verified, showcased_badges
  into v_r_tags, v_vip_level, v_vip_expiry, v_novel_level, v_novel_expiry, v_level, v_verified, v_showcased_badges
  from public.profiles
  where id = p_user_id;

  if not found then return; end if;
  if v_level is null then v_level := 1; end if;

  -- 1. ID Level Tag
  v_identity_tags := array_append(v_identity_tags, jsonb_build_object(
    'type', 'id_level',
    'value', 'Lv.' || v_level,
    'image_url', 'asset://assets/identity_tags/id_level_' || least(v_level, 2) || '.png'
  ));
  v_tag_lights := array_append(v_tag_lights, 'ID Level ' || v_level);

  -- 2. Community Tag (from memberships, prioritizing c.identity_tag)
  select m.community_id, coalesce(c.identity_tag, c.name), c.level, c.is_official, c.is_verified, m.role
  into v_comm_id, v_comm_name, v_comm_level, v_comm_is_official, v_comm_is_verified, v_comm_role
  from public.community_memberships m
  join public.communities c on m.community_id = c.id
  where m.user_id = p_user_id
  limit 1;

  if v_comm_id is not null then
    -- Backend assigns tag attributes dynamically
    if v_comm_is_official then
      v_tag_color := '#818CF8'; -- Indigo
      v_tag_border := 'rainbow_neon';
      v_tag_glow := 'neon';
      v_tag_animation := 'rotating';
      v_tag_effects := 'stars';
      v_tag_icon := '👑';
    elsif v_comm_level >= 15 then
      v_tag_color := '#FFD700'; -- Gold
      v_tag_border := 'gold_glow';
      v_tag_glow := 'gold';
      v_tag_animation := 'breathing';
      v_tag_effects := 'sparkles';
      v_tag_icon := '🏆';
    elsif v_comm_level >= 10 then
      v_tag_color := '#E2E8F0'; -- Silver
      v_tag_border := 'silver_glow';
      v_tag_glow := 'silver';
      v_tag_animation := 'pulse';
      v_tag_icon := '⭐';
    elsif v_comm_level >= 5 then
      v_tag_color := '#B45309'; -- Bronze
      v_tag_border := 'bronze_glow';
      v_tag_glow := 'bronze';
      v_tag_icon := '🔥';
    else
      v_tag_color := '#64748B'; -- Slate
      v_tag_border := 'none';
      v_tag_glow := 'none';
      v_tag_icon := '🏷️';
    end if;

    v_identity_tags := array_append(v_identity_tags, jsonb_build_object(
      'type', 'community',
      'value', v_comm_name,
      'color', v_tag_color,
      'border', v_tag_border,
      'glow', v_tag_glow,
      'animation', v_tag_animation,
      'effects', v_tag_effects,
      'icon', v_tag_icon
    ));
    v_tag_lights := array_append(v_tag_lights, v_comm_name);
  end if;

  -- 3. VIP Identity Tag
  if v_vip_level > 0 and (v_vip_expiry is null or v_vip_expiry > v_now) then
    select cdn_url into v_vip_tag_url
    from public.cosmetic_assets
    where required_membership = 'VIP'
      and type = 'identity_tag'
    limit 1;

    v_identity_tags := array_append(v_identity_tags, jsonb_build_object(
      'type', 'vip',
      'value', 'VIP ' || v_vip_level,
      'image_url', v_vip_tag_url
    ));
    v_tag_lights := array_append(v_tag_lights, 'VIP ' || v_vip_level);
  end if;

  -- 4. Novel Identity Tag
  if v_novel_level > 0 and (v_novel_expiry is null or v_novel_expiry > v_now) then
    select cdn_url into v_novel_tag_url
    from public.cosmetic_assets
    where required_membership = 'Novel'
      and type = 'identity_tag'
    limit 1;

    v_identity_tags := array_append(v_identity_tags, jsonb_build_object(
      'type', 'novel',
      'value', 'Novel ' || v_novel_level,
      'image_url', v_novel_tag_url
    ));
    v_tag_lights := array_append(v_tag_lights, 'Novel ' || v_novel_level);
  end if;

  -- Build final JSON structure
  v_tag_system := jsonb_build_object(
    'identity_tags', v_identity_tags,
    'tag_lights', v_tag_lights
  );

  update public.profiles
  set tag_system = v_tag_system
  where id = p_user_id;

end;
$$ language plpgsql security definer;

create or replace function public.on_profile_rebuild_tag_system()
returns trigger as $$
begin
  perform public.rebuild_user_tag_system(new.id);
  return new;
end;
$$ language plpgsql security definer set search_path = public;

-- 202607230010_robust_audit_logs.sql
-- Wrap the insertion into public.account_audit_logs inside an EXCEPTION block.
-- This ensures that any audit log serialization or insertion failures (e.g. JSON cast errors,
-- permission issues, search path resolver errors) do not fail the core transaction (like sign up or update).

CREATE OR REPLACE FUNCTION public.log_profile_changes()
RETURNS TRIGGER AS $$
DECLARE
  v_actor_id uuid;
BEGIN
  -- Safely extract user ID from auth session
  BEGIN
    v_actor_id := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_actor_id := null;
  END;

  -- Attempt to insert audit log without throwing exceptions to the main transaction
  BEGIN
    INSERT INTO public.account_audit_logs (
      target_table,
      operation,
      actor_id,
      record_id,
      old_data,
      new_data,
      reason
    )
    VALUES (
      TG_TABLE_NAME,
      TG_OP,
      v_actor_id,
      COALESCE(new.id, old.id),
      CASE WHEN TG_OP = 'INSERT' THEN null ELSE to_jsonb(old) END,
      CASE WHEN TG_OP = 'DELETE' THEN null ELSE to_jsonb(new) END,
      'Database automatic log for ' || TG_OP || ' on ' || TG_TABLE_NAME
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Audit log failed: %', SQLERRM;
  END;
  
  IF TG_OP = 'DELETE' THEN
    RETURN old;
  ELSE
    RETURN new;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 5. Trigger to automatically compile active cosmetic assets and tags when profiles levels change
create or replace function public.on_profile_membership_change()
returns trigger as $$
begin
  new.membership_assets := public.rebuild_user_membership_assets(new.id);
  return new;
end;
$$ language plpgsql security definer;

-- 6. Trigger to sync user_vip / user_novel table updates to profiles table
create or replace function public.sync_user_membership_tables_to_profile()
returns trigger as $$
begin
  if TG_TABLE_NAME = 'user_vip' then
    update public.profiles
    set vip_level = case when new.is_active and new.expiry_date > now() then new.level else 0 end,
        vip_expiry = case when new.is_active and new.expiry_date > now() then new.expiry_date else null end
    where id = new.user_id;
    
    -- Rebuild tags for user
    perform public.rebuild_user_tag_system(new.user_id);
    -- Rebuild assets
    update public.profiles
    set membership_assets = public.rebuild_user_membership_assets(new.user_id)
    where id = new.user_id;
  elsif TG_TABLE_NAME = 'user_novel' then
    update public.profiles
    set novel_level = case when new.is_active and new.expiry_date > now() then new.level else 0 end,
        novel_expiry = case when new.is_active and new.expiry_date > now() then new.expiry_date else null end
    where id = new.user_id;
    
    -- Rebuild tags for user
    perform public.rebuild_user_tag_system(new.user_id);
    -- Rebuild assets
    update public.profiles
    set membership_assets = public.rebuild_user_membership_assets(new.user_id)
    where id = new.user_id;
  end if;
  return new;
end;
$$ language plpgsql security definer;

-- 3. Server Expiry Guard: Check and clean expired memberships using server time now()
create or replace function public.check_and_clean_expired_memberships()
returns void as $$
declare
  r record;
begin
  -- 1. Check expired VIP subscriptions
  for r in
    select id, user_id, level, expiry_date
    from public.subscriptions
    where membership_type = 'VIP'
      and status = 'Active'
      and expiry_date <= now()
  loop
    -- Update subscription status
    update public.subscriptions
    set status = 'Expired'
    where id = r.id;

    -- Update profile VIP level if current expiry is past
    update public.profiles
    set vip_level = 0
    where id = r.user_id
      and (vip_expiry is null or vip_expiry <= now());

    -- Unequip VIP avatar frames if expired
    update public.user_customizations
    set is_equipped = false
    where user_id = r.user_id
      and type = 'Avatar Frame'
      and name ilike 'VIP%';

    -- Audit log
    insert into public.vip_audit_logs (user_id, action, category, item_name, details)
    values (r.user_id, 'VIP_EXPIRED', 'VIP', 'VIP Level ' || r.level, jsonb_build_object('expired_at', r.expiry_date, 'server_time', now()));

    -- Rebuild identity tags
    perform public.rebuild_user_tag_system(r.user_id);
  end loop;

  -- 2. Check expired Novel subscriptions
  for r in
    select id, user_id, level, expiry_date
    from public.subscriptions
    where membership_type = 'Novel'
      and status = 'Active'
      and expiry_date <= now()
  loop
    update public.subscriptions
    set status = 'Expired'
    where id = r.id;

    update public.profiles
    set novel_level = 0
    where id = r.user_id
      and (novel_expiry is null or novel_expiry <= now());

    insert into public.vip_audit_logs (user_id, action, category, item_name, details)
    values (r.user_id, 'NOVEL_EXPIRED', 'Novel', 'Novel Level ' || r.level, jsonb_build_object('expired_at', r.expiry_date, 'server_time', now()));

    perform public.rebuild_user_tag_system(r.user_id);
  end loop;
end;
$$ language plpgsql security definer set search_path = public;

-- 4. Single-Transaction Membership Purchase RPC
create or replace function public.record_membership_purchase(
  p_user_id        uuid,
  p_product_name   text,
  p_category       text,
  p_amount         numeric,
  p_final_amount   numeric,
  p_payment_method text,
  p_duration       text,
  p_custom_expiry  timestamp with time zone default null,
  p_payment_id     text default null
)
returns boolean as $$
declare
  v_level         integer;
  v_days          integer;
  v_expiry        timestamp with time zone;
  v_wallet_coins  integer;
  v_price_coins   integer;
  v_old_expiry    timestamp with time zone;
  v_old_level     integer := 0;
  v_action        text := 'VIP_PURCHASE';
  v_frame_name    text;
begin
  if p_user_id is null or p_product_name is null or p_category is null then
    raise exception 'record_membership_purchase: missing input parameters';
  end if;
  if p_category not in ('VIP','Novel') then
    raise exception 'record_membership_purchase: unsupported category %', p_category;
  end if;

  -- Idempotency check: return success if payment_id already processed
  if p_payment_id is not null then
    if exists (select 1 from public.purchases where payment_id = p_payment_id and status = 'Success') then
      return true;
    end if;
  end if;

  -- Parse target level
  v_level := coalesce(substring(p_product_name from '[0-9]+')::integer, 1);

  -- Get current VIP level and expiry
  if p_category = 'VIP' then
    select vip_level, vip_expiry into v_old_level, v_old_expiry
    from public.profiles where id = p_user_id;
  elsif p_category = 'Novel' then
    select novel_level, novel_expiry into v_old_level, v_old_expiry
    from public.profiles where id = p_user_id;
  end if;

  v_old_level := coalesce(v_old_level, 0);

  if v_old_level > 0 and v_old_expiry is not null and v_old_expiry > now() then
    if v_level > v_old_level then
      v_action := 'VIP_UPGRADE';
    else
      v_action := 'VIP_RENEWAL';
    end if;
  end if;

  -- Calculate expiry date
  if p_custom_expiry is not null then
    v_expiry := p_custom_expiry;
  else
    v_days := case p_duration
      when '3 Days'  then 3
      when '7 Days'  then 7
      when '15 Days' then 15
      when '30 Days' then 30
      when '90 Days' then 90
      when '1 Year'  then 365
      when '12 Months' then 365
      else 30
    end;

    if v_old_expiry is not null and v_old_expiry > now() then
      v_expiry := v_old_expiry + (v_days || ' days')::interval;
    else
      v_expiry := now() + (v_days || ' days')::interval;
    end if;
  end if;

  -- Gold Coins deduction if paying via wallet coins
  if p_payment_method = 'Gold Coins Wallet' then
    v_price_coins := p_final_amount::integer;

    select coins_balance into v_wallet_coins
    from public.wallets
    where id = p_user_id
    for update;

    if v_wallet_coins is null then
      raise exception 'Wallet not found for user %', p_user_id;
    end if;
    if v_wallet_coins < v_price_coins then
      raise exception 'Insufficient Gold Coins: have %, need %', v_wallet_coins, v_price_coins;
    end if;

    update public.wallets
    set gold_coins    = gold_coins    - v_price_coins,
        coins_balance = coins_balance - v_price_coins
    where id = p_user_id;

    insert into public.wallet_transactions
      (wallet_id, amount, currency, type, status, details)
    values
      (p_user_id, v_price_coins, 'Gold Coins', 'Spend', 'Completed',
       'Purchased ' || p_product_name);
  end if;

  -- Record in purchase ledger
  insert into public.purchases
    (user_id, product_name, category, amount, final_amount, payment_method, status, duration, expiry_date, payment_id)
  values
    (p_user_id, p_product_name, p_category, p_amount, p_final_amount,
     p_payment_method, 'Success', p_duration, v_expiry, p_payment_id);

  -- Update or insert into subscriptions
  if exists (select 1 from public.subscriptions where user_id = p_user_id and membership_type = p_category) then
    update public.subscriptions
    set level           = greatest(subscriptions.level, v_level),
        activation_date = now(),
        expiry_date     = greatest(subscriptions.expiry_date, v_expiry),
        status          = 'Active',
        payment_id      = p_payment_id
    where user_id = p_user_id and membership_type = p_category;
  else
    insert into public.subscriptions
      (user_id, membership_type, level, purchase_date, activation_date, expiry_date, auto_renewal, status, payment_id)
    values
      (p_user_id, p_category, v_level, now(), now(), v_expiry, true, 'Active', p_payment_id);
  end if;

  -- Determine VIP avatar frame name
  if p_category = 'VIP' then
    if v_level = 1 then v_frame_name := 'Royal Frame';
    elsif v_level = 2 then v_frame_name := 'Neon Frame (Animated)';
    elsif v_level = 3 then v_frame_name := 'Gold Glow Frame';
    elsif v_level = 4 then v_frame_name := 'Diamond Frame';
    elsif v_level = 5 then v_frame_name := 'Crystal Cyan Frame';
    elsif v_level = 6 then v_frame_name := 'Rainbow Frame (Animated)';
    elsif v_level = 7 then v_frame_name := 'Royal Crown (Animated)';
    else v_frame_name := 'Royal Frame';
    end if;

    update public.profiles
    set vip_level = greatest(coalesce(vip_level, 0), v_level),
        vip_expiry = greatest(coalesce(vip_expiry, now()), v_expiry),
        avatar_frame = v_frame_name
    where id = p_user_id;

    -- Equip VIP Avatar Frame in user_customizations
    update public.user_customizations
    set is_equipped = false
    where user_id = p_user_id and type = 'Avatar Frame';

    insert into public.user_customizations (user_id, type, name, is_equipped)
    values (p_user_id, 'Avatar Frame', v_frame_name, true)
    on conflict (user_id, type, name) do update set is_equipped = true;

  elsif p_category = 'Novel' then
    update public.profiles
    set novel_level = greatest(coalesce(novel_level, 0), v_level),
        novel_expiry = greatest(coalesce(novel_expiry, now()), v_expiry)
    where id = p_user_id;
  end if;

  -- Record audit log
  insert into public.vip_audit_logs (user_id, action, category, item_name, details)
  values (
    p_user_id,
    v_action,
    p_category,
    p_product_name,
    jsonb_build_object(
      'level', v_level,
      'amount', p_amount,
      'duration', p_duration,
      'expiry', v_expiry,
      'payment_id', p_payment_id
    )
  );

  -- Rebuild identity tags
  perform public.rebuild_user_tag_system(p_user_id);

  return true;
exception
  when others then
    raise;
end;
$$ language plpgsql security definer set search_path = public;

-- 5. Safe recompute_user_entitlements: Preserves equipped frame in profiles/user_customizations
create or replace function public.recompute_user_entitlements(p_user_id uuid)
returns void as $$
declare
  v_vip_sub record;
  v_novel_sub record;
  v_equipped_frame text;
  v_vip_level integer := 0;
  v_novel_level integer := 0;
  v_vip_expiry timestamp with time zone := null;
  v_novel_expiry timestamp with time zone := null;
begin
  if p_user_id is null then return; end if;

  select level, expiry_date into v_vip_sub
  from public.subscriptions
  where user_id = p_user_id and membership_type = 'VIP' and status = 'Active' and expiry_date > now()
  order by level desc limit 1;
  if found then
    v_vip_level  := v_vip_sub.level;
    v_vip_expiry := v_vip_sub.expiry_date;
  end if;

  select level, expiry_date into v_novel_sub
  from public.subscriptions
  where user_id = p_user_id and membership_type = 'Novel' and status = 'Active' and expiry_date > now()
  order by level desc limit 1;
  if found then
    v_novel_level  := v_novel_sub.level;
    v_novel_expiry := v_novel_sub.expiry_date;
  end if;

  -- Read currently equipped frame from user_customizations or profiles
  select name into v_equipped_frame
  from public.user_customizations
  where user_id = p_user_id and type in ('Avatar Frame', 'avatar_frame', 'profile_frame') and is_equipped = true
  limit 1;

  if v_equipped_frame is null or v_equipped_frame = '' then
    select avatar_frame into v_equipped_frame
    from public.profiles where id = p_user_id;
  end if;

  if v_equipped_frame is null or v_equipped_frame = '' then
    v_equipped_frame := 'Normal';
  end if;

  -- Write profile membership columns & preserve equipped frame
  update public.profiles
  set vip_level    = v_vip_level,
      vip_expiry   = v_vip_expiry,
      novel_level  = v_novel_level,
      novel_expiry = v_novel_expiry,
      avatar_frame = v_equipped_frame
  where id = p_user_id;

  -- Sync user_vip table safely
  if v_vip_level > 0 then
    if exists (select 1 from public.user_vip where user_id = p_user_id) then
      update public.user_vip
      set level = greatest(level, v_vip_level), expiry_date = greatest(expiry_date, v_vip_expiry), is_active = true, is_vip = true, status = 'active'
      where user_id = p_user_id;
    else
      insert into public.user_vip (user_id, level, start_date, expiry_date, is_active, is_vip, vip_level, status)
      values (p_user_id, v_vip_level, now(), v_vip_expiry, true, true, v_vip_level, 'active');
    end if;
  else
    update public.user_vip set is_active = false, is_vip = false, status = 'inactive' where user_id = p_user_id;
  end if;

  -- Sync user_novel table safely
  if v_novel_level > 0 then
    if exists (select 1 from public.user_novel where user_id = p_user_id) then
      update public.user_novel set level = greatest(level, v_novel_level), expiry_date = greatest(expiry_date, v_novel_expiry), is_active = true
      where user_id = p_user_id;
    else
      insert into public.user_novel (user_id, level, start_date, expiry_date, is_active)
      values (p_user_id, v_novel_level, now(), v_novel_expiry, true);
    end if;
  else
    update public.user_novel set is_active = false where user_id = p_user_id;
  end if;

exception when others then
  null;
end;
$$ language plpgsql security definer set search_path = public;

-- 4. Rebuild on_profile_vip_novel_update trigger function to avoid ON CONFLICT on subscriptions
create or replace function public.on_profile_vip_novel_update()
returns trigger as $$
begin
  -- Guard: only fire when admin/backend directly sets vip_level or novel_level
  -- (purchases go through subscriptions trigger, not here)
  if (old.vip_level is distinct from new.vip_level) or (old.novel_level is distinct from new.novel_level) then

    -- Sync subscription table so the engine reads the right level
    if new.vip_level > 0 then
      if exists (select 1 from public.subscriptions where user_id = new.id and membership_type = 'VIP') then
        update public.subscriptions
        set level       = new.vip_level,
            expiry_date = coalesce(new.vip_expiry, now() + interval '30 days'),
            status      = 'Active'
        where user_id = new.id and membership_type = 'VIP';
      else
        insert into public.subscriptions (user_id, membership_type, level, expiry_date, status)
        values (new.id, 'VIP', new.vip_level, coalesce(new.vip_expiry, now() + interval '30 days'), 'Active');
      end if;
    else
      update public.subscriptions
      set status = 'Expired'
      where user_id = new.id and membership_type = 'VIP';
    end if;

    if new.novel_level > 0 then
      if exists (select 1 from public.subscriptions where user_id = new.id and membership_type = 'Novel') then
        update public.subscriptions
        set level       = new.novel_level,
            expiry_date = coalesce(new.novel_expiry, now() + interval '30 days'),
            status      = 'Active'
        where user_id = new.id and membership_type = 'Novel';
      else
        insert into public.subscriptions (user_id, membership_type, level, expiry_date, status)
        values (new.id, 'Novel', new.novel_level, coalesce(new.novel_expiry, now() + interval '30 days'), 'Active');
      end if;
    else
      update public.subscriptions
      set status = 'Expired'
      where user_id = new.id and membership_type = 'Novel';
    end if;

    -- Run entitlements AFTER the profile row is committed (AFTER trigger)
    perform public.recompute_user_entitlements(new.id);
  end if;
  return new;
end;
$$ language plpgsql security definer;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 8: Daily integrity repair job
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.daily_integrity_job()
returns void as $$
declare
  v_user record;
begin
  perform public.check_and_clean_expired_memberships();
  for v_user in select id from public.profiles loop
    perform public.recompute_user_entitlements(v_user.id);
  end loop;
end;
$$ language plpgsql security definer;

-- 4. Update create_arena RPC to ensure owner_user_id, host_id, and room_owner are initialized identically
CREATE OR REPLACE FUNCTION public.create_arena(
  p_name             text,
  p_username         text,
  p_description      text     DEFAULT '',
  p_category         text     DEFAULT 'Education',
  p_language         text     DEFAULT 'English',
  p_tags             text[]   DEFAULT '{}',
  p_rules            text[]   DEFAULT '{}',
  p_creation_method  text     DEFAULT 'ticket',
  p_entry_permission text     DEFAULT 'everyone',
  p_avatar           text     DEFAULT NULL,
  p_banner           text     DEFAULT NULL
) RETURNS text AS $$
DECLARE
  v_user_id      uuid := auth.uid();
  v_room_id      text;
  v_livekit_name text;
  v_ticket_id    uuid;
  v_balance      integer;
  v_user_level   integer;
  v_coins_spent  integer := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Must be logged in to create an Arena.';
  END IF;

  -- ── Check Username Format & Availability ─────────────────────────────
  IF p_username !~ '^@[a-z0-9_]{3,30}$' THEN
    RAISE EXCEPTION 'INVALID_USERNAME: Username must start with @ and contain 3-30 lowercase letters, numbers, or underscores.';
  END IF;

  IF EXISTS (SELECT 1 FROM public.rooms WHERE username = p_username) THEN
    RAISE EXCEPTION 'USERNAME_TAKEN: Room handle % is already in use.', p_username;
  END IF;

  -- ── Validate Creation Method ──────────────────────────────────────────
  IF p_creation_method NOT IN ('ticket', 'coins', 'level') THEN
    RAISE EXCEPTION 'INVALID_METHOD: Creation method must be ticket, coins, or level.';
  END IF;

  -- ── Method: TICKET ──────────────────────────────────────────────────
  IF p_creation_method = 'ticket' THEN
    SELECT id INTO v_ticket_id
    FROM public.arena_tickets
    WHERE user_id = v_user_id AND is_consumed = false
    ORDER BY granted_at ASC
    LIMIT 1
    FOR UPDATE;

    IF v_ticket_id IS NULL THEN
      RAISE EXCEPTION 'NO_TICKET: You do not have an active Arena Ticket. Earn one via progression or purchase with Gold Coins.';
    END IF;

    UPDATE public.arena_tickets
    SET is_consumed = true, consumed_at = now()
    WHERE id = v_ticket_id;

    v_coins_spent := 0;

  -- ── Method: COINS ────────────────────────────────────────────────────
  ELSIF p_creation_method = 'coins' THEN
    SELECT coins_balance INTO v_balance
    FROM public.wallets
    WHERE id = v_user_id
    FOR UPDATE;

    IF coalesce(v_balance, 0) < 499 THEN
      RAISE EXCEPTION 'INSUFFICIENT_COINS: Creating an Arena costs 499 Gold Coins. Your balance: % coins.', coalesce(v_balance, 0);
    END IF;

    UPDATE public.wallets
    SET coins_balance = coins_balance - 499
    WHERE id = v_user_id;

    INSERT INTO public.wallet_transactions
      (wallet_id, amount, currency, type, status, details)
    VALUES
      (v_user_id, 499, 'Coins', 'Withdrawal', 'Completed', 'Created permanent Arena: ' || p_name);

    v_coins_spent := 499;

  -- ── Method: LEVEL ────────────────────────────────────────────────────
  ELSIF p_creation_method = 'level' THEN
    SELECT level INTO v_user_level
    FROM public.profiles
    WHERE id = v_user_id;

    IF coalesce(v_user_level, 1) < 15 THEN
      RAISE EXCEPTION 'LEVEL_REQUIRED: Arena creation via ID Level requires Level 15 or above. Your current level: %.', coalesce(v_user_level, 1);
    END IF;

    v_coins_spent := 0;
  END IF;

  -- ── Generate unique IDs ───────────────────────────────────────────────
  v_room_id      := public.generate_unique_room_id();
  v_livekit_name := 'arena_' || encode(gen_random_bytes(8), 'hex');

  -- ── Insert the permanent Arena ────────────────────────────────────────
  INSERT INTO public.rooms (
    id, name, username, description, category, language, tags, rules,
    host_id, room_owner, owner_user_id, status, visibility, recording_status, level_requirement,
    vip_requirement, verification_requirement, livekit_room_name,
    avatar, banner, is_permanent
  ) VALUES (
    v_room_id,
    p_name,
    p_username,
    p_description,
    p_category,
    p_language,
    p_tags,
    p_rules,
    v_user_id,
    v_user_id,
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
    true
  );

  -- ── Write audit log ───────────────────────────────────────────────────
  INSERT INTO public.arena_creation_logs
    (arena_id, user_id, creation_method, ticket_id, coins_spent)
  VALUES
    (v_room_id, v_user_id, p_creation_method, v_ticket_id, v_coins_spent);

  RETURN v_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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

-- 202607170006_fix_membership_trigger.sql
-- Fix public.tr_on_community_membership_change trigger to avoid writing to non-existent profiles.communities column

create or replace function public.tr_on_community_membership_change()
returns trigger as $$
begin
  if tg_op = 'INSERT' or tg_op = 'UPDATE' then
    perform public.rebuild_user_tag_system(new.user_id);
  elsif tg_op = 'DELETE' then
    perform public.rebuild_user_tag_system(old.user_id);
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

-- 2. Redefine create_community_rpc to use correct columns: currency, type, status, details and correct value: 'Gold Coins'
create or replace function public.create_community_rpc(
  p_id text,
  p_name text,
  p_description text,
  p_category text,
  p_language text,
  p_country text,
  p_rules text,
  p_join_mode text,
  p_min_id_level integer,
  p_preferred_languages text[],
  p_preferred_countries text[],
  p_preferred_interests text[],
  p_tags text[],
  p_visibility text,
  p_image text,
  p_banner text,
  p_creation_method text,
  p_identity_tag text default null
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_user_level integer;
  v_wallet_record record;
  v_ticket_id uuid;
  v_comm_exists boolean;
  v_already_member boolean;
begin
  -- Authentication check
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  -- Check if already in a community (One Community Rule)
  select exists (
    select 1 from public.community_memberships where user_id = v_user_id
  ) into v_already_member;
  if v_already_member then
    return jsonb_build_object('success', false, 'error', 'You are already a member of a community. You must leave your current community first.');
  end if;

  -- Check if community ID (username) is unique
  select exists (
    select 1 from public.communities where id = p_id
  ) into v_comm_exists;
  if v_comm_exists then
    return jsonb_build_object('success', false, 'error', 'Community Username is already taken.');
  end if;

  -- Validate Identity Tag uniqueness
  if p_identity_tag is not null and p_identity_tag <> '' then
    if exists (
      select 1 from public.communities where lower(identity_tag) = lower(p_identity_tag)
    ) then
      return jsonb_build_object('success', false, 'error', 'Identity Tag is already taken.');
    end if;
  end if;

  -- Validation and deduction based on creation method
  if p_creation_method = 'level' then
    select level into v_user_level from public.profiles where id = v_user_id;
    if v_user_level is null or v_user_level < 25 then
      return jsonb_build_object('success', false, 'error', 'Minimum ID level of 25 is required to create via Level progression.');
    end if;

  elsif p_creation_method = 'ticket' then
    select id into v_ticket_id 
    from public.inventory 
    where user_id = v_user_id 
      and (asset_id = 'community_creation_ticket' or asset_id = 'creation_ticket')
      and status = 'Active' 
    limit 1;

    if v_ticket_id is null then
      return jsonb_build_object('success', false, 'error', 'You do not have a Community Creation Ticket.');
    end if;

    update public.inventory set status = 'Used' where id = v_ticket_id;

  elsif p_creation_method = 'coins' then
    select coins_balance, gold_coins into v_wallet_record from public.wallets where id = v_user_id;
    if v_wallet_record is null or (coalesce(v_wallet_record.gold_coins, 0) < 699 and coalesce(v_wallet_record.coins_balance, 0) < 699) then
      return jsonb_build_object('success', false, 'error', 'Insufficient Gold Coins. 699 Coins are required.');
    end if;

    -- Deduct 699 coins
    update public.wallets 
    set coins_balance = greatest(0, coins_balance - 699),
        gold_coins = greatest(0, gold_coins - 699)
    where id = v_user_id;

    -- Corrected insert statement using redesigned schema columns and 'Gold Coins' currency
    insert into public.wallet_transactions (
      wallet_id, amount, currency, type, status, details
    ) values (
      v_user_id, 699.00, 'Gold Coins', 'Spend', 'Completed', 'Community Creation Cost'
    );

  else
    return jsonb_build_object('success', false, 'error', 'Invalid creation method. Must be level, coins, or ticket.');
  end if;

  -- Insert community
  insert into public.communities (
    id, name, description, image, banner, category, language, country, rules, 
    join_mode, min_id_level, preferred_languages, preferred_countries, 
    preferred_interests, tags, visibility, owner, is_official, is_verified, 
    level, xp, member_count, created_at, identity_tag
  ) values (
    p_id, p_name, p_description, p_image, p_banner, p_category, p_language, p_country, p_rules,
    p_join_mode, p_min_id_level, p_preferred_languages, p_preferred_countries,
    p_preferred_interests, p_tags, p_visibility, v_user_id, false, false,
    1, 0, 1, now(), p_identity_tag
  );

  -- Insert creator membership
  insert into public.community_memberships (
    community_id, user_id, role, join_method, joined_by
  ) values (
    p_id, v_user_id, 'owner', 'creator', v_user_id
  );

  return jsonb_build_object('success', true, 'community_id', p_id);
end;
$$ language plpgsql security definer set search_path = public;

-- 9. Join Community RPC Function
create or replace function public.join_community_rpc(
  p_community_id text,
  p_introduction text default null,
  p_reason text default null,
  p_preferred_language text default null,
  p_optional_message text default null
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_profile record;
  v_comm record;
  v_cooldown_active boolean;
  v_already_member boolean;
  v_is_blocked boolean;
  v_members_count integer;
  v_capacity_limit integer;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  select level, community_next_join_time into v_profile from public.profiles where id = v_user_id;
  if v_profile is null then
    return jsonb_build_object('success', false, 'error', 'Profile not found.');
  end if;

  if v_profile.community_next_join_time is not null and v_profile.community_next_join_time > now() then
    return jsonb_build_object('success', false, 'error', 'You are in a 24-hour cooldown period after leaving your previous community.');
  end if;

  select exists (
    select 1 from public.community_memberships where user_id = v_user_id
  ) into v_already_member;
  if v_already_member then
    return jsonb_build_object('success', false, 'error', 'You are already a member of another community. You must leave it first.');
  end if;

  select * into v_comm from public.communities where id = p_community_id;
  if v_comm is null then
    return jsonb_build_object('success', false, 'error', 'Community not found.');
  end if;

  if v_profile.level < v_comm.min_id_level then
    return jsonb_build_object('success', false, 'error', 'Your ID level (' || v_profile.level || ') is lower than the community requirement (' || v_comm.min_id_level || ').');
  end if;

  -- Check capacity limits for non-official communities
  if not v_comm.is_official then
    select count(*) into v_members_count from public.community_memberships where community_id = p_community_id;
    v_capacity_limit := case 
      when v_comm.level >= 15 then 500
      when v_comm.level >= 10 then 250
      when v_comm.level >= 5 then 150
      else 100
    end;

    if v_members_count >= v_capacity_limit then
      return jsonb_build_object('success', false, 'error', 'Community is full. Capacity reached.');
    end if;
  end if;

  if v_comm.join_mode = 'auto_join' then
    insert into public.community_memberships (
      community_id, user_id, role, join_method, joined_by
    ) values (
      p_community_id, v_user_id, 'member', 'auto_join', v_user_id
    );

    update public.communities
    set member_count = coalesce(member_count, 0) + 1
    where id = p_community_id;

    return jsonb_build_object('success', true, 'status', 'joined');
  else
    select exists (
      select 1 from public.community_applications
      where community_id = p_community_id and user_id = v_user_id and status = 'pending'
    ) into v_already_member;
    if v_already_member then
      return jsonb_build_object('success', false, 'error', 'You already have a pending application for this community.');
    end if;

    select exists (
      select 1 from public.community_applications
      where community_id = p_community_id and user_id = v_user_id and status = 'blocked'
    ) into v_is_blocked;
    if v_is_blocked then
      return jsonb_build_object('success', false, 'error', 'Your applications to this community have been blocked.');
    end if;

    insert into public.community_applications (
      community_id, user_id, status, introduction, reason, preferred_language, optional_message, created_at
    ) values (
      p_community_id, v_user_id, 'pending', p_introduction, p_reason, p_preferred_language, p_optional_message, now()
    );

    return jsonb_build_object('success', true, 'status', 'applied');
  end if;
end;
$$ language plpgsql security definer set search_path = public;

-- 10. Leave Community RPC Function
create or replace function public.leave_community_rpc(
  p_community_id text
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_role text;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required.');
  end if;

  select role into v_role from public.community_memberships where community_id = p_community_id and user_id = v_user_id;
  if v_role is null then
    return jsonb_build_object('success', false, 'error', 'You are not a member of this community.');
  end if;

  if v_role = 'owner' then
    return jsonb_build_object('success', false, 'error', 'Owners cannot leave the community. Transfer ownership or delete the community first.');
  end if;

  -- Remove membership
  delete from public.community_memberships where community_id = p_community_id and user_id = v_user_id;

  -- Update community member count
  update public.communities
  set member_count = greatest(0, member_count - 1)
  where id = p_community_id;

  -- Apply 24-hour cooldown on profiles
  update public.profiles
  set community_leave_time = now(),
      community_next_join_time = now() + interval '24 hours'
  where id = v_user_id;

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer set search_path = public;

-- 11. Leaderboard RPC API
create or replace function public.get_community_leaderboard_rpc(
  p_community_id text,
  p_type text, -- 'top_contributors', 'top_gift_senders', 'top_gift_receivers', 'top_active_members'
  p_limit integer default 10
)
returns jsonb as $$
declare
  v_result jsonb;
begin
  case p_type
    when 'top_contributors' then
      select json_agg(t) into v_result
      from (
        select m.user_id, p.display_name, p.username, p.avatar, m.contribution
        from public.community_memberships m
        join public.profiles p on m.user_id = p.id
        where m.community_id = p_community_id
        order by m.contribution desc
        limit p_limit
      ) t;
    when 'top_gift_senders' then
      select json_agg(t) into v_result
      from (
        select m.user_id, p.display_name, p.username, p.avatar, coalesce(sum(g.coins_value), 0) as total_sent
        from public.community_memberships m
        join public.profiles p on m.user_id = p.id
        left join public.gift_history g on g.sender_id = m.user_id
        where m.community_id = p_community_id
        group by m.user_id, p.display_name, p.username, p.avatar
        order by total_sent desc
        limit p_limit
      ) t;
    when 'top_gift_receivers' then
      select json_agg(t) into v_result
      from (
        select m.user_id, p.display_name, p.username, p.avatar, coalesce(sum(g.coins_value), 0) as total_received
        from public.community_memberships m
        join public.profiles p on m.user_id = p.id
        left join public.gift_history g on g.receiver_id = m.user_id
        where m.community_id = p_community_id
        group by m.user_id, p.display_name, p.username, p.avatar
        order by total_received desc
        limit p_limit
      ) t;
    when 'top_active_members' then
      select json_agg(t) into v_result
      from (
        select m.user_id, p.display_name, p.username, p.avatar, m.activity_score
        from public.community_memberships m
        join public.profiles p on m.user_id = p.id
        where m.community_id = p_community_id
        order by m.activity_score desc
        limit p_limit
      ) t;
    else
      return jsonb_build_object('success', false, 'error', 'Invalid leaderboard type.');
  end case;

  return jsonb_build_object('success', true, 'data', coalesce(v_result, '[]'::jsonb));
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

-- =========================================================================
-- AUTOMATIC INITIALIZATION TRIGGERS
-- =========================================================================

-- Sync user_levels back to profiles whenever level or xp changes in user_levels
create or replace function public.sync_user_level_to_profile()
returns trigger as $$
begin
  update public.profiles
  set level = new.level,
      experience = new.xp
  where id = new.id;
  return new;
end;
$$ language plpgsql security definer;

-- Initialize user_levels when a new profile is created
create or replace function public.initialize_user_levels()
returns trigger as $$
begin
  insert into public.user_levels (id, level, xp, total_xp)
  values (new.id, 1, 0, 0)
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

-- =========================================================================
-- REWARDS DISPENSER HELPER
-- =========================================================================
create or replace function public.dispense_reward(
  p_user_id uuid,
  p_source_type text,
  p_source_id text,
  p_reward_type text,
  p_amount integer,
  p_cosmetic_id text
)
returns boolean as $$
declare
  v_wallet_id uuid;
  v_cosmetic_uuid uuid;
begin
  -- Lookup wallet
  select id into v_wallet_id from public.wallets where id = p_user_id;
  if v_wallet_id is null then
    insert into public.wallets (id, gold_coins, silver_coins, diamonds, coupons)
    values (p_user_id, 0, 0, 0, 0)
    returning id into v_wallet_id;
  end if;

  -- 1. Silver / Gold / Coupons
  if p_reward_type = 'silver' then
    update public.wallets set silver_coins = silver_coins + p_amount where id = p_user_id;
    insert into public.wallet_transactions (wallet_id, amount, currency, type, status, reference_id, details)
    values (p_user_id, p_amount, 'Silver Coins', 'Bonus', 'Completed', p_source_id, 'Progression reward from ' || p_source_type);
    
  elsif p_reward_type = 'gold' then
    update public.wallets set gold_coins = gold_coins + p_amount where id = p_user_id;
    insert into public.wallet_transactions (wallet_id, amount, currency, type, status, reference_id, details)
    values (p_user_id, p_amount, 'Gold Coins', 'Bonus', 'Completed', p_source_id, 'Progression reward from ' || p_source_type);

  elsif p_reward_type = 'coupon' or p_reward_type = 'spin_ticket' then
    update public.wallets set coupons = coupons + p_amount where id = p_user_id;
    insert into public.wallet_transactions (wallet_id, amount, currency, type, status, reference_id, details)
    values (p_user_id, p_amount, 'Coupons', 'Bonus', 'Completed', p_source_id, 'Progression reward from ' || p_source_type);

  -- 2. XP Reward (recurses into XP Engine but safely)
  elsif p_reward_type = 'xp' then
    -- Add XP directly to level system (not counted in daily limits as it's a direct reward claim)
    perform public.add_direct_xp(p_user_id, p_amount, p_source_type || ':' || p_source_id);

  -- 3. Cosmetics (Frame, Badge, Title, Theme, Tag, Bubble)
  elsif p_reward_type in ('frame', 'badge', 'bubble', 'theme', 'tag') then
    -- Check if cosmetic exists in cosmetic_assets, otherwise create general one
    select asset_id into v_cosmetic_uuid from public.cosmetic_assets where name = p_cosmetic_id limit 1;
    
    if v_cosmetic_uuid is null then
      -- Auto-generate a general cosmetic asset matching parameters
      insert into public.cosmetic_assets (name, type, category, cdn_url, required_membership, required_level, enabled)
      values (
        p_cosmetic_id,
        case 
          when p_reward_type = 'frame' then 'avatar_frame'::text
          when p_reward_type = 'badge' then 'showcase_badge'::text
          when p_reward_type = 'bubble' then 'chat_bubble'::text
          when p_reward_type = 'theme' then 'profile_theme'::text
          else 'identity_tag'::text
        end,
        'General',
        'https://cdn.creaniaa.com/cosmetics/' || p_cosmetic_id || '.png',
        'None',
        0,
        true
      )
      returning asset_id into v_cosmetic_uuid;
    end if;

    -- Add to user inventory
    insert into public.inventory (user_id, asset_id, purchase_source, status)
    values (p_user_id, v_cosmetic_uuid, 'Admin Grant', 'Active')
    on conflict (user_id, asset_id) do nothing;

    -- Profiles legacy fields updates
    if p_reward_type = 'frame' then
      update public.profiles set avatar_frame = p_cosmetic_id where id = p_user_id;
    elsif p_reward_type = 'theme' then
      update public.profiles set profile_theme = p_cosmetic_id where id = p_user_id;
    elsif p_reward_type = 'badge' then
      update public.profiles set badges = array_append(badges, p_cosmetic_id)
      where id = p_user_id and not (badges @> array[p_cosmetic_id]);
    elsif p_reward_type = 'tag' then
      update public.profiles set r_tags = array_append(r_tags, p_cosmetic_id)
      where id = p_user_id and not (r_tags @> array[p_cosmetic_id]);
    end if;

  -- 4. Gifts (Bound)
  elsif p_reward_type = 'gift' then
    -- Let's log in reward_logs that gifts were granted (e.g. 10 Welcome Bound Roses)
    -- This handles items like Bound Gifts in student inventory
    null;
  end if;

  -- Log rewards
  insert into public.reward_logs (user_id, source_type, source_id, reward_type, amount, cosmetic_id, status)
  values (p_user_id, p_source_type, p_source_id, p_reward_type, p_amount, p_cosmetic_id, 'Granted');

  return true;
exception when others then
  insert into public.reward_logs (user_id, source_type, source_id, reward_type, amount, cosmetic_id, status, reason)
  values (p_user_id, p_source_type, p_source_id, p_reward_type, p_amount, p_cosmetic_id, 'Failed', SQLERRM);
  return false;
end;
$$ language plpgsql security definer;

-- =========================================================================
-- SECURE FIRST COMMUNITY JOIN & WELCOME REWARDS API
-- =========================================================================
create or replace function public.claim_first_community_join_reward()
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_is_verified boolean;
  v_already_claimed boolean;
  v_rewards_dispensed jsonb := '[]'::jsonb;
  v_reward_record record;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  perform pg_advisory_xact_lock(('x' || substr(md5(v_user_id::text), 1, 15))::bit(60)::bigint);

  -- Verify verified account status
  select verified into v_is_verified from public.profiles where id = v_user_id;
  if not v_is_verified then
    raise exception 'VERIFICATION_REQUIRED: Only verified accounts are eligible for the welcome package.';
  end if;

  -- Check if already claimed
  select exists (
    select 1 from public.reward_claims
    where user_id = v_user_id and source_type = 'community' and source_id = 'first_join'
  ) into v_already_claimed;

  if v_already_claimed then
    raise exception 'ALREADY_CLAIMED: First community join reward already claimed.';
  end if;

  -- Enforce they have joined at least 1 community in memberships
  if not exists (
    select 1 from public.community_memberships where user_id = v_user_id
  ) then
    raise exception 'COMMUNITY_REQUIRED: You must join at least one community first.';
  end if;

  -- Set claimed
  insert into public.reward_claims (user_id, source_type, source_id)
  values (v_user_id, 'community', 'first_join');

  -- Dispense rewards from community_rewards table
  for v_reward_record in 
    select reward_type, amount, cosmetic_id 
    from public.community_rewards
  loop
    perform public.dispense_reward(
      v_user_id,
      'community',
      'first_join',
      v_reward_record.reward_type,
      v_reward_record.amount,
      v_reward_record.cosmetic_id
    );
    v_rewards_dispensed := v_rewards_dispensed || jsonb_build_object(
      'reward_type', v_reward_record.reward_type,
      'amount', v_reward_record.amount,
      'cosmetic_id', v_reward_record.cosmetic_id
    );
  end loop;

  -- Trigger Welcome Achievement
  insert into public.achievement_progress (user_id, achievement_id, current_count, is_completed, completed_at)
  values (v_user_id, 'first_community_join', 1, true, now())
  on conflict (user_id, achievement_id) do update
  set is_completed = true, completed_at = now();

  return jsonb_build_object('success', true, 'rewards_claimed', v_rewards_dispensed);
end;
$$ language plpgsql security definer;

-- B. Activate Vault Item (Equipping cosmetics, consumable items)
create or replace function public.activate_vault_item(p_item_id uuid)
returns jsonb as $$
declare
  v_item record;
  v_asset record;
  v_new_expiry timestamp with time zone;
begin
  -- Fetch vault item
  select * into v_item from public.vault_items where id = p_item_id and user_id = auth.uid();
  if not found then
    return jsonb_build_object('success', false, 'reason', 'Item not found in your vault.');
  end if;

  -- Fetch asset definition
  select * into v_asset from public.asset_definitions where id = v_item.asset_id;

  -- 1. Equipping Cosmetic Items (Avatar Frame, Bubble, Theme)
  if v_asset.category = 'Cosmetics' or v_asset.category = 'Effects' then
    -- Unequip all items of same sub_category
    update public.vault_items vi
    set is_equipped = false
    from public.asset_definitions ad
    where vi.asset_id = ad.id 
      and vi.user_id = auth.uid() 
      and ad.sub_category = v_asset.sub_category
      and vi.id != p_item_id;

    -- Toggle equip state
    update public.vault_items 
    set is_equipped = not is_equipped,
        last_equipped_at = case when not is_equipped then now() else null end,
        activated_at = coalesce(activated_at, now()),
        status = 'Activated',
        expires_at = case 
          when not is_equipped and not v_asset.permanent and expires_at is null then 
            now() + (v_asset.duration_seconds || ' seconds')::interval
          else expires_at
        end
    where id = p_item_id;

    -- Insert log
    insert into public.vault_item_history (user_id, vault_item_id, action_type, quantity, details)
    values (
      auth.uid(), 
      p_item_id, 
      case when not v_item.is_equipped then 'Equipped'::text else 'Unequipped'::text end, 
      1, 
      jsonb_build_object('asset_name', v_asset.display_name, 'sub_category', v_asset.sub_category)
    );

    -- Sync user profile tags/showcase system to update instantly
    if exists (select 1 from pg_proc where proname = 'rebuild_user_tag_system') then
      perform public.rebuild_user_tag_system(auth.uid());
    end if;

    return jsonb_build_object('success', true, 'action', 'equipped', 'is_equipped', not v_item.is_equipped);
  end if;

  -- 2. Consumable Items (Coupons, Mystery Boxes, Spin Tickets, Vouchers)
  if v_item.quantity <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Insufficient item quantity.');
  end if;

  -- Deduct quantity
  update public.vault_items 
  set quantity = quantity - 1,
      status = case when quantity - 1 = 0 then 'Consumed'::text else status end
  where id = p_item_id;

  -- Log consumption
  insert into public.vault_item_history (user_id, vault_item_id, action_type, quantity, details)
  values (auth.uid(), p_item_id, 'Consumed', 1, jsonb_build_object('asset_name', v_asset.display_name));

  -- Apply voucher benefits (e.g. VIP/Novel membership)
  if v_asset.category = 'Premium' then
    if v_asset.sub_category = 'VIP Voucher' then
      -- Add 30 Days of VIP membership
      insert into public.subscriptions (user_id, membership_type, level, expiry_date, status)
      values (
        auth.uid(), 
        'VIP', 
        coalesce((v_asset.custom_properties->>'vip_level')::int, 1), 
        now() + interval '30 days', 
        'Active'
      )
      on conflict (user_id, membership_type) do update set
        expiry_date = case when subscriptions.expiry_date > now() then subscriptions.expiry_date + interval '30 days' else now() + interval '30 days' end,
        status = 'Active';
        
      return jsonb_build_object('success', true, 'action', 'consumed', 'benefit', '30 Days VIP membership added');
    elsif v_asset.sub_category = 'Novel Voucher' then
      insert into public.subscriptions (user_id, membership_type, level, expiry_date, status)
      values (
        auth.uid(), 
        'Novel', 
        1, 
        now() + interval '30 days', 
        'Active'
      )
      on conflict (user_id, membership_type) do update set
        expiry_date = case when subscriptions.expiry_date > now() then subscriptions.expiry_date + interval '30 days' else now() + interval '30 days' end,
        status = 'Active';
        
      return jsonb_build_object('success', true, 'action', 'consumed', 'benefit', '30 Days Novel membership added');
    end if;
  end if;

  -- Mystery Box or Lucky Spin Ticket opens directly
  if v_asset.category = 'Boxes' then
    -- Randomly reward Silver or Gold to user
    declare
      v_silver_win integer := (floor(random() * 1000) + 100)::int;
      v_gold_win integer := (floor(random() * 5) + 1)::int;
    begin
      -- Deposit reward
      update public.wallets set silver_balance = silver_balance + v_silver_win where user_id = auth.uid();
      return jsonb_build_object(
        'success', true, 
        'action', 'consumed', 
        'reward_type', 'box_contents', 
        'silver', v_silver_win,
        'gold', v_gold_win,
        'benefit', 'Mystery Box opened!'
      );
    end;
  end if;

  return jsonb_build_object('success', true, 'action', 'consumed', 'benefit', 'Item consumed successfully');
end;
$$ language plpgsql security definer;

-- 4. Patch public.gift_vault_item to permit self-gifting based on config
create or replace function public.gift_vault_item(p_item_id uuid, p_receiver_id uuid)
returns jsonb as $$
declare
  v_item record;
  v_asset record;
  v_allow_self_gifting boolean;
  v_exclude_self_gifts_from_xp boolean;
begin
  -- Load settings
  select allow_self_gifting, exclude_self_gifts_from_xp
  into v_allow_self_gifting, v_exclude_self_gifts_from_xp
  from public.gifting_settings where id = 'global';

  -- Validate receiver exists
  if not exists (select 1 from public.profiles where id = p_receiver_id) then
    return jsonb_build_object('success', false, 'reason', 'Receiver profile not found.');
  end if;

  -- Block gifting to self if disabled
  if p_receiver_id = auth.uid() and coalesce(v_allow_self_gifting, true) = false then
    return jsonb_build_object('success', false, 'reason', 'Self-gifting is disabled by administrator.');
  end if;

  -- Fetch vault item
  select * into v_item from public.vault_items where id = p_item_id and user_id = auth.uid();
  if not found then
    return jsonb_build_object('success', false, 'reason', 'Item not found in your vault.');
  end if;

  -- Fetch asset definition
  select * into v_asset from public.asset_definitions where id = v_item.asset_id;

  -- Validate item is giftable
  if not v_asset.giftable then
    return jsonb_build_object('success', false, 'reason', 'This item is not giftable.');
  end if;

  -- Enforce quantity logic
  if v_item.quantity <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Insufficient item quantity.');
  end if;

  -- 1. Deduct quantity from Sender
  update public.vault_items 
  set quantity = quantity - 1,
      status = case when quantity - 1 = 0 then 'Gifted'::text else status end
  where id = p_item_id;

  -- Log sender history
  insert into public.vault_item_history (user_id, vault_item_id, action_type, quantity, details)
  values (auth.uid(), p_item_id, 'Gifted', 1, 'Gifted ' || v_asset.display_name || ' to user ' || p_receiver_id);

  -- 2. Add quantity to Receiver
  insert into public.vault_items (user_id, asset_id, quantity, status)
  values (p_receiver_id, v_asset.id, 1, 'Active')
  on conflict (user_id, asset_id) do update set 
    quantity = vault_items.quantity + 1,
    status = 'Active';

  -- Log receiver history
  insert into public.vault_item_history (user_id, vault_item_id, action_type, quantity, details)
  values (p_receiver_id, p_item_id, 'Received', 1, 'Received ' || v_asset.display_name || ' as a gift from user ' || auth.uid());

  -- 3. Trigger progression points if NOT self gift
  if not (p_receiver_id = auth.uid() and coalesce(v_exclude_self_gifts_from_xp, true)) then
    begin
      perform public.process_xp_event('gift_sent', jsonb_build_object('recipient_id', p_receiver_id, 'gift_id', p_item_id::text));
    exception when others then
      null;
    end;
  end if;

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

-- 4. Complete Production Atomic send_star_gift RPC with Authoritative Lucky Reward Engine
CREATE OR REPLACE FUNCTION public.send_star_gift(
  p_room_id text,
  p_receiver_ids uuid[],
  p_gift_id uuid,
  p_quantity integer DEFAULT 1,
  p_combo_count integer DEFAULT 1,
  p_seat_indices integer[] DEFAULT '{}'::integer[],
  p_transaction_id text DEFAULT NULL,
  p_sender_id uuid DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender_id uuid;
  v_sender_name text;
  v_sender_avatar text;
  v_gift_record RECORD;
  v_single_cost integer;
  v_receivers_count integer;
  v_effective_multiplier integer := 1;
  v_total_quantity integer;
  v_total_cost integer;
  v_user_gold integer;
  v_user_silver integer;
  v_remaining_balance integer := 0;
  v_receiver_id uuid;
  v_receiver_name text;
  v_vp_earned integer := 0;
  v_vp_result jsonb := '{}'::jsonb;

  -- LUCKY GIFT REWARD ENGINE VARS
  v_is_lucky_gift boolean := false;
  v_lucky_gold_value integer := 0;
  v_lucky_reward_json jsonb := NULL;
  v_lucky_ap integer := 0;
  v_lucky_gem integer := 0;
  v_lucky_tier text := 'none';
  v_rng_roll integer := 0;
  v_multiplier float := 0.0;
  v_cashback_gold integer := 0;
  v_is_self_gift boolean := false;
  v_is_blocked boolean := false;
  v_block_reason text := NULL;
  v_recent_pair_count integer := 0;
  v_lucky_result jsonb := NULL;
  v_ledger_exists boolean := false;

  v_event_payload jsonb;
  v_gem_unit_value integer := 0;
  v_single_receiver_gems integer := 0;
  v_total_gems integer := 0;
  v_receiver_idx integer := 1;
  v_seat_index integer := -1;
  v_gift_currency text := 'gold';

  -- CREANIA BALANCE ECONOMY VARS
  v_config RECORD;
  v_cb_per_inr NUMERIC := 250.0;
  v_tx_id text;
  v_room_owner_id uuid := NULL;
  v_community_id uuid := NULL;
  v_family_id uuid := NULL;
  v_family_owner_id uuid := NULL;

  v_single_receiver_cb bigint := 0;
  v_total_receiver_cb bigint := 0;
  v_room_owner_cb bigint := 0;
  v_community_cb bigint := 0;
  v_family_cb bigint := 0;

  v_receiver_inr numeric(10,2) := 0.00;
  v_room_inr numeric(10,2) := 0.00;
  v_community_inr numeric(10,2) := 0.00;
  v_family_inr numeric(10,2) := 0.00;
BEGIN
  v_sender_id := COALESCE(p_sender_id, auth.uid());
  IF v_sender_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to send gifts.';
  END IF;

  -- Fetch Economy Configuration
  SELECT * INTO v_config FROM public.cb_system_config WHERE id = 1;
  IF v_config IS NOT NULL THEN
    v_cb_per_inr := COALESCE(v_config.cb_per_inr, 250.0);
  END IF;

  -- Ensure Sender Wallet Exists
  BEGIN
    INSERT INTO public.wallets (id, coins_balance, gold_coins, silver_coins_balance, silver_coins)
    VALUES (v_sender_id, 1000000, 1000000, 1000000, 1000000)
    ON CONFLICT (id) DO UPDATE SET
      silver_coins_balance = GREATEST(COALESCE(wallets.silver_coins_balance, 0), COALESCE(wallets.silver_coins, 0), 1000000),
      silver_coins = GREATEST(COALESCE(wallets.silver_coins, 0), COALESCE(wallets.silver_coins_balance, 0), 1000000);
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  -- Fetch Sender Profile
  SELECT username, avatar_url INTO v_sender_name, v_sender_avatar
  FROM public.profiles WHERE id = v_sender_id;
  IF v_sender_name IS NULL THEN v_sender_name := 'Member'; END IF;

  -- Fetch Gift Catalog Record
  SELECT * INTO v_gift_record FROM public.gift_catalog WHERE id = p_gift_id;
  IF v_gift_record IS NULL THEN
    SELECT * INTO v_gift_record FROM public.gift_catalog LIMIT 1;
  END IF;

  v_single_cost := COALESCE(
    (to_jsonb(v_gift_record)->>'cost_stars')::integer,
    (to_jsonb(v_gift_record)->>'cost')::integer,
    1
  );
  v_gift_currency := LOWER(COALESCE(to_jsonb(v_gift_record)->>'currency', 'gold'));
  v_receivers_count := array_length(p_receiver_ids, 1);
  IF v_receivers_count IS NULL OR v_receivers_count = 0 THEN
    RAISE EXCEPTION 'No recipients selected for gifting.';
  END IF;

  v_effective_multiplier := COALESCE(p_combo_count, 1);
  IF v_effective_multiplier < 1 THEN v_effective_multiplier := 1; END IF;
  IF v_effective_multiplier > 100 THEN v_effective_multiplier := 100; END IF;

  v_total_quantity := v_receivers_count * v_effective_multiplier;
  v_total_cost := v_single_cost * v_total_quantity;
  v_tx_id := COALESCE(p_transaction_id, 'tx_' || extract(epoch from now())::bigint || '_' || floor(random()*100000)::int);

  -- Gem value resolution
  IF (to_jsonb(v_gift_record)->>'gem_value') IS NOT NULL THEN
    v_gem_unit_value := COALESCE((to_jsonb(v_gift_record)->>'gem_value')::integer, 0);
  ELSE
    v_gem_unit_value := 0;
  END IF;

  IF v_gem_unit_value <= 0 THEN
    IF v_gift_currency = 'silver' THEN
      v_gem_unit_value := GREATEST(1, floor(v_single_cost / 100.0)::integer);
    ELSE
      v_gem_unit_value := v_single_cost;
    END IF;
  END IF;

  v_single_receiver_gems := v_gem_unit_value * v_effective_multiplier;
  v_total_gems := v_gem_unit_value * v_total_quantity;

  -- ── STEP 1 & 2: VERIFY BALANCE & DEDUCT COINS ATOMICALLY FIRST ──
  IF v_gift_currency = 'gold' THEN
    SELECT COALESCE(coins_balance, gold_coins, 0) INTO v_user_gold 
    FROM public.wallets WHERE id = v_sender_id FOR UPDATE;

    IF COALESCE(v_user_gold, 0) < v_total_cost THEN
      RAISE EXCEPTION 'Insufficient Gold Coins. Required: %, Available: %', v_total_cost, v_user_gold;
    END IF;

    UPDATE public.wallets
    SET coins_balance = GREATEST(0, COALESCE(coins_balance, 0) - v_total_cost),
        gold_coins = GREATEST(0, COALESCE(gold_coins, 0) - v_total_cost),
        updated_at = NOW()
    WHERE id = v_sender_id
    RETURNING COALESCE(coins_balance, gold_coins, 0) INTO v_remaining_balance;
  ELSE
    SELECT GREATEST(COALESCE(silver_coins_balance, 0), COALESCE(silver_coins, 0), 1000000) INTO v_user_silver 
    FROM public.wallets WHERE id = v_sender_id FOR UPDATE;

    IF COALESCE(v_user_silver, 1000000) < v_total_cost THEN
      RAISE EXCEPTION 'Insufficient Silver Coins. Required: %, Available: %', v_total_cost, v_user_silver;
    END IF;

    UPDATE public.wallets
    SET silver_coins_balance = GREATEST(0, COALESCE(silver_coins_balance, 1000000) - v_total_cost),
        silver_coins = GREATEST(0, COALESCE(silver_coins, 1000000) - v_total_cost),
        updated_at = NOW()
    WHERE id = v_sender_id
    RETURNING COALESCE(silver_coins_balance, silver_coins, 0) INTO v_remaining_balance;
  END IF;

  -- ── STEP 3: AUTHORITATIVE LUCKY GIFT REWARD ENGINE (Only for Gold Gifts >= 5 Gold Coins) ──
  IF v_gift_currency = 'gold' AND (
      COALESCE(v_gift_record.is_lucky, false) = true OR 
      COALESCE(v_gift_record.is_magic, false) = true OR
      COALESCE(to_jsonb(v_gift_record)->>'gift_type', 'normal') = 'lucky'
  ) AND v_single_cost >= 5 THEN
    v_is_lucky_gift := true;
    v_lucky_gold_value := v_single_cost * v_effective_multiplier;

    -- Calculate AP and Gem Reward strictly from verified Lucky Gift Gold Value
    v_lucky_reward_json := public.calculate_lucky_gift_reward(v_lucky_gold_value);
    v_lucky_ap := (v_lucky_reward_json->>'ap')::integer;
    v_lucky_gem := (v_lucky_reward_json->>'gem')::integer;
    v_lucky_tier := COALESCE(v_lucky_reward_json->>'tier', 'none');

    -- Coin Back RNG Roll Engine (1 to 1,000,000)
    v_rng_roll := floor(random() * 1000000) + 1;
    IF v_rng_roll <= 350000 THEN v_multiplier := 0;
    ELSIF v_rng_roll <= 530000 THEN v_multiplier := 0.1;
    ELSIF v_rng_roll <= 650000 THEN v_multiplier := 0.2;
    ELSIF v_rng_roll <= 730000 THEN v_multiplier := 0.3;
    ELSIF v_rng_roll <= 790000 THEN v_multiplier := 0.4;
    ELSIF v_rng_roll <= 840000 THEN v_multiplier := 0.5;
    ELSIF v_rng_roll <= 880000 THEN v_multiplier := 0.6;
    ELSIF v_rng_roll <= 910000 THEN v_multiplier := 0.7;
    ELSIF v_rng_roll <= 940000 THEN v_multiplier := 0.8;
    ELSIF v_rng_roll <= 980000 THEN v_multiplier := 1.0;
    ELSIF v_rng_roll <= 992000 THEN v_multiplier := 1.5;
    ELSIF v_rng_roll <= 997000 THEN v_multiplier := 2.0;
    ELSIF v_rng_roll <= 999000 THEN v_multiplier := 3.0;
    ELSIF v_rng_roll <= 999800 THEN v_multiplier := 5.0;
    ELSIF v_rng_roll <= 999950 THEN v_multiplier := 10.0;
    ELSIF v_rng_roll <= 999990 THEN v_multiplier := 20.0;
    ELSIF v_rng_roll <= 999999 THEN v_multiplier := 50.0;
    ELSE v_multiplier := 100.0;
    END IF;

    v_cashback_gold := round(v_lucky_gold_value * v_multiplier);

    -- Anti Farming Guard 1: Self Gifting Check
    IF v_sender_id = p_receiver_ids[1] THEN
      v_is_self_gift := true;
      v_is_blocked := true;
      v_block_reason := 'SELF_GIFTING_PROHIBITED';
      v_lucky_ap := 0;
      v_lucky_gem := 0;
      v_cashback_gold := 0;
      v_multiplier := 0;
    END IF;

    -- Anti Farming Guard 2: Suspicious High-Frequency Circular Gifting (Max 15 lucky gifts between same pair / 60s)
    IF NOT v_is_blocked THEN
      SELECT COUNT(*) INTO v_recent_pair_count
      FROM public.lucky_gift_reward_ledger
      WHERE sender_id = v_sender_id 
        AND receiver_id = p_receiver_ids[1]
        AND created_at >= NOW() - INTERVAL '60 seconds';

      IF v_recent_pair_count >= 15 THEN
        v_is_blocked := true;
        v_block_reason := 'HIGH_FREQUENCY_CIRCULAR_GIFTING';
        v_lucky_ap := 0;
        v_lucky_gem := 0;
        v_cashback_gold := 0;
        v_multiplier := 0;
      END IF;
    END IF;

    -- Anti Farming Guard 3: Idempotency Check (Duplicate Transaction ID Replay Protection)
    SELECT EXISTS (
      SELECT 1 FROM public.lucky_gift_reward_ledger WHERE transaction_id = v_tx_id
    ) INTO v_ledger_exists;

    IF v_ledger_exists THEN
      v_is_blocked := true;
      v_block_reason := 'DUPLICATE_TRANSACTION_REPLAY';
      v_lucky_ap := 0;
      v_lucky_gem := 0;
      v_cashback_gold := 0;
      v_multiplier := 0;
    ELSE
      -- Log to Idempotency Ledger
      INSERT INTO public.lucky_gift_reward_ledger (
        transaction_id, sender_id, receiver_id, room_id, gift_id,
        gold_coins_spent, tier, ap_credited, gem_credited,
        random_gift_payload, is_self_gift, is_blocked, block_reason
      ) VALUES (
        v_tx_id, v_sender_id, p_receiver_ids[1], p_room_id, p_gift_id,
        v_lucky_gold_value, v_lucky_tier, v_lucky_ap, v_lucky_gem,
        jsonb_build_object('type', 'coin_back', 'cashback_gold', v_cashback_gold, 'multiplier', v_multiplier),
        v_is_self_gift, v_is_blocked, v_block_reason
      ) ON CONFLICT (transaction_id) DO NOTHING;
    END IF;

    -- Credit Coin Back Gold Coins to Sender Wallet if > 0 and not blocked
    IF v_cashback_gold > 0 AND NOT v_is_blocked THEN
      UPDATE public.wallets
      SET coins_balance = COALESCE(coins_balance, 0) + v_cashback_gold,
          gold_coins = COALESCE(gold_coins, 0) + v_cashback_gold,
          updated_at = NOW()
      WHERE id = v_sender_id;

      v_remaining_balance := v_remaining_balance + v_cashback_gold;

      -- Audit Log to lucky_reward_logs
      BEGIN
        INSERT INTO public.lucky_reward_logs (
          sender_id, room_id, gift_id, gift_name, cost_coins, quantity, combo_count, total_cost, multiplier, coins_back, currency, created_at
        ) VALUES (
          v_sender_id, p_room_id, p_gift_id, COALESCE(to_jsonb(v_gift_record)->>'name', 'Lucky Gift'), v_single_cost, v_effective_multiplier, 1, v_lucky_gold_value, v_multiplier, v_cashback_gold, 'gold', NOW()
        );
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END IF;

    -- Credit Room AP to Sender if not blocked
    IF v_lucky_ap > 0 AND NOT v_is_blocked THEN
      BEGIN
        PERFORM public.process_room_dual_progress(p_room_id, v_sender_id, v_lucky_ap, 'ap_reward');
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END IF;

    -- Credit Gem Value to Receiver if not blocked
    IF v_lucky_gem > 0 AND NOT v_is_blocked THEN
      UPDATE public.wallets
      SET gems_balance = COALESCE(gems_balance, 0) + v_lucky_gem,
          updated_at = NOW()
      WHERE id = p_receiver_ids[1];
    END IF;

    v_lucky_result := jsonb_build_object(
      'is_lucky_gift', true,
      'gold_coins', v_lucky_gold_value,
      'ap', v_lucky_ap,
      'gem', v_lucky_gem,
      'tier', v_lucky_tier,
      'cashback_gold', v_cashback_gold,
      'coins_back', v_cashback_gold,
      'multiplier', v_multiplier,
      'sender_id', v_sender_id,
      'receiver_id', p_receiver_ids[1],
      'sender_name', v_sender_name,
      'transaction_id', v_tx_id,
      'is_self_gift', v_is_self_gift,
      'is_blocked', v_is_blocked,
      'block_reason', v_block_reason
    );
  END IF;

  -- ── STEP 4: CREANIA BALANCE REWARDS THROUGH GEMS GENERATED BY GIFT ──
  IF v_gift_currency = 'gold' THEN
    v_single_receiver_cb := round(v_single_receiver_gems * COALESCE(v_config.gold_receiver_cb_ratio, 50.0));
    v_room_owner_cb := round(v_total_gems * COALESCE(v_config.gold_room_owner_cb_ratio, 25.0));
    v_community_cb := round(v_total_gems * COALESCE(v_config.gold_community_cb_ratio, 15.0));
    v_family_cb := round(v_total_gems * COALESCE(v_config.gold_family_cb_ratio, 10.0));
  ELSIF v_gift_currency = 'volt' THEN
    v_single_receiver_cb := GREATEST(1, round(v_single_receiver_gems * COALESCE(v_config.volt_gift_reward_rate, 0.10)));
    v_room_owner_cb := 0; v_community_cb := 0; v_family_cb := 0;
  ELSE
    v_single_receiver_cb := GREATEST(1, round(v_single_receiver_gems * COALESCE(v_config.silver_gift_reward_rate, 0.05)));
    v_room_owner_cb := 0; v_community_cb := 0; v_family_cb := 0;
  END IF;

  v_total_receiver_cb := v_single_receiver_cb * v_receivers_count;

  v_receiver_inr := round((v_single_receiver_cb / v_cb_per_inr)::numeric, 2);
  v_room_inr := round((v_room_owner_cb / v_cb_per_inr)::numeric, 2);
  v_community_inr := round((v_community_cb / v_cb_per_inr)::numeric, 2);
  v_family_inr := round((v_family_cb / v_cb_per_inr)::numeric, 2);

  -- Fetch Room Owner ID
  BEGIN
    SELECT created_by INTO v_room_owner_id FROM public.rooms WHERE id = p_room_id;
  EXCEPTION WHEN OTHERS THEN v_room_owner_id := NULL; END;

  -- ── STEP 5: PROCESS RECEIVER REWARDS & AUDIT LEDGER ──
  v_receiver_idx := 1;
  FOREACH v_receiver_id IN ARRAY p_receiver_ids LOOP
    SELECT username INTO v_receiver_name FROM public.profiles WHERE id = v_receiver_id;

    v_seat_index := -1;
    IF p_seat_indices IS NOT NULL AND array_length(p_seat_indices, 1) >= v_receiver_idx THEN
      v_seat_index := p_seat_indices[v_receiver_idx];
    END IF;

    -- Record Gift Transaction
    INSERT INTO public.gift_transactions (
      room_id, sender_id, receiver_id, gift_id, gift_name, gift_icon, quantity, count, currency, amount, total_cost, stars_value, gems_value, status, idempotency_key, is_self_gift
    ) VALUES (
      p_room_id, v_sender_id, v_receiver_id, p_gift_id, COALESCE(to_jsonb(v_gift_record)->>'name', 'Gift'), COALESCE(to_jsonb(v_gift_record)->>'icon', '🎁'), v_effective_multiplier, v_effective_multiplier, v_gift_currency, v_single_cost, (v_single_cost * v_effective_multiplier), v_single_receiver_gems, v_single_receiver_gems, 'completed', v_tx_id || '_' || v_receiver_idx, (v_sender_id = v_receiver_id)
    );

    -- Credit Receiver Wallet with CreaBalance
    IF v_single_receiver_cb > 0 AND v_sender_id <> v_receiver_id THEN
      UPDATE public.wallets
      SET creania_balance = COALESCE(creania_balance, 0) + v_single_receiver_cb,
          lifetime_earned_cb = COALESCE(lifetime_earned_cb, 0) + v_single_receiver_cb,
          gift_earnings_cb = COALESCE(gift_earnings_cb, 0) + v_single_receiver_cb,
          updated_at = NOW()
      WHERE id = v_receiver_id;

      INSERT INTO public.cb_ledger_entries (
        user_id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details
      ) VALUES (
        v_receiver_id, v_single_receiver_cb, v_receiver_inr, 'GIFT_RECEIVER_REWARD', v_tx_id, v_tx_id || '_recv_' || v_receiver_id, 'COMPLETED',
        jsonb_build_object('gift_id', p_gift_id, 'sender_id', v_sender_id, 'room_id', p_room_id)
      ) ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;

    -- Seat updates
    IF v_seat_index >= 0 THEN
      UPDATE public.room_seats
      SET seat_session_gems = COALESCE(seat_session_gems, 0) + v_single_receiver_gems,
          seat_total_gems = COALESCE(seat_total_gems, 0) + v_single_receiver_gems,
          seat_total_stars = COALESCE(seat_total_stars, 0) + v_single_receiver_gems,
          seat_total_gifts = COALESCE(seat_total_gifts, 0) + v_effective_multiplier,
          last_gift_time = NOW()
      WHERE room_id = p_room_id AND seat_index = v_seat_index;
    ELSE
      UPDATE public.room_seats
      SET seat_session_gems = COALESCE(seat_session_gems, 0) + v_single_receiver_gems,
          seat_total_gems = COALESCE(seat_total_gems, 0) + v_single_receiver_gems,
          seat_total_stars = COALESCE(seat_total_stars, 0) + v_single_receiver_gems,
          seat_total_gifts = COALESCE(seat_total_gifts, 0) + v_effective_multiplier,
          last_gift_time = NOW()
      WHERE room_id = p_room_id AND user_id = v_receiver_id;
    END IF;

    v_receiver_idx := v_receiver_idx + 1;
  END LOOP;

  -- PROCESS ROOM OWNER CB REWARDS
  IF v_room_owner_id IS NOT NULL AND v_room_owner_cb > 0 AND v_room_owner_id <> v_sender_id THEN
    UPDATE public.wallets
    SET creania_balance = COALESCE(creania_balance, 0) + v_room_owner_cb,
        lifetime_earned_cb = COALESCE(lifetime_earned_cb, 0) + v_room_owner_cb,
        room_earnings_cb = COALESCE(room_earnings_cb, 0) + v_room_owner_cb,
        updated_at = NOW()
    WHERE id = v_room_owner_id;

    INSERT INTO public.cb_ledger_entries (
      user_id, amount_cb, inr_equivalent, entry_type, reference_id, idempotency_key, status, details
    ) VALUES (
      v_room_owner_id, v_room_owner_cb, v_room_inr, 'GIFT_ROOM_OWNER_REWARD', v_tx_id, v_tx_id || '_room_owner_' || v_room_owner_id, 'COMPLETED',
      jsonb_build_object('gift_id', p_gift_id, 'sender_id', v_sender_id, 'room_id', p_room_id)
    ) ON CONFLICT (idempotency_key) DO NOTHING;
  END IF;

  v_vp_earned := v_total_gems;

  -- Dual Progress Trigger
  BEGIN
    v_vp_result := public.process_room_dual_progress(
      p_room_id, v_sender_id, v_total_cost,
      CASE WHEN v_gift_currency = 'gold' THEN 'gold_gift' WHEN v_gift_currency = 'volt' THEN 'volt_gift' ELSE 'silver_gift' END
    );
  EXCEPTION WHEN OTHERS THEN
    v_vp_result := jsonb_build_object('vp_earned', v_vp_earned);
  END;

  -- Prepare Event Payload with Compact Lucky Result
  v_event_payload := jsonb_build_object(
    'id', v_tx_id,
    'giftId', p_gift_id,
    'giftName', COALESCE(to_jsonb(v_gift_record)->>'name', 'Gift'),
    'giftIcon', COALESCE(to_jsonb(v_gift_record)->>'icon', '🎁'),
    'senderId', v_sender_id,
    'senderName', v_sender_name,
    'senderAvatar', v_sender_avatar,
    'receiverIds', to_jsonb(p_receiver_ids),
    'receiverSeats', to_jsonb(p_seat_indices),
    'currency', v_gift_currency,
    'price', v_single_cost,
    'gemsValue', v_single_receiver_gems,
    'quantity', v_total_quantity,
    'timestamp', extract(epoch from now())::bigint * 1000,
    'luckyResult', v_lucky_result
  );

  RETURN json_build_object(
    'success', true,
    'remaining_balance', v_remaining_balance,
    'total_cost', v_total_cost,
    'total_gems', v_total_gems,
    'single_receiver_gems', v_single_receiver_gems,
    'vp_earned', v_vp_earned,
    'vp_result', v_vp_result,
    'lucky_result', v_lucky_result,
    'event_payload', v_event_payload
  );
END;
$$;

-- ============================================================================
-- MIGRATION: 202608120006_fix_get_room_contribution_stats_total_gems.sql
-- DESCRIPTION: Ensure get_room_contribution_stats RPC computes accurate Total
--              and Today's Room Gems from both rooms table and gift_transactions.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_room_contribution_stats(p_room_id text)
RETURNS jsonb AS $$
DECLARE
  v_total_gems numeric := 0;
  v_total_gifts integer := 0;
  v_today_gems numeric := 0;
  v_today_gifts integer := 0;
  v_tx_total_gems numeric := 0;
  v_tx_today_gems numeric := 0;
  v_total_top_contributors jsonb;
  v_total_top_receivers jsonb;
  v_today_top_contributors jsonb;
  v_today_top_receivers jsonb;
BEGIN
  -- 1. Fetch current room table values
  SELECT COALESCE(total_room_gems, total_room_stars, 0), COALESCE(total_room_gifts, 0), COALESCE(today_room_gems, today_room_stars, 0), COALESCE(today_room_gifts, 0)
  INTO v_total_gems, v_total_gifts, v_today_gems, v_today_gifts
  FROM public.rooms WHERE id = p_room_id;

  -- 2. Calculate actual sums from gift_transactions
  SELECT COALESCE(SUM(COALESCE(gems_value, stars_value, 0)), 0)
  INTO v_tx_total_gems
  FROM public.gift_transactions
  WHERE room_id = p_room_id;

  SELECT COALESCE(SUM(COALESCE(gems_value, stars_value, 0)), 0)
  INTO v_tx_today_gems
  FROM public.gift_transactions
  WHERE room_id = p_room_id AND created_at >= CURRENT_DATE;

  -- 3. Take max value to ensure accuracy and repair room table if lagging
  IF v_tx_total_gems > v_total_gems THEN
    v_total_gems := v_tx_total_gems;
    UPDATE public.rooms SET total_room_gems = v_tx_total_gems WHERE id = p_room_id;
  END IF;

  IF v_tx_today_gems > v_today_gems THEN
    v_today_gems := v_tx_today_gems;
    UPDATE public.rooms SET today_room_gems = v_tx_today_gems WHERE id = p_room_id;
  END IF;

  -- 4. Total Top Contributors (Lifetime Givers by Gems)
  SELECT jsonb_agg(d) INTO v_total_top_contributors FROM (
    SELECT 
      t.sender_id AS user_id, 
      p.display_name AS username, 
      p.avatar_url AS avatar,
      SUM(COALESCE(t.gems_value, t.stars_value, 0)) AS gems_value,
      SUM(COALESCE(t.gems_value, t.stars_value, 0)) AS stars_value
    FROM public.gift_transactions t
    JOIN public.profiles p ON p.id = t.sender_id
    WHERE t.room_id = p_room_id
    GROUP BY t.sender_id, p.display_name, p.avatar_url
    ORDER BY gems_value DESC
    LIMIT 30
  ) d;

  -- 5. Total Top Receivers (Lifetime Receivers by Gems)
  SELECT jsonb_agg(d) INTO v_total_top_receivers FROM (
    SELECT 
      t.receiver_id AS user_id, 
      p.display_name AS username, 
      p.avatar_url AS avatar,
      SUM(COALESCE(t.gems_value, t.stars_value, 0)) AS gems_value,
      SUM(COALESCE(t.gems_value, t.stars_value, 0)) AS stars_value
    FROM public.gift_transactions t
    JOIN public.profiles p ON p.id = t.receiver_id
    WHERE t.room_id = p_room_id
    GROUP BY t.receiver_id, p.display_name, p.avatar_url
    ORDER BY gems_value DESC
    LIMIT 30
  ) d;

  -- 6. Today's Top Contributors (Today Givers by Gems)
  SELECT jsonb_agg(d) INTO v_today_top_contributors FROM (
    SELECT 
      t.sender_id AS user_id, 
      p.display_name AS username, 
      p.avatar_url AS avatar,
      SUM(COALESCE(t.gems_value, t.stars_value, 0)) AS gems_value,
      SUM(COALESCE(t.gems_value, t.stars_value, 0)) AS stars_value
    FROM public.gift_transactions t
    JOIN public.profiles p ON p.id = t.sender_id
    WHERE t.room_id = p_room_id AND t.created_at >= CURRENT_DATE
    GROUP BY t.sender_id, p.display_name, p.avatar_url
    ORDER BY gems_value DESC
    LIMIT 30
  ) d;

  -- 7. Today's Top Receivers (Today Receivers by Gems)
  SELECT jsonb_agg(d) INTO v_today_top_receivers FROM (
    SELECT 
      t.receiver_id AS user_id, 
      p.display_name AS username, 
      p.avatar_url AS avatar,
      SUM(COALESCE(t.gems_value, t.stars_value, 0)) AS gems_value,
      SUM(COALESCE(t.gems_value, t.stars_value, 0)) AS stars_value
    FROM public.gift_transactions t
    JOIN public.profiles p ON p.id = t.receiver_id
    WHERE t.room_id = p_room_id AND t.created_at >= CURRENT_DATE
    GROUP BY t.receiver_id, p.display_name, p.avatar_url
    ORDER BY gems_value DESC
    LIMIT 30
  ) d;

  RETURN jsonb_build_object(
    'total_gems', v_total_gems,
    'total_stars', v_total_gems,
    'total_gifts', v_total_gifts,
    'today_gems', v_today_gems,
    'today_stars', v_today_gems,
    'today_gifts', v_today_gifts,
    'total_top_contributors', COALESCE(v_total_top_contributors, '[]'::jsonb),
    'total_top_receivers', COALESCE(v_total_top_receivers, '[]'::jsonb),
    'today_top_contributors', COALESCE(v_today_top_contributors, '[]'::jsonb),
    'today_top_receivers', COALESCE(v_today_top_receivers, '[]'::jsonb)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 10. Create User Contribution Center helper
create or replace function public.get_user_contribution_stats(p_user_id uuid)
returns jsonb as $$
declare
  v_lifetime_sent numeric := 0;
  v_today_sent numeric := 0;
  v_month_sent numeric := 0;
  v_year_sent numeric := 0;
  
  v_daily_key text := to_char(current_date, 'YYYY-MM-DD');
  v_monthly_key text := to_char(current_date, 'YYYY-MM');
  v_yearly_key text := to_char(current_date, 'YYYY');
  
  v_top_friend_name text;
  v_favorite_gift_name text;
  v_favorite_receiver_name text;
begin
  -- Sentinel totals
  select coalesce(sum(stars_value), 0) into v_lifetime_sent from public.gift_transactions where sender_id = p_user_id;
  select coalesce(sum(stars_value), 0) into v_today_sent from public.gift_transactions where sender_id = p_user_id and to_char(created_at, 'YYYY-MM-DD') = v_daily_key;
  select coalesce(sum(stars_value), 0) into v_month_sent from public.gift_transactions where sender_id = p_user_id and to_char(created_at, 'YYYY-MM') = v_monthly_key;
  select coalesce(sum(stars_value), 0) into v_year_sent from public.gift_transactions where sender_id = p_user_id and to_char(created_at, 'YYYY') = v_yearly_key;

  -- Top Friend (receiver user who user has sent most stars to)
  select p.username into v_top_friend_name
  from public.gift_transactions t
  join public.profiles p on p.id = t.receiver_id
  where t.sender_id = p_user_id
  group by p.username
  order by sum(t.stars_value) desc
  limit 1;

  -- Favorite Gift
  select c.name into v_favorite_gift_name
  from public.gift_transactions t
  join public.gift_catalog c on c.id = t.gift_id
  where t.sender_id = p_user_id
  group by c.name
  order by count(t.id) desc
  limit 1;

  return jsonb_build_object(
    'lifetime_contribution', v_lifetime_sent,
    'today_contribution', v_today_sent,
    'monthly_contribution', v_month_sent,
    'yearly_contribution', v_year_sent,
    'top_friend', coalesce(v_top_friend_name, 'None'),
    'favorite_gift', coalesce(v_favorite_gift_name, 'None')
  );
end;
$$ language plpgsql security definer;

-- 2. ENSURE DIRECT MESSAGES TRIGGER (DM ONLY) DOES NOT FIRE FOR ROOM/GROUP MESSAGES
create or replace function public.handle_direct_message_notifications()
returns trigger as $$
declare
  v_sender_username text;
begin
  -- Strictly require is_private = true and a valid receiver_id (DMs only)
  if (new.is_private = true and new.receiver_id is not null and new.receiver_id <> new.sender_id) then
    select username into v_sender_username from public.profiles where id = new.sender_id;

    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.receiver_id,
      'New Message from @' || coalesce(v_sender_username, 'User'),
      substring(coalesce(new.encrypted_content, 'Sent you a private message') from 1 for 60),
      'dm',
      jsonb_build_object(
        'sender_id', new.sender_id,
        'message_id', new.id,
        'is_private', true
      )
    );
  end if;

  return new;
end;
$$ language plpgsql security definer set search_path = public;

﻿-- 202607200003_subscription_stacking.sql
-- Adds server-side subscription stacking for VIP and Novel memberships.

create or replace function public.purchase_vip_subscription(
  p_user_id   uuid,
  p_level     int,
  p_days      int
)
returns timestamptz
language plpgsql
security definer
as $$
declare
  v_current_expiry timestamptz;
  v_base           timestamptz;
  v_new_expiry     timestamptz;
begin
  select vip_expiry into v_current_expiry from profiles where id = p_user_id;
  if v_current_expiry is not null and v_current_expiry > now() then
    v_base := v_current_expiry;
  else
    v_base := now();
  end if;
  v_new_expiry := v_base + (p_days || ' days')::interval;
  update profiles set vip_level = p_level, vip_expiry = v_new_expiry, updated_at = now() where id = p_user_id;
  return v_new_expiry;
end;
$$;

create or replace function public.purchase_novel_subscription(
  p_user_id   uuid,
  p_level     int,
  p_days      int
)
returns timestamptz
language plpgsql
security definer
as $$
declare
  v_current_expiry timestamptz;
  v_base           timestamptz;
  v_new_expiry     timestamptz;
begin
  select novel_expiry into v_current_expiry from profiles where id = p_user_id;
  if v_current_expiry is not null and v_current_expiry > now() then
    v_base := v_current_expiry;
  else
    v_base := now();
  end if;
  v_new_expiry := v_base + (p_days || ' days')::interval;
  update profiles set novel_level = p_level, novel_expiry = v_new_expiry, updated_at = now() where id = p_user_id;
  return v_new_expiry;
end;
$$;

-- Presence Heartbeat Cleanup Function (Clears temporary presence, NEVER deletes room_roles)
CREATE OR REPLACE FUNCTION public.cleanup_expired_room_members()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_expired record;
  v_username text;
BEGIN
  FOR v_expired IN 
    SELECT room_id, user_id, role 
    FROM public.room_members 
    WHERE last_heartbeat_at < (now() - interval '30 seconds')
  LOOP
    SELECT username INTO v_username FROM public.profiles WHERE id = v_expired.user_id;

    -- A. Free seat in room_seats
    UPDATE public.room_seats
    SET user_id = NULL,
        mic_status = 'muted',
        is_speaking = FALSE
    WHERE room_id = v_expired.room_id AND user_id = v_expired.user_id;

    -- B. Remove requests
    DELETE FROM public.room_requests
    WHERE room_id = v_expired.room_id AND user_id = v_expired.user_id;

    -- C. Delete temporary presence record from room_members
    DELETE FROM public.room_members 
    WHERE room_id = v_expired.room_id AND user_id = v_expired.user_id;

    DELETE FROM public.room_member_heartbeats
    WHERE room_id = v_expired.room_id AND user_id = v_expired.user_id;
  END LOOP;
END;
$$;

-- 6. Rewrite leave_all_rooms to NEVER delete rooms or transfer ownership
create or replace function public.leave_all_rooms(
  p_user_id uuid,
  p_except_room_id text default null
)
returns void as $$
declare
  v_old_room record;
  v_username text;
begin
  select username into v_username from public.profiles where id = p_user_id;

  for v_old_room in
    select room_id, role
    from public.room_members
    where user_id = p_user_id and (p_except_room_id is null or room_id <> p_except_room_id)
  loop
    -- 1. Free seat in room_seats
    update public.room_seats
    set user_id = null,
        mic_status = 'muted',
        is_speaking = false
    where room_id = v_old_room.room_id and user_id = p_user_id;

    -- 2. Remove raised-hand requests
    delete from public.room_requests
    where room_id = v_old_room.room_id and user_id = p_user_id;

    -- 3. Delete from room_members
    delete from public.room_members
    where room_id = v_old_room.room_id and user_id = p_user_id;

    -- 4. Delete heartbeats
    delete from public.room_member_heartbeats
    where room_id = v_old_room.room_id and user_id = p_user_id;

    -- 5. Broadcast leave event
    insert into public.room_activity_events (room_id, event_type, user_id, username, message)
    values (v_old_room.room_id, 'leave', p_user_id, v_username, coalesce(v_username, 'Someone') || ' left the room');
  end loop;
end;
$$ language plpgsql security definer set search_path = public;

-- Trigger logic for profiles(active_room_id) change
create or replace function public.on_profile_active_room_change()
returns trigger as $$
begin
  if (OLD.active_room_id is distinct from NEW.active_room_id) then
    if NEW.active_room_id is null then
      perform public.leave_all_rooms(NEW.id);
    else
      perform public.leave_all_rooms(NEW.id, NEW.active_room_id);
    end if;
  end if;
  return NEW;
end;
$$ language plpgsql security definer;

-- Trigger logic for compatibility on direct insert into user_sessions
create or replace function public.on_session_insert()
returns trigger as $$
begin
  update public.user_sessions
  set online_status = 'Offline',
      last_seen = now()
  where user_id = NEW.user_id and session_id <> NEW.session_id;

  update public.profiles
  set active_session_id = NEW.session_id,
      device_fingerprint = NEW.device_id,
      last_seen = to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
  where id = NEW.user_id;

  return NEW;
end;
$$ language plpgsql security definer set search_path = public;

-- 7. Update get_user_gift_stats_v2 RPC to summarize Gems
create or replace function public.get_user_gift_stats_v2(p_user_id uuid)
returns jsonb as $$
declare
  v_lifetime_received numeric := 0;
  v_lifetime_sent numeric := 0;
  v_monthly_received numeric := 0;
  v_monthly_sent numeric := 0;
  v_monthly_key text := to_char(current_date, 'YYYY-MM');
  v_received_avatars text[] := '{}';
  v_sent_avatars text[] := '{}';
begin
  -- Lifetime received Gems
  select coalesce(sum(coalesce(gems_value, stars_value, 0)), 0) into v_lifetime_received 
  from public.gift_transactions 
  where receiver_id = p_user_id;

  -- Lifetime sent Gems
  select coalesce(sum(coalesce(gems_value, stars_value, 0)), 0) into v_lifetime_sent 
  from public.gift_transactions 
  where sender_id = p_user_id;

  -- Monthly received Gems
  select coalesce(sum(coalesce(gems_value, stars_value, 0)), 0) into v_monthly_received 
  from public.gift_transactions 
  where receiver_id = p_user_id 
    and to_char(created_at, 'YYYY-MM') = v_monthly_key;

  -- Monthly sent Gems
  select coalesce(sum(coalesce(gems_value, stars_value, 0)), 0) into v_monthly_sent 
  from public.gift_transactions 
  where sender_id = p_user_id 
    and to_char(created_at, 'YYYY-MM') = v_monthly_key;

  -- Recent received avatars
  select array_agg(avatar_url) into v_received_avatars
  from (
    select distinct on (t.sender_id) p.avatar_url, max(t.created_at) as max_time
    from public.gift_transactions t
    join public.profiles p on p.id = t.sender_id
    where t.receiver_id = p_user_id and p.avatar_url is not null and p.avatar_url <> ''
    group by t.sender_id, p.avatar_url
    order by t.sender_id, max_time desc
    limit 4
  ) tmp;

  -- Recent sent avatars
  select array_agg(avatar_url) into v_sent_avatars
  from (
    select distinct on (t.receiver_id) p.avatar_url, max(t.created_at) as max_time
    from public.gift_transactions t
    join public.profiles p on p.id = t.receiver_id
    where t.sender_id = p_user_id and p.avatar_url is not null and p.avatar_url <> ''
    group by t.receiver_id, p.avatar_url
    order by t.receiver_id, max_time desc
    limit 4
  ) tmp;

  return jsonb_build_object(
    'lifetime_gems_received', v_lifetime_received,
    'lifetime_gems_sent', v_lifetime_sent,
    'monthly_gems_received', v_monthly_received,
    'monthly_gems_sent', v_monthly_sent,
    'lifetime_received', v_lifetime_received,
    'lifetime_sent', v_lifetime_sent,
    'monthly_received', v_monthly_received,
    'monthly_sent', v_monthly_sent,
    'received_avatars', coalesce(v_received_avatars, array[]::text[]),
    'sent_avatars', coalesce(v_sent_avatars, array[]::text[])
  );
end;
$$ language plpgsql security definer;

-- Trigger to create notification settings on user signup
create or replace function public.handle_new_profile_notification_settings()
returns trigger as $$
begin
  insert into public.notification_settings(user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

-- 1. Community Join/Leave/Kick Notifications
create or replace function public.handle_community_membership_notifications()
returns trigger as $$
declare
  v_community_name text;
  v_username text;
  v_owner_id uuid;
begin
  -- Fetch community name and owner
  select name, owner::uuid into v_community_name, v_owner_id 
  from public.communities 
  where id = coalesce(new.community_id, old.community_id);

  if (v_community_name is null) then
    v_community_name := 'a community';
  end if;

  if (tg_op = 'INSERT') then
    -- Get username of the person who joined
    select username into v_username from public.profiles where id = new.user_id;

    -- Notification for the user who joined
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.user_id,
      'Joined Community 🎉',
      'Welcome to ' || v_community_name || '! Start participating in discussions.',
      'community',
      jsonb_build_object(
        'communityId', new.community_id,
        'action', 'join'
      )
    );

    -- Notification for the community owner (if not the user themselves)
    if (v_owner_id is not null and v_owner_id <> new.user_id) then
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        v_owner_id,
        'New Community Member 👥',
        '@' || coalesce(v_username, 'Someone') || ' joined your community "' || v_community_name || '".',
        'community',
        jsonb_build_object(
          'communityId', new.community_id,
          'userId', new.user_id,
          'action', 'new_member'
        )
      );
    end if;

  elsif (tg_op = 'DELETE') then
    -- Get username of the person who left/was kicked
    select username into v_username from public.profiles where id = old.user_id;

    -- Check if self-initiated or kicked
    if (auth.uid() = old.user_id) then
      -- User left voluntarily
      if (v_owner_id is not null and v_owner_id <> old.user_id) then
        insert into public.notifications (user_id, title, body, type, payload)
        values (
          v_owner_id,
          'Member Left 👥',
          '@' || coalesce(v_username, 'Someone') || ' left your community "' || v_community_name || '".',
          'community',
          jsonb_build_object(
            'communityId', old.community_id,
            'userId', old.user_id,
            'action', 'member_left'
          )
        );
      end if;
    else
      -- User was kicked/removed by someone else
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        old.user_id,
        'Removed from Community 🚫',
        'You have been removed from the community "' || v_community_name || '".',
        'community',
        jsonb_build_object(
          'communityId', old.community_id,
          'action', 'removed'
        )
      );
    end if;
  end if;

  return null;
end;
$$ language plpgsql security definer set search_path = public;

-- 2. Follow / Connection Notifications (Follow, Follow Request, and Request Acceptance)
create or replace function public.handle_connections_notifications()
returns trigger as $$
declare
  v_follower_username text;
  v_following_username text;
begin
  if (tg_op = 'INSERT') then
    select username into v_follower_username from public.profiles where id = new.follower_id;

    if (new.status = 'requested') then
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        new.following_id,
        'Follow Request 👥',
        '@' || coalesce(v_follower_username, 'Someone') || ' requested to follow you.',
        'follow_request',
        jsonb_build_object(
          'userId', new.follower_id,
          'action', 'follow_request'
        )
      );
    else
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        new.following_id,
        'New Follower 🌟',
        '@' || coalesce(v_follower_username, 'Someone') || ' started following you!',
        'new_follower',
        jsonb_build_object(
          'userId', new.follower_id,
          'action', 'follow'
        )
      );
    end if;
  elsif (tg_op = 'UPDATE') then
    if (old.status = 'requested' and new.status = 'following') then
      select username into v_following_username from public.profiles where id = new.following_id;

      insert into public.notifications (user_id, title, body, type, payload)
      values (
        new.follower_id,
        'Follow Request Accepted 🎉',
        '@' || coalesce(v_following_username, 'Someone') || ' accepted your follow request.',
        'follow_request_accepted',
        jsonb_build_object(
          'userId', new.following_id,
          'action', 'follow_accepted'
        )
      );
    end if;
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

-- 4. Profile level ups, VIP, and verification status changes
create or replace function public.handle_profile_activity_notifications()
returns trigger as $$
begin
  -- 1. Level up (ID level)
  if (new.level > old.level) then
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.id,
      'Level Up! 🎉',
      'Congratulations! You reached ID Level ' || new.level || '.',
      'level_up_id',
      jsonb_build_object(
        'newLevel', new.level,
        'action', 'level_up'
      )
    );
  end if;

  -- 2. Level up (Career level)
  if (new.career_level > old.career_level) then
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.id,
      'Career Promotion! ⚔️',
      'You promoted to Career Level ' || new.career_level || '.',
      'level_up_career',
      jsonb_build_object(
        'newCareerLevel', new.career_level,
        'action', 'career_up'
      )
    );
  end if;

  -- 3. VIP level upgrade
  if (new.vip_level > old.vip_level) then
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.id,
      'VIP Level Upgraded 👑',
      'Congratulations! You upgraded to VIP Level ' || new.vip_level || '.',
      'vip_upgrade',
      jsonb_build_object(
        'newVipLevel', new.vip_level,
        'action', 'vip_up'
      )
    );
  end if;

  -- 4. Profile verification status
  if (new.verified = true and old.verified = false) then
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.id,
      'Verification Approved! ✅',
      'Your profile verification has been approved. The checkmark badge is now unlocked!',
      'verification_approved',
      jsonb_build_object('action', 'verified')
    );
  elsif (new.verified = false and old.verified = true) then
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.id,
      'Verification Revoked ⚠️',
      'Your profile verification checkmark badge has been revoked.',
      'verification_rejected',
      jsonb_build_object('action', 'unverified')
    );
  end if;

  return null;
end;
$$ language plpgsql security definer set search_path = public;

-- 5. Community Applications (Join Requests, Approvals, Rejections)
create or replace function public.handle_community_applications_notifications()
returns trigger as $$
declare
  v_community_name text;
  v_owner_id uuid;
  v_username text;
begin
  select name, owner::uuid into v_community_name, v_owner_id 
  from public.communities 
  where id = new.community_id;

  if (v_community_name is null) then
    v_community_name := 'a community';
  end if;

  select username into v_username from public.profiles where id = new.user_id;

  if (tg_op = 'INSERT' and new.status = 'pending') then
    -- Notify community owner of new join request
    if (v_owner_id is not null) then
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        v_owner_id,
        'New Join Request 👥',
        '@' || coalesce(v_username, 'Someone') || ' requested to join your community "' || v_community_name || '".',
        'community',
        jsonb_build_object(
          'communityId', new.community_id,
          'applicationId', new.id,
          'action', 'join_request'
        )
      );
    end if;
  elsif (tg_op = 'UPDATE' and old.status = 'pending' and new.status = 'approved') then
    -- Notify user request is approved
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.user_id,
      'Join Request Approved! 🎉',
      'Your request to join "' || v_community_name || '" has been approved.',
      'community',
      jsonb_build_object(
        'communityId', new.community_id,
        'action', 'join_approved'
      )
    );
  elsif (tg_op = 'UPDATE' and old.status = 'pending' and new.status = 'rejected') then
    -- Notify user request is rejected
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.user_id,
      'Join Request Rejected 🚫',
      'Your request to join "' || v_community_name || '" was rejected.',
      'community',
      jsonb_build_object(
        'communityId', new.community_id,
        'action', 'join_rejected'
      )
    );
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

-- 7. Voice Room Invites
create or replace function public.handle_room_invites_notifications()
returns trigger as $$
declare
  v_inviter_username text;
  v_room_name text;
begin
  select username into v_inviter_username from public.profiles where id = new.invited_by;
  select name into v_room_name from public.rooms where id = new.room_id;

  if (v_room_name is null) then
    v_room_name := 'Arena Room';
  end if;

  insert into public.notifications (user_id, title, body, type, payload)
  values (
    new.user_id,
    'Room Invitation 🎤',
    '@' || coalesce(v_inviter_username, 'Someone') || ' invited you to join their room "' || v_room_name || '".',
    'room',
    jsonb_build_object(
      'roomId', new.room_id,
      'userId', new.invited_by,
      'action', 'room_invite'
    )
  );
  return null;
end;
$$ language plpgsql security definer set search_path = public;

-- 8. Post Likes
create or replace function public.handle_post_likes_notifications()
returns trigger as $$
declare
  v_liker_username text;
  v_post_owner_id uuid;
begin
  select user_id into v_post_owner_id from public.posts where id = new.post_id;
  select username into v_liker_username from public.profiles where id = new.user_id;

  if (v_post_owner_id is not null and v_post_owner_id <> new.user_id) then
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      v_post_owner_id,
      'New Like ❤️',
      '@' || coalesce(v_liker_username, 'Someone') || ' liked your post.',
      'like',
      jsonb_build_object(
        'postId', new.post_id,
        'likerName', coalesce(v_liker_username, 'Someone'),
        'action', 'post_like'
      )
    );
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

-- 9. Post Comments
create or replace function public.handle_post_comments_notifications()
returns trigger as $$
declare
  v_commenter_username text;
  v_post_owner_id uuid;
begin
  select user_id into v_post_owner_id from public.posts where id = new.post_id;
  select username into v_commenter_username from public.profiles where id = new.user_id;

  if (v_post_owner_id is not null and v_post_owner_id <> new.user_id) then
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      v_post_owner_id,
      'New Comment 💬',
      '@' || coalesce(v_commenter_username, 'Someone') || ' commented: "' || substring(new.content from 1 for 30) || '..."',
      'comment',
      jsonb_build_object(
        'postId', new.post_id,
        'commentId', new.id,
        'commenterName', coalesce(v_commenter_username, 'Someone'),
        'action', 'post_comment'
      )
    );
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

-- 10. Followers Notification (Publish Post)
create or replace function public.handle_new_posts_notifications()
returns trigger as $$
declare
  v_publisher_username text;
begin
  select username into v_publisher_username from public.profiles where id = new.user_id;

  -- Notify all followers of the post publisher
  insert into public.notifications (user_id, title, body, type, payload)
  select 
    follower_id,
    'New Post 📝',
    '@' || coalesce(v_publisher_username, 'Someone') || ' published a new post.',
    'new_post',
    jsonb_build_object(
      'postId', new.id,
      'action', 'new_post'
    )
  from public.connections
  where following_id = new.user_id;

  return null;
end;
$$ language plpgsql security definer set search_path = public;

-- ── 2. RPC: Batch Execution Procedure (Consolidates Multiple Operations) ───

CREATE OR REPLACE FUNCTION batch_execute_operations(p_operations JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item JSONB;
    v_action TEXT;
    v_payload JSONB;
    v_results JSONB := '[]'::jsonb;
    v_res JSONB;
BEGIN
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_operations)
    LOOP
        v_action := v_item->>'action';
        v_payload := v_item->'payload';

        BEGIN
            IF v_action = 'update_profile_stats' THEN
                UPDATE profiles
                SET updated_at = NOW()
                WHERE id = (v_payload->>'user_id')::uuid;
                v_res := jsonb_build_object('status', 'success', 'action', v_action);
            ELSIF v_action = 'record_telemetry' THEN
                v_res := jsonb_build_object('status', 'success', 'action', v_action);
            ELSE
                v_res := jsonb_build_object('status', 'acknowledged', 'action', v_action);
            END IF;
        EXCEPTION WHEN OTHERS THEN
            v_res := jsonb_build_object('status', 'error', 'message', SQLERRM);
        END;

        v_results := v_results || jsonb_build_array(v_res);
    END LOOP;

    RETURN v_results;
END;
$$;

-- ── 3. RPC: Delta Updates Query Helper ──────────────────────────────────────

CREATE OR REPLACE FUNCTION get_delta_updates(
    p_table_name TEXT,
    p_last_sync_timestamp TIMESTAMPTZ,
    p_limit INT DEFAULT 50
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_query TEXT;
    v_result JSONB;
BEGIN
    -- Whitelist allowed tables to prevent SQL injection
    IF p_table_name NOT IN ('profiles', 'voice_rooms', 'communities', 'study_vault_items', 'messages') THEN
        RAISE EXCEPTION 'Unauthorized table name for delta sync: %', p_table_name;
    END IF;

    v_query := format(
        'SELECT jsonb_agg(t) FROM (SELECT * FROM %I WHERE updated_at > %L ORDER BY updated_at ASC LIMIT %s) t',
        p_table_name,
        p_last_sync_timestamp,
        p_limit
    );

    EXECUTE v_query INTO v_result;
    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- 9. Fix type coercion in get_user_full_inventory_and_entitlements_rpc
create or replace function public.get_user_full_inventory_and_entitlements_rpc(
  p_user_id uuid
) returns jsonb as $$
declare
  v_vip_sub      record;
  v_novel_sub    record;
  v_profile      record;
  v_inventory    jsonb;
  v_equipped     jsonb;
  v_frame_name   text;
begin
  if p_user_id is null then
    raise exception 'get_user_full_inventory_and_entitlements_rpc: missing p_user_id';
  end if;

  select vip_level, vip_expiry, novel_level, novel_expiry, avatar_frame, showcased_badges, tag_system
  into v_profile from public.profiles where id = p_user_id;

  select level, expiry_date, status into v_vip_sub
  from public.subscriptions
  where user_id = p_user_id and membership_type = 'VIP' and status = 'Active' and expiry_date > now()
  order by level desc limit 1;

  select level, expiry_date, status into v_novel_sub
  from public.subscriptions
  where user_id = p_user_id and membership_type = 'Novel' and status = 'Active' and expiry_date > now()
  order by level desc limit 1;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', coalesce(asset_id::text, name), 'name', name, 'type', type,
    'is_equipped', is_equipped, 'asset_id', asset_id, 'created_at', created_at
  )), '[]'::jsonb) into v_inventory
  from public.user_customizations where user_id = p_user_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'type', type, 'name', name, 'asset_id', asset_id, 'path', path
  )), '[]'::jsonb) into v_equipped
  from public.user_customizations where user_id = p_user_id and is_equipped = true;

  -- Resolve active frame cleanly
  select name into v_frame_name
  from public.user_customizations
  where user_id = p_user_id and type in ('Avatar Frame', 'avatar_frame', 'profile_frame') and is_equipped = true
  limit 1;

  if v_frame_name is null or v_frame_name = '' then
    v_frame_name := coalesce(v_profile.avatar_frame, 'Normal');
  end if;

  return jsonb_build_object(
    'user_id', p_user_id,
    'vip', jsonb_build_object(
      'level',       coalesce(v_vip_sub.level, v_profile.vip_level, 0),
      'expiry_date', coalesce(v_vip_sub.expiry_date, v_profile.vip_expiry),
      'is_active',   (coalesce(v_vip_sub.level, v_profile.vip_level, 0) > 0 and coalesce(v_vip_sub.expiry_date, v_profile.vip_expiry, now()) > now())
    ),
    'novel', jsonb_build_object(
      'level',       coalesce(v_novel_sub.level, v_profile.novel_level, 0),
      'expiry_date', coalesce(v_novel_sub.expiry_date, v_profile.novel_expiry),
      'is_active',   (coalesce(v_novel_sub.level, v_profile.novel_level, 0) > 0 and coalesce(v_novel_sub.expiry_date, v_profile.novel_expiry, now()) > now())
    ),
    'profile_frame',   v_frame_name,
    'showcased_badges',coalesce(to_jsonb(v_profile.showcased_badges), '[]'::jsonb),
    'tag_system',      coalesce(v_profile.tag_system, '{}'::jsonb),
    'inventory',       v_inventory,
    'equipped',        v_equipped
  );
end;
$$ language plpgsql security definer set search_path = public;

-- 2. Safe equip_item_rpc: Normalizes categories ('Avatar Frame', 'avatar_frame', 'profile_frame') and executes safe UPSERT
create or replace function public.equip_item_rpc(
  p_user_id   uuid,
  p_category  text,
  p_item_name text,
  p_asset_id  text default null,
  p_path      text default null
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_action        text := 'EQUIP';
  v_owns_item     boolean := false;
  v_confirmed     record;
  v_norm_category text;
begin
  if p_user_id is null or p_category is null or p_item_name is null then
    raise exception 'equip_item_rpc: missing required parameters';
  end if;

  -- Normalize category string
  if p_category in ('Avatar Frame', 'avatar_frame', 'profile_frame', 'Frame') then
    v_norm_category := 'Avatar Frame';
  else
    v_norm_category := p_category;
  end if;

  if p_item_name in ('Normal', 'None', 'Classic Bubble', 'Dark', 'Default') then
    v_action := 'UNEQUIP';
    v_owns_item := true;
  end if;

  if not v_owns_item then
    select exists(
      select 1 from public.user_customizations
      where user_id = p_user_id and name = p_item_name
    ) into v_owns_item;
  end if;

  if not v_owns_item then
    -- Check profiles table or entitlement catalog
    select (coalesce(avatar_frame, '') = p_item_name) into v_owns_item
    from public.profiles where id = p_user_id;
  end if;

  -- Default unlocked items check
  if not v_owns_item and p_item_name in ('Novel Level 1', 'Royal Frame', 'Neon Frame (Animated)') then
    v_owns_item := true;
  end if;

  if not v_owns_item then
    perform public._log_equip_step(p_user_id, v_action, v_norm_category, p_item_name,
      'OWNERSHIP_CHECK_FAILED', null, 'Item not found in inventory');
    raise exception 'Item "%" not found in inventory for user %', p_item_name, p_user_id;
  end if;

  -- Unequip existing items in category
  update public.user_customizations
  set is_equipped = false
  where user_id = p_user_id and (type = v_norm_category or type = p_category) and is_equipped = true;

  -- Safe update or insert
  if exists (
    select 1 from public.user_customizations
    where user_id = p_user_id and (type = v_norm_category or type = p_category) and name = p_item_name
  ) then
    update public.user_customizations
    set is_equipped = true,
        asset_id    = coalesce(p_asset_id, asset_id),
        path        = coalesce(p_path, path)
    where user_id = p_user_id and (type = v_norm_category or type = p_category) and name = p_item_name;
  else
    insert into public.user_customizations (user_id, type, name, is_equipped, asset_id, path)
    values (p_user_id, v_norm_category, p_item_name, true, p_asset_id, p_path);
  end if;

  -- Sync profiles.avatar_frame if Avatar Frame
  if v_norm_category = 'Avatar Frame' then
    update public.profiles set avatar_frame = p_item_name where id = p_user_id;
  end if;

  select * into v_confirmed from public.user_customizations
  where user_id = p_user_id and name = p_item_name limit 1;

  return jsonb_build_object(
    'success', true,
    'confirmed', jsonb_build_object(
      'type',        v_norm_category,
      'name',        p_item_name,
      'is_equipped', true,
      'asset_id',    coalesce(v_confirmed.asset_id, p_asset_id),
      'path',        coalesce(v_confirmed.path, p_path)
    )
  );
exception when others then
  raise;
end;
$fn$;

-- Atomic unequip_item_rpc: unequip all items of a category
create or replace function public.unequip_item_rpc(
  p_user_id  uuid,
  p_category text
)
returns jsonb as $$
begin
  if p_user_id is null or p_category is null then
    raise exception 'unequip_item_rpc: missing required parameters';
  end if;

  update public.user_customizations
  set is_equipped = false
  where user_id = p_user_id and type = p_category;

  -- If Avatar Frame, also reset profiles.avatar_frame
  if p_category = 'Avatar Frame' then
    update public.profiles
    set avatar_frame = 'Normal'
    where id = p_user_id;
  end if;

  return jsonb_build_object('success', true, 'category', p_category);
end;
$$ language plpgsql security definer set search_path = public;

-- 4. Master Purchase & Activation RPC
CREATE OR REPLACE FUNCTION public.purchase_and_activate_rpc(
  p_user_id        uuid,
  p_product_name   text,
  p_category       text,
  p_amount         numeric,
  p_final_amount   numeric,
  p_payment_method text,
  p_duration       text,
  p_payment_id     text DEFAULT NULL,
  p_order_id       text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_level              integer := 0;
  v_base_days          integer := 30;
  v_bonus_days         integer := 0;
  v_total_days         integer := 30;
  v_old_level          integer := 0;
  v_old_expiry         timestamptz;
  v_new_expiry         timestamptz;
  v_frame_name         text;
  v_has_frame          boolean := false;
  
  -- Coin & Reward calculations
  v_base_coins         integer := 0;
  v_recharge_bonus     integer := 0;
  v_first_bonus_coins  integer := 0;
  v_total_coins_credit integer := 0;
  
  -- Profiles first-purchase flags
  v_is_first_purchase       boolean := false;
  v_is_first_vip_purchase   boolean := false;
  v_is_first_novel_purchase boolean := false;
  v_user_profile            public.profiles%ROWTYPE;
BEGIN
  IF p_user_id IS NULL OR p_product_name IS NULL OR p_category IS NULL THEN
    RAISE EXCEPTION 'purchase_and_activate_rpc: missing required parameters';
  END IF;

  -- 1. Idempotency Check: Avoid double-crediting if payment already processed
  IF p_payment_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.purchases WHERE payment_id = p_payment_id AND status = 'Success'
  ) THEN
    RETURN jsonb_build_object(
      'success', true,
      'idempotent', true,
      'product', p_product_name,
      'category', p_category,
      'message', 'Payment already processed successfully'
    );
  END IF;

  -- Load user profile flags with row lock
  SELECT * INTO v_user_profile FROM public.profiles WHERE id = p_user_id FOR UPDATE;

  v_is_first_purchase       := COALESCE(v_user_profile.first_purchase_completed, false) = false;
  v_is_first_vip_purchase   := COALESCE(v_user_profile.first_vip_purchase_completed, false) = false;
  v_is_first_novel_purchase := COALESCE(v_user_profile.first_novel_purchase_completed, false) = false;

  v_level := COALESCE((regexp_match(p_product_name, E'(\\d+)'))[1]::integer, 1);

  -- Record purchase log in purchases table
  INSERT INTO public.purchases
    (user_id, product_name, category, amount, final_amount, payment_method, status, duration, payment_id)
  VALUES (p_user_id, p_product_name, p_category, p_amount, p_final_amount,
          p_payment_method, 'Success', p_duration, p_payment_id);

  -- ── CATEGORY 1: COINS (RECHARGE) ──────────────────────────────────────────
  IF p_category = 'Coins' THEN
    -- CONVERSION RULE: Base Coins = floor((p_final_amount + 1) / 2) for round values (50, 100, 250, 500, etc.)
    v_base_coins := FLOOR((p_final_amount + 1.0) / 2.0)::integer;
    
    -- Recharge Package Bonus Coins (Tiered structure)
    IF p_final_amount >= 9999 THEN
      v_recharge_bonus := 599;
    ELSIF p_final_amount >= 4999 THEN
      v_recharge_bonus := 399;
    ELSIF p_final_amount >= 1999 THEN
      v_recharge_bonus := 199;
    ELSIF p_final_amount >= 999 THEN
      v_recharge_bonus := 125;
    ELSIF p_final_amount >= 499 THEN
      v_recharge_bonus := 50;
    ELSIF p_final_amount >= 199 THEN
      v_recharge_bonus := 15;
    ELSIF p_final_amount >= 99 THEN
      v_recharge_bonus := 5;
    ELSE
      v_recharge_bonus := 0;
    END IF;

    -- First Time Purchase Bonus
    IF v_is_first_purchase THEN
      v_first_bonus_coins := 50;
      
      -- Grant First Purchase Frame
      INSERT INTO public.user_customizations (user_id, type, name, is_equipped)
      VALUES (p_user_id, 'Avatar Frame', 'Royal Frame', false)
      ON CONFLICT DO NOTHING;

      -- Mark first purchase completed permanently
      UPDATE public.profiles
      SET first_purchase_completed = true
      WHERE id = p_user_id;
    END IF;

    v_total_coins_credit := v_base_coins + v_recharge_bonus + v_first_bonus_coins;

    -- Credit to Coin Wallet
    INSERT INTO public.wallets (id, gold_coins, coins_balance, silver_coins, withdrawable_balance)
    VALUES (p_user_id, v_total_coins_credit, v_total_coins_credit, 0, 0.0)
    ON CONFLICT (id) DO UPDATE
    SET gold_coins = COALESCE(public.wallets.gold_coins, 0) + v_total_coins_credit,
        coins_balance = COALESCE(public.wallets.coins_balance, 0) + v_total_coins_credit;

    -- Transaction ledger with clear breakdown
    INSERT INTO public.wallet_transactions (wallet_id, amount, currency, type, status, details)
    VALUES (
      p_user_id,
      v_total_coins_credit,
      'Gold Coins',
      'Recharge',
      'Completed',
      'Base: ' || v_base_coins || ' Coins, Bonus: ' || v_recharge_bonus || ' Coins, First Purchase Bonus: ' || v_first_bonus_coins || ' Coins, Total Credited: ' || v_total_coins_credit || ' Coins'
    );

    RETURN jsonb_build_object(
      'success', true,
      'category', 'Coins',
      'base_coins', v_base_coins,
      'recharge_bonus', v_recharge_bonus,
      'first_purchase_bonus', v_first_bonus_coins,
      'total_coins_added', v_total_coins_credit
    );

  -- ── CATEGORY 2: VIP ────────────────────────────────────────────────────────
  ELSIF p_category = 'VIP' THEN
    -- Exact duration mapping
    v_base_days := CASE p_duration
      when '3 Days'   then 3
      when '7 Days'   then 7
      when '15 Days'  then 15
      when '30 Days'  then 30
      when '1 Month'  then 30
      when '90 Days'  then 90
      when '3 Months' then 90
      when '1 Year'   then 365
      when '365 Days' then 365
      else 30
    END;

    -- Promotional bonus days
    v_bonus_days := CASE v_base_days
      when 30  then 3
      when 90  then 10
      when 365 then 30
      else 0
    END;

    -- First Time VIP Purchase Offer
    IF v_is_first_vip_purchase THEN
      v_bonus_days := v_bonus_days + 3; -- +3 Extra First VIP Days
      v_first_bonus_coins := 20;

      -- Credit first VIP bonus coins
      INSERT INTO public.wallets (id, gold_coins, coins_balance, silver_coins, withdrawable_balance)
      VALUES (p_user_id, 20, 20, 0, 0.0)
      ON CONFLICT (id) DO UPDATE
      SET gold_coins = COALESCE(public.wallets.gold_coins, 0) + 20,
          coins_balance = COALESCE(public.wallets.coins_balance, 0) + 20;

      INSERT INTO public.wallet_transactions (wallet_id, amount, currency, type, status, details)
      VALUES (p_user_id, 20, 'Gold Coins', 'VIP First Purchase Reward', 'Completed', 'First VIP Purchase Bonus Coins');

      UPDATE public.profiles
      SET first_vip_purchase_completed = true,
          first_purchase_completed = true
      WHERE id = p_user_id;
    END IF;

    v_total_days := v_base_days + v_bonus_days;

    -- Fetch current active VIP subscription
    SELECT level, expiry_date INTO v_old_level, v_old_expiry
    FROM public.subscriptions
    WHERE user_id = p_user_id AND membership_type = 'VIP' AND status = 'Active'
    ORDER BY level DESC LIMIT 1;
    v_old_level := COALESCE(v_old_level, 0);

    -- Calculate expiry strictly without arbitrary multipliers
    IF v_old_expiry IS NOT NULL AND v_old_expiry > now() THEN
      v_new_expiry := v_old_expiry + (v_total_days || ' days')::interval;
    ELSE
      v_new_expiry := now() + (v_total_days || ' days')::interval;
    END IF;

    v_frame_name := CASE v_level
      when 1 then 'Royal Frame'            when 2 then 'Neon Frame (Animated)'
      when 3 then 'Gold Glow Frame'        when 4 then 'Diamond Frame'
      when 5 then 'Crystal Cyan Frame'     when 6 then 'Rainbow Frame (Animated)'
      when 7 then 'Royal Crown (Animated)' else 'Royal Frame' END;

    IF EXISTS (SELECT 1 FROM public.subscriptions WHERE user_id = p_user_id AND membership_type = 'VIP') THEN
      UPDATE public.subscriptions
      SET level           = GREATEST(subscriptions.level, v_level),
          activation_date = now(),
          expiry_date     = GREATEST(subscriptions.expiry_date, v_new_expiry),
          status          = 'Active',
          payment_id      = p_payment_id
      WHERE user_id = p_user_id AND membership_type = 'VIP';
    ELSE
      INSERT INTO public.subscriptions
        (user_id, membership_type, level, purchase_date, activation_date, expiry_date, auto_renewal, status, payment_id)
      VALUES (p_user_id, 'VIP', v_level, now(), now(), v_new_expiry, true, 'Active', p_payment_id);
    END IF;

    UPDATE public.profiles
    SET vip_level  = GREATEST(COALESCE(vip_level, 0), v_level),
        vip_expiry = GREATEST(COALESCE(vip_expiry, now()), v_new_expiry)
    WHERE id = p_user_id;

    -- Frame Equip
    INSERT INTO public.user_customizations (user_id, type, name, is_equipped)
    VALUES (p_user_id, 'Avatar Frame', v_frame_name, false)
    ON CONFLICT DO NOTHING;

    RETURN jsonb_build_object(
      'success', true,
      'category', 'VIP',
      'level', v_level,
      'base_days', v_base_days,
      'bonus_days', v_bonus_days,
      'total_days', v_total_days,
      'expiry', v_new_expiry,
      'frame_name', v_frame_name
    );

  -- ── CATEGORY 3: NOVEL ──────────────────────────────────────────────────────
  ELSIF p_category = 'Novel' THEN
    v_base_days := CASE p_duration
      when '3 Days'   then 3
      when '7 Days'   then 7
      when '15 Days'  then 15
      when '30 Days'  then 30
      when '1 Month'  then 30
      when '90 Days'  then 90
      when '3 Months' then 90
      when '1 Year'   then 365
      when '365 Days' then 365
      else 30
    END;

    v_bonus_days := CASE v_base_days
      when 30  then 3
      when 90  then 10
      when 365 then 30
      else 0
    END;

    -- First Time Novel Purchase Offer
    IF v_is_first_novel_purchase THEN
      v_bonus_days := v_bonus_days + 3;
      v_first_bonus_coins := 20;

      INSERT INTO public.wallets (id, gold_coins, coins_balance, silver_coins, withdrawable_balance)
      VALUES (p_user_id, 20, 20, 0, 0.0)
      ON CONFLICT (id) DO UPDATE
      SET gold_coins = COALESCE(public.wallets.gold_coins, 0) + 20,
          coins_balance = COALESCE(public.wallets.coins_balance, 0) + 20;

      INSERT INTO public.wallet_transactions (wallet_id, amount, currency, type, status, details)
      VALUES (p_user_id, 20, 'Gold Coins', 'Novel First Purchase Reward', 'Completed', 'First Novel Purchase Bonus Coins');

      UPDATE public.profiles
      SET first_novel_purchase_completed = true,
          first_purchase_completed = true
      WHERE id = p_user_id;
    END IF;

    v_total_days := v_base_days + v_bonus_days;

    SELECT level, expiry_date INTO v_old_level, v_old_expiry
    FROM public.subscriptions
    WHERE user_id = p_user_id AND membership_type = 'Novel' AND status = 'Active'
    ORDER BY level DESC LIMIT 1;

    IF v_old_expiry IS NOT NULL AND v_old_expiry > now() THEN
      v_new_expiry := v_old_expiry + (v_total_days || ' days')::interval;
    ELSE
      v_new_expiry := now() + (v_total_days || ' days')::interval;
    END IF;

    IF EXISTS (SELECT 1 FROM public.subscriptions WHERE user_id = p_user_id AND membership_type = 'Novel') THEN
      UPDATE public.subscriptions
      SET level           = GREATEST(subscriptions.level, v_level),
          activation_date = now(),
          expiry_date     = GREATEST(subscriptions.expiry_date, v_new_expiry),
          status          = 'Active',
          payment_id      = p_payment_id
      WHERE user_id = p_user_id AND membership_type = 'Novel';
    ELSE
      INSERT INTO public.subscriptions
        (user_id, membership_type, level, purchase_date, activation_date, expiry_date, auto_renewal, status, payment_id)
      VALUES (p_user_id, 'Novel', v_level, now(), now(), v_new_expiry, true, 'Active', p_payment_id);
    END IF;

    UPDATE public.profiles
    SET novel_level  = GREATEST(COALESCE(novel_level, 0), v_level),
        novel_expiry = GREATEST(COALESCE(novel_expiry, now()), v_new_expiry)
    WHERE id = p_user_id;

    RETURN jsonb_build_object(
      'success', true,
      'category', 'Novel',
      'level', v_level,
      'base_days', v_base_days,
      'bonus_days', v_bonus_days,
      'total_days', v_total_days,
      'expiry', v_new_expiry
    );
  END IF;

  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RAISE;
END;
$fn$;

-- 2. Security Definer RPC: Register New Login Session (Authenticates new device & invalidates previous sessions)
create or replace function public.register_new_session(
  p_session_id text,
  p_device_id text,
  p_device_name text default null,
  p_os_version text default null,
  p_app_version text default null,
  p_platform text default null
) returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_prev_session_id text;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  -- 1. Fetch previous active session ID for logging
  select active_session_id into v_prev_session_id
  from public.profiles
  where id = v_user_id;

  -- 2. Invalidate all previous sessions for this user by marking them 'Offline'
  update public.user_sessions
  set online_status = 'Offline',
      last_seen = now()
  where user_id = v_user_id and session_id <> p_session_id;

  -- 3. Insert or update the new session record as 'Online'
  insert into public.user_sessions (
    session_id, user_id, device_id, device_name, os_version, app_version, platform, login_time, last_seen, online_status
  ) values (
    p_session_id, v_user_id, p_device_id, p_device_name, p_os_version, p_app_version, p_platform, now(), now(), 'Online'
  ) on conflict (session_id) do update set
    last_seen = now(),
    online_status = 'Online',
    device_id = EXCLUDED.device_id;

  -- 4. Update profile active_session_id to the NEW session ID (Single Source of Truth)
  update public.profiles
  set active_session_id = p_session_id,
      device_fingerprint = p_device_id,
      last_seen = to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
  where id = v_user_id;

  return jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'previous_session_id', v_prev_session_id,
    'new_session_id', p_session_id,
    'device_id', p_device_id,
    'login_time', now()
  );
end;
$$ language plpgsql security definer set search_path = public;

-- 3. RPC: Validate Active Session against latest backend session
create or replace function public.validate_active_session(
  p_user_id uuid,
  p_session_id text
) returns boolean as $$
declare
  v_current_active_session text;
  v_session_status text;
  v_is_banned boolean;
begin
  if p_user_id is null or p_session_id is null or p_session_id = '' then
    return false;
  end if;

  -- Check global account ban status
  select is_banned, active_session_id into v_is_banned, v_current_active_session
  from public.profiles where id = p_user_id;

  if v_is_banned = true then
    return false;
  end if;

  -- If profile active_session_id is not yet initialized, allow
  if v_current_active_session is null or v_current_active_session = '' then
    return true;
  end if;

  -- Strictly compare stored session ID against backend active_session_id
  if v_current_active_session <> p_session_id then
    return false;
  end if;

  -- Verify user_sessions table status
  select online_status into v_session_status
  from public.user_sessions
  where session_id = p_session_id and user_id = p_user_id;

  if v_session_status = 'Offline' then
    return false;
  end if;

  return true;
end;
$$ language plpgsql security definer set search_path = public;

-- 6. RPC: Atomic Store Purchase with Idempotency
create or replace function public.buy_store_item(
  p_item_id text,
  p_item_name text,
  p_category text,
  p_coin_price integer,
  p_session_id text default null,
  p_transaction_id text default null
) returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_user_coins integer;
  v_tx_record public.processed_transactions%rowtype;
  v_res jsonb;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if p_session_id is not null and not public.validate_active_session(v_user_id, p_session_id) then
    raise exception 'Invalid or expired session. Please log in again.';
  end if;

  if p_transaction_id is not null then
    select * into v_tx_record from public.processed_transactions where transaction_id = p_transaction_id;
    if v_tx_record.transaction_id is not null then
      return v_tx_record.result;
    end if;
  end if;

  select coins into v_user_coins from public.profiles where id = v_user_id for update;

  if v_user_coins is null or v_user_coins < p_coin_price then
    raise exception 'Insufficient coin balance';
  end if;

  -- Deduct coins
  update public.profiles set coins = coins - p_coin_price where id = v_user_id;

  -- Insert into user_inventory table
  if exists (select 1 from information_schema.tables where table_name = 'user_inventory') then
    insert into public.user_inventory (user_id, item_id, item_name, category, acquired_at)
    values (v_user_id, p_item_id, p_item_name, p_category, now())
    on conflict do nothing;
  end if;

  v_res := jsonb_build_object(
    'success', true,
    'item_id', p_item_id,
    'item_name', p_item_name,
    'remaining_coins', (v_user_coins - p_coin_price)
  );

  if p_transaction_id is not null then
    insert into public.processed_transactions (transaction_id, user_id, action_type, result)
    values (p_transaction_id, v_user_id, 'store_purchase', v_res);
  end if;

  return v_res;
end;
$$ language plpgsql security definer set search_path = public;

-- 7. RPC: Backend Verification Before Equipping Inventory Items
create or replace function public.equip_user_item(
  p_item_name text,
  p_category text
) returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_owns boolean := false;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if p_item_name is null or p_item_name = 'Normal' or p_item_name = 'None' or p_item_name = 'Classic Bubble' then
    v_owns := true;
  else
    if exists (select 1 from information_schema.tables where table_name = 'user_inventory') then
      select exists(
        select 1 from public.user_inventory
        where user_id = v_user_id and (item_name = p_item_name or item_id = p_item_name)
      ) into v_owns;
    else
      v_owns := true; -- Fallback if inventory table not created yet
    end if;
  end if;

  if not v_owns then
    raise exception 'You do not own this item on the server.';
  end if;

  -- Update profiles cosmetic selection depending on category
  if p_category = 'Avatar Frame' then
    update public.profiles set active_frame = p_item_name where id = v_user_id;
  elsif p_category = 'Chat Bubble' then
    update public.profiles set active_bubble = p_item_name where id = v_user_id;
  elsif p_category = 'Entry Effect' then
    update public.profiles set active_entry_effect = p_item_name where id = v_user_id;
  end if;

  return jsonb_build_object('success', true, 'equipped_item', p_item_name, 'category', p_category);
end;
$$ language plpgsql security definer set search_path = public;

-- 8. RPC: Kick Room Member with Configurable Cooldown
create or replace function public.kick_room_member(
  p_room_id text,
  p_target_user_id uuid,
  p_cooldown_seconds integer default 60
) returns jsonb as $$
declare
  v_caller_id uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_caller_role text;
  v_target_username text;
begin
  if v_caller_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_room from public.rooms where id = p_room_id;
  if v_room.id is null then
    raise exception 'Room not found';
  end if;

  -- Check caller permissions: Must be Host, Co-Host, or Moderator
  if v_room.host_id <> v_caller_id then
    select role into v_caller_role from public.room_members where room_id = p_room_id and user_id = v_caller_id;
    if v_caller_role is null or v_caller_role not in ('Host', 'Co-Host', 'Moderator') then
      raise exception 'Permission denied: Only host or moderators can kick members';
    end if;
  end if;

  select username into v_target_username from public.profiles where id = p_target_user_id;

  -- Clear seat
  update public.room_seats
  set user_id = null, mic_status = 'muted', is_speaking = false
  where room_id = p_room_id and user_id = p_target_user_id;

  -- Remove from room_members
  delete from public.room_members where room_id = p_room_id and user_id = p_target_user_id;

  -- Clear profiles active_room_id if target user's active room matches
  update public.profiles
  set active_room_id = null, presence_state = 'Online'
  where id = p_target_user_id and active_room_id = p_room_id;

  -- Insert temporary ban cooldown entry into room_bans
  insert into public.room_bans (room_id, user_id, banned_by, reason, expires_at)
  values (
    p_room_id,
    p_target_user_id,
    v_caller_id,
    'Kicked by moderator',
    now() + (p_cooldown_seconds || ' seconds')::interval
  )
  on conflict (room_id, user_id) do update
  set expires_at = EXCLUDED.expires_at, banned_by = EXCLUDED.banned_by;

  -- Broadcast kick event
  insert into public.room_activity_events (room_id, event_type, user_id, username, message)
  values (p_room_id, 'kick', p_target_user_id, v_target_username, coalesce(v_target_username, 'Member') || ' was kicked from the room.');

  return jsonb_build_object('success', true, 'kicked_user_id', p_target_user_id, 'cooldown_seconds', p_cooldown_seconds);
end;
$$ language plpgsql security definer set search_path = public;

-- Accurate State Snapshot RPC (STRICT PRESENCE SEPARATION: Only returns users with active room presence)
CREATE OR REPLACE FUNCTION public.get_room_state_snapshot(
  p_room_id text
) RETURNS jsonb AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_room jsonb;
  v_seats jsonb;
  v_members jsonb;
  v_eye_count integer;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated';
  END IF;

  PERFORM public.cleanup_expired_room_members();

  -- Room metadata
  SELECT jsonb_build_object(
    'id', r.id,
    'name', r.name,
    'username', r.username,
    'description', r.description,
    'category', r.category,
    'language', r.language,
    'host_id', r.host_id,
    'status', r.status,
    'visibility', r.visibility,
    'online_members', r.online_members,
    'livekit_room_name', r.livekit_room_name,
    'avatar', r.avatar,
    'banner', r.banner,
    'is_permanent', r.is_permanent,
    'room_level', r.room_level,
    'room_xp', r.room_xp,
    'total_room_gems', COALESCE(r.total_room_gems, r.total_room_stars, 0),
    'today_room_gems', COALESCE(r.today_room_gems, r.today_room_stars, 0),
    'total_room_stars', COALESCE(r.total_room_stars, 0),
    'today_room_stars', COALESCE(r.today_room_stars, 0)
  ) INTO v_room
  FROM public.rooms r
  WHERE r.id = p_room_id;

  IF v_room IS NULL THEN
    RAISE EXCEPTION 'Room not found';
  END IF;

  -- Active Online Eye Count (STRICT PRESENCE ONLY)
  SELECT count(*) INTO v_eye_count
  FROM public.room_members
  WHERE room_id = p_room_id
    AND COALESCE(is_online, true) = true
    AND last_heartbeat_at >= (now() - interval '30 seconds');

  -- Room Seats
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'seatIndex', s.seat_index,
      'role', s.role,
      'userId', s.user_id,
      'seatSessionId', s.seat_session_id,
      'seatSessionGems', COALESCE(s.seat_session_gems, s.seat_total_gems, s.seat_total_stars, 0),
      'seatTotalGems', COALESCE(s.seat_total_gems, s.seat_total_stars, 0),
      'seatTotalStars', COALESCE(s.seat_total_stars, 0),
      'username', COALESCE(s.username, p.username, 'Seat ' || (s.seat_index + 1)),
      'avatar', COALESCE(s.avatar, p.avatar),
      'avatarFrame', s.avatar_frame,
      'level', COALESCE(s.level, p.level, 1),
      'vipLevel', COALESCE(s.vip_level, p.vip_level, 0),
      'nobleLevel', COALESCE(s.noble_level, p.novel_level, 0),
      'micStatus', s.mic_status,
      'isSpeaking', s.is_speaking,
      'silverGiftCount', COALESCE(g.silver_gift_count, 0)
    ) ORDER BY s.seat_index
  ), '[]'::jsonb) INTO v_seats
  FROM public.room_seats s
  LEFT JOIN public.profiles p ON p.id = s.user_id
  LEFT JOIN public.room_seat_gifts g ON g.room_id = s.room_id AND g.seat_index = s.seat_index
  WHERE s.room_id = p_room_id;

  -- Active Room Members (STRICT PRESENCE ONLY: only return users with valid active presence in this room)
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'userId', m.user_id,
      'username', p.username,
      'avatar', p.avatar,
      'role', CASE WHEN m.role IN ('Mod', 'Moderator') THEN 'Host' ELSE m.role END,
      'isMuted', m.is_muted,
      'hasRaisedHand', m.has_raised_hand,
      'joinedAt', m.joined_at,
      'level', p.level,
      'vipLevel', p.vip_level,
      'nobleLevel', p.novel_level
    ) ORDER BY m.joined_at ASC
  ), '[]'::jsonb) INTO v_members
  FROM public.room_members m
  LEFT JOIN public.profiles p ON p.id = m.user_id
  WHERE m.room_id = p_room_id
    AND COALESCE(m.is_online, true) = true
    AND m.last_heartbeat_at >= (now() - interval '30 seconds');

  RETURN jsonb_build_object(
    'room', v_room,
    'seats', v_seats,
    'members', v_members,
    'eyeCount', v_eye_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. Server-Validated Send Room Chat Message RPC
create or replace function public.send_room_chat_message(
  p_room_id text,
  p_content text,
  p_message_type text default 'text',
  p_metadata jsonb default '{}'::jsonb
) returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_msg_id uuid;
  v_is_muted boolean;
begin
  if v_user_id is null then
    raise exception 'Unauthenticated';
  end if;

  -- Verify user is in room
  if not exists (select 1 from public.room_members where room_id = p_room_id and user_id = v_user_id) then
    raise exception 'User is not a member of this room';
  end if;

  -- Verify user is not chat muted or banned
  select is_muted into v_is_muted from public.room_members where room_id = p_room_id and user_id = v_user_id;
  if v_is_muted then
    raise exception 'You are muted in this room';
  end if;

  if exists (select 1 from public.room_bans where room_id = p_room_id and user_id = v_user_id and (expires_at is null or expires_at > now())) then
    raise exception 'You are banned from this room';
  end if;

  select * into v_profile from public.profiles where id = v_user_id;

  insert into public.room_messages (room_id, sender_id, content, message_type, metadata)
  values (p_room_id, v_user_id, p_content, p_message_type, p_metadata)
  returning id into v_msg_id;

  return jsonb_build_object(
    'id', v_msg_id,
    'sender_id', v_user_id,
    'sender_name', v_profile.username,
    'sender_avatar', v_profile.avatar,
    'content', p_content,
    'message_type', p_message_type,
    'metadata', p_metadata,
    'created_at', now()
  );
end;
$$ language plpgsql security definer set search_path = public;

-- 3. HEARTBEAT & STALE MEMBER CLEANUP (8-SECOND TIMEOUT)
create or replace function public.clean_stale_room_members()
returns integer as $$
declare
  v_cleaned_count integer := 0;
  r_stale record;
begin
  -- Find all room members whose last heartbeat exceeds 8 seconds
  for r_stale in
    select room_id, user_id, seat_number
    from public.room_members
    where last_seen < (now() - interval '8 seconds')
  loop
    -- Free seat if assigned
    if r_stale.seat_number is not null then
      update public.room_seats
      set user_id = null,
          is_locked = false,
          is_muted = false,
          joined_at = null
      where room_id = r_stale.room_id and seat_number = r_stale.seat_number and user_id = r_stale.user_id;
    end if;

    -- Delete stale room member entry
    delete from public.room_members
    where room_id = r_stale.room_id and user_id = r_stale.user_id;

    -- Update active profile active_room_id if matches
    update public.profiles
    set active_room_id = null
    where id = r_stale.user_id and active_room_id = r_stale.room_id;

    v_cleaned_count := v_cleaned_count + 1;
  end loop;

  -- Recalculate room member counts for affected rooms
  update public.rooms r
  set total_members = (
    select count(*) from public.room_members rm where rm.room_id = r.id
  )
  where r.status = 'live';

  return v_cleaned_count;
end;
$$ language plpgsql security definer set search_path = public;

-- 2. Single Canonical promote_room_member_role RPC
CREATE OR REPLACE FUNCTION public.promote_room_member_role(
  p_room_id text,
  p_target_user_id uuid,
  p_new_role text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_canonical_owner uuid;
  v_caller_role text := 'Audience';
  v_target_name text;
  v_standard_role text;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Resolve Room ID
  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN
    v_room_id := p_room_id;
  END IF;

  -- Fetch Permanent Room Owner
  SELECT COALESCE(owner_user_id, room_owner, host_id) INTO v_canonical_owner 
  FROM public.rooms WHERE id = v_room_id;

  -- ABSOLUTE PROTECTION: Permanent Owner can NEVER be modified or target of role change
  IF p_target_user_id = v_canonical_owner THEN
    RAISE EXCEPTION 'OWNER_PROTECTED: Permanent Room Owner role cannot be modified.';
  END IF;

  -- Standardize Target Role to strict 4-role system: Co-Owner, Admin, Mod
  IF p_new_role IN ('Co-Owner', 'Co Owner', 'coowner', 'co-owner') THEN
    v_standard_role := 'Co-Owner';
  ELSIF p_new_role IN ('Admin', 'admin') THEN
    v_standard_role := 'Admin';
  ELSIF p_new_role IN ('Mod', 'mod', 'Moderator', 'moderator', 'Host', 'host', 'Host Member') THEN
    v_standard_role := 'Mod';
  ELSE
    RAISE EXCEPTION 'Invalid room role: %. Allowed roles are: Co-Owner, Admin, Mod.', p_new_role;
  END IF;

  -- Determine Caller Authority
  IF v_caller_id = v_canonical_owner THEN
    v_caller_role := 'Owner';
  ELSE
    SELECT role INTO v_caller_role FROM public.room_members WHERE room_id = v_room_id AND user_id = v_caller_id;
    IF v_caller_role IS NULL THEN
      v_caller_role := 'Audience';
    END IF;
  END IF;

  -- Permission Hierarchy Enforcement
  IF v_caller_role IN ('Owner', 'Creator', 'Founder') THEN
    -- Owner can assign Co-Owner, Admin, Mod
    NULL;
  ELSIF v_caller_role = 'Co-Owner' THEN
    IF v_standard_role NOT IN ('Admin', 'Mod') THEN
      RAISE EXCEPTION 'Co-Owners can only assign Admin or Mod roles.';
    END IF;
  ELSIF v_caller_role = 'Admin' THEN
    IF v_standard_role NOT IN ('Mod') THEN
      RAISE EXCEPTION 'Admins can only assign Mod role.';
    END IF;
  ELSE
    RAISE EXCEPTION 'Insufficient permissions to assign room roles.';
  END IF;

  -- Perform Role Update in room_members table
  UPDATE public.room_members
  SET role = v_standard_role, updated_at = NOW()
  WHERE room_id = v_room_id AND user_id = p_target_user_id;

  IF NOT FOUND THEN
    SELECT username INTO v_target_name FROM public.profiles WHERE id = p_target_user_id;
    INSERT INTO public.room_members (room_id, user_id, role, joined_at, updated_at)
    VALUES (v_room_id, p_target_user_id, v_standard_role, NOW(), NOW());
  ELSE
    SELECT username INTO v_target_name FROM public.profiles WHERE id = p_target_user_id;
  END IF;

  -- Update arrays on public.rooms table
  IF v_standard_role = 'Co-Owner' THEN
    UPDATE public.rooms 
    SET co_owner_ids = array_distinct(array_append(co_owner_ids, p_target_user_id::text)),
        admin_ids = array_remove(admin_ids, p_target_user_id::text),
        host_ids = array_remove(host_ids, p_target_user_id::text)
    WHERE id = v_room_id;
  ELSIF v_standard_role = 'Admin' THEN
    UPDATE public.rooms 
    SET admin_ids = array_distinct(array_append(admin_ids, p_target_user_id::text)),
        co_owner_ids = array_remove(co_owner_ids, p_target_user_id::text),
        host_ids = array_remove(host_ids, p_target_user_id::text)
    WHERE id = v_room_id;
  ELSIF v_standard_role = 'Mod' THEN
    UPDATE public.rooms 
    SET host_ids = array_distinct(array_append(host_ids, p_target_user_id::text)),
        co_owner_ids = array_remove(co_owner_ids, p_target_user_id::text),
        admin_ids = array_remove(admin_ids, p_target_user_id::text)
    WHERE id = v_room_id;
  END IF;

  -- Log Activity Event
  INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
  VALUES (v_room_id, 'system', p_target_user_id, COALESCE(v_target_name, 'Member'), COALESCE(v_target_name, 'Member') || ' promoted to ' || v_standard_role);

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'target_user_id', p_target_user_id,
    'new_role', v_standard_role
  );
END;
$$;

-- 4. Single Canonical demote_room_member_role RPC
CREATE OR REPLACE FUNCTION public.demote_room_member_role(
  p_room_id text,
  p_target_user_id uuid,
  p_role_to_remove text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_canonical_owner uuid;
  v_target_name text;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN
    v_room_id := p_room_id;
  END IF;

  SELECT COALESCE(owner_user_id, room_owner, host_id) INTO v_canonical_owner 
  FROM public.rooms WHERE id = v_room_id;

  IF p_target_user_id = v_canonical_owner THEN
    RAISE EXCEPTION 'OWNER_PROTECTED: Permanent Room Owner role cannot be demoted.';
  END IF;

  SELECT username INTO v_target_name FROM public.profiles WHERE id = p_target_user_id;

  -- Reset Role to Audience
  UPDATE public.room_members
  SET role = 'Audience', updated_at = NOW()
  WHERE room_id = v_room_id AND user_id = p_target_user_id;

  UPDATE public.rooms 
  SET co_owner_ids = array_remove(co_owner_ids, p_target_user_id::text),
      admin_ids = array_remove(admin_ids, p_target_user_id::text),
      host_ids = array_remove(host_ids, p_target_user_id::text)
  WHERE id = v_room_id;

  INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
  VALUES (v_room_id, 'system', p_target_user_id, COALESCE(v_target_name, 'Member'), COALESCE(v_target_name, 'Member') || ' demoted to Audience');

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'target_user_id', p_target_user_id,
    'new_role', 'Audience'
  );
END;
$$;

-- Migration: 202608060003_smart_default_avatar_system.sql
-- Description: Smart Default Avatar Assignment System at Database Level

CREATE OR REPLACE FUNCTION public.smart_assign_default_avatar()
RETURNS TRIGGER AS $$
DECLARE
    v_gender text;
    v_random_num int;
    v_chosen_folder text;
    v_avatar_path text;
BEGIN
    -- Only assign a default avatar if the user has NO custom profile image
    -- (i.e. avatar_url is null, empty, or an old placeholder like dicebear)
    IF NEW.avatar_url IS NULL 
       OR TRIM(NEW.avatar_url) = '' 
       OR NEW.avatar_url LIKE '%dicebear%' THEN

        v_gender := LOWER(TRIM(COALESCE(NEW.gender, '')));
        v_random_num := floor(random() * 10 + 1)::int; -- Generates integer 1..10

        IF v_gender IN ('male', 'm', 'boy', 'man') THEN
            v_avatar_path := 'assets/creaniaa_avtar_auto/male/' || v_random_num || '.jpeg';
        ELSIF v_gender IN ('female', 'f', 'girl', 'woman') THEN
            v_avatar_path := 'assets/creaniaa_avtar_auto/female/' || v_random_num || '.jpeg';
        ELSE
            -- Neutral / Unknown / Prefer not to say
            -- Randomly pick between male and female folders
            IF random() < 0.5 THEN
                v_chosen_folder := 'male';
            ELSE
                v_chosen_folder := 'female';
            END IF;
            v_avatar_path := 'assets/creaniaa_avtar_auto/' || v_chosen_folder || '/' || v_random_num || '.jpeg';
        END IF;

        -- Permanently set the assigned avatar fields
        NEW.avatar_url := v_avatar_path;
        NEW.avatar := v_avatar_path;
        NEW.profile_photo := v_avatar_path;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Single Consolidated Atomic RPC for Room Entry
CREATE OR REPLACE FUNCTION public.join_room_fast_v2(
  p_room_id text,
  p_provided_password text DEFAULT NULL,
  p_user_id text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_id uuid;
  v_room_id text;
  v_room RECORD;
  v_room_json jsonb;
  v_host_id uuid;
  v_room_owner_id uuid;
  v_host_profile RECORD;
  v_caller_profile RECORD;
  v_is_banned boolean := false;
  v_kick_active boolean := false;
  v_role text := 'Listener';
  v_is_owner boolean := false;
  v_is_co_owner boolean := false;
  v_is_admin boolean := false;
  v_seats jsonb;
  v_custom_perms jsonb;
  v_who_can_join text;
  v_room_pass text;
  v_member_count int := 0;
BEGIN
  -- Resolve Caller UUID (supports auth.uid() or explicit p_user_id fallback)
  IF p_user_id IS NOT NULL AND length(trim(p_user_id)) > 0 THEN
    BEGIN
      v_caller_id := p_user_id::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_caller_id := auth.uid();
    END;
  ELSE
    v_caller_id := auth.uid();
  END IF;

  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- 1. Atomic Room Resolution & Room Details Fetch
  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN
    v_room_id := p_room_id;
  END IF;

  SELECT * INTO v_room FROM public.rooms WHERE id = v_room_id;
  IF v_room.id IS NULL THEN
    RETURN jsonb_build_object(
      'join_allowed', false,
      'reason', 'Room not found.'
    );
  END IF;

  -- Convert room record to jsonb to prevent runtime "record has no field" errors
  v_room_json := to_jsonb(v_room);
  
  BEGIN
    v_host_id := (v_room_json->>'host_id')::uuid;
  EXCEPTION WHEN OTHERS THEN
    v_host_id := NULL;
  END;

  BEGIN
    v_room_owner_id := (v_room_json->>'room_owner')::uuid;
  EXCEPTION WHEN OTHERS THEN
    v_room_owner_id := NULL;
  END;

  -- 2. Fetch Host & Caller Profiles
  IF v_host_id IS NOT NULL THEN
    BEGIN
      SELECT id, username, COALESCE(avatar_url, profile_photo, '') as avatar, gender, level, vip_level INTO v_host_profile 
      FROM public.profiles WHERE id = v_host_id;
    EXCEPTION WHEN OTHERS THEN
      v_host_profile := NULL;
    END;
  END IF;

  BEGIN
    SELECT id, username, COALESCE(avatar_url, profile_photo, '') as avatar, gender, level, vip_level INTO v_caller_profile 
    FROM public.profiles WHERE id = v_caller_id;
  EXCEPTION WHEN OTHERS THEN
    v_caller_profile := NULL;
  END;

  -- 3. Resolve User Role in Room
  IF (v_host_id IS NOT NULL AND v_host_id = v_caller_id) OR (v_room_owner_id IS NOT NULL AND v_room_owner_id = v_caller_id) THEN
    v_role := 'Owner';
    v_is_owner := true;
  ELSE
    SELECT role INTO v_role 
    FROM public.room_members WHERE room_id = v_room_id AND user_id = v_caller_id;
    
    IF v_role IS NULL OR v_role = 'Audience' THEN 
      v_role := 'Listener'; 
    END IF;

    IF v_role IN ('Co-Owner', 'Co Owner') THEN v_is_co_owner := true; END IF;
    IF v_role = 'Admin' THEN v_is_admin := true; END IF;
  END IF;

  -- 4. Check Ban Status (Permanent Ban Check)
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'room_admin_activity_logs' AND table_schema = 'public'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM public.room_admin_activity_logs 
      WHERE room_id = v_room_id AND target_user_id = v_caller_id AND action_type = 'BAN'
    ) THEN
      IF NOT v_is_owner THEN
        RETURN jsonb_build_object(
          'join_allowed', false,
          'reason', 'Permanently banned from this room.'
        );
      END IF;
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'room_bans' AND table_schema = 'public'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM public.room_bans 
      WHERE room_id = v_room_id AND user_id = v_caller_id AND (expires_at IS NULL OR expires_at > now())
    ) THEN
      IF NOT v_is_owner THEN
        RETURN jsonb_build_object(
          'join_allowed', false,
          'reason', 'Banned from this room.'
        );
      END IF;
    END IF;
  END IF;

  -- 5. Check Active Kick Status (Temporary Kick)
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'room_admin_activity_logs' AND table_schema = 'public'
  ) THEN
    SELECT EXISTS (
      SELECT 1 FROM public.room_admin_activity_logs 
      WHERE room_id = v_room_id AND target_user_id = v_caller_id AND action_type = 'KICK'
        AND created_at > (now() - interval '10 minutes')
    ) INTO v_kick_active;

    IF v_kick_active AND NOT v_is_owner AND NOT v_is_co_owner THEN
      RETURN jsonb_build_object(
        'join_allowed', false,
        'reason', 'You were recently removed from this room. Please wait a few minutes.'
      );
    END IF;
  END IF;

  -- 6. Evaluate Room Entry Permissions (Password, Followers Only, VIP Level, User Level, Community)
  v_who_can_join := LOWER(COALESCE(v_room_json->>'entry_permission', v_room_json->>'visibility', v_room_json->>'who_can_join', 'everyone'));
  
  -- Resolve specific custom password created by the room owner in public.rooms or public.room_settings
  v_room_pass := COALESCE(
    NULLIF(trim(v_room_json->>'room_password'), ''),
    (SELECT NULLIF(trim(room_password), '') FROM public.room_settings WHERE room_id = v_room_id LIMIT 1)
  );
  
  IF NOT v_is_owner AND NOT v_is_co_owner AND NOT v_is_admin THEN
    -- A. Unique Room Password Verification
    IF v_who_can_join LIKE '%password%' OR (v_room_pass IS NOT NULL AND length(v_room_pass) > 0) THEN
      IF p_provided_password IS NULL OR length(trim(p_provided_password)) = 0 THEN
        RETURN jsonb_build_object(
          'join_allowed', false,
          'reason', 'PASSWORD_REQUIRED',
          'password_required', true
        );
      ELSIF v_room_pass IS NOT NULL AND length(v_room_pass) > 0 AND trim(p_provided_password) != trim(v_room_pass) THEN
        RETURN jsonb_build_object(
          'join_allowed', false,
          'reason', 'Incorrect room password. Access denied.',
          'invalid_password', true
        );
      END IF;
    END IF;

    -- B1. Followers Only Mode (Caller must follow Room Host/Owner)
    IF (v_who_can_join LIKE '%followers_only%' OR v_who_can_join LIKE '%followers only%' OR v_who_can_join LIKE '%owner followers%') THEN
      IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'connections' AND table_schema = 'public'
      ) THEN
        IF v_host_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM public.connections 
          WHERE follower_id = v_caller_id AND following_id = v_host_id
        ) THEN
          RETURN jsonb_build_object(
            'join_allowed', false,
            'reason', 'This arena is restricted to Owner Followers only.',
            'follower_required', true
          );
        END IF;
      END IF;
    END IF;

    -- B2. Owner Following Mode (Room Owner must follow Caller)
    IF (v_who_can_join LIKE '%following_only%' OR v_who_can_join LIKE '%following only%' OR v_who_can_join LIKE '%owner following%') THEN
      IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'connections' AND table_schema = 'public'
      ) THEN
        IF v_host_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM public.connections 
          WHERE follower_id = v_host_id AND following_id = v_caller_id
        ) THEN
          RETURN jsonb_build_object(
            'join_allowed', false,
            'reason', 'This arena is restricted to users followed by the Room Owner.',
            'following_required', true
          );
        END IF;
      END IF;
    END IF;

    -- C. VIP Level Requirement
    IF v_who_can_join LIKE '%vip%' AND COALESCE(v_caller_profile.vip_level, 1) < COALESCE((v_room_json->>'vip_requirement')::int, 0) THEN
      RETURN jsonb_build_object(
        'join_allowed', false,
        'reason', format('VIP Level %s required to enter this arena.', COALESCE((v_room_json->>'vip_requirement')::int, 0)),
        'vip_required', true
      );
    END IF;

    -- D. User Level Requirement
    IF v_who_can_join LIKE '%level%' AND COALESCE(v_caller_profile.level, 1) < COALESCE((v_room_json->>'level_requirement')::int, 1) THEN
      RETURN jsonb_build_object(
        'join_allowed', false,
        'reason', format('User Level %s required to enter this arena.', COALESCE((v_room_json->>'level_requirement')::int, 1)),
        'level_required', true
      );
    END IF;
  END IF;

  -- 7. Fetch Active Seat Map Layout & Occupants
  SELECT jsonb_agg(s) INTO v_seats FROM (
    SELECT 
      m.user_id,
      m.role,
      m.is_muted,
      p.username,
      COALESCE(p.avatar_url, p.profile_photo, '') as avatar,
      p.username as display_name
    FROM public.room_members m
    LEFT JOIN public.profiles p ON p.id = m.user_id
    WHERE m.room_id = v_room_id
    LIMIT 10
  ) s;

  -- 8. Get Realtime Audience Count
  SELECT COUNT(*) INTO v_member_count FROM public.room_members WHERE room_id = v_room_id;
  IF v_member_count = 0 THEN v_member_count := 1; END IF;

  -- 9. Upsert Member Join Session
  INSERT INTO public.room_members (room_id, user_id, role, joined_at)
  VALUES (v_room_id, v_caller_id, v_role, now())
  ON CONFLICT (room_id, user_id) DO UPDATE 
  SET role = EXCLUDED.role, joined_at = now();

  -- 10. Construct Single Consolidated Response
  RETURN jsonb_build_object(
    'join_allowed', true,
    'reason', 'Allowed',
    'room_info', jsonb_build_object(
      'id', v_room_json->>'id',
      'name', COALESCE(v_room_json->>'name', 'Arena'),
      'username', COALESCE(v_room_json->>'username', ''),
      'category', COALESCE(v_room_json->>'category', 'General'),
      'language', COALESCE(v_room_json->>'language', 'English'),
      'host_id', v_host_id,
      'room_owner', v_room_owner_id,
      'avatar', COALESCE(v_room_json->>'avatar', ''),
      'banner', COALESCE(v_room_json->>'banner', ''),
      'room_cover_url', COALESCE(v_room_json->>'room_cover_url', ''),
      'room_level', COALESCE((v_room_json->>'room_level')::int, 1),
      'is_emergency_mode', COALESCE((v_room_json->>'is_emergency_mode')::boolean, false),
      'security_score', COALESCE((v_room_json->>'security_score')::numeric, 5.00),
      'health_score', COALESCE((v_room_json->>'health_score')::int, 100),
      'governance_level', COALESCE((v_room_json->>'governance_level')::int, 1)
    ),
    'host_profile', jsonb_build_object(
      'id', COALESCE(v_host_profile.id, v_host_id),
      'username', COALESCE(v_host_profile.username, 'Creania Host'),
      'display_name', COALESCE(v_host_profile.username, 'Creania Host'),
      'avatar', COALESCE(v_host_profile.avatar, ''),
      'gender', COALESCE(v_host_profile.gender, 'other'),
      'level', COALESCE(v_host_profile.level, 1),
      'vip_level', COALESCE(v_host_profile.vip_level, 0)
    ),
    'caller_permissions', jsonb_build_object(
      'role', v_role,
      'is_owner', v_is_owner,
      'is_co_owner', v_is_co_owner,
      'is_admin', v_is_admin,
      'custom_permissions', COALESCE(v_custom_perms, '{}'::jsonb)
    ),
    'seat_map', COALESCE(v_seats, '[]'::jsonb),
    'member_count', v_member_count,
    'server_timestamp', now()
  );
END;
$$;

-- 5. Enhanced add_room_vp with 20 Anti-Fake Rules & Trust Score Validation
create or replace function public.add_room_vp(
  p_room_id text,
  p_vp integer,
  p_source text,
  p_user_id uuid default null,
  p_device_fingerprint text default null
)
returns jsonb as $$
declare
  v_user_id uuid := coalesce(p_user_id, auth.uid());
  v_user_trust_score integer := 80;
  v_is_banned_device boolean := false;
  v_owner_id uuid;
  v_owner_device text;
  v_old_xp integer := 0;
  v_new_xp integer := 0;
  v_old_level integer := 1;
  v_new_level integer := 1;
  v_did_upgrade boolean := false;
  v_effective_vp integer := p_vp;
  v_last_interaction timestamptz;
  v_is_idle boolean := false;
begin
  if p_vp <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Invalid VP amount');
  end if;

  -- Get room owner details
  select host_id into v_owner_id from public.rooms where id = p_room_id;
  
  -- Rule 3 & 4: Self-Gifting / Same Account / Same Device Protection
  if v_user_id is not null and v_owner_id is not null and v_user_id = v_owner_id and p_source = 'self_gift' then
    perform public.update_user_trust_score(v_user_id, -30, 'self_gifting_attempt');
    return jsonb_build_object('success', false, 'reason', 'Self-support gifting blocked', 'added_vp', 0);
  end if;

  -- Validate user trust score & banned device
  if v_user_id is not null then
    select trust_score, is_banned_device into v_user_trust_score, v_is_banned_device 
    from public.profiles where id = v_user_id;

    -- Rule 17: Banned Device Guard
    if v_is_banned_device then
      return jsonb_build_object('success', false, 'reason', 'Banned device cannot earn VP', 'added_vp', 0);
    end if;

    -- Rule 20: Hidden Trust Score Guard (Score < 30 = 0 VP)
    if v_user_trust_score < 30 then
      return jsonb_build_object('success', false, 'reason', 'Low trust score (<30). VP disabled', 'added_vp', 0);
    elsif v_user_trust_score < 70 then
      -- 50% Slow mode for medium risk
      v_effective_vp := (p_vp * 0.5)::integer;
    end if;
  end if;

  -- Rule 2: 10-Minute Idle Freeze Check
  select last_interaction_at into v_last_interaction 
  from public.room_activity_tracker where room_id = p_room_id;

  if v_last_interaction is not null and (now() - v_last_interaction) > interval '10 minutes' then
    return jsonb_build_object('success', false, 'reason', 'Room idle for >10 minutes. VP paused', 'added_vp', 0);
  end if;

  -- Ensure level progress entry exists
  insert into public.room_level_progress (room_id, current_level, current_xp)
  values (p_room_id, 1, 0)
  on conflict (room_id) do nothing;

  select current_xp, current_level into v_old_xp, v_old_level
  from public.room_level_progress
  where room_id = p_room_id;

  v_new_xp := v_old_xp + v_effective_vp;

  -- Determine level based on room_level_matrix
  select level into v_new_level
  from public.room_level_matrix
  where required_vp <= v_new_xp
  order by level desc
  limit 1;

  if v_new_level is null then v_new_level := 1; end if;
  if v_new_level > v_old_level then v_did_upgrade := true; end if;

  update public.room_level_progress
  set current_xp = v_new_xp,
      current_level = v_new_level
  where room_id = p_room_id;

  update public.rooms
  set room_xp = v_new_xp,
      level = v_new_level,
      today_room_xp = today_room_xp + v_effective_vp
  where id = p_room_id;

  -- Unlock Perks & Grand Prizes on upgrade
  if v_owner_id is not null then
    insert into public.user_unlocked_perks (user_id, perk_type, perk_id, source_level, is_permanent)
    values (v_owner_id, 'avatar_frame', 'room_level_frame_' || v_new_level, v_new_level, true)
    on conflict (user_id, perk_type, perk_id) do nothing;

    if v_did_upgrade then
      if v_new_level = 5 then
        update public.profiles
        set gold_coins = gold_coins + 2000,
            vip_level = greatest(vip_level, 2),
            vip_expires_at = case when vip_expires_at is null or vip_expires_at < now() then now() + interval '60 days' else vip_expires_at + interval '60 days' end
        where id = v_owner_id;
      elsif v_new_level = 6 then
        update public.profiles
        set gold_coins = gold_coins + 5000,
            vip_level = greatest(vip_level, 2),
            vip_expires_at = case when vip_expires_at is null or vip_expires_at < now() then now() + interval '180 days' else vip_expires_at + interval '180 days' end
        where id = v_owner_id;
      elsif v_new_level = 7 then
        update public.profiles
        set gold_coins = gold_coins + 12000,
            vip_level = greatest(vip_level, 3),
            vip_expires_at = case when vip_expires_at is null or vip_expires_at < now() then now() + interval '365 days' else vip_expires_at + interval '365 days' end
        where id = v_owner_id;
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'success', true,
    'room_id', p_room_id,
    'added_vp', v_effective_vp,
    'new_total_vp', v_new_xp,
    'old_level', v_old_level,
    'new_level', v_new_level,
    'did_upgrade', v_did_upgrade,
    'trust_score', v_user_trust_score
  );
end;
$$ language plpgsql security definer;

-- B. Claim Treasure Box Reward RPC
create or replace function public.claim_treasure_box_reward(
  p_box_tier text
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_coins integer := 0;
  v_vp integer := 0;
  v_silver integer := 0;
  v_keys integer := 0;
begin
  if v_user_id is null then
    raise exception 'Unauthenticated user';
  end if;

  case p_box_tier
    when 'normal' then
      v_coins := 50 + (floor(random() * 50))::integer;
      v_silver := 200 + (floor(random() * 200))::integer;
      v_vp := 100 + (floor(random() * 100))::integer;
      v_keys := 1;
    when 'gold' then
      v_coins := 300 + (floor(random() * 300))::integer;
      v_silver := 1000 + (floor(random() * 500))::integer;
      v_vp := 500 + (floor(random() * 500))::integer;
      v_keys := 3;
    when 'room' then
      v_coins := 1000 + (floor(random() * 1000))::integer;
      v_silver := 3000 + (floor(random() * 2000))::integer;
      v_vp := 2000 + (floor(random() * 1000))::integer;
      v_keys := 5;
    when 'legendary' then
      v_coins := 5000 + (floor(random() * 5000))::integer;
      v_silver := 10000 + (floor(random() * 5000))::integer;
      v_vp := 10000 + (floor(random() * 5000))::integer;
      v_keys := 10;
    else
      raise exception 'Invalid chest tier';
  end case;

  update public.profiles
  set gold_coins = gold_coins + v_coins,
      silver_coins = silver_coins + v_silver
  where id = v_user_id;

  return jsonb_build_object(
    'success', true,
    'box_tier', p_box_tier,
    'coins_earned', v_coins,
    'silver_earned', v_silver,
    'vp_earned', v_vp,
    'lucky_keys_earned', v_keys
  );
end;
$$ language plpgsql security definer;

-- 4. Calculate User Trust Score Function
create or replace function public.calculate_user_trust_score(
  p_user_id uuid
)
returns jsonb as $$
declare
  v_score integer := 80;
  v_activity_score integer := 50;
  v_risk_score integer := 0;
  v_is_verified boolean := false;
  v_is_emulator boolean := false;
  v_is_vpn boolean := false;
  v_is_device_banned boolean := false;
  v_account_age_days integer := 0;
  v_linked_accounts_count integer := 0;
  v_multiplier numeric := 1.0;
begin
  if p_user_id is null then
    return jsonb_build_object('trust_score', 0, 'multiplier', 0.0, 'status', 'unauthenticated');
  end if;

  -- Read profile parameters
  select 
    coalesce(extract(day from (now() - p.created_at)), 0)::integer,
    coalesce(uts.trust_score, 80),
    coalesce(uts.activity_score, 50),
    coalesce(uts.risk_score, 0),
    coalesce(uts.is_verified, false),
    coalesce(uts.is_emulator, false),
    coalesce(uts.is_vpn, false),
    coalesce(uts.is_device_banned, false)
  into 
    v_account_age_days, v_score, v_activity_score, v_risk_score,
    v_is_verified, v_is_emulator, v_is_vpn, v_is_device_banned
  from public.profiles p
  left join public.user_trust_scores uts on uts.user_id = p.id
  where p.id = p_user_id;

  -- Adjust trust score dynamically based on trust rules
  -- Verified account bonus (+15)
  if v_is_verified then
    v_score := v_score + 15;
  end if;

  -- Older account bonus (+10 for > 30 days)
  if v_account_age_days >= 30 then
    v_score := v_score + 10;
  end if;

  -- Emulator penalty (-30)
  if v_is_emulator then
    v_score := v_score - 30;
    v_risk_score := v_risk_score + 25;
  end if;

  -- VPN penalty (-20)
  if v_is_vpn then
    v_score := v_score - 20;
    v_risk_score := v_risk_score + 20;
  end if;

  -- Device ban penalty (-100)
  if v_is_device_banned then
    v_score := 0;
    v_risk_score := 100;
  end if;

  -- Clamp score range 0-100
  v_score := greatest(0, least(100, v_score));
  v_risk_score := greatest(0, least(100, v_risk_score));

  -- Determine VP payout multiplier based on score bracket
  if v_is_device_banned or v_score < 20 then
    v_multiplier := 0.0;
  elsif v_score < 50 then
    v_multiplier := 0.5;
  else
    v_multiplier := 1.0;
  end if;

  -- Ensure record exists in user_trust_scores
  insert into public.user_trust_scores (user_id, trust_score, activity_score, risk_score, is_verified, is_emulator, is_vpn, is_device_banned, updated_at)
  values (p_user_id, v_score, v_activity_score, v_risk_score, v_is_verified, v_is_emulator, v_is_vpn, v_is_device_banned, now())
  on conflict (user_id) do update set
    trust_score = excluded.trust_score,
    activity_score = excluded.activity_score,
    risk_score = excluded.risk_score,
    updated_at = now();

  return jsonb_build_object(
    'user_id', p_user_id,
    'trust_score', v_score,
    'activity_score', v_activity_score,
    'risk_score', v_risk_score,
    'multiplier', v_multiplier,
    'is_verified', v_is_verified,
    'is_emulator', v_is_emulator,
    'is_vpn', v_is_vpn,
    'is_device_banned', v_is_device_banned
  );
end;
$$ language plpgsql security definer;

-- 4. RPC to Update User Trust Score
create or replace function public.update_user_trust_score(
  p_user_id uuid,
  p_delta integer,
  p_reason text
)
returns integer as $$
declare
  v_old_score integer := 80;
  v_new_score integer := 80;
begin
  select trust_score into v_old_score from public.profiles where id = p_user_id;
  if v_old_score is null then
    v_old_score := 80;
  end if;

  v_new_score := (v_old_score + p_delta)::integer;
  if v_new_score > 100 then v_new_score := 100; end if;
  if v_new_score < 0 then v_new_score := 0; end if;

  update public.profiles
  set trust_score = v_new_score,
      last_trust_audit_at = now()
  where id = p_user_id;

  insert into public.user_anti_abuse_logs (user_id, event_type, trust_score_delta, details)
  values (p_user_id, 'trust_change', p_delta, jsonb_build_object('reason', p_reason, 'old_score', v_old_score, 'new_score', v_new_score));

  return v_new_score;
end;
$$ language plpgsql security definer;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Overwrite leave_user_active_room to REMOVE Auto Ownership Transfer
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.leave_user_active_room(p_user_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_old_room record;
  v_username text;
begin
  if p_user_id is null then return; end if;

  select username into v_username from public.profiles where id = p_user_id;

  for v_old_room in
    select room_id from public.room_members where user_id = p_user_id
  loop
    update public.room_seats
    set user_id = null, mic_status = 'muted', is_speaking = false
    where room_id = v_old_room.room_id and user_id = p_user_id;

    delete from public.room_members
    where room_id = v_old_room.room_id and user_id = p_user_id;

    insert into public.room_activity_events (room_id, event_type, user_id, username, message)
    values (v_old_room.room_id, 'leave', p_user_id, v_username, coalesce(v_username, 'Someone') || ' left the room');

    -- NO AUTO TRANSFER OF OWNERSHIP.
    -- Ownership remains with original creator permanently.
  end loop;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Update ultra_fast_room_join_rpc to Auto-Restore Permanent Assigned Roles
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.ultra_fast_room_join_rpc(
  p_room_id text,
  p_user_id uuid default null,
  p_password text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_caller_id uuid := coalesce(p_user_id, auth.uid());
  v_room record;
  v_room_json jsonb;
  v_host_id uuid;
  v_room_owner_id uuid;
  v_host_profile record;
  v_caller_profile record;
  v_role text := 'Listener';
  v_is_owner boolean := false;
  v_is_co_owner boolean := false;
  v_is_admin boolean := false;
  v_assigned_role text;
  v_seats jsonb := '[]'::jsonb;
  v_stats jsonb := '{}'::jsonb;
  v_room_id text;
begin
  if v_caller_id is null then
    return jsonb_build_object('join_allowed', false, 'reason', 'UNAUTHENTICATED');
  end if;

  select * into v_room from public.rooms where id = p_room_id or username = p_room_id limit 1;
  if v_room is null then
    return jsonb_build_object('join_allowed', false, 'reason', 'ROOM_NOT_FOUND');
  end if;

  v_room_id := v_room.id;
  v_room_json := to_jsonb(v_room);

  begin v_host_id := (v_room_json->>'host_id')::uuid; exception when others then v_host_id := null; end;
  begin v_room_owner_id := (v_room_json->>'room_owner')::uuid; exception when others then v_room_owner_id := null; end;

  -- 1. Fetch Host & Caller Profiles
  if v_host_id is not null then
    select id, username, coalesce(avatar_url, profile_photo, '') as avatar, gender, level, vip_level 
    into v_host_profile from public.profiles where id = v_host_id;
  end if;

  select id, username, coalesce(avatar_url, profile_photo, '') as avatar, gender, level, vip_level 
  into v_caller_profile from public.profiles where id = v_caller_id;

  -- 2. Resolve User Role in Room (Check Owner -> Assigned Roles -> Arrays -> room_members)
  if (v_host_id is not null and v_host_id = v_caller_id) or (v_room_owner_id is not null and v_room_owner_id = v_caller_id) then
    v_role := 'Owner';
    v_is_owner := true;
  else
    -- Check permanent assigned roles table
    select role into v_assigned_role from public.room_assigned_roles where room_id = v_room_id and user_id = v_caller_id;

    if v_assigned_role is not null then
      v_role := v_assigned_role;
    elsif v_caller_id::text = any(coalesce(v_room.co_owner_ids, '{}')) then
      v_role := 'Co-Owner';
    elsif v_caller_id::text = any(coalesce(v_room.admin_ids, '{}')) then
      v_role := 'Admin';
    elsif v_caller_id::text = any(coalesce(v_room.star_member_ids, '{}')) then
      v_role := 'Star Member';
    else
      select role into v_assigned_role from public.room_members where room_id = v_room_id and user_id = v_caller_id;
      if v_assigned_role is not null then
        v_role := v_assigned_role;
      end if;
    end if;

    if v_role is null or v_role = 'Audience' then 
      v_role := 'Listener'; 
    end if;

    if v_role in ('Co-Owner', 'Co Owner') then v_is_co_owner := true; end if;
    if v_role = 'Admin' then v_is_admin := true; end if;
  end if;

  -- 3. Password Check
  if v_room.entry_permission = 'password' or v_room.visibility = 'password_required' then
    if not (v_is_owner or v_is_co_owner or v_is_admin) then
      if p_password is null or v_room.room_password is distinct from p_password then
        return jsonb_build_object(
          'join_allowed', false,
          'reason', 'PASSWORD_REQUIRED',
          'room_name', v_room.name
        );
      end if;
    end if;
  end if;

  -- 4. Upsert active member with resolved permanent role
  insert into public.room_members (room_id, user_id, role, joined_at, last_heartbeat_at)
  values (v_room_id, v_caller_id, v_role, now(), now())
  on conflict (room_id, user_id) do update 
  set role = v_role, last_heartbeat_at = now();

  -- 5. Fetch seats info
  select jsonb_agg(to_jsonb(s)) into v_seats
  from (
    select seat_index, user_id, mic_status, is_speaking, is_locked, seat_name
    from public.room_seats where room_id = v_room_id order by seat_index asc
  ) s;

  return jsonb_build_object(
    'join_allowed', true,
    'room_id', v_room_id,
    'role', v_role,
    'is_owner', v_is_owner,
    'is_co_owner', v_is_co_owner,
    'is_admin', v_is_admin,
    'host_profile', to_jsonb(v_host_profile),
    'caller_profile', to_jsonb(v_caller_profile),
    'seats', coalesce(v_seats, '[]'::jsonb),
    'room', v_room_json
  );
end;
$$;

-- Presence Grace Period Cleanup Function
CREATE OR REPLACE FUNCTION public.process_presence_grace_period_and_cleanup()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rec record;
  v_username text;
BEGIN
  FOR v_rec IN 
    SELECT room_id, user_id, role 
    FROM public.room_members 
    WHERE is_reconnecting = TRUE 
      AND last_heartbeat_at < (now() - interval '30 seconds')
  LOOP
    SELECT username INTO v_username FROM public.profiles WHERE id = v_rec.user_id;

    -- A. Free seat
    UPDATE public.room_seats
    SET user_id = NULL,
        mic_status = 'muted',
        is_speaking = FALSE,
        is_reconnecting = FALSE,
        session_id = NULL
    WHERE room_id = v_rec.room_id AND user_id = v_rec.user_id;

    -- B. Delete requests
    DELETE FROM public.room_requests
    WHERE room_id = v_rec.room_id AND user_id = v_rec.user_id;

    -- C. Delete temporary presence record
    DELETE FROM public.room_members 
    WHERE room_id = v_rec.room_id AND user_id = v_rec.user_id;

    DELETE FROM public.room_member_heartbeats
    WHERE room_id = v_rec.room_id AND user_id = v_rec.user_id;

    -- D. Broadcast leave event
    INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
    VALUES (v_rec.room_id, 'leave', v_rec.user_id, v_username, COALESCE(v_username, 'Someone') || ' left the room');
  END LOOP;
END;
$$;

-- 3. Idempotent Signup Reward Claim RPC
CREATE OR REPLACE FUNCTION public.claim_signup_reward_rpc(
  p_user_id uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_id uuid := COALESCE(p_user_id, auth.uid());
  v_already_claimed boolean := false;
  v_reward_coins integer := 50;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT signup_reward_claimed INTO v_already_claimed
  FROM public.profiles WHERE id = v_caller_id;

  IF v_already_claimed = true THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_claimed', true,
      'coins_added', 0,
      'message', 'Signup reward already claimed'
    );
  END IF;

  -- Add to Coin Wallet
  INSERT INTO public.wallets (id, gold_coins, coins_balance, silver_coins, withdrawable_balance)
  VALUES (v_caller_id, v_reward_coins, v_reward_coins, 0, 0.0)
  ON CONFLICT (id) DO UPDATE
  SET gold_coins = COALESCE(public.wallets.gold_coins, 0) + v_reward_coins,
      coins_balance = COALESCE(public.wallets.coins_balance, 0) + v_reward_coins;

  -- Ledger Log
  INSERT INTO public.wallet_transactions (wallet_id, amount, currency, type, status, details)
  VALUES (v_caller_id, v_reward_coins, 'Coins', 'Reward', 'Completed', 'First Account Creation Reward');

  -- Mark claimed
  UPDATE public.profiles
  SET signup_reward_claimed = true
  WHERE id = v_caller_id;

  RETURN jsonb_build_object(
    'success', true,
    'already_claimed', false,
    'coins_added', v_reward_coins,
    'message', 'Successfully credited signup reward to Coin Wallet'
  );
END;
$$;

-- Migration: 202608100002_room_share_and_invitations.sql
-- Description: RPC procedures for StarMaker style in-app room invitations, rate limiting, and room status verification

-- 1. Function to validate and send a room invitation to a receiver user
CREATE OR REPLACE FUNCTION send_room_invitation(
    p_room_id TEXT,
    p_receiver_id UUID,
    p_room_title TEXT DEFAULT 'Voice Room',
    p_host_name TEXT DEFAULT 'Host',
    p_room_cover TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sender_id UUID;
    v_room_exists BOOLEAN;
    v_receiver_exists BOOLEAN;
    v_recent_invites_count INT;
    v_message_id UUID;
    v_now TIMESTAMPTZ := NOW();
    v_encrypted_content TEXT;
    v_payload JSONB;
BEGIN
    v_sender_id := auth.uid();
    
    -- Check sender auth
    IF v_sender_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized sender');
    END IF;

    -- Cannot send invitation to self
    IF v_sender_id = p_receiver_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot send invitation to yourself');
    END IF;

    -- Check if target receiver exists
    SELECT EXISTS(
        SELECT 1 FROM profiles WHERE id = p_receiver_id
    ) INTO v_receiver_exists;

    IF NOT v_receiver_exists THEN
        RETURN jsonb_build_object('success', false, 'error', 'Recipient user does not exist');
    END IF;

    -- Check if room exists and is active
    SELECT EXISTS(
        SELECT 1 FROM rooms 
        WHERE (id::text = p_room_id OR sid = p_room_id)
          AND is_active = true
    ) INTO v_room_exists;

    IF NOT v_room_exists THEN
        -- Fallback: check voice_rooms table if rooms table wasn't matched
        SELECT EXISTS(
            SELECT 1 FROM rooms WHERE id::text = p_room_id
        ) INTO v_room_exists;
    END IF;

    -- Anti-spam: Rate limit - max 10 room invitations per minute per sender
    SELECT COUNT(*) INTO v_recent_invites_count
    FROM messages
    WHERE sender_id = v_sender_id
      AND media_type = 'roomInvite'
      AND created_at > (v_now - INTERVAL '1 minute');

    IF v_recent_invites_count >= 15 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Sending invitations too fast. Please wait a moment.');
    END IF;

    v_message_id := gen_random_uuid();
    v_encrypted_content := '🎙️ Room Invite: ' || COALESCE(p_room_title, 'Voice Room');

    -- Insert invitation message into canonical messages table
    INSERT INTO messages (
        id,
        sender_id,
        receiver_id,
        encrypted_content,
        is_private,
        message_status,
        media_type,
        location_name,
        contact_name,
        contact_phone,
        media_url,
        created_at
    ) VALUES (
        v_message_id,
        v_sender_id,
        p_receiver_id,
        v_encrypted_content,
        true,
        'sent',
        'roomInvite',
        p_room_title,
        p_host_name,
        p_room_id,
        p_room_cover,
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'message_id', v_message_id,
        'room_id', p_room_id,
        'receiver_id', p_receiver_id,
        'timestamp', v_now
    );
END;
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

-- 202608110008_user_block_unfollow_and_advanced_reports.sql
-- User Block side-effects (auto-unfollow/unfriend) and Advanced Reports with file/chat attachments

-- 1. Enhanced RPC: Block User with Automatic Social Connection Removal (Unfollow / Unfriend)
CREATE OR REPLACE FUNCTION public.block_user(p_blocked_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_blocker_id uuid := auth.uid();
BEGIN
  IF v_blocker_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  IF v_blocker_id = p_blocked_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot block yourself');
  END IF;

  -- 1. Insert into user_blocks table
  INSERT INTO public.user_blocks (blocker_id, blocked_id)
  VALUES (v_blocker_id, p_blocked_id)
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

  -- 2. Remove mutual follow & friend relationships on profiles
  -- Decrement followers/following counts if greater than 0
  UPDATE public.profiles
  SET 
    following_count = GREATEST(0, COALESCE(following_count, 0) - 1),
    friends_count = GREATEST(0, COALESCE(friends_count, 0) - 1)
  WHERE id = v_blocker_id;

  UPDATE public.profiles
  SET 
    followers_count = GREATEST(0, COALESCE(followers_count, 0) - 1),
    friends_count = GREATEST(0, COALESCE(friends_count, 0) - 1)
  WHERE id = p_blocked_id;

  -- 3. If community_members table exists, cleanup any direct follows
  BEGIN
    DELETE FROM public.user_followers
    WHERE (follower_id = v_blocker_id AND following_id = p_blocked_id)
       OR (follower_id = p_blocked_id AND following_id = v_blocker_id);
  EXCEPTION WHEN undefined_table THEN
    -- Ignore if table does not exist
  END;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- RPC: Get Blocked Users
CREATE OR REPLACE FUNCTION public.get_blocked_users()
RETURNS TABLE (
  blocked_id uuid,
  username text,
  display_name text,
  avatar_url text,
  blocked_at timestamp with time zone
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ub.blocked_id,
    p.username,
    COALESCE(p.profession, p.username) as display_name,
    COALESCE(p.avatar_url, p.profile_photo) as avatar_url,
    ub.created_at as blocked_at
  FROM public.user_blocks ub
  JOIN public.profiles p ON ub.blocked_id = p.id
  WHERE ub.blocker_id = auth.uid()
  ORDER BY ub.created_at DESC;
END;
$$;

-- 6. Two-Factor Authentication (2FA) RPCs
CREATE OR REPLACE FUNCTION public.enable_2fa(p_pin text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  IF length(p_pin) < 4 OR length(p_pin) > 6 THEN
    RETURN jsonb_build_object('success', false, 'error', 'PIN must be 4 to 6 digits');
  END IF;

  UPDATE public.profiles
  SET two_factor_enabled = true,
      two_factor_secret = crypt(p_pin, gen_salt('bf')),
      updated_at = timezone('utc'::text, now())
  WHERE id = v_user_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.disable_2fa(p_pin text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_stored_secret text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  SELECT two_factor_secret INTO v_stored_secret
  FROM public.profiles
  WHERE id = v_user_id;

  IF v_stored_secret IS NULL OR crypt(p_pin, v_stored_secret) != v_stored_secret THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid Security PIN');
  END IF;

  UPDATE public.profiles
  SET two_factor_enabled = false,
      two_factor_secret = NULL,
      updated_at = timezone('utc'::text, now())
  WHERE id = v_user_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.verify_2fa(p_pin text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_stored_secret text;
  v_enabled boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  SELECT two_factor_enabled, two_factor_secret 
  INTO v_enabled, v_stored_secret
  FROM public.profiles
  WHERE id = v_user_id;

  IF NOT COALESCE(v_enabled, false) THEN
    RETURN jsonb_build_object('success', true, 'required', false);
  END IF;

  IF v_stored_secret IS NOT NULL AND crypt(p_pin, v_stored_secret) = v_stored_secret THEN
    RETURN jsonb_build_object('success', true, 'required', true);
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Incorrect Security PIN');
  END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 1: Get 2FA Status
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_2fa_status(p_user_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := COALESCE(p_user_id, auth.uid());
  v_rec record;
  v_profile_2fa boolean := false;
  v_recovery_count int := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  SELECT * INTO v_rec FROM public.user_security_settings WHERE user_id = v_uid;
  SELECT two_factor_enabled INTO v_profile_2fa FROM public.profiles WHERE id = v_uid;
  SELECT count(*) INTO v_recovery_count FROM public.recovery_codes WHERE user_id = v_uid AND used = false;

  RETURN jsonb_build_object(
    'success', true,
    'two_factor_enabled', COALESCE(v_rec.two_factor_enabled, v_profile_2fa, false),
    'two_factor_method', COALESCE(v_rec.two_factor_method, 'totp'),
    'has_totp_secret', (v_rec.totp_secret_encrypted IS NOT NULL AND length(v_rec.totp_secret_encrypted) > 0),
    'recovery_codes_remaining', v_recovery_count,
    'last_verified_at', v_rec.last_verified_at
  );
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 2: Generate TOTP Setup Secret
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_totp_setup_secret(p_user_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := COALESCE(p_user_id, auth.uid());
  v_chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  v_secret text := '';
  v_i int;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  -- Generate 16-character random Base32 string
  FOR v_i IN 1..16 LOOP
    v_secret := v_secret || substr(v_chars, floor(random() * 32 + 1)::int, 1);
  END LOOP;

  -- Ensure user_security_settings row exists
  INSERT INTO public.user_security_settings (user_id, two_factor_enabled, totp_secret_encrypted, updated_at)
  VALUES (v_uid, false, v_secret, timezone('utc'::text, now()))
  ON CONFLICT (user_id) DO UPDATE
  SET totp_secret_encrypted = EXCLUDED.totp_secret_encrypted,
      updated_at = timezone('utc'::text, now());

  RETURN jsonb_build_object(
    'success', true,
    'secret', v_secret
  );
END;
$$;

-- Migration: 202608110011_2fa_selectable_methods.sql
-- Description: Supports method-selectable 2FA setup (TOTP, Server Key, or Recovery Code).

-- Update verify_and_enable_2fa RPC to support optional TOTP secret and method parameter
CREATE OR REPLACE FUNCTION public.verify_and_enable_2fa(
  p_totp_secret text DEFAULT NULL,
  p_recovery_code_hashes text[] DEFAULT NULL,
  p_user_id uuid DEFAULT NULL,
  p_method text DEFAULT 'totp'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := COALESCE(p_user_id, auth.uid());
  v_hash text;
  v_method text := COALESCE(p_method, 'totp');
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  -- Enable 2FA in user_security_settings
  INSERT INTO public.user_security_settings (user_id, two_factor_enabled, two_factor_method, totp_secret_encrypted, last_verified_at, updated_at)
  VALUES (v_uid, true, v_method, p_totp_secret, timezone('utc'::text, now()), timezone('utc'::text, now()))
  ON CONFLICT (user_id) DO UPDATE
  SET two_factor_enabled = true,
      two_factor_method = v_method,
      totp_secret_encrypted = COALESCE(EXCLUDED.totp_secret_encrypted, user_security_settings.totp_secret_encrypted),
      last_verified_at = timezone('utc'::text, now()),
      updated_at = timezone('utc'::text, now());

  -- Update profiles table
  UPDATE public.profiles
  SET two_factor_enabled = true,
      updated_at = timezone('utc'::text, now())
  WHERE id = v_uid;

  -- Insert recovery code hashes if provided
  IF p_recovery_code_hashes IS NOT NULL AND array_length(p_recovery_code_hashes, 1) > 0 THEN
    DELETE FROM public.recovery_codes WHERE user_id = v_uid;
    FOREACH v_hash IN ARRAY p_recovery_code_hashes LOOP
      INSERT INTO public.recovery_codes (user_id, code_hash, used)
      VALUES (v_uid, v_hash, false);
    END LOOP;
  END IF;

  INSERT INTO public.security_events (user_id, event_type, metadata)
  VALUES (v_uid, '2FA_ENABLED', jsonb_build_object('method', v_method));

  RETURN jsonb_build_object('success', true, 'method', v_method);
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 4: Check Rate Limit for 2FA Attempts
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_2fa_rate_limit(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_failed_count int;
  v_lockout_until timestamptz;
BEGIN
  -- Count failed attempts in the last 15 minutes
  SELECT count(*) INTO v_failed_count
  FROM public.two_factor_attempts
  WHERE user_id = p_user_id
    AND success = false
    AND created_at > (timezone('utc'::text, now()) - interval '15 minutes');

  IF v_failed_count >= 5 THEN
    -- Get time of 5th recent failure
    SELECT (created_at + interval '15 minutes') INTO v_lockout_until
    FROM public.two_factor_attempts
    WHERE user_id = p_user_id AND success = false
    ORDER BY created_at DESC
    LIMIT 1 OFFSET 4;

    RETURN jsonb_build_object(
      'allowed', false,
      'error', 'Too many failed verification attempts. Please wait before trying again.',
      'lockout_until', v_lockout_until,
      'failed_count', v_failed_count
    );
  END IF;

  RETURN jsonb_build_object('allowed', true, 'failed_count', v_failed_count);
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 5: Record 2FA Attempt
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_2fa_attempt(
  p_user_id uuid,
  p_action text,
  p_success boolean,
  p_device_id text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.two_factor_attempts (user_id, action, success, device_id)
  VALUES (p_user_id, p_action, p_success, p_device_id);
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 6: Verify Recovery Code Login
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.verify_recovery_code_login(
  p_user_id uuid,
  p_code_hash text,
  p_device_id text DEFAULT NULL,
  p_device_name text DEFAULT NULL,
  p_trust_device boolean DEFAULT false,
  p_device_token_hash text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_code_row record;
  v_rate_check jsonb;
  v_remaining_count int;
  v_expires_at timestamptz;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User ID is required');
  END IF;

  -- Check rate limiting
  v_rate_check := public.check_2fa_rate_limit(p_user_id);
  IF (v_rate_check->>'allowed')::boolean = false THEN
    RETURN v_rate_check;
  END IF;

  -- Find matching unused recovery code hash
  SELECT * INTO v_code_row
  FROM public.recovery_codes
  WHERE user_id = p_user_id
    AND code_hash = p_code_hash
    AND used = false;

  IF v_code_row.id IS NULL THEN
    PERFORM public.record_2fa_attempt(p_user_id, 'recovery_code_verify', false, p_device_id);
    INSERT INTO public.security_events (user_id, event_type, metadata)
    VALUES (p_user_id, '2FA_LOGIN_FAILED', jsonb_build_object('reason', 'invalid_recovery_code', 'device_id', p_device_id));

    RETURN jsonb_build_object('success', false, 'error', 'Invalid verification code. Please try again.');
  END IF;

  -- Mark recovery code as used
  UPDATE public.recovery_codes
  SET used = true,
      used_at = timezone('utc'::text, now())
  WHERE id = v_code_row.id;

  -- Count remaining
  SELECT count(*) INTO v_remaining_count
  FROM public.recovery_codes
  WHERE user_id = p_user_id AND used = false;

  -- Record attempt success & update last verified
  PERFORM public.record_2fa_attempt(p_user_id, 'recovery_code_verify', true, p_device_id);

  UPDATE public.user_security_settings
  SET last_verified_at = timezone('utc'::text, now()),
      updated_at = timezone('utc'::text, now())
  WHERE user_id = p_user_id;

  -- Handle Trust Device if requested
  IF p_trust_device = true AND p_device_token_hash IS NOT NULL AND length(p_device_token_hash) > 0 THEN
    v_expires_at := timezone('utc'::text, now()) + interval '30 days';

    INSERT INTO public.trusted_devices (user_id, device_id, device_name, token_hash, expires_at)
    VALUES (p_user_id, COALESCE(p_device_id, 'unknown_device'), COALESCE(p_device_name, 'Trusted Device'), p_device_token_hash, v_expires_at);

    INSERT INTO public.security_events (user_id, event_type, metadata)
    VALUES (p_user_id, 'TRUSTED_DEVICE_CREATED', jsonb_build_object('device_name', p_device_name, 'expires_at', v_expires_at));
  END IF;

  INSERT INTO public.security_events (user_id, event_type, metadata)
  VALUES (p_user_id, 'RECOVERY_CODE_USED', jsonb_build_object('remaining_codes', v_remaining_count, 'device_id', p_device_id));

  RETURN jsonb_build_object(
    'success', true,
    'recovery_code_used', true,
    'remaining_codes', v_remaining_count
  );
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 7: Record Successful TOTP Verification
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_successful_totp_login(
  p_user_id uuid,
  p_device_id text DEFAULT NULL,
  p_device_name text DEFAULT NULL,
  p_trust_device boolean DEFAULT false,
  p_device_token_hash text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_expires_at timestamptz;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User ID is required');
  END IF;

  PERFORM public.record_2fa_attempt(p_user_id, 'totp_verify', true, p_device_id);

  UPDATE public.user_security_settings
  SET last_verified_at = timezone('utc'::text, now()),
      updated_at = timezone('utc'::text, now())
  WHERE user_id = p_user_id;

  IF p_trust_device = true AND p_device_token_hash IS NOT NULL AND length(p_device_token_hash) > 0 THEN
    v_expires_at := timezone('utc'::text, now()) + interval '30 days';

    INSERT INTO public.trusted_devices (user_id, device_id, device_name, token_hash, expires_at)
    VALUES (p_user_id, COALESCE(p_device_id, 'unknown_device'), COALESCE(p_device_name, 'Trusted Device'), p_device_token_hash, v_expires_at);

    INSERT INTO public.security_events (user_id, event_type, metadata)
    VALUES (p_user_id, 'TRUSTED_DEVICE_CREATED', jsonb_build_object('device_name', p_device_name, 'expires_at', v_expires_at));
  END IF;

  INSERT INTO public.security_events (user_id, event_type, metadata)
  VALUES (p_user_id, '2FA_LOGIN_SUCCESS', jsonb_build_object('method', 'totp', 'device_id', p_device_id));

  RETURN jsonb_build_object('success', true);
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 8: Check Device Trust Status
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_device_trust(
  p_user_id uuid,
  p_token_hash text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_row record;
BEGIN
  IF p_user_id IS NULL OR p_token_hash IS NULL THEN
    RETURN jsonb_build_object('trusted', false);
  END IF;

  SELECT * INTO v_row
  FROM public.trusted_devices
  WHERE user_id = p_user_id
    AND token_hash = p_token_hash
    AND revoked_at IS NULL
    AND expires_at > timezone('utc'::text, now())
  LIMIT 1;

  IF v_row.id IS NOT NULL THEN
    UPDATE public.trusted_devices
    SET last_used_at = timezone('utc'::text, now())
    WHERE id = v_row.id;

    RETURN jsonb_build_object(
      'trusted', true,
      'device_name', v_row.device_name,
      'expires_at', v_row.expires_at
    );
  END IF;

  RETURN jsonb_build_object('trusted', false);
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 9: Disable 2FA
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.disable_2fa_rpc(p_user_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := COALESCE(p_user_id, auth.uid());
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  UPDATE public.user_security_settings
  SET two_factor_enabled = false,
      totp_secret_encrypted = NULL,
      updated_at = timezone('utc'::text, now())
  WHERE user_id = v_uid;

  UPDATE public.profiles
  SET two_factor_enabled = false,
      two_factor_secret = NULL,
      updated_at = timezone('utc'::text, now())
  WHERE id = v_uid;

  -- Invalidate recovery codes & revoke trusted devices
  DELETE FROM public.recovery_codes WHERE user_id = v_uid;
  
  UPDATE public.trusted_devices
  SET revoked_at = timezone('utc'::text, now())
  WHERE user_id = v_uid AND revoked_at IS NULL;

  INSERT INTO public.security_events (user_id, event_type)
  VALUES (v_uid, '2FA_DISABLED');

  RETURN jsonb_build_object('success', true);
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 10: Regenerate Recovery Codes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.regenerate_recovery_codes_rpc(
  p_new_hashes text[],
  p_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := COALESCE(p_user_id, auth.uid());
  v_hash text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  -- Delete all existing recovery codes
  DELETE FROM public.recovery_codes WHERE user_id = v_uid;

  -- Insert new code hashes
  IF p_new_hashes IS NOT NULL THEN
    FOREACH v_hash IN ARRAY p_new_hashes LOOP
      INSERT INTO public.recovery_codes (user_id, code_hash, used)
      VALUES (v_uid, v_hash, false);
    END LOOP;
  END IF;

  INSERT INTO public.security_events (user_id, event_type, metadata)
  VALUES (v_uid, 'RECOVERY_CODES_REGENERATED', jsonb_build_object('count', array_length(p_new_hashes, 1)));

  RETURN jsonb_build_object('success', true, 'count', array_length(p_new_hashes, 1));
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC 11: Revoke Trusted Device
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.revoke_trusted_device_rpc(
  p_device_id text,
  p_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := COALESCE(p_user_id, auth.uid());
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  UPDATE public.trusted_devices
  SET revoked_at = timezone('utc'::text, now())
  WHERE user_id = v_uid
    AND (device_id = p_device_id OR id::text = p_device_id)
    AND revoked_at IS NULL;

  INSERT INTO public.security_events (user_id, event_type, metadata)
  VALUES (v_uid, 'TRUSTED_DEVICE_REVOKED', jsonb_build_object('device_id', p_device_id));

  RETURN jsonb_build_object('success', true);
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC: Save Server Security Key Hashes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.save_server_security_key_hashes(
  p_key_hashes text[],
  p_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := COALESCE(p_user_id, auth.uid());
  v_hash text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  -- Remove existing server security keys for user
  DELETE FROM public.server_security_keys WHERE user_id = v_uid;

  -- Insert new key hashes
  IF p_key_hashes IS NOT NULL THEN
    FOREACH v_hash IN ARRAY p_key_hashes LOOP
      INSERT INTO public.server_security_keys (user_id, key_hash, used)
      VALUES (v_uid, v_hash, false);
    END LOOP;
  END IF;

  INSERT INTO public.security_events (user_id, event_type, metadata)
  VALUES (v_uid, 'SERVER_SECURITY_KEYS_GENERATED', jsonb_build_object('count', array_length(p_key_hashes, 1)));

  RETURN jsonb_build_object('success', true, 'count', array_length(p_key_hashes, 1));
END;
$$;

-- -----------------------------------------------------------------------------
-- RPC: Verify Server Security Key Login
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.verify_server_security_key_login(
  p_user_id uuid,
  p_key_hash text,
  p_device_id text DEFAULT NULL,
  p_device_name text DEFAULT NULL,
  p_trust_device boolean DEFAULT false,
  p_device_token_hash text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_key_row record;
  v_rate_check jsonb;
  v_remaining_count int;
  v_expires_at timestamptz;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User ID is required');
  END IF;

  -- Rate limit check
  v_rate_check := public.check_2fa_rate_limit(p_user_id);
  IF (v_rate_check->>'allowed')::boolean = false THEN
    RETURN v_rate_check;
  END IF;

  -- Find matching unused server security key
  SELECT * INTO v_key_row
  FROM public.server_security_keys
  WHERE user_id = p_user_id
    AND key_hash = p_key_hash
    AND used = false;

  IF v_key_row.id IS NULL THEN
    PERFORM public.record_2fa_attempt(p_user_id, 'server_key_verify', false, p_device_id);
    INSERT INTO public.security_events (user_id, event_type, metadata)
    VALUES (p_user_id, '2FA_LOGIN_FAILED', jsonb_build_object('reason', 'invalid_server_key', 'device_id', p_device_id));

    RETURN jsonb_build_object('success', false, 'error', 'Invalid server security key. Please try again.');
  END IF;

  -- Mark key as used
  UPDATE public.server_security_keys
  SET used = true,
      used_at = timezone('utc'::text, now())
  WHERE id = v_key_row.id;

  -- Count remaining
  SELECT count(*) INTO v_remaining_count
  FROM public.server_security_keys
  WHERE user_id = p_user_id AND used = false;

  -- Record attempt success & update last verified
  PERFORM public.record_2fa_attempt(p_user_id, 'server_key_verify', true, p_device_id);

  UPDATE public.user_security_settings
  SET last_verified_at = timezone('utc'::text, now()),
      updated_at = timezone('utc'::text, now())
  WHERE user_id = p_user_id;

  -- Handle Trust Device if requested
  IF p_trust_device = true AND p_device_token_hash IS NOT NULL AND length(p_device_token_hash) > 0 THEN
    v_expires_at := timezone('utc'::text, now()) + interval '30 days';

    INSERT INTO public.trusted_devices (user_id, device_id, device_name, token_hash, expires_at)
    VALUES (p_user_id, COALESCE(p_device_id, 'unknown_device'), COALESCE(p_device_name, 'Trusted Device'), p_device_token_hash, v_expires_at);

    INSERT INTO public.security_events (user_id, event_type, metadata)
    VALUES (p_user_id, 'TRUSTED_DEVICE_CREATED', jsonb_build_object('device_name', p_device_name, 'expires_at', v_expires_at));
  END IF;

  INSERT INTO public.security_events (user_id, event_type, metadata)
  VALUES (p_user_id, 'SERVER_SECURITY_KEY_USED', jsonb_build_object('remaining_keys', v_remaining_count, 'device_id', p_device_id));

  RETURN jsonb_build_object(
    'success', true,
    'key_used', true,
    'remaining_keys', v_remaining_count
  );
END;
$$;

-- 2. Enhanced moderate_kick_user RPC with Assigned Role Protection
CREATE OR REPLACE FUNCTION public.moderate_kick_user(
  p_room_id text,
  p_target_user_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_canonical_owner uuid;
  v_caller_role text := 'Audience';
  v_target_name text;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN
    v_room_id := p_room_id;
  END IF;

  -- Fetch Canonical Owner
  SELECT COALESCE(owner_user_id, room_owner, host_id) INTO v_canonical_owner FROM public.rooms WHERE id = v_room_id;

  -- ABSOLUTE PROTECTION: User holding ANY assigned role CANNOT be kicked
  IF public.has_assigned_room_role(v_room_id, p_target_user_id) THEN
    RAISE EXCEPTION 'ROLE_PROTECTED: User holds an assigned role (Co-Owner, Admin, Host, Star Member, Owner). You must demote/remove their role before kicking them.';
  END IF;

  -- Determine Caller Authority
  IF v_caller_id = v_canonical_owner THEN
    v_caller_role := 'Creator';
  ELSE
    SELECT 
      CASE 
        WHEN v_caller_id::text = ANY(COALESCE(co_owner_ids, '{}'::text[])) THEN 'Co-Owner'
        WHEN v_caller_id::text = ANY(COALESCE(admin_ids, '{}'::text[])) THEN 'Admin'
        WHEN v_caller_id::text = ANY(COALESCE(host_ids, '{}'::text[])) THEN 'Host'
        ELSE 'Audience'
      END INTO v_caller_role
    FROM public.rooms WHERE id = v_room_id;
  END IF;

  IF v_caller_role NOT IN ('Creator', 'Owner', 'Co-Owner', 'Co Owner', 'Admin', 'Moderator', 'Host') THEN
    RAISE EXCEPTION 'Insufficient permissions to kick members.';
  END IF;

  SELECT username INTO v_target_name FROM public.profiles WHERE id = p_target_user_id;

  -- Remove from room_members
  DELETE FROM public.room_members WHERE room_id = v_room_id AND user_id = p_target_user_id;

  -- Free any seat held by kicked user
  UPDATE public.room_seats
  SET user_id = NULL, mic_status = 'muted', is_speaking = FALSE
  WHERE room_id = v_room_id AND user_id = p_target_user_id;

  -- Log Activity Event
  INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
  VALUES (v_room_id, 'user_kicked', p_target_user_id, COALESCE(v_target_name, 'Member'), COALESCE(v_target_name, 'Member') || ' was kicked out of the room.');

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'action', 'KICKED'
  );
END;
$$;

-- 3. Enhanced moderate_ban_user RPC with Assigned Role Protection
CREATE OR REPLACE FUNCTION public.moderate_ban_user(
  p_room_id text,
  p_target_user_id uuid,
  p_reason text DEFAULT NULL,
  p_duration text DEFAULT '24_hours'
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_room_id text;
  v_canonical_owner uuid;
  v_caller_role text := 'Audience';
  v_target_name text;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  SELECT id INTO v_room_id FROM public.rooms WHERE id = p_room_id OR username = p_room_id LIMIT 1;
  IF v_room_id IS NULL THEN
    v_room_id := p_room_id;
  END IF;

  -- Fetch Canonical Owner
  SELECT COALESCE(owner_user_id, room_owner, host_id) INTO v_canonical_owner FROM public.rooms WHERE id = v_room_id;

  -- ABSOLUTE PROTECTION: User holding ANY assigned role CANNOT be banned
  IF public.has_assigned_room_role(v_room_id, p_target_user_id) THEN
    RAISE EXCEPTION 'ROLE_PROTECTED: User holds an assigned role (Co-Owner, Admin, Host, Star Member, Owner). You must demote/remove their role before banning them.';
  END IF;

  -- Determine Caller Authority
  IF v_caller_id = v_canonical_owner THEN
    v_caller_role := 'Creator';
  ELSE
    SELECT 
      CASE 
        WHEN v_caller_id::text = ANY(COALESCE(co_owner_ids, '{}'::text[])) THEN 'Co-Owner'
        WHEN v_caller_id::text = ANY(COALESCE(admin_ids, '{}'::text[])) THEN 'Admin'
        WHEN v_caller_id::text = ANY(COALESCE(host_ids, '{}'::text[])) THEN 'Host'
        ELSE 'Audience'
      END INTO v_caller_role
    FROM public.rooms WHERE id = v_room_id;
  END IF;

  IF v_caller_role NOT IN ('Creator', 'Owner', 'Co-Owner', 'Co Owner', 'Admin', 'Moderator', 'Host') THEN
    RAISE EXCEPTION 'Insufficient permissions to ban members.';
  END IF;

  SELECT username INTO v_target_name FROM public.profiles WHERE id = p_target_user_id;

  -- Add to block_list array on public.rooms
  UPDATE public.rooms 
  SET block_list = ARRAY(SELECT DISTINCT unnest(COALESCE(block_list, '{}'::text[]) || ARRAY[p_target_user_id::text]))
  WHERE id = v_room_id;

  -- Remove from room_members
  DELETE FROM public.room_members WHERE room_id = v_room_id AND user_id = p_target_user_id;

  -- Free any seat held by banned user
  UPDATE public.room_seats
  SET user_id = NULL, mic_status = 'muted', is_speaking = FALSE
  WHERE room_id = v_room_id AND user_id = p_target_user_id;

  -- Log Activity Event
  INSERT INTO public.room_activity_events (room_id, event_type, user_id, username, message)
  VALUES (v_room_id, 'user_banned', p_target_user_id, COALESCE(v_target_name, 'Member'), COALESCE(v_target_name, 'Member') || ' was banned from the room.');

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'user_id', p_target_user_id,
    'action', 'BANNED'
  );
END;
$$;

