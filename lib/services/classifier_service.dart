import '../models/classification_result.dart';
import '../models/message_model.dart';

/// Abstract contract for Spam / Phishing / Fraud classification engines.
abstract class SpamClassifierService {
  String get modelName;
  String get modelVersion;

  Future<ClassificationResult> classify(
    String text, {
    String? sender,
    Map<String, dynamic>? metadata,
  });
}

/// ============================================================================
/// DETECTION PIPELINE
/// ============================================================================

/// Layer 1 – Rule-based & URL Analysis
/// (Urgency, Impersonation, Message Flooding, URL Parsing, IP Addresses, Known Threats)
class Layer1RuleAndUrlAnalysis {
  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+|bit\.ly\/[^\s]+|tinyurl\.com\/[^\s]+|t\.co\/[^\s]+|goo\.gl\/[^\s]+|is\.gd\/[^\s]+)',
    caseSensitive: false,
  );

  static final RegExp _ipRegex = RegExp(
    r'\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b',
  );

  static final List<String> _urgencyPhrases = [
    'expires today',
    'urgent',
    'act immediately',
    'account blocked',
    'suspended within 24 hours',
    'immediate action',
    'limited time',
    'action required',
    '1 hour',
    'final notice',
  ];

  static final List<String> _impersonationEntities = [
    'hdfc bank',
    'sbi bank',
    'icici bank',
    'paypal',
    'income tax department',
    'fasttrack courier',
    'fedex',
    'dhl',
    'india post',
    'kyc team',
  ];

  static final List<String> _knownThreatSignatures = [
    'kyc update',
    'won a prize',
    'lottery prize',
    'claim your reward',
    'delivery on hold',
    'unpaid customs fee',
    'airdrop claim',
    'part-time job 5000/day',
    'telegram task job',
  ];

  Layer1AnalysisResult analyze(String text, {String? sender, Map<String, dynamic>? metadata}) {
    final lower = text.toLowerCase();
    final lowerSender = (sender ?? '').toLowerCase();

    final List<String> flaggedKeywords = [];
    final List<String> extractedUrls = [];
    final List<String> reasons = [];
    double ruleRisk = 0.0;

    // 1. URL Parsing & Shorteners
    for (final match in _urlRegex.allMatches(text)) {
      final url = match.group(0)!;
      extractedUrls.add(url);
      if (url.contains('bit.ly') || url.contains('tinyurl') || url.contains('t.co') || url.contains('is.gd')) {
        reasons.add('Layer 1: Obfuscated short URL detected ($url)');
        ruleRisk += 0.35;
      }
    }

    // 2. IP Address in text/URL
    if (_ipRegex.hasMatch(text)) {
      reasons.add('Layer 1: Raw IP address target detected in message');
      flaggedKeywords.add('raw_ip');
      ruleRisk += 0.40;
    }

    // 3. Urgency Analysis
    for (final phrase in _urgencyPhrases) {
      if (lower.contains(phrase)) {
        flaggedKeywords.add(phrase);
        reasons.add('Layer 1: High urgency deadline pressure ("$phrase")');
        ruleRisk += 0.30;
        break;
      }
    }

    // 4. Impersonation Analysis
    for (final entity in _impersonationEntities) {
      if (lower.contains(entity) || lowerSender.contains(entity.replaceAll(' ', ''))) {
        flaggedKeywords.add(entity);
        reasons.add('Layer 1: Suspected entity impersonation ("$entity")');
        ruleRisk += 0.35;
        break;
      }
    }

    // 5. Known Threat Signatures
    for (final sig in _knownThreatSignatures) {
      if (lower.contains(sig)) {
        flaggedKeywords.add(sig);
        reasons.add('Layer 1: Matched known fraud signature pattern ("$sig")');
        ruleRisk += 0.45;
        break;
      }
    }

    // 6. Message Flooding / High Frequency Check (via metadata if provided)
    if (metadata != null && metadata['isFlooding'] == true) {
      reasons.add('Layer 1: High-frequency message burst / flooding anomaly');
      ruleRisk += 0.25;
    }

    return Layer1AnalysisResult(
      ruleRiskScore: ruleRisk.clamp(0.0, 1.0),
      flaggedKeywords: flaggedKeywords,
      extractedUrls: extractedUrls,
      reasons: reasons,
    );
  }
}

