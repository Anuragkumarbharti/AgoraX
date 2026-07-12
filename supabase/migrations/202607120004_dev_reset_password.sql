-- supabase/migrations/202607120004_dev_reset_password.sql
-- Function to allow sandbox password reset for development

create or replace function public.dev_reset_password(
  user_email text,
  user_phone text,
  new_password text
)
returns boolean
security definer
language plpgsql
as $$
declare
  target_user_id uuid;
begin
  -- Find the user ID by email or phone
  if user_email is not null and user_email <> '' then
    select id into target_user_id from auth.users where email = user_email;
  elsif user_phone is not null and user_phone <> '' then
    select id into target_user_id from auth.users where phone = user_phone;
  end if;

  if target_user_id is null then
    return false;
  end if;

  -- Update auth.users password using blowfish (bf) hashing
  update auth.users
  set encrypted_password = crypt(new_password, gen_salt('bf'))
  where id = target_user_id;

  return true;
end;
$$;

-- Grant execution privilege to anon and authenticated roles
grant execute on function public.dev_reset_password to anon;
grant execute on function public.dev_reset_password to authenticated;
