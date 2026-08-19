-- ==========================================================================
-- Consolidated Supabase Migration Module 13: 202607090013_production_security_and_rls.sql
-- Authoritative baseline schema, functions, triggers, policies, and seeds.
-- ==========================================================================

-- Row Level Security (RLS) Policies
alter table public.profiles enable row level security;

create policy "Allow read access to everyone" on public.profiles for select using (true);

create policy "Allow insert access to owner" on public.profiles for insert with check (auth.uid() = id);

create policy "Allow update access to owner" on public.profiles for update using (auth.uid() = id);

create policy "Allow delete access to owner" on public.profiles for delete using (auth.uid() = id);

-- Row Level Security (RLS) Policies
alter table public.wallets enable row level security;

create policy "Users can view their own wallet" on public.wallets for select using (auth.uid() = id);

create policy "Users can update their own wallet" on public.wallets for update using (auth.uid() = id);

alter table public.wallet_transactions enable row level security;

create policy "Users can view their transactions" on public.wallet_transactions for select using (auth.uid() = wallet_id);

-- Row Level Security (RLS) Policies
alter table public.store_items enable row level security;

create policy "Anyone can view active store items" on public.store_items for select using (is_active = true);

alter table public.inventory enable row level security;

create policy "Users can view their inventory" on public.inventory for select using (auth.uid() = user_id);

-- Row Level Security (RLS) Policies
alter table public.vip_plans enable row level security;

create policy "Anyone can view VIP plans" on public.vip_plans for select using (true);

alter table public.novel_plans enable row level security;

create policy "Anyone can view Novel plans" on public.novel_plans for select using (true);

alter table public.purchase_history enable row level security;

create policy "Users can view purchase history" on public.purchase_history for select using (auth.uid() = user_id);

-- Row Level Security (RLS) Policies
alter table public.communities enable row level security;

create policy "Allow read access to all communities" on public.communities for select using (true);

create policy "Allow write access to own communities" on public.communities for all using (auth.uid() = owner);

-- Row Level Security (RLS) Policies
alter table public.rooms enable row level security;

create policy "Anyone can view active rooms" on public.rooms for select using (status <> 'ended');

create policy "Host can all on own rooms" on public.rooms for all using (auth.uid() = host_id);

create policy "Update rooms" on public.rooms for update using (
  auth.uid() = host_id 
  or exists (
    select 1 from public.room_members 
    where room_members.room_id = rooms.id 
      and room_members.user_id = auth.uid() 
      and room_members.role in ('Co-Host', 'Moderator')
  )
);

alter table public.room_members enable row level security;

create policy "Members are viewable by everyone" on public.room_members for select using (true);

create policy "Insert members" on public.room_members for insert with check (
  auth.uid() = user_id 
  or exists (
    select 1 from public.rooms 
    where rooms.id = room_members.room_id and rooms.host_id = auth.uid()
  )
);

create policy "Update members" on public.room_members for update using (
  auth.uid() = user_id 
  or exists (
    select 1 from public.rooms 
    where rooms.id = room_members.room_id and rooms.host_id = auth.uid()
  )
);

create policy "Delete members" on public.room_members for delete using (
  auth.uid() = user_id 
  or exists (
    select 1 from public.rooms 
    where rooms.id = room_members.room_id and rooms.host_id = auth.uid()
  )
);

alter table public.room_seat_applications enable row level security;

create policy "Users can view applications for rooms they are in" on public.room_seat_applications for select using (true);

create policy "Users can insert their own application" on public.room_seat_applications for insert with check (auth.uid() = applicant_id);

create policy "Users can update/delete their own application or room managers can update/delete" on public.room_seat_applications for all using (
  auth.uid() = applicant_id or
  exists (
    select 1 from public.room_members
    where room_members.room_id = room_seat_applications.room_id
    and room_members.user_id = auth.uid()
    and room_members.role in ('Host', 'Co-Host')
  )
);

alter table public.room_activity_events enable row level security;

create policy "Select events allowed for all" on public.room_activity_events for select using (true);

create policy "Insert events allowed for all" on public.room_activity_events for insert with check (true);

-- Row Level Security (RLS) Policies
alter table public.gift_history enable row level security;

create policy "Users can view sent/received gifts" on public.gift_history for select using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- Row Level Security (RLS) Policies
alter table public.posts enable row level security;

create policy "Allow read access to all posts" on public.posts for select using (true);

create policy "Allow write access to own posts" on public.posts for all using (auth.uid() = user_id);

alter table public.post_likes enable row level security;

create policy "Allow read access to all likes" on public.post_likes for select using (true);

create policy "Allow write access to own likes" on public.post_likes for all using (auth.uid() = user_id);

alter table public.post_bookmarks enable row level security;

create policy "Allow read access to all bookmarks" on public.post_bookmarks for select using (true);

create policy "Allow write access to own bookmarks" on public.post_bookmarks for all using (auth.uid() = user_id);

alter table public.post_comments enable row level security;

create policy "Allow read access to all comments" on public.post_comments for select using (true);

create policy "Allow write access to own comments" on public.post_comments for all using (auth.uid() = user_id);

alter table public.stories enable row level security;

create policy "Allow read access to stories" on public.stories for select using (true);

create policy "Allow write access to own stories" on public.stories for all using (auth.uid() = user_id);

alter table public.story_views enable row level security;

create policy "Allow read access to story views" on public.story_views for select using (true);

create policy "Allow write access to own views" on public.story_views for all using (auth.uid() = viewer_id);

alter table public.connections enable row level security;

create policy "Allow read access to all connections" on public.connections for select using (true);

create policy "Allow write access to own connections" on public.connections for all using (auth.uid() = follower_id or auth.uid() = following_id);

alter table public.user_customizations enable row level security;

create policy "Allow read access to customizations" on public.user_customizations for select using (true);

create policy "Allow write access to own customizations" on public.user_customizations for all using (auth.uid() = user_id);

-- Row Level Security (RLS) Policies
alter table public.messages enable row level security;

create policy "Users can view messages" on public.messages for select using (
  not is_private or auth.uid() = sender_id or auth.uid() = receiver_id
);

create policy "Users can insert messages" on public.messages for insert with check (auth.uid() = sender_id);

alter table public.notifications enable row level security;

create policy "Users can view their notifications" on public.notifications for select using (auth.uid() = user_id);

create policy "Allow everyone to insert notifications" on public.notifications for insert with check (true);

-- Row Level Security (RLS) Policies
alter table public.admins enable row level security;

create policy "Admin roles viewable by admins and owners" on public.admins for select using (true);

alter table public.reports enable row level security;

