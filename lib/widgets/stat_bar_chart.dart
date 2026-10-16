import 'package:flutter/material.dart';
import '../models/shield_stats_model.dart';
import '../theme/app_colors.dart';

class StatBarChart extends StatelessWidget {
  final List<DailySpamStat> dailyStats;
  final double height;

  const StatBarChart({
    super.key,
    required this.dailyStats,
    this.height = 90,
  });

  @override
  Widget build(BuildContext context) {
    if (dailyStats.isEmpty) return const SizedBox.shrink();

    final maxCount = dailyStats
        .map((s) => s.count)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: dailyStats.map((stat) {
          final double ratio = maxCount > 0 ? (stat.count / maxCount).clamp(0.25, 1.0) : 0.4;
          final double barHeight = height * ratio;

          return _buildBar(
            height: barHeight,
            isActive: stat.isCurrentDay,
            dayName: stat.dayName,
            count: stat.count,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBar({
    required double height,
    required bool isActive,
    required String dayName,
    required int count,
  }) {
    return Tooltip(
      message: '$dayName: $count spam blocked',
      child: Container(
        width: 32,
        height: height,
        decoration: BoxDecoration(
          color: isActive ? AppColors.chartBarActive : const Color(0xFFF9A8A8),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
