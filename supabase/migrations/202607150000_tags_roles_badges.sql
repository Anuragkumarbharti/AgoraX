-- Add new columns for tag_lights, r_tags, and showcased_badges to profiles
alter table public.profiles add column if not exists tag_lights text[] default '{}';
alter table public.profiles add column if not exists r_tags text[] default '{}';
alter table public.profiles add column if not exists showcased_badges text[] default '{}';

-- Create or update security trigger function to restrict client-side modification of restricted columns
create or replace function public.check_profile_restricted_columns_update()
returns trigger as $$
begin
  if old.tag_lights is distinct from new.tag_lights or 
     old.r_tags is distinct from new.r_tags or 
     old.badges is distinct from new.badges then
     
     -- Check if caller role is authenticated/anon (blocks client library updates)
     if current_setting('role') in ('authenticated', 'anon') then
       raise exception 'You do not have permission to modify restricted profile columns (tag_lights, r_tags, badges).';
     end if;
  end if;
  return new;
end;
$$ language plpgsql;

-- Attach check trigger to profiles
drop trigger if exists check_profile_restricted_columns on public.profiles;
create trigger check_profile_restricted_columns
before update on public.profiles
for each row execute function public.check_profile_restricted_columns_update();

-- Seed initial tags, roles, and badges on all existing developer/test profiles
update public.profiles set 
  tag_lights = '{Verified,VIP Level 1,ID Level,Community Level,Developer}', 
  r_tags = '{Developer,Official,Employee}',
  badges = '{Anniversary,Founder Badge,Early User,Beta Tester,Event Winner,Top Gifter}',
  showcased_badges = '{Anniversary,Founder Badge,Early User,Beta Tester}';
