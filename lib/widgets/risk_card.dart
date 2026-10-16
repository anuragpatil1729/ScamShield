import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../theme/app_colors.dart';

class RiskCard extends StatelessWidget {
  final MessageCategory category;
  final int riskPercentage;
  final String description;

  const RiskCard({
    super.key,
    required this.category,
    required this.riskPercentage,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.getRiskCardBackgroundColor(category);
    final textColor = AppColors.getRiskTextColor(category);

    final String tagText;
    switch (category) {
      case MessageCategory.spam:
        tagText = 'SPAM DETECTED';
        break;
      case MessageCategory.notSpam:
        tagText = 'NOT SPAM';
        break;
      case MessageCategory.sus:
        tagText = 'SUSPICIOUS DETECTED';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tagText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$riskPercentage% risk',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textColor.withValues(alpha: 0.85),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
