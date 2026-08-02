# Creania Chat System Specification
Version: 2.0
Status: Production Architecture

==================================================

# GOAL

Build a private messaging system that behaves like WhatsApp while fitting inside the Creania ecosystem.

Priority

1. Reliability
2. Privacy
3. Security
4. Realtime
5. Performance

No fake implementations.
No mock data.
No shortcuts.

==================================================

# SYSTEM ARCHITECTURE

Flutter
↓
Socket.IO
↓
Northflank
↓
Redis (Temporary Relay)
↓
Receiver
↓
Isar Local Database

Supabase is NOT the message transport.
Supabase is used only for:
- Authentication
- Profiles
- Followers
- Notifications
- Storage
- App Metadata

Chat messages never permanently live inside Supabase.
Server is only a relay.
Messages are permanently stored only on users' devices using Isar.

==================================================

# MESSAGE FLOW

User A
↓
Creates Message
↓
Encrypts
↓
Stores locally (Isar)
↓
Status = Sending
↓
Socket.IO
↓
Northflank
↓
Redis
↓
Receiver
↓
Receiver stores in Isar
↓
Receiver sends Delivery ACK
↓
Redis deletes encrypted packet
↓
Sender receives Delivered
↓
Single Tick → Double Tick

When receiver opens chat:
↓
Read ACK
↓
Double Blue Tick

==================================================

# CHAT STATUS

- Sending: Small loading animation / clock
- Sent: Single Grey Tick
- Delivered: Double Grey Tick
- Seen: Double Blue Tick
- Failed: Red retry icon

Retry only on tap or automatic reconnect.
Never duplicate.

==================================================

# CHAT HEADER

Header must always display ONLY OTHER USER.
Never display current user.

Header contains:
- Avatar
- Username
- Verified Badge
- Level Badge
- VIP Badge
- Online
- Offline
- Last Seen
- Typing...
- Recording...
- Blocked
- Muted

==================================================

# ONLINE SYSTEM

Online means:
- Socket Connected
- Authenticated
- Heartbeat Alive

Offline means:
- Socket Disconnected
- Logout
- Network Lost
- App Closed
- Heartbeat Timeout

Never keep ghost users online.

==================================================

# LAST SEEN

Update automatically.

Examples:
- Online
- Last seen just now
- Last seen 2 min ago
- Last seen yesterday
- Last seen 10:15 PM

Never update your own last seen in your own header.

==================================================

# TYPING

Events:
- typing_start
- typing_stop

Rules:
- Typing visible ONLY to receiver.
- Never show your own typing.
- Auto stop after 3 seconds.
- Auto stop after send.
- Auto stop after leaving chat.
- Ignore duplicate typing events.

==================================================

# RECORDING

Voice recording indicator:
- Recording...
- Receiver only.
- Stop immediately after send.

==================================================

# MESSAGE TYPES

- Text
- Emoji
- GIF
- Sticker
- Image
- Video
- Audio
- Voice Note
- PDF
- Location
- Contact
- Poll
- Future Ready

==================================================

# MESSAGE FEATURES

- Reply
- Forward
- Copy
- Delete for Me
- Delete for Everyone
- Star Message
- Pin Message
- React
- Edit (future)
- Share
- Multi Select
- Search

==================================================

# MESSAGE STATES

- Sending
- Sent
- Delivered
- Seen
- Failed
- Deleted
- Forwarded
- Replied
- Edited
- Pinned
- Starred

==================================================

# CHAT UI

- Rounded bubbles
- Smooth animation
- Reply preview
- Forward label
- Timestamp
- Delivery ticks
- Seen ticks
- Unread separator
- Date separator
- Auto scroll
- Scroll to bottom button
- Jump to unread
- Lazy loading
- Virtual list

==================================================

# CONVERSATIONS

Each conversation is isolated.
Never mix messages.

Each chat has:
- conversationId
- otherUserId
- lastMessage
- lastTime
- unreadCount
- isMuted
- isPinned
- draft

==================================================

# GROUP CHAT

Each group has independent storage.
Separate unread count.
Separate notifications.
Separate typing.
Separate delivery.
Separate read status.
Never merge with private chats.

==================================================

# ROOM CHAT

Voice Room Chat:
- Independent database.
- Independent notification.
- Independent unread.
- Deleted automatically when room ends if configured.

==================================================

# COMMUNITY CHAT

Completely separate.
Own unread count.
Own notification.
Own storage.

==================================================

# NOTIFICATION SYSTEM

Every chat type has independent notifications:
- Private Chat
- Group Chat
- Community Chat
- Arena Chat
- Room Chat
- System Notification
- Friend Request
- Follow
- Gift
- Mention
- Reply
- Quote
- Level Up
- Achievement

Never combine these notifications.

==================================================

# NOTIFICATION BADGES

- Private Chat Badge: Only unread private chats.
- Group Badge: Only unread groups.
- Community Badge: Only unread community messages.
- Arena Badge: Only arena messages.
- Notification Center: System events only.

==================================================

# PUSH NOTIFICATIONS

Receive push only when app background or closed.
When app open:
- Do not duplicate notification.
- Open correct destination.
  - Private → Private Chat
  - Group → Group
  - Community → Community
  - Arena → Arena

==================================================

# SECURITY

- AES-256-GCM Encryption
- Unique IV
- Unique Key
- Replay attack prevention
- Timestamp validation
- Device validation
- JWT validation
- Session validation
- Never expose plaintext on server.

==================================================

# SOCKET EVENTS

- connect
- disconnect
- heartbeat
- send_message
- receive_message
- delivery_ack
- read_ack
- typing_start
- typing_stop
- recording_start
- recording_stop
- presence_update
- message_deleted
- message_reaction
- conversation_update

==================================================

# SOCKET RULES

- No duplicate listeners.
- No duplicate emits.
- Auto reconnect.
- Exponential backoff.
- Heartbeat every 15 seconds.
- Cleanup listeners.
- Dispose correctly.

==================================================

# ISAR

- Permanent message storage.
- Conversation cache.
- Unread cache.
- Media metadata.
- Pending queue.
- Failed queue.
- Never duplicate records.

==================================================

# REDIS

- Temporary relay only.
- Delete encrypted packet after delivery_ack.
- No permanent logs.
- No plaintext.

==================================================

# PERFORMANCE

- Realtime only.
- No polling.
- Lazy loading.
- Avatar cache.
- Image cache.
- Virtual scrolling.
- Message pagination.
- Minimum rebuilds.

==================================================

# TEST CHECKLIST

✓ Message send
✓ Message receive
✓ Retry
✓ Failed
✓ Delivered
✓ Seen
✓ Typing
✓ Recording
✓ Online
✓ Offline
✓ Last Seen
✓ Notification
✓ Deep Link
✓ Background Notification
✓ Foreground Notification
✓ Reconnect
✓ Internet Loss
✓ Pending Queue
✓ Duplicate Prevention
✓ Scroll Performance
✓ Search
✓ Media
✓ Reply
✓ Forward
✓ Delete
✓ React
✓ Group
✓ Community
✓ Arena
