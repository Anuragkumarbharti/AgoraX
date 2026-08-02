require('dotenv').config();
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const redis = require('redis');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const { createClient } = require('@supabase/supabase-js');

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://zccrgiplrbeslgpcezul.supabase.co';
// ✅ FIX: Always prefer SERVICE ROLE KEY. Anon key fails RLS for backend writes.
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY || '';
const JWT_SECRET = process.env.SUPABASE_JWT_SECRET || 'super-secret-jwt-key';

if (!SUPABASE_KEY || SUPABASE_KEY.length < 100) {
  console.warn('⚠️  [AUTH] SUPABASE_SERVICE_ROLE_KEY not set or appears to be anon key. Backend DB writes may fail RLS. Set SUPABASE_SERVICE_ROLE_KEY in Northflank env vars.');
}

// Initialize Supabase Client with service role key
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  },
  // ✅ FIX: Increase ping interval/timeout to prevent false disconnects behind Northflank proxy
  pingInterval: 15000,   // Every 15s
  pingTimeout: 10000,    // Wait 10s for pong before closing
  connectTimeout: 10000,
});

// ─────────────────────────────────────────────
// Redis Client
// ─────────────────────────────────────────────

let isRedisConnected = false;
const redisClient = redis.createClient({ url: REDIS_URL });

redisClient.on('error', (err) => {
  console.error('❌ [Redis] Client Error:', err.message);
  isRedisConnected = false;
});

redisClient.on('reconnecting', () => {
  console.warn('🔄 [Redis] Reconnecting...');
});

redisClient.on('ready', () => {
  console.log('✅ [Redis] Connected and ready.');
  isRedisConnected = true;
});

redisClient.connect()
  .then(() => {
    isRedisConnected = true;
    syncFromSupabase();
  })
  .catch((err) => {
    console.warn('⚠️  [Redis] Connection failed. Falling back to In-Memory store. Error:', err.message);
    isRedisConnected = false;
  });

// ─────────────────────────────────────────────
// In-Memory Fallback Stores
// ─────────────────────────────────────────────

const activeUsers = new Map();          // userId → socketId (in-memory mirror)
const socketSessions = new Map();       // sessionId → socketId
const presenceRegistry = new Map();     // userId → presenceObj
const reconnectWindowTimers = new Map(); // userId → { timeout, roomId }
const offlineQueues = new Map();        // receiverId → { messageId: payloadStr }
const rateLimitMap = new Map();         // key → timestamps[]

// ─────────────────────────────────────────────
// Redis + Memory Abstraction Helpers
// ─────────────────────────────────────────────

// ✅ BUG #4 FIX: Persist activeUsers to Redis so restarts don't lose socket mapping
async function setActiveUser(userId, socketId) {
  activeUsers.set(userId, socketId);
  if (isRedisConnected) {
    try {
      await redisClient.setEx(`active:user:${userId}`, 3600, socketId); // 1hr TTL
    } catch (e) {
      console.warn(`⚠️  [Redis] setActiveUser failed for ${userId}:`, e.message);
    }
  }
}

async function getActiveUserSocket(userId) {
  // Check memory first (fastest)
  const memSocket = activeUsers.get(userId);
  if (memSocket) return memSocket;
  // Fallback to Redis (for cross-process / post-restart)
  if (isRedisConnected) {
    try {
      return await redisClient.get(`active:user:${userId}`);
    } catch (e) {
      console.warn(`⚠️  [Redis] getActiveUserSocket failed for ${userId}:`, e.message);
    }
  }
  return null;
}

async function deleteActiveUser(userId) {
  activeUsers.delete(userId);
  if (isRedisConnected) {
    try {
      await redisClient.del(`active:user:${userId}`);
    } catch (e) {
      console.warn(`⚠️  [Redis] deleteActiveUser failed for ${userId}:`, e.message);
    }
  }
}

// ─────────────────────────────────────────────
// Offline Message Queue Helpers
// ─────────────────────────────────────────────

