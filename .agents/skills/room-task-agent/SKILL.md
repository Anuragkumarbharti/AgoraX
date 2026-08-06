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
* **32 Total Tasks per Day:** 14 Normal Daily Tasks, 8 Gold Tasks, 6 Team Arena Tasks, 4 Community Arena Tasks.
* **4:00 AM Reset:** Daily progress counters reset to 0 every morning at 4:00 AM; Total Arena XP is preserved permanently.
* **Active Member Turbo Surge:** `Surge Multiplier = 1.0 + (activeMemberCount * 0.15)`.

## 3. Core File Architecture
* **Migration SQL**: `supabase/migrations/202608070006_creania_room_level_and_task_engine.sql`
* **Models**: `lib/models/progression/room_progression_models.dart`
* **Controller**: `lib/services/room/room_progression_controller.dart`
* **UI Bar**: `lib/widgets/room/creania_vp_progress_bar.dart` & `lib/screens/rooms/voice_room/widgets/room_call_header.dart`
* **Dialogs**: `lib/screens/rooms/voice_room/dialogs/room_tasks_and_rewards_dialog.dart`
* **Unit Tests**: `test/room/creaniaa_room_level_system_test.dart`
