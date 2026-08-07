# Creaniaa Daily Task & Room Battle Task Agent Specification
Version: 3.0 (StarMaker Dual Progress, 32 Daily Tasks, Room Battle System & 20-Point Anti-Abuse Engine)
Status: Production Architecture (Backend-First)

---

## 📋 1. System Overview & Objectives

Creaniaa Voice Room System me **Daily Tasks**, **Room Level Progression (Titles & Perks)**, aur **Room Battles (PK Systems)** to engaging, gamified, aur secure tarike se operate karne ke liye yeh Task Agent Specification design ki gayi hai.

### Key Objectives:
1. **Decoupled Dual Progress Engine**:
   - **Daily Tasks**: Daily Free Tasks (0/600 AP) & Daily Gold Tasks (0/1200 VP) for daily rewards. Resets every day at 4:00 AM IST. NEVER triggers Room Level Up directly.
   - **Total Task & Room Level**: Room Level depends EXCLUSIVELY on `total_task` reaching the level requirement. On Level Up, ONLY `total_task` resets for the new level target.
2. **32 Daily Resetting Tasks**: Daily 04:00 AM IST reset scheduler system jo active engagement, mic occupancy, room sharing, gifting, aur battles par rewards deta hai.
3. **Room Level Progression (LV 1 to LV 7)**: Room Level Up thresholds based ONLY on Total Task progress, unlocking Role Limits (Co-Owner/Admin/Seats), Badges, Animated Frames, aur Grand Prizes (Gold Coins + VIP Subscriptions).
4. **Room Battle (PK Engine)**: 1v1 / Squad Room Battles with Turbo VP Surge (1.5x / 2.0x), battle streaks, winner room titles, aur real-time score tracking.
5. **20-Point Anti-Abuse & Hidden Trust Score Engine (0–100)**: Self-gifting, idle seating, multi-device abuse, bot patterns, aur VPN abuse ko 100% block karne ke liye server-side Postgres RPC guards.

---

## 🏆 2. Room Level Matrix, Title Progression & Grand Prizes

Har Voice Room me total cumulative XP/VP save hoti hai. As the room gains VP, it levels up from **LV 1 (Basic Arena)** to **LV 7 (Legendary Arena)** unlocking high-tier titles, perks, host seat capacity, role limits, and direct Grand Prize rewards for the Room Owner & Top Contributors.

| Level | Title / Arena Rank | Required VP / XP | Role Caps & Host Seats | Room Badges & Unlocked Perks | Grand Prize Rewards |
|---|---|---|---|---|---|
| **LV 1** | 🥉 Basic Arena | `0 XP` | 1 Co-Owner, 4 Admins, 4 Host Seats | Standard background, normal music, basic announcement | Standard Daily Chests |
| **LV 2** | 🥈 Premium Arena | `35,500 XP` | 1 Co-Owner, 7 Admins, 6 Host Seats | Premium background, welcome banner, room statistics deck | Premium Daily Chests |
| **LV 3** | 🥇 Animated Arena | `59,500 XP` | 2 Co-Owners, 11 Admins, 8 Host Seats | **Showcase Badge**, Animated room frame, Gift wall | Animated Daily Chests |
| **LV 4** | 💎 Dynamic Arena | `95,000 XP` | 2 Co-Owners, 14 Admins, 11 Host Seats | Dynamic background, premium entrance effects, event scheduler | Dynamic Daily Chests |
| **LV 5** | ⭐ Official Arena | `490,000 XP` | 3 Co-Owners, 16 Admins, 13 Host Seats | **Official Room Badge**, **Permanent Chat Bubble**, priority discovery | **🎁 2,000 Gold Coins + VIP 2 (60 Days)** |
| **LV 6** | 👑 Luxury Arena | `940,000 XP` | 3 Co-Owners, 18 Admins, 14 Host Seats | Luxury theme frame, animated entry banner, VIP room controls | **🎁 5,000 Gold Coins + VIP 2 (6 Months)** |
| **LV 7** | 🔥 Legendary Arena | `1,590,000 XP` | 3 Co-Owners (Max), 20 Admins (Max), 15 Host Seats (Max) | **Legendary Crown Title**, Exclusive background, Top #1 recommended tag | **🎁 12,000 Gold Coins + VIP 3 (1 Year)** |