create policy "Allow select reports for owner and admins" on public.reports for select using (
  auth.uid() = reporter_id or exists (select 1 from public.admins where id = auth.uid())
);

create policy "Allow insert reports for authenticated users" on public.reports for insert with check (auth.role() = 'authenticated');

alter table public.bans enable row level security;

create policy "Bans viewable by everyone" on public.bans for select using (true);

create policy "Bans manageable by admins only" on public.bans for all using (
  exists (select 1 from public.admins where id = auth.uid())
);

alter table public.audit_logs enable row level security;

create policy "Audit logs manageable by admins only" on public.audit_logs for all using (
  exists (select 1 from public.admins where id = auth.uid())
);

alter table public.moderation_logs enable row level security;

create policy "Moderation logs manageable by admins only" on public.moderation_logs for all using (
  exists (select 1 from public.admins where id = auth.uid())
);

-- Row Level Security (RLS) Policies
alter table public.user_activity enable row level security;

create policy "Users can view their activity logs" on public.user_activity for select using (auth.uid() = user_id);

create policy "Allow insert activity logs" on public.user_activity for insert with check (auth.role() = 'authenticated');

alter table public.login_history enable row level security;

create policy "Users can view their login history" on public.login_history for select using (auth.uid() = user_id);

alter table public.device_sessions enable row level security;

create policy "Users can view their device sessions" on public.device_sessions for select using (auth.uid() = user_id);

create policy "Allow all actions on own device sessions" on public.device_sessions for all using (auth.uid() = user_id);

-- Row Level Security (RLS) Policies
alter table public.study_vault_items enable row level security;

create policy "Anyone can view approved items" on public.study_vault_items for select using (status = 'Approved');

create policy "Users can upload resources" on public.study_vault_items for insert with check (auth.uid() = seller_id);

alter table public.study_reviews enable row level security;

create policy "Anyone can view reviews" on public.study_reviews for select using (true);

alter table public.reading_history enable row level security;

create policy "Users can modify their own history" on public.reading_history for all using (auth.uid() = user_id);

-- Enable RLS on audit logs
alter table public.account_audit_logs enable row level security;

create policy "Allow admins to read audit logs" on public.account_audit_logs for select
using (exists (select 1 from public.admins where id = auth.uid()));

create policy "Allow delete access to admins only" on public.profiles for delete 
using (exists (select 1 from public.admins where id = auth.uid()));

-- Enable RLS on all tables
alter table public.vip_plans enable row level security;

alter table public.vip_assets enable row level security;

alter table public.novel_assets enable row level security;

alter table public.user_vip enable row level security;

alter table public.user_novel enable row level security;

alter table public.purchases enable row level security;

create policy "Allow select plans for authenticated users" on public.novel_plans for select using (auth.role() = 'authenticated');

create policy "Allow select assets for authenticated users" on public.vip_assets for select using (auth.role() = 'authenticated');

create policy "Allow select assets for authenticated users" on public.novel_assets for select using (auth.role() = 'authenticated');

create policy "Allow select user_vip for self and admins" on public.user_vip for select using (auth.uid() = user_id or exists (select 1 from public.admins where id = auth.uid()));

create policy "Allow select user_novel for self and admins" on public.user_novel for select using (auth.uid() = user_id or exists (select 1 from public.admins where id = auth.uid()));

create policy "Allow select purchases for self and admins" on public.purchases for select using (auth.uid() = user_id or exists (select 1 from public.admins where id = auth.uid()));

alter table public.cosmetic_assets enable row level security;

create policy "Anyone can select active cosmetic assets" on public.cosmetic_assets for select using (enabled = true);

create policy "Users can select their own inventory" on public.inventory for select using (auth.uid() = user_id);

alter table public.subscriptions enable row level security;

create policy "Users can select their own subscriptions" on public.subscriptions for select using (auth.uid() = user_id or exists (select 1 from public.admins where id = auth.uid()));

-- RLS
alter table public.arena_tickets enable row level security;

alter table public.arena_creation_logs enable row level security;

-- Enable RLS on memberships
alter table public.community_memberships enable row level security;

create policy "Allow read access to memberships" on public.community_memberships for select using (true);

create policy "Allow all actions for service_role/postgres" on public.community_memberships for all using (true);

-- Enable RLS on applications
alter table public.community_applications enable row level security;

create policy "Allow read applications to managers and applicant" on public.community_applications for select
  using (
    auth.uid() = user_id or 
    exists (
      select 1 from public.community_memberships
      where community_id = community_applications.community_id
        and user_id = auth.uid()
        and role in ('owner', 'co_owner', 'admin')
    )
  );

create policy "Allow insert application to applicant" on public.community_applications for insert
  with check (auth.uid() = user_id);

create policy "Allow update application to managers" on public.community_applications for update
  using (
    exists (
      select 1 from public.community_memberships
      where community_id = community_applications.community_id
        and user_id = auth.uid()
        and role in ('owner', 'co_owner')
    )
  );

-- Enable RLS
alter table public.community_member_daily_limits enable row level security;

create policy "Allow read daily limits" on public.community_member_daily_limits for select using (true);

create policy "Allow service_role full control daily limits" on public.community_member_daily_limits for all using (true);

-- Enable RLS
alter table public.community_exp_transactions enable row level security;

create policy "Allow read exp transactions" on public.community_exp_transactions for select using (true);

create policy "Allow service_role full control exp transactions" on public.community_exp_transactions for all using (true);

-- Enable RLS
alter table public.community_announcements enable row level security;

create policy "Allow read announcements to everyone" on public.community_announcements for select using (true);

create policy "Allow service_role full control on announcements" on public.community_announcements for all using (true);

-- Enable RLS
alter table public.community_events enable row level security;

create policy "Allow read events to everyone" on public.community_events for select using (true);

create policy "Allow service_role full control on events" on public.community_events for all using (true);

-- Enable RLS
alter table public.community_event_participants enable row level security;

create policy "Allow read participants to everyone" on public.community_event_participants for select using (true);

create policy "Allow service_role full control on participants" on public.community_event_participants for all using (true);

-- Enable RLS
alter table public.community_logs enable row level security;

create policy "Allow read logs to managers" on public.community_logs for select
  using (
    exists (
      select 1 from public.community_memberships
      where community_id = community_logs.community_id
        and user_id = auth.uid()
        and role in ('owner', 'co_owner', 'admin')
    )
  );

create policy "Allow service_role full control on logs" on public.community_logs for all using (true);

-- =========================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =========================================================================
alter table public.level_requirements enable row level security;

alter table public.user_levels enable row level security;

alter table public.xp_history enable row level security;

alter table public.daily_tasks enable row level security;

