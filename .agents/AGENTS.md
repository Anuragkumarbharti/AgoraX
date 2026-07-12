# Creania - Study Vault System (Technical Logs & Rules)

This document contains a comprehensive record of the **Study Vault (Library)** system designed and implemented for the Creania codebase, explaining "kya kaise hua hai" (what has been built and how) to guide future agent interactions.

---

## 1. Architectural Overview & File Structures

We implemented a digital marketplace (Kindle + Play Books + Gumroad clone) inside the Creania application. Below are the key files created and modified:

### 🌟 Models (`lib/models/`)
* **[study_vault_model.dart](file:///c:/Users/MSI/Downloads/Creania/lib/models/study_vault_model.dart)**: Defines core structures:
  * `StudyVaultItem`: Represents books, cheat sheets, capstone projects, lab manuals, and assignments.
  * `StudyReview`: Handles verified student ratings & reviews.
  * `VaultWallet` & `VaultTransaction`: Tracks creator balance & earnings breakdowns.
  * `ReadingHistory`: Stores reading state, page markers, bookmarks, notes, and highlights.

### ⚙️ Services & Controllers (`lib/services/`)
* **[study_vault_controller.dart](file:///c:/Users/MSI/Downloads/Creania/lib/services/study_vault_controller.dart)**: Centralized state management using GetX. Houses catalog lists, local SharedPreferences caching, AI simulation engines, and purchase flow processors.

### 🖥️ Screen Views (`lib/screens/study_vault/`)
* **[study_vault_home_screen.dart](file:///c:/Users/MSI/Downloads/Creania/lib/screens/study_vault/study_vault_home_screen.dart)**: Visual bookshelf layouts, continue reading progress tracking, categories, search, and featured carousels.
* **[book_details_screen.dart](file:///c:/Users/MSI/Downloads/Creania/lib/screens/study_vault/book_details_screen.dart)**: Catalog detail display, verified student review decks, and interactive price breakdown sheet.
* **[study_vault_reader_screen.dart](file:///c:/Users/MSI/Downloads/Creania/lib/screens/study_vault/study_vault_reader_screen.dart)**: Simulated academic reading view with diagonal watermark overlays, light/dark theme options, text highlighting, and AI widgets.
* **[my_library_screen.dart](file:///c:/Users/MSI/Downloads/Creania/lib/screens/study_vault/my_library_screen.dart)**: Tabbed shelf displaying Purchased items, VIP collections, Wishlists, Reading History, and Downloaded books.
* **[seller_dashboard_screen.dart](file:///c:/Users/MSI/Downloads/Creania/lib/screens/study_vault/seller_dashboard_screen.dart)**: Earnings analysis charts, withdrawal settlement requests, upload trackers, and logs.
* **[upload_book_screen.dart](file:///c:/Users/MSI/Downloads/Creania/lib/screens/study_vault/upload_book_screen.dart)**: Forms for uploading educational content with real-time price calculators.
* **[admin_vault_panel_screen.dart](file:///c:/Users/MSI/Downloads/Creania/lib/screens/study_vault/admin_vault_panel_screen.dart)**: Review approvals, upload official content, settle UPI payouts, and review copyright piracy complaints.

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
  * Creania official board materials are unlocked automatically for users whose VIP Membership Level matches or exceeds the book's `requiredVipLevel`.
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
* **Diagonal Watermark:** The reader viewport overlays a repeating semi-transparent diagonal string containing user identification data: `Creania • [UserName] • [UserID] • [UserIP]`.
* **Screenshot & Copy Protection:** Clipboard copy actions are blocked inside the reader, and screenshot captures trigger custom warning warnings to deter piracy.
* **Offline Download Cache:** PDFs are stored in localized encrypted SharedPreferences. The admin settings define a global limit (e.g. max 3 devices) that a user can authorize for local offline access.

---

## 3. Integration & Entry Points

We linked the Study Vault into the core shell widgets of Creania:
1. **HomeScreen ([home_screen.dart](file:///c:/Users/MSI/Downloads/Creania/lib/screens/home/home_screen.dart))**: Added a horizontal slider section named "Trending in Study Vault" above the community listings.
2. **ExploreScreen ([explore_screen.dart](file:///c:/Users/MSI/Downloads/Creania/lib/screens/explore/explore_screen.dart))**:
   * Added a promotional Study Vault exploration card at the top.
   * Added a dedicated "Study Vault" tab with grid-search capabilities.
3. **ProfileScreen ([profile_screen.dart](file:///c:/Users/MSI/Downloads/Creania/lib/screens/profile/profile_screen.dart))**: Inserted a "STUDY VAULT DECK" containing options for Study Vault, My Library, Seller Dashboard, and Admin Panel.

---

## 4. Verification

* Tests were implemented in **[study_vault_test.dart](file:///c:/Users/MSI/Downloads/Creania/test/study_vault_test.dart)**.
* Unit tests successfully verify:
  * Baseline pricing breakdowns & VIP discounts.
  * Unlock logic mapping for official VIP levels and user-uploaded purchases.
  * Membership daily limit bounds (VIP 1 = 1, VIP 5 = 5) and block triggers.
  * Creator read-visit payout calculations (₹5.00 credit).
* Run command used to verify: `flutter test test/study_vault_test.dart` (Passed 100%).

---

## 5. Cross-Platform Architectural & Backend-First Rules

To support future platform expansions (Mobile App, Official Web Platform, Admin Panels, Employee/Moderator/Support/Verification Portals/Dashboards), follow these permanent rules for any feature development:

### 📱💻 Multi-Platform Target
* **Unified Backend:** Every feature, database table, API, authentication flow, permission system, storage structure, and service must support both the Mobile App and the Official Website from day one. Do not build mobile-only architectures or local-only business logic.
* **Dashboards & Portals Support:** Ensure backend services and APIs are ready to serve:
  * Official Website & User Dashboard
  * Creator & Author Dashboards
  * Employee, Moderator, Admin, & Super Admin Dashboards
  * Verification & Customer Support Portals

### 🏗️ Backend-First Sequence
1. **Design Backend & DB First:** Design backend services first.
2. **Schema & Security:** Build database tables, Row-Level Security (RLS) policies, and permissions.
3. **Clean APIs:** Expose functional REST/RPC APIs (e.g. Supabase Edge Functions / Postgres Functions) that encapsulate all business logic. Do not write frontend-specific business logic.
4. **Frontend Integration:** Connect the Mobile App and Web App to the unified APIs.

### ⚙️ Production Stack & Standards
* **Technology Stack:** Built on Supabase, PostgreSQL (RLS), Edge Functions, Supabase Storage, Supabase Realtime, LiveKit, FCM, and Razorpay.
* **No Fakes/Mocks:** Never use fake data, mock services, hardcoded values, or temporary demo logic. Everything must be production-ready and scale to 1M+ users securely.
* **Pre-Implementation Verification:** Ask the following 7 questions before writing any code:
  1. Will this work on both the mobile app and website?
  2. Will this work for Admin, Employees and Users?
  3. Will this scale to 1M+ users?
  4. Will this require database changes later?
  5. Is this secure?
  6. Is this reusable?
  7. Is there a better long-term architecture?
  If any answer is NO, redesign it before writing code.

---

## 6. Production Backend Architecture & Database Schema (v2.0)

This section outlines the Postgres schema structures, security, cryptography, and real-time messaging subsystems defined in the backend migration plan.

### 📊 A. PostgreSQL Database Schema
All data schemas are managed in Supabase migration scripts (e.g. `supabase/migrations/202607090000_init_schema.sql`). Key tables include:

* **Profiles Table (`profiles`)**: Stores core student identity, gamification levels, and VIP/Novel membership tier expirations.
* **Audit-Ready Ledger Systems**:
  * `wallets`: Stores Creator and User balances.
  * `wallet_transactions`: Ledger log tracking transaction categories (`Deposit`, `Withdrawal`, `Payout`, `Refund`, `Reward`, `Commission`).
  * `purchase_history`: Track book / resource sales.
  * `gift_history`: Track direct virtual gifting logs.
  * `withdraw_history`: Track creator payout request statuses.
* **Encrypted Messages Table (`messages`)**: E2EE chat storage. Fields: `id`, `sender_id`, `receiver_id`, `room_id`, `encrypted_content`, `nonce`, `is_private`, `message_status` (sent/delivered/seen), deletion trackers (per-user/everyone arrays), reaction logs, and media attachments.
* **Voice Rooms Tables**:
  * `rooms`: Metadata, co-hosts, rules.
  * `room_members` & `room_moderators`: Permission matrices.
  * `room_messages`: Live room text chat logs.
  * `room_gifts` & `room_events`: Live virtual gifting/seat change events.
* **Moderation & Security**: `admins`, `reports`, `bans`, `audit_logs`, and `moderation_logs`.
* **Storage Buckets**: `avatars/` (Public), `study-covers/` (Public), and `study-files/` (Private PDFs served via signed URLs).

### 🔑 B. End-to-End Encryption (E2EE) Specifications
To secure private messaging between clients, the system enforces client-side E2EE:
1. **Key Exchange**: X25519 Diffie-Hellman protocol.
2. **KDF**: HKDF-SHA256 generates a 256-bit symmetric key from the shared secret.
3. **Symmetric Encryption**: AES-256-GCM. The client encrypts payloads and stores the encrypted message, IV/nonce, and auth tag in the DB. Only participants hold the keys to decrypt.

### 📱 C. LiveKit Voice & Video SFU
For scaling audio rooms up to 1M+ users:
* Open-source LiveKit SFU instances are deployed.
* Tokens are generated securely via Supabase Edge Functions.
* The Flutter app joins using the LiveKit WebRTC SDK, co-existing with ZEGOCLOUD or replacing it.

### 🏗️ D. Migration Sequence
1. **Database Schema:** Set up PostgreSQL tables, functions, and RLS policies on the local Supabase instance.
2. **Dependencies:** Add `supabase_flutter` and `encrypt` packages.
3. **Auth:** Hook up login/signup screens to Supabase Auth.
4. **Chat Controller Refactoring:** Introduce E2EE key exchanges and swap local mock streams with Supabase Realtime Channels.
5. **Ledger Bindings:** Bind purchase, gift, and withdraw actions to database transactions.
6. **LiveKit Integration:** Hook up LiveKit WebRTC client.
