import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../services/message_repository.dart';
import '../theme/app_colors.dart';

class ComposeMessageSheet extends StatefulWidget {
  final MessageRepository repository;

  const ComposeMessageSheet({
    super.key,
    required this.repository,
  });

  static Future<void> show(BuildContext context, MessageRepository repository) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ComposeMessageSheet(repository: repository),
    );
  }

  @override
  State<ComposeMessageSheet> createState() => _ComposeMessageSheetState();
}

class _ComposeMessageSheetState extends State<ComposeMessageSheet> {
  final _senderController = TextEditingController(text: 'Rohan <rohan@gmail.com>');
  final _subjectController = TextEditingController(text: 'Dinner tonight');
  final _bodyController = TextEditingController(text: 'Hey! Are we still on for dinner tonight at 8?');

  MessageCategory _selectedCategory = MessageCategory.notSpam;
  bool _isSending = false;

  @override
  void dispose() {
    _senderController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final sender = _senderController.text.trim();
    final body = _bodyController.text.trim();
    final subject = _subjectController.text.trim();

    if (sender.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both sender and message body'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    final int risk;
    final List<String> reasons;
    final String statusDesc;

    switch (_selectedCategory) {
      case MessageCategory.spam:
        risk = 92;
        reasons = ['Flagged by SpamShield rules', 'High phishing risk keyword pattern'];
        statusDesc = 'Blocked before opening. Do not tap links or share OTPs.';
        break;
      case MessageCategory.sus:
        risk = 55;
        reasons = ['Suspicious sender format', 'Review content before trusting'];
        statusDesc = 'Suspicious flags detected. Proceed with caution.';
        break;
      case MessageCategory.notSpam:
        risk = 4;
        reasons = ['Saved contact pattern', 'No threats detected'];
        statusDesc = 'Looks like a normal message. Safe to open.';
        break;
    }

    try {
      await widget.repository.sendMessageViaSupabase(
        sender: sender,
        messageText: body,
        subject: subject,
        category: _selectedCategory,
        riskPercentage: risk,
        statusDescription: statusDesc,
        reasons: reasons,
      );

      if (mounted) {
        Navigator.of(context).pop();
        final notifInfo = _selectedCategory == MessageCategory.notSpam
            ? '🔔 Notification triggered (Safe mail)!'
            : '🛡️ Quarantined silently (Notification suppressed)!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message sent via Supabase! $notifInfo'),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Send Message via Supabase',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tests notifications & pre-open classification',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Presets
                  const Text(
                    'QUICK SCENARIOS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textSectionHeader,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetChip('Safe Email (Not Spam)', () {
                          setState(() {
                            _senderController.text = 'Rohan <rohan@gmail.com>';
                            _subjectController.text = 'Dinner tonight';
                            _bodyController.text = 'Are we still on for dinner tonight at 8?';
                            _selectedCategory = MessageCategory.notSpam;
                          });
                        }),
                        const SizedBox(width: 8),
                        _buildPresetChip('KYC Phishing (Spam)', () {
                          setState(() {
                            _senderController.text = 'VK-KYCTEAM <kyc@bank-urgent.biz>';
                            _subjectController.text = 'Account Blocked';
                            _bodyController.text =
                                'Your KYC expires today. Update now to avoid account block: https://kyc-verify-portal.me';
                            _selectedCategory = MessageCategory.spam;
                          });
                        }),
                        const SizedBox(width: 8),
                        _buildPresetChip('Crypto Airdrop (Sus)', () {
                          setState(() {
                            _senderController.text = 'CryptoPromo <bot@telegram-airdrop.xyz>';
                            _subjectController.text = 'Guaranteed Returns';
                            _bodyController.text =
                                'Claim your 500 USDT bonus in our Telegram channel: t.me/free_crypto_vip';
                            _selectedCategory = MessageCategory.sus;
                          });
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Sender
                  const Text(
                    'SENDER / EMAIL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textSectionHeader,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: TextField(
                      controller: _senderController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. sender@example.com',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subject
                  const Text(
                    'SUBJECT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textSectionHeader,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: TextField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        hintText: 'Email Subject',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Message Body
                  const Text(
                    'MESSAGE CONTENT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textSectionHeader,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: TextField(
                      controller: _bodyController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Type email body...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Target Category Selector
                  const Text(
                    'SIMULATED PRE-CLASSIFICATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textSectionHeader,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildCategoryChoice(
                        category: MessageCategory.notSpam,
                        label: 'Not Spam (White)',
                        color: AppColors.notSpamBadgeText,
                        bgColor: AppColors.notSpamBadgeBg,
                        notifyDesc: '🔔 Shows notification',
                      ),
                      const SizedBox(width: 8),
                      _buildCategoryChoice(
                        category: MessageCategory.sus,
                        label: 'Sus (Yellow)',
                        color: AppColors.susBadgeText,
                        bgColor: AppColors.susBadgeBg,
                        notifyDesc: '🚫 Silenced',
                      ),
                      const SizedBox(width: 8),
                      _buildCategoryChoice(
                        category: MessageCategory.spam,
                        label: 'Spam (Red)',
                        color: AppColors.spamBadgeText,
                        bgColor: AppColors.spamBadgeBg,
                        notifyDesc: '🚫 Silenced',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Notification behavior notice
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _selectedCategory == MessageCategory.notSpam
                          ? AppColors.bannerBlueBg
                          : AppColors.spamBannerBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedCategory == MessageCategory.notSpam
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_off_rounded,
                          size: 20,
                          color: _selectedCategory == MessageCategory.notSpam
                              ? AppColors.bannerBlueText
                              : AppColors.spamBannerText,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedCategory == MessageCategory.notSpam
                                ? 'Notification WILL be shown on device (Safe message).'
                                : 'Notification BLOCKED. Message quarantined in app (Spam/Sus).',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _selectedCategory == MessageCategory.notSpam
                                  ? AppColors.bannerBlueText
                                  : AppColors.spamBannerText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                      label: Text(
                        _isSending ? 'Sending to Supabase...' : 'Send Message to Supabase',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      onPressed: _isSending ? null : _sendMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChoice({
    required MessageCategory category,
    required String label,
    required Color color,
    required Color bgColor,
    required String notifyDesc,
  }) {
    final isSelected = _selectedCategory == category;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = category),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? bgColor : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppColors.borderSubtle,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? color : AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                notifyDesc,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? color : AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.borderSubtle),
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
