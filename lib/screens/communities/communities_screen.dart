import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../services/community_controller.dart';
import 'community_detail_screen.dart';
import 'create_community_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({Key? key}) : super(key: key);

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  final _controller = Get.find<CommunityController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(
          'Communities',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 28),
            onPressed: () => Get.to(() => const CreateCommunityScreen()),
          ),
        ],
      ),
      body: Obx(() {
        final myCommunities = _controller.communities.where((c) {
          return c.members.contains(CommunityController.currentUserId);
        }).toList();

        final otherCommunities = _controller.communities.where((c) {
          return !c.members.contains(CommunityController.currentUserId);
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // User coins widget
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.bgLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Your Coins',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Text(
                    '${_controller.userCoins.value}',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            if (myCommunities.isNotEmpty) ...[
              Text(
                'My Families',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...myCommunities.map((comm) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildCommunityTile(context, comm, true),
                  )),
              const SizedBox(height: 16),
            ],

            if (otherCommunities.isNotEmpty) ...[
              Text(
                'Explore Families',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...otherCommunities.map((comm) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildCommunityTile(context, comm, false),
                  )),
            ],
          ],
        );
      }),
    );
  }

  Widget _buildCommunityTile(BuildContext context, dynamic comm, bool isJoined) {
    final role = _controller.getUserRole(comm);
    final isLogoUnlocked = comm.isLogoUnlocked;

    return GestureDetector(
      onTap: () => Get.to(() => CommunityDetailScreen(communityId: comm.id)),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor, width: 0.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Logo
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isJoined
                      ? [AppTheme.primaryColor, AppTheme.secondaryColor]
                      : [AppTheme.bgLight, AppTheme.borderColor],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  comm.image ?? comm.name.substring(0, 1),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          comm.name,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (comm.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, color: Color(0xFF60A5FA), size: 14),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${comm.memberCount} members',
                        style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(color: AppTheme.textTertiary, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Lv.${comm.level}',
                        style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Badge / Actions
            if (isJoined) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: role == 'Owner'
                      ? Colors.amber.withOpacity(0.15)
                      : AppTheme.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: role == 'Owner' ? Colors.amber.withOpacity(0.3) : AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  role,
                  style: TextStyle(
                    color: role == 'Owner' ? Colors.amber : AppTheme.primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],

            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}