async function hSetQueue(receiverId, messageId, payload) {
  if (isRedisConnected) {
    try {
      await redisClient.hSet(`chat:queue:${receiverId}`, messageId, JSON.stringify(payload));
      // Set TTL of 14 days on the queue hash
      await redisClient.expire(`chat:queue:${receiverId}`, 14 * 24 * 3600);
      return;
    } catch (e) {
      console.warn(`⚠️  [Redis] hSetQueue failed for ${receiverId}/${messageId}:`, e.message);
    }
  }
  if (!offlineQueues.has(receiverId)) offlineQueues.set(receiverId, {});
  offlineQueues.get(receiverId)[messageId] = JSON.stringify(payload);
}

async function hDelQueue(receiverId, messageId) {
  if (isRedisConnected) {
    try {
      await redisClient.hDel(`chat:queue:${receiverId}`, messageId);
      return;
    } catch (e) {
      console.warn(`⚠️  [Redis] hDelQueue failed for ${receiverId}/${messageId}:`, e.message);
    }
  }
  if (offlineQueues.has(receiverId)) {
    delete offlineQueues.get(receiverId)[messageId];
  }
}

async function hGetAllQueue(receiverId) {
  if (isRedisConnected) {
    try {
      const data = await redisClient.hGetAll(`chat:queue:${receiverId}`);
      if (data && Object.keys(data).length > 0) return data;
    } catch (e) {
      console.warn(`⚠️  [Redis] hGetAllQueue failed for ${receiverId}:`, e.message);
    }
  }
  return offlineQueues.get(receiverId) || {};
}

// ─────────────────────────────────────────────
// ✅ BUG #3 FIX: Redis-backed Deduplication (TTL: 5 minutes)
// ─────────────────────────────────────────────

async function isDuplicateMessage(messageId) {
  const key = `msg:dedup:${messageId}`;
  if (isRedisConnected) {
    try {
      const result = await redisClient.setNX(key, '1');
      if (result) {
        await redisClient.expire(key, 300); // 5 minutes TTL
        return false; // First time — not a duplicate
      }
      return true; // Already exists — duplicate
    } catch (e) {
      console.warn(`⚠️  [Redis] dedup check failed for ${messageId}:`, e.message);
    }
  }
  // Fallback: in-memory with manual TTL
  if (inMemoryDedup.has(messageId)) return true;
  inMemoryDedup.add(messageId);
  setTimeout(() => inMemoryDedup.delete(messageId), 300000);
  return false;
}

const inMemoryDedup = new Set();

// ─────────────────────────────────────────────
// Presence Helpers
// ─────────────────────────────────────────────

async function setPresence(userId, status, roomId = null, extra = {}) {
  const presenceObj = {
    userId,
    status,
    roomId,
    lastSeen: new Date().toISOString(),
    ...extra
  };

  presenceRegistry.set(userId, presenceObj);

  if (isRedisConnected) {
    try {
      await redisClient.setEx(`presence:user:${userId}`, 3600, JSON.stringify(presenceObj));
    } catch (e) {
      console.warn(`⚠️  [Redis] setPresence failed for ${userId}:`, e.message);
    }
  }

  // Sync to database
  try {
    await supabase
      .from('profiles')
      .update({
        presence_state: status === 'offline' ? 'Offline' : (roomId ? 'In Room' : 'Online'),
        last_seen_at: new Date().toISOString()
      })
      .eq('id', userId);
  } catch (e) {
    console.error(`❌ [DB] Failed to sync presence for ${userId}:`, e.message);
  }

  // Broadcast presence update to all connected clients
  io.emit('presence_update', {
    userId,
    status,
    roomId,
    lastSeen: presenceObj.lastSeen
  });
}

async function getPresence(userId) {
  if (isRedisConnected) {
    try {
      const data = await redisClient.get(`presence:user:${userId}`);
      if (data) return JSON.parse(data);
    } catch (e) {
      console.warn(`⚠️  [Redis] getPresence failed for ${userId}:`, e.message);
    }
  }
  return presenceRegistry.get(userId);
}

// ─────────────────────────────────────────────
// Startup Cache Sync
// ─────────────────────────────────────────────

async function syncFromSupabase() {
  try {
    console.log('🔄 [Startup] Syncing active DB sessions and presence to Redis...');
    const { data: profiles, error } = await supabase
      .from('profiles')
      .select('id, active_room_id, presence_state');

    if (error) throw error;

    for (const profile of profiles) {
      if (profile.presence_state && profile.presence_state !== 'Offline') {
        await setPresence(profile.id, profile.presence_state.toLowerCase(), profile.active_room_id);
      }
    }
    console.log(`✅ [Startup] Synced ${profiles.length} profiles to Redis.`);
  } catch (e) {
    console.error('❌ [Startup] Supabase sync error:', e.message);
  }
}

