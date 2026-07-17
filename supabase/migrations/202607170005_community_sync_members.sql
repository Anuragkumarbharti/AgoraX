-- 202607170005_community_sync_members.sql
-- Trigger to keep public.communities.members array and member_count in perfect sync with public.community_memberships

create or replace function public.tr_sync_members_on_membership_change()
returns trigger as $$
declare
  v_comm_id text;
  v_members text[];
begin
  if tg_op = 'INSERT' then
    v_comm_id := new.community_id;
  elsif tg_op = 'UPDATE' then
    v_comm_id := new.community_id;
  elsif tg_op = 'DELETE' then
    v_comm_id := old.community_id;
  end if;

  if v_comm_id is not null then
    -- Select all user_ids as text array for this community
    select array_agg(user_id::text) into v_members
    from public.community_memberships
    where community_id = v_comm_id;

    -- Update public.communities members array
    update public.communities
    set members = coalesce(v_members, '{}'::text[])
    where id = v_comm_id;
  end if;

  return null;
end;
$$ language plpgsql security definer set search_path = public;

-- Drop trigger if exists
drop trigger if exists trigger_sync_members_on_membership_change on public.community_memberships;

-- Create trigger
create trigger trigger_sync_members_on_membership_change
after insert or update or delete on public.community_memberships
for each row execute procedure public.tr_sync_members_on_membership_change();

-- Seed sync for existing memberships (to populate members arrays immediately)
do $$
declare
  r record;
  v_members text[];
begin
  for r in select id from public.communities loop
    select array_agg(user_id::text) into v_members
    from public.community_memberships
    where community_id = r.id;

    update public.communities
    set members = coalesce(v_members, '{}'::text[])
    where id = r.id;
  end loop;
end;
$$;
