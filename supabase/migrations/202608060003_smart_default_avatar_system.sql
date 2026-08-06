-- Migration: 202608060003_smart_default_avatar_system.sql
-- Description: Smart Default Avatar Assignment System at Database Level

CREATE OR REPLACE FUNCTION public.smart_assign_default_avatar()
RETURNS TRIGGER AS $$
DECLARE
    v_gender text;
    v_random_num int;
    v_chosen_folder text;
    v_avatar_path text;
BEGIN
    -- Only assign a default avatar if the user has NO custom profile image
    -- (i.e. avatar_url is null, empty, or an old placeholder like dicebear)
    IF NEW.avatar_url IS NULL 
       OR TRIM(NEW.avatar_url) = '' 
       OR NEW.avatar_url LIKE '%dicebear%' THEN

        v_gender := LOWER(TRIM(COALESCE(NEW.gender, '')));
        v_random_num := floor(random() * 10 + 1)::int; -- Generates integer 1..10

        IF v_gender IN ('male', 'm', 'boy', 'man') THEN
            v_avatar_path := 'assets/creaniaa_avtar_auto/male/' || v_random_num || '.jpeg';
        ELSIF v_gender IN ('female', 'f', 'girl', 'woman') THEN
            v_avatar_path := 'assets/creaniaa_avtar_auto/female/' || v_random_num || '.jpeg';
        ELSE
            -- Neutral / Unknown / Prefer not to say
            -- Randomly pick between male and female folders
            IF random() < 0.5 THEN
                v_chosen_folder := 'male';
            ELSE
                v_chosen_folder := 'female';
            END IF;
            v_avatar_path := 'assets/creaniaa_avtar_auto/' || v_chosen_folder || '/' || v_random_num || '.jpeg';
        END IF;

        -- Permanently set the assigned avatar fields
        NEW.avatar_url := v_avatar_path;
        NEW.avatar := v_avatar_path;
        NEW.profile_photo := v_avatar_path;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger to profiles table for BEFORE INSERT OR UPDATE
DROP TRIGGER IF EXISTS trg_smart_default_avatar ON public.profiles;

CREATE TRIGGER trg_smart_default_avatar
BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.smart_assign_default_avatar();

-- Backfill existing profiles in DB that have missing/empty/dicebear avatars
DO $$
DECLARE
    r RECORD;
    v_gender text;
    v_random_num int;
    v_chosen_folder text;
    v_avatar_path text;
BEGIN
    FOR r IN 
        SELECT id, gender FROM public.profiles 
        WHERE avatar_url IS NULL 
           OR TRIM(avatar_url) = '' 
           OR avatar_url LIKE '%dicebear%'
    LOOP
        v_gender := LOWER(TRIM(COALESCE(r.gender, '')));
        v_random_num := floor(random() * 10 + 1)::int;

        IF v_gender IN ('male', 'm', 'boy', 'man') THEN
            v_avatar_path := 'assets/creaniaa_avtar_auto/male/' || v_random_num || '.jpeg';
        ELSIF v_gender IN ('female', 'f', 'girl', 'woman') THEN
            v_avatar_path := 'assets/creaniaa_avtar_auto/female/' || v_random_num || '.jpeg';
        ELSE
            IF random() < 0.5 THEN
                v_chosen_folder := 'male';
            ELSE
                v_chosen_folder := 'female';
            END IF;
            v_avatar_path := 'assets/creaniaa_avtar_auto/' || v_chosen_folder || '/' || v_random_num || '.jpeg';
        END IF;

        UPDATE public.profiles
        SET avatar_url = v_avatar_path,
            avatar = v_avatar_path,
            profile_photo = v_avatar_path
        WHERE id = r.id;
    END LOOP;
END;
$$;