// ─────────────────────────────────────────────
// Rate Limiting
// ─────────────────────────────────────────────

function isRateLimited(key, maxRequests, windowMs) {
  const now = Date.now();
  if (!rateLimitMap.has(key)) rateLimitMap.set(key, []);
  const timestamps = rateLimitMap.get(key).filter(t => now - t < windowMs);
  if (timestamps.length >= maxRequests) return true;
  timestamps.push(now);
  rateLimitMap.set(key, timestamps);
  return false;
}

// ─────────────────────────────────────────────
// Socket.IO Auth Middleware
// ─────────────────────────────────────────────

io.use(async (socket, next) => {
  try {
    const { userId, sessionId, deviceId, token } = socket.handshake.query;

    if (!userId || !sessionId || !deviceId) {
      return next(new Error('Authentication failed: Missing userId, sessionId, or deviceId'));
    }

    // JWT Validation via Supabase
    if (token) {
      try {
        const { data: { user }, error } = await supabase.auth.getUser(token);
        if (error || !user || user.id !== userId) {
          console.warn(`⚠️  [Auth] JWT mismatch for userId ${userId}: ${error?.message}`);
          return next(new Error('Authentication failed: Invalid JWT token'));
        }
      } catch (jwtErr) {
        return next(new Error('Authentication failed: JWT verification error'));
      }
    }

    // Global Ban Check
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('is_banned')
      .eq('id', userId)
      .maybeSingle();

    if (profileError || (profile && profile.is_banned)) {
      return next(new Error('Authentication failed: User account is banned'));
    }

    socket.userId = userId;
    socket.sessionId = sessionId;
    socket.deviceId = deviceId;
    console.log(`🔐 [Auth] Authenticated: userId=${userId} device=${deviceId}`);
    return next();
  } catch (err) {
    return next(new Error('Authentication failed: ' + err.message));
  }
});

// ─────────────────────────────────────────────
// Connection Handler
// ─────────────────────────────────────────────

