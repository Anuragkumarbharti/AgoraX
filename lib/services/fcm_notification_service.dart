import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/user_model.dart';
import '../services/user_profile_cache_manager.dart';
import '../screens/chat/chat_screen.dart';
import '../services/chat_controller.dart';
import '../services/room_controller.dart';
import '../screens/rooms/voice_room_call_screen.dart';
import '../screens/communities/community_detail_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../widgets/gift_history_bottom_sheet.dart';
import '../screens/events/wallet_screen.dart';
import '../screens/profile/mcq_quiz_screen.dart';
import '../screens/notifications/notification_history_screen.dart';
import '../utils/secure_dto_sanitizer.dart';

class FCMNotificationService extends GetxService {
  static FCMNotificationService get to => Get.find<FCMNotificationService>();

  final _supabase = Supabase.instance.client;
  final RxInt unreadCount = 0.obs;
  
  // Shared Realtime notifications list for history binding
  final RxList<Map<String, dynamic>> notificationsList = <Map<String, dynamic>>[].obs;
  RealtimeChannel? _realtimeChannel;

  // Persistent Local Deletion Cache
  static const String _keyLocallyDeletedIds = 'loc_deleted_notif_ids';
  static const String _keyLastClearedTime = 'loc_last_cleared_notif_time';
  final Set<String> _locallyDeletedIds = {};
  DateTime? _lastClearedTimestamp;

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _firebaseActive = false;

