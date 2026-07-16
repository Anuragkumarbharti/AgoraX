-- 202607090002_wallets_and_transactions.sql
-- Wallets, transactions ledgers, auto-wallet initializer trigger, and RLS policies

create table public.wallets (
  id uuid references public.profiles(id) on delete cascade primary key,
  coins_balance integer default 0 check (coins_balance >= 0),
  inr_balance numeric(10, 2) default 0.00 check (inr_balance >= 0.00),
  withdrawable_balance numeric(10, 2) default 0.00 check (withdrawable_balance >= 0.00),
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

create table public.wallet_transactions (
  id uuid default gen_random_uuid() primary key,
  wallet_id uuid references public.wallets(id) on delete cascade not null,
  amount numeric(10, 2) not null,
  currency text default 'Coins' not null check (currency in ('INR', 'Coins')),
  type text default 'Payout' not null check (type in ('Deposit', 'Withdrawal', 'Payout', 'Refund', 'Reward', 'Commission')),
  status text default 'Completed' not null check (status in ('Completed', 'Pending', 'Failed')),
  reference_id text,
  details text,
  transaction_type text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Trigger to auto-create wallet when a profile is inserted
create or replace function public.initialize_user_wallet()
returns trigger as $$
begin
  insert into public.wallets (id, coins_balance, inr_balance, withdrawable_balance)
  values (new.id, 0, 0.00, 0.00)
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

create trigger tr_on_profile_created_wallet
after insert on public.profiles
for each row execute function public.initialize_user_wallet();

-- Row Level Security (RLS) Policies
alter table public.wallets enable row level security;
create policy "Users can view their own wallet" on public.wallets for select using (auth.uid() = id);
create policy "Users can update their own wallet" on public.wallets for update using (auth.uid() = id);

alter table public.wallet_transactions enable row level security;
create policy "Users can view their transactions" on public.wallet_transactions for select using (auth.uid() = wallet_id);
