import 'package:flutter/material.dart';
import '../services/message_repository.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  final MessageRepository repository;

  const SettingsScreen({
    super.key,
    required this.repository,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _smsProtection = true;
  bool _callProtection = true;
  bool _maskLinks = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),

              // Account Card: Login / Signup
              _buildAccountCard(),
              const SizedBox(height: 24),

              // Protection Toggles
              const Text(
                'PROTECTION CONTROLS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSectionHeader,
                ),
              ),
              const SizedBox(height: 10),
              Material(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.borderSubtle),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _smsProtection,
                      title: const Text('Real-time SMS Scanning', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Filter incoming messages into Spam, Sus & Safe'),
                      activeTrackColor: AppColors.primaryDark,
                      onChanged: (v) => setState(() => _smsProtection = v),
                    ),
                    const Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),
                    SwitchListTile(
                      value: _callProtection,
                      title: const Text('Fraud Call Shield', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Screen high-risk spam robocalls'),
                      activeTrackColor: AppColors.primaryDark,
                      onChanged: (v) => setState(() => _callProtection = v),
                    ),
                    const Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),
                    SwitchListTile(
                      value: _maskLinks,
                      title: const Text('Disable Phishing Links', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Mask malicious links automatically'),
                      activeTrackColor: AppColors.primaryDark,
                      onChanged: (v) => setState(() => _maskLinks = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF81C784)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Color(0xFF2E7D32),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '100% Private Shield',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Zero cloud storage • All messages stay on device',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: const Text(
              'ACTIVE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
