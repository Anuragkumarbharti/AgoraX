import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../services/storage/fcm_notification_service.dart';
import '../../services/user/user_profile_cache_manager.dart';
import '../../widgets/skeletons/notification_skeleton_widget.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({Key? key}) : super(key: key);

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshNotifications();
  }

  Future<void> _refreshNotifications() async {
    setState(() => _isLoading = true);
    await FCMNotificationService.to.loadNotifications(refresh: true);
    await FCMNotificationService.to.markAllAsRead();
    setState(() => _isLoading = false);
  }


  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'chat':
      case 'personal_message':
      case 'group_message':
        return Icons.chat_bubble_outline_rounded;
      case 'voice_room':
      case 'room':
      case 'room_invitation':
        return Icons.spatial_audio_off_rounded;
      case 'community':
      case 'new_post':
        return Icons.people_outline_rounded;
      case 'wallet':
      case 'coins_received':
      case 'recharge_success':
        return Icons.account_balance_wallet_outlined;
      case 'quiz':
      case 'quiz_started':
        return Icons.quiz_outlined;
      case 'system':
      case 'security_alert':
        return Icons.security_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'chat':
      case 'personal_message':
      case 'group_message':
        return AppTheme.primaryColor;
      case 'voice_room':
      case 'room':
      case 'room_invitation':
        return Colors.purpleAccent;
      case 'community':
      case 'new_post':
        return Colors.greenAccent;
      case 'wallet':
      case 'coins_received':
        return Colors.amberAccent;
      case 'quiz':
      case 'quiz_started':
        return Colors.tealAccent;
      case 'system':
      case 'security_alert':
        return Colors.redAccent;
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A10) : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Get.back(),
        ),
        actions: [
          Obx(() {
            final list = FCMNotificationService.to.notificationsList;
            if (list.isEmpty) return const SizedBox.shrink();
            final bool hasUnread = list.any((n) => !(n['is_read'] == true || n['read'] == true));
            return PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white : Colors.black87),
              onSelected: (val) async {
                if (val == 'read_all') {
                  await FCMNotificationService.to.markAllAsRead();
                  Get.snackbar('Success', 'All notifications marked as read',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.black.withOpacity(0.85),
                      colorText: Colors.white);
                } else if (val == 'clear_all') {
                  await FCMNotificationService.to.clearAllNotifications();
                  Get.snackbar('Cleared', 'All notifications cleared',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.black.withOpacity(0.85),
                      colorText: Colors.white);
                }
              },
              itemBuilder: (context) => [
                if (hasUnread)
                  const PopupMenuItem(
                    value: 'read_all',
                    child: Row(
                      children: [
                        Icon(Icons.done_all_rounded, size: 20, color: Colors.blueAccent),
                        SizedBox(width: 8),
                        Text('Mark all read'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_rounded, size: 20, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Clear all'),
                    ],
                  ),
                ),
              ],
            );
          })
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNotifications,
        color: AppTheme.primaryColor,
        backgroundColor: const Color(0xFF161622),
        child: Obx(() {
          final rawList = FCMNotificationService.to.notificationsList;
          final list = rawList.where((n) {
            final t = n['type']?.toString().toLowerCase() ?? '';
            return t != 'chat' && t != 'personal_message';
          }).toList();

          if (_isLoading && list.isEmpty) {
            return const NotificationSkeletonWidget();
          }

          if (list.isEmpty) {
            return _buildEmptyState(isDark);
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              final bool isRead = (item['is_read'] == true) || (item['read'] == true);
              final type = item['type'] ?? 'system';
              final createdAt = item['created_at'] != null
                  ? DateTime.parse(item['created_at']).toLocal()
                  : DateTime.now();

              return Dismissible(
                key: Key(item['id'].toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20.0),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                ),
                onDismissed: (_) => FCMNotificationService.to.deleteNotification(item['id'].toString()),
                child: GestureDetector(
                  onTap: () {
                    if (!isRead) {
                      FCMNotificationService.to.markAsRead(item['id'].toString());
                    }
                    final payload = item['payload'] != null
                        ? Map<String, dynamic>.from(item['payload'])
                        : <String, dynamic>{};
                    payload['type'] = type;
                    payload['notificationId'] = item['id'].toString();
                    FCMNotificationService.to.handleNotificationDeepLink(payload);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? (isRead ? const Color(0xFF12121E) : const Color(0xFF1C1C2E))
                          : (isRead ? Colors.white : Colors.blue[50]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? (isRead ? Colors.white10 : AppTheme.primaryColor.withOpacity(0.3))
                            : Colors.transparent,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getColorForType(type).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIconForType(type),
                          color: _getColorForType(type),
                          size: 24,
                        ),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                if (!isRead) ...[
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                                Expanded(
                                  child: Text(
                                    item['title'] ?? 'Notification',
                                    style: GoogleFonts.outfit(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    semanticsLabel: 'Notification Title',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(createdAt),
                            style: GoogleFonts.outfit(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          item['body'] ?? '',
                          style: GoogleFonts.outfit(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 13,
                            fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: Get.height * 0.2),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.blueGrey[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_off_outlined,
                  size: 64,
                  color: isDark ? Colors.white38 : Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'All caught up!',
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No new notifications to display.',
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white38 : Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('dd MMM').format(time);
    }
  }
}
