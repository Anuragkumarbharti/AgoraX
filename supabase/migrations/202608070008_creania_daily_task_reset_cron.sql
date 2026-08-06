-- 202608070008_creania_daily_task_reset_cron.sql
-- Creania Arena Daily Task 04:00 AM IST Reset RPC & Automated pg_cron Schedule

-- 1. Reset Function RPC (Resets daily progress, preserves total XP & Levels)
create or replace function public.reset_room_daily_tasks()
returns void as $$
declare
  v_today date := ((now() at time zone 'Asia/Kolkata') - interval '4 hours')::date;
begin
  -- 1. Reset daily room statistics (today_room_xp, today_visitors, etc.)
  -- Total room_xp and current_level in public.rooms & public.room_level_progress are PERMANENTLY PRESERVED!
  update public.rooms
  set today_room_xp = 0;

  update public.room_statistics
  set today_visitors = 0,
      today_silver_coins = 0,
      today_gold_coins = 0,
      today_task_points = 0,
      today_extra_xp_points = 0,
      updated_at = now();

  -- 2. Reset seat daily gift counters
  update public.room_seat_gifts
  set silver_gift_count = 0,
      gold_gift_count = 0,
      updated_at = now();

  -- 3. Clear old day task progress entries so new date begins fresh at 04:00 AM IST
  delete from public.user_daily_task_progress
  where task_date < v_today;

  delete from public.room_team_task_progress
  where task_date < v_today;

  raise notice 'Creania Daily Room Tasks reset successfully for date % at 04:00 AM IST', v_today;
end;
$$ language plpgsql security definer;

-- 2. Setup Automated pg_cron Schedule at 04:00 AM IST (22:30 UTC every day)
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    -- Unschedule existing job if present
    perform cron.unschedule('creania-daily-room-task-reset');
    
    -- Schedule cron job for 22:30 UTC = 04:00 AM IST
    perform cron.schedule(
      'creania-daily-room-task-reset',
      '30 22 * * *',
      $$ select public.reset_room_daily_tasks(); $$
    );
  end if;
exception when others then
  raise notice 'pg_cron extension not active or permission restricted';
end;
$$;
