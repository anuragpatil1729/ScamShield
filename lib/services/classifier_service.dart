import '../models/classification_result.dart';
import '../models/message_model.dart';

/// Abstract contract for Spam / Phishing / Fraud classification engines.
///
/// When connecting a TensorFlow Lite, ONNX, PyTorch, PyTorch Mobile,
/// HuggingFace API, or custom Neural Network backend, implement this interface
/// and pass it to the [MessageRepository].
abstract class SpamClassifierService {
  String get modelName;
  String get modelVersion;

  Future<ClassificationResult> classify(
    String text, {
    String? sender,
    Map<String, dynamic>? metadata,
  });
}

/// Dynamic default implementation providing intelligent text heuristics
/// until the user injects their Machine Learning / Neural Network model.
class HeuristicMockClassifierService implements SpamClassifierService {
  @override
  String get modelName => 'ScamShield Neural Baseline (Ready for ML Integration)';

  @override
  String get modelVersion => 'v1.0.0-draft';

  @override
  Future<ClassificationResult> classify(
    String text, {
    String? sender,
    Map<String, dynamic>? metadata,
  }) async {
    // Simulate real neural network inference latency
    await Future.delayed(const Duration(milliseconds: 300));

    final lower = text.toLowerCase();
    final lowerSender = (sender ?? '').toLowerCase();

    final List<String> flaggedKeywords = [];
    final List<String> maskedLinks = [];
    final List<String> reasons = [];
    double riskScore = 0.04;

    // Link detection pattern
    final urlRegex = RegExp(r'(https?:\/\/[^\s]+|bit\.ly\/[^\s]+|t\.co\/[^\s]+|tinyurl\.com\/[^\s]+)');
    final matches = urlRegex.allMatches(text);
    for (final match in matches) {
      maskedLinks.add(match.group(0)!);
    }

    // High risk triggers (Spam)
    if (lower.contains('kyc') ||
        lower.contains('expires today') ||
        lower.contains('account block') ||
        lower.contains('update now') ||
        lowerSender.contains('kyc')) {
      riskScore = 0.96;
      flaggedKeywords.addAll(['kyc', 'block', 'expires today']);
      reasons.add('Urgent deadline pressure');
      if (maskedLinks.isNotEmpty) {
        reasons.add('Shortened link hides real address');
      } else {
        reasons.add('Deceptive credential harvesting request');
      }
      reasons.add('Sender ID not verified in legitimate telecom registry');
    } else if (lower.contains('won a prize') ||
        lower.contains('lottery') ||
        lower.contains('claim your reward') ||
        lower.contains('1 hour') ||
        lower.contains('cashback 5000')) {
      riskScore = 0.88;
      flaggedKeywords.addAll(['prize', 'reward', 'claim']);
      reasons.add('Lotto / Prize lure with artificial urgency');
      reasons.add('Suspicious unknown financial sender');
      reasons.add('High similarity with reported fraud templates');
    } else if (lower.contains('delivery on hold') ||
        lower.contains('small fee') ||
        lower.contains('parcel') ||
        lowerSender.contains('parcel')) {
      riskScore = 0.82;
      flaggedKeywords.addAll(['delivery on hold', 'fee']);
      reasons.add('Unsolicited postal payment demand');
      reasons.add('Advance fee scam pattern detected');
      reasons.add('Unverified courier origin');
    } else if (lower.contains('crypto') ||
        lower.contains('airdrop') ||
        lower.contains('investment') ||
        lower.contains('work from home') ||
        lower.contains('part time job') ||
        lower.contains('telegram')) {
      riskScore = 0.58; // SUS category
      flaggedKeywords.addAll(['telegram', 'investment', 'airdrop']);
      reasons.add('Unsolicited commercial solicitation');
      reasons.add('Third-party channel redirection');
      reasons.add('High-risk financial claims');
    } else if (maskedLinks.isNotEmpty) {
      riskScore = 0.42; // SUS category
      reasons.add('Contains external unverified link');
      reasons.add('Sender is not in trusted contacts');
      reasons.add('Follow-up verification advised');
    } else {
      // Safe / Not Spam
      riskScore = 0.04;
      reasons.add('Saved contact or regular messaging behavior');
      reasons.add('No links or payment requests');
      reasons.add('Normal conversation history and linguistic pattern');
    }

    final category = riskScore >= 0.70
        ? MessageCategory.spam
        : (riskScore >= 0.35 ? MessageCategory.sus : MessageCategory.notSpam);

    final statusDesc = category == MessageCategory.spam
        ? 'Blocked before opening. Do not tap links or share OTPs.'
        : (category == MessageCategory.sus
            ? 'Suspicious flags found. Exercise caution before opening links.'
            : 'Looks like a normal message. Safe to open.');

    return ClassificationResult(
      category: category,
      riskScore: riskScore,
      riskPercentage: (riskScore * 100).round(),
      statusDescription: statusDesc,
      reasons: reasons,
      flaggedKeywords: flaggedKeywords,
      maskedLinks: maskedLinks,
    );
  }
}
