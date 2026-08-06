# Creaniaa Voice Room & Arena System Specification
Version: 12.0 (Role Popups, @Mentions, Gift Star Metrics & 20-Point Anti-Abuse Engine)
Status: Production Architecture (Backend-First)

==================================================

# GOAL

Build a state-of-the-art, high-concurrency Live Voice Room & Stage Arena system (combining StarMaker, Clubhouse, Discord Stage, and LiveKit/ZEGOCLOUD SFU audio) inside the Creaniaa ecosystem.

Priority:
1. Backend Integrity & Security (Postgres RLS & RPCs)
2. Scalability (1M+ Concurrent Users)
3. Audio Clarity & Realtime Latency (<200ms)
4. Strict Room Authority & Dynamic Role Permissions
5. Creator Economy (Audited Gifting & Room XP Progression)

No fake implementations.
No mock data.
No shortcuts.

==================================================

# SYSTEM ARCHITECTURE

Flutter App (Mobile / Web)
↓
Supabase Auth (JWT & Role Entitlements)
↓
PostgreSQL Database (Rooms, Seats, Members, Audit Logs, RPCs)
↓
Supabase Realtime Channels (Transfers transient room chat, seat updates, gifting events)
↓
LiveKit / ZEGOCLOUD SFU (Low-latency WebRTC Audio Stream)

==================================================

# CREANIAA ROOM ROLE SYSTEM

### 1. 👑 Owner (Room Creator - Permanent)
- **Tag**: 👑 Owner (Gold Tag / Animated Gold Crown)
- **Maximum Count**: Only 1 per Room
- **Can be Changed?**: ❌ **Never** (Transfer, remove, or delete NOT allowed. The Creator of the room is the permanent System Owner of the room. If an account is permanently deleted, ownership can only be migrated via special admin support process).
- **Can Leave Room?**: ✅ Yes
- **Power & Permissions**:
  - Highest permanent authority of the room.
  - Complete room management.
  - Can assign & remove Co Owners and Admins.
  - Can lock seats, mute everyone, kick users, ban users.
  - Can change room background, room name, room category, room announcement, entry restrictions, and password.
  - Can view room statistics, start/end PK, change room mode, edit room information.
  - Can access revenue analytics, change room identity, manage security, monetization, and permanently delete room.
  - **No one can remove, demote, kick, or ban the Owner.**

### 2. 💎 Co Owner
- **Tag**: 💎 Co Owner (Purple Diamond Tag)
- **Maximum Count**: Level-based (See Room Level Role Limits Table).
- **Power & Permissions**:
  - Almost equal to Owner except ownership management.
  - Can manage Admins, mute users, kick users, ban users.
  - Can lock seats, unlock seats, edit room information, edit background, edit category, edit announcement, edit password.
  - Can manage room events, schedule, and welcome message.
  - **Can decide room entry rules**: Followers Only, Following Only, Friends Only, Password, VIP Only, Family Only, Blacklist, Whitelist.
  - **Cannot**: Remove Owner, assign another Co Owner, transfer ownership, or delete room.

### 3. 🛡 Admin
- **Tag**: 🛡 Admin (Blue Shield Tag)
- **Maximum Count**: Level-based (See Room Level Role Limits Table).
- **Power & Permissions**:
  - Can mute microphones, kick users, ban users, lock/unlock seats.
  - Can accept/reject mic requests, edit room info, announcement, background, description.
  - Can manage queue, manage audience, start countdown, manage games, control gifts, maintain room discipline.
  - **Cannot**: Assign Admin or Co Owner, remove Co Owner or Owner, change entry permissions (Followers/Following/Friends/Password/Family/VIP), delete room, or transfer ownership.

### 4. 🎤 Host
- **Tag**: 🎤 Host (Red Mic Tag — **ONLY on Seat 1**)
- **Definition**: **Host is NOT a persistent role.** Host is the user currently sitting on Seat 1 (Host Seat).
- **Duration**: Host power is automatically active while occupying Seat 1 and **disappears immediately after leaving Seat 1**.
- **Host Power**:
  - Start, stop, and pause music.
  - Change voice effects, start singing, control karaoke.
  - Accept and reject duets, manage song queue, manage lyrics, control room music.
  - **Cannot**: Assign Admin or Co Owner, or change room settings.
- **Seat 1 Access**: Only users with sufficient permission (Owner, Co Owner, or Admin) can occupy the restricted Host Seat 1 when required.

### 5. 👤 Audience
- **Tag**: No Tag
- **Power**: Chat, send gifts, request mic, follow users, join PK support, like room, report users, share room, invite friends. Nothing else.

==================================================

# CREANIAAA REAL TIME ROLE PERSISTENCE ENGINE

### 🚨 CORE RULE: Room Role = Permanent Until Changed
- Roles are assigned permanently in the PostgreSQL database (`public.room_members`).
- A role NEVER auto-expires, resets, or disappears. It stays active until explicitly changed or demoted by an authorized role.

### 1. Automatic Role & Tag Recovery Pipeline
Upon any event (leaving room, re-joining, app restart, logout/login, device switch, network drop, server reconnect, or session expiry), the server executes auto recovery:
- `User Room Join Request` → `Load Room Role from Postgres` → `Load Role Permissions` → `Load Role Tag` → `Load Role Badge & Color` → `Load Role Context Menu` → `Broadcast Realtime State` → `Room Successfully Joined`.
- Tags (`👑 Owner`, `💎 Co Owner`, `🛡 Admin`) render automatically on entry with zero manual re-assignment needed.

