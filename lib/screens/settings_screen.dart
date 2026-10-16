import 'package:flutter/material.dart';
import '../services/message_repository.dart';
import '../theme/app_colors.dart';
import 'classify_tester_sheet.dart';

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
  double _spamThreshold = 50.0;
  double _susThreshold = 35.0;

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

              // ML / Neural Network Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.memory_rounded, color: AppColors.primaryDark),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Neural Network & ML Engine',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Modular AI Backend Architecture',
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Active Engine: ${widget.repository.classifierService.modelName}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ready to plug in TensorFlow Lite, ONNX, PyTorch Mobile, or custom transformer weights with zero UI changes.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.science_outlined, size: 18),
                        label: const Text('Launch AI Classifier Tester'),
                        onPressed: () => ClassifyTesterSheet.show(context, widget.repository),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
              const SizedBox(height: 24),

              // Sensitivity Sliders
              const Text(
                'DETECTION THRESHOLDS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSectionHeader,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Spam Threshold', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('${_spamThreshold.round()}% risk & above',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.spamBadgeText)),
                      ],
                    ),
                    Slider(
                      value: _spamThreshold,
                      min: 40,
                      max: 90,
                      divisions: 10,
                      activeColor: AppColors.spamActionPrimary,
                      onChanged: (v) => setState(() => _spamThreshold = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Suspicious Threshold', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('${_susThreshold.round()}% risk & above',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.susBadgeText)),
                      ],
                    ),
                    Slider(
                      value: _susThreshold,
                      min: 20,
                      max: 50,
                      divisions: 6,
                      activeColor: AppColors.susBadgeText,
                      onChanged: (v) => setState(() => _susThreshold = v),
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
}
