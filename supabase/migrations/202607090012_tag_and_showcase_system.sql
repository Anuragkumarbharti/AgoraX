-- 202607090012_tag_and_showcase_system.sql
-- Restricted column updates, rebuild_user_tag_system JSONB builders, and change triggers

-- Restricted profiles column guard (tag_system, tag_lights, r_tags, badges)
create or replace function public.check_profile_restricted_columns_update()
returns trigger as $$
begin
  if old.tag_lights is distinct from new.tag_lights or 
     old.r_tags is distinct from new.r_tags or 
     old.badges is distinct from new.badges or
     old.tag_system is distinct from new.tag_system then
     
     if current_setting('role') in ('authenticated', 'anon') then
        raise exception 'You do not have permission to modify restricted profile columns (tag_system, tag_lights, r_tags, badges).';
     end if;
  end if;
  return new;
end;
$$ language plpgsql;

create trigger check_profile_restricted_columns
before update on public.profiles
for each row execute function public.check_profile_restricted_columns_update();

-- dynamic tag system JSONB builder
create or replace function public.rebuild_user_tag_system(p_user_id uuid)
returns void as $$
declare
  v_r_tags text[];
  v_vip_level integer;
  v_vip_expiry timestamp with time zone;
  v_novel_level integer;
  v_novel_expiry timestamp with time zone;
  v_level integer;
  v_verified boolean;
  v_showcased_badges text[];
  
  v_identity_tags jsonb[] := array[]::jsonb[];
  v_community_tag text := null;
  v_comm_id text;
  v_special_tag text := null;
  v_verified_tag text := null;
  v_role_tag text := null;
  
  v_role text;
  v_now timestamp with time zone := now();
  v_tag_system jsonb;
  v_tag_lights text[] := '{}';
