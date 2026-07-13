-- supabase/migrations/202607130009_fix_room_update_permission_v2.sql

create or replace function public.check_room_update_permission()
returns trigger as $$
declare
  v_actor_id uuid;
  v_role text;
begin
  -- Resolve current actor ID
  v_actor_id := auth.uid();
  if v_actor_id is null then
    -- If no authenticated user (e.g. system trigger or postgres process), allow the update
    return new;
  end if;

  -- If none of the restricted/manual settings columns changed, allow the update (it's a system/stats sync update):
  if not (
    (new.name is distinct from old.name) or
    (new.username is distinct from old.username) or
    (new.description is distinct from old.description) or
    (new.category is distinct from old.category) or
    (new.language is distinct from old.language) or
    (new.visibility is distinct from old.visibility) or
    (new.level_requirement is distinct from old.level_requirement) or
    (new.vip_requirement is distinct from old.vip_requirement) or
    (new.verification_requirement is distinct from old.verification_requirement) or
    (new.avatar is distinct from old.avatar) or
    (new.banner is distinct from old.banner) or
    (new.room_cover_url is distinct from old.room_cover_url) or
    (new.co_host_can_edit_cover is distinct from old.co_host_can_edit_cover) or
    (new.admin_can_edit_cover is distinct from old.admin_can_edit_cover) or
    (new.is_permanent is distinct from old.is_permanent) or
    (new.host_id is distinct from old.host_id)
  ) then
    return new;
  end if;

  -- Resolve the updater's role in the room members table
  select role into v_role 
  from public.room_members 
  where room_id = old.id and user_id = v_actor_id;

  -- If host_id is auth.uid(), allow all changes:
  if old.host_id = v_actor_id then
    return new;
  end if;

  -- Check if they are Co-Host or Moderator and if the respective cover permission is enabled:
  if (v_role = 'Co-Host' and old.co_host_can_edit_cover = true) or
     (v_role = 'Moderator' and old.admin_can_edit_cover = true) then
    -- Verify they ONLY changed allowed columns: avatar (cover), room_cover_url, updated_by, updated_at
    if (new.id is distinct from old.id) or
       (new.name is distinct from old.name) or
       (new.username is distinct from old.username) or
       (new.description is distinct from old.description) or
       (new.category is distinct from old.category) or
       (new.language is distinct from old.language) or
       (new.visibility is distinct from old.visibility) or
       (new.level_requirement is distinct from old.level_requirement) or
       (new.vip_requirement is distinct from old.vip_requirement) or
       (new.verification_requirement is distinct from old.verification_requirement) or
       (new.banner is distinct from old.banner) or
       (new.co_host_can_edit_cover is distinct from old.co_host_can_edit_cover) or
       (new.admin_can_edit_cover is distinct from old.admin_can_edit_cover) or
       (new.is_permanent is distinct from old.is_permanent) or
       (new.host_id is distinct from old.host_id)
    then
      raise exception 'Unauthorized to modify these settings';
    end if;
    
    new.updated_by := v_actor_id;
    new.updated_at := now();
    return new;
  end if;

  raise exception 'Unauthorized to edit this room';
end;
$$ language plpgsql security definer;
