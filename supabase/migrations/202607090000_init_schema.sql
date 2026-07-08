-- 202607090000_init_schema.sql
-- Production-Ready Database Schema for AgoraX (Supabase / PostgreSQL)

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ── 1. PROFILES TABLE ──
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  username text unique not null,
  avatar_url text,
  level integer default 1 check (level >= 1),
  experience integer default 0 check (experience >= 0),
  followers integer default 0 check (followers >= 0),
  following integer default 0 check (following >= 0),
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
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.profiles enable row level security;

create policy "Public profiles are viewable by everyone" on public.profiles for select using (true);
create policy "Users can update their own profile" on public.profiles for update using (auth.uid() = id);

-- ── 2. WALLETS ──
create table public.wallets (
  id uuid references public.profiles(id) on delete cascade primary key,
  coins_balance integer default 0 check (coins_balance >= 0),
  inr_balance numeric(10, 2) default 0.00 check (inr_balance >= 0.00),
  withdrawable_balance numeric(10, 2) default 0.00 check (withdrawable_balance >= 0.00),
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

alter table public.wallets enable row level security;

create policy "Users can view their own wallet" on public.wallets for select using (auth.uid() = id);

-- ── 3. WALLET LEDGERS & HISTORY ──
create table public.wallet_transactions (
  id uuid default gen_random_uuid() primary key,
  wallet_id uuid references public.wallets(id) on delete cascade not null,
  amount numeric(10, 2) not null,
  currency text not null check (currency in ('INR', 'Coins')),
  type text not null check (type in ('Deposit', 'Withdrawal', 'Payout', 'Refund', 'Reward', 'Commission')),
  status text not null check (status in ('Completed', 'Pending', 'Failed')),
  reference_id text,
  details text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.wallet_transactions enable row level security;
create policy "Users can view their transactions" on public.wallet_transactions for select using (auth.uid() = wallet_id);

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

alter table public.purchase_history enable row level security;
create policy "Users can view purchase history" on public.purchase_history for select using (auth.uid() = user_id);

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

alter table public.gift_history enable row level security;
create policy "Users can view sent/received gifts" on public.gift_history for select using (auth.uid() = sender_id or auth.uid() = receiver_id);

create table public.withdraw_history (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  amount numeric(10, 2) not null check (amount > 0.00),
  payment_method text not null check (payment_method in ('UPI', 'Bank')),
  payment_details text not null,
  status text default 'Pending' check (status in ('Completed', 'Pending', 'Failed')),
  utr_reference text,
  admin_comment text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.withdraw_history enable row level security;
create policy "Users can view withdrawal requests" on public.withdraw_history for select using (auth.uid() = user_id);

-- ── 4. STORES, PLANS & INVENTORY ──
create table public.store_items (
  id text primary key,
  name text not null,
  description text,
  category text not null check (category in ('Cosmetic', 'Frame', 'Bubble', 'VirtualGift')),
  price_coins integer not null check (price_coins >= 0),
  price_inr numeric(10, 2) not null check (price_inr >= 0.00),
  is_active boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.store_items enable row level security;
create policy "Anyone can view active store items" on public.store_items for select using (is_active = true);

create table public.inventory (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  item_id text references public.store_items(id) on delete cascade,
  is_equipped boolean default false,
  unlocked_at timestamp with time zone default timezone('utc'::text, now()) not null,
  expires_at timestamp with time zone,
  unique(user_id, item_id)
);

alter table public.inventory enable row level security;
create policy "Users can view their inventory" on public.inventory for select using (auth.uid() = user_id);

create table public.vip_plans (
  id text primary key,
  vip_level integer not null check (vip_level between 1 and 7),
  duration text not null,
  price_inr numeric(10, 2) not null check (price_inr >= 0.00),
  price_coins integer not null check (price_coins >= 0)
);

create table public.novel_plans (
  id text primary key,
  novel_level integer not null check (novel_level between 1 and 7),
  duration text not null,
  price_inr numeric(10, 2) not null check (price_inr >= 0.00),
  price_coins integer not null check (price_coins >= 0)
);

-- ── 5. STUDY VAULT ITEMS (BOOKS & NOTES) ──
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
  watermark_text text default 'AgoraX',
  is_featured boolean default false,
  status text default 'Pending' check (status in ('Approved', 'Pending', 'Rejected')),
  admin_comment text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.study_vault_items enable row level security;
create policy "Anyone can view approved items" on public.study_vault_items for select using (status = 'Approved');
create policy "Users can upload resources" on public.study_vault_items for insert with check (auth.uid() = seller_id);

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

alter table public.study_reviews enable row level security;
create policy "Anyone can view reviews" on public.study_reviews for select using (true);

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

alter table public.reading_history enable row level security;
create policy "Users can modify their own history" on public.reading_history for all using (auth.uid() = user_id);

-- ── 6. CHATS, MESSAGES & E2EE KEY EXCHANGE ──
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

alter table public.messages enable row level security;
create policy "Users can view eligible messages" on public.messages for select using (
  not is_private or auth.uid() = sender_id or auth.uid() = receiver_id
);
create policy "Users can insert messages" on public.messages for insert with check (auth.uid() = sender_id);

-- ── 7. VOICE ROOMS & CHANNELS (LIVEKIT SIGNALLING) ──
create table public.rooms (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  description text,
  host_id uuid references public.profiles(id) on delete cascade not null,
  is_private boolean default false,
  room_password text,
  livekit_room_name text unique not null,
  max_participants integer default 50 check (max_participants > 0),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.rooms enable row level security;
create policy "Anyone can view active rooms" on public.rooms for select using (true);

create table public.room_members (
  room_id uuid references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  joined_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, user_id)
);

alter table public.room_members enable row level security;
create policy "Members are viewable by everyone" on public.room_members for select using (true);

create table public.room_moderators (
  room_id uuid references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  assigned_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (room_id, user_id)
);

create table public.room_messages (
  id uuid default gen_random_uuid() primary key,
  room_id uuid references public.rooms(id) on delete cascade not null,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  content text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.room_messages enable row level security;
create policy "Anyone in room can view room messages" on public.room_messages for select using (true);

create table public.room_gifts (
  id uuid default gen_random_uuid() primary key,
  room_id uuid references public.rooms(id) on delete cascade not null,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  receiver_id uuid references public.profiles(id) on delete cascade not null,
  gift_id text not null,
  quantity integer default 1 check (quantity >= 1),
  coins_value integer not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.room_events (
  id uuid default gen_random_uuid() primary key,
  room_id uuid references public.rooms(id) on delete cascade not null,
  event_type text not null,
  payload jsonb default '{}'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ── 8. NOTIFICATIONS ──
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

alter table public.notifications enable row level security;
create policy "Users can view their notifications" on public.notifications for select using (auth.uid() = user_id);

-- ── 9. ADMIN, AUDITING & MODERATION ──
create table public.admins (
  id uuid references public.profiles(id) on delete cascade primary key,
  role text not null check (role in ('SuperAdmin', 'Moderator', 'Support')),
  assigned_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.admins enable row level security;
create policy "Admin roles viewable by admins" on public.admins for select using (
  exists (select 1 from public.admins where admins.id = auth.uid())
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

create table public.moderation_logs (
  id uuid default gen_random_uuid() primary key,
  admin_id uuid references public.admins(id) on delete set null,
  target_id text not null,
  target_type text not null,
  action text not null,
  reason text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ── 10. ANALYTICS & LOGINS ──
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

-- ── 11. TRIGGER FUNCTION FOR PROFILE/WALLET ON SIGNUP ──
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, avatar_url, vip_level, novel_level, level, experience)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', 'user_' || substr(new.id::text, 1, 8)),
    new.raw_user_meta_data->>'avatar_url',
    0,
    0,
    1,
    0
  );

  insert into public.wallets (id, coins_balance, inr_balance, withdrawable_balance)
  values (new.id, 0, 0.00, 0.00);

  return new;
end;
$$ language plpgsql security definer;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
