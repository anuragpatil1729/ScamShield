import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../theme/app_colors.dart';

class FlagReasonsCard extends StatelessWidget {
  final MessageCategory category;
  final List<String> reasons;

  const FlagReasonsCard({
    super.key,
    required this.category,
    required this.reasons,
  });

  @override
  Widget build(BuildContext context) {
    final String title;
    switch (category) {
      case MessageCategory.spam:
        title = 'WHY WE FLAGGED IT';
        break;
      case MessageCategory.notSpam:
        title = 'WHY IT LOOKS SAFE';
        break;
      case MessageCategory.sus:
        title = 'WHY WE FLAGGED AS SUSPICIOUS';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textSectionHeader,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < reasons.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Text(
                    reasons[i],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (i < reasons.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.borderSubtle,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
