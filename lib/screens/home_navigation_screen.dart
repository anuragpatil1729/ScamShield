import 'package:flutter/material.dart';
import '../services/message_repository.dart';
import '../theme/app_colors.dart';
import 'calls_screen.dart';
import 'inbox_screen.dart';
import 'settings_screen.dart';
import 'shield_screen.dart';

class HomeNavigationScreen extends StatefulWidget {
  final MessageRepository repository;

  const HomeNavigationScreen({
    super.key,
    required this.repository,
  });

  @override
  State<HomeNavigationScreen> createState() => _HomeNavigationScreenState();
}

class _HomeNavigationScreenState extends State<HomeNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      InboxScreen(repository: widget.repository),
      const CallsScreen(),
      ShieldScreen(repository: widget.repository),
      SettingsScreen(repository: widget.repository),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.borderSubtle.withValues(alpha: 0.8),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.inbox_outlined,
                  activeIcon: Icons.inbox_rounded,
                  label: 'Inbox',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.phone_outlined,
                  activeIcon: Icons.phone_rounded,
                  label: 'Calls',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.shield_outlined,
                  activeIcon: Icons.shield_rounded,
                  label: 'Shield',
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.primaryDark : AppColors.textMuted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: color,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