io.on('connection', async (socket) => {
  const userId = socket.userId;
  const sessionId = socket.sessionId;
  const deviceId = socket.deviceId;

  console.log(`🔌 [Socket Connected] userId=${userId} session=${sessionId} device=${deviceId} socketId=${socket.id}`);

  // ── Reconnect grace window recovery ──
  const pendingRecovery = reconnectWindowTimers.get(userId);
  if (pendingRecovery) {
    console.log(`🔄 [Reconnect] User ${userId} reconnected within grace window. Restoring state.`);
    clearTimeout(pendingRecovery.timeout);
    reconnectWindowTimers.delete(userId);
  }

  // ── Disconnect duplicate sockets for same user ──
  const oldUserSocketId = await getActiveUserSocket(userId);
  if (oldUserSocketId && oldUserSocketId !== socket.id) {
    const oldSocket = io.sockets.sockets.get(oldUserSocketId);
    if (oldSocket) {
      // Only force-logout if it's a DIFFERENT session (not same user reconnecting)
      if (oldSocket.sessionId !== sessionId) {
        console.log(`⚠️  [Duplicate Session] Force logging out old session for user ${userId}`);
        oldSocket.emit('force_logout', { message: 'Logged in from another device.' });
      } else {
        console.log(`🔄 [Reconnect] Disconnecting stale socket for same session ${sessionId}`);
      }
      oldSocket.disconnect(true);
    }
  }

  // ── Disconnect duplicate sockets for same session ──
  const oldSessionSocketId = socketSessions.get(sessionId);
  if (oldSessionSocketId && oldSessionSocketId !== socket.id) {
    const oldSocket = io.sockets.sockets.get(oldSessionSocketId);
    if (oldSocket) {
      console.log(`🔄 [Session Dedup] Disconnecting older duplicate socket for session ${sessionId}`);
      oldSocket.disconnect(true);
    }
  }

  // ── Register user ──
  await setActiveUser(userId, socket.id);
  socketSessions.set(sessionId, socket.id);

  // ── Upsert session record in DB ──
  try {
    await supabase.from('user_sessions').upsert({
      session_id: sessionId,
      user_id: userId,
      device_id: deviceId,
      login_time: new Date().toISOString(),
      last_seen: new Date().toISOString(),
      socket_id: socket.id,
      online_status: 'Online'
    });
  } catch (dbErr) {
    console.error(`❌ [DB] Error upserting user_sessions for ${userId}:`, dbErr.message);
  }

  // ── Set presence ──
  const currentPresence = await getPresence(userId);
  const activeRoomId = currentPresence?.roomId || null;
  await setPresence(userId, activeRoomId ? 'in room' : 'online', activeRoomId);

  // ─────────────────────────────────────────────
  // ✅ BUG #1 FIX: Drain offline queue AND send delivery_ack back to original sender
  // ─────────────────────────────────────────────
  try {
    const offlineMsgs = await hGetAllQueue(userId);
    const msgIds = Object.keys(offlineMsgs);
    if (msgIds.length > 0) {
      console.log(`📬 [Queue Drain] Delivering ${msgIds.length} queued messages to user ${userId}`);
      for (const [msgId, payloadStr] of Object.entries(offlineMsgs)) {
        let payload;
        try {
          payload = JSON.parse(payloadStr);
        } catch {
          await hDelQueue(userId, msgId);
          continue;
        }

        // Emit the queued message to the now-online receiver
        socket.emit('message', payload);
        console.log(`📩 [Queue Drain] Delivered queued message ${msgId} to user ${userId}`);

        // ✅ Delete from queue immediately after emit
        // (If socket drops mid-drain, the DB catch-up RPC on next connect will re-fetch from Supabase DB)
        await hDelQueue(userId, msgId);

        // ✅ Notify original sender that message was delivered (double tick)
        const senderSocketId = await getActiveUserSocket(payload.senderId);
        if (senderSocketId) {
          io.to(senderSocketId).emit('delivery_ack', {
            messageId: msgId,
            status: 'delivered',
            conversationId: payload.conversationId,
          });
          console.log(`✅ [Delivery ACK] Sent delivery_ack for ${msgId} to sender ${payload.senderId}`);
        }

        // Also update DB message_status to 'delivered'
        try {
          await supabase
            .from('messages')
            .update({ message_status: 'delivered', delivered_at: new Date().toISOString() })
            .eq('id', msgId);
        } catch (dbErr) {
          console.error(`❌ [DB] Failed to update delivered_at for message ${msgId}:`, dbErr.message);
        }
      }
    }
  } catch (err) {
    console.error(`❌ [Queue Drain] Error for user ${userId}:`, err.message);
  }

  // ─────────────────────────────────────────────
  // 1. Heartbeat Handler
  // ─────────────────────────────────────────────
  socket.on('heartbeat', async () => {
    try {
      const presence = await getPresence(userId);
      await setPresence(userId, presence?.status || 'online', presence?.roomId, {
        lastSeen: new Date().toISOString()
      });
      socket.emit('heartbeat', { status: 'alive', ts: Date.now() });

      // Throttled DB session update
      await supabase
        .from('user_sessions')
        .update({ last_seen: new Date().toISOString() })
        .eq('session_id', sessionId);
    } catch (e) {
      console.error(`❌ [Heartbeat] Error for user ${userId}:`, e.message);
    }
  });

  // ─────────────────────────────────────────────
  // 2. Chat Message Relay
  // ─────────────────────────────────────────────
  socket.on('message', async (payload) => {
    try {
      const { id, senderId, receiverId, conversationId } = payload;

      if (!id || !senderId || !receiverId) {
        return socket.emit('message_error', { error: 'Invalid message payload: missing id, senderId, or receiverId' });
      }

      // Rate limit: 5 messages / 3 seconds
      if (isRateLimited(`rate:chat:${userId}`, 5, 3000)) {
        console.warn(`⚠️  [Rate Limit] Chat rate limit hit for user ${userId}`);
        return socket.emit('rate_limit_error', { message: 'Too many messages. Slow down.' });
      }

      // ✅ BUG #3 FIX: Redis deduplication
      const alreadyProcessed = await isDuplicateMessage(id);
      if (alreadyProcessed) {
        console.warn(`♻️  [Dedup] Message ${id} already processed. Ignoring duplicate.`);
        // Still send ACK so client clears retry
        return socket.emit('server_ack', { messageId: id, status: 'sent' });
      }

      console.log(`📨 [Message Received] id=${id} from=${senderId} to=${receiverId} conv=${conversationId}`);

      // Queue for offline delivery (always queue first, delete on ACK)
      await hSetQueue(receiverId, id, payload);
      console.log(`📦 [Queue Push] Message ${id} queued for ${receiverId}`);

      // ✅ BUG #4 FIX: Look up receiver in Redis (not just in-memory map)
      const receiverSocketId = await getActiveUserSocket(receiverId);

      if (receiverSocketId) {
        const receiverSocket = io.sockets.sockets.get(receiverSocketId);
        if (receiverSocket && receiverSocket.connected) {
          io.to(receiverSocketId).emit('message', payload);
          console.log(`⚡ [Message Relayed] id=${id} delivered to ONLINE user ${receiverId}`);
        } else {
          // Socket entry stale — user actually offline
          await deleteActiveUser(receiverId);
          console.log(`🔌 [Stale Socket] Cleaned up stale socket entry for ${receiverId}. Message queued.`);
          await sendOfflineNotification(senderId, receiverId, id);
        }
      } else {
        console.log(`📤 [Offline] Message ${id} buffered for OFFLINE user ${receiverId}`);
        await sendOfflineNotification(senderId, receiverId, id);
      }

      // Server ACK: confirms message reached the relay server (single tick)
      socket.emit('server_ack', { messageId: id, status: 'sent', ts: Date.now() });
      console.log(`✅ [Server ACK] Sent server_ack for message ${id} to sender ${senderId}`);

    } catch (err) {
      console.error(`❌ [Message Handler] Error:`, err.message);
      socket.emit('message_error', { error: 'Server error processing message.' });
    }
  });

  // ─────────────────────────────────────────────
  // 3. Gift Event Relay
  // ─────────────────────────────────────────────
  socket.on('gift_send', async (payload) => {
    try {
      const { transactionId, roomId, senderId, giftId, count } = payload;

      if (isRateLimited(`rate:gift:${userId}`, 10, 1000)) {
        return socket.emit('rate_limit_error', { message: 'Too many gifts. Please wait.' });
      }

      const alreadyProcessed = await isDuplicateMessage(`gift:${transactionId}`);
      if (alreadyProcessed) {
        console.warn(`♻️  [Dedup] Gift transaction ${transactionId} already processed.`);
        return;
      }

      io.emit(`gift_broadcast:${roomId}`, payload);
      console.log(`🎁 [Gift] Broadcasted gift ${giftId} x${count} in room ${roomId}`);
    } catch (err) {
      console.error(`❌ [Gift Handler] Error:`, err.message);
    }
  });

  // ─────────────────────────────────────────────
  // 4. Room Lifecycle
  // ─────────────────────────────────────────────
  socket.on('join_room_status', async (data) => {
    const { roomId } = data;
    if (isRateLimited(`rate:join:${userId}`, 5, 60000)) {
      return socket.emit('rate_limit_error', { message: 'Too many room joins. Max 5/minute.' });
    }
    await setPresence(userId, 'in room', roomId);
    console.log(`🏠 [Room] User ${userId} joined room ${roomId}`);
  });

  socket.on('logout_room', async (data) => {
    const { roomId } = data;
    console.log(`🚪 [Room] User ${userId} requested logout from room ${roomId}`);
    const pendingRecovery = reconnectWindowTimers.get(userId);
    if (pendingRecovery) {
      clearTimeout(pendingRecovery.timeout);
      reconnectWindowTimers.delete(userId);
    }
    await performDisconnectCleanup(userId, sessionId, roomId);
  });

  // ─────────────────────────────────────────────
  // 5. App Lifecycle
  // ─────────────────────────────────────────────
  socket.on('background_state', async (data) => {
    const { state } = data;
    const presence = await getPresence(userId);

    if (state === 'background_60s') {
      console.log(`⏸️  [Lifecycle] User ${userId} in background (60s). Pausing mic.`);
      await setPresence(userId, 'background', presence?.roomId);
      try {
        await supabase
          .from('room_seats')
          .update({ mic_status: 'muted', is_speaking: false })
          .eq('room_id', presence?.roomId)
          .eq('user_id', userId);
      } catch (err) {
        console.error(`❌ [Lifecycle] Failed to mute seat for ${userId}:`, err.message);
      }
    } else if (state === 'background_5m') {
      console.log(`🔴 [Lifecycle] User ${userId} in background (5m). Disconnecting from room.`);
      await performDisconnectCleanup(userId, sessionId, presence?.roomId);
      socket.disconnect(true);
    }
  });

  // ─────────────────────────────────────────────
  // 6. ACK & Typing
  // ─────────────────────────────────────────────

  // Delivery ACK: Receiver confirms message received → remove from queue → notify sender
  socket.on('delivery_ack', async (data) => {
    try {
      const { messageId, senderId, receiverId: ackReceiverId } = data;
      console.log(`📬 [Delivery ACK] Message ${messageId} ACKed by receiver ${userId}`);

      // Remove from offline queue (keyed by the receiver = current user)
      await hDelQueue(userId, messageId);

      // Notify the original sender about delivery (double tick)
      const senderSocketId = await getActiveUserSocket(senderId);
      if (senderSocketId) {
        io.to(senderSocketId).emit('delivery_ack', {
          messageId,
          status: 'delivered',
          conversationId: data.conversationId,
        });
        console.log(`✅ [Delivery ACK] Forwarded delivery_ack to sender ${senderId}`);
      }

      // Update DB message_status
      try {
        await supabase
          .from('messages')
          .update({ message_status: 'delivered', delivered_at: new Date().toISOString() })
          .eq('id', messageId);
        console.log(`💾 [DB] Updated message ${messageId} status → delivered`);
      } catch (dbErr) {
        console.error(`❌ [DB] Failed to update delivered_at for ${messageId}:`, dbErr.message);
      }
    } catch (err) {
      console.error(`❌ [Delivery ACK] Error:`, err.message);
    }
  });

  // ✅ BUG #9 FIX: read_ack — senderId and receiverId were SWAPPED. Fixed now.
  socket.on('read_ack', async (data) => {
    try {
      const { messageId, senderId, receiverId: ackReceiverId, conversationId } = data;
      console.log(`👁️  [Read ACK] Message ${messageId} seen. Notifying original sender ${senderId}`);

      // senderId = person who SENT the original message (needs to see blue tick)
      const originalSenderSocketId = await getActiveUserSocket(senderId);
      if (originalSenderSocketId) {
        io.to(originalSenderSocketId).emit('read_ack', {
          messageId,
          conversationId,
          status: 'read',
        });
        console.log(`✅ [Read ACK] Blue tick sent to original sender ${senderId}`);
      }

      // Update DB
      try {
        await supabase
          .from('messages')
          .update({ message_status: 'seen', seen_at: new Date().toISOString() })
          .eq('id', messageId);
        console.log(`💾 [DB] Updated message ${messageId} status → seen`);
      } catch (dbErr) {
        console.error(`❌ [DB] Failed to update seen_at for ${messageId}:`, dbErr.message);
      }
    } catch (err) {
      console.error(`❌ [Read ACK] Error:`, err.message);
    }
  });

  socket.on('typing_start', (data) => {
    const { conversationId, receiverId } = data;
    getActiveUserSocket(receiverId).then(receiverSocketId => {
      if (receiverSocketId) {
        io.to(receiverSocketId).emit('typing_start', { conversationId, senderId: userId });
      }
    });
  });

  socket.on('typing_stop', (data) => {
    const { conversationId, receiverId } = data;
    getActiveUserSocket(receiverId).then(receiverSocketId => {
      if (receiverSocketId) {
        io.to(receiverSocketId).emit('typing_stop', { conversationId, senderId: userId });
      }
    });
  });

  // ─────────────────────────────────────────────
  // 7. Socket Disconnect (Grace Window)
  // ─────────────────────────────────────────────
  socket.on('disconnect', async (reason) => {
    console.log(`🔌 [Socket Disconnected] userId=${userId} reason=${reason}. Starting 20s grace window...`);

    // Remove from memory immediately
    activeUsers.delete(userId);
    socketSessions.delete(sessionId);

    // NOTE: Do NOT delete from Redis immediately — allow grace window reconnect to reclaim it

    const presence = await getPresence(userId);
    const roomId = presence?.roomId;

    const timeout = setTimeout(async () => {
      console.log(`⏰ [Grace Expired] Cleaning up user ${userId} after 20s disconnect timeout.`);
      await deleteActiveUser(userId);
      await performDisconnectCleanup(userId, sessionId, roomId);
    }, 20000);

    reconnectWindowTimers.set(userId, { timeout, roomId });
  });
});