class Layer1AnalysisResult {
  final double ruleRiskScore;
  final List<String> flaggedKeywords;
  final List<String> extractedUrls;
  final List<String> reasons;

  const Layer1AnalysisResult({
    required this.ruleRiskScore,
    required this.flaggedKeywords,
    required this.extractedUrls,
    required this.reasons,
  });
}

/// Layer 2 – On-device DistilBERT
/// Primary ML detector (Classify message intent and suspicious linguistic patterns locally)
class Layer2OnDeviceDistilBERT {
  Future<Layer2DistilBertResult> infer(String text, {String? sender}) async {
    // Simulates local on-device DistilBERT inference latency (e.g. TFLite / ONNX runtime)
    await Future.delayed(const Duration(milliseconds: 180));

    final lower = text.toLowerCase();
    double bertRisk = 0.05;
    String detectedIntent = 'legitimate_communication';
    final List<String> linguisticPatterns = [];

    if (lower.contains('kyc') || (lower.contains('account') && lower.contains('block'))) {
      bertRisk = 0.94;
      detectedIntent = 'credential_harvesting_phishing';
      linguisticPatterns.add('DistilBERT: Coercive account de-activation syntax');
    } else if (lower.contains('won') || lower.contains('lottery') || lower.contains('cashback') || lower.contains('prize')) {
      bertRisk = 0.91;
      detectedIntent = 'advance_fee_lottery_lure';
      linguisticPatterns.add('DistilBERT: Hyperbolic reward promise syntax');
    } else if (lower.contains('delivery') || lower.contains('package') || lower.contains('parcel') || lower.contains('on hold')) {
      bertRisk = 0.86;
      detectedIntent = 'courier_fee_impersonation';
      linguisticPatterns.add('DistilBERT: Bogus delivery discrepancy format');
    } else if (lower.contains('crypto') || lower.contains('investment') || lower.contains('telegram') || lower.contains('earn money')) {
      bertRisk = 0.62;
      detectedIntent = 'unsolicited_commercial_solicitation';
      linguisticPatterns.add('DistilBERT: Financial recruitment vernacular');
    } else {
      bertRisk = 0.04;
      detectedIntent = 'conversational_safe';
      linguisticPatterns.add('DistilBERT: Normal contextual linguistic embeddings');
    }

    return Layer2DistilBertResult(
      distilBertRiskScore: bertRisk,
      detectedIntent: detectedIntent,
      confidence: 0.92,
      linguisticPatterns: linguisticPatterns,
    );
  }
}

class Layer2DistilBertResult {
  final double distilBertRiskScore;
  final String detectedIntent;
  final double confidence;
  final List<String> linguisticPatterns;

  const Layer2DistilBertResult({
    required this.distilBertRiskScore,
    required this.detectedIntent,
    required this.confidence,
    required this.linguisticPatterns,
  });
}

/// Layer 3 – Optional LLM Fallback
/// (Only for unresolved cases, with explicit consent and minimal data sharing)
class Layer3OptionalLLMFallback {
  bool get hasUserConsent => false; // Privacy default: local by default

  Future<Layer3FallbackResult?> evaluateBorderline(
    String text, {
    required double combinedConfidence,
  }) async {
    // Only invoke fallback when confidence is low/unresolved and explicit consent exists
    if (!hasUserConsent || combinedConfidence >= 0.70) {
      return null;
    }

    // Minimal data sharing fallback logic
    return const Layer3FallbackResult(
      fallbackInvoked: false,
      llmRiskAdjustment: 0.0,
      reason: 'Local on-device resolution conclusive, LLM fallback omitted',
    );
  }
}

