const admin = require('firebase-admin');
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://zccrgiplrbeslgpcezul.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY;
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

let firebaseApp = null;
let isFirebaseInitialized = false;

// 1. Initialize Firebase Admin SDK
try {
  let serviceAccount = null;

  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  } else {
    const serviceAccountPath = path.join(__dirname, 'firebase-service-account.json');
    if (fs.existsSync(serviceAccountPath)) {
      serviceAccount = require(serviceAccountPath);
    }
  }

  if (serviceAccount) {
    firebaseApp = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    isFirebaseInitialized = true;
    console.log('🔥 Firebase Admin SDK initialized successfully.');
  } else {
    console.warn('⚠️ No Firebase service account credentials found. Starting in SIMULATION mode.');
  }
} catch (error) {
  console.error('❌ Failed to initialize Firebase Admin SDK. Starting in SIMULATION mode:', error.message);
}

/**
 * Check if the user settings allow notifications for the given category
 */
async function checkNotificationPreferences(userId, type) {
  try {
    const { data, error } = await supabase
      .from('notification_settings')
      .select('*')
      .eq('user_id', userId)
      .maybeSingle();

    if (error || !data) return true; 

    if (data.mute_all) return false;

    if (['security', 'system', 'wallet'].includes(type.toLowerCase())) return true;

    const typeMapping = {
      'personal_message': 'messages',
      'group_message': 'messages',
      'room_chat_message': 'messages',
      'message_reaction': 'messages',
      'message_reply': 'messages',
      'new_follower': 'followers',
      'follow_request_accepted': 'followers',
      'new_post': 'community',
      'new_announcement': 'community',
      'new_event': 'community',
      'community_invite': 'community',
      'poll_started': 'community',
      'room_invitation': 'voice_rooms',
      'host_started_room': 'voice_rooms',
      'co_host_invitation': 'voice_rooms',
      'seat_invitation': 'voice_rooms',
      'seat_accepted': 'voice_rooms',
      'seat_rejected': 'voice_rooms',
      'quiz_started': 'quiz',
      'quiz_reminder': 'quiz',
      'quiz_winner': 'quiz',
      'reward_received': 'quiz',
      'coins_received': 'wallet',
      'coins_deducted': 'wallet',
      'recharge_success': 'wallet',
      'withdrawal_success': 'wallet',
      'withdrawal_rejected': 'wallet',
      'marketing': 'marketing'
    };

    const settingKey = typeMapping[type] || 'marketing';
    return data[settingKey] !== false;
  } catch (err) {
    console.error(`Error checking preferences for user ${userId}:`, err);
    return true;
  }
}

/**
 * Cleans up invalid FCM tokens
 */
async function deleteInvalidToken(token) {
  try {
    await supabase.from('fcm_tokens').delete().eq('token', token);
    console.log(`🧹 Deleted invalid token from DB: ${token.substring(0, 15)}...`);
  } catch (err) {
    console.error('Error cleaning up token:', err);
  }
}

/**
 * Log notification delivery status
 */
async function logNotificationDelivery({ notificationId, receiverId, token, status, errorReason }) {
  try {
    await supabase.from('notification_logs').insert({
      notification_id: notificationId,
      receiver_id: receiverId,
      fcm_token: token,
      status: status,
      failure_reason: errorReason,
      delivered_at: status === 'delivered' ? new Date().toISOString() : null
    });
  } catch (err) {
    console.error('Failed to log delivery status:', err);
  }
}

/**
 * Map notification categories to Android channels created in Kotlin
 */
function getChannelIdForType(type) {
  const typeLower = type.toLowerCase();
  if (['personal_message', 'group_message', 'room_chat_message', 'message_reaction', 'message_reply'].includes(typeLower)) {
    return 'messages_channel';
  }
  if (['room_invitation', 'host_started_room', 'co_host_invitation', 'seat_invitation', 'seat_accepted', 'seat_rejected'].includes(typeLower)) {
    return 'voice_rooms_channel';
  }
  if (['new_post', 'new_announcement', 'new_event', 'community_invite', 'poll_started', 'community'].includes(typeLower)) {
    return 'community_channel';
  }
  if (['coins_received', 'coins_deducted', 'recharge_success', 'withdrawal_success', 'withdrawal_rejected'].includes(typeLower)) {
    return 'wallet_channel';
  }
  if (['quiz_started', 'quiz_reminder', 'quiz_winner', 'reward_received'].includes(typeLower)) {
    return 'quiz_channel';
  }
  if (['security_alert', 'login_detected', 'password_changed', 'account_warning', 'account_banned', 'version_update', 'maintenance_notice'].includes(typeLower)) {
    return 'system_channel';
  }
  return 'marketing_channel';
}

