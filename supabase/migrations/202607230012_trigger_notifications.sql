-- 202607230012_trigger_notifications.sql
-- Database-level automatic triggers to insert notifications for important user interactions
alter table public.notifications add column if not exists push_dispatched boolean default false not null;

-- 1. Community Join/Leave/Kick Notifications
create or replace function public.handle_community_membership_notifications()
returns trigger as $$
declare
  v_community_name text;
  v_username text;
  v_owner_id uuid;
begin
  -- Fetch community name and owner
  select name, owner::uuid into v_community_name, v_owner_id 
  from public.communities 
  where id = coalesce(new.community_id, old.community_id);

  if (v_community_name is null) then
    v_community_name := 'a community';
  end if;

  if (tg_op = 'INSERT') then
    -- Get username of the person who joined
    select username into v_username from public.profiles where id = new.user_id;

    -- Notification for the user who joined
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.user_id,
      'Joined Community 🎉',
      'Welcome to ' || v_community_name || '! Start participating in discussions.',
      'community',
      jsonb_build_object(
        'communityId', new.community_id,
        'action', 'join'
      )
    );

    -- Notification for the community owner (if not the user themselves)
    if (v_owner_id is not null and v_owner_id <> new.user_id) then
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        v_owner_id,
        'New Community Member 👥',
        '@' || coalesce(v_username, 'Someone') || ' joined your community "' || v_community_name || '".',
        'community',
        jsonb_build_object(
          'communityId', new.community_id,
          'userId', new.user_id,
          'action', 'new_member'
        )
      );
    end if;

  elsif (tg_op = 'DELETE') then
    -- Get username of the person who left/was kicked
    select username into v_username from public.profiles where id = old.user_id;

    -- Check if self-initiated or kicked
    if (auth.uid() = old.user_id) then
      -- User left voluntarily
      if (v_owner_id is not null and v_owner_id <> old.user_id) then
        insert into public.notifications (user_id, title, body, type, payload)
        values (
          v_owner_id,
          'Member Left 👥',
          '@' || coalesce(v_username, 'Someone') || ' left your community "' || v_community_name || '".',
          'community',
          jsonb_build_object(
            'communityId', old.community_id,
            'userId', old.user_id,
            'action', 'member_left'
          )
        );
      end if;
    else
      -- User was kicked/removed by someone else
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        old.user_id,
        'Removed from Community 🚫',
        'You have been removed from the community "' || v_community_name || '".',
        'community',
        jsonb_build_object(
          'communityId', old.community_id,
          'action', 'removed'
        )
      );
    end if;
  end if;

  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists tr_community_membership_notifications on public.community_memberships;
create trigger tr_community_membership_notifications
  after insert or delete on public.community_memberships
  for each row execute function public.handle_community_membership_notifications();


-- 2. Follow / Connection Notifications (Follow, Follow Request, and Request Acceptance)
create or replace function public.handle_connections_notifications()
returns trigger as $$
declare
  v_follower_username text;
  v_following_username text;
begin
  if (tg_op = 'INSERT') then
    select username into v_follower_username from public.profiles where id = new.follower_id;

    if (new.status = 'requested') then
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        new.following_id,
        'Follow Request 👥',
        '@' || coalesce(v_follower_username, 'Someone') || ' requested to follow you.',
        'follow_request',
        jsonb_build_object(
          'userId', new.follower_id,
          'action', 'follow_request'
        )
      );
    else
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        new.following_id,
        'New Follower 🌟',
        '@' || coalesce(v_follower_username, 'Someone') || ' started following you!',
        'new_follower',
        jsonb_build_object(
          'userId', new.follower_id,
          'action', 'follow'
        )
      );
    end if;
  elsif (tg_op = 'UPDATE') then
    if (old.status = 'requested' and new.status = 'following') then
      select username into v_following_username from public.profiles where id = new.following_id;

      insert into public.notifications (user_id, title, body, type, payload)
      values (
        new.follower_id,
        'Follow Request Accepted 🎉',
        '@' || coalesce(v_following_username, 'Someone') || ' accepted your follow request.',
        'follow_request_accepted',
        jsonb_build_object(
          'userId', new.following_id,
          'action', 'follow_accepted'
        )
      );
    end if;
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists tr_connections_notifications on public.connections;
create trigger tr_connections_notifications
  after insert or update on public.connections
  for each row execute function public.handle_connections_notifications();


