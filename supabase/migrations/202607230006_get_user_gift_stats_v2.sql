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
  -- Lifetime received
  select coalesce(sum(stars_value), 0) into v_lifetime_received 
  from public.gift_transactions 
  where receiver_id = p_user_id;

  -- Lifetime sent
  select coalesce(sum(stars_value), 0) into v_lifetime_sent 
  from public.gift_transactions 
  where sender_id = p_user_id;

  -- Monthly received
  select coalesce(sum(stars_value), 0) into v_monthly_received 
  from public.gift_transactions 
  where receiver_id = p_user_id 
    and to_char(created_at, 'YYYY-MM') = v_monthly_key;

  -- Monthly sent
  select coalesce(sum(stars_value), 0) into v_monthly_sent 
  from public.gift_transactions 
  where sender_id = p_user_id 
    and to_char(created_at, 'YYYY-MM') = v_monthly_key;

  -- Recent received avatars (top 4 distinct senders' avatars)
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

  -- Recent sent avatars (top 4 distinct receivers' avatars)
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
    'lifetime_received', v_lifetime_received,
    'lifetime_sent', v_lifetime_sent,
    'monthly_received', v_monthly_received,
    'monthly_sent', v_monthly_sent,
    'recent_received_avatars', coalesce(v_received_avatars, '{}'::text[]),
    'recent_sent_avatars', coalesce(v_sent_avatars, '{}'::text[])
  );
end;
$$ language plpgsql security definer;
