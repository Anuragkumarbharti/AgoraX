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
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpjY3JnaXBscmJlc2xncGNlenVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQyMDQyNDAsImV4cCI6MjA5OTc4MDI0MH0.iYRR8y7Z_S0z_ROVzVyvj1M4rv6sWK2q7Z6K7vRwD4g';
const JWT_SECRET = process.env.SUPABASE_JWT_SECRET || 'super-secret-jwt-key';

// Initialize Supabase Client
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Initialize Redis Client
let isRedisConnected = false;
const redisClient = redis.createClient({ url: REDIS_URL });

redisClient.on('error', (err) => {
  console.error('Redis Client Error:', err);
  isRedisConnected = false;
});

redisClient.connect()
  .then(() => {
    console.log('Successfully connected to Redis Server.');
    isRedisConnected = true;
    syncFromSupabase();
  })
  .catch((err) => {
    console.warn('Redis connection failed. Falling back to In-Memory store.');
    isRedisConnected = false;
  });

// --- In-Memory Store Fallbacks ---
const activeUsers = new Map();         // userId -> socketId
const socketSessions = new Map();      // sessionId -> socketId
const presenceRegistry = new Map();    // userId -> presenceObj
const reconnectWindowTimers = new Map(); // userId -> { timeout, seatState, roomId }
const offlineQueues = new Map();       // receiverId -> { messageId: payloadStr }
const rateLimitMap = new Map();        // key -> timestamps array
const processedGifts = new Set();      // gift_transaction_id set
const processedMessages = new Set();   // message_uuid set

// --- Helper Functions to support Redis/In-Memory abstraction ---

async function hSetQueue(receiverId, messageId, payload) {
  if (isRedisConnected) {
    try {
      await redisClient.hSet(`chat:queue:${receiverId}`, messageId, JSON.stringify(payload));
      return;
    } catch (e) {
      console.warn('Redis write failed, falling back to memory:', e);
    }
  }
  if (!offlineQueues.has(receiverId)) {
    offlineQueues.set(receiverId, {});
  }
  offlineQueues.get(receiverId)[messageId] = JSON.stringify(payload);
}

async function hDelQueue(receiverId, messageId) {
  if (isRedisConnected) {
    try {
      await redisClient.hDel(`chat:queue:${receiverId}`, messageId);
      return;
    } catch (e) {
      console.warn('Redis delete failed, falling back to memory:', e);
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
      console.warn('Redis read failed, falling back to memory:', e);
    }
  }
  return offlineQueues.get(receiverId) || {};
}

// Presence Helper
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
      await redisClient.set(`presence:user:${userId}`, JSON.stringify(presenceObj));
    } catch (e) {
      console.warn('Redis set presence failed:', e);
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
    console.error('Failed to sync presence to profiles table:', e);
  }

  // Broadcast presence update
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
      console.warn('Redis get presence failed:', e);
    }
  }
  return presenceRegistry.get(userId);
}

// Sync Cache from Supabase on startup / Redis connect
async function syncFromSupabase() {
  try {
    console.log('Syncing active database sessions and presence to Redis...');
    const { data: profiles, error } = await supabase
      .from('profiles')
      .select('id, active_room_id, presence_state');
    
    if (error) throw error;
    
    for (const profile of profiles) {
      if (profile.presence_state && profile.presence_state !== 'Offline') {
        await setPresence(profile.id, profile.presence_state.toLowerCase(), profile.active_room_id);
      }
    }
  } catch (e) {
    console.error('Supabase synchronization error:', e);
  }
}

// --- Rate Limiting Helper ---
function isRateLimited(key, maxRequests, windowMs) {
  const now = Date.now();
  if (!rateLimitMap.has(key)) {
    rateLimitMap.set(key, []);
  }

  const timestamps = rateLimitMap.get(key).filter(t => now - t < windowMs);
  if (timestamps.length >= maxRequests) {
    return true;
  }

  timestamps.push(now);
  rateLimitMap.set(key, timestamps);
  return false;
}

