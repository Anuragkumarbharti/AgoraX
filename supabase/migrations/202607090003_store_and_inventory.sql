-- 202607090003_store_and_inventory.sql
-- Store cosmetic items, user inventories, and RLS policies

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

create table public.inventory (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  item_id text references public.store_items(id) on delete cascade,
  is_equipped boolean default false,
  unlocked_at timestamp with time zone default timezone('utc'::text, now()) not null,
  expires_at timestamp with time zone,
  unique(user_id, item_id)
);

-- Row Level Security (RLS) Policies
alter table public.store_items enable row level security;
create policy "Anyone can view active store items" on public.store_items for select using (is_active = true);

alter table public.inventory enable row level security;
create policy "Users can view their inventory" on public.inventory for select using (auth.uid() = user_id);
