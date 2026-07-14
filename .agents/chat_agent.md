# Creania - Chat Integration Guidelines (chat_agent.md)

This document defines the core architecture splits and guidelines for the private messaging subsystem in Creania.

---

## 1. Chat System Architecture

The chat system is split into two primary components: client-side offline storage (Isar) and the memory-only message relay (Socket.IO + Redis on Northflank):

```
├── Isar (Client Local Database)
│      ├── Chat History
│      ├── Pending Messages
│      ├── Media Metadata
│      └── Conversation Cache
│
└── Socket.IO Client (Real-time Transport)
       │
       ▼
   Northflank (Relay Node Server)
       │
       ├── Node.js
       ├── Express
       ├── Socket.IO
       └── Redis Queue
```

---

## 2. Component Specifications

### 📱 Isar (Local Database)
- **Chat History**: Permanent record of decrypted messages. Single source of truth.
- **Pending Messages**: Queue of outbound messages with `sending` status awaiting connection.
- **Media Metadata**: Pointers, URLs, and encryption keys for media attachments (files, voice notes).
- **Conversation Cache**: Pinned/muted metadata, badges, and unread counts.

### 🌐 Socket.IO Client
- Registers user connection and presence.
- Handles real-time event loops (`send_message`, `receive_message`).
- Triggers delivery and read receipts (`delivery_ack`, `read_ack`).
- Auto-reconnects and drains the pending queue.

### ☁️ Northflank
- **Node.js + Express + Socket.IO**: Low-latency event engine.
- **Redis Queue**: Temporary in-memory transit storage. Messages are deleted instantly upon receiving `delivery_ack`. The backend never logs or stores chat logs permanently.
- **E2EE Guarantee**: Relays only GCM-encrypted payloads. The server cannot read message content.
