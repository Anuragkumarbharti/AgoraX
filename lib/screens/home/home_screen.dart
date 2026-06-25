import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/index.dart';
import '../../widgets/post_card.dart';
import '../../widgets/community_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ScrollController _scrollController;
  bool _showFloatingButton = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      setState(() {
        _showFloatingButton = _scrollController.offset < 100;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: Text(
          'Home',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Trending Communities
              _buildSectionHeader(context, 'Trending Communities'),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: CommunityCard(
                        community: Community(
                          id: '$index',
                          name: ['Flutter', 'AI', 'Web Dev', 'UPSC', 'Gaming'][index],
                          description: 'Discussion on ${['Flutter', 'AI', 'Web Dev', 'UPSC', 'Gaming'][index]}',
                          category: 'Technology',
                          type: 'public',
                          owner: 'admin',
                          admins: [],
                          members: [],
                          memberCount: 1000 + (index * 500),
                          isVerified: index % 2 == 0,
                          createdAt: DateTime.now(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),

              // Popular Questions
              _buildSectionHeader(context, 'Popular Questions'),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildQuestionCard(context, index),
                  );
                },
              ),
              const SizedBox(height: 32),

              // Recent Posts
              _buildSectionHeader(context, 'Recent Posts'),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PostCard(
                      post: Post(
                        id: '$index',
                        userId: 'user$index',
                        communityId: 'comm$index',
                        content: 'This is a sample post content ${index + 1}. Check out this amazing discussion!',
                        likes: 100 + (index * 50),
                        comments: 20 + (index * 10),
                        shares: 10 + index,
                        isLiked: false,
                        isBookmarked: false,
                        createdAt: DateTime.now(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _showFloatingButton
          ? FloatingActionButton(
              onPressed: () {},
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add),
            )
          : null,
    );

  Widget _buildSectionHeader(BuildContext context, String title) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        TextButton(
          onPressed: () {},
          child: Text(
            'View All',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.primaryColor,
                ),
          ),
        ),
      ],
    );

  Widget _buildQuestionCard(BuildContext context, int index) => Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor, width: 0.5),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to implement state management in Flutter?',
            style: Theme.of(context).textTheme.bodyLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Flutter',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryColor,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${24 + index} answers',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
}
