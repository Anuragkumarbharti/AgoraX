-- 202607090000_extensions_and_privileges.sql
-- Enable database extensions and grant base privileges

create extension if not exists "uuid-ossp";

-- Grant explicit privileges on ALL current tables and sequences in public schema
grant select, insert, update, delete on all tables in schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to anon;

grant usage, select on all sequences in schema public to authenticated;
grant usage, select on all sequences in schema public to anon;

-- Configure default privileges so any future tables automatically inherit these permissions
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema public grant select, insert, update, delete on tables to anon;

alter default privileges in schema public grant usage, select on sequences to authenticated;
alter default privileges in schema public grant usage, select on sequences to anon;
