import 'package:flutter/material.dart';
import '../models/shield_stats_model.dart';
import '../services/message_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/stat_bar_chart.dart';

class ShieldScreen extends StatefulWidget {
  final MessageRepository repository;

  const ShieldScreen({
    super.key,
    required this.repository,
  });

  @override
  State<ShieldScreen> createState() => _ShieldScreenState();
}

class _ShieldScreenState extends State<ShieldScreen> {
  String _selectedTimeframe = 'This week';

  @override
  Widget build(BuildContext context) {
    final stats = widget.repository.shieldStats;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(context),
              const SizedBox(height: 16),

              // Hero Card (Dark Navy)
              _buildHeroCard(stats),
              const SizedBox(height: 28),

              // Colour Guide Section
              _buildColourGuide(),
              const SizedBox(height: 28),

              // Top Spam Types Section
              _buildTopSpamTypes(stats.topSpamTypes),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Shield',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        // Timeframe Pill Selector
        PopupMenuButton<String>(
          initialValue: _selectedTimeframe,
          onSelected: (val) {
            setState(() {
              _selectedTimeframe = val;
            });
          },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedTimeframe,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'Today', child: Text('Today')),
            const PopupMenuItem(value: 'This week', child: Text('This week')),
            const PopupMenuItem(value: 'This month', child: Text('This month')),
            const PopupMenuItem(value: 'All time', child: Text('All time')),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroCard(ShieldStats stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.shieldHeroBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shieldHeroBg.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spam stopped',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${stats.totalSpamStopped}',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 24),
          StatBarChart(
            dailyStats: stats.dailyStats,
            height: 95,
          ),
        ],
      ),
    );
  }

  Widget _buildColourGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COLOUR GUIDE',
          style: TextStyle(
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
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // SPAM Row
              _buildGuideRow(
                badgeLabel: 'SPAM',
                badgeBg: AppColors.spamBadgeBg,
                badgeText: AppColors.spamBadgeText,
                description: 'Risk 50% and above',
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),

              // SUS Row (Added for user requirement!)
              _buildGuideRow(
                badgeLabel: 'SUS',
                badgeBg: AppColors.susBadgeBg,
                badgeText: AppColors.susBadgeText,
                description: 'Risk 35% to 49%',
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),

              // NOT SPAM Row
              _buildGuideRow(
                badgeLabel: 'NOT SPAM',
                badgeBg: AppColors.notSpamBadgeBg,
                badgeText: AppColors.notSpamBadgeText,
                description: 'Risk below 35%',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuideRow({
    required String badgeLabel,
    required Color badgeBg,
    required Color badgeText,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                color: badgeText,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Text(
            description,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSpamTypes(List<SpamTypeStat> types) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TOP SPAM TYPES',
          style: TextStyle(
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
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < types.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        types[i].typeName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${types[i].count}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < types.length - 1)
                  const Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