-- 3. Wallet Transactions Notifications
create or replace function public.handle_wallet_transaction_notifications()
returns trigger as $$
begin
  if (new.status = 'Completed') then
    if (new.amount > 0 and new.type in ('Deposit', 'Refund', 'Reward', 'Payout', 'Recharge', 'Bonus', 'Admin Grant')) then
      -- Coins / INR received
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        new.wallet_id,
        'Wallet Credited 🪙',
        'You have received ' || new.amount || ' ' || new.currency || ' (' || new.type || ').',
        'coins_received',
        jsonb_build_object(
          'transactionId', new.id,
          'action', 'credit'
        )
      );
    elsif (new.type = 'Withdrawal') then
      -- Withdrawal success
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        new.wallet_id,
        'Withdrawal Successful ✅',
        'Your withdrawal of ' || new.amount || ' INR has been successfully settled.',
        'withdrawal_success',
        jsonb_build_object(
          'transactionId', new.id,
          'action', 'withdrawal_success'
        )
      );
    end if;
  elsif (new.status = 'Pending') then
    if (new.type = 'Withdrawal') then
      -- Withdrawal requested
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        new.wallet_id,
        'Withdrawal Requested 💸',
        'Your withdrawal request of ' || new.amount || ' INR is pending approval.',
        'withdrawal_requested',
        jsonb_build_object(
          'transactionId', new.id,
          'action', 'withdrawal_requested'
        )
      );
    end if;
  elsif (new.status = 'Failed') then
    if (new.type = 'Withdrawal') then
      -- Withdrawal failed/rejected
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        new.wallet_id,
        'Withdrawal Rejected ❌',
        'Your withdrawal request of ' || new.amount || ' INR was rejected/failed.',
        'withdrawal_rejected',
        jsonb_build_object(
          'transactionId', new.id,
          'action', 'withdrawal_failed'
        )
      );
    end if;
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists tr_wallet_transaction_notifications on public.wallet_transactions;
create trigger tr_wallet_transaction_notifications
  after insert or update on public.wallet_transactions
  for each row execute function public.handle_wallet_transaction_notifications();


-- 4. Profile level ups, VIP, and verification status changes
create or replace function public.handle_profile_activity_notifications()
returns trigger as $$
begin
  -- 1. Level up (ID level)
  if (new.level > old.level) then
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.id,
      'Level Up! 🎉',
      'Congratulations! You reached ID Level ' || new.level || '.',
      'level_up_id',
      jsonb_build_object(
        'newLevel', new.level,
        'action', 'level_up'
      )
    );
  end if;

  -- 2. Level up (Career level)
  if (new.career_level > old.career_level) then
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.id,
      'Career Promotion! ⚔️',
      'You promoted to Career Level ' || new.career_level || '.',
      'level_up_career',
      jsonb_build_object(
        'newCareerLevel', new.career_level,
        'action', 'career_up'
      )
    );
  end if;

  -- 3. VIP level upgrade
  if (new.vip_level > old.vip_level) then
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.id,
      'VIP Level Upgraded 👑',
      'Congratulations! You upgraded to VIP Level ' || new.vip_level || '.',
      'vip_upgrade',
      jsonb_build_object(
        'newVipLevel', new.vip_level,
        'action', 'vip_up'
      )
    );
  end if;

  -- 4. Profile verification status
  if (new.verified = true and old.verified = false) then
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.id,
      'Verification Approved! ✅',
      'Your profile verification has been approved. The checkmark badge is now unlocked!',
      'verification_approved',
      jsonb_build_object('action', 'verified')
    );
  elsif (new.verified = false and old.verified = true) then
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.id,
      'Verification Revoked ⚠️',
      'Your profile verification checkmark badge has been revoked.',
      'verification_rejected',
      jsonb_build_object('action', 'unverified')
    );
  end if;

  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists tr_profile_activity_notifications on public.profiles;
create trigger tr_profile_activity_notifications
  after update of level, career_level, vip_level, verified on public.profiles
  for each row execute function public.handle_profile_activity_notifications();


