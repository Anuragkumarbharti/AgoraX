require('dotenv').config();
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const redis = require('redis');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

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
  })
  .catch((err) => {
    console.warn('Redis connection failed. Falling back to In-Memory Queue.');
    isRedisConnected = false;
  });

// Resilient In-Memory Queue fallback map (receiverId -> { messageId: payloadStr })
const memoryQueue = new Map();

async function hSetQueue(receiverId, messageId, payload) {
  if (isRedisConnected) {
    try {
      await redisClient.hSet(`chat:queue:${receiverId}`, messageId, JSON.stringify(payload));
      return;
    } catch (e) {
      console.warn('Redis write failed, falling back to memory:', e);
    }
  }
  if (!memoryQueue.has(receiverId)) {
    memoryQueue.set(receiverId, {});
  }
  memoryQueue.get(receiverId)[messageId] = JSON.stringify(payload);
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
  if (memoryQueue.has(receiverId)) {
    delete memoryQueue.get(receiverId)[messageId];
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
  return memoryQueue.get(receiverId) || {};
}

// In-memory registry for online users: userId -> socketId
const activeUsers = new Map();

// API Health Check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', onlineUsers: activeUsers.size, redisOnline: isRedisConnected });
});

// Socket.IO Event Engine
// Socket.IO Event Engine
io.on('connection', async (socket) => {
  const userId = socket.handshake.query.userId;
  if (!userId) {
    console.warn('Socket connection rejected: Missing userId in query parameters.');
    return socket.disconnect();
  }

  activeUsers.set(userId, socket.id);
  console.log(`User registered: ${userId} (Socket: ${socket.id})`);

  // Broadcast presence update (online)
  io.emit('presence_update', { userId, status: 'online' });

  // 1. Heartbeat ping-pong
  socket.on('heartbeat', () => {
    socket.emit('heartbeat', { status: 'alive' });
  });

  // 2. Drain offline Redis/Memory Queue
  try {
    const offlineMsgs = await hGetAllQueue(userId);
    if (offlineMsgs && Object.keys(offlineMsgs).length > 0) {
      console.log(`Draining ${Object.keys(offlineMsgs).length} offline messages to user ${userId}...`);
      for (const [msgId, payloadStr] of Object.entries(offlineMsgs)) {
        const payload = JSON.parse(payloadStr);
        socket.emit('message', payload);
      }
    }
  } catch (err) {
    console.error(`Error draining queue for user ${userId}:`, err);
  }

  // 3. Relay Message (E2EE payload)
  socket.on('message', async (payload) => {
    try {
      const { id, senderId, receiverId } = payload;
      const receiverSocketId = activeUsers.get(receiverId);

      // Store in receiver's delivery queue instantly
      await hSetQueue(receiverId, id, payload);

      if (receiverSocketId) {
        // Receiver is online, relay instantly
        io.to(receiverSocketId).emit('message', payload);
        console.log(`Relayed message ${id} from ${senderId} to online receiver ${receiverId}`);
      } else {
        console.log(`Buffered message ${id} from ${senderId} in queue for offline receiver ${receiverId}`);
      }

      // ACK to sender that message reached the relay server (Single Tick)
      socket.emit('server_ack', { messageId: id, status: 'sent' });
    } catch (err) {
      console.error('Error handling message:', err);
    }
  });

  // 4. Delivery Acknowledgment (triggered when recipient saves message to local Isar)
  socket.on('delivery_ack', async (data) => {
    try {
      const { messageId, senderId, receiverId } = data;

      // Remove from receiver's temporary delivery queue
      await hDelQueue(receiverId, messageId);
      console.log(`Purged delivered message ${messageId} from queue of user ${receiverId}`);

      // Forward delivery status update to sender (Double Grey Tick)
      const senderSocketId = activeUsers.get(senderId);
      if (senderSocketId) {
        io.to(senderSocketId).emit('delivery_ack', { messageId, status: 'delivered' });
      }
    } catch (err) {
      console.error('Error handling delivery_ack:', err);
    }
  });

  // 5. Read Acknowledgment (triggered when recipient opens chat screen)
  socket.on('read_ack', async (data) => {
    try {
      const { messageId, senderId, receiverId, conversationId } = data;

      // Forward read receipts to the conversation participant (Double Blue Tick)
      const senderSocketId = activeUsers.get(receiverId);
      if (senderSocketId) {
        io.to(senderSocketId).emit('read_ack', { messageId, conversationId, status: 'read' });
      }
    } catch (err) {
      console.error('Error handling read_ack:', err);
    }
  });

  // 6. Typing Indicators (typing_start & typing_stop)
  socket.on('typing_start', (data) => {
    try {
      const { conversationId, receiverId } = data;
      const receiverSocketId = activeUsers.get(receiverId);
      if (receiverSocketId) {
        io.to(receiverSocketId).emit('typing_start', { conversationId, senderId: userId });
      }
    } catch (err) {
      console.error('Error handling typing_start:', err);
    }
  });

  socket.on('typing_stop', (data) => {
    try {
      const { conversationId, receiverId } = data;
      const receiverSocketId = activeUsers.get(receiverId);
      if (receiverSocketId) {
        io.to(receiverSocketId).emit('typing_stop', { conversationId, senderId: userId });
      }
    } catch (err) {
      console.error('Error handling typing_stop:', err);
    }
  });

  // 7. Request presence status / last seen manually
  socket.on('last_seen_update', (data) => {
    try {
      const { targetUserId } = data;
      const isOnline = activeUsers.has(targetUserId);
      socket.emit('last_seen_update', {
        userId: targetUserId,
        status: isOnline ? 'online' : 'offline',
        lastSeen: isOnline ? null : new Date().toISOString()
      });
    } catch (err) {
      console.error('Error handling last_seen_update:', err);
    }
  });

  // 8. Handle Disconnection
  socket.on('disconnect', () => {
    activeUsers.delete(userId);
    console.log(`User disconnected: ${userId}`);
    
    // Broadcast presence update (offline with lastSeen timestamp)
    io.emit('presence_update', { 
      userId, 
      status: 'offline', 
      lastSeen: new Date().toISOString() 
    });
  });
});

// Launch server
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Creania Chat Relay Backend listening on port ${PORT}`);
});
