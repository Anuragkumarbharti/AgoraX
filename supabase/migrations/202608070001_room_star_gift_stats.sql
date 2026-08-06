-- 202608070001_room_star_gift_stats.sql

-- Update get_room_contribution_stats RPC to return Today's and Total breakdown for Sent and Received gifts
create or replace function public.get_room_contribution_stats(p_room_id text)
returns jsonb as $$
declare
  v_total_stars numeric := 0;
  v_total_gifts integer := 0;
  v_today_stars numeric := 0;
  v_today_gifts integer := 0;
  v_total_top_contributors jsonb;
  v_total_top_receivers jsonb;
  v_today_top_contributors jsonb;
  v_today_top_receivers jsonb;
begin
  select coalesce(total_room_stars, 0), coalesce(total_room_gifts, 0), coalesce(today_room_stars, 0), coalesce(today_room_gifts, 0)
  into v_total_stars, v_total_gifts, v_today_stars, v_today_gifts
  from public.rooms where id = p_room_id;

  -- Total Top Contributors (Lifetime Givers)
  select jsonb_agg(d) into v_total_top_contributors from (
    select 
      t.sender_id as user_id, 
      p.username, 
      p.avatar_url as avatar,
      sum(t.stars_value) as stars_value
    from public.gift_transactions t
    join public.profiles p on p.id = t.sender_id
    where t.room_id = p_room_id
    group by t.sender_id, p.username, p.avatar_url
    order by stars_value desc
    limit 30
  ) d;

  -- Total Top Receivers (Lifetime Receivers)
  select jsonb_agg(d) into v_total_top_receivers from (
    select 
      t.receiver_id as user_id, 
      p.username, 
      p.avatar_url as avatar,
      sum(t.stars_value) as stars_value
    from public.gift_transactions t
    join public.profiles p on p.id = t.receiver_id
    where t.room_id = p_room_id
    group by t.receiver_id, p.username, p.avatar_url
    order by stars_value desc
    limit 30
  ) d;

  -- Today's Top Contributors (Today Givers)
  select jsonb_agg(d) into v_today_top_contributors from (
    select 
      t.sender_id as user_id, 
      p.username, 
      p.avatar_url as avatar,
      sum(t.stars_value) as stars_value
    from public.gift_transactions t
    join public.profiles p on p.id = t.sender_id
    where t.room_id = p_room_id and t.created_at >= CURRENT_DATE
    group by t.sender_id, p.username, p.avatar_url
    order by stars_value desc
    limit 30
  ) d;

  -- Today's Top Receivers (Today Receivers)
  select jsonb_agg(d) into v_today_top_receivers from (
    select 
      t.receiver_id as user_id, 
      p.username, 
      p.avatar_url as avatar,
      sum(t.stars_value) as stars_value
    from public.gift_transactions t
    join public.profiles p on p.id = t.receiver_id
    where t.room_id = p_room_id and t.created_at >= CURRENT_DATE
    group by t.receiver_id, p.username, p.avatar_url
    order by stars_value desc
    limit 30
  ) d;

  return jsonb_build_object(
    'total_stars', v_total_stars,
    'total_gifts', v_total_gifts,
    'today_stars', v_today_stars,
    'today_gifts', v_today_gifts,
    'total_top_contributors', coalesce(v_total_top_contributors, '[]'::jsonb),
    'total_top_receivers', coalesce(v_total_top_receivers, '[]'::jsonb),
    'today_top_contributors', coalesce(v_today_top_contributors, '[]'::jsonb),
    'today_top_receivers', coalesce(v_today_top_receivers, '[]'::jsonb),
    -- Backward compatibility aliases
    'session_stars', v_today_stars,
    'session_gifts', v_today_gifts,
    'top_contributors', coalesce(v_total_top_contributors, '[]'::jsonb),
    'top_receivers', coalesce(v_total_top_receivers, '[]'::jsonb)
  );
end;
$$ language plpgsql security definer;