/**
 * Process a notification database record and send push notification
 */
async function processPushNotification(record) {
  const { id: notificationId, user_id: userId, title, body, type, payload } = record;
  console.log(`📡 Processing Realtime Push Notification ${notificationId} for User ${userId}: "${title}"`);

  // 1. Mark as processed immediately to prevent duplicate delivery attempts
  await supabase
    .from('notifications')
    .update({ push_dispatched: true })
    .eq('id', notificationId);

  // 2. Check preferences
  const isAllowed = await checkNotificationPreferences(userId, type);
  if (!isAllowed) {
    console.log(`🔕 Push muted by user preferences: ${type} for User ${userId}`);
    await logNotificationDelivery({
      notificationId,
      receiverId: userId,
      token: null,
      status: 'failed',
      errorReason: 'user_muted'
    });
    return;
  }

  // 3. Fetch FCM tokens
  const { data: tokensData, error: tokensError } = await supabase
    .from('fcm_tokens')
    .select('token, device_type')
    .eq('user_id', userId);

  if (tokensError || !tokensData || tokensData.length === 0) {
    console.log(`ℹ️ No active FCM tokens for User ${userId}.`);
    await logNotificationDelivery({
      notificationId,
      receiverId: userId,
      token: null,
      status: 'failed',
      errorReason: 'no_tokens_registered'
    });
    return;
  }

  const finalPayload = { 
    ...payload, 
    notificationId, 
    type, 
    title, 
    body 
  };

  const sendPromises = tokensData.map(async (device) => {
    const token = device.token;

    if (!isFirebaseInitialized) {
      console.log(`[SIMULATION] Push to token ${token.substring(0, 10)}...: "${body}"`);
      await logNotificationDelivery({
        notificationId,
        receiverId: userId,
        token: token,
        status: 'delivered'
      });
      return;
    }

    const message = {
      token: token,
      notification: {
        title: title,
        body: body
      },
      data: Object.fromEntries(
        Object.entries(finalPayload).map(([key, val]) => [key, typeof val === 'object' ? JSON.stringify(val) : String(val)])
      ),
      android: {
        notification: {
          channelId: getChannelIdForType(type),
          sound: 'default'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1
          }
        }
      }
    };

    try {
      await admin.messaging().send(message);
      await logNotificationDelivery({
        notificationId,
        receiverId: userId,
        token: token,
        status: 'delivered'
      });
    } catch (err) {
      console.error(`❌ FCM delivery error for token ${token.substring(0, 10)}...:`, err.message);
      
      const isInvalidToken = 
        err.code === 'messaging/registration-token-not-registered' ||
        err.code === 'messaging/invalid-argument' ||
        err.message.includes('not registered');

      if (isInvalidToken) {
        await deleteInvalidToken(token);
      }

      await logNotificationDelivery({
        notificationId,
        receiverId: userId,
        token: token,
        status: 'failed',
        errorReason: err.code || err.message
      });
    }
  });

  await Promise.all(sendPromises);
}

/**
 * Inserts notification in database. The realtime listener picks it up and sends the push.
 */
