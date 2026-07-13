# Tasks Checklist - Universal Purchase & Expiry Rule

- [x] Remove duplicate silverCoins key logic in study_category_controller.dart and career_progression_controller.dart
- [x] Implement completedTaskIds tracking and loading in study_category_controller.dart
- [x] Implement `checkExpirations()`, `purchaseOrRenewCustomItem()`, and `getActiveReminders()` utilities in `CustomizationController`
- [x] Connect `checkExpirations()` inside customization screen initialization
- [x] 4. UI & Screen Updates (`lib/screens/rooms/voice_room_call_screen.dart`)
  - [x] Display seat avatars, premium frames, levels, vip/noble badges, mic status, speaking animations
  - [x] Display seat-specific gift count, star counts, and latest gift combo
  - [x] Display real-time lifetime and today room statistics in the top header capsules
  - [x] Integrate reactive XP progression bar and Level indicators
  - [x] Build upload/crop/picker sheets for room owner to edit room banner
- [x] 5. Verification & Validation
  - [x] Write integration test cases for real-time room updates, banner changes, and event formatting
  - [x] Validate and run project locally using `flutter analyze`
  - [x] Resolve nested Obx error triggers and empty chat/seat observer warnings
  - [x] Synchronize banner updates reactively across list cards and room views
