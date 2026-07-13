-- supabase/migrations/202607130000_remove_daily_tasks.sql
-- 1. Alter wallet_transactions to add transaction_type and set default values
alter table public.wallet_transactions add column if not exists transaction_type text;
alter table public.wallet_transactions alter column currency set default 'Coins';
alter table public.wallet_transactions alter column type set default 'Payout';
alter table public.wallet_transactions alter column status set default 'Completed';

-- 2. Drop triggers on posts/comments/likes
drop trigger if exists trigger_on_comment_added on public.post_comments;
drop trigger if exists trigger_on_like_added on public.post_likes;
drop trigger if exists trigger_on_post_added on public.posts;

-- 3. Drop trigger functions
drop function if exists public.on_comment_added() cascade;
drop function if exists public.on_like_added() cascade;
drop function if exists public.on_post_added() cascade;

-- 4. Drop task progression functions
drop function if exists public.rotate_daily_tasks(uuid) cascade;
drop function if exists public.increment_task_progress(text, integer) cascade;
drop function if exists public.claim_task_reward(uuid) cascade;
drop function if exists public.rotate_career_tasks(uuid) cascade;
drop function if exists public.increment_career_task_progress(text, integer) cascade;
drop function if exists public.claim_career_task_reward(uuid) cascade;
drop function if exists public.rotate_id_tasks(uuid) cascade;
drop function if exists public.increment_id_task_progress(text, integer) cascade;
drop function if exists public.claim_id_task_reward(uuid) cascade;

-- 5. Drop daily task tables
drop table if exists public.career_tasks cascade;
drop table if exists public.id_tasks cascade;
drop table if exists public.weekly_tasks cascade;
drop table if exists public.monthly_tasks cascade;
drop table if exists public.event_tasks cascade;
drop table if exists public.user_daily_progress cascade;
drop table if exists public.daily_rewards cascade;
drop table if exists public.career_daily_tasks cascade;
drop table if exists public.id_daily_tasks cascade;
drop table if exists public.career_progress cascade;
drop table if exists public.id_progress cascade;
drop table if exists public.career_history cascade;
drop table if exists public.id_history cascade;
drop table if exists public.career_rewards cascade;
drop table if exists public.id_rewards cascade;
