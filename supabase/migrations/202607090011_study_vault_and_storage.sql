-- ==========================================================================
-- Consolidated Supabase Migration Module 11: 202607090011_study_vault_and_storage.sql
-- Authoritative baseline schema, functions, triggers, policies, and seeds.
-- ==========================================================================

-- 202607090016_storage_buckets.sql
-- Storage bucket registrations and read/write security policies

insert into storage.buckets (id, name, public)
values 
  ('avatars', 'avatars', true),
  ('banners', 'banners', true),
  ('room-covers', 'room-covers', true),
  ('community-covers', 'community-covers', true),
  ('event-banners', 'event-banners', true),
  ('post-images', 'post-images', true),
  ('post-videos', 'post-videos', true),
  ('reels', 'reels', true),
  ('stories', 'stories', true),
  ('chat-media', 'chat-media', true),
  ('gifts', 'gifts', true),
  ('stickers', 'stickers', true),
  ('badges', 'badges', true),
  ('frames', 'frames', true),
  ('entry-effects', 'entry-effects', true),
  ('thumbnails', 'thumbnails', true),
  ('study-files', 'study-files', false),
  ('study-covers', 'study-covers', true)
on conflict (id) do nothing;

drop policy if exists "Allow public read on storage objects" on storage.objects;

drop policy if exists "Allow authenticated upload on storage objects" on storage.objects;

drop policy if exists "Allow authenticated update on storage objects" on storage.objects;

drop policy if exists "Allow authenticated delete on storage objects" on storage.objects;

create policy "Allow public read on storage objects" on storage.objects for select using (true);

create policy "Allow authenticated upload on storage objects" on storage.objects for insert with check (auth.role() = 'authenticated');

create policy "Allow authenticated update on storage objects" on storage.objects for update using (auth.role() = 'authenticated');

create policy "Allow authenticated delete on storage objects" on storage.objects for delete using (auth.role() = 'authenticated');

drop table if exists public.cosmetic_assets cascade;

create trigger cosmetic_assets_view_trigger
instead of insert or update or delete on public.cosmetic_assets
for each row execute function public.sync_cosmetic_assets_view_to_definitions();

CREATE INDEX IF NOT EXISTS idx_study_vault_category_price ON study_vault_items(category, base_price_inr);

CREATE INDEX IF NOT EXISTS idx_study_vault_updated ON study_vault_items(updated_at DESC);

-- 4. Create storage bucket for report attachments if not exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('report-attachments', 'report-attachments', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage policies for report-attachments
CREATE POLICY "Allow public read access to report attachments"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'report-attachments');

CREATE POLICY "Allow authenticated users to upload report attachments"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'report-attachments' AND auth.role() = 'authenticated');

-- D. Retrieve User Vault History logs
create or replace function public.get_vault_history()
returns table (
  id uuid,
  action_type text,
  quantity integer,
  details jsonb,
  created_at timestamp with time zone,
  asset_name text,
  thumbnail_url text,
  rarity text
) as $$
begin
  return query
  select 
    vh.id,
    vh.action_type,
    vh.quantity,
    vh.details,
    vh.created_at,
    ad.display_name,
    ad.thumbnail_url,
    ad.rarity
  from public.vault_item_history vh
  join public.vault_items vi on vh.vault_item_id = vi.id
  join public.asset_definitions ad on vi.asset_id = ad.id
  where vh.user_id = auth.uid()
  order by vh.created_at desc;
end;
$$ language plpgsql security definer;

-- 8. Admin APIs for Vault Grants

-- A. Grant Asset to User
create or replace function public.admin_grant_vault_asset(p_user_id uuid, p_asset_id uuid, p_qty integer, p_duration_seconds bigint)
returns jsonb as $$
declare
  v_expiry timestamp with time zone := null;
begin
  -- Validate admin status
  if not exists (select 1 from public.admins where id = auth.uid()) then
    return jsonb_build_object('success', false, 'reason', 'Unauthorized admin action.');
  end if;

  if p_duration_seconds > 0 then
    v_expiry := now() + (p_duration_seconds || ' seconds')::interval;
  end if;

  insert into public.vault_items (
    user_id, asset_id, quantity, status, purchase_source, purchase_date, expires_at
  ) values (
    p_user_id,
    p_asset_id,
    p_qty,
    'Unlocked',
    'Admin Grant',
    now(),
    v_expiry
  )
  on conflict (user_id, asset_id) do update set
    quantity = vault_items.quantity + p_qty,
    expires_at = v_expiry;

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

