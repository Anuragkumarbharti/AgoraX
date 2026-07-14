import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import 'chat_screen.dart';
import '../../models/chat_model.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({Key? key}) : super(key: key);

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final RxString _searchQuery = ''.obs;

  // Realistic mock users
  final List<MockContact> _allContacts = [
    MockContact(name: 'Aisha Khan', username: 'aisha_k', avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120', isOnline: true, isVerified: true, vipLevel: 3),
    MockContact(name: 'Arjun Verma', username: 'arjun_v', avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120', isOnline: true, isVerified: false, vipLevel: 0),
    MockContact(name: 'Bhavna Sharma', username: 'bhavna_s', avatar: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=120', isOnline: false, isVerified: true, vipLevel: 1),
    MockContact(name: 'Chirag Sen', username: 'chirag_sen', avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=120', isOnline: true, isVerified: false, vipLevel: 4),
    MockContact(name: 'Devika Nair', username: 'devika_n', avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120', isOnline: true, isVerified: true, vipLevel: 5),
    MockContact(name: 'Kabir Malhotra', username: 'kabir_m', avatar: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=120', isOnline: true, isVerified: false, vipLevel: 2),
    MockContact(name: 'Mehak Sharma', username: 'mehak_s', avatar: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=120', isOnline: true, isVerified: true, vipLevel: 0),
    MockContact(name: 'Pranav Joshi', username: 'pranav_j', avatar: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=120', isOnline: false, isVerified: false, vipLevel: 1),
    MockContact(name: 'Riya Singh', username: 'riya_s', avatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=120', isOnline: true, isVerified: true, vipLevel: 3),
    MockContact(name: 'Vivek Raj', username: 'vivek_r', avatar: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=120', isOnline: true, isVerified: false, vipLevel: 0),
    MockContact(name: 'Zoya Qureshi', username: 'zoya_q', avatar: 'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=120', isOnline: true, isVerified: true, vipLevel: 5),
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      _searchQuery.value = _searchCtrl.text;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MockContact> get _filteredContacts {
    final query = _searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return _allContacts;
    return _allContacts.where((c) {
      return c.name.toLowerCase().contains(query) || c.username.toLowerCase().contains(query);
    }).toList();
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
    final list = _filteredContacts;
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
    // Group categories
    final recents = _allContacts.take(4).toList();
    final online = _allContacts.where((c) => c.isOnline).toList();
    final suggested = _allContacts.where((c) => c.vipLevel >= 3).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // Recent Contacts Horizontal List
        _buildSectionHeader('Recent Contacts'),
        _buildHorizontalUserRow(recents),

        // Online Friends Horizontal List
        _buildSectionHeader('Online Friends'),
        _buildHorizontalUserRow(online),

        // Suggested Users
        _buildSectionHeader('Suggested Creators'),
        ...suggested.map((c) => _contactTile(c)),

        // Alphabetical list header
        _buildSectionHeader('All Contacts (A-Z)'),
        ..._allContacts.map((c) => _contactTile(c)),

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

  Widget _buildHorizontalUserRow(List<MockContact> users) {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: users.length,
        itemBuilder: (context, idx) {
          final u = users[idx];
          return GestureDetector(
            onTap: () => _openPrivateChat(u),
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
                            color: u.vipLevel > 0 ? AppTheme.accentColor : Colors.transparent,
                            width: u.vipLevel > 0 ? 1.5 : 0,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundImage: NetworkImage(u.avatar),
                        ),
                      ),
                      if (u.isOnline)
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
                    u.name.split(' ').first,
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

  Widget _contactTile(MockContact contact) {
    return ListTile(
      onTap: () => _openPrivateChat(contact),
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
              backgroundImage: NetworkImage(contact.avatar),
            ),
          ),
          if (contact.isOnline)
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
            contact.name,
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

  void _openPrivateChat(MockContact contact) {
    // Generate a dummy conversation object
    final conv = Conversation(
      id: 'conv_${contact.username}',
      otherUserId: contact.username,
      otherUserName: contact.name,
      otherUserAvatar: contact.avatar,
      otherUserOnline: contact.isOnline,
      isVerified: contact.isVerified,
      lastMessage: 'Let\'s start talking!',
      lastMessageTime: DateTime.now(),
      unreadCount: 0,
      isPinned: false,
      isMuted: false,
      levelTitle: 'VIP ${contact.vipLevel}',
      level: contact.vipLevel,
      lastMessageSenderId: 'me',
    );
    Get.to(() => ChatScreen(conversation: conv));
  }
}

class MockContact {
  final String name;
  final String username;
  final String avatar;
  final bool isOnline;
  final bool isVerified;
  final int vipLevel;

  MockContact({
    required this.name,
    required this.username,
    required this.avatar,
    required this.isOnline,
    required this.isVerified,
    required this.vipLevel,
  });
}
