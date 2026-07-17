-- 202607170006_fix_membership_trigger.sql
-- Fix public.tr_on_community_membership_change trigger to avoid writing to non-existent profiles.communities column

create or replace function public.tr_on_community_membership_change()
returns trigger as $$
begin
  if tg_op = 'INSERT' or tg_op = 'UPDATE' then
    perform public.rebuild_user_tag_system(new.user_id);
  elsif tg_op = 'DELETE' then
    perform public.rebuild_user_tag_system(old.user_id);
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public;
