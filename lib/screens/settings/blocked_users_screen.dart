import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../widgets/common/optimized_image.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({Key? key}) : super(key: key);

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase.rpc('get_blocked_users');
      if (res != null && res is List) {
        setState(() {
          _blockedUsers = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      } else {
        setState(() {
          _blockedUsers = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[BlockedUsersScreen] Error fetching blocked users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unblockUser(String blockedId, String username) async {
    try {
      final res = await _supabase.rpc('unblock_user', params: {'p_blocked_id': blockedId});
      if (res != null && res['success'] == true) {
        setState(() {
          _blockedUsers.removeWhere((item) => item['blocked_id'] == blockedId);
        });
        Get.snackbar(
          'Unblocked',
          '@$username has been unblocked.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar('Error', res?['error'] ?? 'Failed to unblock user');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to unblock: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Blocked Users',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, index) {
                    final user = _blockedUsers[index];
                    final String blockedId = user['blocked_id'] ?? '';
                    final String username = user['username'] ?? 'User';
                    final String displayName = user['display_name'] ?? username;
                    final String? avatarUrl = user['avatar_url'];
                    final String blockedAtStr = user['blocked_at'] ?? '';
                    DateTime? blockedAt;
                    if (blockedAtStr.isNotEmpty) {
                      blockedAt = DateTime.tryParse(blockedAtStr);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.borderColor, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: context.primaryColor.withOpacity(0.2),
                            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                                ? OptimizedImage.getOptimizedImageProvider(avatarUrl)
                                : null,
                            child: (avatarUrl == null || avatarUrl.isEmpty)
                                ? Icon(Icons.person_rounded, color: context.textSecondary, size: 22)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: context.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '@$username',
                                  style: GoogleFonts.poppins(
                                    color: context.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                if (blockedAt != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Blocked ${DateFormat.yMMMd().format(blockedAt)}',
                                    style: GoogleFonts.poppins(
                                      color: context.caption,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => _unblockUser(blockedId, username),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: context.primaryColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            child: Text(
                              'Unblock',
                              style: GoogleFonts.poppins(
                                color: context.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block_flipped, size: 64, color: context.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No Blocked Users',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Accounts you block will appear here.',
            style: GoogleFonts.poppins(
              color: context.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