### 2. Automatic Permission Recovery & Mismatch Prevention
Before rendering the room UI, the server validates:
`Room ID` → `User ID` → `Role` → `Permissions` → `Load Complete`.
- Eliminates bugs like "Admin tag without permissions" or "Powers without a tag".

### 3. Real-Time Synchronization & Zero-Delay Target (100–300 ms)
- Role Change Sequence: `Client / RPC Invocation` → `Server Validation` → `Database Update` → `Redis Cache Update` → `WebSocket Broadcast` → `All Connected Clients Updated`.
- Target broadcast latency: **100–300 ms**.
- Updates Tag, Badge, Permissions, Member List, Chat, Mic Frame, Profile Card, and Context Menus simultaneously for all connected clients without page refresh.

### 4. Multi-Device Realtime Sync
- Role changes immediately synchronize across all active logged-in devices for multi-device users.

### 5. Redis Cache Fallback & Loss Protection
- If Redis cache restarts or flushes, system automatically reloads role records directly from PostgreSQL DB (`public.room_members`). Role data is NEVER lost.

### 6. Mandatory Server-Side Permission Verification
Every administrative action (Kick, Ban, Mute, Lock Seat, etc.) enforces mandatory server verification:
`Action Trigger` → `Verify Room ID` → `Verify User Role in DB` → `Verify Permission` → `Execute Action`.
- Client-side state is NEVER trusted alone.

### 7. Atomic Role Transaction
- Role updates execute inside a single atomic database & broadcast transaction.
- Eliminates partial state mismatches (e.g. tag updated but permissions lagged, or chat showing Admin while member list shows Audience). Either full role updates or nothing.

### 8. 12-Step Room Join Validation Sequence
1. `User Authentication`
2. `Room Validation`
3. `Entry Permission Check`
4. `Ban / Kick Check`
5. `Load User Role`
6. `Load Role Permissions`
7. `Load Role Tags`
8. `Load VIP / Family / Agency Tags`
9. `Load Seat Status`
10. `Join Room`
11. `Realtime Sync`

### 9. Permanent Role Audit Log Table (`public.room_role_audit_logs`)
- Every role assignment, promotion, and demotion is permanently recorded:
  - `action` (`'ADMIN_ASSIGNED'`, `'CO_OWNER_PROMOTED'`, `'ROLE_DEMOTED'`)
  - `room_id` (UUID)
  - `target_user_id` (UUID)
  - `assigned_by` (UUID)
  - `role` (Text)
  - `status` (`'ACTIVE'`, `'REVOKED'`)
  - `timestamp` (Timestamptz)
- Audit log records are NEVER deleted; demotion only updates `status = 'REVOKED'`, ensuring complete moderation history.

==================================================

# CREANIAAA REAL TIME ROLE NOTIFICATIONS, MENTIONS & GIFT STAR METRICS

### 1. Real-Time Role Event Popups & Room Marquee Broadcasts
Whenever a user role is assigned, promoted, or demoted, the server triggers an instant atomic event:
- **Role Assignment Event**:
  - **User Targeted Modal Popup**:
    `🎉 Congratulations!`
    `You have been promoted to 🛡 Admin in Room: Arena Music`
    `Your new permissions are now active.`
  - **In-Room Public Broadcast Banner**:
    `🛡 Rahul has been promoted to Admin.`
- **Role Revocation / Demotion Event**:
  - **User Targeted Modal Popup**:
    `Your Admin role has been removed.`
    `You are now an Audience member.`
    `Reason: Inactive for 30 days`
  - **In-Room Public Broadcast Banner**:
    `🛡 Rahul is no longer an Admin.`
- **Atomic Event Consistency**: Role, Tag, Badge, Profile Card, and Permission set update simultaneously across all room participants in a single Realtime broadcast event (<100ms).

### 2. In-Room Member Mention System (`@Mention`)
- **Interactive Mention Overlay**: Typing `@` in the chat input opens a search dropdown filtered strictly by active room participants.
- **Profile / Member List Trigger**: Long-pressing a member's avatar or opening their mini profile card displays a `"Mention User"` action button, auto-populating `@Rahul` in chat input.
- **Mention Highlights & Notifications**:
  - Mentioned user receives an instant visual & audible notification badge.
  - Mentioned chat message renders with distinct golden/purple highlighted background.
  - Chat stream displays a `@Mentioned` pill badge.
- **Scope Restriction**: Only users **currently inside the room** can be tagged/mentioned.

### 3. Triple Gift Star Metric Display System
Room header & statistics panel display 3 distinct gift star counters:
1. **Today's Room Gift Stars**: Cumulative gift star value earned by the room today (Resets at 00:00 Local Time).
2. **Lifetime Total Room Gift Stars**: Total historical cumulative gift star value earned by the room since creation.
3. **User Daily Star Contribution**: Gift stars contributed by the specific logged-in user to this room today.

==================================================

# CREANIAAA ROOM LEVEL & PROGRESSION SYSTEM

### 1. Room Levels & VP Thresholds Table (Levels 1 to 7 Max)

