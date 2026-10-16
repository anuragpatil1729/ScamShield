import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../theme/app_colors.dart';

class MessageTile extends StatelessWidget {
  final MessageItem message;
  final VoidCallback onTap;

  const MessageTile({
    super.key,
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.getItemBackgroundColor(message.category);
    final avatarBg = AppColors.getAvatarBackgroundColor(message.category);
    final avatarTextColor = AppColors.getAvatarTextColor(message.category);
    final badgeBg = AppColors.getBadgeBackgroundColor(message.category);
    final badgeTextColor = AppColors.getBadgeTextColor(message.category);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: avatarBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: message.category == MessageCategory.spam
                  ? Icon(
                      Icons.priority_high_rounded,
                      color: avatarTextColor,
                      size: 24,
                    )
                  : (message.category == MessageCategory.sus
                      ? Icon(
                          Icons.question_mark_rounded,
                          color: avatarTextColor,
                          size: 22,
                        )
                      : Text(
                          message.senderAvatarChar,
                          style: TextStyle(
                            color: avatarTextColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        )),
            ),
            const SizedBox(width: 16),
            // Title & Snippet
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          message.sender,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          message.category.displayName,
                          style: TextStyle(
                            color: badgeTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message.snippet,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
