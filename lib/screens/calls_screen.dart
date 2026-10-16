import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final blockedCalls = [
      {
        'caller': '+91 80 4912 3400',
        'type': 'Robocall / Loan scam',
        'time': 'Today, 2:15 PM',
        'tag': 'SPAM',
        'risk': '92%',
      },
      {
        'caller': 'Unknown +1 (800) 555-0199',
        'type': 'Tech Support Impersonation',
        'time': 'Yesterday, 6:40 PM',
        'tag': 'SPAM',
        'risk': '87%',
      },
      {
        'caller': '+91 94xxx 88219',
        'type': 'Unregistered Marketing',
        'time': 'Yesterday, 11:20 AM',
        'tag': 'SUS',
        'risk': '48%',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Calls',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),

              // Call Shield Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.bannerBlueBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.phone_locked_rounded, color: AppColors.bannerBlueText),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Live Call Screening active · 14 unknown callers filtered',
                        style: TextStyle(
                          color: AppColors.bannerBlueText,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'RECENTLY FILTERED CALLS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSectionHeader,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < blockedCalls.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: blockedCalls[i]['tag'] == 'SPAM'
                                    ? AppColors.spamAvatarBg
                                    : AppColors.susAvatarBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.phone_disabled_rounded,
                                color: blockedCalls[i]['tag'] == 'SPAM'
                                    ? AppColors.spamAvatarText
                                    : AppColors.susAvatarText,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    blockedCalls[i]['caller']!,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${blockedCalls[i]['type']} · ${blockedCalls[i]['time']}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: blockedCalls[i]['tag'] == 'SPAM'
                                    ? AppColors.spamBadgeBg
                                    : AppColors.susBadgeBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                blockedCalls[i]['tag']!,
                                style: TextStyle(
                                  color: blockedCalls[i]['tag'] == 'SPAM'
                                      ? AppColors.spamBadgeText
                                      : AppColors.susBadgeText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < blockedCalls.length - 1)
                        const Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
