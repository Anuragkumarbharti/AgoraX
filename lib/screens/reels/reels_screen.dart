import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import '../../models/community/post_model.dart';
import '../../services/post/post_repository.dart';
import '../../widgets/common/optimized_image.dart';

class ReelsScreen extends StatefulWidget {
  final int initialIndex;

  const ReelsScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final PageController _pageController = PageController();
  List<Post> _reels = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  // Video controller pool
  final Map<int, VideoPlayerController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadReels();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _disposeAllControllers();
    super.dispose();
  }

  void _disposeAllControllers() {
    _controllers.forEach((_, controller) => controller.dispose());
    _controllers.clear();
  }

  Future<void> _loadReels() async {
    try {
      final fetched = await PostRepository.fetchReels(limit: 20);
      setState(() {
        _reels = fetched;
        _isLoading = false;
      });

      if (_reels.isNotEmpty) {
        _initializeVideoPlayer(_currentIndex);
      }
    } catch (e) {
      debugPrint('Error loading reels: $e');
      setState(() => _isLoading = false);
    }
  }

  void _initializeVideoPlayer(int index) {
    if (index < 0 || index >= _reels.length) return;

    final videoUrl = _reels[index].mediaUrl;
    if (videoUrl.isEmpty) return;

    if (!_controllers.containsKey(index)) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _controllers[index] = controller;

      controller.initialize().then((_) {
        if (mounted && index == _currentIndex) {
          controller.setLooping(true);
          controller.play();
          setState(() {});
        }
      });
    } else {
      _controllers[index]?.play();
    }

    // Clean up controllers far away (keep current and adjacent)
    _controllers.keys.toList().forEach((k) {
      if ((k - index).abs() > 1) {
        _controllers[k]?.dispose();
        _controllers.remove(k);
      }
    });

    // Preload next video
    if (index + 1 < _reels.length && !_controllers.containsKey(index + 1)) {
      final nextUrl = _reels[index + 1].mediaUrl;
      if (nextUrl.isNotEmpty) {
        final nextCtrl = VideoPlayerController.networkUrl(Uri.parse(nextUrl));
        _controllers[index + 1] = nextCtrl;
        nextCtrl.initialize();
      }
    }
  }

  void _onPageChanged(int index) {
    _controllers[_currentIndex]?.pause();
    setState(() => _currentIndex = index);
    _initializeVideoPlayer(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _reels.isEmpty
                  ? _buildEmptyState()
                  : PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: _reels.length,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, index) {
                        return _buildReelItem(_reels[index], index);
                      },
                    ),

          // Header Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReelItem(Post reel, int index) {
    final controller = _controllers[index];
    final isInitialized = controller != null && controller.value.isInitialized;

    return Stack(
      children: [
        // Video Viewport or Thumbnail Placeholder
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              if (controller != null) {
                if (controller.value.isPlaying) {
                  controller.pause();
                } else {
                  controller.play();
                }
                setState(() {});
              }
            },
            child: isInitialized
                ? AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  )
                : (reel.thumbnailUrl.isNotEmpty
                    ? OptimizedImage(imageUrl: reel.thumbnailUrl, fit: BoxFit.cover)
                    : Container(
                        color: Colors.black87,
                        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                      )),
          ),
        ),

        // Pause Icon Overlay
        if (isInitialized && !controller.value.isPlaying)
          const Center(
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.black45,
              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
            ),
          ),

        // Right Side Actions Bar (Like, Comment, Share, Save)
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              _buildActionButton(
                icon: Icons.favorite_rounded,
                color: reel.isLiked ? Colors.redAccent : Colors.white,
                label: '${reel.likes}',
                onTap: () => PostRepository.toggleLike(reel.id, reel.isLiked),
              ),
              const SizedBox(height: 18),
              _buildActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                color: Colors.white,
                label: '${reel.comments}',
                onTap: () => _openComments(reel),
              ),
              const SizedBox(height: 18),
              _buildActionButton(
                icon: Icons.share_rounded,
                color: Colors.white,
                label: 'Share',
                onTap: () => Share.share(reel.caption),
              ),
              const SizedBox(height: 18),
              _buildActionButton(
                icon: reel.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: reel.isBookmarked ? const Color(0xFF8B5CF6) : Colors.white,
                label: 'Save',
                onTap: () => PostRepository.toggleBookmark(reel.id, reel.isBookmarked),
              ),
            ],
          ),
        ),

        // Bottom Overlay (Author Info, Caption, Music)
        Positioned(
          left: 16,
          right: 80,
          bottom: 30,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: reel.authorAvatarUrl != null && reel.authorAvatarUrl!.isNotEmpty
                          ? OptimizedImage(imageUrl: reel.authorAvatarUrl!, fit: BoxFit.cover)
                          : Container(
                              color: Colors.white24,
                              child: const Icon(Icons.person, color: Colors.white, size: 20),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    reel.authorUsername ?? 'Creania Creator',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Follow',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                reel.caption,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.music_note_rounded, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Original Audio • Creania Sound',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _openComments(Post reel) {
    Get.bottomSheet(
      Container(
        height: 400,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.dialogBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Text('Comments (${reel.comments})', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            Expanded(
              child: Center(
                child: Text('No comments yet. Be the first to comment!', style: GoogleFonts.poppins(color: context.caption, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.video_library_rounded, size: 64, color: Colors.white30),
          const SizedBox(height: 12),
          Text(
            'No Reels Available',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Short videos will appear here.',
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