begin
  select r_tags, vip_level, vip_expiry, novel_level, novel_expiry, level, verified, showcased_badges
  into v_r_tags, v_vip_level, v_vip_expiry, v_novel_level, v_novel_expiry, v_level, v_verified, v_showcased_badges
  from public.profiles
  where id = p_user_id;

  if v_level is null then
    v_level := 1;
  end if;

  -- 1. ID Level Tag (Fixed)
  v_identity_tags := array_append(v_identity_tags, jsonb_build_object('type', 'id_level', 'value', 'Lv.' || v_level));
  v_tag_lights := array_append(v_tag_lights, 'ID Level ' || v_level);

  -- 2. Community Tag
  select id into v_comm_id
  from public.communities
  where p_user_id::text = any(members) and id in ('comm-official-001', 'comm-creators-002', 'comm-gamers-003', 'comm-campus-004', 'comm-connect-005')
  order by case id
    when 'comm-connect-005' then 1
    when 'comm-creators-002' then 2
    when 'comm-gamers-003' then 3
    when 'comm-campus-004' then 4
    when 'comm-official-001' then 5
    else 6
  end asc
  limit 1;

  if v_comm_id = 'comm-connect-005' then
    v_community_tag := 'Connect';
  elsif v_comm_id = 'comm-creators-002' then
    v_community_tag := 'Studio';
  elsif v_comm_id = 'comm-gamers-003' then
    v_community_tag := 'ArenaX';
  elsif v_comm_id = 'comm-campus-004' then
    v_community_tag := 'Campus';
  elsif v_comm_id = 'comm-official-001' then
    v_community_tag := 'Origin';
  end if;

  if v_community_tag is not null then
    v_identity_tags := array_append(v_identity_tags, jsonb_build_object('type', 'community', 'value', v_community_tag));
    v_tag_lights := array_append(v_tag_lights, v_community_tag);
  end if;

  -- 3. VIP Tag
  if (v_vip_level > 0 and (v_vip_expiry is null or v_vip_expiry > v_now)) then
    v_identity_tags := array_append(v_identity_tags, jsonb_build_object('type', 'vip', 'value', 'VIP ' || v_vip_level));
    v_tag_lights := array_append(v_tag_lights, 'VIP Level ' || v_vip_level);
  end if;

  -- 4. Noble Tag
  if (v_novel_level > 0 and (v_novel_expiry is null or v_novel_expiry > v_now)) then
    v_identity_tags := array_append(v_identity_tags, jsonb_build_object('type', 'noble', 'value', 'Novel ' || v_novel_level));
    v_tag_lights := array_append(v_tag_lights, 'Novel ' || v_novel_level);
  end if;

  -- 5. Special Identity Tag
  if 'Anniversary' = any(v_r_tags) then
    v_special_tag := 'Anniversary';
  elsif 'Champion' = any(v_r_tags) then
    v_special_tag := 'Champion';
  elsif 'Creator' = any(v_r_tags) or 'Star Creator' = any(v_r_tags) then
    v_special_tag := 'Creator';
  elsif 'Official' = any(v_r_tags) or 'Creania Official' = any(v_r_tags) then
    v_special_tag := 'Official';
  end if;

  if v_special_tag is not null then
    v_identity_tags := array_append(v_identity_tags, jsonb_build_object('type', 'special', 'value', v_special_tag));
    v_tag_lights := array_append(v_tag_lights, v_special_tag);
  end if;

  -- 6. Verified Tag
  foreach v_role in array array['Celebrity', 'Partner', 'Official', 'Verified', 'verified tester'] loop
    if v_role = any(v_r_tags) then
      v_verified_tag := v_role;
      exit;
    end if;
  end loop;

  if v_verified_tag is null and v_verified = true then
    v_verified_tag := 'Verified';
  end if;

  -- 7. Role Tag
  foreach v_role in array array['Developer', 'Administrator', 'Admin', 'Official Staff', 'Employee', 'Moderator', 'Host'] loop
    if v_role = any(v_r_tags) then
      if v_role = 'Admin' then
        v_role_tag := 'Administrator';
      elsif v_role = 'Employee' then
        v_role_tag := 'Official Staff';
      else
        v_role_tag := v_role;
      end if;
      exit;
    end if;
  end loop;

  v_tag_system := jsonb_build_object(
    'identityTagBar', to_jsonb(v_identity_tags),
    'officialStatus', jsonb_build_object(
      'verifiedTag', v_verified_tag,
      'roleTag', v_role_tag
    ),
    'profileShowcase', to_jsonb(coalesce(v_showcased_badges, '{}'::text[]))
  );

  update public.profiles
  set 
    tag_system = v_tag_system,
    tag_lights = v_tag_lights
  where id = p_user_id;
end;
$$ language plpgsql security definer set search_path = public;

create or replace function public.on_profile_rebuild_tag_system()
returns trigger as $$
begin
  perform public.rebuild_user_tag_system(new.id);
  return new;
end;
$$ language plpgsql security definer set search_path = public;

create trigger trigger_profile_rebuild_tag_system
after insert or update of level, vip_level, vip_expiry, novel_level, novel_expiry, r_tags, verified, showcased_badges
on public.profiles
for each row execute procedure public.on_profile_rebuild_tag_system();

create or replace function public.handle_community_membership_change()
returns trigger as $$
declare
  joined_user_id text;
  left_user_id text;
begin
  if new.members is distinct from old.members then
    select val into joined_user_id
    from unnest(new.members) as val
    except
    select val from unnest(old.members) as val
    limit 1;

    if joined_user_id is not null then
      perform public.rebuild_user_tag_system(joined_user_id::uuid);
    end if;

    select val into left_user_id
    from unnest(old.members) as val
    except
    select val from unnest(new.members) as val
    limit 1;

    if left_user_id is not null then
      perform public.rebuild_user_tag_system(left_user_id::uuid);
    end if;
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

create trigger on_community_membership_change
after update on public.communities
for each row execute procedure public.handle_community_membership_change();

-- Rebuild all profiles
do $$
declare
  r record;
begin
  for r in select id from public.profiles loop
    perform public.rebuild_user_tag_system(r.id);
  end loop;
end;
$$;