// ─────────────────────────────────────────────
// Offline Notification Helper
// ─────────────────────────────────────────────

async function sendOfflineNotification(senderId, receiverId, messageId) {
  let senderName = 'Someone';
  try {
    const { data: profile } = await supabase
      .from('profiles')
      .select('username, display_name')
      .eq('id', senderId)
      .maybeSingle();
    if (profile) {
      senderName = profile.display_name || profile.username || 'Someone';
    }
  } catch (dbErr) {
    console.error(`❌ [Notification] Failed to fetch sender profile for ${senderId}:`, dbErr.message);
  }

  notificationService.sendNotificationToUser(
    receiverId,
    `New Message from ${senderName} 💬`,
    `@${senderName} sent you a message.`,
    'chat',
    { userId: senderId, messageId, action: 'message' }
  ).catch(err => console.error(`❌ [Notification] Failed to send offline notification:`, err.message));
}

// ─────────────────────────────────────────────
// Definitive Disconnect Cleanup
// ─────────────────────────────────────────────

async function performDisconnectCleanup(userId, sessionId, roomId) {
  reconnectWindowTimers.delete(userId);
  await setPresence(userId, 'offline', null);

  try {
    await supabase
      .from('user_sessions')
      .update({ online_status: 'Offline', last_seen: new Date().toISOString() })
      .eq('session_id', sessionId);
  } catch (err) {
    console.error(`❌ [DB] Failed to update session offline for ${sessionId}:`, err.message);
  }

  if (roomId) {
    try {
      await supabase.rpc('leave_room', { p_room_id: roomId });
      console.log(`🚪 [Room] Cleaned up user ${userId} from room ${roomId} seats`);
    } catch (err) {
      console.error(`❌ [Room] Failed to call leave_room RPC for ${userId}:`, err.message);
    }
  }

  console.log(`🔴 [Cleanup] User ${userId} marked offline. Session ${sessionId} closed.`);
}