// --- Socket.IO Auth Middleware ---
io.use(async (socket, next) => {
  try {
    const { userId, sessionId, deviceId, token } = socket.handshake.query;

    if (!userId || !sessionId || !deviceId) {
      return next(new Error('Authentication failed: Missing userId, sessionId, or deviceId'));
    }

    // 1. JWT validation
    if (token) {
      try {
        // Option A: Verify token locally with JWT_SECRET if matching signature is used
        // Option B: Verify with Supabase client securely
        const { data: { user }, error } = await supabase.auth.getUser(token);
        if (error || !user || user.id !== userId) {
          return next(new Error('Authentication failed: Invalid JWT token'));
        }
      } catch (jwtErr) {
        return next(new Error('Authentication failed: JWT verification failed'));
      }
    }

    // 2. Global Ban Check
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('is_banned')
      .eq('id', userId)
      .maybeSingle();

    if (profileError || (profile && profile.is_banned)) {
      return next(new Error('Authentication failed: User account is banned'));
    }

    // Pass validated parameters to connection handler
    socket.userId = userId;
    socket.sessionId = sessionId;
    socket.deviceId = deviceId;
    return next();
  } catch (err) {
    return next(new Error('Authentication failed: ' + err.message));
  }
});

// --- Connection Handler ---
io.on('connection', async (socket) => {
  const userId = socket.userId;
  const sessionId = socket.sessionId;
  const deviceId = socket.deviceId;

  console.log(`User connected: ${userId} (Session: ${sessionId}, Device: ${deviceId}, Socket: ${socket.id})`);

  // Handle network reconnect window recovery
  const pendingRecovery = reconnectWindowTimers.get(userId);
  if (pendingRecovery) {
    console.log(`User ${userId} reconnected within grace window. Restoring states.`);
    clearTimeout(pendingRecovery.timeout);
    reconnectWindowTimers.delete(userId);
  }

  // Single Device Login enforcement: Invalidate previous session
  const oldSocketId = socketSessions.get(sessionId);
  const oldUserSocketId = activeUsers.get(userId);

  if (oldUserSocketId && oldUserSocketId !== socket.id) {
    const oldSocket = io.sockets.sockets.get(oldUserSocketId);
    if (oldSocket && oldSocket.sessionId !== sessionId) {
      console.log(`Force logging out older session for user ${userId}`);
      oldSocket.emit('force_logout', { message: 'Logged in from another device.' });
      oldSocket.disconnect(true);
    }
  }

  // Prevent Duplicate Sockets on same session
  if (oldSocketId && oldSocketId !== socket.id) {
    const oldSocket = io.sockets.sockets.get(oldSocketId);
    if (oldSocket) {
      console.log(`Disconnecting older duplicate socket for session ${sessionId}`);
      oldSocket.disconnect(true);
    }
  }

  activeUsers.set(userId, socket.id);
  socketSessions.set(sessionId, socket.id);

  // Initialize or update user session record in Supabase
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
    console.error('Error upserting user session details:', dbErr);
  }

  // Broadcast presence update
  const currentPresence = await getPresence(userId);
  const activeRoomId = currentPresence?.roomId || null;
  await setPresence(userId, activeRoomId ? 'in room' : 'online', activeRoomId);

  // Drain offline message queue
  try {
    const offlineMsgs = await hGetAllQueue(userId);
    if (offlineMsgs && Object.keys(offlineMsgs).length > 0) {
      console.log(`Draining ${Object.keys(offlineMsgs).length} offline messages to user ${userId}...`);
      for (const [msgId, payloadStr] of Object.entries(offlineMsgs)) {
        socket.emit('message', JSON.parse(payloadStr));
      }
    }
  } catch (err) {
    console.error(`Error draining queue for user ${userId}:`, err);
  }

  // 1. Heartbeat Handler
  socket.on('heartbeat', async () => {
    try {
      const presence = await getPresence(userId);
      await setPresence(userId, presence?.status || 'online', presence?.roomId, { lastSeen: new Date().toISOString() });
      socket.emit('heartbeat', { status: 'alive' });
      
      // Update session last_seen in database periodically (throttle)
      await supabase
        .from('user_sessions')
        .update({ last_seen: new Date().toISOString() })
        .eq('session_id', sessionId);
    } catch (e) {
      console.error('Heartbeat processing error:', e);
    }
  });

  // 2. Chat message relay & deduplication & rate limiting
  socket.on('message', async (payload) => {
    try {
      const { id, senderId, receiverId } = payload;

      // Rate limit: Max 5 messages / 3 sec
      if (isRateLimited(`rate:chat:${userId}`, 5, 3000)) {
        return socket.emit('rate_limit_error', { message: 'Too many messages. Slow down.' });
      }

      // Deduplication: Ignore if already processed
      if (processedMessages.has(id)) {
        return console.warn(`Message ${id} ignored: duplicate packet.`);
      }
      processedMessages.add(id);
      setTimeout(() => processedMessages.delete(id), 60000); // 60s TTL

      const receiverSocketId = activeUsers.get(receiverId);
      await hSetQueue(receiverId, id, payload);

      if (receiverSocketId) {
        io.to(receiverSocketId).emit('message', payload);
        console.log(`Relayed message ${id} to online user ${receiverId}`);
      } else {
        console.log(`Buffered message ${id} for offline user ${receiverId}`);
      }

      socket.emit('server_ack', { messageId: id, status: 'sent' });
    } catch (err) {
      console.error('Error handling message:', err);
    }
  });

  // 3. Gift event relay & deduplication & rate limiting
  socket.on('gift_send', async (payload) => {
    try {
      const { transactionId, roomId, senderId, targetSeatIndexes, giftId, count } = payload;

      // Rate limit: Max 10 gifts / sec
      if (isRateLimited(`rate:gift:${userId}`, 10, 1000)) {
        return socket.emit('rate_limit_error', { message: 'Too many gifts sent. Please wait.' });
      }

      // Deduplication
      if (processedGifts.has(transactionId)) {
        return console.warn(`Gift transaction ${transactionId} ignored: duplicate packet.`);
      }
      processedGifts.add(transactionId);
      setTimeout(() => processedGifts.delete(transactionId), 60000);

      // Broadcast gift animation to room
      io.emit(`gift_broadcast:${roomId}`, payload);
      console.log(`Broadcasted gift ${giftId} x${count} in room ${roomId}`);
    } catch (err) {
      console.error('Error handling gift_send:', err);
    }
  });

  // 4. Room lifecycle: join_room & leave_room updates
  socket.on('join_room_status', async (data) => {
    const { roomId } = data;
    if (isRateLimited(`rate:join:${userId}`, 5, 60000)) {
      return socket.emit('rate_limit_error', { message: 'Too many room joins. Max 5/minute.' });
    }
    await setPresence(userId, 'in room', roomId);
    console.log(`User ${userId} joined room ${roomId}`);
  });

  socket.on('logout_room', async (data) => {
    const { roomId } = data;
    console.log(`User ${userId} requested logout_room for room ${roomId}. Performing instant cleanup.`);
    
    // Invalidate reconnect grace window timers if any
    const pendingRecovery = reconnectWindowTimers.get(userId);
    if (pendingRecovery) {
      clearTimeout(pendingRecovery.timeout);
      reconnectWindowTimers.delete(userId);
    }

    await performDisconnectCleanup(userId, sessionId, roomId);
  });

  // 5. App Lifecycle background state updates
  socket.on('background_state', async (data) => {
    const { state } = data; // 'background_60s', 'background_5m'
    const presence = await getPresence(userId);
    
    if (state === 'background_60s') {
      console.log(`User ${userId} in background for 60s. Pausing speaking animation.`);
      await setPresence(userId, 'background', presence?.roomId);
      // Mute seat mic
      try {
        await supabase
          .from('room_seats')
          .update({ mic_status: 'muted', is_speaking: false })
          .eq('room_id', presence?.roomId)
          .eq('user_id', userId);
      } catch (err) {
        console.error('Failed to mute user on background 60s:', err);
      }
    } else if (state === 'background_5m') {
      console.log(`User ${userId} in background for 5m. Disconnecting and clearing seat.`);
      await performDisconnectCleanup(userId, sessionId, presence?.roomId);
      socket.disconnect(true);
    }
  });

  // 6. Acknowledgments & Typings
  socket.on('delivery_ack', async (data) => {
    try {
      const { messageId, senderId, receiverId } = data;
      await hDelQueue(receiverId, messageId);
      const senderSocketId = activeUsers.get(senderId);
      if (senderSocketId) {
        io.to(senderSocketId).emit('delivery_ack', { messageId, status: 'delivered' });
      }
    } catch (err) {
      console.error('Error handling delivery_ack:', err);
    }
  });

  socket.on('read_ack', async (data) => {
    try {
      const { messageId, senderId, receiverId, conversationId } = data;
      const senderSocketId = activeUsers.get(receiverId);
      if (senderSocketId) {
        io.to(senderSocketId).emit('read_ack', { messageId, conversationId, status: 'read' });
      }
    } catch (err) {
      console.error('Error handling read_ack:', err);
    }
  });

  socket.on('typing_start', (data) => {
    const { conversationId, receiverId } = data;
    const receiverSocketId = activeUsers.get(receiverId);
    if (receiverSocketId) {
      io.to(receiverSocketId).emit('typing_start', { conversationId, senderId: userId });
    }
  });

  socket.on('typing_stop', (data) => {
    const { conversationId, receiverId } = data;
    const receiverSocketId = activeUsers.get(receiverId);
    if (receiverSocketId) {
      io.to(receiverSocketId).emit('typing_stop', { conversationId, senderId: userId });
    }
  });

  // 7. Socket Disconnect (Grace connection recovery window)
  socket.on('disconnect', async () => {
    console.log(`User socket disconnected: ${userId}. Starting 20s recovery grace window...`);
    activeUsers.delete(userId);
    socketSessions.delete(sessionId);

    // Reconnection grace window
    const presence = await getPresence(userId);
    const roomId = presence?.roomId;

    const timeout = setTimeout(async () => {
      console.log(`Grace window expired for user ${userId}. Cleaning up voice seats and presence.`);
      await performDisconnectCleanup(userId, sessionId, roomId);
    }, 20000); // 20 seconds reconnect grace window

    reconnectWindowTimers.set(userId, { timeout, roomId });
  });
});