| Room Level | Required VP | Co Owner | Admin | Host Slots | Audience Capacity | Feature Unlocks |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Level 1** | 0 VP | 1 | 4 | 4 | Default | Basic Room, Basic Background, Basic Announcement, Normal Daily Tasks |
| **Level 2** | 100,000 VP | 1 | 10 | 8 | Expanded | Premium Background, Welcome Banner, Room Statistics |
| **Level 3** | 300,000 VP | 2 | 15 | 10 | Expanded | Animated Room Frame, Room Music, Gift Wall |
| **Level 4** | 700,000 VP | 2 | 18 | 12 | Expanded | Dynamic Background, Premium Room Effects, Event Scheduler |
| **Level 5** | 1,500,000 VP | 3 | 20 | 15 | High | Official Room Badge, Premium Discovery, Advanced Analytics |
| **Level 6** | 3,000,000 VP | 4 | 23 | 18 | High | Luxury Theme, Animated Entry, VIP Room Features |
| **Level 7 (Max)** | 6,000,000 VP | 5 | 25 (Max) | 20 (Max) | Maximum | Legendary Room, Exclusive Backgrounds, Highest Discovery Priority, Official Recommendation, Premium Events |

### 2. Room VP Accumulation Sources
Room VP is strictly earned through active room engagement and gifting:
- **Silver Gifts**: `+1 VP` per 100 Silver spent in room
- **Gold Gifts**: `+2 VP` per 1 Gold Coin spent in room
- **User Stay Time**: `+5 VP` per minute per active room listener
- **Active Mic Time**: `+8 VP` per minute per seated speaker
- **🔥 Dynamic Audience Mic Time Multiplier**:
  - `3+` active room users: `+10 VP` per minute
  - Scaled up to `10+` active room users: `+40 VP` per minute
- **New Member Join**: `+20 VP`
- **Returning Member Join**: `+30 VP`

### 3. Real-Time Room Progress Bar
Displayed prominently at the top of the Room header viewport:
`Room Level 3 [████████░░░░░░░░] 327,500 / 700,000 VP (46%)`
- Progress bar updates dynamically in real-time as gifts arrive or user stay time ticks.

### 4. Daily Task System (Normal vs Gold Tasks)
- **Normal Daily Tasks** (Completable with Silver or Gold gifts):
  - Rewards: Room VP, Gold Coins, Silver Coins, Normal Treasure Box.
- **Gold Daily Tasks** (Completable strictly via Gold Gifts — Silver gifts do NOT count):
  - Tasks: Send 10/50/100 Gold, Send Premium Gift, Support 3 Different Hosts, Spend 500 Gold Today, Win Gold Lucky Box, Complete Gold Combo.
  - Rewards: Large Room VP, Exclusive Frame Fragments, Lucky Keys, Premium Treasure Box, Exclusive Titles.

### 5. Room Team Tasks & Dynamic Member Scaling
Automatically starts when at least **3 active members** are present in the room:
- **3 Members**: Stay together 20 min → Small VP
- **5 Members**: Send 20 Gifts → Medium VP
- **8 Members**: Active Mic 30 min → Treasure Box
- **10 Members**: Room receives 100 Gifts → Room VP, Room Coins, Special Animation
- **15 Members**: Complete PK Battle → Legend Chest
- **20 Members**: Stay Active 45 min → Large Room VP, Exclusive Room Effects

*⚡ Dynamic Task Scaling*: More active room members dramatically accelerate task progress speed.

### 6. Creaniaa Collaborative Community Tasks (Exclusive Feature)
Superior to StarMaker individual tasks; unifies the entire room as a single team:
- **Daily Join Target**: 50 unique users join room today.
- **Follower Surge**: 10 new room followers earned today.
- **Uptime Challenge**: Keep room active continuously for 3 hours.
- **Collective Gifting Goal**: Room hosts collectively receive 1,000 Gold today.

### 7. 4-Tier Treasure Box System
- Normal Tasks → **Normal Treasure Box**
- Gold Tasks → **Gold Treasure Box**
- Team Tasks → **Room Treasure Box**
- Legend Tasks → **Legendary Treasure Box**

### 8. Midnight Reset Rules
- **Every day at 00:00 Local Time**: Normal Tasks, Gold Tasks, Team Tasks, and Daily Progress reset.
- **NEVER Resets**: Room Level, Total Room VP, and User Lifetime VP are **permanently retained**.

### 9. CREANIAAA Daily VP Task Targets & Dual Progress Rules

#### Daily VP Target Limits
- 🟢 **Free Tasks Daily Target**: `700 VP` (Earned via Free activity, Seat occupancy, Silver Gifts, and Gold Gifts).
- 🟡 **Gold Tasks Daily Target**: `1000 VP` (**Earned STRICTLY via Gold Gifts**. Silver Gifts, Free Gifts, Event Gifts, and Seat activity do NOT count).
- 🌟 **Weekend Bonus Target (Saturday + Sunday)**:
  - 🟢 Free Daily Target: `1,250 VP`
  - 🟡 Gold Daily Target: `1,250 VP`
  - Total Daily Target: `2,500 VP` (Unlocks elevated Weekend rewards).

#### Active Stage Seat VP Matrix (Requires ≥1 Occupant on Stage)
- Audience alone generates `0 VP`. At least 1 user must occupy a seat on stage (Seat 1 to 10).
- Seated user status: Muted, unmuted, singing, or idle — all valid for seat VP progression.
- **Seated Occupant VP Accumulation Rate**:
  - `1 Occupant`: `4 VP / min`
  - `2 Occupants`: `8 VP / min`
  - `3 Occupants`: `14 VP / min`
  - `4 Occupants`: `20 VP / min`
  - `5 Occupants`: `28 VP / min`
  - `6 Occupants`: `36 VP / min`
  - `7 Occupants`: `44 VP / min`
  - `8 Occupants`: `50 VP / min`
  - `9 Occupants`: `55 VP / min`
  - `10 Occupants`: `60 VP / min`
  *(1 user completes Free VP target in ~6 hours; 10 active seats complete target in ~1.5–2 hours).*