  Future<void> _loadLocalDeletionCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyLocallyDeletedIds) ?? [];
      _locallyDeletedIds.clear();
      _locallyDeletedIds.addAll(list);

      final timeStr = prefs.getString(_keyLastClearedTime);
      if (timeStr != null) {
        _lastClearedTimestamp = DateTime.tryParse(timeStr);
      }
    } catch (_) {}
  }

  Future<void> _saveLocalDeletionCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyLocallyDeletedIds, _locallyDeletedIds.toList());
      if (_lastClearedTimestamp != null) {
        await prefs.setString(_keyLastClearedTime, _lastClearedTimestamp!.toIso8601String());
      }
    } catch (_) {}
  }

  Future<FCMNotificationService> init() async {
    try {
      // 0. Initialize Local Notifications for top status bar push notifications (WhatsApp/Instagram style)
      try {
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const DarwinInitializationSettings initializationSettingsDarwin =
            DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
        const InitializationSettings initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );
        await _localNotificationsPlugin.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) {
            if (response.payload != null && response.payload!.isNotEmpty) {
              try {
                final Map<String, dynamic> data = jsonDecode(response.payload!);
                handleNotificationDeepLink(data);
              } catch (e) {
                debugPrint('Error parsing notification payload: $e');
              }
            }
          },
        );

        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'creania_high_importance_channel',
          'Creania Notifications',
          description: 'This channel is used for important app notifications.',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );

        await _localNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);

        debugPrint('🔔 Flutter Local Notifications & High Importance Channel initialized successfully.');
      } catch (lne) {
        debugPrint('⚠️ Local notifications plugin initialization bypassed/failed: $lne');
      }

      // 1. Initialize Firebase gracefully
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp();
        }
        _firebaseActive = true;
        debugPrint('🔥 Firebase Core initialized successfully in FCMNotificationService.');
      } catch (fe) {
        debugPrint('⚠️ Firebase Core initialization bypassed/failed (normal if config is missing): $fe');
        _firebaseActive = false;
      }

      if (_firebaseActive) {
        // 2. Request permissions on first launch
        await _requestPermissionOnFirstLaunch();

        // 3. Setup token generation & updates
        await setupFCMToken();

        // 4. Setup foreground message handler
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          _handleForegroundMessage(message);
        });

        // 5. Setup background message handlers
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          handleNotificationDeepLink(message.data);
        });

        FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
          if (message != null) {
            Future.delayed(const Duration(milliseconds: 1200), () {
              handleNotificationDeepLink(message.data);
            });
          }
        });
      }

      // 6. Monitor Auth state to link/unlink tokens and start Realtime subscription
      _supabase.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        if (event == AuthChangeEvent.signedIn) {
          if (_firebaseActive) {
            syncTokenToSupabase();
          }
          startRealtimeSubscription();
          loadNotifications();
        } else if (event == AuthChangeEvent.signedOut) {
          if (_firebaseActive) {
            removeTokenFromSupabase();
          }
          stopRealtimeSubscription();
          notificationsList.clear();
          unreadCount.value = 0;
          try {
            _localNotificationsPlugin.cancelAll();
          } catch (_) {}
        }
      });


      await _loadLocalDeletionCache();

      // Fetch initial unread count & start realtime if already logged in
      if (_supabase.auth.currentSession != null) {
        startRealtimeSubscription();
        loadNotifications();
      }
    } catch (e) {
      debugPrint('❌ Error initializing FCMNotificationService: $e');
    }
    return this;
  }

  void startRealtimeSubscription() {
    final userId = UserProfileCacheManager.currentUserId;
    if (userId.isEmpty) return;

    // Clear previous subscription
    stopRealtimeSubscription();

    debugPrint('📡 Subscribing globally to notifications table Realtime updates for User: $userId');
    _realtimeChannel = _supabase
        .channel('global:notifications:user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final eventType = payload.eventType;
            
            if (eventType == PostgresChangeEvent.insert) {
              final newNotif = Map<String, dynamic>.from(payload.newRecord);
              final notifId = newNotif['id']?.toString() ?? '';
              final notifType = newNotif['type']?.toString().toLowerCase() ?? '';
              final isDeleted = newNotif['is_deleted'] == true;
              final createdAtStr = newNotif['created_at']?.toString();
              final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

              // Exclude deleted notifications
              if (isDeleted || _locallyDeletedIds.contains(notifId)) return;
              if (_lastClearedTimestamp != null && createdAt != null && createdAt.isBefore(_lastClearedTimestamp!)) return;

              // Chat/message notifications should NEVER appear in system notification history
              if (notifType == 'chat' || notifType == 'personal_message' || notifType == 'group_message' || notifType == 'message' || notifType == 'dm') {
                _showForegroundBanner(newNotif);
                return;
              }

              // Deduplicate in memory
              final isDup = notificationsList.any((n) {
                if (n['id']?.toString() == notifId) return true;
                if (newNotif['event_id'] != null && n['event_id']?.toString() == newNotif['event_id']?.toString()) return true;
                return n['title'] == newNotif['title'] && n['body'] == newNotif['body'];
              });

              if (!isDup) {
                final clean = SecureDtoSanitizer.sanitizeNotificationMap(newNotif);
                notificationsList.insert(0, clean);
                if (clean['is_read'] != true && clean['read'] != true) {
                  unreadCount.value++;
                }
                debugPrint('[REALTIME LOG] UI Updated -> Badge Updated: New count = ${unreadCount.value}');
                _showForegroundBanner(clean);
              }
            } else if (eventType == PostgresChangeEvent.update) {
              final updatedNotif = Map<String, dynamic>.from(payload.newRecord);
              final notifId = updatedNotif['id']?.toString() ?? '';
              final isDeleted = updatedNotif['is_deleted'] == true;

              if (isDeleted || _locallyDeletedIds.contains(notifId)) {
                notificationsList.removeWhere((n) => n['id']?.toString() == notifId);
                notificationsList.refresh();
                fetchUnreadCount();
                return;
              }

              final index = notificationsList.indexWhere((n) => n['id']?.toString() == notifId);
              if (index != -1) {
                notificationsList[index] = SecureDtoSanitizer.sanitizeNotificationMap(updatedNotif);
                notificationsList.refresh();
              }
              fetchUnreadCount();
            } else if (eventType == PostgresChangeEvent.delete) {
              final deletedId = payload.oldRecord['id']?.toString();
              if (deletedId != null) {
                _locallyDeletedIds.add(deletedId);
                _saveLocalDeletionCache();
                notificationsList.removeWhere((n) => n['id']?.toString() == deletedId);
                notificationsList.refresh();
                fetchUnreadCount();
              }
            }
          },
        );
    _realtimeChannel?.subscribe();
  }

  void stopRealtimeSubscription() {
    if (_realtimeChannel != null) {
      _supabase.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
      debugPrint('📡 Unsubscribed global notifications Realtime channel.');
    }
  }

  Future<void> loadNotifications({bool refresh = false}) async {
    final userId = UserProfileCacheManager.currentUserId;
    if (userId.isEmpty) return;

    await _loadLocalDeletionCache();

    if (refresh) {
      notificationsList.clear();
    }

    try {
      final response = await _supabase
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100);

      final List<dynamic> rawData = response as List<dynamic>;
      final List<Map<String, dynamic>> filteredList = [];
      final Set<String> seenKeys = {};

      for (var raw in rawData) {
        final item = Map<String, dynamic>.from(raw);
        final notifId = item['id']?.toString() ?? '';
        final type = item['type']?.toString().toLowerCase() ?? '';
        final isDeleted = item['is_deleted'] == true;
        final createdAtStr = item['created_at']?.toString();
        final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

        // 1. Exclude deleted notifications
        if (isDeleted || _locallyDeletedIds.contains(notifId)) continue;
        if (_lastClearedTimestamp != null && createdAt != null && createdAt.isBefore(_lastClearedTimestamp!)) continue;

        // 2. Exclude chat/message types completely
        if (type == 'chat' || type == 'personal_message' || type == 'group_message' || type == 'message' || type == 'dm') continue;

        // 3. Deduplicate
        final dedupeKey = item['event_id']?.toString() ?? '${item['title']}_${item['body']}';
        if (seenKeys.contains(dedupeKey)) continue;
        seenKeys.add(dedupeKey);

        filteredList.add(SecureDtoSanitizer.sanitizeNotificationMap(item));
      }

      notificationsList.assignAll(filteredList);
      unreadCount.value = notificationsList.where((n) => !(n['is_read'] == true || n['read'] == true)).length;
      debugPrint('[REALTIME LOG] Load Notifications History -> Loaded ${notificationsList.length} items, Unread count = ${unreadCount.value}');
    } catch (e) {
      debugPrint('Error loading notifications in service: $e');
    }
  }

  Future<void> markAsRead(String notifId) async {
    if (notifId.isEmpty) return;
    try {
      final index = notificationsList.indexWhere((n) => n['id']?.toString() == notifId.toString());
      if (index != -1) {
        notificationsList[index]['is_read'] = true;
        notificationsList[index]['read'] = true;
        notificationsList.refresh();
      }

      unreadCount.value = notificationsList.where((n) => !(n['is_read'] == true || n['read'] == true)).length;

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notifId);

      await fetchUnreadCount();

      debugPrint('[REALTIME LOG] Notification Marked Read: $notifId -> UI Updated -> Badge Updated');
    } catch (e) {
      debugPrint('Error marking notification read: $e');
    }
  }

  Future<void> deleteNotification(String notifId) async {
    try {
      _locallyDeletedIds.add(notifId);
      await _saveLocalDeletionCache();

      notificationsList.removeWhere((n) => n['id']?.toString() == notifId.toString());
      notificationsList.refresh();
      unreadCount.value = notificationsList.where((n) => !(n['is_read'] ?? n['read'] ?? false)).length;

      // Soft delete + Hard delete in DB
      try {
        await _supabase.rpc('delete_single_notification', params: {
          'p_user_id': UserProfileCacheManager.currentUserId,
          'p_notif_id': notifId,
        });
      } catch (_) {
        await _supabase.from('notifications').update({'is_deleted': true, 'is_read': true}).eq('id', notifId);
        await _supabase.from('notifications').delete().eq('id', notifId);
      }

      debugPrint('[REALTIME LOG] Notification Permanently Deleted: $notifId -> UI Updated -> Badge Updated');
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> clearAllNotifications() async {
    final userId = UserProfileCacheManager.currentUserId;
    if (userId.isEmpty) return;

    try {
      _lastClearedTimestamp = DateTime.now();
      for (var n in notificationsList) {
        final id = n['id']?.toString();
        if (id != null) _locallyDeletedIds.add(id);
      }
      await _saveLocalDeletionCache();

      notificationsList.clear();
      unreadCount.value = 0;

      // Soft delete + Hard delete in DB via RPC and direct queries
      try {
        await _supabase.rpc('clear_all_user_notifications', params: {'p_user_id': userId});
      } catch (_) {
        await _supabase.from('notifications').update({'is_deleted': true, 'is_read': true}).eq('user_id', userId);
        await _supabase.from('notifications').delete().eq('user_id', userId);
      }

      debugPrint('[REALTIME LOG] All Notifications Cleared -> Persistent Cache Updated -> Badge Zeroed');
    } catch (e) {
      notificationsList.clear();
      unreadCount.value = 0;
      debugPrint('Error clearing all notifications: $e');
    }
  }

  Future<void> sendNotification({
    required String targetUserId,
    required String title,
    required String body,
    required String type,
    String? eventId,
    Map<String, dynamic>? payload,
  }) async {
    try {
      // Exclude chat message insertion
      if (type.toLowerCase() == 'chat' || type.toLowerCase() == 'personal_message' || type.toLowerCase() == 'message') {
        return;
      }

      await _supabase.from('notifications').insert({
        'user_id': targetUserId,
        'title': title,
        'body': body,
        'type': type,
        'event_id': eventId,
        'payload': payload ?? {},
        'is_read': false,
        'is_deleted': false,
        'push_dispatched': false,
      });
      debugPrint('[REALTIME LOG] Notification Created -> Database Inserted: for $targetUserId');
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  Future<void> _requestPermissionOnFirstLaunch() async {
    if (!_firebaseActive) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPermissionRequested = prefs.getBool('fcm_permission_requested') ?? false;

      if (!isPermissionRequested) {
        final status = await Permission.notification.request();
        await prefs.setBool('fcm_permission_requested', true);
        debugPrint('** Notification permission requested on first launch: $status');
      }
    } catch (e) {
      debugPrint('❌ Error requesting fcm permission: $e');
    }
  }

  Future<void> setupFCMToken() async {
    if (!_firebaseActive) return;
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        debugPrint('🔑 FCM Token generated: $token');
        await _saveLocalToken(token);
        if (_supabase.auth.currentSession != null) {
          await syncTokenToSupabase();
        }
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint('🔑 FCM Token refreshed: $newToken');
        await _saveLocalToken(newToken);
        if (_supabase.auth.currentSession != null) {
          await syncTokenToSupabase();
        }
      });
    } catch (e) {
      debugPrint('❌ Error setting up FCM Token: $e');
    }
  }

  Future<void> _saveLocalToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  Future<String?> getLocalToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }

  Future<void> syncTokenToSupabase() async {
    if (!_firebaseActive) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final token = await getLocalToken();
    if (token == null) return;

    try {
      await _supabase.rpc('register_fcm_token', params: {
        'p_user_id': userId,
        'p_token': token,
        'p_device_id': 'flutter_device_${userId.hashCode}', 
        'p_device_type': kIsWeb ? 'web' : (GetPlatform.isAndroid ? 'android' : 'ios'),
      });
      debugPrint('🔑 Synced FCM token to Supabase successfully');
    } catch (e) {
      debugPrint('❌ Error syncing FCM token to Supabase: $e');
    }
  }

  Future<void> removeTokenFromSupabase() async {
    if (!_firebaseActive) return;
    final token = await getLocalToken();
    if (token == null) return;

    try {
      await _supabase.rpc('unregister_fcm_token', params: {
        'p_token': token,
      });
      debugPrint('🔑 Removed FCM token from Supabase successfully');
    } catch (e) {
      debugPrint('❌ Error removing FCM token from Supabase: $e');
    }
  }

  Future<void> showSystemTrayNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'creania_high_importance_channel',
        'Creania Notifications',
        channelDescription: 'This channel is used for important app notifications.',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );
      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      );

      final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      final String? payloadJson = payload != null ? jsonEncode(payload) : null;

      await _localNotificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payloadJson,
      );
      debugPrint('🔔 System tray notification posted: $title');
    } catch (e) {
      debugPrint('❌ Error posting system tray notification: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 Foreground FCM Message received: ${message.messageId}');
    debugPrint('[REALTIME LOG] Event Triggered -> FCM Sent -> Realtime Delivered (FCM)');
    
    final rawTitle = message.notification?.title ?? message.data['title'] ?? 'New Notification';
    final rawBody = message.notification?.body ?? message.data['body'] ?? '';
    final title = SecureDtoSanitizer.sanitizeNotificationTitle(rawTitle, fallback: 'New Notification');
    final body = SecureDtoSanitizer.sanitizeNotificationBody(rawBody, fallback: 'New message received');
    final payload = message.data;

    // Show native system status bar notification (Instagram/WhatsApp style top notification)
    showSystemTrayNotification(
      title: title,
      body: body,
      payload: payload,
    );

    // Show custom SnackBar/banner
    Get.snackbar(
      title,
      body,
      titleText: Text(
        title,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      messageText: Text(
        body,
        style: GoogleFonts.outfit(
          color: Colors.white.withOpacity(0.75),
          fontSize: 12,
        ),
      ),
      icon: const Icon(Icons.notifications_active, color: Colors.amberAccent),
      backgroundColor: const Color(0xDD0F172A), 
      barBlur: 15,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(12),
      borderRadius: 16,
      borderWidth: 1,
      borderColor: Colors.white12,
      boxShadows: const [
        BoxShadow(
          color: Colors.black54,
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
      onTap: (_) {
        handleNotificationDeepLink(payload);
      },
    );

    // Refresh unread count
    fetchUnreadCount();
  }

  void _showForegroundBanner(Map<String, dynamic> notif) {
    final title = SecureDtoSanitizer.sanitizeNotificationTitle(notif['title'], fallback: 'New Notification');
    final body = SecureDtoSanitizer.sanitizeNotificationBody(notif['body'], fallback: 'New message received');
    final payload = Map<String, dynamic>.from(notif['payload'] ?? {});
    final type = notif['type']?.toString();
    payload['type'] = type;
    payload['notificationId'] = notif['id']?.toString();

    // If user is currently actively viewing this chat, suppress toast to avoid clutter
    if (type == 'chat') {
      final senderId = payload['userId']?.toString() ?? payload['senderId']?.toString() ?? '';
      if (senderId.isNotEmpty && Get.currentRoute == '/ChatScreen') {
        fetchUnreadCount();
        return;
      }
    }

    // Show native system status bar notification (Instagram/WhatsApp style top notification)
    showSystemTrayNotification(
      title: title,
      body: body,
      payload: payload,
    );

    // Show foreground toast/snackbar
    Get.snackbar(
      title,
      body,
      titleText: Text(
        title,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      messageText: Text(
        body,
        style: GoogleFonts.outfit(
          color: Colors.white.withOpacity(0.75),
          fontSize: 12,
        ),
      ),
      icon: const Icon(Icons.notifications_active, color: Colors.amberAccent),
      backgroundColor: const Color(0xDD0F172A), 
      barBlur: 15,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(12),
      borderRadius: 16,
      borderWidth: 1,
      borderColor: Colors.white12,
      boxShadows: const [
        BoxShadow(
          color: Colors.black54,
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
      onTap: (_) {
        handleNotificationDeepLink(payload);
      },
    );
  }

  Future<void> fetchUnreadCount() async {
    final userId = UserProfileCacheManager.currentUserId;
    if (userId.isEmpty) return;

    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false)
          .eq('is_deleted', false)
          .neq('type', 'chat')
          .neq('type', 'personal_message')
          .neq('type', 'group_message')
          .neq('type', 'message')
          .neq('type', 'dm');
      
      unreadCount.value = (response as List).length;
    } catch (e) {
      unreadCount.value = notificationsList.where((n) => !(n['is_read'] == true || n['read'] == true)).length;
      debugPrint('❌ Error fetching unread count: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final userId = UserProfileCacheManager.currentUserId;
    if (userId.isEmpty) return;

    try {
      // 1. Immediately update local state & zero unread count so UI badge updates instantly
      for (var n in notificationsList) {
        n['is_read'] = true;
        n['read'] = true;
      }
      notificationsList.refresh();
      unreadCount.value = 0;
      debugPrint('[REALTIME LOG] All Marked Read -> UI Updated Immediately -> Badge Reset');

      // 2. Persist in Database
      try {
        await _supabase.rpc('mark_all_notifications_read', params: {'p_user_id': userId});
      } catch (_) {
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', userId)
            .eq('is_read', false);
      }

      unreadCount.value = 0;
    } catch (e) {
      unreadCount.value = 0;
      debugPrint('❌ Error marking notifications as read: $e');
    }
  }

  void handleNotificationDeepLink(Map<String, dynamic> data) async {
    final type = data['type']?.toString().toLowerCase() ?? '';
    debugPrint('🔗 Deep Link Action Type: $type, Payload: $data');

    final notificationId = data['notificationId']?.toString();
    if (notificationId != null) {
      _logNotificationClick(notificationId);
      markAsRead(notificationId); // auto mark read when clicked
    }

    switch (type) {
      case 'chat':
        final otherUserId = data['userId']?.toString() ?? '';
        if (otherUserId.isNotEmpty) {
          try {
            final otherUser = await UserProfileCacheManager.fetchUserProfile(otherUserId);
            final chatCtrl = Get.find<ChatController>();
            final conversation = chatCtrl.getOrCreateConversation(
              otherUser.id,
              otherUser.displayName,
              otherUser.avatar ?? '',
            );
            Get.to(() => ChatScreen(conversation: conversation));
          } catch (e) {
            Get.snackbar('Error', 'Failed to open chat: $e');
          }
        }
        break;

      case 'room':
      case 'voice_room':
        final roomId = data['roomId']?.toString() ?? '';
        if (roomId.isNotEmpty) {
          try {
            if (Get.isRegistered<RoomController>() && Get.find<RoomController>().activeRoomId == roomId) {
              return;
            }
            final response = await _supabase
                .from('rooms')
                .select()
                .eq('id', roomId)
                .maybeSingle();
            if (response != null) {
              final currentUid = UserProfileCacheManager.currentUserId;
              final currentUsername = UserProfileCacheManager.currentUser?.username ?? 'Creania Student';
              Get.to(() => VoiceRoomCallScreen(
                roomId: roomId,
                roomName: response['name'] ?? 'Arena Room',
                userId: currentUid,
                userName: currentUsername,
                isHost: response['host_id'] == currentUid,
              ));
            } else {
              Get.snackbar('Error', 'Room no longer exists');
            }
          } catch (e) {
            Get.snackbar('Error', 'Failed to join room: $e');
          }
        }
        break;

      case 'community':
        final communityId = data['communityId']?.toString() ?? '';
        if (communityId.isNotEmpty) {
          Get.to(() => CommunityDetailScreen(communityId: communityId));
        }
        break;

      case 'profile':
        final targetUserId = data['userId']?.toString() ?? '';
        if (targetUserId.isNotEmpty) {
          try {
            final targetUser = await UserProfileCacheManager.fetchUserProfile(targetUserId);
            Get.to(() => ProfileScreen(visitorUser: targetUser));
          } catch (e) {
            Get.snackbar('Error', 'Failed to load profile: $e');
          }
        } else {
          Get.to(() => const ProfileScreen());
        }
        break;

      case 'gift':
        final targetUserId = data['userId']?.toString() ?? UserProfileCacheManager.currentUserId;
        if (targetUserId.isNotEmpty) {
          GiftHistoryBottomSheet.show(Get.context!, targetUserId, true);
        }
        break;

      case 'wallet':
        Get.to(() => const WalletScreen());
        break;

      case 'quiz':
        Get.to(() => const MCQQuizScreen());
        break;

      case 'system':
      default:
        Get.to(() => const NotificationHistoryScreen());
        break;
    }
  }

  Future<void> _logNotificationClick(String notificationId) async {
    try {
      await _supabase
          .from('notification_logs')
          .update({
            'status': 'clicked',
            'clicked_at': DateTime.now().toIso8601String(),
          })
          .eq('notification_id', notificationId);
    } catch (_) {}
  }
}