async function sendNotificationToUser(userId, title, body, type, payload = {}) {
  console.log(`📤 Dispatching notification [${type}] to User ${userId}: "${title}"`);

  const typeLower = type.toLowerCase();
  
  // 1. Smart Merging Rule: Chat Messages
  if (['chat', 'personal_message', 'group_message'].includes(typeLower)) {
    const senderId = payload.senderId;
    if (senderId) {
      try {
        const { data: existing, error } = await supabase
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .eq('is_read', false)
          .eq('type', type)
          .eq('payload->>senderId', senderId)
          .order('created_at', { ascending: false })
          .limit(1)
          .maybeSingle();

        if (existing && !error) {
          const count = (existing.payload.count || 1) + 1;
          const senderName = payload.senderName || 'Someone';
          const newBody = `${senderName} sent you ${count} messages`;

          const { data: updated, error: updateErr } = await supabase
            .from('notifications')
            .update({
              body: newBody,
              payload: { ...existing.payload, count },
              push_dispatched: false,
              created_at: new Date().toISOString()
            })
            .eq('id', existing.id)
            .select()
            .single();

          if (!updateErr && updated) {
            return { success: true, notificationId: updated.id };
          }
        }
      } catch (err) {
        console.warn('Chat merging check failed:', err);
      }
    }
  }

  // 2. Smart Merging Rule: Likes
  else if (['like', 'post_like', 'comment_like'].includes(typeLower)) {
    const postId = payload.postId || payload.commentId;
    const likerName = payload.likerName || 'Someone';
    if (postId) {
      try {
        const { data: existing, error } = await supabase
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .eq('is_read', false)
          .eq('type', type)
          .eq('payload->>postId', postId)
          .order('created_at', { ascending: false })
          .limit(1)
          .maybeSingle();

        if (existing && !error) {
          const likers = existing.payload.likers || [];
          if (!likers.includes(likerName)) {
            likers.push(likerName);
          }
          const count = likers.length;
          let newBody = `${likerName} liked your post`;
          if (count === 2) {
            newBody = `${likers[0]} and ${likers[1]} liked your post`;
          } else if (count > 2) {
            newBody = `${likers[0]} and ${count - 1} others liked your post`;
          }

          const { data: updated, error: updateErr } = await supabase
            .from('notifications')
            .update({
              body: newBody,
              payload: { ...existing.payload, likers },
              push_dispatched: false,
              created_at: new Date().toISOString()
            })
            .eq('id', existing.id)
            .select()
            .single();

          if (!updateErr && updated) {
            return { success: true, notificationId: updated.id };
          }
        } else {
          payload.likers = [likerName];
        }
      } catch (err) {
        console.warn('Like merging check failed:', err);
      }
    }
  }

  // 3. Smart Merging Rule: Voice Room Gifts
  else if (['gift', 'gift_received'].includes(typeLower)) {
    const senderId = payload.senderId;
    if (senderId) {
      try {
        const { data: existing, error } = await supabase
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .eq('is_read', false)
          .eq('type', type)
          .eq('payload->>senderId', senderId)
          .order('created_at', { ascending: false })
          .limit(1)
          .maybeSingle();

        if (existing && !error) {
          const count = (existing.payload.count || 1) + 1;
          const senderName = payload.senderName || 'Someone';
          const newBody = `${senderName} sent you ${count} gifts!`;

          const { data: updated, error: updateErr } = await supabase
            .from('notifications')
            .update({
              body: newBody,
              payload: { ...existing.payload, count },
              push_dispatched: false,
              created_at: new Date().toISOString()
            })
            .eq('id', existing.id)
            .select()
            .single();

          if (!updateErr && updated) {
            return { success: true, notificationId: updated.id };
          }
        }
      } catch (err) {
        console.warn('Gift merging check failed:', err);
      }
    }
  }

  // Default: Insert new notification record
  const { data, error } = await supabase
    .from('notifications')
    .insert({
      user_id: userId,
      title: title,
      body: body,
      type: type,
      payload: payload,
      is_read: false,
      push_dispatched: false
    })
    .select()
    .single();

  if (error) {
    console.error('❌ Failed to insert notification in DB:', error);
    return { success: false, reason: 'db_insert_failed' };
  }
  return { success: true, notificationId: data.id };
}

/**
 * Send notification to multiple users
 */
async function sendNotificationToMultipleUsers(userIds, title, body, type, payload = {}) {
  const promises = userIds.map(userId => sendNotificationToUser(userId, title, body, type, payload));
  const results = await Promise.all(promises);
  return results;
}

/**
 * Send notification to all room members
 */
async function sendNotificationToRoom(roomId, title, body, type, payload = {}) {
  try {
    const { data: members, error } = await supabase
      .from('room_members')
      .select('user_id')
      .eq('room_id', roomId);

    if (error || !members) {
      console.error(`Error loading members for room ${roomId}:`, error);
      return [];
    }

    const userIds = members.map(m => m.user_id);
    const finalPayload = { ...payload, roomId };
    return await sendNotificationToMultipleUsers(userIds, title, body, type, finalPayload);
  } catch (err) {
    console.error('Error in sendNotificationToRoom:', err);
    return [];
  }
}

