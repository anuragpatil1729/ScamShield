import 'message_model.dart';

class ClassificationResult {
  final MessageCategory category;
  final double riskScore; // 0.0 to 1.0
  final int riskPercentage; // 0 to 100
  final String statusDescription;
  final List<String> reasons;
  final List<String> flaggedKeywords;
  final List<String> maskedLinks;
  final double? ruleScore;
  final String? layer1Route;
  final List<String>? layer1Hits;
  final Map<String, double>? features;

  const ClassificationResult({
    required this.category,
    required this.riskScore,
    required this.riskPercentage,
    required this.statusDescription,
    required this.reasons,
    this.flaggedKeywords = const [],
    this.maskedLinks = const [],
    this.ruleScore,
    this.layer1Route,
    this.layer1Hits,
    this.features,
  });

  factory ClassificationResult.fromScore({
    required double score,
    String? customDescription,
    List<String>? customReasons,
    List<String>? flaggedKeywords,
    List<String>? maskedLinks,
  }) {
    final int percentage = (score * 100).clamp(0, 100).round();
    final MessageCategory cat;
    final String desc;
    final List<String> defaultReasons;

    if (percentage >= 50) {
      cat = MessageCategory.spam;
      desc = customDescription ?? 'Blocked before opening. Do not tap links or share OTPs.';
      defaultReasons = [
        'Urgent deadline pressure detected',
        'Suspicious URL pattern or shortened link',
        'Sender ID not verified in legitimate directory',
      ];
    } else if (percentage >= 25) {
      cat = MessageCategory.sus;
      desc = customDescription ?? 'Potential phishing or marketing risk. Proceed with caution.';
      defaultReasons = [
        'Unknown sender pattern',
        'Unsolicited offer or promotion keywords',
        'Verification required before proceeding',
      ];
    } else {
      cat = MessageCategory.notSpam;
      desc = customDescription ?? 'Looks like a normal message. Safe to open.';
      defaultReasons = [
        'Saved contact or verified sender',
        'No deceptive links or payment requests',
        'Normal conversation context and tone',
      ];
    }

    return ClassificationResult(
      category: cat,
      riskScore: score,
      riskPercentage: percentage,
      statusDescription: desc,
      reasons: customReasons ?? defaultReasons,
      flaggedKeywords: flaggedKeywords ?? [],
      maskedLinks: maskedLinks ?? [],
    );
  }
}