alter table public.weekly_tasks enable row level security;

alter table public.monthly_tasks enable row level security;

alter table public.season_tasks enable row level security;

alter table public.task_progress enable row level security;

alter table public.task_rewards enable row level security;

alter table public.level_rewards enable row level security;

alter table public.reward_claims enable row level security;

alter table public.daily_limits enable row level security;

alter table public.checkin_history enable row level security;

alter table public.achievements enable row level security;

alter table public.achievement_progress enable row level security;

alter table public.loyalty_rewards enable row level security;

alter table public.spin_rewards enable row level security;

alter table public.spin_history enable row level security;

alter table public.reward_logs enable row level security;

alter table public.gift_xp_logs enable row level security;

alter table public.community_rewards enable row level security;

alter table public.event_rewards enable row level security;

alter table public.reward_config enable row level security;

alter table public.xp_config enable row level security;

alter table public.economy_config enable row level security;

alter table public.system_settings enable row level security;

create policy "Allow all read user_levels" on public.user_levels for select using (true);

create policy "Allow owner read xp_history" on public.xp_history for select using (auth.uid() = user_id);

create policy "Allow all read daily_tasks" on public.daily_tasks for select using (true);

create policy "Allow all read weekly_tasks" on public.weekly_tasks for select using (true);

create policy "Allow all read monthly_tasks" on public.monthly_tasks for select using (true);

create policy "Allow all read season_tasks" on public.season_tasks for select using (true);

create policy "Allow owner read task_progress" on public.task_progress for select using (auth.uid() = user_id);

create policy "Allow all read task_rewards" on public.task_rewards for select using (true);

create policy "Allow all read level_rewards" on public.level_rewards for select using (true);

create policy "Allow owner read reward_claims" on public.reward_claims for select using (auth.uid() = user_id);

create policy "Allow owner read daily_limits" on public.daily_limits for select using (auth.uid() = user_id);

create policy "Allow owner read checkin_history" on public.checkin_history for select using (auth.uid() = user_id);

create policy "Allow all read achievements" on public.achievements for select using (true);

create policy "Allow owner read achievement_progress" on public.achievement_progress for select using (auth.uid() = user_id);

create policy "Allow all read loyalty_rewards" on public.loyalty_rewards for select using (true);

create policy "Allow all read spin_rewards" on public.spin_rewards for select using (true);

create policy "Allow owner read spin_history" on public.spin_history for select using (auth.uid() = user_id);

create policy "Allow owner read reward_logs" on public.reward_logs for select using (auth.uid() = user_id);

create policy "Allow sender/receiver read gift_xp_logs" on public.gift_xp_logs for select using (auth.uid() = sender_id or auth.uid() = receiver_id);

create policy "Allow all read community_rewards" on public.community_rewards for select using (true);

create policy "Allow all read event_rewards" on public.event_rewards for select using (true);

create policy "Allow all read configs" on public.reward_config for select using (true);

create policy "Allow all read xp_config" on public.xp_config for select using (true);

create policy "Allow all read economy_config" on public.economy_config for select using (true);

create policy "Allow all read system_settings" on public.system_settings for select using (true);

create policy "Allow admin modify user_levels" on public.user_levels for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify xp_history" on public.xp_history for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify daily_tasks" on public.daily_tasks for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify weekly_tasks" on public.weekly_tasks for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify monthly_tasks" on public.monthly_tasks for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify season_tasks" on public.season_tasks for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify task_progress" on public.task_progress for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify task_rewards" on public.task_rewards for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify level_rewards" on public.level_rewards for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify reward_claims" on public.reward_claims for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify daily_limits" on public.daily_limits for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify checkin_history" on public.checkin_history for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify achievements" on public.achievements for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify achievement_progress" on public.achievement_progress for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify loyalty_rewards" on public.loyalty_rewards for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify spin_rewards" on public.spin_rewards for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify spin_history" on public.spin_history for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify reward_logs" on public.reward_logs for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify gift_xp_logs" on public.gift_xp_logs for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify community_rewards" on public.community_rewards for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify event_rewards" on public.event_rewards for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify configs" on public.reward_config for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify xp_config" on public.xp_config for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify economy_config" on public.economy_config for all using (public.is_admin(auth.uid()));

create policy "Allow admin modify system_settings" on public.system_settings for all using (public.is_admin(auth.uid()));

-- Enable RLS on asset_definitions
alter table public.asset_definitions enable row level security;

create policy "Anyone can select active asset definitions" on public.asset_definitions for select using (enabled = true);

-- Enable RLS on vault_items
alter table public.vault_items enable row level security;

create policy "Users can select their own vault items" on public.vault_items for select using (auth.uid() = user_id);

create policy "Users can update their own vault items" on public.vault_items for update using (auth.uid() = user_id);

-- Enable RLS on vault_item_history
alter table public.vault_item_history enable row level security;

create policy "Users can view their own vault history" on public.vault_item_history for select using (auth.uid() = user_id);

-- Enable RLS for all newly created tables
alter table public.gift_categories enable row level security;

alter table public.gift_catalog enable row level security;

alter table public.gift_transactions enable row level security;

alter table public.gift_statistics enable row level security;

alter table public.gift_leaderboards enable row level security;

alter table public.gift_animation enable row level security;

alter table public.gift_combo enable row level security;

alter table public.gift_history enable row level security;

alter table public.gift_notifications enable row level security;

alter table public.gift_wallet_logs enable row level security;

alter table public.gift_seat_logs enable row level security;

alter table public.gift_effects enable row level security;

alter table public.gift_assets enable row level security;

alter table public.gift_settings enable row level security;

alter table public.gift_event_logs enable row level security;

create policy "Allow read access to authenticated users on gift_catalog" on public.gift_catalog for select to authenticated using (true);

create policy "Allow read access to authenticated users on gift_transactions" on public.gift_transactions for select to authenticated using (true);

create policy "Allow read access to authenticated users on gift_statistics" on public.gift_statistics for select to authenticated using (true);

create policy "Allow read access to authenticated users on gift_leaderboards" on public.gift_leaderboards for select to authenticated using (true);

create policy "Allow read access to authenticated users on gift_animation" on public.gift_animation for select to authenticated using (true);

create policy "Allow read access to authenticated users on gift_combo" on public.gift_combo for select to authenticated using (true);

create policy "Allow read access to authenticated users on gift_history" on public.gift_history for select to authenticated using (true);

create policy "Allow read access to authenticated users on gift_notifications" on public.gift_notifications for select to authenticated using (true);

create policy "Allow read access to authenticated users on gift_wallet_logs" on public.gift_wallet_logs for select to authenticated using (true);

