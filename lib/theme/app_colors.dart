import 'package:flutter/material.dart';
import '../models/message_model.dart';

class AppColors {
  AppColors._();

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFEDF2F7);

  // Brand / Dark Navy
  static const Color primaryDark = Color(0xFF0F172A);
  static const Color secondaryDark = Color(0xFF1E293B);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textSectionHeader = Color(0xFF475569);

  // Protection / Blue Banner
  static const Color bannerBlueBg = Color(0xFFEFF6FF);
  static const Color bannerBlueText = Color(0xFF1E3A8A);

  // SPAM Colors (Screen 1, 4, 5)
  static const Color spamItemBg = Color(0xFFFFF2F2);
  static const Color spamBadgeBg = Color(0xFFFEE2E2);
  static const Color spamBadgeText = Color(0xFFDC2626);
  static const Color spamAvatarBg = Color(0xFFFEE2E2);
  static const Color spamAvatarText = Color(0xFFDC2626);
  static const Color spamRiskCardBg = Color(0xFFFEE8E6);
  static const Color spamRiskText = Color(0xFF991B1B);
  static const Color spamActionPrimary = Color(0xFF991B1B);
  static const Color spamBannerBg = Color(0xFFFDE8E8);
  static const Color spamBannerText = Color(0xFF991B1B);
  static const Color spamDashedBorder = Color(0xFFDC2626);

  // NOT SPAM Colors (Screen 1, 2)
  static const Color notSpamItemBg = Color(0xFFFFFFFF);
  static const Color notSpamBadgeBg = Color(0xFFDCFCE7);
  static const Color notSpamBadgeText = Color(0xFF059669);
  static const Color notSpamAvatarBg = Color(0xFFDCFCE7);
  static const Color notSpamAvatarText = Color(0xFF059669);
  static const Color notSpamRiskCardBg = Color(0xFFE6F7EC);
  static const Color notSpamRiskText = Color(0xFF047857);
  static const Color notSpamActionPrimary = Color(0xFF0F172A);

  // SUS Colors (Suspicious / Warning)
  static const Color susItemBg = Color(0xFFFFFDF5);
  static const Color susBadgeBg = Color(0xFFFEF3C7);
  static const Color susBadgeText = Color(0xFFD97706);
  static const Color susAvatarBg = Color(0xFFFEF3C7);
  static const Color susAvatarText = Color(0xFFD97706);
  static const Color susRiskCardBg = Color(0xFFFEF9C3);
  static const Color susRiskText = Color(0xFFB45309);
  static const Color susActionPrimary = Color(0xFFB45309);

  // Shield Chart & Hero
  static const Color shieldHeroBg = Color(0xFF0E1726);
  static const Color chartBarNormal = Color(0xFFF87171);
  static const Color chartBarActive = Color(0xFFFFFFFF);

  // Helpers based on MessageCategory
  static Color getItemBackgroundColor(MessageCategory category) {
    switch (category) {
      case MessageCategory.spam:
        return spamItemBg;
      case MessageCategory.notSpam:
        return notSpamItemBg;
      case MessageCategory.sus:
        return susItemBg;
    }
  }

  static Color getBadgeBackgroundColor(MessageCategory category) {
    switch (category) {
      case MessageCategory.spam:
        return spamBadgeBg;
      case MessageCategory.notSpam:
        return notSpamBadgeBg;
      case MessageCategory.sus:
        return susBadgeBg;
    }
  }

  static Color getBadgeTextColor(MessageCategory category) {
    switch (category) {
      case MessageCategory.spam:
        return spamBadgeText;
      case MessageCategory.notSpam:
        return notSpamBadgeText;
      case MessageCategory.sus:
        return susBadgeText;
    }
  }

  static Color getAvatarBackgroundColor(MessageCategory category) {
    switch (category) {
      case MessageCategory.spam:
        return spamAvatarBg;
      case MessageCategory.notSpam:
        return notSpamAvatarBg;
      case MessageCategory.sus:
        return susAvatarBg;
    }
  }

  static Color getAvatarTextColor(MessageCategory category) {
    switch (category) {
      case MessageCategory.spam:
        return spamAvatarText;
      case MessageCategory.notSpam:
        return notSpamAvatarText;
      case MessageCategory.sus:
        return susAvatarText;
    }
  }

  static Color getRiskCardBackgroundColor(MessageCategory category) {
    switch (category) {
      case MessageCategory.spam:
        return spamRiskCardBg;
      case MessageCategory.notSpam:
        return notSpamRiskCardBg;
      case MessageCategory.sus:
        return susRiskCardBg;
    }
  }

  static Color getRiskTextColor(MessageCategory category) {
    switch (category) {
      case MessageCategory.spam:
        return spamRiskText;
      case MessageCategory.notSpam:
        return notSpamRiskText;
      case MessageCategory.sus:
        return susRiskText;
    }
  }
}
