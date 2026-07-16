-- 202607090018_prevent_profile_deletion.sql
-- Table-level audit logging, admin-only deletion, and unique constraints

-- 1. Create account audit logs table
create table if not exists public.account_audit_logs (
  id uuid default gen_random_uuid() primary key,
  event_time timestamp with time zone default now() not null,
  target_table text not null,
  operation text not null,
  actor_id uuid,
  record_id uuid not null,
  old_data jsonb,
  new_data jsonb,
  reason text
);

-- Enable RLS on audit logs
alter table public.account_audit_logs enable row level security;
create policy "Allow admins to read audit logs" on public.account_audit_logs for select
using (exists (select 1 from public.admins where id = auth.uid()));

-- 2. Create trigger function to log changes on profiles and auth.users
create or replace function public.log_profile_changes()
returns trigger as $$
declare
  v_actor_id uuid;
begin
  begin
    v_actor_id := auth.uid();
  exception when others then
    v_actor_id := null;
  end;

  insert into public.account_audit_logs (
    target_table,
    operation,
    actor_id,
    record_id,
    old_data,
    new_data,
    reason
  )
  values (
    TG_TABLE_NAME,
    TG_OP,
    v_actor_id,
    coalesce(new.id, old.id),
    case when TG_OP = 'INSERT' then null else to_jsonb(old) end,
    case when TG_OP = 'DELETE' then null else to_jsonb(new) end,
    'Database automatic log for ' || TG_OP || ' on ' || TG_TABLE_NAME
  );
  
  if TG_OP = 'DELETE' then
    return old;
  else
    return new;
  end if;
end;
$$ language plpgsql security definer;

-- 3. Attach audit trigger to public.profiles
drop trigger if exists audit_profiles_trigger on public.profiles;
create trigger audit_profiles_trigger
after insert or update or delete on public.profiles
for each row execute function public.log_profile_changes();

-- 4. Attach audit trigger to auth.users
drop trigger if exists audit_users_trigger on auth.users;
create trigger audit_users_trigger
after insert or update or delete on auth.users
for each row execute function public.log_profile_changes();

-- 5. Drop owner-based profile delete policy and restrict to admin users only
drop policy if exists "Allow delete access to owner" on public.profiles;
drop policy if exists "Allow delete access to admins only" on public.profiles;

create policy "Allow delete access to admins only" on public.profiles for delete 
using (exists (select 1 from public.admins where id = auth.uid()));

-- 6. Enforce unique constraint on profiles.id
alter table public.profiles drop constraint if exists profiles_id_key;
alter table public.profiles add constraint profiles_id_key unique (id);
