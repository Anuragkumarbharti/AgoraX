# Tasks Checklist - Universal Purchase & Expiry Rule

- [x] Remove duplicate silverCoins key logic in study_category_controller.dart and career_progression_controller.dart
- [/] Implement completedTaskIds tracking and loading in study_category_controller.dart
- [x] Implement `checkExpirations()`, `purchaseOrRenewCustomItem()`, and `getActiveReminders()` utilities in `CustomizationController`
- [x] Connect `checkExpirations()` inside customization screen initialization
- [x] Update `profile_customization_screen.dart` with renewal buttons, card states, and category warning banners
- [x] Refactor premium_name_widget.dart with dynamic cache resolvers
- [/] Refactor custom_avatar_frame.dart with dynamic frame resolutions and top warning banners
- [x] Update `novel_purchase_screen.dart` with purchase restrictions and top warning banners
- [ ] Verify clean compilation using `flutter analyze`
