-- supabase/migrations/202607120007_remove_canonical_mapping.sql
-- Remove User Auth Mapping / Canonical ID layer and enforce auth.uid() everywhere

-- 1. Drop mappings table
drop table if exists public.user_auth_mappings cascade;

-- 2. Drop canonical_uid function
drop function if exists public.canonical_uid() cascade;

-- 3. Re-create handle_new_user trigger function without mapping
create or replace function public.handle_new_user()
returns trigger as $$
declare
  generated_uid bigint;
begin
  generated_uid := public.generate_unique_uid();

  begin
    insert into public.profiles (
      id, 
      uid,
      username, 
      email,
      phone,
      display_name,
      avatar_url, 
      profile_photo,
      vip_level, 
      novel_level, 
      level, 
      experience,
      verified
    )
    values (
      new.id,
      generated_uid,
      coalesce(new.raw_user_meta_data->>'username', 'user_' || substr(new.id::text, 1, 8)),
      new.email,
      new.phone,
      coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'full_name', 'Creania Student'),
      new.raw_user_meta_data->>'avatar_url',
      new.raw_user_meta_data->>'avatar_url',
      0,
      0,
      1,
      0,
      false
    )
    on conflict (id) do update set
      email = coalesce(profiles.email, excluded.email),
      phone = coalesce(profiles.phone, excluded.phone),
      display_name = coalesce(profiles.display_name, excluded.display_name),
      avatar_url = coalesce(profiles.avatar_url, excluded.avatar_url),
      profile_photo = coalesce(profiles.profile_photo, excluded.profile_photo);
  exception when unique_violation then
    -- Catch unique violation to prevent crash on duplicate email/username from unlinked social accounts
    begin
      insert into public.profiles (
        id, 
        uid,
        username, 
        email,
        phone,
        display_name,
        avatar_url, 
        profile_photo,
        vip_level, 
        novel_level, 
        level, 
        experience,
        verified
      )
      values (
        new.id,
        generated_uid,
        'user_' || substr(new.id::text, 1, 8) || '_' || (random() * 1000)::int::text,
        null, -- set to null to avoid unique violation
        null, -- set to null to avoid unique violation
        coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'full_name', 'Creania Student'),
        new.raw_user_meta_data->>'avatar_url',
        new.raw_user_meta_data->>'avatar_url',
        0,
        0,
        1,
        0,
        false
      );
    exception when others then
      -- Log and ignore failure so auth signup finishes
      raise notice 'Failed to insert profile: %', SQLERRM;
    end;
  end;

  return new;
end;
$$ language plpgsql security definer;

-- 4. Setup clean RLS policies for profiles (All users can view, only owner can edit)
drop policy if exists "Users can insert their own profile" on public.profiles;
drop policy if exists "Users can read their own profile" on public.profiles;
drop policy if exists "Users can update their own profile" on public.profiles;

create policy "Allow read access to everyone" on public.profiles for select using (true);
create policy "Allow insert access to owner" on public.profiles for insert with check (auth.uid() = id);
create policy "Allow update access to owner" on public.profiles for update using (auth.uid() = id);
create policy "Allow delete access to owner" on public.profiles for delete using (auth.uid() = id);

-- 5. Drop and recreate RLS policies of other tables to use auth.uid() directly
-- Wallets
drop policy if exists "Users can view their own wallet" on public.wallets;
drop policy if exists "Users can update their own wallet" on public.wallets;
create policy "Users can view their own wallet" on public.wallets for select using (auth.uid() = id);
create policy "Users can update their own wallet" on public.wallets for update using (auth.uid() = id);

-- Wallet Transactions
drop policy if exists "Users can view their transactions" on public.wallet_transactions;
create policy "Users can view their transactions" on public.wallet_transactions for select using (auth.uid() = wallet_id);

-- Purchase History
drop policy if exists "Users can view purchase history" on public.purchase_history;
create policy "Users can view purchase history" on public.purchase_history for select using (auth.uid() = user_id);

-- Gift History
drop policy if exists "Users can view sent/received gifts" on public.gift_history;
create policy "Users can view sent/received gifts" on public.gift_history for select using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- Withdraw History
drop policy if exists "Users can view withdrawal requests" on public.withdraw_history;
create policy "Users can view withdrawal requests" on public.withdraw_history for select using (auth.uid() = user_id);

-- Inventory
drop policy if exists "Users can view their inventory" on public.inventory;
create policy "Users can view their inventory" on public.inventory for select using (auth.uid() = user_id);

-- Study Vault Items
drop policy if exists "Users can upload resources" on public.study_vault_items;
create policy "Users can upload resources" on public.study_vault_items for insert with check (auth.uid() = seller_id);

-- Reading History
drop policy if exists "Users can modify their own history" on public.reading_history;
create policy "Users can modify their own history" on public.reading_history for all using (auth.uid() = user_id);

-- Messages
drop policy if exists "Users can view messages" on public.messages;
drop policy if exists "Users can insert messages" on public.messages;
create policy "Users can view messages" on public.messages for select using (not is_private or auth.uid() = sender_id or auth.uid() = receiver_id);
create policy "Users can insert messages" on public.messages for insert with check (auth.uid() = sender_id);

-- Notifications
drop policy if exists "Users can view their notifications" on public.notifications;
create policy "Users can view their notifications" on public.notifications for select using (auth.uid() = user_id);

-- Communities
drop policy if exists "Allow write access to own communities" on public.communities;
create policy "Allow write access to own communities" on public.communities for all using (auth.uid() = owner);

-- Events
drop policy if exists "Allow write access to event creators" on public.events;
create policy "Allow write access to event creators" on public.events for all using (auth.uid() = creator_id);

-- Posts
drop policy if exists "Allow write access to own posts" on public.posts;
create policy "Allow write access to own posts" on public.posts for all using (auth.uid() = user_id);

-- Post Likes
drop policy if exists "Allow write access to own likes" on public.post_likes;
create policy "Allow write access to own likes" on public.post_likes for all using (auth.uid() = user_id);

-- Post Bookmarks
drop policy if exists "Allow write access to own bookmarks" on public.post_bookmarks;
create policy "Allow write access to own bookmarks" on public.post_bookmarks for all using (auth.uid() = user_id);

-- Post Comments
drop policy if exists "Allow write access to own comments" on public.post_comments;
create policy "Allow write access to own comments" on public.post_comments for all using (auth.uid() = user_id);

-- Stories
drop policy if exists "Allow write access to own stories" on public.stories;
create policy "Allow write access to own stories" on public.stories for all using (auth.uid() = user_id);

-- Story Views
drop policy if exists "Allow write access to own views" on public.story_views;
create policy "Allow write access to own views" on public.story_views for all using (auth.uid() = viewer_id);

-- Connections
drop policy if exists "Allow write access to own connections" on public.connections;
create policy "Allow write access to own connections" on public.connections for all using (auth.uid() = follower_id or auth.uid() = following_id);

-- User Customizations
drop policy if exists "Allow write access to own customizations" on public.user_customizations;
create policy "Allow write access to own customizations" on public.user_customizations for all using (auth.uid() = user_id);

-- Daily Tasks Progress
drop policy if exists "Allow write access to own tasks" on public.user_daily_tasks;
create policy "Allow write access to own tasks" on public.user_daily_tasks for all using (auth.uid() = user_id);
