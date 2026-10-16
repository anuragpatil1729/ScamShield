import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../theme/app_colors.dart';

class FilterChipBar extends StatelessWidget {
  final MessageCategory? selectedCategory;
  final int totalCount;
  final int spamCount;
  final int notSpamCount;
  final int susCount;
  final ValueChanged<MessageCategory?> onSelected;

  const FilterChipBar({
    super.key,
    required this.selectedCategory,
    required this.totalCount,
    required this.spamCount,
    required this.notSpamCount,
    required this.susCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildChip(
            label: 'All $totalCount',
            isSelected: selectedCategory == null,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Spam $spamCount',
            isSelected: selectedCategory == MessageCategory.spam,
            onTap: () => onSelected(MessageCategory.spam),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Sus $susCount',
            isSelected: selectedCategory == MessageCategory.sus,
            onTap: () => onSelected(MessageCategory.sus),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Not spam $notSpamCount',
            isSelected: selectedCategory == MessageCategory.notSpam,
            onTap: () => onSelected(MessageCategory.notSpam),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.border,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
