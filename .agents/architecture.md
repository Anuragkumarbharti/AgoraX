# Creania - Production Implementation Roadmap & System Architecture (architecture.md)

This document contains the detailed system architecture layout, database constraints, and the complete 21-phase roadmap for building and deploying the Creania application.

---

## 1. System Architecture

```
Flutter App
│
├── UI (GetX State Views)
├── Isar (Client Local Database)
├── Socket.IO Client (Real-time Relay)
├── Encryption (X25519 + AES-GCM-256)
└── Background Sync (Queue Drainage Engine)
│
├──────────────┐
│              │
▼              ▼
Supabase     Northflank (Backend VM Container Node)
(Auth ONLY)  │
             ├── Node.js (Express REST API)
             ├── Socket.IO (Real-time Relay Gateway)
             ├── PostgreSQL (App Data Store)
             ├── Redis (Transit Encrypted Delivery Queue)
             ├── BullMQ (Job/Worker Management)
             ├── MinIO (Self-hosted Encrypted Object Storage)
             ├── PM2 (Node Process Monitoring)
             └── Nginx (Reverse Proxy & SSL)
                    │
                    ▼
              Firebase Cloud Messaging (FCM Notifications)
                    │
                    ▼
               ZEGOCLOUD (Audio Seating & Speaking Streams ONLY)
```

---

## 2. Strict Service Responsibilities

To maintain clean separation of concerns:
- **Flutter**: Owns local state, UI layout, E2E crypto keys, Isar cache, and audio stream rendering.
- **Supabase**: Restricted **strictly** to Auth verification, user authentication, OTP/refresh tokens. **NEVER** holds chat content.
- **Northflank**: Hosts the Node.js Express endpoints, Socket.IO gateways, and PostgreSQL databases.
- **Redis**: Purely a transit memory buffer for unreceived E2EE payloads (purged immediately on `delivery_ack`).
- **ZEGOCLOUD**: Restricted **strictly** to live voice stream transport, seat handshakes, and speak effects.

---

## 3. Production Roadmap (Phases 0 - 21)

### Phase 0: Architecture Documentation
- Complete System Architecture diagrams.
- Database ER schemas (Postgres / Isar).
- Socket.IO Event registries.
- Message sequence flows and E2EE key handshakes.

### Phase 1: Project Foundation
- Setup Flutter folder packages.
- Express API framework.
- Dependency injection bindings.
- Repository patterns and error wrappers.

### Phase 2: Flutter UI (Mock Data)
- Layout all screens: Onboarding, Chats list, Arena voice rooms, Private chat bubble streams, Profile settings, Wallet, and Store views.

### Phase 3: Isar Local Database
- Create collections: `Users`, `Conversations`, `Messages`, `Pending Messages`, `Media`, `Read Status`, `Delivery Status`.
- Enable fast offline reads.

### Phase 4: Supabase Integration
- Hook up JWT, OTP login, profile metadata, followers lists, and settings. No chats.

### Phase 5: Node.js Backend API
- Setup REST routing, verification middlewares, and admin dashboard queries.

### Phase 6: PostgreSQL Database Schema
- Create profiles, wallets, transactions, rooms, followers, and settings tables. No message tables.

### Phase 7: Redis Transit Buffer
- Implement temporary Redis queues for offline socket messages.

### Phase 8: BullMQ Job Workers
- Setup retry queues, cleanups, and notification dispatches.

### Phase 9: MinIO Object Storage
- Setup buckets for encrypted media attachments (photos, wallpapers, stickers, voice notes).

### Phase 10: Socket.IO Gateway
- Connect client sockets, listen for message dispatches, ACKs, presence updates, and room joining.

### Phase 11: End-to-End Encryption
- Integrate X25519, HKDF key derivation, and AES-256-GCM.

### Phase 12: Chat Message Flow
- Message written to Isar -> encrypted -> Socket relay -> Redis queue -> delivered -> decrypted on recipient device -> delivery ACK -> Redis entry deleted.

### Phase 13: Offline & Reconnect Engine
- Local offline queue drainage, automatic socket reconnect handshakes, and background sync.

### Phase 14: Encrypted Media Sharing
- Encrypt binary -> upload to MinIO -> Socket relays signed metadata -> recipient downloads -> decrypts locally.

### Phase 15: Push Notifications
- Connect FCM background listeners to awake socket receiver tasks.

### Phase 16: ZEGOCLOUD Integration
- Voice streaming seats, speak detection, noise filters in Arena rooms.

### Phase 17: Background Service Loops
- Token refreshes, queue check loops, and background delivery updates.

### Phase 18: Performance Optimization
- Pagination, lazy loading, payload compression, and connection pooling.

### Phase 19: Security Hardening
- PM2 process control, SSL pin checks, SQL Injection guards, and rate limiters.

### Phase 20: Northflank Production Deployment
- Deploy Node.js, Redis, BullMQ, MinIO, Nginx proxy, and PostgreSQL on Northflank containers.

### Phase 21: Verification & Testing
- Test E2EE messaging, reconnect stability, offline sync checks, and voice room audio seat performance.
