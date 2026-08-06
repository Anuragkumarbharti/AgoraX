import 'package:creania/core/theme.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/community/community_model.dart';

class CommunityCard extends StatelessWidget {

  const CommunityCard({
    Key? key,
    required this.community,
    this.onTap,
  }) : super(key: key);
  final Community community;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor, width: 0.5),
        ),
        child: Column(
          children: [
            // Avatar/Image
            Container(
              height: 65,
              decoration: BoxDecoration(
                color: context.primaryColor.withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Center(
                child: Text(
                  community.name.substring(0, 1),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: context.primaryColor,
                      ),
                ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            community.name,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (community.isVerified)
                          Icon(
                            Icons.verified,
                            size: 12,
                            color: context.accentOrange,
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${community.memberCount}K members',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          backgroundColor: context.primaryColor,
                        ),
                        child: Text(
                          'Join',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