// ─────────────────────────────────────────────
// ✅ BUG #16 FIX: Heartbeat Daemon — Check Redis Presence (not just in-memory)
// ─────────────────────────────────────────────

setInterval(async () => {
  const now = Date.now();
  const staleThresholdMs = 45000; // 45 seconds without heartbeat

  // Check in-memory first
  for (const [userId, presence] of presenceRegistry.entries()) {
    if (presence.status === 'offline') continue;
    const lastSeenTime = new Date(presence.lastSeen).getTime();
    if (now - lastSeenTime > staleThresholdMs) {
      console.warn(`⚠️  [Heartbeat Daemon] Stale presence for user ${userId} (${Math.round((now - lastSeenTime)/1000)}s). Forcing disconnect.`);
      const socketId = await getActiveUserSocket(userId);
      if (socketId) {
        const socket = io.sockets.sockets.get(socketId);
        if (socket) socket.disconnect(true);
      }
      const sessionId = presence.sessionId || '';
      await performDisconnectCleanup(userId, sessionId, presence.roomId);
    }
  }

  // Also scan Redis for presence keys that aren't in memory (post-restart scenario)
  if (isRedisConnected) {
    try {
      const keys = await redisClient.keys('presence:user:*');
      for (const key of keys) {
        const data = await redisClient.get(key);
        if (!data) continue;
        const presence = JSON.parse(data);
        if (presence.status === 'offline') continue;
        if (presenceRegistry.has(presence.userId)) continue; // Already handled above

        const lastSeenTime = new Date(presence.lastSeen).getTime();
        if (now - lastSeenTime > staleThresholdMs) {
          console.warn(`⚠️  [Heartbeat Daemon/Redis] Stale presence for user ${presence.userId}. Cleaning up.`);
          await performDisconnectCleanup(presence.userId, '', presence.roomId);
        }
      }
    } catch (e) {
      console.warn('⚠️  [Heartbeat Daemon] Redis key scan failed:', e.message);
    }
  }
}, 10000);