#### Gift VP Values & Bonus Rules
- **Free Gift VP**: Normal Gifts, Silver Gifts, and Event Gifts count toward Free Task progress.
  - **Star / Coin Valuation Rule**: **1 Star / Coin Value = 1 VP** (e.g. 50 Star gift = 50 VP).
  - ⭐ (1 Star) = `2 VP`
  - ⭐⭐ (2 Star) = `5 VP`
  - ⭐⭐⭐ (5 Star) = `10 VP`
  - ⭐⭐⭐⭐ (10 Star) = `20 VP`
  - ⭐⭐⭐⭐⭐ (20 Star) = `40 VP`
  - ⭐⭐⭐⭐⭐⭐ (35 Star) = `70 VP`
  - Luxury Event Gifts = `80 – 250 VP` (based on gift value).
- **First Five Gifts Bonus**: The first 5 gifts of the day (Silver, Gold, or Event) grant **+25 Bonus VP** per gift.
- **First Seat Bonus**: First seat occupancy each day grants **+20 Bonus VP**.

#### Gold Tasks & Dual-Progress Bar Rules
- Gold Gifts earn Gold VP (e.g., 5 Gold = 40 VP, 20 Gold = 120 VP, 100 Gold = 350 VP, Premium Gift = 500 VP, Festival Gift = 700 VP, Gold Combo = Extra Bonus VP).
- **🔥 Dual Progress Bar Rule**:
  - **Gold Gift Sent** → Fills **Gold Task Progress Bar** AND ALSO fills **Free Task Progress Bar** simultaneously ✅!
  - **Silver / Free Gift Sent** → Fills **Free Task Progress Bar** ONLY ✅ (Gold Task = ❌).
  - *Sending Gold Coin gifts fills the Gold Task first and automatically counts toward completing the Normal/Free Task progress bar.*

#### Progress Bars & Chest Rewards
- 🟢 FREE TASK: `[████████░░░░░░░░] 520 / 700 VP` → Unlocks **Normal Chest**
- 🟡 GOLD TASK: `[██████░░░░░░░░░] 420 / 1000 VP` → Unlocks **Gold Chest**
- 🌟 WEEKEND BONUS: `2,500 VP` → Unlocks **Legendary Chest**

#### VP Sources & Target Compatibility Matrix

| Activity | Free Task Progress | Gold Task Progress |
| :--- | :---: | :---: |
| **Seat Activity** | ✅ | ❌ |
| **Silver Gift** | ✅ | ❌ |
| **Event Gift** | ✅ | ❌ |
| **Gold Gift** | ✅ | ✅ |
| **Premium Gift** | ✅ | ✅ |
| **First 5 Gifts Bonus** | ✅ | ✅ (If Gold) |
| **First Seat Bonus** | ✅ | ❌ |

==================================================

# CREANIAAA 20-POINT ENTERPRISE ANTI-ABUSE & TRUST SCORE ENGINE

### 1. Minimum Active Stage Occupant & Slow Mode
- Task progression requires at least 1 user sitting on a stage seat (Seat 1 to 10). Audience count alone does not count.
- If only 1 solo user sits alone for extended periods without room activity, system enters **Slow Mode** (reduces seat VP accumulation speed until others join).

### 2. 10-Minute Idle Freeze Rule
- If 10 consecutive minutes pass with 0 gifts, 0 joins, 0 leaves, 0 seat changes, 0 mic state changes, and 0 PK battles, **seat VP earning automatically freezes/pauses**.
- Earning resumes instantly on the next verified room interaction event.

### 3. Multi-Device & Hardware Fingerprint Shield
- Multiple user accounts running on the same physical device, emulator, or suspicious hardware fingerprint inside the same room generate **0 VP** (`VP = 0`).

### 4. Self-Gifting & Alternate Account Protection
- Gifting an alternate account owned by the same user or matching IP/device/hardware signatures yields **0 VP & 0 Task Progress** (`VP = 0`, `Progress = 0`).

### 5. Risk-Scored & Duplicate Account Filter
- Fake accounts, newly created spam IDs, banned IDs, and high-risk accounts are strictly excluded from task progress.

### 6. Rapid Join/Leave Cooldown Guard
- Rapid Join → Leave → Join → Leave cycles trigger a **30-Second Cooldown** on join VP.

### 7. Seat Swapping & Jump Spam Guard
- Rapidly hopping across seats (Seat 3 → Seat 4 → Seat 5 → Seat 2 → Seat 1) grants **0 Extra VP**.
- First Seat Bonus is granted strictly **once per day**.

### 8. Fraudulent & Refunded Gift Shield
- Refunded, cancelled, chargeback, or illegal gifts are automatically stripped of VP credits.

### 9. 24/7 Robotic Bot Pattern Filter
- Accounts online 24x7 with exact robotic patterns and zero organic human interaction are flagged and VP is disabled.

### 10. Coin Value Valuation (Gift Count Protection)
- Sending 1000 micro-gifts in 1 second does not exploit the task.
- Server calculates VP strictly based on **Total Coin/Star Valuation**, NOT gift quantity count.

