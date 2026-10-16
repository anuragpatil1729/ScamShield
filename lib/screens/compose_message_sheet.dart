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
  final _bodyController = TextEditingController(
      text: 'Hey! Are we still syncing up for the review today? Let me know!');

  MessageCategory _selectedCategory = MessageCategory.notSpam;
  bool _isSending = false;

  @override
  void dispose() {
    _senderController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final sender = _senderController.text.trim();
    final body = _bodyController.text.trim();

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

    try {
      final chatId = sender.toLowerCase().replaceAll(RegExp(r'\s+'), '_');

      // Receive and classify locally with notification pre-filtering
      await widget.repository.receiveIncomingMessage(
        chatId: chatId,
        sender: sender,
        text: body,
        overrideCategory: _selectedCategory,
      );

      if (mounted) {
        Navigator.of(context).pop();
        final notifInfo = _selectedCategory == MessageCategory.notSpam
            ? '🔔 Notification triggered (Safe message)!'
            : '🛡️ Quarantined silently (Notification suppressed)!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message delivered locally! $notifInfo'),
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
            content: Text('Error: $e'),
            backgroundColor: AppColors.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _applyScenario(String sender, String body, MessageCategory category) {
    setState(() {
      _senderController.text = sender;
      _bodyController.text = body;
      _selectedCategory = category;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sheet Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.send_rounded, color: AppColors.primaryDark, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Simulate Incoming Chat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Local ML Classifier & Safe-Only Notification Filter',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Quick Scenario Presets
            const Text(
              'Quick Scenarios:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildScenarioChip(
                    label: '🟢 Safe Message',
                    color: const Color(0xFFE8F5E9),
                    textColor: const Color(0xFF2E7D32),
                    onTap: () => _applyScenario(
                      'Rohan Sharma',
                      'Hey! Are we still syncing up for the review today? Let me know!',
                      MessageCategory.notSpam,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildScenarioChip(
                    label: '🟡 Sus Promo',
                    color: const Color(0xFFFFFBEA),
                    textColor: const Color(0xFFF57F17),
                    onTap: () => _applyScenario(
                      'Unknown (+1 555-0192)',
                      '🎉 Claim 0.5 BTC airdrop! Join t.me/free_crypto_airdrop before timer expires.',
                      MessageCategory.sus,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildScenarioChip(
                    label: '🔴 Urgent Spam',
                    color: const Color(0xFFFFEEEE),
                    textColor: const Color(0xFFC62828),
                    onTap: () => _applyScenario(
                      'VK-TAXDEPT',
                      'URGENT: Income Tax Refund of Rs. 42,850 pending. KYC expired! Tap http://bit.ly/incometax-verify-kyc immediately!',
                      MessageCategory.spam,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Category Selector
            const Text(
              'Classification Category:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildCategoryRadio(
                  category: MessageCategory.notSpam,
                  label: 'White (Safe)',
                  color: const Color(0xFF2E7D32),
                  bgColor: const Color(0xFFE8F5E9),
                ),
                const SizedBox(width: 8),
                _buildCategoryRadio(
                  category: MessageCategory.sus,
                  label: 'Yellow (Sus)',
                  color: const Color(0xFFF57F17),
                  bgColor: const Color(0xFFFFFBEA),
                ),
                const SizedBox(width: 8),
                _buildCategoryRadio(
                  category: MessageCategory.spam,
                  label: 'Red (Spam)',
                  color: const Color(0xFFC62828),
                  bgColor: const Color(0xFFFFEEEE),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Sender
            TextFormField(
              controller: _senderController,
              decoration: InputDecoration(
                labelText: 'Contact / Sender',
                hintText: 'e.g. Rohan Sharma or +91 98200 12345',
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Message Body
            TextFormField(
              controller: _bodyController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Message Body',
                hintText: 'Enter text to classify and filter...',
                alignLabelWithHint: true,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Deliver Message Locally',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioChip({
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: textColor.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRadio({
    required MessageCategory category,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    final isSelected = _selectedCategory == category;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = category),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? bgColor : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : AppColors.borderSubtle,
              width: isSelected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? color : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