// --- Cleanup on definitive disconnect or heartbeat timeout ---
async function performDisconnectCleanup(userId, sessionId, roomId) {
  reconnectWindowTimers.delete(userId);
  await setPresence(userId, 'offline', null);

  try {
    // Invalidate user session database record
    await supabase
      .from('user_sessions')
      .update({ online_status: 'Offline' })
      .eq('session_id', sessionId);
  } catch (err) {
    console.error('Failed to update session offline status:', err);
  }

  // Clear room seats and trigger leave updates in Supabase
  if (roomId) {
    try {
      await supabase.rpc('leave_room', { p_room_id: roomId });
      console.log(`Cleaned up user ${userId} from room ${roomId} seats`);
    } catch (err) {
      console.error('Failed to call leave_room cleanup RPC:', err);
    }
  }
}

// --- Heartbeat Missing Daemon Check (Runs every 10 seconds) ---
setInterval(async () => {
  const now = Date.now();
  for (const [userId, presence] of presenceRegistry.entries()) {
    if (presence.status === 'offline') continue;

    const lastSeenTime = new Date(presence.lastSeen).getTime();
    if (now - lastSeenTime > 45000) { // Missing heartbeat for 45 seconds
      console.log(`Heartbeat missing for 45s from user ${userId}. Forcing disconnection.`);
      
      const socketId = activeUsers.get(userId);
      if (socketId) {
        const socket = io.sockets.sockets.get(socketId);
        if (socket) {
          socket.disconnect(true);
        }
      }

      const sessionId = presence.sessionId || '';
      await performDisconnectCleanup(userId, sessionId, presence.roomId);
    }
  }
}, 10000);

// --- API Health Check ---
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', onlineUsers: activeUsers.size, redisOnline: isRedisConnected });
});

// Launch server
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Creania Chat & Session Relay Backend listening on port ${PORT}`);
});