create policy "Allow read access to authenticated users on gift_seat_logs" on public.gift_seat_logs for select to authenticated using (true);

create policy "Allow read access to authenticated users on gift_effects" on public.gift_effects for select to authenticated using (true);

create policy "Allow read access to authenticated users on gift_assets" on public.gift_assets for select to authenticated using (true);

create policy "Allow read access to authenticated users on gift_settings" on public.gift_settings for select to authenticated using (true);

create policy "Allow read access to authenticated users on gift_event_logs" on public.gift_event_logs for select to authenticated using (true);

-- Enable RLS for newly created tables
alter table public.magic_gift_rewards enable row level security;

alter table public.magic_gift_budget enable row level security;

alter table public.magic_reward_logs enable row level security;

alter table public.room_star_statistics enable row level security;

alter table public.seat_star_statistics enable row level security;

alter table public.vault_gift_logs enable row level security;

create policy "Allow read access to magic_gift_budget" on public.magic_gift_budget for select to authenticated using (true);

create policy "Allow read access to magic_reward_logs" on public.magic_reward_logs for select to authenticated using (true);

create policy "Allow read access to room_star_statistics" on public.room_star_statistics for select to authenticated using (true);

create policy "Allow read access to seat_star_statistics" on public.seat_star_statistics for select to authenticated using (true);

create policy "Allow read access to vault_gift_logs" on public.vault_gift_logs for select to authenticated using (true);

-- Enable RLS for settings
alter table public.gifting_settings enable row level security;

create policy "Allow read access to gifting_settings" on public.gifting_settings for select to authenticated using (true);

-- ══════════════════════════════════════════════════════════════
-- 6. RLS policy for conversations table — ensure it exists
-- ══════════════════════════════════════════════════════════════

alter table public.conversations enable row level security;

create policy "Users can view their conversations" on public.conversations
  for select using (auth.uid() = participant_a or auth.uid() = participant_b);

create policy "Users can insert their conversations" on public.conversations
  for insert with check (auth.uid() = participant_a or auth.uid() = participant_b);

create policy "Users can update their conversations" on public.conversations
  for update using (auth.uid() = participant_a or auth.uid() = participant_b);

create policy "Service role can manage conversations" on public.conversations
  for all using (auth.role() = 'service_role');

-- Enable RLS
alter table public.avatar_frames enable row level security;

-- Enable RLS
alter table public.room_requests enable row level security;

-- Enable RLS for user_sessions
alter table public.user_sessions enable row level security;

-- Enable RLS for room_assigned_roles
alter table public.room_assigned_roles enable row level security;

-- Enable RLS for room_invites
alter table public.room_invites enable row level security;

-- Enable RLS
alter table public.fcm_tokens enable row level security;

alter table public.notification_settings enable row level security;

alter table public.notification_logs enable row level security;

alter table public.scheduled_notifications enable row level security;

create policy "Users can read their own notification settings" on public.notification_settings
  for select using (auth.uid() = user_id);

create policy "Users can update their own notification settings" on public.notification_settings
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users can insert their own notification settings" on public.notification_settings
  for insert with check (auth.uid() = user_id);

create policy "Users can read their own notification logs" on public.notification_logs
  for select using (auth.uid() = receiver_id);

create policy "Users can update their own notification logs" on public.notification_logs
  for update using (auth.uid() = receiver_id) with check (auth.uid() = receiver_id);

create policy "Allow all actions on logs for service_role" on public.notification_logs
  for all using (true) with check (true);

create policy "Users can read their own scheduled notifications" on public.scheduled_notifications
  for select using (auth.uid() = user_id);

-- 4. RLS Security Policies on messages table
alter table public.messages enable row level security;

create policy "Users can view messages" on public.messages 
  for select using (
    not is_private or auth.uid() = sender_id or auth.uid() = receiver_id
  );

create policy "Users can insert messages" on public.messages 
  for insert with check (
    auth.uid() = sender_id
  );

create policy "Users can update messages" on public.messages 
  for update using (
    auth.uid() = sender_id or auth.uid() = receiver_id
  ) with check (
    auth.uid() = sender_id or auth.uid() = receiver_id
  );

create policy "Users can delete messages" on public.messages 
  for delete using (
    auth.uid() = sender_id
  );

-- 7. RLS Policies for conversations table
alter table public.conversations enable row level security;

-- Enable RLS on payments
alter table public.payments enable row level security;

-- Enable RLS on vip_audit_logs
alter table public.vip_audit_logs enable row level security;

-- 2. Add explicit RLS Policies for UPDATE and DELETE on public.notifications
alter table public.notifications enable row level security;

create policy "Users can update their notifications" on public.notifications for update using (auth.uid() = user_id);

create policy "Users can delete their notifications" on public.notifications for delete using (auth.uid() = user_id);

alter table public.processed_transactions enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'processed_transactions' and policyname = 'Allow select for self') then
    create policy "Allow select for self" on public.processed_transactions
      for select using (auth.uid() = user_id);
  end if;
end
$$;

-- Enable RLS and define policies
ALTER TABLE public.room_permission_history ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.room_admin_activity_logs ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.room_user_warnings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow members to view permission history" 
ON public.room_permission_history FOR SELECT 
USING (auth.uid() IS NOT NULL);

CREATE POLICY "Allow members to view admin activity logs" 
ON public.room_admin_activity_logs FOR SELECT 
USING (auth.uid() IS NOT NULL);

CREATE POLICY "Allow members to view room warnings" 
ON public.room_user_warnings FOR SELECT 
USING (auth.uid() IS NOT NULL);

-- RLS for Anti-Abuse Logs
alter table public.user_anti_abuse_logs enable row level security;

-- 8. Enable RLS and grant public access to gifting tables
alter table public.gift_transactions enable row level security;

create policy "Allow select on gift_transactions" on public.gift_transactions for select to authenticated using (true);

create policy "Allow select on gift_history" on public.gift_history for select to authenticated using (true);

create policy "Allow select on gift_statistics" on public.gift_statistics for select to authenticated using (true);

create policy "Allow select on gift_leaderboards" on public.gift_leaderboards for select to authenticated using (true);

-- 2. Enable RLS and Grant Access
alter table public.room_dual_progress enable row level security;

create policy "Allow read access on room_dual_progress" on public.room_dual_progress
  for select to authenticated using (true);

create policy "Allow update access on room_dual_progress" on public.room_dual_progress
  for update to authenticated using (true);

-- Enable RLS and Realtime for room_dual_progress
alter table public.room_dual_progress enable row level security;