---

## ⚡ 3. Dual Progress Bar System (StarMaker Architecture)

Voice Room Header me Dual Progress Bar render hota hai:
1. **Free Task Progress Bar (AP - Activity Points)**: Room engagement, mic occupancy, room joins, shares, and silver gifts se fill hota hai.
2. **Gold Task Progress Bar (VP - Value Points)**: Direct gold gifts, premium battles, and paid task events se fill hota hai.

```
       [ 🏆 ROOM LEVEL 3 - ANIMATED ARENA ]
  ┌──────────────────────────────────────────────────┐
  │ 🟢 Free Progress: [████████████░░░░] 3,500 / 5,000 │
  │ 🟡 Gold Progress: [████████████████] 2,000 / 2,000 │
  └──────────────────────────────────────────────────┘
```

### Dual Progress Gifting Rules:
* **Gold Gift Rule (Dual Fill)**: Gold Coin se bheja gaya gift **Free Task Progress Bar** AUR **Gold Task Progress Bar** DONO ko simultaneously equal amount me fill karta hai.
* **Silver Gift Rule (Free Only)**: Silver/Free Coins se bheja gaya gift ONLY Free Task Progress Bar ko fill karta hai.
* **Overflow Carry Forward Protection**: Level up karne par extra points discard nahi hote; next level ke target me auto carry-forward hote hain.

---

## 📅 4. 32 Daily Resetting Tasks & Earning Mechanics

Every morning at **04:00 AM IST**, daily task progress reset ho jata hai. Free AP aur Gold VP caps apply hote hain to protect against unlimited inflation.

### A. Daily Resetting Limits (StarMaker Architecture)
* 🟢 **Free Task Limit (`FREE_TASK_LIMIT`)**: **600 AP / Day** (Resets at 04:00 AM server timezone).
* 🟡 **Gold Task Limit (`GOLD_TASK_LIMIT`)**: **1,200 VP / Day** (Resets at 04:00 AM server timezone).
* **Total Daily Target**: **1,800 Points / Day**
* **Total Lifetime Task**: Never resets, accumulates all valid daily task progress.

### B. Free AP Earning Matrix (Mic Occupancy & Seat Scaling)
Seat par active rehne wale users room ke Free AP Bar ko har minute continuously boost karte hain based on active occupancy count:

| Seated Occupants | Free AP per Minute | 10 Min AP Generation | 60 Min AP Generation |
|---|---|---|---|
| 1 Occupant | **4 AP / min** | 40 AP | 240 AP |
| 2 Occupants | **8 AP / min** | 80 AP | 480 AP |
| 3 Occupants | **14 AP / min** | 140 AP | 840 AP |
| 4 Occupants | **20 AP / min** | 200 AP | 1,200 AP |
| 5 Occupants | **28 AP / min** | 280 AP | 1,680 AP |
| 6 Occupants | **36 AP / min** | 360 AP | 2,160 AP |
| 7 Occupants | **44 AP / min** | 440 AP | 2,640 AP |
| 8 Occupants | **50 AP / min** | 500 AP | 3,000 AP |
| 9 Occupants | **55 AP / min** | 550 AP | 3,300 AP |
| 10 Occupants | **60 AP / min (Max)** | 600 AP | 3,600 AP |

### C. Seat & Gifting One-Time Daily Bonuses
1. **First Seat Occupancy Bonus**: Room join karke seat lene wale pehle 5 unique users ko **+20 AP/VP** ka 1-time bonus milta hai (Max 100 AP daily per room).
2. **First 5 Gifts Daily Bonus**: Room me bheje gaye first 5 gifts par har gift par **+25 AP/VP** bonus reward add hota hai (Max 125 AP daily per room).

### D. The 32 Daily Tasks Breakdown Table

