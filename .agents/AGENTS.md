# AgoraX - Study Vault System (Technical Logs & Rules)

This document contains a comprehensive record of the **Study Vault (Library)** system designed and implemented for the AgoraX codebase, explaining "kya kaise hua hai" (what has been built and how) to guide future agent interactions.

---

## 1. Architectural Overview & File Structures

We implemented a digital marketplace (Kindle + Play Books + Gumroad clone) inside the AgoraX application. Below are the key files created and modified:

### 🌟 Models (`lib/models/`)
* **[study_vault_model.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/models/study_vault_model.dart)**: Defines core structures:
  * `StudyVaultItem`: Represents books, cheat sheets, capstone projects, lab manuals, and assignments.
  * `StudyReview`: Handles verified student ratings & reviews.
  * `VaultWallet` & `VaultTransaction`: Tracks creator balance & earnings breakdowns.
  * `ReadingHistory`: Stores reading state, page markers, bookmarks, notes, and highlights.

### ⚙️ Services & Controllers (`lib/services/`)
* **[study_vault_controller.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/services/study_vault_controller.dart)**: Centralized state management using GetX. Houses catalog lists, local SharedPreferences caching, AI simulation engines, and purchase flow processors.

### 🖥️ Screen Views (`lib/screens/study_vault/`)
* **[study_vault_home_screen.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/screens/study_vault/study_vault_home_screen.dart)**: Visual bookshelf layouts, continue reading progress tracking, categories, search, and featured carousels.
* **[book_details_screen.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/screens/study_vault/book_details_screen.dart)**: Catalog detail display, verified student review decks, and interactive price breakdown sheet.
* **[study_vault_reader_screen.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/screens/study_vault/study_vault_reader_screen.dart)**: Simulated academic reading view with diagonal watermark overlays, light/dark theme options, text highlighting, and AI widgets.
* **[my_library_screen.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/screens/study_vault/my_library_screen.dart)**: Tabbed shelf displaying Purchased items, VIP collections, Wishlists, Reading History, and Downloaded books.
* **[seller_dashboard_screen.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/screens/study_vault/seller_dashboard_screen.dart)**: Earnings analysis charts, withdrawal settlement requests, upload trackers, and logs.
* **[upload_book_screen.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/screens/study_vault/upload_book_screen.dart)**: Forms for uploading educational content with real-time price calculators.
* **[admin_vault_panel_screen.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/screens/study_vault/admin_vault_panel_screen.dart)**: Review approvals, upload official content, settle UPI payouts, and review copyright piracy complaints.

---

## 2. Business Logic & Calculations (Kaise Hua Hai)

### 📊 A. Pricing & Revenue splits (INR & Gold Coins)
All buyer prices and seller net payouts are determined via a base listing price `P` set by the seller:
* **Taxes & Platforms Fees applied:**
  * **GST (Goods & Services Tax):** 18% of base price
  * **Payment Gateway (PG) Processing Fee:** 2% of base price
  * **Platform Service Fee:** 17% of base price
* **Formulae:**
  * `Buyer Pays = Base Price * 1.37` (Base + 18% GST + 2% PG + 17% Platform)
  * `Seller Net Payout = Base Price * 0.63` (Base - 18% GST - 2% PG - 17% Platform)
  * `Platform Gross Revenue = Base Price * 0.74` (Total Buyer Pays - Seller Net Payout)
* **Gold Coin Conversion:**
  * Gold coins price is calculated as: `(Buyer Pays INR * 0.49).round()`.

### 👑 B. VIP Membership Discounts & Lock Rules
* **Official Content:**
  * AgoraX official board materials are unlocked automatically for users whose VIP Membership Level matches or exceeds the book's `requiredVipLevel`.
  * If membership is inactive or level is low, access remains locked.
* **User-Uploaded Content:**
  * VIP users receive percentage discounts on paid user uploads before applying taxes:
    * **VIP 1:** 5% discount
    * **VIP 2:** 10% discount
    * **VIP 3:** 15% discount
    * **VIP 4:** 20% discount
    * **VIP 5:** 25% discount

### 📖 C. VIP & Novel Membership Reading Access (Daily Limits & Payouts)
* **Daily Unique Book Limits:** Users reading books under VIP or Novel membership access are capped daily:
  * **Starting Level (VIP 1 / Novel 1):** Only **1 unique book per day**.
  * **Max Level (VIP 5 / Novel 5+):** Max **5 unique books per day**.
  * Capped formula: `Limit = max(vipLevel, novelLevel).clamp(1, 5)`.
* **No Offline Downloads:** Downloading is strictly disabled for books accessed via VIP/Novel membership. Only purchased books or free uploads can be downloaded.
* **₹5.00 Seller Visit Payout:** When a member reads/visits a book via membership (and it's a new book visited today), the uploader/seller receives ₹5.00 added directly to their wallet withdrawable balance.

### 🛡️ D. Anti-Piracy DRM Security
* **Diagonal Watermark:** The reader viewport overlays a repeating semi-transparent diagonal string containing user identification data: `AgoraX • [UserName] • [UserID] • [UserIP]`.
* **Screenshot & Copy Protection:** Clipboard copy actions are blocked inside the reader, and screenshot captures trigger custom warning warnings to deter piracy.
* **Offline Download Cache:** PDFs are stored in localized encrypted SharedPreferences. The admin settings define a global limit (e.g. max 3 devices) that a user can authorize for local offline access.

---

## 3. Integration & Entry Points

We linked the Study Vault into the core shell widgets of AgoraX:
1. **HomeScreen ([home_screen.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/screens/home/home_screen.dart))**: Added a horizontal slider section named "Trending in Study Vault" above the community listings.
2. **ExploreScreen ([explore_screen.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/screens/explore/explore_screen.dart))**:
   * Added a promotional Study Vault exploration card at the top.
   * Added a dedicated "Study Vault" tab with grid-search capabilities.
3. **ProfileScreen ([profile_screen.dart](file:///c:/Users/MSI/Downloads/AgoraX/lib/screens/profile/profile_screen.dart))**: Inserted a "STUDY VAULT DECK" containing options for Study Vault, My Library, Seller Dashboard, and Admin Panel.

---

## 4. Verification

* Tests were implemented in **[study_vault_test.dart](file:///c:/Users/MSI/Downloads/AgoraX/test/study_vault_test.dart)**.
* Unit tests successfully verify:
  * Baseline pricing breakdowns & VIP discounts.
  * Unlock logic mapping for official VIP levels and user-uploaded purchases.
  * Membership daily limit bounds (VIP 1 = 1, VIP 5 = 5) and block triggers.
  * Creator read-visit payout calculations (₹5.00 credit).
* Run command used to verify: `flutter test test/study_vault_test.dart` (Passed 100%).