/**
 * Send notification to all community members
 */
async function sendNotificationToCommunity(communityId, title, body, type, payload = {}) {
  try {
    const { data: memberships, error } = await supabase
      .from('community_memberships')
      .select('user_id')
      .eq('community_id', communityId);

    if (error || !memberships) {
      console.error(`Error loading memberships for community ${communityId}:`, error);
      return [];
    }

    const userIds = memberships.map(m => m.user_id);
    const finalPayload = { ...payload, communityId };
    return await sendNotificationToMultipleUsers(userIds, title, body, type, finalPayload);
  } catch (err) {
    console.error('Error in sendNotificationToCommunity:', err);
    return [];
  }
}

/**
 * Send notification by Topic
 */
async function sendNotificationByTopic(topic, title, body, type, payload = {}) {
  console.log(`📤 Sending topic notification [${topic}]: "${title}"`);

  if (!isFirebaseInitialized) {
    console.log(`[SIMULATION] Send Topic Notification [${topic}]: "${title}"`);
    return { success: true, simulated: true };
  }

  const finalPayload = { ...payload, type, title, body };

  const message = {
    topic: topic,
    notification: {
      title: title,
      body: body
    },
    data: Object.fromEntries(
      Object.entries(finalPayload).map(([key, val]) => [key, typeof val === 'object' ? JSON.stringify(val) : String(val)])
    )
  };

  try {
    await admin.messaging().send(message);
    return { success: true };
  } catch (err) {
    console.error(`Error sending to topic ${topic}:`, err);
    return { success: false, error: err.message };
  }
}

/**
 * Schedule a notification
 */
async function scheduleNotification(userId, title, body, type, payload = {}, scheduledTime) {
  try {
    const { data, error } = await supabase
      .from('scheduled_notifications')
      .insert({
        user_id: userId,
        title: title,
        body: body,
        type: type,
        payload: payload,
        scheduled_for: new Date(scheduledTime).toISOString(),
        status: 'pending'
      })
      .select()
      .single();

    if (error) throw error;
    return { success: true, scheduledId: data.id };
  } catch (err) {
    console.error('Error scheduling notification:', err);
    return { success: false, error: err.message };
  }
}

/**
 * Polling job to process and send scheduled notifications
 */
async function processScheduledNotifications() {
  try {
    const nowStr = new Date().toISOString();
    const { data: pending, error } = await supabase
      .from('scheduled_notifications')
      .select('*')
      .eq('status', 'pending')
      .lte('scheduled_for', nowStr);

    if (error || !pending || pending.length === 0) return;

    console.log(`⏰ Processing ${pending.length} scheduled notifications...`);

    for (const job of pending) {
      try {
        await supabase
          .from('scheduled_notifications')
          .update({ status: 'sent' })
          .eq('id', job.id);

        const result = await sendNotificationToUser(job.user_id, job.title, job.body, job.type, job.payload);
        if (!result.success) {
          await supabase
            .from('scheduled_notifications')
            .update({
              status: job.retry_count >= 3 ? 'failed' : 'pending',
              retry_count: job.retry_count + 1
            })
            .eq('id', job.id);
        }
      } catch (err) {
        console.error(`Error processing scheduled job ${job.id}:`, err);
      }
    }
  } catch (err) {
    console.error('Error in processScheduledNotifications polling:', err);
  }
}

/**
 * Start Supabase Realtime Listener for push notifications
 */
function startRealtimeListener() {
  console.log('📡 Starting Supabase Realtime listener for DB-level push notifications...');
  supabase
    .channel('notification-inserts')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'notifications' }, async (payload) => {
      const record = payload.new;
      if (record && !record.push_dispatched) {
        try {
          await processPushNotification(record);
        } catch (err) {
          console.error('Error processing realtime push notification:', err);
        }
      }
    })
    .subscribe((status) => {
      console.log(`Realtime channel subscription status: ${status}`);
    });
}

module.exports = {
  sendNotificationToUser,
  sendNotificationToMultipleUsers,
  sendNotificationToRoom,
  sendNotificationToCommunity,
  sendNotificationByTopic,
  scheduleNotification,
  processScheduledNotifications,
  startRealtimeListener
};
