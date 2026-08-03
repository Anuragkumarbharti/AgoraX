# Profile Tag & Showcase System (Technical Stages & Rules)

This document contains a comprehensive record of the **Backend-Driven Profile Tag & Showcase System** implemented in the Creaniaa/AgoraX application. It outlines the architectural phases, database schema, design specifications, and synchronization rules to guide future agent interactions.

---

## 🛠️ Stage 1: Database Schema & Migration
- **Migration File**: [202607090000_init_schema.sql](file:///c:/Users/MSI/Downloads/AgoraX/supabase/migrations/202607090000_init_schema.sql)
- **JSONB Column**: Added `tag_system` to the `profiles` table.
- **Security Check Trigger**: Attached trigger function `check_profile_tag_system_update()` to prevent client-side modifications from authenticated or anonymous roles.
- **Automated Rebuild Trigger**:
  - Implemented `rebuild_user_tag_system(p_user_id uuid)` to automatically evaluate, priority-sort, and store the tag structure.
  - Triggers listen for updates on `profiles` (for levels, VIP/Novel tier changes) and `community_members` (for joining/leaving community).

---

## 🏷️ Stage 2: Three Core Tag Categories & Priorities

### 1. Identity Tag Bar (5 Fixed Display Positions)
Positioned next to the username, evaluated in this exact priority sequence:
- **Position 1 - ID Level Tag**: Fixed, displays account level (e.g. `Lv.26`).
- **Position 2 - Community Tag**: Appears only if the user is a community member.
- **Position 3 - VIP Tag**: Shows VIP tier.
- **Position 4 - Noble Tag**: Shows active workspace premium status.
- **Position 5 - Special Identity Tag**: Priority-prioritized tag (e.g. `Origin`, `Studio`, `Creator`).

### 2. Official Status Tags
An independent horizontal row containing Verified and Role tags displayed side-by-side:
- **Verified Priorities**: `Celebrity` > `Partner` > `Official` > `Verified` > `verified tester`.
- **Role Priorities**: `Developer` > `Administrator` > `Official Staff` > `Moderator` > `Host`.

### 3. Profile Showcase (Equipped Badges)
- Max 5 slots editable by the user via drag-and-drop customization.
- **Display Limit**: Maximum of **6 badges** are visible. If the user has more, the first 5 are shown and the 6th slot displays a `+N` badge representing the remaining badges.

---

## 🎨 Stage 3: High-Fidelity UI Styling & Compact Tokens
Designed to match modern social live streaming profile standards. Dimension properties are fixed and do not scale up on high-resolution screens:

| Component | Size / Dimension | Additional Styling |
| :--- | :--- | :--- |
| **Avatar Frame** | `112 × 112` px | Fitted precisely around the avatar |
| **Avatar Image** | `96 × 96` px (radius `48`) | Centered inside the frame with equal padding |
| **Username** | `18` px | SemiBold (`w600`), primary focus |
| **User ID** | `13` px | Medium (`w500`), copyable Pill shape |
| **Identity Tags** | Height `19` px, Padding `8` px | Font `10` px, Border radius `999` px (fully rounded) |
| **Official Status Tag**| Height `19` px, Padding `8` px | Font `10` px, same height as identity tags |
| **Showcase Badges** | `36 × 36` px | `6` px spacing between badges |
| **Vertical Gaps** | `6` px | Compact, consistent spacing between all items |

### Visual Layout Order (Centered):
1. **Avatar / Avatar Frame** (Centered)
2. **Username** (SemiBold, centered)
3. **User ID Pill** (Medium, centered)
4. **Identity Tags** (Wrap-centered, max-width `320` px)
5. **Official Status Tags** (verified & role side-by-side, centered)
6. **Showcase Badges** (centered row)

---

## 🔄 Stage 4: Frontend State & Sync Logic
- **Models**: [user_model.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/models/user_model.dart)
  - Mapped `TagSystem`, `IdentityTag`, and `OfficialStatus` models to standard JSON schema.
- **Client Cache Manager**: [user_profile_cache_manager.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/services/user_profile_cache_manager.dart)
  - Replaced legacy lists with `rebuildAndSyncCurrentUserTagSystem` to dynamically construct and cache structures for instant client-side updates.
- **Controllers**: Synced within [vip_controller.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/services/vip_controller.dart), [novel_controller.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/services/novel_controller.dart), and [community_controller.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/services/community_controller.dart).

---

## 🧪 Stage 5: Verification & Unit Tests
- **Test File**: [test/tags_roles_badges_test.dart](file:///c:/Users/MSI/Downloads/AgoraX/test/tags_roles_badges_test.dart)
- Validates model parsing, tag system structure, fallback mapping, and official priority hierarchy.
- Command to run: `flutter test test/tags_roles_badges_test.dart` (Passed 100%).
