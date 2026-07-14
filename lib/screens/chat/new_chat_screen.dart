import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../core/theme.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_controller.dart';
import '../../services/user_profile_cache_manager.dart';
import 'chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({Key? key}) : super(key: key);

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final RxString _searchQuery = ''.obs;
  final RxList<User> _realContacts = <User>[].obs;
  final RxList<User> _searchResultsList = <User>[].obs;
  final RxBool _isLoading = false.obs;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _fetchRealProfiles();
    _searchCtrl.addListener(() {
      _searchQuery.value = _searchCtrl.text;
      _searchProfilesFromSupabase(_searchCtrl.text);
    });
  }

  void _fetchRealProfiles() async {
    _isLoading.value = true;
    try {
      final currentUid = UserProfileCacheManager.currentUserId;
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .limit(50);
      
      final List<User> loaded = [];
      if (response != null) {
        for (final item in response) {
          final uObj = User.fromJson(item);
          if (uObj.id != currentUid) {
            loaded.add(uObj);
          }
        }
      }
      _realContacts.assignAll(loaded);
    } catch (e) {
      debugPrint('Error fetching real profiles: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  void _searchProfilesFromSupabase(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final cleanQuery = query.trim();
      if (cleanQuery.isEmpty) {
        _searchResultsList.clear();
        return;
      }
      try {
        final currentUid = UserProfileCacheManager.currentUserId;
        var queryBuilder = Supabase.instance.client.from('profiles').select();
        
        final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(cleanQuery);
        if (isUuid) {
          queryBuilder = queryBuilder.eq('id', cleanQuery);
        } else {
          queryBuilder = queryBuilder.ilike('username', '%$cleanQuery%');
        }

        final response = await queryBuilder.limit(20);
        final List<User> loaded = [];
        if (response != null) {
          for (final item in response) {
            final uObj = User.fromJson(item);
            if (uObj.id != currentUid) {
              loaded.add(uObj);
            }
          }
        }
        _searchResultsList.assignAll(loaded);
      } catch (e) {
        debugPrint('Error searching profiles: $e');
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgLight,
        elevation: 0,
        title: Text(
          'New Chat',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
          onPressed: () => Get.back(),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: Obx(() {
              if (_isLoading.value) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
              }
              final query = _searchQuery.value;
              if (query.isNotEmpty) {
                return _buildSearchResults();
              }
              return _buildMainContent();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.bgLight.withOpacity(0.5),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search_rounded, color: AppTheme.textTertiary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by name or username...',
                  hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_searchCtrl.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, color: AppTheme.textTertiary, size: 16),
                onPressed: () => _searchCtrl.clear(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final list = _searchResultsList;
    if (list.isEmpty) {
      return Center(
        child: Text(
          'No contacts found matching "${_searchQuery.value}"',
          style: GoogleFonts.outfit(color: AppTheme.textTertiary, fontSize: 14),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, idx) => _contactTile(list[idx]),
    );
  }

  Widget _buildMainContent() {
    // 1. Recent Contacts: Only users actually chatted with (from ChatController.to.conversations)
    final recents = ChatController.to.conversations.take(4).toList();
    
    // 2. Online Friends: Filter from real active chat list where online status is true
    final online = ChatController.to.conversations.where((c) => c.otherUserOnline).toList();
    
    // 3. Suggested Creators: Real high-level/vip users returned by backend
    final suggested = _realContacts.where((u) => u.vipLevel > 0 || u.level > 1).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // Recent Contacts Horizontal List
        if (recents.isNotEmpty) ...[
          _buildSectionHeader('Recent Contacts'),
          _buildHorizontalConversationRow(recents),
        ],

        // Online Friends Horizontal List
        if (online.isNotEmpty) ...[
          _buildSectionHeader('Online Friends'),
          _buildHorizontalConversationRow(online),
        ],

        // Suggested Users
        if (suggested.isNotEmpty) ...[
          _buildSectionHeader('Suggested Creators'),
          ...suggested.map((u) => _contactTile(u)),
        ],

        // Alphabetical list header
        if (_realContacts.isNotEmpty) ...[
          _buildSectionHeader('All Contacts (A-Z)'),
          ..._realContacts.map((u) => _contactTile(u)),
        ],

        // Clean Empty State if no real contacts exist
        if (_realContacts.isEmpty && recents.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 80.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline_rounded, size: 48, color: AppTheme.textTertiary.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Text(
                    'No contacts found',
                    style: GoogleFonts.outfit(color: AppTheme.textTertiary, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              color: AppTheme.primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            'See All',
            style: GoogleFonts.outfit(
              color: AppTheme.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalConversationRow(List<Conversation> convs) {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: convs.length,
        itemBuilder: (context, idx) {
          final c = convs[idx];
          return GestureDetector(
            onTap: () => _openPrivateChat(c),
            child: Container(
              width: 72,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c.level > 0 ? AppTheme.accentColor : Colors.transparent,
                            width: c.level > 0 ? 1.5 : 0,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundImage: NetworkImage(c.otherUserAvatar),
                        ),
                      ),
                      if (c.otherUserOnline)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppTheme.successColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.bgDark, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.otherUserName.split(' ').first,
                    style: GoogleFonts.outfit(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _contactTile(User contact) {
    return ListTile(
      onTap: () => _openPrivateChatForUser(contact),
      leading: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: contact.vipLevel > 0 ? AppTheme.accentColor : Colors.transparent,
                width: contact.vipLevel > 0 ? 1.5 : 0,
              ),
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundImage: NetworkImage(contact.avatar ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150'),
            ),
          ),
          if (contact.onlineStatus)
            Positioned(
              bottom: 1,
              right: 1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.successColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.bgDark, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Text(
            contact.displayName,
            style: GoogleFonts.outfit(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          if (contact.isVerified) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified_rounded, color: Color(0xFF60A5FA), size: 14),
          ],
          if (contact.vipLevel > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.accentColor, width: 0.5),
              ),
              child: Text(
                'VIP ${contact.vipLevel}',
                style: GoogleFonts.outfit(
                  color: AppTheme.accentColor,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        '@${contact.username}',
        style: GoogleFonts.outfit(
          color: AppTheme.textTertiary,
          fontSize: 13,
        ),
      ),
      trailing: const Icon(
        Icons.chat_bubble_outline_rounded,
        color: AppTheme.primaryColor,
        size: 18,
      ),
    );
  }

  void _openPrivateChat(Conversation conv) {
    Get.to(() => ChatScreen(conversation: conv));
  }

  void _openPrivateChatForUser(User u) {
    final conv = Conversation(
      id: 'conv_${u.id}',
      otherUserId: u.id,
      otherUserName: u.displayName,
      otherUserAvatar: u.avatar ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
      otherUserOnline: u.onlineStatus,
      isVerified: u.isVerified,
      lastMessage: '',
      lastMessageTime: DateTime.now(),
      unreadCount: 0,
      isPinned: false,
      isMuted: false,
      levelTitle: 'VIP ${u.vipLevel}',
      level: u.vipLevel,
      lastMessageSenderId: 'me',
    );
    Get.to(() => ChatScreen(conversation: conv));
  }
}