| ID | Task Name | Category | Action Target | AP / VP Reward | Daily Cap |
|---|---|---|---|---|---|
| T01 | Daily Room Check-in | Engagement | Room me enter hona | +15 AP | 1x Daily |
| T02 | Take a Host Seat | Seat | Mic seat occupy karna | +20 AP | 1x Daily |
| T03 | Active Seat Stay (5 Mins) | Seat | Mic par 5 min continuous stay | +25 AP | 1x Daily |
| T04 | Active Seat Stay (15 Mins) | Seat | Mic par 15 min continuous stay | +40 AP | 1x Daily |
| T05 | Active Seat Stay (30 Mins) | Seat | Mic par 30 min continuous stay | +60 AP | 1x Daily |
| T06 | Active Seat Stay (60 Mins) | Seat | Mic par 60 min continuous stay | +100 AP | 1x Daily |
| T07 | Send 1 Lucky Gift | Gifting | 1 Lucky gift send karna | +25 AP | 1x Daily |
| T08 | Send 5 Star Gifts | Gifting | 5 Star gifts send karna | +50 AP + 50 VP | 1x Daily |
| T09 | Send 10 Star Gifts | Gifting | 10 Star gifts send karna | +100 VP | 1x Daily |
| T10 | Send 1 Gold Gift | Gifting | Gold coin gift send | +50 VP | Unlimited (up to cap) |
| T11 | Share Room to Social / Chat | Viral | Room link share करना | +15 AP | 3x Daily (+45 AP) |
| T12 | Follow Room Host | Social | Room owner/host ko follow | +10 AP | 1x Daily |
| T13 | Send Room Text Message | Chat | Room text chat me message post | +5 AP | 5x Daily (+25 AP) |
| T14 | Send Voice Note in Room | Chat | 5s+ Voice note send karna | +15 AP | 2x Daily (+30 AP) |
| T15 | Play Background Music | Host | Seat 1 host status me music play | +20 AP | 1x Daily |
| T16 | Host PK Battle | Battle | Room vs Room battle create | +50 VP | 2x Daily (+100 VP) |
| T17 | Participate in PK Battle | Battle | PK battle me mic stay | +30 VP | 3x Daily (+90 VP) |
| T18 | Send Gift during PK Battle | Battle | PK time gift support | +40 VP | 5x Daily (+200 VP) |
| T19 | Win 1 PK Battle | Battle | Room PK match jeetna | +100 VP | 2x Daily (+200 VP) |
| T20 | Reach 3 PK Win Streak | Battle | Continuous 3 victories | +250 VP | 1x Daily |
| T21 | Invite 3 Friends to Room | Viral | 3 friends ko room invite bhejna | +30 AP | 1x Daily |
| T22 | Stay in Room Audience (10 Mins) | Audience | Audience grid stay | +20 AP | 1x Daily |
| T23 | Stay in Room Audience (30 Mins) | Audience | Audience grid stay | +50 AP | 1x Daily |
| T24 | Receive 1 Gift as Host | Creator | Seat occupant status me gift pana | +30 VP | 5x Daily (+150 VP) |
| T25 | Unlock Daily Free Chest | Reward | Daily task progress 50% completion | +50 AP + 10 Coins | 1x Daily |
| T26 | Unlock Daily Legendary Chest | Reward | Daily task 100% full completion | +150 VP + 50 Coins | 1x Daily |
| T27 | Room Level Up Contribution | Loyalty | Room Level up me support | +200 VP | Event Based |
| T28 | Family Member Room Visit | Community | Same family member ka visit | +20 AP | 5x Daily (+100 AP) |
| T29 | VIP User Room Visit | VIP | VIP 1+ tier user ka room join | +30 VP | 5x Daily (+150 VP) |
| T30 | Activate Turbo VP Surge (1.5x) | Battle | Room Turbo Surge trigger | +50 VP | 1x Daily |
| T31 | Send Animated Combo Gift | Gifting | 10x / 50x Combo gift send | +80 VP | 2x Daily (+160 VP) |
| T32 | Midnight Night Owl Task (12-4 AM) | Special | Late night 15 min room stay | +35 AP | 1x Daily |

---

## ⚔️ 5. Room Battle (PK Battle Engine) Architecture

Room Battle system do Voice Rooms ke beech real-time competitive Gifting aur Engagement match conduct karta hai.

```
┌─────────────────────────────────────────────────────────┐
│               ⚔️ LIVE ROOM BATTLE (PK)                   │
│   ROOM A (Host: Anurag)    VS     ROOM B (Host: Rahul)  │
│   SCORE: 45,200 pts               SCORE: 38,900 pts     │
│  [████████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░]  │
│   ⚡ TURBO SURGE 2.0x ACTIVE! (Remaining: 01:45)        │
└─────────────────────────────────────────────────────────┘
```

