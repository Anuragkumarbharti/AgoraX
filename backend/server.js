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
const redisClient = redis.createClient({ url: REDIS_URL });

redisClient.on('error', (err) => console.error('Redis Client Error:', err));
redisClient.connect()
  .then(() => console.log('Successfully connected to Redis Server.'))
  .catch((err) => console.error('Failed connecting to Redis:', err));

// In-memory registry for online users: userId -> socketId
const activeUsers = new Map();

// API Health Check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', onlineUsers: activeUsers.size });
});

// Socket.IO Event Engine
io.on('connection', async (socket) => {
  const userId = socket.handshake.query.userId;
  if (!userId) {
    console.warn('Socket connection rejected: Missing userId in query parameters.');
    return socket.disconnect();
  }

  activeUsers.set(userId, socket.id);
  console.log(`User registered: ${userId} (Socket: ${socket.id})`);

  // Broadcast online status
  socket.broadcast.emit('user_presence', { userId, status: 'online' });

  // 1. Drain offline Redis Queue
  try {
    const queueKey = `chat:queue:${userId}`;
    const offlineMsgs = await redisClient.hGetAll(queueKey);
    if (offlineMsgs && Object.keys(offlineMsgs).length > 0) {
      console.log(`Draining ${Object.keys(offlineMsgs).length} offline messages to user ${userId}...`);
      for (const [msgId, payloadStr] of Object.entries(offlineMsgs)) {
        const payload = JSON.parse(payloadStr);
        socket.emit('receive_message', payload);
        // Note: The message stays in Redis until the client decrypts, saves to Isar,
        // and emits a 'delivery_ack' back to the server.
      }
    }
  } catch (err) {
    console.error(`Error draining Redis queue for user ${userId}:`, err);
  }

  // 2. Relay Message
  socket.on('send_message', async (payload) => {
    try {
      const { id, senderId, receiverId } = payload;
      const receiverSocketId = activeUsers.get(receiverId);

      // Store in receiver's Redis queue instantly (fail-safe fallback)
      await redisClient.hSet(`chat:queue:${receiverId}`, id, JSON.stringify(payload));

      if (receiverSocketId) {
        // Receiver is online, relay instantly
        io.to(receiverSocketId).emit('receive_message', payload);
        console.log(`Relayed message ${id} from ${senderId} to online receiver ${receiverId}`);
      } else {
        console.log(`Buffered message ${id} from ${senderId} in Redis queue for offline receiver ${receiverId}`);
      }

      // ACK to sender that message reached the relay server
      socket.emit('server_ack', { messageId: id, status: 'sent' });
    } catch (err) {
      console.error('Error handling send_message:', err);
    }
  });

  // 3. Delivery Acknowledgment (triggered when recipient saves message to local Isar)
  socket.on('delivery_ack', async (data) => {
    try {
      const { messageId, senderId, receiverId } = data;

      // Remove from receiver's temporary Redis delivery queue
      await redisClient.hDel(`chat:queue:${receiverId}`, messageId);
      console.log(`Purged delivered message ${messageId} from Redis queue of user ${receiverId}`);

      // Forward delivery status update to sender
      const senderSocketId = activeUsers.get(senderId);
      if (senderSocketId) {
        io.to(senderSocketId).emit('delivery_ack', { messageId, status: 'delivered' });
      }
    } catch (err) {
      console.error('Error handling delivery_ack:', err);
    }
  });

  // 4. Read Acknowledgment (triggered when recipient opens chat screen)
  socket.on('read_ack', async (data) => {
    try {
      const { conversationId, receiverId } = data;

      // Forward read receipts to the conversation participant
      const senderSocketId = activeUsers.get(receiverId);
      if (senderSocketId) {
        io.to(senderSocketId).emit('read_ack', { conversationId, status: 'read' });
      }
    } catch (err) {
      console.error('Error handling read_ack:', err);
    }
  });

  // 5. Typing Indicator Relay
  socket.on('typing_state', (data) => {
    try {
      const { conversationId, isTyping } = data;
      // Broadcast to other participant
      socket.broadcast.emit('typing_state', { conversationId, isTyping });
    } catch (err) {
      console.error('Error handling typing_state:', err);
    }
  });

  // 6. Handle Disconnection
  socket.on('disconnect', () => {
    activeUsers.delete(userId);
    console.log(`User disconnected: ${userId}`);
    
    // Broadcast offline presence with last seen timestamp
    socket.broadcast.emit('user_presence', { 
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
