import 'package:flutter/material.dart';

class ProfileSkeletonWidget extends StatefulWidget {
  const ProfileSkeletonWidget({Key? key}) : super(key: key);

  @override
  State<ProfileSkeletonWidget> createState() => _ProfileSkeletonWidgetState();
}

class _ProfileSkeletonWidgetState extends State<ProfileSkeletonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildShimmerBox({
    required double width,
    required double height,
    double borderRadius = 8,
    BoxShape shape = BoxShape.rectangle,
  }) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            shape: shape,
            borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
            color: Colors.white.withOpacity(_animation.value * 0.15),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF11131C),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              // Skeleton Cover Photo Banner & Avatar Header
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Cover Photo
                  _buildShimmerBox(width: double.infinity, height: 180, borderRadius: 0),
                  
                  // Content Header Overlay
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40, left: 16, right: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Top bar placeholders
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildShimmerBox(width: 32, height: 32, borderRadius: 16),
                              _buildShimmerBox(width: 32, height: 32, borderRadius: 16),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Avatar circle skeleton (96dp)
                          _buildShimmerBox(width: 96, height: 96, shape: BoxShape.circle),
                          const SizedBox(height: 12),

                          // Username skeleton
                          _buildShimmerBox(width: 140, height: 18, borderRadius: 6),
                          const SizedBox(height: 8),

                          // User ID pill skeleton
                          _buildShimmerBox(width: 110, height: 22, borderRadius: 12),
                          const SizedBox(height: 12),

                          // Tags skeleton row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildShimmerBox(width: 70, height: 20, borderRadius: 10),
                              const SizedBox(width: 6),
                              _buildShimmerBox(width: 80, height: 20, borderRadius: 10),
                              const SizedBox(width: 6),
                              _buildShimmerBox(width: 60, height: 20, borderRadius: 10),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Skeleton Stats Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        _buildShimmerBox(width: 40, height: 16, borderRadius: 4),
                        const SizedBox(height: 6),
                        _buildShimmerBox(width: 60, height: 12, borderRadius: 4),
                      ],
                    ),
                    Column(
                      children: [
                        _buildShimmerBox(width: 40, height: 16, borderRadius: 4),
                        const SizedBox(height: 6),
                        _buildShimmerBox(width: 60, height: 12, borderRadius: 4),
                      ],
                    ),
                    Column(
                      children: [
                        _buildShimmerBox(width: 40, height: 16, borderRadius: 4),
                        const SizedBox(height: 6),
                        _buildShimmerBox(width: 60, height: 12, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Skeleton Tabs Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildShimmerBox(width: 80, height: 32, borderRadius: 16),
                    _buildShimmerBox(width: 80, height: 32, borderRadius: 16),
                    _buildShimmerBox(width: 80, height: 32, borderRadius: 16),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Skeleton Content Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildShimmerBox(width: double.infinity, height: 100, borderRadius: 16),
                    const SizedBox(height: 12),
                    _buildShimmerBox(width: double.infinity, height: 100, borderRadius: 16),
                    const SizedBox(height: 12),
                    _buildShimmerBox(width: double.infinity, height: 100, borderRadius: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