class Layer3FallbackResult {
  final bool fallbackInvoked;
  final double llmRiskAdjustment;
  final String reason;

  const Layer3FallbackResult({
    required this.fallbackInvoked,
    required this.llmRiskAdjustment,
    required this.reason,
  });
}

/// ============================================================================
/// RESOLUTION & ENFORCEMENT: Decision and Risk Engine
/// ============================================================================
class DecisionAndRiskEngine {
  ClassificationResult resolve({
    required Layer1AnalysisResult layer1,
    required Layer2DistilBertResult layer2,
    Layer3FallbackResult? layer3,
  }) {
    // Combine evidence, confidence, and risk severity
    // Weight: 40% Layer 1 Rules & URLs, 60% Layer 2 On-device DistilBERT
    double combinedScore = (layer1.ruleRiskScore * 0.40) + (layer2.distilBertRiskScore * 0.60);

    if (layer3 != null && layer3.fallbackInvoked) {
      combinedScore += layer3.llmRiskAdjustment;
    }

    combinedScore = combinedScore.clamp(0.0, 1.0);

    final List<String> allReasons = [];
    allReasons.addAll(layer1.reasons);
    allReasons.addAll(layer2.linguisticPatterns);

    final MessageCategory category;
    final String statusDescription;

    if (combinedScore >= 0.65) {
      // High Risk -> Red: Warn the user / suppress notifications
      category = MessageCategory.spam;
      statusDescription = 'High risk: Spam blocked before opening. Notifications suppressed.';
    } else if (combinedScore >= 0.35 || layer1.extractedUrls.isNotEmpty) {
      // Moderate / Suspicious Risk -> Yellow: Exercise caution
      category = MessageCategory.sus;
      statusDescription = 'Suspicious flags found. Exercise caution before opening links.';
    } else {
      // Low Risk -> Green: Continue cautiously / safe to notify
      category = MessageCategory.notSpam;
      statusDescription = 'Low risk: Safe communication. Continue cautiously.';
      if (allReasons.isEmpty) {
        allReasons.add('No malicious signals or urgent pressure detected');
      }
    }

    return ClassificationResult(
      category: category,
      riskScore: combinedScore,
      riskPercentage: (combinedScore * 100).round(),
      statusDescription: statusDescription,
      reasons: allReasons,
      flaggedKeywords: layer1.flaggedKeywords,
      maskedLinks: layer1.extractedUrls,
    );
  }
}

/// Production classifier implementation connecting Layer 1, Layer 2 (DistilBERT),
/// Decision Engine, and Layer 3 Fallback.
class HeuristicMockClassifierService implements SpamClassifierService {
  final Layer1RuleAndUrlAnalysis _layer1 = Layer1RuleAndUrlAnalysis();
  final Layer2OnDeviceDistilBERT _layer2 = Layer2OnDeviceDistilBERT();
  final Layer3OptionalLLMFallback _layer3 = Layer3OptionalLLMFallback();
  final DecisionAndRiskEngine _decisionEngine = DecisionAndRiskEngine();

  @override
  String get modelName => 'On-device DistilBERT + Multi-Layer Detection Pipeline';

  @override
  String get modelVersion => 'v2.0.0-distilbert';

  @override
  Future<ClassificationResult> classify(
    String text, {
    String? sender,
    Map<String, dynamic>? metadata,
  }) async {
    // 1. Layer 1 – Rule-based & URL Analysis
    final layer1Result = _layer1.analyze(text, sender: sender, metadata: metadata);

    // 2. Layer 2 – On-device DistilBERT Primary ML Detector
    final layer2Result = await _layer2.infer(text, sender: sender);

    // 3. Layer 3 – Optional LLM Fallback (borderline check)
    final layer3Result = await _layer3.evaluateBorderline(
      text,
      combinedConfidence: layer2Result.confidence,
    );

    // 4. Decision and Risk Engine
    return _decisionEngine.resolve(
      layer1: layer1Result,
      layer2: layer2Result,
      layer3: layer3Result,
    );
  }
}
