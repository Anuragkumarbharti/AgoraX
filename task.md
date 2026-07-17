# Task Checklist

- [x] Write Progression Calibration Database Migration (`202607170011_adjust_progression_rules.sql`)
  - [x] Increase XP curve requirements up to Level 60 (Base 200, 1.11 multiplier)
  - [x] Configure ad rewards (500 Silver + 1-5 Gold) and active daily limit checks
  - [x] Configure Silver Spin probabilities (95% for 50-200 silver, 0.0091 gold 1-5, 0.0098 silver 200+)
  - [x] Configure minute-by-minute voice room task XP and Silver rewards
  - [x] Rebuild check-in status and claim procedures into a rolling 7-day streak calendar (with reset on miss)
- [x] Configure AdMob SDK
  - [x] Add `google_mobile_ads` dependency in `pubspec.yaml`
  - [x] Add App ID in AndroidManifest.xml
  - [x] Add GADApplicationIdentifier in Runner/Info.plist
  - [x] Implement AdmobService (`lib/services/admob_service.dart`)
- [x] Integrate progression events in App startup (`lib/main.dart`)
- [x] Integrate voice room timers in RoomController (`lib/services/room_controller.dart`)
- [x] Redesign Progression Center UI (`lib/screens/profile/progression_center_screen.dart`)
  - [x] Rebuild Check-in Calendar tab to horizontal 7-day rolling layout with detail cards
  - [x] Wire Ad watch trigger to call `AdmobService` interstitial
- [x] Verify with unit tests (`test/progression_system_test.dart`)
