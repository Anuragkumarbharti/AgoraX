# Creania - Supabase Backend Integration (Technical Logs & Architecture)

This document contains a comprehensive record of how the Creania codebase is connected to the Supabase backend, detailing the database schema, real-time synchronization, and client-side controller refactoring logic.

---

## 1. Architectural Schema & Migrations

All database structures and storage buckets are defined in Supabase PostgreSQL migration scripts.

### 📜 A. Base Schema (`202607090000_init_schema.sql`)
Defines the core database structures:
* **Profiles Table (`public.profiles`)**: Holds primary student identities, gamification scores (XP, level), VIP/Novel membership levels, and equipped customizations.
* **Wallet Ledger (`public.wallets` & `public.wallet_transactions`)**: Implements cash and coin balances with structured credit/debit records (`Deposit`, `Withdrawal`, `Payout`, `Refund`, `Reward`, `Commission`).
* **Study Vault (`public.study_vault_items` & `public.study_reviews`)**: Stores library educational resources, page markers, and verified reviews.
* **Signalling Voice Rooms (`public.rooms` & `public.room_members`)**: Manages metadata for LiveKit audio seats.

### 📜 B. Account Linking & Merging (`202607120001_auth_merge.sql`)
Solves identity duplication if a user logs in using different providers (Email, Phone, Google, Apple):
* **`public.user_auth_mappings`**: Maps auth session IDs (`auth.users.id`) to a single, shared profile canonical ID (`canonical_id`).
* **Trigger `handle_new_user()`**: Automatically intercepts sign-ups, checks for existing accounts by email/phone/social keys, coalesces missing credentials, and links them to the same profile.
* **RLS Resolver `canonical_uid()`**: Replaces `auth.uid()` in Row-Level Security policies to secure access based on mapped canonical IDs.

### 📜 C. Community & Events Tables (`202607120002_full_backend.sql`)
Bridges community posts, user milestones, and customizations to SQL tables:
* **`public.communities` & `public.events`**: Manages groups and active quizzes/contests.
* **`public.posts`, `public.post_likes`, `public.post_bookmarks`**: Enforces relational data constraints on feed feeds.
* **`public.user_customizations`**: Persists unlocked/equipped borders, name colors, entry effects, and showcase badges.
* **`public.user_daily_tasks`**: Stores individual daily checklist completions.
* **Storage Buckets**: Auto-registers public buckets for banners, avatars, thumbnails, and media, alongside the private bucket `study-files`.

---

## 2. Linked Identity Integration (Client-Side)

### 🔑 Resolved Canonical UIDs
Instead of reading `Supabase.instance.client.auth.currentUser.id` directly (which points to the specific OAuth login session ID and could cause data duplication), all client states resolve IDs via:
* **[UserProfileCacheManager.currentUserId](file:///c:/Users/MSI/Downloads/AgoraX/lib/services/user_profile_cache_manager.dart)**: Returns the pre-resolved canonical profile ID fetched during authentication.
* Modifying user profiles, listing connections, or deleting accounts in Settings screens query via this canonical profile reference.

---

## 3. Database-Wired Controllers (`lib/services/`)

All mock data lists have been replaced with direct Supabase reads, Postgres inserts, and real-time subscriptions.

### 🤝 A. Community Controller (`community_controller.dart`)
* **Realtime Subscriptions**: Listens to the `public:communities` database channel using Supabase Realtime to push member count changes and name updates automatically.
* **Wired Actions**: `createCommunity` and `joinCommunity` query/update database rows asynchronously.

### 🏆 B. Event Controller (`event_controller.dart`)
* **Wired Actions**:
  * `createPaidEvent`: Deducts host commission fee (59 coins) from the database `wallets` table, writes to the ledger, and inserts a row into `events`. If database insert fails, it automatically refunds the coins.
  * `registerForEvent`: Verifies deadline/max capacity, deducts cash or coins based on entry parameters, logs the payout/commission transaction, and appends the user to the event's `registered_user_ids` array.
* **Compatibility Layer**: Restored UI methods (`withdrawCash`, `depositCash`, `kickMember`, etc.) so screens compile smoothly without breaking.

### 🎨 C. Customization Controller (`customization_controller.dart`)
* **Equipped Items**: Equipped border frames, chat bubbles, and entry effects are written to `public.user_customizations` with `is_equipped = true` and `is_equipped = false` updates.
* **Unlocked Items**: Unlocked badge arrays are synced directly to the `badges` column of `public.profiles`.

### 📈 D. Progression & Category Controllers (`career_progression_controller.dart` & `study_category_controller.dart`)
* **Experience & Streak**: Direct queries update the `experience`, `level`, and `learning_streak` columns on the `profiles` table.
* **Daily Tasks**: Updates progress count and marks tasks as completed within `public.user_daily_tasks`.

---

## 4. Verification Status

* **Email Verification Engine (`email_validation_test.dart`)**: Passed 100%. Verifies email format validations, disposable blocklists (via local/GitHub checks), Google MX DNS query resolutions, and cooldown rate-limits.
* **Study Vault Access & Payouts (`study_vault_test.dart`)**: Passed 100%. Verifies Kindle/Gumroad split models (18% GST, 2% PG, 17% Platform), VIP membership unlock thresholds, and the ₹5.00 seller payout visit rewards.
