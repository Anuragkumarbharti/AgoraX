-- 202607090004_plans_and_purchases.sql
-- VIP / Novel plans, user purchase ledger entries, and RLS policies

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

-- Row Level Security (RLS) Policies
alter table public.vip_plans enable row level security;
create policy "Anyone can view VIP plans" on public.vip_plans for select using (true);

alter table public.novel_plans enable row level security;
create policy "Anyone can view Novel plans" on public.novel_plans for select using (true);

alter table public.purchase_history enable row level security;
create policy "Users can view purchase history" on public.purchase_history for select using (auth.uid() = user_id);