-- 5. Community Applications (Join Requests, Approvals, Rejections)
create or replace function public.handle_community_applications_notifications()
returns trigger as $$
declare
  v_community_name text;
  v_owner_id uuid;
  v_username text;
begin
  select name, owner::uuid into v_community_name, v_owner_id 
  from public.communities 
  where id = new.community_id;

  if (v_community_name is null) then
    v_community_name := 'a community';
  end if;

  select username into v_username from public.profiles where id = new.user_id;

  if (tg_op = 'INSERT' and new.status = 'pending') then
    -- Notify community owner of new join request
    if (v_owner_id is not null) then
      insert into public.notifications (user_id, title, body, type, payload)
      values (
        v_owner_id,
        'New Join Request 👥',
        '@' || coalesce(v_username, 'Someone') || ' requested to join your community "' || v_community_name || '".',
        'community',
        jsonb_build_object(
          'communityId', new.community_id,
          'applicationId', new.id,
          'action', 'join_request'
        )
      );
    end if;
  elsif (tg_op = 'UPDATE' and old.status = 'pending' and new.status = 'approved') then
    -- Notify user request is approved
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.user_id,
      'Join Request Approved! 🎉',
      'Your request to join "' || v_community_name || '" has been approved.',
      'community',
      jsonb_build_object(
        'communityId', new.community_id,
        'action', 'join_approved'
      )
    );
  elsif (tg_op = 'UPDATE' and old.status = 'pending' and new.status = 'rejected') then
    -- Notify user request is rejected
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.user_id,
      'Join Request Rejected 🚫',
      'Your request to join "' || v_community_name || '" was rejected.',
      'community',
      jsonb_build_object(
        'communityId', new.community_id,
        'action', 'join_rejected'
      )
    );
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists tr_community_applications_notifications on public.community_applications;
create trigger tr_community_applications_notifications
  after insert or update on public.community_applications
  for each row execute function public.handle_community_applications_notifications();


-- 6. Gift Transactions (Virtual Gift Received)
create or replace function public.handle_gift_received_notifications()
returns trigger as $$
declare
  v_sender_username text;
  v_gift_name text;
begin
  if (new.status = 'Completed' and new.receiver_id is not null) then
    select username into v_sender_username from public.profiles where id = new.sender_id;
    select name into v_gift_name from public.gift_catalog where id = new.gift_id;

    insert into public.notifications (user_id, title, body, type, payload)
    values (
      new.receiver_id,
      'Gift Received 🎁',
      '@' || coalesce(v_sender_username, 'Someone') || ' sent you ' || new.quantity || ' ' || coalesce(v_gift_name, 'Gift') || '(s)!',
      'gift',
      jsonb_build_object(
        'transactionId', new.id,
        'senderId', new.sender_id,
        'senderName', coalesce(v_sender_username, 'Someone'),
        'giftId', new.gift_id,
        'action', 'gift_received'
      )
    );
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists tr_gift_received_notifications on public.gift_transactions;
create trigger tr_gift_received_notifications
  after insert or update of status on public.gift_transactions
  for each row execute function public.handle_gift_received_notifications();


-- 7. Voice Room Invites
create or replace function public.handle_room_invites_notifications()
returns trigger as $$
declare
  v_inviter_username text;
  v_room_name text;
begin
  select username into v_inviter_username from public.profiles where id = new.invited_by;
  select name into v_room_name from public.rooms where id = new.room_id;

  if (v_room_name is null) then
    v_room_name := 'Arena Room';
  end if;

  insert into public.notifications (user_id, title, body, type, payload)
  values (
    new.user_id,
    'Room Invitation 🎤',
    '@' || coalesce(v_inviter_username, 'Someone') || ' invited you to join their room "' || v_room_name || '".',
    'room',
    jsonb_build_object(
      'roomId', new.room_id,
      'userId', new.invited_by,
      'action', 'room_invite'
    )
  );
  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists tr_room_invites_notifications on public.room_invites;
create trigger tr_room_invites_notifications
  after insert on public.room_invites
  for each row execute function public.handle_room_invites_notifications();


-- 8. Post Likes
create or replace function public.handle_post_likes_notifications()
returns trigger as $$
declare
  v_liker_username text;
  v_post_owner_id uuid;
