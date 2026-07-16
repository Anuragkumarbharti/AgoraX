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

create table public.room_gift_statistics (
  room_id text primary key references public.rooms(id) on delete cascade not null,
  total_gold_received integer default 0 not null,
  total_silver_received integer default 0 not null,
  weekly_gold_received integer default 0 not null,
  monthly_gold_received integer default 0 not null
);

-- Functions
create or replace function public.calculate_gift_stars(item_id text, coins_value integer, quantity integer)
returns integer as $$
declare
  stars_per_unit integer;
begin
  if item_id = '2-Star Gift' then
    stars_per_unit := 2;
  elsif item_id = '1-Star Gift' then
    stars_per_unit := 1;
  else
    stars_per_unit := greatest(1, coins_value / 10);
  end if;
  return stars_per_unit * quantity;
end;
$$ language plpgsql immutable;

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

create trigger on_gift_history_insert
after insert
on public.gift_history
for each row execute procedure public.handle_gift_history_insert();

-- Send room gift RPC
create or replace function public.send_room_gift(
  p_room_id text,
  p_receiver_id uuid,
  p_gift_name text,
  p_coins_value integer,
  p_quantity integer default 1
) returns jsonb as $$
declare
  v_sender_id uuid := auth.uid();
  v_sender_balance integer;
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

  select username, coins_balance into v_sender_name, v_sender_balance 
  from public.profiles p
  join public.wallets w on w.id = p.id
  where p.id = v_sender_id;

  if coalesce(v_sender_balance, 0) < v_total_cost then
    raise exception 'Insufficient Gold Coins (Requires % coins)', v_total_cost;
  end if;

  select username into v_receiver_name from public.profiles where id = p_receiver_id;
  if v_receiver_name is null then
    v_receiver_name := 'Receiver';
  end if;

  v_stars := public.calculate_gift_stars(p_gift_name, p_coins_value, p_quantity);

  -- Deduct from sender
  update public.wallets set coins_balance = coins_balance - v_total_cost where id = v_sender_id;
  insert into public.wallet_transactions (wallet_id, amount, currency, type, status, details, transaction_type)
  values (v_sender_id, -v_total_cost, 'Coins', 'Payout', 'Completed', 'Sent ' || p_gift_name || ' gift in voice room', 'Purchase');

  -- Add to receiver (if not self)
  if v_sender_id <> p_receiver_id then
    update public.wallets set coins_balance = coins_balance + v_total_cost where id = p_receiver_id;
    insert into public.wallet_transactions (wallet_id, amount, currency, type, status, details, transaction_type)
    values (p_receiver_id, v_total_cost, 'Coins', 'Reward', 'Completed', 'Received ' || p_gift_name || ' gift in voice room', 'Reward');
  end if;

  -- General gift history log
  insert into public.gift_history (sender_id, receiver_id, item_id, item_type, quantity, coins_value)
  values (v_sender_id, p_receiver_id, p_gift_name, 'VirtualGift', p_quantity, p_coins_value);

  -- Record Room Gift
  insert into public.room_gifts (room_id, sender_id, receiver_id, gift_name, coins_value, quantity)
  values (p_room_id, v_sender_id, p_receiver_id, p_gift_name, p_coins_value, p_quantity)
  returning id into v_gift_id;

  -- Update room-wide star & gift stats
  update public.rooms
  set total_room_gifts = total_room_gifts + p_quantity,
      today_room_gifts = today_room_gifts + p_quantity,
      total_room_stars = total_room_stars + (v_stars),
      today_room_stars = today_room_stars + (v_stars),
      updated_at = now()
  where id = p_room_id;

  -- Update seat-specific star & gift stats if receiver is seated
  update public.room_seats
  set seat_total_gifts = seat_total_gifts + p_quantity,
      seat_total_stars = seat_total_stars + (v_stars),
      last_gift_time = now()
  where room_id = p_room_id and user_id = p_receiver_id;

  update public.room_gift_statistics
  set total_gold_received = total_gold_received + v_total_cost
  where room_id = p_room_id;

  insert into public.room_messages (
    room_id, sender_id, content, message_type, metadata
  ) values (
    p_room_id, v_sender_id, v_sender_name || ' sent ' || p_gift_name || ' to ' || v_receiver_name, 'gift',
    jsonb_build_object('gift_name', p_gift_name, 'coins_value', p_coins_value, 'quantity', p_quantity, 'receiver_id', p_receiver_id)
  );

  return jsonb_build_object(
    'success', true,
    'gift_id', v_gift_id,
    'remaining_balance', v_sender_balance - v_total_cost
  );
end;
$$ language plpgsql security definer;

-- Row Level Security (RLS) Policies
alter table public.gift_history enable row level security;
create policy "Users can view sent/received gifts" on public.gift_history for select using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- Realtime registrations
do $$
begin
  alter publication supabase_realtime add table public.room_seat_gifts;
exception when others then
  raise notice 'Table room_seat_gifts already in supabase_realtime publication';
end;
$$;