### 11. Room Hopping Cooldown Guard
- Hopping across multiple rooms every minute (Room A → Room B → Room C) triggers a **60-Second Cooldown** on room VP earning.

### 12. Minimum Seat Duration (1-Minute Threshold)
- Sitting on a mic seat for 10–20 seconds and leaving grants **0 VP**.
- Minimum valid stay duration for seat VP credit is **1 Minute**.

### 13. Hidden Private Room Farming Shield
- Private rooms populated by alt IDs are checked by backend algorithms (unique users, verified interaction, gifting, retention) before awarding VP.

### 14. Rigid Behavioral Pattern Risk Score
- Rigid daily patterns (e.g. login 9:00 → gift 9:05 → logout 9:06 daily) raise the account's **Risk Score**.

### 15. Daily VP Hard Cap Enforcement
- Reaching daily targets stops VP generation until the midnight reset.

### 16. Mandatory Server-Side RPC Task Validation
- Client-side code NEVER determines VP. All task progress is validated, approved, and committed server-side via Supabase RPCs.

### 17. Device Ban Enforcement
- Banned physical hardware devices receive `VP = 0`, `Task Progress = 0`, `Rewards = 0`.

### 18. VPN, Proxy & Datacenter IP Shield
- High-risk VPNs, Datacenter IPs, Tor exit nodes, and known proxies temporarily disable VP task earning.

### 19. Dynamic Real-Human Activity Score
- Each user maintains a dynamic Activity Score:
  - **Boosted by**: Organic gifts, active room participation, diverse user interaction, PK participation, long session consistency.
  - **Penalty for**: Idle farming, fake joins, repeat alt interaction, suspicious gifting.
  - Low score users experience reduced or blocked VP generation.

### 20. Fair Play Enforcement & Instant Revocation
- Violations trigger instant progress cancellation, VP stripping, reward revocation, and moderation review placement without prior warning.

---

### ⭐ HIDDEN TRUST SCORE SYSTEM (0–100 Rating)

Every account maintains a hidden backend `Trust Score` (0 to 100):
- **Score Boosters (+)**: Account age, verified identity, genuine coin purchases, normal human interaction, diverse social network.
- **Score Penalties (-)**: Emulators, VPN abuse, multi-account fingerprinting, self-gifting, fake farming, chargebacks, spam reports.
- **Low Trust Score (<30) Enforcement**:
  - Accounts with Trust Score < 30 can still join voice rooms, talk, and listen normally.
  - However, they are **COMPLETELY EXCLUDED from Daily VP Tasks, Event Rewards, Leaderboards, and Chest Drops**.
  - *Result*: Fake farming is completely neutralized without penalizing genuine users!

==================================================

# CREANIAAA ROOM ENTRY PERMISSION ENGINE

### 1. Entry Priority Hierarchy & Management Override
Server checks entry permissions in strict priority order:
1. **👑 Owner / Creator**
2. **💎 Co-Owner**
3. **🛡 Admin**
4. **🎤 Current Host (Seat 1 / Seat 2)**
5. **👤 Audience**

**🚨 Priority Access Rule**:
Users holding **Owner (Creator), Co-Owner, Admin, or Current Host** status **ALWAYS enter the room unconditionally** ✅.
- They bypass Password, Followers Only, Following Only, Friends Only, Family Only, VIP Only, and Invite Only restrictions.
- Only permanent room bans or global account suspensions can restrict room management access.

### 2. Sequential Audience Entry Validation (Steps 1–12)
For Audience members, the backend server executes sequential validation checks:

- **Step 1: Room Active Check** → If closed: `"❌ Room is currently closed."`
- **Step 2: Permanent Ban Check** → If on room ban list: `"🚫 Permanently Banned from this room"` (Displays Action By, Reason, Ban Date, Appeal Button).
- **Step 3: Temporary Kick Check** → Redis TTL check: If active, displays Kick Modal (`"❌ Removed from Room"`, Removed By, Reason, Restriction Duration e.g. 24h, Live Remaining Countdown e.g. 18h 12m, Rejoin Date/Time, Join Button Disabled).
- **Step 4: Followers Only Check** → Checks Owner's Followers list. If false: `"❤️ Followers Only Room - Follow the Room Owner to enter."`
- **Step 5: Following Only Check** → Checks Owner's Following list. If false: `"➡ Following Only Room - Only users followed by the Room Owner can enter."`
- **Step 6: Friends Only Check** → Checks mutual friendship. If false: `"👥 Friends Only Room - Become a friend of the Room Owner to enter."`
- **Step 7: Family Only Check** → Checks family guild membership. If false: `"🏠 Family Only Room - Only members of the owner's family can enter."`
- **Step 8: VIP Only Check** → Checks user VIP tier. If requirement not met: `"👑 VIP Only Room - Minimum Requirement VIP 3 (Your VIP: VIP 1)."`
- **Step 9: Invite Only Check** → Checks invitation record. If missing: `"✉ Invitation Required - You need an invitation from the Owner or Co Owner."`
- **Step 10: Password Check** → 4-Digit Password prompt. Incorrect password shows: `"Incorrect Password. Attempts Remaining: 3"`.
- **Step 11: Room Capacity Check** → If capacity reached: `"👥 Room Full (Current Capacity: 500/500)."`
- **Step 12: Success** → `"Joining Room..."`

### 3. Lock Indicator Badges on Room Cards
Room cards display active restriction badges before user taps join:
- `🔓 Public`
- `🔒 Password`
- `👥 Friends`
- `❤️ Followers`
- `➡ Following`
- `👑 VIP`
- `🏠 Family`
- `✉ Invite`

