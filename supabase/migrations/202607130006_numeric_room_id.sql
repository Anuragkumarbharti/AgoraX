-- Re-create generate_unique_room_id to return 6-digit numeric ID string
create or replace function public.generate_unique_room_id() returns text as $$
declare
  v_id text;
  v_exists boolean;
begin
  loop
    v_id := (floor(random() * (999999 - 100000 + 1) + 100000))::text;
    select exists(select 1 from public.rooms where id = v_id) into v_exists;
    if not v_exists then
      return v_id;
    end if;
  end loop;
end;
$$ language plpgsql;

-- Truncate existing rooms cascade to clear old format room IDs and maintain integrity
truncate table public.rooms cascade;
