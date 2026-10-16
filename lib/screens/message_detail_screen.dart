import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../services/message_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/flag_reasons_card.dart';
import '../widgets/message_body_card.dart';
import '../widgets/risk_card.dart';

class MessageDetailScreen extends StatelessWidget {
  final MessageItem message;
  final MessageRepository repository;

  const MessageDetailScreen({
    super.key,
    required this.message,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildAppBar(context),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Risk Card
                    RiskCard(
                      category: message.category,
                      riskPercentage: message.riskPercentage,
                      description: message.statusDescription,
                    ),
                    const SizedBox(height: 24),

                    // Why Flagged / Why Safe Card
                    FlagReasonsCard(
                      category: message.category,
                      reasons: message.reasons,
                    ),
                    const SizedBox(height: 24),

                    // Message Content Card
                    MessageBodyCard(
                      category: message.category,
                      fullMessage: message.fullMessage,
                      maskedLinks: message.maskedLinks,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Action Buttons
            _buildBottomActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back pill button
          _buildPillButton(
            label: 'Back',
            onTap: () => Navigator.of(context).pop(),
          ),

          // Sender Name
          Expanded(
            child: Text(
              message.sender,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // More pill button
          _buildPillButton(
            label: 'More',
            onTap: () => _showMoreSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPillButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    final bool isSpam = message.category == MessageCategory.spam;
    final bool isSus = message.category == MessageCategory.sus;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.borderSubtle.withValues(alpha: 0.5))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary Action
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                if (isSpam || isSus) {
                  repository.blockAndReport(message.id);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Blocked and reported ${message.sender}'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Opening reply to ${message.sender}...'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: (isSpam || isSus)
                    ? AppColors.spamActionPrimary
                    : AppColors.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                (isSpam || isSus) ? 'Block and report' : 'Reply',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Secondary Action
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () {
                if (isSpam) {
                  repository.markAsNotSpam(message.id);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Marked ${message.sender} as not spam'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  repository.reportAsSpam(message.id);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reported ${message.sender} as spam'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.primaryDark, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                isSpam ? 'Not spam' : 'Report as spam',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share message details'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy message text'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.security_rounded),
              title: const Text('View sender telemetry'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
}