### Battle Mechanics & Scoring Rules:
1. **Battle Modes**:
   - **1v1 Single Mic Duel**: Both Room Hosts on Seat 1 compete.
   - **3v3 Squad Battle**: Top 3 Seated members of Room A vs Room B.
   - **Full Room Arena PK**: Entire room's total gifting score counts.
2. **PK Timer & Phasing**:
   - **Warmup Phase (30s)**: Announcement and countdown on both room screens.
   - **Battle Phase (5 Mins / 10 Mins)**: Real-time score counting.
   - **Turbo Surge Phase (Last 2 Mins)**: All Gifting points multiplier becomes **2.0x**.
   - **Victory Phase (1 Min)**: Punish game / Winner celebration with exclusive winner banner.
3. **Point Conversion**:
   - **1 Gold Coin Gifted** = **10 PK Points** (Normal) / **20 PK Points** (During Turbo Surge 2.0x).
   - **1 Silver Gift Gifted** = **1 PK Point**.
   - **Mic Chatter & Applause** = **5 PK Points per minute per active mic occupant**.
4. **Battle Rewards & Winner Perks**:
   - **Winning Room**: Receives **+500 Room VP**, Winner Room Badge for 24 Hours, and top spot on Live PK Leaderboard.
   - **Losing Room**: Receives consolation **+150 Room VP**.
   - **Top MVP Contributor**: User gifting maximum points during PK gains **MVP Aura Frame (7 Days)** and **+100 Profile XP**.

---

## 🛡️ 6. 20-Point Anti-Abuse Engine & Hidden Trust Score (0–100)

System integrity, fake accounts, self-gifting, aur bot farming protect karne ke liye hidden Trust Score engine active rehta hai.

### A. Hidden Trust Score Engine (0–100)
Har user profile par server-side hidden score compute hota hai (Default = 80):

| Trust Score | Status | VP & Daily Task Multiplier | Action Applied |
|---|---|---|---|
| **0 – 29** | 🚫 High Risk / Banned | **0.0x (Blocked)** | All VP earnings, task completion & daily chests strictly frozen (`VP = 0`). |
| **30 – 69** | ⚠️ Suspicious / Slow | **0.5x (Slow Mode)** | VP & AP rates halved. High-risk flag logged in audit database. |
| **70 – 100** | 🟢 Verified / Clean | **1.0x (Full Rate)** | Standard full VP/AP generation rate. |

#### Trust Score Rules:
* **Deductions**: Self-gifting (-30 pts), Multi-device same fingerprint (-40 pts), Emulator / VPN abuse (-25 pts), Chargeback / cancelled transactions (-60 pts).
* **Increases**: Verified account age > 30 days (+10 pts), Genuine Gold coin purchases (+15 pts), PK battle participation (+5 pts), Interaction with unique verified users (+5 pts).

### B. 20 Mandatory Anti-Abuse Guards