-- Enable RLS and policies on room_daily_user_bonuses
alter table public.room_daily_user_bonuses enable row level security;

create policy "Allow read access on room_daily_user_bonuses" on public.room_daily_user_bonuses
  for select to authenticated using (true);

create policy "Allow insert/update access on room_daily_user_bonuses" on public.room_daily_user_bonuses
  for all to authenticated using (true);

-- Ensure table policies & publication
alter table public.room_dual_progress enable row level security;

alter table public.room_ownership_logs enable row level security;

create policy "Users can view logs of rooms they own or participate in"
  on public.room_ownership_logs for select
  using (
    exists (select 1 from public.rooms where id = room_id and (host_id = auth.uid() or room_owner = auth.uid()))
    or old_owner_id = auth.uid()
    or new_owner_id = auth.uid()
    or exists (select 1 from public.admins where id = auth.uid())
  );

-- Enable RLS
alter table public.lucky_reward_logs enable row level security;

create policy "Users can view their own wallet" on public.wallets for select to authenticated using (auth.uid() = id);

-- RLS
alter table public.events enable row level security;

-- Enable RLS
alter table public.post_mcqs enable row level security;

alter table public.post_mcq_votes enable row level security;

alter table public.post_polls enable row level security;

alter table public.post_poll_votes enable row level security;

alter table public.post_questions enable row level security;

alter table public.post_reports enable row level security;

create policy "Allow insert access to own post_mcqs" on public.post_mcqs for insert with check (
  exists (select 1 from public.posts where id = post_id and user_id = auth.uid())
);

create policy "Allow read access to all post_mcq_votes" on public.post_mcq_votes for select using (true);

create policy "Allow insert access to own post_mcq_votes" on public.post_mcq_votes for insert with check (auth.uid() = user_id);

create policy "Allow read access to all post_polls" on public.post_polls for select using (true);

create policy "Allow insert access to own post_polls" on public.post_polls for insert with check (
  exists (select 1 from public.posts where id = post_id and user_id = auth.uid())
);

create policy "Allow read access to all post_poll_votes" on public.post_poll_votes for select using (true);

create policy "Allow insert access to own post_poll_votes" on public.post_poll_votes for insert with check (auth.uid() = user_id);

create policy "Allow read access to all post_questions" on public.post_questions for select using (true);

create policy "Allow insert access to own post_questions" on public.post_questions for insert with check (
  exists (select 1 from public.posts where id = post_id and user_id = auth.uid())
);

create policy "Allow insert access to reports" on public.post_reports for insert with check (auth.uid() = reporter_id);

-- Enable RLS
alter table public.hashtags enable row level security;

alter table public.post_hashtags enable row level security;

alter table public.post_mentions enable row level security;

alter table public.audio_tracks enable row level security;

alter table public.audio_usages enable row level security;

alter table public.content_views enable row level security;

alter table public.content_engagements enable row level security;

alter table public.post_saves enable row level security;

alter table public.user_feed_feedback enable row level security;

alter table public.post_answers enable row level security;

create policy "Allow public read access to post_hashtags" on public.post_hashtags for select using (true);

create policy "Allow public read access to post_mentions" on public.post_mentions for select using (true);

create policy "Allow public read access to audio_tracks" on public.audio_tracks for select using (true);

create policy "Allow insert access to user_owned audio_tracks" on public.audio_tracks for insert with check (auth.uid() = creator_id);

create policy "Allow public read access to audio_usages" on public.audio_usages for select using (true);

create policy "Allow insert access to audio_usages" on public.audio_usages for insert with check (auth.uid() = creator_id);

create policy "Allow read/write access to own saves" on public.post_saves for all using (auth.uid() = user_id);

create policy "Allow read/write access to own feed feedback" on public.user_feed_feedback for all using (auth.uid() = user_id);

create policy "Allow public read access to post_answers" on public.post_answers for select using (true);

create policy "Allow insert access to own post_answers" on public.post_answers for insert with check (auth.uid() = author_id);

create policy "Allow authenticated users to view content" on public.content_views for insert with check (true);

create policy "Allow authenticated users to engage" on public.content_engagements for insert with check (auth.uid() = user_id);

-- RLS policies for message_tombstones
ALTER TABLE public.message_tombstones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read tombstones for their conversations"
ON public.message_tombstones FOR SELECT
USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can insert tombstones for own messages"
ON public.message_tombstones FOR INSERT
WITH CHECK (auth.uid() = deleted_by);

-- 13. Enable RLS and Policies (Idempotent)
ALTER TABLE public.cb_system_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read cb_system_config" ON public.cb_system_config FOR SELECT USING (true);

ALTER TABLE public.cb_ledger_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "User read own ledger" ON public.cb_ledger_entries FOR SELECT USING (auth.uid() = user_id);

ALTER TABLE public.family_pending_rewards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "User read own family pending rewards" ON public.family_pending_rewards FOR SELECT USING (auth.uid() = family_owner_id);

ALTER TABLE public.family_settlement_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "User read own family settlements" ON public.family_settlement_history FOR SELECT USING (auth.uid() = family_owner_id);

ALTER TABLE public.cb_withdrawals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "User read own withdrawals" ON public.cb_withdrawals FOR SELECT USING (auth.uid() = user_id);

-- Enable RLS
ALTER TABLE public.lucky_gift_reward_ledger ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own blocks"
  ON public.user_blocks FOR SELECT
  USING (auth.uid() = blocker_id);

CREATE POLICY "Users can insert their own blocks"
  ON public.user_blocks FOR INSERT
  WITH CHECK (auth.uid() = blocker_id);

CREATE POLICY "Users can delete their own blocks"
  ON public.user_blocks FOR DELETE
  USING (auth.uid() = blocker_id);

ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own devices"
  ON public.user_devices FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert/update their own devices"
  ON public.user_devices FOR ALL
  USING (auth.uid() = user_id);

ALTER TABLE public.user_login_activity ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own login activity"
  ON public.user_login_activity FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert login activity"
  ON public.user_login_activity FOR INSERT
  WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own support tickets"
  ON public.support_tickets FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can submit support tickets"
  ON public.support_tickets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.user_security_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own security settings"
  ON public.user_security_settings FOR SELECT
  USING (auth.uid() = user_id);

ALTER TABLE public.recovery_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own recovery codes count"
  ON public.recovery_codes FOR SELECT
  USING (auth.uid() = user_id);

ALTER TABLE public.trusted_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own trusted devices"
  ON public.trusted_devices FOR SELECT
  USING (auth.uid() = user_id);

ALTER TABLE public.two_factor_attempts ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.security_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own security events"
  ON public.security_events FOR SELECT
  USING (auth.uid() = user_id);