// ─────────────────────────────────────────────
// Notifications Service
// ─────────────────────────────────────────────

const notificationService = require('./notification_service');

app.post('/api/notifications/send', async (req, res) => {
  const { userId, userIds, roomId, communityId, topic, title, body, type, payload, scheduledFor } = req.body;

  try {
    if (!title || !body || !type) {
      return res.status(400).json({ error: 'Missing title, body, or type' });
    }

    if (scheduledFor) {
      const targetUserId = userId || (userIds && userIds[0]);
      if (!targetUserId) {
        return res.status(400).json({ error: 'Scheduled notifications require a target user' });
      }
      const schedResult = await notificationService.scheduleNotification(
        targetUserId, title, body, type, payload, scheduledFor
      );
      return res.status(200).json(schedResult);
    }

    let result;
    if (userId) {
      result = await notificationService.sendNotificationToUser(userId, title, body, type, payload);
    } else if (userIds && Array.isArray(userIds)) {
      result = await notificationService.sendNotificationToMultipleUsers(userIds, title, body, type, payload);
    } else if (roomId) {
      result = await notificationService.sendNotificationToRoom(roomId, title, body, type, payload);
    } else if (communityId) {
      result = await notificationService.sendNotificationToCommunity(communityId, title, body, type, payload);
    } else if (topic) {
      result = await notificationService.sendNotificationByTopic(topic, title, body, type, payload);
    } else {
      return res.status(400).json({ error: 'Must specify userId, userIds, roomId, communityId, or topic' });
    }

    return res.status(200).json({ success: true, result });
  } catch (err) {
    console.error('❌ [API] Notification send error:', err.message);
    return res.status(500).json({ error: err.message });
  }
});