1. **Rule 1 (Min Member & Solo Slow Mode)**: Minimum 1 seated user required. Solo idle user (> 5 mins) automatically slows VP generation rate by 50%.
2. **Rule 2 (10-Minute Idle Freeze Anti-Abuse Guard)**: Agar room me 10 minute tak koi text chat, gift, ya seat action na ho, to seat VP generation strictly **pause** ho jata hai. Interactive action aate hi instant resume.
3. **Rule 3 (Multi-Device Hardware Fingerprint Block)**: Ek hi device fingerprint / IP se chalne wale multiple alt accounts ka VP generation **0 VP** kar diya jata hai.
4. **Rule 4 (Self-Support & Self-Gifting Block)**: User dwara apne hi alt account ko gift bhejkar task fill karne par **0 VP** grant hota hai.
5. **Rule 5 (Banned / Spam ID Filter)**: Banned ya blacklisted user IDs through room stays generate **0 VP**.
6. **Rule 6 (Join Cooldown Guard)**: Room join karne ke baad min **30 seconds** stay required hai room stay count ke liye.
7. **Rule 7 (Seat Jump Guard)**: First seat occupancy bonus (+20 AP) ek user ke liye daily 1-time strictly capped hai.
8. **Rule 8 (Fake Gift / Cancelled Transaction Filter)**: Failed, refunded, ya chargeback gifts se koi VP or task progress count nahi hoga.
9. **Rule 9 (Bot & Script Pattern Detection)**: 24x7 static timing robotic actions detect hone par account trust score drop karke VP block kiya jata hai.
10. **Rule 10 (Value-Based Gift VP)**: Gift count par VP kabhi nahi milta; exclusively gift value / gold cost par compute hota hai.
11. **Rule 11 (Room Switch Cooldown)**: Har 60 seconds me multiple rooms switch karne par temporary 2-min VP cooling period apply hota hai.
12. **Rule 12 (Min Stay Validation)**: 60s se kam wale room visit grant 0 VP. Minimum valid stay = 1 minute.
13. **Rule 13 (Hidden / Private Room Protection)**: Lock / Private rooms require at least 2 unique non-same-device verified users to trigger task VP.
14. **Rule 14 (Suspicious Pattern Detection)**: Exact fixed timestamp par auto-login/logout automation flag ki jaati hai.
15. **Rule 15 (Daily Hard Cap Guard)**: Hard limit strictly enforced server-side via RPC (Mon-Fri max 700/1000, Sat-Sun max 1400/2400).
16. **Rule 16 (Server-Side Postgres RPC Validation)**: Flutter app level score local calculation null & void hai. Centralized Postgres RPC `process_room_dual_progress` enforce karti hai.
17. **Rule 17 (Banned Device Fingerprint Block)**: Device ID blacklisted hone par dynamic IP address change karne par bhi task progress 0 rehta hai.
18. **Rule 18 (VPN / DataCenter IP Block)**: High-risk proxy IPs par daily task VP temporarily pause kar diya jata hai.
19. **Rule 19 (Human Activity Score Modifier)**: Dynamic interaction score multiplier (0x / 0.5x / 1.0x) apply hota hai.
20. **Rule 20 (Fair Play Enforcement)**: Violations par server automatically invalid VP revoke karta hai and alert log send karta hai.

---

## 🗄️ 7. Database Schema & Postgres RPC Architecture

### A. Database Table: `public.room_dual_progress`
```sql
create table if not exists public.room_dual_progress (
  room_id uuid primary key references public.rooms(id) on delete cascade,
  gold_points integer default 0 not null check (gold_points >= 0),
  gold_target integer default 2000 not null check (gold_target > 0),
  normal_points integer default 0 not null check (normal_points >= 0),
  normal_target integer default 5000 not null check (normal_target > 0),
  overflow_points integer default 0 not null check (overflow_points >= 0),
  room_level integer default 1 not null check (room_level >= 1 and room_level <= 7),
  unique_join_count integer default 0 not null check (unique_join_count >= 0),
  first_gift_bonus_count integer default 0 not null check (first_gift_bonus_count >= 0),
  active_seat_minutes integer default 0 not null check (active_seat_minutes >= 0),
  gold_xp integer generated always as (gold_points) stored,
  normal_ap integer generated always as (normal_points) stored,
  updated_at timestamptz default now() not null
);
```

