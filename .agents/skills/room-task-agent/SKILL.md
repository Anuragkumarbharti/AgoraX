---
name: room-task-agent
description: Specialized rules, level progression matrix, 32 daily reset tasks, Turbo VP surge engine, role/host seat caps, and Grand Prize rewards for Creania Arena.
---

# Room Task Agent (Creania Arena Level & Task Progression)

This skill defines the rules, backend RPC integration, level progression thresholds, daily resets, host seat caps, and Grand Prizes for **Room Task Agent** in Creania Arena.

## 1. Level Matrix & Grand Prizes

| Level | Required XP / VP | Grand Prize Rewards | Role Caps & Host Seats | Unlocked Perks & Features |
|---|---|---|---|---|
| **LV 1 (Basic Arena)** | `0 XP` | Standard Daily Rewards | 1 Co-Owner, 4 Admins, 4 Host Seats | Basic background, basic announcement, normal daily tasks, room music |
| **LV 2 (Premium Arena)** | `35,500 XP` | Standard Daily Rewards | 1 Co-Owner, 7 Admins, 6 Host Seats | Premium background, welcome banner, room statistics, room music |
| **LV 3 (Animated Arena)** | `59,500 XP` | Standard Daily Rewards | 2 Co-Owners, 11 Admins, 8 Host Seats | Animated room frame, gift wall, **Showcase Badge**, room music |
| **LV 4 (Dynamic Arena)** | `95,000 XP` | Standard Daily Rewards | 2 Co-Owners, 14 Admins, 11 Host Seats | Dynamic background, premium room effects, event scheduler, room music |
| **LV 5 (Official Arena)** | `490,000 XP` | **🎁 2,000 Gold Coins + VIP 2 (60 Days)** | 3 Co-Owners, 16 Admins, 13 Host Seats | Official room badge, **Permanent Chat Bubble**, premium discovery, advanced analytics |
| **LV 6 (Luxury Arena)** | `940,000 XP` | **🎁 5,000 Gold Coins + VIP 2 (6 Months)** | 3 Co-Owners, 18 Admins, 14 Host Seats | Luxury theme, animated entry, VIP room features, room music |
| **LV 7 (Legendary Arena)** | `1,590,000 XP` | **🎁 12,000 Gold Coins + VIP 3 (1 Year)** | 3 Co-Owners (Max), 20 Admins (Max), 15 Host Seats (Max) | Legendary crown, exclusive backgrounds, highest discovery priority, official recommendation |

## 2. Daily Task & Reset Rules
* **04:00 AM IST Daily Reset:** Daily progress resets to 0 every morning at 04:00 AM IST. Total Arena XP is preserved permanently.
* **Daily Capping & Weekend Bonus:**
  - Weekday Limit: 🟢 Free Tasks = 700 VP, 🟡 Gold Tasks = 1000 VP (1700 Total).
  - Weekend Limit (Sat + Sun): 🟢 Free Tasks = 1400 VP, 🟡 Gold Tasks = 2400 VP (3800 Total + Legendary Chest).
  - Once daily limit is reached (7001st / 1701st task), 0 VP is granted until 04:00 AM IST reset.
* **Active Stage Seat Per-Minute Matrix:** 1: 4 VP, 2: 8 VP, 3: 14 VP, 4: 20 VP, 5: 28 VP, 6: 36 VP, 7: 44 VP, 8: 50 VP, 9: 55 VP, 10: 60 VP.
* **Bonuses:** First 5 Gifts Daily Bonus (+25 VP per gift); First Seat Occupancy Bonus (+20 VP).
* **Gold Dual Progress Rule:** Gold gifts add progress to BOTH Free Task & Gold Task progress bars simultaneously; Silver gifts add progress ONLY to Free Task.
* **10-Minute Idle Freeze Anti-Abuse Guard:** Pauses seat VP if no interaction occurs for 10 minutes. Resumes instantly on new interaction.
* **Overflow Carry Forward Protection:** Extra progress on level upgrade carries forward into the next level target.

## 5. Daily Task Anti-Fake Rules & Hidden Trust Score Engine (0-100)
1. **Hidden Trust Score Engine (0–100):** Hidden score assigned per profile (Default: 80).
   - **Score < 30:** VP earning, task progress, & daily chests are **strictly disabled/blocked** (`VP = 0`).
   - **Score 30–69:** 50% slow mode applied to VP generation.
   - **Score 70–100:** 1.0x full VP generation rate.
   - **Deductions:** Self-gifting (-30), Multi-device abuse (-40), Emulator/VPN abuse (-25), Chargeback (-60).
   - **Increases:** Old verified account (+10), genuine purchases (+15), PK participation (+5), interaction with unique real users (+5).
2. **20 Mandatory Anti-Abuse Guards:**
   - **Rule 1 (Min Member & Solo Slow Mode):** Requires 1 seated occupant; solo idle user >5 min slows VP rate by 50%.
   - **Rule 2 (10-Min Idle Freeze):** 10 minutes of zero room interaction automatically pauses VP.
   - **Rule 3 & 4 (Multi-Device & Self-Support Block):** Self-gifting or alt IDs on same device ID generate **0 VP**.
   - **Rule 5 (Spam ID Filter):** Banned/high-risk IDs generate 0 VP.
   - **Rule 6 (Join Cooldown):** 30s cooldown required between room joins to count stay time.
   - **Rule 7 (Seat Jump Guard):** First seat occupancy bonus (+20 VP) is strictly 1-time per user daily.
   - **Rule 8 (Fake Gift Filter):** Refunded/cancelled gifts generate 0 VP.
   - **Rule 9 (Bot Detection):** 24x7 robotic pattern accounts have VP disabled.
   - **Rule 10 (Value-Based Gift VP):** VP is calculated by Gift Value/Stars, never gift counts.
   - **Rule 11 (Room Switch Cooldown):** 60s cooldown required when switching rooms before stay VP starts.
   - **Rule 12 (Min Stay Validation):** Stays under 60s grant 0 VP; min valid stay = 1 min.
   - **Rule 13 (Hidden Room Protection):** Private rooms require unique verified user interaction.
   - **Rule 14 (Suspicious Pattern Detection):** Exact daily login/logout timings raise risk score.
   - **Rule 15 (Daily VP Cap):** Hard caps enforced (700/1000 Mon-Fri, 1400/2400 Sat-Sun).
   - **Rule 16 (Server Validation):** All VP additions are validated server-side via Postgres RPC (`add_room_vp`).
   - **Rule 17 (Banned Device Block):** Banned device fingerprints receive 0 VP.
   - **Rule 18 (VPN / Proxy Block):** High-risk VPN/datacenter IPs temporarily disable tasks.
   - **Rule 19 (Human Activity Score):** Dynamic score modifier enforces 0x / 0.5x / 1.0x multipliers.
   - **Rule 20 (Fair Play Enforcement):** Server revokes VP, cancels tasks, and flags accounts on violation.

## 3. Core File Architecture
* **Migration SQL**: `supabase/migrations/202608070006_creania_room_level_and_task_engine.sql`
* **Models**: `lib/models/progression/room_progression_models.dart`
* **Controller**: `lib/services/room/room_progression_controller.dart`
* **UI Bar**: `lib/widgets/room/creania_vp_progress_bar.dart` & `lib/screens/rooms/voice_room/widgets/room_call_header.dart`
* **Dialogs**: `lib/screens/rooms/voice_room/dialogs/room_tasks_and_rewards_dialog.dart`
* **Unit Tests**: `test/room/creaniaa_room_level_system_test.dart`
