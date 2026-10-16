import 'package:flutter/material.dart';
import '../models/classification_result.dart';
import '../services/message_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/flag_reasons_card.dart';
import '../widgets/risk_card.dart';

class ClassifyTesterSheet extends StatefulWidget {
  final MessageRepository repository;

  const ClassifyTesterSheet({
    super.key,
    required this.repository,
  });

  static Future<void> show(BuildContext context, MessageRepository repository) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClassifyTesterSheet(repository: repository),
    );
  }

  @override
  State<ClassifyTesterSheet> createState() => _ClassifyTesterSheetState();
}

class _ClassifyTesterSheetState extends State<ClassifyTesterSheet> {
  final _senderController = TextEditingController(text: 'Bank-Alert');
  final _messageController = TextEditingController(
    text: 'Your card is blocked. Complete KYC immediately at: https://secure-bank-update.in',
  );

  bool _isLoading = false;
  ClassificationResult? _result;

  @override
  void dispose() {
    _senderController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _runClassification() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _result = null;
    });

    final res = await widget.repository.classifierService.classify(
      text,
      sender: _senderController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _result = res;
      });
    }
  }

  Future<void> _addMessageToInbox() async {
    if (_messageController.text.trim().isEmpty) return;

    await widget.repository.processAndAddMessage(
      sender: _senderController.text.trim().isEmpty ? 'Unknown' : _senderController.text.trim(),
      messageText: _messageController.text.trim(),
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message classified and added to Inbox!'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
                        'Spam Prediction & Testing',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Test any text with the classification engine',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
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

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Presets
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetChip('Fake KYC (Spam)', () {
                          _senderController.text = 'VK-KYCTEAM';
                          _messageController.text =
                              'Your KYC expires today. Update now to avoid account block: https://bit.ly/kyc-update-now';
                          _runClassification();
                        }),
                        const SizedBox(width: 8),
                        _buildPresetChip('Prize Lure (Spam)', () {
                          _senderController.text = '+91 98xxx 41207';
                          _messageController.text =
                              'You won a prize! Claim your reward ₹50,000 within 1 hour: http://lottery-claim.biz';
                          _runClassification();
                        }),
                        const SizedBox(width: 8),
                        _buildPresetChip('Telegram Crypto (Sus)', () {
                          _senderController.text = 'Crypto Bot';
                          _messageController.text =
                              'Get 150% guaranteed return with VIP crypto signals. Join telegram t.me/profit_signals';
                          _runClassification();
                        }),
                        const SizedBox(width: 8),
                        _buildPresetChip('Personal Chat (Safe)', () {
                          _senderController.text = 'Rohan';
                          _messageController.text = 'Are we still on for dinner tonight?';
                          _runClassification();
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Sender Input
                  const Text(
                    'SENDER / ORIGIN',
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
                        hintText: 'e.g. VK-KYCTEAM or +91...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Message Input
                  const Text(
                    'MESSAGE TEXT',
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
                      controller: _messageController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Type or paste message to classify...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _runClassification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Predict Classification',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  // Result display if available
                  if (_result != null) ...[
                    const SizedBox(height: 24),
                    const Divider(color: AppColors.borderSubtle),
                    const SizedBox(height: 16),
                    RiskCard(
                      category: _result!.category,
                      riskPercentage: _result!.riskPercentage,
                      description: _result!.statusDescription,
                    ),
                    const SizedBox(height: 16),
                    FlagReasonsCard(
                      category: _result!.category,
                      reasons: _result!.reasons,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add to Active Inbox List'),
                        onPressed: _addMessageToInbox,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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