*Multiple active locks are stacked (e.g. `❤️ Followers` + `👑 VIP` + `🔒 Password`), requiring all conditions to be met for Audience entry.*

### 4. Rich "Why Can't I Join?" User Feedback UX
Replaces generic `"Access Denied"` with clear, actionable explanations:
- `❤️ You must follow the Room Owner.`
- `➡ The Room Owner is not following you.`
- `👑 VIP 3 or above is required.`
- `🏠 Only family members can join.`
- `🔒 Enter the correct room password.`
- `🚫 You are banned from this room.`
- `⏳ You were kicked. 17 hours 42 minutes remaining.`
- `👥 Room is full.`

==================================================

# ROOM MEMBER LIST UI (StarMaker Style)

In the **Room Information screen**, member roles must always be displayed in the following strict order:

1. 👑 **Owner** (1) — Gold Tag / Crown (Permanent Room Creator)
2. 💎 **Co Owners** (Level Based) — Purple Diamond Tag
3. 🛡 **Admins** (Level Based) — Blue Shield Tag
4. 🎤 **Host** (Current Seat 1 Occupant) — Red Mic Tag (Visible ONLY on Seat 1)
5. 👥 **Audience** — No special tag

Each user avatar displays their role tag and color badge directly beneath the avatar.

==================================================

# CREANIAAA ARENA ROOM SEAT SYSTEM (Fixed 10 Seats)

### 1. Fixed Seat Capacity
- **Total Stage Seats**: Exactly **10 Fixed Seats** (Seat 1 to Seat 10).
- **Level Immutable**: Total seats will NEVER increase or decrease with Room Level. Always fixed at 10 seats.

### 2. Seat Architecture & Access Control
- **👑 Seat 1 (Host Seat)**:
  - **Tag**: Host
  - **Purpose**: Main room controller, primary seat of the room.
  - **Access**: ✅ Owner, ✅ Co-Owner, ✅ Admin. ❌ Audience (NEVER allowed, even if seat lock is OFF. Permanently protected seat).
- **💎 Seat 2 (Co Host Seat)**:
  - **Tag**: Co Host
  - **Purpose**: Second priority seat (Main singer, main speaker, main performer, backup host).
  - **Access**: ✅ Owner, ✅ Co-Owner, ✅ Admin. ❌ Audience (NEVER allowed, even if seat lock is OFF. Permanently protected seat).
- **Seat 3 to Seat 10 (Guest Seats)**:
  - **Tag**: Dynamic per room mode (e.g. 🎤 Main Singer, 🎤 Guest, 🎤 Speaker).
  - **Purpose**: Public guest seats.
  - **Access**: ✅ Owner, ✅ Co-Owner, ✅ Admin, ✅ Audience (Everyone allowed).

### 3. Independent Seat Lock System
- Every seat has its own independent lock state (`Seat 1 🔒`, `Seat 2 🔒`, `Seat 3 🔓`, `Seat 4 🔒`, `Seat 5 🔓`, etc.).
- **Locked Seat Behavior**: Nobody can sit when a seat is locked. Only permission holders (Owner, Co-Owner, Admin) can unlock a seat. After unlocking, eligible users can sit.

### 4. Occupancy & Technical Rules
- **Occupancy Rule**: **One Seat = One User**. Shared seats or multiple audio streams per seat are strictly prohibited.
- **Server Validation**: `seat_id`, `occupied_by`, `status`. If `occupied_by` already exists, returns `"Seat Full"`.
- **Auto Seat Switch**: Moving from Seat 1 to Seat 5 automatically empties Seat 1 and occupies Seat 5. A user can never occupy two seats simultaneously.
- **Seat Swap**: Only Owner, Co-Owner, Admin can swap seats (e.g., Seat 3 ↔ Seat 7). Audience cannot swap.
- **Force Remove**: Owner, Co-Owner, and Admin can remove normal seat occupants down to the audience. (Owner cannot be removed by lower roles).
- **Auto Leave**: Disconnect, Leave Room, Kick, Ban, Logout, or loss of Internet connection automatically empties the seat.
- **Seat Queue System**: Audience member raises hand -> Queue entry created -> Admin/Owner approves -> User automatically seated on selected seat.

### 5. Dynamic Seat Priority & Mode Labels
- **Seat 1**: 👑 Host
- **Seat 2**: 💎 Co Host
- **Seat 3**: 🎤 Main Singer / Dynamic
- **Seats 4–10**: 🎤 Guest / Dynamic
- *Labels for Seats 3–10 change dynamically based on active room mode (Singing, Debate, Study, Social), but underlying access permissions remain strictly enforced.*

==================================================

# DATABASE SCHEMA & CORE RPCs

### 1. PostgreSQL Tables
- `public.rooms`: Core metadata, levels, XP, `host_id` (Owner), numeric_id, sid.
- `public.room_seats`: Seat index mapping (1 to 10), user occupancy, `is_locked`, `locked_by`.
- `public.room_members`: User membership roster, `role`, `assigned_by`, `assigned_at`, `status`.
- `public.room_role_audit_logs`: Audit history table for role actions (`action`, `room_id`, `target_user_id`, `assigned_by`, `status`, `timestamp`).

