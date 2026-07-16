import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import '../../services/community_controller.dart';
import '../../models/community_model.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({Key? key}) : super(key: key);

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  final _controller = Get.find<CommunityController>();

  final List<Map<String, String>> _comingSoonCategories = [
    {'name': 'Coding & Development', 'icon': '💻'},
    {'name': 'AI & Robotics', 'icon': '🤖'},
    {'name': 'Business & Startup', 'icon': '🚀'},
    {'name': 'Creative Arts', 'icon': '🎨'},
    {'name': 'UPSC & Exams', 'icon': '📚'},
    {'name': 'Sports & Fitness', 'icon': '⚽'},
    {'name': 'Design & UX', 'icon': '📐'},
    {'name': 'Language Learning', 'icon': '🗣️'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF11131C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Communities',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Official Communities Section
            Text(
              'Official Communities',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Obx(() {
              final officialComms = _controller.communities
                  .where((c) => c.type == 'Official')
                  .toList();

              if (officialComms.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: officialComms.length,
                itemBuilder: (context, index) {
                  return _buildOfficialCommunityRowCard(context, officialComms[index], _controller);
                },
              );
            }),

            const SizedBox(height: 28),

            // Other Categories Section
            Text(
              'Other Categories',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
              ),
              itemCount: _comingSoonCategories.length,
              itemBuilder: (context, index) {
                final cat = _comingSoonCategories[index];
                return _buildComingSoonCard(context, cat['name']!, cat['icon']!);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficialCommunityRowCard(BuildContext context, Community comm, CommunityController ctrl) {
    final isJoined = comm.members.contains(CommunityController.currentUserId);

    String tag = '';
    if (comm.id == 'comm-connect-005') {
      tag = 'Connect';
    } else if (comm.id == 'comm-creators-002') {
      tag = 'Studio';
    } else if (comm.id == 'comm-gamers-003') {
      tag = 'ArenaX';
    } else if (comm.id == 'comm-campus-004') {
      tag = 'Campus';
    } else if (comm.id == 'comm-official-001') {
      tag = 'Origin';
    } else {
      tag = comm.category;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Image
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: comm.banner ?? 'https://images.unsplash.com/photo-1579546929518-9e396f3cc809',
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.white10),
                  errorWidget: (context, url, error) => Container(color: Colors.white10),
                ),
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, const Color(0xFF1E293B).withOpacity(0.8), const Color(0xFF1E293B)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // Floating Avatar/Emoji
                Positioned(
                  bottom: 8,
                  left: 16,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1E293B), width: 3),
                    ),
                    child: Center(
                      child: Text(
                        comm.image ?? comm.name.substring(0, 1),
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                ),
                // Tag Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tag,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content Area
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        comm.name,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified,
                        color: Color(0xFF60A5FA),
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    comm.description,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${comm.memberCount} members',
                        style: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(
                        height: 32,
                        width: 100,
                        child: ElevatedButton(
                          onPressed: () {
                            if (isJoined) {
                              ctrl.leaveCommunity(comm.id);
                            } else {
                              ctrl.joinCommunity(comm.id);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isJoined ? Colors.transparent : const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isJoined ? Colors.white24 : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            isJoined ? 'Joined' : 'Join',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComingSoonCard(BuildContext context, String title, String icon) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Coming Soon',
                  style: GoogleFonts.poppins(
                    color: Colors.white38,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 24,
                child: ElevatedButton(
                  onPressed: null, // Disabled
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.04),
                    disabledBackgroundColor: Colors.white.withOpacity(0.02),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    'Join',
                    style: GoogleFonts.poppins(
                      color: Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