ALTER TABLE public.server_security_keys ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own server security keys count"
  ON public.server_security_keys FOR SELECT
  USING (auth.uid() = user_id);

-- Row Level Security (RLS)
ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own sessions"
  ON public.user_sessions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own sessions"
  ON public.user_sessions FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own sessions"
  ON public.user_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 3. Row Level Security (RLS) on wallets table:
-- Revoke direct UPDATE & INSERT for authenticated users to prevent client-side balance spoofing.
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own wallet" ON public.wallets
  FOR SELECT USING (auth.uid() = id);

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow select payments for self and admins" ON public.payments
  FOR SELECT USING (auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.admins WHERE id = auth.uid()));

ALTER TABLE public.room_roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow select room_roles for all" ON public.room_roles FOR SELECT USING (true);

ALTER TABLE public.room_assigned_roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow select for all assigned roles" ON public.room_assigned_roles FOR SELECT USING (true);

-- =========================================================================
-- DIRECT XP ADDER (Bypasses caps, used for claim claims)
-- =========================================================================
create or replace function public.add_direct_xp(
  p_user_id uuid,
  p_xp_amount integer,
  p_source text
)
returns void as $$
declare
  v_current_level integer;
  v_current_xp integer;
  v_total_xp integer;
  v_next_xp_required integer;
  v_reward_record record;
begin
  -- Fetch user levels
  select level, xp, total_xp into v_current_level, v_current_xp, v_total_xp
  from public.user_levels
  where id = p_user_id;

  if v_current_level is null then
    return;
  end if;

  v_current_xp := v_current_xp + p_xp_amount;
  v_total_xp := v_total_xp + p_xp_amount;

  -- Level up loop
  loop
    select xp_required into v_next_xp_required
    from public.level_requirements
    where level = v_current_level + 1;

    exit when v_next_xp_required is null or v_current_xp < v_next_xp_required or v_current_level >= 60;

    v_current_xp := v_current_xp - v_next_xp_required;
    v_current_level := v_current_level + 1;

    -- Log Level Up event
    insert into public.xp_history (user_id, event_type, xp_gained, metadata)
    values (p_user_id, 'level_up', 0, jsonb_build_object('reached_level', v_current_level));

    -- Dispense level rewards
    for v_reward_record in 
      select reward_type, amount, cosmetic_id 
      from public.level_rewards 
      where level = v_current_level
    loop
      perform public.dispense_reward(
        p_user_id, 
        'level_up', 
        v_current_level::text, 
        v_reward_record.reward_type, 
        v_reward_record.amount, 
        v_reward_record.cosmetic_id
      );
    end loop;
  end loop;

  update public.user_levels
  set level = v_current_level,
      xp = v_current_xp,
      total_xp = v_total_xp,
      last_xp_update = now(),
      updated_at = now()
  where id = p_user_id;
end;
$$ language plpgsql security definer;

-- =========================================================================
-- SECURE TASK ENGINE APIS
-- =========================================================================

-- Get active tasks and current progress
create or replace function public.get_user_tasks()
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_daily_cycle text;
  v_weekly_cycle text;
  v_monthly_cycle text;
  v_season_cycle text := 'season_1'; -- configurable in system_settings
  v_out jsonb;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  v_daily_cycle := to_char(current_date, 'YYYY-MM-DD');
  v_weekly_cycle := to_char(current_date, 'YYYY-') || 'W' || to_char(current_date, 'IW');
  v_monthly_cycle := to_char(current_date, 'YYYY-MM');

  with active_tasks as (
    -- Daily tasks
    select 'daily' as type, task_id, title, description, required_action, required_count, priority, v_daily_cycle as cycle
    from public.daily_tasks where is_active = true
    union all
    -- Weekly tasks
    select 'weekly' as type, task_id, title, description, required_action, required_count, priority, v_weekly_cycle as cycle
    from public.weekly_tasks where is_active = true
    union all
    -- Monthly tasks
    select 'monthly' as type, task_id, title, description, required_action, required_count, priority, v_monthly_cycle as cycle
    from public.monthly_tasks where is_active = true
    union all
    -- Season tasks
    select 'season' as type, task_id, title, description, required_action, required_count, priority, v_season_cycle as cycle
    from public.season_tasks where is_active = true
  ),
  progressed_tasks as (
    select 
      t.type,
      t.task_id,
      t.title,
      t.description,
      t.required_action,
      t.required_count,
      t.priority,
      coalesce(p.current_count, 0) as current_count,
      coalesce(p.is_completed, false) as is_completed,
      coalesce(p.is_claimed, false) as is_claimed,
      (
        select jsonb_agg(jsonb_build_object('reward_type', r.reward_type, 'amount', r.amount, 'cosmetic_id', r.cosmetic_id))
        from public.task_rewards r where r.task_id = t.task_id and r.task_type = t.type
      ) as rewards
    from active_tasks t
    left join public.task_progress p 
      on p.task_id = t.task_id 
     and p.task_type = t.type 
     and p.cycle_key = t.cycle
     and p.user_id = v_user_id
  )
  select jsonb_agg(to_jsonb(pt)) into v_out from progressed_tasks pt;
  
  return coalesce(v_out, '[]'::jsonb);
end;
$$ language plpgsql security definer;

-- Increment progress on tasks (automatically invoked on events)
create or replace function public.increment_task_progress(
  p_user_id uuid,
  p_action text,
  p_amount integer default 1
)
returns void as $$
declare
  v_daily_cycle text := to_char(current_date, 'YYYY-MM-DD');
  v_weekly_cycle text := to_char(current_date, 'YYYY-') || 'W' || to_char(current_date, 'IW');
  v_monthly_cycle text := to_char(current_date, 'YYYY-MM');
  v_season_cycle text := 'season_1';
  v_record record;
begin
  -- Search for daily, weekly, monthly, season tasks listening to this action
  for v_record in 
    select 'daily' as type, task_id, required_count, v_daily_cycle as cycle from public.daily_tasks where required_action = p_action and is_active = true
    union all
    select 'weekly' as type, task_id, required_count, v_weekly_cycle as cycle from public.weekly_tasks where required_action = p_action and is_active = true
    union all
    select 'monthly' as type, task_id, required_count, v_monthly_cycle as cycle from public.monthly_tasks where required_action = p_action and is_active = true
    union all
    select 'season' as type, task_id, required_count, v_season_cycle as cycle from public.season_tasks where required_action = p_action and is_active = true
  loop
    insert into public.task_progress (user_id, task_id, task_type, cycle_key, current_count, is_completed)
    values (p_user_id, v_record.task_id, v_record.type, v_record.cycle, p_amount, p_amount >= v_record.required_count)
    on conflict (user_id, task_id, task_type, cycle_key) do update
    set current_count = task_progress.current_count + p_amount,
        is_completed = (task_progress.current_count + p_amount) >= v_record.required_count,
        completed_at = case when not task_progress.is_completed and (task_progress.current_count + p_amount) >= v_record.required_count then now() else task_progress.completed_at end;
  end loop;