### 2. Essential RPCs (`supabase/migrations/202608040001_seat_lock_system.sql` & `202608040000_room_roles_and_permissions.sql`)
- `promote_room_member_role(p_room_id, p_target_user_id, p_new_role)`: Promotes user, writes to Postgres, logs audit event, and broadcasts Realtime update.
- `demote_room_member_role(p_room_id, p_target_user_id)`: Demotes user, updates audit status to `'REVOKED'`, revokes permissions, and broadcasts Realtime update.
- `join_room_seat_v3(p_room_id, p_seat_index)`: Strictly enforces Seat 1 & Seat 2 restriction (Audience blocked) and seat lock state.
- `toggle_seat_lock(p_room_id, p_seat_index)`: Enables independent locking for Seats 1 through 10.

==================================================

# TEST CHECKLIST

✓ Real-Time Role Assign / Revoke Popup System & In-Room Broadcast Banners
✓ In-Room Member Mention System (@Mention search dropdown, profile trigger, golden highlight, chat badge)
✓ Triple Gift Star Metric Display (Today's Stars, Lifetime Total Stars, User Daily Contribution Stars)
✓ 20-Point Anti-Abuse System (Multi-device fingerprinting, self-gifting, join/seat spam, bot detection)
✓ Hidden Trust Score Engine (0–100 score; <30 Trust Score excludes account from VP tasks/rewards/leaderboards)
✓ 10-Minute Idle Freeze Rule & Minimum 1-Minute Seat Duration
✓ VPN, Proxy & Datacenter IP Shield
✓ Dynamic Real-Human Activity Score Calculation
✓ Room Level VP Progression (Levels 1–7 VP Thresholds & Feature Unlocks)
✓ Daily VP Tasks (700 VP Free Target vs 1,000 VP Gold Target)
✓ Dual Progress Bar Fill Rule (Gold gifts fill Gold AND Free task bars simultaneously)
✓ Active Seat VP Accumulation Rate Matrix (1 occupant = 4 VP/min up to 10 occupants = 60 VP/min)
✓ Core Rule Validation: Room Role = Permanent Until Changed
✓ Auto Role & Tag Recovery (Postgres DB reload on restart, logout/login, reconnect, device switch)
✓ 12-Step Room Join Validation Sequence & Fixed 10-Seat Protected Access

==================================================

# CREANIAA ROOM ENGINE - STARMAKER LEVEL PERFORMANCE (MASTER PROMPT)

### MISSION

Transform the entire room engine into a production grade, ultra low latency, real time system that feels as fast as or faster than StarMaker.

The room must never feel slow.

Every tap should produce immediate visual feedback.

Every online user should see the same changes almost simultaneously.

The room must remain smooth with hundreds or thousands of concurrent users.

====================================================
CORE OBJECTIVES
====================================================

• Zero noticeable delay
• Zero fake data
• Zero duplicate events
• Zero inconsistent room state
• Zero unnecessary API calls
• Zero unnecessary widget rebuilds
• Zero frame drops
• Zero UI freezing
• Zero memory leaks
• Zero polling inside rooms

Target 60 FPS minimum.

Support 120 FPS devices.

====================================================
NETWORK ARCHITECTURE
====================================================

Technology Stack

Frontend
Flutter

Backend
Supabase

Database
PostgreSQL

Realtime
WebSocket

Cache
Redis

Realtime Broadcast
Redis Pub/Sub

Storage
Supabase Storage

CDN
Cloudflare CDN or equivalent

Background Jobs
Queue Workers

====================================================
ROOM COMMUNICATION
====================================================

Everything inside a room must work through WebSocket.

Never use REST API for room actions.

Room actions include

Seat Lock
Seat Unlock
Take Seat
Leave Seat
Kick User
Role Change
Host Change
Mic
Mute
Gift
Chat
Typing
Room XP
VP
Leaderboard
Online Count
Notifications
Room Settings

Only Login, Profile, History, Settings and Room List should use REST APIs.

====================================================
REDIS ROOM STATE
====================================================

Keep complete live room state inside Redis.

Store

Current Seats
Locked Seats
Host
Moderators
Mic Status
Mute Status
Online Users
Viewer Count
Room XP
VP
Gift Count
Today's Gifts
Current Background
Room Settings

Never fetch PostgreSQL for every room action.

Redis is the source of truth for live room state.

====================================================
POSTGRESQL
====================================================

Use PostgreSQL only for permanent storage.

Store

Gift History
Transactions
User Profiles
Room History
Daily Statistics
Leaderboards
Reports
Analytics

Never update full rows.

Update only modified fields.

Always use indexes.

Use prepared statements.

Use connection pooling.

====================================================
EVENT FLOW
====================================================

Every room event follows this flow.

User taps button
↓
Immediate local UI update
↓
WebSocket event
↓
Backend validation
↓
Redis update
↓
Redis Pub/Sub
↓
Broadcast
↓
Every client updates instantly

Never wait for server before showing UI changes.

Use optimistic UI everywhere.

Rollback only if validation fails.

====================================================
WEBSOCKET
====================================================

Persistent connection.

Automatic reconnect.

Heartbeat every twenty seconds.

Resume after reconnect.

Restore missed events.

Guarantee event ordering.

Prevent duplicate events.

Use event acknowledgements.

Compress packets.

====================================================
SUPPORTED EVENTS
====================================================

seat_locked
seat_unlocked
seat_taken
seat_left
seat_removed
host_changed
role_changed
gift_sent
message_sent
message_deleted
typing_started
typing_stopped
user_joined
user_left
mute_changed
mic_changed
background_changed
room_updated
xp_updated
vp_updated
leaderboard_updated
notification

====================================================
ROOM JOIN
====================================================

Join room under 300 milliseconds.

Immediately load

Cached avatars
Cached room background
Cached seats
Cached gifts
Cached room info
Cached user list

Then silently synchronize.

Never show blank screen.

Never block UI.

====================================================
ROOM EXIT
====================================================

Immediately

Dispose websocket listeners.
Dispose RTC resources.
Dispose animations.
Dispose timers.
Dispose microphone.
Dispose providers.
Dispose controllers.
Dispose streams.
Clear temporary cache.

Prevent memory leaks.

====================================================
SEAT ENGINE
====================================================

Tap seat

Avatar appears instantly.
Seat animation starts instantly.
Seat status changes instantly.
Background synchronization begins.

If server rejects

Rollback instantly.

====================================================
LOCK SYSTEM
====================================================

Tap Lock

Immediately

Lock icon changes.
Seat disabled.
Animation plays.
Toast: Seat Locked
Send websocket event.

If failed

Rollback.

Same for Unlock.

====================================================
HOST SEAT
====================================================

Host seat validation happens locally.

If non host taps

Instant popup: You can't take Host Seat.

No API request.

====================================================
REMOVE USER
====================================================

Host taps Remove.

Immediately

Seat becomes empty.
Removed animation.
Removed user popup.

Synchronize later.

Rollback only if backend rejects.

====================================================
CHAT
====================================================

Message appears immediately.

Status: Sending

After acknowledgement: Sent

Retry only on failure.

Incoming messages through WebSocket only.

No polling.

====================================================
GIFTS
====================================================

Gift animation starts instantly.

Coins deducted locally.

Gift counter updates.

Leaderboard updates.

Room XP updates.

VP updates.

Background synchronization.

Rollback only for payment failure.

====================================================
ROOM XP
====================================================

Realtime.

No refresh.

Progress bar updates instantly.

Everyone sees identical values.

====================================================
VP
====================================================

Realtime.

Update every connected client.

No refresh.

====================================================
LEADERBOARD
====================================================

Realtime.

Only changed users update.

Never reload whole leaderboard.

====================================================
ONLINE USERS
====================================================

Realtime join.
Realtime leave.
Realtime seat movement.
Realtime role updates.
Realtime mic updates.

====================================================
IMAGE SYSTEM
====================================================

Use AVIF or WebP.

Lazy loading.

Memory cache.

Disk cache.

Preload visible images.

Thumbnail first.

High quality later.

Never reload cached avatars.

====================================================
CDN
====================================================

Serve

Avatars
Room Backgrounds
Gift Assets
Animations
Icons
Images
Videos

Only through CDN.

Never directly from backend.

====================================================
FLUTTER PERFORMANCE
====================================================

Use const widgets.

Use RepaintBoundary.

Avoid unnecessary setState.

Separate providers.

Virtual scrolling.

Image preloading.

Widget caching.

Animation caching.

Background isolates.

Debounce events.

Throttle rapid actions.

Render only visible widgets.

Never rebuild the entire room.

Only rebuild affected widgets.

====================================================
DATABASE PERFORMANCE
====================================================

Indexed queries.

Atomic transactions.

Batch updates.

Prepared statements.

Connection pooling.

Async writes.

Avoid N+1 queries.

Avoid full document updates.

Update only modified fields.

====================================================
REDIS PERFORMANCE
====================================================

Redis stores only live state.

Expire inactive rooms automatically.

Redis Pub/Sub synchronizes multiple backend servers.

Never query PostgreSQL for live room state.

====================================================
FAILURE HANDLING
====================================================

Reconnect automatically.

Restore room state.

Replay missed events.

Prevent duplicate users.

Prevent duplicate gifts.

Prevent duplicate messages.

Prevent duplicate seat assignments.

Recover gracefully after network interruption.

====================================================
SECURITY
====================================================

Validate every event server side.

Prevent double seat.

Prevent fake gifts.

Prevent fake VP.

Prevent fake XP.

Prevent unauthorized role changes.

Prevent race conditions.

Use atomic locking where needed.

====================================================
MONITORING
====================================================

Track

API latency
WebSocket latency
Redis latency
Database latency
Frame rendering
Dropped frames
Memory usage
CPU usage
Crash logs
Realtime errors

====================================================
TARGET PERFORMANCE
====================================================

Tap Feedback: Under 10 ms
UI Response: Under 16 ms
Seat Animation: Under 16 ms
Popup: Under 20 ms
Redis Update: Under 5 ms
Backend Validation: Under 20 ms
WebSocket Broadcast: Under 20 ms
Client Event Processing: Under 10 ms
Room Join: Under 300 ms
Avatar From Cache: Under 10 ms
Gift Animation: Instant
Message Visible: Instant
Room FPS: 60 minimum
High Refresh Devices: 120 FPS

====================================================
FINAL REQUIREMENT
====================================================

The room must behave like a premium production application similar to StarMaker.

Every tap must feel instant.

Every room participant must see identical room state almost simultaneously.

No loading spinners for normal room actions.

No visible delay.

No polling.

No fake data.

No inconsistent UI.

No duplicate events.

No full room refresh.

No unnecessary API calls.

No unnecessary widget rebuilds.

The implementation must prioritize low latency, scalability, reliability, consistency, fault tolerance, and an exceptional user experience while supporting thousands of concurrent users without degrading performance.

