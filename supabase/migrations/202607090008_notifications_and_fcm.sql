-- ==========================================================================
-- Consolidated Supabase Migration Module 08: 202607090008_notifications_and_fcm.sql
-- Authoritative baseline schema, functions, triggers, policies, and seeds.
-- ==========================================================================

-- RLS Policies
create policy "Users can manage their own fcm tokens" on public.fcm_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Realtime replication
do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception when others then
  raise notice 'Table notifications already in supabase_realtime publication';
end;
$$;

-- 202607230012_trigger_notifications.sql
-- Database-level automatic triggers to insert notifications for important user interactions
alter table public.notifications add column if not exists push_dispatched boolean default false not null;

drop trigger if exists tr_connections_notifications on public.connections;

create trigger tr_connections_notifications
  after insert or update on public.connections
  for each row execute function public.handle_connections_notifications();

drop trigger if exists tr_post_likes_notifications on public.post_likes;

create trigger tr_post_likes_notifications
  after insert on public.post_likes
  for each row execute function public.handle_post_likes_notifications();

drop trigger if exists tr_post_comments_notifications on public.post_comments;

create trigger tr_post_comments_notifications
  after insert on public.post_comments
  for each row execute function public.handle_post_comments_notifications();

drop trigger if exists tr_new_posts_notifications on public.posts;

create trigger tr_new_posts_notifications
  after insert on public.posts
  for each row execute function public.handle_new_posts_notifications();

-- Migration 202607250013_fix_notifications_rls_dedup_and_delete.sql
-- Fix notifications table RLS policies, soft delete, deduplication, and RPCs

-- 1. Ensure columns exist on public.notifications
alter table public.notifications add column if not exists is_deleted boolean default false not null;

alter table public.notifications add column if not exists event_id text default null;

drop policy if exists "Users can view their notifications" on public.notifications;

drop policy if exists "Allow everyone to insert notifications" on public.notifications;

drop policy if exists "Users can update their notifications" on public.notifications;

drop policy if exists "Users can delete their notifications" on public.notifications;

-- 3. Create index for fast user notification filtering
create index if not exists idx_notifications_user_deleted on public.notifications(user_id, is_deleted, created_at desc);

create index if not exists idx_notifications_event_id on public.notifications(user_id, event_id) where event_id is not null;

grant execute on function public.clear_all_user_notifications(uuid) to authenticated, service_role;

grant execute on function public.delete_single_notification(uuid, uuid) to authenticated, service_role;

grant execute on function public.mark_all_notifications_read(uuid) to authenticated, service_role;

-- Functions
create or replace function public.register_fcm_token(
  p_user_id uuid,
  p_token text,
  p_device_id text,
  p_device_type text
)
returns void as $$
begin
  insert into public.fcm_tokens(user_id, token, device_id, device_type)
  values (p_user_id, p_token, p_device_id, p_device_type)
  on conflict (token) do update set
    user_id = excluded.user_id,
    device_id = excluded.device_id,
    device_type = excluded.device_type,
    updated_at = now();
end;
$$ language plpgsql security definer;

create or replace function public.unregister_fcm_token(
  p_token text
)
returns void as $$
begin
  delete from public.fcm_tokens where token = p_token;
end;
$$ language plpgsql security definer;

-- 4. RPC: Clear all notifications for user (hard delete + soft delete fallback)
create or replace function public.clear_all_user_notifications(p_user_id uuid)
returns void as $$
begin
  -- Mark as deleted first
  update public.notifications
  set is_deleted = true, is_read = true
  where user_id = p_user_id;

  -- Delete rows
  delete from public.notifications
  where user_id = p_user_id;
end;
$$ language plpgsql security definer;

-- 5. RPC: Delete single notification
create or replace function public.delete_single_notification(p_user_id uuid, p_notif_id uuid)
returns void as $$
begin
  update public.notifications
  set is_deleted = true, is_read = true
  where id = p_notif_id and user_id = p_user_id;

  delete from public.notifications
  where id = p_notif_id and user_id = p_user_id;
end;
$$ language plpgsql security definer;

-- 6. RPC: Mark all notifications read
create or replace function public.mark_all_notifications_read(p_user_id uuid)
returns void as $$
begin
  update public.notifications
  set is_read = true
  where user_id = p_user_id and is_read = false and is_deleted = false;
end;
$$ language plpgsql security definer;

