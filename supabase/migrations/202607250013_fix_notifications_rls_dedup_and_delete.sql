-- Migration 202607250013_fix_notifications_rls_dedup_and_delete.sql
-- Fix notifications table RLS policies, soft delete, deduplication, and RPCs

-- 1. Ensure columns exist on public.notifications
alter table public.notifications add column if not exists is_deleted boolean default false not null;
alter table public.notifications add column if not exists event_id text default null;

-- 2. Add explicit RLS Policies for UPDATE and DELETE on public.notifications
alter table public.notifications enable row level security;

drop policy if exists "Users can view their notifications" on public.notifications;
create policy "Users can view their notifications" on public.notifications for select using (auth.uid() = user_id);

drop policy if exists "Allow everyone to insert notifications" on public.notifications;
create policy "Allow everyone to insert notifications" on public.notifications for insert with check (true);

drop policy if exists "Users can update their notifications" on public.notifications;
create policy "Users can update their notifications" on public.notifications for update using (auth.uid() = user_id);

drop policy if exists "Users can delete their notifications" on public.notifications;
create policy "Users can delete their notifications" on public.notifications for delete using (auth.uid() = user_id);

-- 3. Create index for fast user notification filtering
create index if not exists idx_notifications_user_deleted on public.notifications(user_id, is_deleted, created_at desc);
create index if not exists idx_notifications_event_id on public.notifications(user_id, event_id) where event_id is not null;

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

grant execute on function public.clear_all_user_notifications(uuid) to authenticated, service_role;
grant execute on function public.delete_single_notification(uuid, uuid) to authenticated, service_role;
grant execute on function public.mark_all_notifications_read(uuid) to authenticated, service_role;
