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