// Poll scheduled notifications every minute
setInterval(() => {
  notificationService.processScheduledNotifications();
}, 60000);

// Start Supabase Realtime listener for notification dispatch
notificationService.startRealtimeListener();

// ─────────────────────────────────────────────
// Offline Message TTL Purge (Every Hour)
// ─────────────────────────────────────────────

setInterval(async () => {
  console.log('🧹 [Purge] Running offline message TTL cleanup (14 days)...');
  const now = Date.now();
  const maxAgeMs = 14 * 24 * 60 * 60 * 1000;

  if (isRedisConnected) {
    try {
      const keys = await redisClient.keys('chat:queue:*');
      let purgedCount = 0;
      for (const key of keys) {
        const queue = await redisClient.hGetAll(key);
        for (const [msgId, payloadStr] of Object.entries(queue)) {
          try {
            const payload = JSON.parse(payloadStr);
            const msgTime = new Date(payload.timestamp || payload.created_at || 0).getTime();
            if (now - msgTime > maxAgeMs) {
              await redisClient.hDel(key, msgId);
              purgedCount++;
            }
          } catch {
            await redisClient.hDel(key, msgId);
            purgedCount++;
          }
        }
      }
      console.log(`🧹 [Purge] Purged ${purgedCount} expired messages from Redis.`);
    } catch (e) {
      console.warn('⚠️  [Purge] Redis queue purge failed:', e.message);
    }
  }

  // Memory queue purge
  for (const [receiverId, queue] of offlineQueues.entries()) {
    for (const [msgId, payloadStr] of Object.entries(queue)) {
      try {
        const payload = JSON.parse(payloadStr);
        const msgTime = new Date(payload.timestamp || 0).getTime();
        if (now - msgTime > maxAgeMs) {
          delete queue[msgId];
        }
      } catch {
        delete queue[msgId];
      }
    }
    if (Object.keys(queue).length === 0) offlineQueues.delete(receiverId);
  }
}, 3600000);

// ─────────────────────────────────────────────
// Health Check
// ─────────────────────────────────────────────

app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    onlineUsers: activeUsers.size,
    redisOnline: isRedisConnected,
    firebaseSDK: true,
    uptime: process.uptime(),
    ts: new Date().toISOString(),
  });
});

// ─────────────────────────────────────────────
// Launch
// ─────────────────────────────────────────────

server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 [Server] AgoraX Chat & Relay Backend listening on port ${PORT}`);
  console.log(`📡 [Server] Redis: ${REDIS_URL}`);
  console.log(`🔗 [Server] Supabase: ${SUPABASE_URL}`);
});