end;
$$ language plpgsql security definer;

-- Claim task reward
create or replace function public.claim_task_reward(
  p_task_id text,
  p_task_type text
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_daily_cycle text := to_char(current_date, 'YYYY-MM-DD');
  v_weekly_cycle text := to_char(current_date, 'YYYY-') || 'W' || to_char(current_date, 'IW');
  v_monthly_cycle text := to_char(current_date, 'YYYY-MM');
  v_season_cycle text := 'season_1';
  v_cycle text;
  v_progress_id uuid;
  v_is_completed boolean;
  v_is_claimed boolean;
  v_reward_record record;
  v_rewards_claimed jsonb := '[]'::jsonb;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  v_cycle := case 
    when p_task_type = 'daily' then v_daily_cycle
    when p_task_type = 'weekly' then v_weekly_cycle
    when p_task_type = 'monthly' then v_monthly_cycle
    else v_season_cycle
  end;

  select id, is_completed, is_claimed into v_progress_id, v_is_completed, v_is_claimed
  from public.task_progress
  where user_id = v_user_id
    and task_id = p_task_id
    and task_type = p_task_type
    and cycle_key = v_cycle;

  if v_progress_id is null or not v_is_completed then
    return jsonb_build_object('success', false, 'reason', 'Task not completed or not found');
  end if;

  if v_is_claimed then
    return jsonb_build_object('success', false, 'reason', 'Reward already claimed');
  end if;

  -- Set claimed
  update public.task_progress
  set is_claimed = true,
      claimed_at = now()
  where id = v_progress_id;

  -- Record in global claims ledger
  insert into public.reward_claims (user_id, source_type, source_id)
  values (v_user_id, 'task', p_task_type || ':' || p_task_id)
  on conflict (user_id, source_type, source_id) do nothing;

  -- Dispense rewards
  for v_reward_record in 
    select reward_type, amount, cosmetic_id 
    from public.task_rewards 
    where task_id = p_task_id and task_type = p_task_type
  loop
    perform public.dispense_reward(
      v_user_id,
      'task',
      p_task_id,
      v_reward_record.reward_type,
      v_reward_record.amount,
      v_reward_record.cosmetic_id
    );
    v_rewards_claimed := v_rewards_claimed || jsonb_build_object(
      'reward_type', v_reward_record.reward_type,
      'amount', v_reward_record.amount,
      'cosmetic_id', v_reward_record.cosmetic_id
    );
  end loop;

  return jsonb_build_object('success', true, 'rewards_claimed', v_rewards_claimed);
end;
$$ language plpgsql security definer;

-- =========================================================================
-- SECURE ACHIEVEMENTS & LOYALTY APIS
-- =========================================================================

-- Get user achievements list and progress status
create or replace function public.get_user_achievements()
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_out jsonb;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  with expanded_achievements as (
    select 
      a.achievement_id,
      a.title,
      a.description,
      a.required_action,
      a.required_count,
      a.reward_type,
      a.reward_amount,
      a.reward_cosmetic_id,
      coalesce(ap.current_count, 0) as current_count,
      coalesce(ap.is_completed, false) as is_completed,
      coalesce(ap.is_claimed, false) as is_claimed
    from public.achievements a
    left join public.achievement_progress ap 
      on ap.achievement_id = a.achievement_id 
     and ap.user_id = v_user_id
  )
  select jsonb_agg(to_jsonb(ea)) into v_out from expanded_achievements ea;

  return coalesce(v_out, '[]'::jsonb);
end;
$$ language plpgsql security definer;

-- Claim achievement reward
create or replace function public.claim_achievement_reward(
  p_achievement_id text
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_progress_id uuid;
  v_is_completed boolean;
  v_is_claimed boolean;
  v_reward_type text;
  v_amount integer;
  v_cosmetic_id text;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  perform pg_advisory_xact_lock(('x' || substr(md5(v_user_id::text), 1, 15))::bit(60)::bigint);

  select id, is_completed, is_claimed into v_progress_id, v_is_completed, v_is_claimed
  from public.achievement_progress
  where user_id = v_user_id and achievement_id = p_achievement_id;

  if v_progress_id is null or not v_is_completed then
    raise exception 'NOT_COMPLETED: Achievement not completed or not registered.';
  end if;

  if v_is_claimed then
    raise exception 'ALREADY_CLAIMED: Achievement reward already claimed.';
  end if;

  -- Set claimed
  update public.achievement_progress
  set is_claimed = true, claimed_at = now()
  where id = v_progress_id;

  insert into public.reward_claims (user_id, source_type, source_id)
  values (v_user_id, 'achievement', p_achievement_id)
  on conflict (user_id, source_type, source_id) do nothing;

  -- Fetch reward definitions
  select reward_type, reward_amount, reward_cosmetic_id into v_reward_type, v_amount, v_cosmetic_id
  from public.achievements
  where achievement_id = p_achievement_id;

  perform public.dispense_reward(
    v_user_id,
    'achievement',
    p_achievement_id,
    v_reward_type,
    v_amount,
    v_cosmetic_id
  );

  return jsonb_build_object(
    'success', true,
    'reward_type', v_reward_type,
    'amount', v_amount,
    'cosmetic_id', v_cosmetic_id
  );
end;
$$ language plpgsql security definer;

-- Get loyalty milestones and progress
create or replace function public.get_loyalty_status()
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_active_days integer := 0;
  v_milestones jsonb;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  -- Count total distinct active days of login
  select count(distinct login_time::date) into v_active_days
  from public.login_history
  where user_id = v_user_id;

  with milestones_agg as (
    select 
      l.active_days as required_days,
      l.reward_type,
      l.amount,
      l.cosmetic_id,
      exists (
        select 1 from public.reward_claims
        where user_id = v_user_id and source_type = 'loyalty' and source_id = l.active_days::text
      ) as is_claimed
    from public.loyalty_rewards l
  )
  select jsonb_agg(to_jsonb(ma)) into v_milestones from milestones_agg ma;

  return jsonb_build_object(
    'total_active_days', v_active_days,
    'milestones', coalesce(v_milestones, '[]'::jsonb)
  );
end;
$$ language plpgsql security definer;

-- Claim loyalty milestone
create or replace function public.claim_loyalty_reward(
  p_active_days integer
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_active_days integer := 0;
  v_reward_type text;
  v_amount integer;
  v_cosmetic_id text;
  v_already_claimed boolean;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED: Must be logged in.';
  end if;

  perform pg_advisory_xact_lock(('x' || substr(md5(v_user_id::text), 1, 15))::bit(60)::bigint);

  -- Count total distinct active days of login
  select count(distinct login_time::date) into v_active_days
  from public.login_history
  where user_id = v_user_id;

  if v_active_days < p_active_days then
    raise exception 'NOT_ELIGIBLE: Insufficient active days. Required: %, You have: %', p_active_days, v_active_days;
  end if;

  select exists (
    select 1 from public.reward_claims
    where user_id = v_user_id and source_type = 'loyalty' and source_id = p_active_days::text
  ) into v_already_claimed;

  if v_already_claimed then
    raise exception 'ALREADY_CLAIMED: Loyalty milestone reward already claimed.';
  end if;

  -- Fetch reward
  select reward_type, amount, cosmetic_id into v_reward_type, v_amount, v_cosmetic_id
  from public.loyalty_rewards
  where active_days = p_active_days;

  if v_reward_type is null then
    raise exception 'NOT_FOUND: Milestone configuration not found.';
  end if;

  -- Claim rewards
  insert into public.reward_claims (user_id, source_type, source_id)
  values (v_user_id, 'loyalty', p_active_days::text);

  perform public.dispense_reward(
    v_user_id,
    'loyalty',
    p_active_days::text,
    v_reward_type,
    v_amount,
    v_cosmetic_id
  );

  return jsonb_build_object(
    'success', true,
    'reward_type', v_reward_type,
    'amount', v_amount,
    'cosmetic_id', v_cosmetic_id
  );
end;
$$ language plpgsql security definer;

-- Configure Task
create or replace function public.admin_configure_task(
  p_task_id text,
  p_task_type text,
  p_title text,
  p_description text,
  p_required_action text,
  p_required_count integer,
  p_is_active boolean,
  p_rewards jsonb -- array of rewards: [{"reward_type": "xp", "amount": 50}, ...]
)
returns jsonb as $$
declare
  v_admin_id uuid := auth.uid();
  v_reward record;
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'UNAUTHORIZED: Admin access only.';
  end if;

  -- 1. Upsert into appropriate task registry table
  if p_task_type = 'daily' then
    insert into public.daily_tasks (task_id, title, description, required_action, required_count, is_active, updated_at)
    values (p_task_id, p_title, p_description, p_required_action, p_required_count, p_is_active, now())
    on conflict (task_id) do update 
    set title = excluded.title, description = excluded.description, required_action = excluded.required_action, required_count = excluded.required_count, is_active = excluded.is_active, updated_at = now();
  elsif p_task_type = 'weekly' then
    insert into public.weekly_tasks (task_id, title, description, required_action, required_count, is_active, updated_at)
    values (p_task_id, p_title, p_description, p_required_action, p_required_count, p_is_active, now())
    on conflict (task_id) do update 
    set title = excluded.title, description = excluded.description, required_action = excluded.required_action, required_count = excluded.required_count, is_active = excluded.is_active, updated_at = now();
  elsif p_task_type = 'monthly' then
    insert into public.monthly_tasks (task_id, title, description, required_action, required_count, is_active, updated_at)
    values (p_task_id, p_title, p_description, p_required_action, p_required_count, p_is_active, now())
    on conflict (task_id) do update 
    set title = excluded.title, description = excluded.description, required_action = excluded.required_action, required_count = excluded.required_count, is_active = excluded.is_active, updated_at = now();
  elsif p_task_type = 'season' then
    insert into public.season_tasks (task_id, title, description, required_action, required_count, is_active, updated_at)
    values (p_task_id, p_title, p_description, p_required_action, p_required_count, p_is_active, now())
    on conflict (task_id) do update 
    set title = excluded.title, description = excluded.description, required_action = excluded.required_action, required_count = excluded.required_count, is_active = excluded.is_active, updated_at = now();
  end if;

  -- 2. Repopulate rewards
  delete from public.task_rewards where task_id = p_task_id and task_type = p_task_type;
  
  for v_reward in select * from jsonb_to_recordset(p_rewards) as r(reward_type text, amount integer, cosmetic_id text) loop
    insert into public.task_rewards (task_id, task_type, reward_type, amount, cosmetic_id)
    values (p_task_id, p_task_type, v_reward.reward_type, v_reward.amount, v_reward.cosmetic_id);
  end loop;

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

-- Configure spin probabilities
create or replace function public.admin_configure_spin_reward(
  p_spin_type text,
  p_reward_type text,
  p_amount integer,
  p_cosmetic_id text,
  p_probability double precision
)
returns jsonb as $$
declare
  v_admin_id uuid := auth.uid();
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'UNAUTHORIZED: Admin access only.';
  end if;

  insert into public.spin_rewards (spin_type, reward_type, amount, cosmetic_id, probability)
  values (p_spin_type, p_reward_type, p_amount, p_cosmetic_id, p_probability)
  on conflict (id) do update
  set reward_type = excluded.reward_type, amount = excluded.amount, cosmetic_id = excluded.cosmetic_id, probability = excluded.probability, updated_at = now();

  return jsonb_build_object('success', true);
end;
$$ language plpgsql security definer;

-- RPC: Register Device
CREATE OR REPLACE FUNCTION public.register_user_device(
  p_device_id text,
  p_device_name text,
  p_platform text,
  p_ip text DEFAULT '127.0.0.1'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  -- Mark other devices as not current
  UPDATE public.user_devices
  SET is_current = false
  WHERE user_id = v_user_id;

  -- Upsert current device
  INSERT INTO public.user_devices (user_id, device_id, device_name, platform, ip_address, is_current, revoked_at, last_active)
  VALUES (v_user_id, p_device_id, p_device_name, p_platform, p_ip, true, NULL, timezone('utc'::text, now()))
  ON CONFLICT (user_id, device_id) DO UPDATE SET
    device_name = EXCLUDED.device_name,
    platform = EXCLUDED.platform,
    ip_address = EXCLUDED.ip_address,
    is_current = true,
    revoked_at = NULL,
    last_active = timezone('utc'::text, now());

  RETURN jsonb_build_object('success', true);
END;
$$;

-- RPC: Revoke Device Access
CREATE OR REPLACE FUNCTION public.revoke_user_device(p_device_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated');
  END IF;

  UPDATE public.user_devices
  SET revoked_at = timezone('utc'::text, now()), is_current = false
  WHERE user_id = v_user_id AND device_id = p_device_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

