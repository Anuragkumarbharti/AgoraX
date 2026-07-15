import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:creania/core/theme.dart';
import '../../services/community_controller.dart';
import 'community_detail_screen.dart';
import 'create_community_screen.dart';
import '../coming_soon_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({Key? key}) : super(key: key);

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  final _controller = Get.find<CommunityController>();

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(title: 'Communities');
  }

  Widget _buildCommunityTile(BuildContext context, dynamic comm, bool isJoined) {
    final role = _controller.getUserRole(comm);
    final isLogoUnlocked = comm.isLogoUnlocked;

    return GestureDetector(
      onTap: () => Get.to(() => CommunityDetailScreen(communityId: comm.id)),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor, width: 0.5),
        ),
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // Logo
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isJoined
                      ? [context.primaryColor, AppTheme.secondaryColor]
                      : [context.secondaryBackgroundColor, context.borderColor],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  comm.image ?? comm.name.substring(0, 1),
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(width: 16),

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
                        SizedBox(width: 4),
                        Icon(Icons.verified_rounded, color: Color(0xFF60A5FA), size: 14),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${comm.memberCount} members',
                        style: TextStyle(color: context.caption, fontSize: 11),
                      ),
                      SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(color: context.caption, shape: BoxShape.circle),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Lv.${comm.level}',
                        style: TextStyle(color: context.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Badge / Actions
            if (isJoined) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: role == 'Owner'
                      ? Colors.amber.withOpacity(0.15)
                      : context.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: role == 'Owner' ? Colors.amber.withOpacity(0.3) : context.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  role,
                  style: TextStyle(
                    color: role == 'Owner' ? Colors.amber : context.primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 8),
            ],

            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.caption),
          ],
        ),
      ),
    );
  }
}