begin
  select user_id into v_post_owner_id from public.posts where id = new.post_id;
  select username into v_liker_username from public.profiles where id = new.user_id;

  if (v_post_owner_id is not null and v_post_owner_id <> new.user_id) then
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      v_post_owner_id,
      'New Like ❤️',
      '@' || coalesce(v_liker_username, 'Someone') || ' liked your post.',
      'like',
      jsonb_build_object(
        'postId', new.post_id,
        'likerName', coalesce(v_liker_username, 'Someone'),
        'action', 'post_like'
      )
    );
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists tr_post_likes_notifications on public.post_likes;
create trigger tr_post_likes_notifications
  after insert on public.post_likes
  for each row execute function public.handle_post_likes_notifications();


-- 9. Post Comments
create or replace function public.handle_post_comments_notifications()
returns trigger as $$
declare
  v_commenter_username text;
  v_post_owner_id uuid;
begin
  select user_id into v_post_owner_id from public.posts where id = new.post_id;
  select username into v_commenter_username from public.profiles where id = new.user_id;

  if (v_post_owner_id is not null and v_post_owner_id <> new.user_id) then
    insert into public.notifications (user_id, title, body, type, payload)
    values (
      v_post_owner_id,
      'New Comment 💬',
      '@' || coalesce(v_commenter_username, 'Someone') || ' commented: "' || substring(new.content from 1 for 30) || '..."',
      'comment',
      jsonb_build_object(
        'postId', new.post_id,
        'commentId', new.id,
        'commenterName', coalesce(v_commenter_username, 'Someone'),
        'action', 'post_comment'
      )
    );
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists tr_post_comments_notifications on public.post_comments;
create trigger tr_post_comments_notifications
  after insert on public.post_comments
  for each row execute function public.handle_post_comments_notifications();


-- 10. Followers Notification (Publish Post)
create or replace function public.handle_new_posts_notifications()
returns trigger as $$
declare
  v_publisher_username text;
begin
  select username into v_publisher_username from public.profiles where id = new.user_id;

  -- Notify all followers of the post publisher
  insert into public.notifications (user_id, title, body, type, payload)
  select 
    follower_id,
    'New Post 📝',
    '@' || coalesce(v_publisher_username, 'Someone') || ' published a new post.',
    'new_post',
    jsonb_build_object(
      'postId', new.id,
      'action', 'new_post'
    )
  from public.connections
  where following_id = new.user_id;

  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists tr_new_posts_notifications on public.posts;
create trigger tr_new_posts_notifications
  after insert on public.posts
  for each row execute function public.handle_new_posts_notifications();


-- 11. Community Announcements Notifications
create or replace function public.handle_community_announcement_notifications()
returns trigger as $$
declare
  v_community_name text;
begin
  select name into v_community_name from public.communities where id = new.community_id;
  if (v_community_name is null) then
    v_community_name := 'Community';
  end if;

  -- Notify all community members
  insert into public.notifications (user_id, title, body, type, payload)
  select 
    user_id,
    'Community Announcement 📢',
    '"' || v_community_name || '": ' || new.title,
    'community',
    jsonb_build_object(
      'communityId', new.community_id,
      'announcementId', new.id,
      'action', 'announcement'
    )
  from public.community_memberships
  where community_id = new.community_id;

  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists tr_community_announcement_notifications on public.community_announcements;
create trigger tr_community_announcement_notifications
  after insert on public.community_announcements
  for each row execute function public.handle_community_announcement_notifications();


-- 12. Community Events Notifications
create or replace function public.handle_community_event_notifications()
returns trigger as $$
declare
  v_community_name text;
begin
  select name into v_community_name from public.communities where id = new.community_id;
  if (v_community_name is null) then
    v_community_name := 'Community';
  end if;

  -- Notify all community members
  insert into public.notifications (user_id, title, body, type, payload)
  select 
    user_id,
    'New Community Event 🗓️',
    '"' || v_community_name || '" created event: ' || new.name,
    'community',
    jsonb_build_object(
      'communityId', new.community_id,
      'eventId', new.id,
      'action', 'event'
    )
  from public.community_memberships
  where community_id = new.community_id;

  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists tr_community_event_notifications on public.community_events;
create trigger tr_community_event_notifications
  after insert on public.community_events
  for each row execute function public.handle_community_event_notifications();