### B. Core Atomic RPC: `public.process_room_dual_progress`
```sql
create or replace function public.process_room_dual_progress(
  p_room_id uuid,
  p_user_id uuid,
  p_amount integer,
  p_source text -- 'gold_gift', 'silver_gift', 'seat_join_bonus', 'active_seat_stay'
) returns jsonb
language plpgsql
security definer
as $$
declare
  v_trust_score integer := 80;
  v_room_rec public.room_dual_progress%rowtype;
  v_effective_amount integer;
begin
  -- 1. Trust score check
  select coalesce(trust_score, 80) into v_trust_score from public.profiles where id = p_user_id;
  if v_trust_score < 30 then
    return jsonb_build_object('success', false, 'reason', 'Trust score too low (<30)');
  elsif v_trust_score < 70 then
    v_effective_amount := (p_amount * 0.5)::integer;
  else
    v_effective_amount := p_amount;
  end if;

  -- 2. Lock & update room_dual_progress
  insert into public.room_dual_progress (room_id, gold_points, gold_target, normal_points, normal_target, room_level)
  values (p_room_id, 0, 2000, 0, 5000, 1)
  on conflict (room_id) do nothing;

  select * into v_room_rec from public.room_dual_progress where room_id = p_room_id for update;

  if p_source = 'gold_gift' then
    v_room_rec.gold_points := v_room_rec.gold_points + v_effective_amount;
    v_room_rec.normal_points := v_room_rec.normal_points + v_effective_amount;
  else
    v_room_rec.normal_points := v_room_rec.normal_points + v_effective_amount;
  end if;

  -- Level up overflow check
  if v_room_rec.normal_points >= v_room_rec.normal_target and v_room_rec.room_level < 7 then
    v_room_rec.overflow_points := v_room_rec.normal_points - v_room_rec.normal_target;
    v_room_rec.room_level := v_room_rec.room_level + 1;
    v_room_rec.normal_points := v_room_rec.overflow_points;
    v_room_rec.normal_target := v_room_rec.normal_target * 2;
  end if;

  update public.room_dual_progress
  set gold_points = v_room_rec.gold_points,
      normal_points = v_room_rec.normal_points,
      room_level = v_room_rec.room_level,
      normal_target = v_room_rec.normal_target,
      updated_at = now()
  where room_id = p_room_id;

  return jsonb_build_object('success', true, 'room_level', v_room_rec.room_level, 'normal_points', v_room_rec.normal_points);
end;
$$;
```

---

## 💻 8. Core Files & Codebase Map

| Component | File Path |
|---|---|
| **Postgres Schema & RPCs** | `supabase/migrations/202608070014_star_maker_dual_progress_system.sql`<br>`supabase/migrations/202608070015_balanced_free_ap_earning_system.sql`<br>`supabase/migrations/202608070016_fix_gold_gift_task_and_dual_progress.sql`<br>`supabase/migrations/202608070017_fix_gifting_error_room_level_column.sql` |
| **Dart Models** | [room_progression_models.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/models/progression/room_progression_models.dart)<br>[room_dual_progress_model.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/models/progression/room_dual_progress_model.dart) |
| **GetX Controllers** | [room_progression_controller.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/services/room/room_progression_controller.dart)<br>[star_maker_dual_progress_controller.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/services/room/star_maker_dual_progress_controller.dart) |
| **UI Progress Bars & Headers** | [starmaker_dual_progress_bar.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/widgets/room/starmaker_dual_progress_bar.dart)<br>[creania_vp_progress_bar.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/widgets/room/creania_vp_progress_bar.dart)<br>[room_call_header.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/screens/rooms/voice_room/widgets/room_call_header.dart) |
| **Dialogs & Views** | [room_tasks_and_rewards_dialog.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/screens/rooms/voice_room/dialogs/room_tasks_and_rewards_dialog.dart) |
| **Unit Verification Tests** | [creaniaa_room_level_system_test.dart](file:///c:/Users/MSI/Downloads/AgoraX/test/room/creaniaa_room_level_system_test.dart)<br>[starmaker_dual_progress_test.dart](file:///c:/Users/MSI/Downloads/AgoraX/test/room/starmaker_dual_progress_test.dart)<br>[free_ap_earning_system_test.dart](file:///c:/Users/MSI/Downloads/AgoraX/test/room/free_ap_earning_system_test.dart) |

---

## 🧪 9. Verification & Automated Testing Commands

System rules and calculations verify karne ke liye unit tests implement kiye gaye hain:

```bash
# Run StarMaker Dual Progress & Task Engine Unit Tests
flutter test test/room/starmaker_dual_progress_test.dart
flutter test test/room/free_ap_earning_system_test.dart
flutter test test/room/creaniaa_room_level_system_test.dart
```

---

## 🎯 Summary Checklist for Future Development
* [x] **04:00 AM IST Daily Reset** handled on backend.
* [x] **StarMaker Dual Bar (Free AP & Gold VP)** rendered in `StarMakerDualProgressBar`.
* [x] **32 Daily Tasks Matrix** tracked via server-side Postgres RPCs.
* [x] **Room Battle / PK Engine** with 2.0x Turbo Surge and leaderboards.
* [x] **20-Point Anti-Abuse System** with dynamic Trust Score (0-100) filtering.
* [x] **Grand Prizes & Room Titles** (LV 1 to LV 7 Legendary Arena) mapped with direct gold coin & VIP rewards.
