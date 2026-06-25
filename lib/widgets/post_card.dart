import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/post_model.dart';

class PostCard extends StatelessWidget {

  const PostCard({
    Key? key,
    required this.post,
    this.onTap,
  }) : super(key: key);
  final Post post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor, width: 0.5),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                  child: Text('U', style: Theme.of(context).textTheme.bodySmall),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Name',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      Text(
                        '2 hours ago',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Content
            Text(
              post.content,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAction(context, Icons.favorite_outline, '${post.likes}'),
                _buildAction(context, Icons.chat_bubble_outline, '${post.comments}'),
                _buildAction(context, Icons.share_outlined, '${post.shares}'),
                _buildAction(context, Icons.bookmark_outline, ''),
              ],
            ),
          ],
        ),
      ),
    );

  Widget _buildAction(BuildContext context, IconData icon, String count) => Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textTertiary),
        if (count.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(count, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
}
