import 'dart:math' as math;

import '../models/classification_result.dart';
import '../models/message_model.dart';
import 'v4_spam_model.dart';
import 'rule_scorer.dart';

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
/// DETECTION PIPELINE: LAYER 2 ON-DEVICE DISTILBERT CLASSIFIER
/// ============================================================================

class Layer2OnDeviceDistilBERT {
  final V4SpamModel _model = V4SpamModel();

  Future<Layer2DistilBertResult> infer(
    String text, {
    String? sender,
    Map<String, double>? features,
  }) async {
    final prediction = await _model.classify(text);

    return Layer2DistilBertResult(
      distilBertRiskScore: prediction.spamProbability,
      detectedIntent: prediction.label,
      confidence: math
          .max(prediction.spamProbability, 1 - prediction.spamProbability)
          .toDouble(),
      linguisticPatterns: [
        'DistilBERT v4 ONNX: ${prediction.label} (${(prediction.spamProbability * 100).round()}% spam probability)',
      ],
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

/// ============================================================================
/// LAYER 3 – OPTIONAL LLM FALLBACK
/// ============================================================================
class Layer3OptionalLLMFallback {
  bool get hasUserConsent => false; // Privacy first: local on-device by default

  Future<Layer3FallbackResult?> evaluateBorderline(
    String text, {
    required double combinedConfidence,
  }) async {
    if (!hasUserConsent || combinedConfidence >= 0.70) {
      return null;
    }

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
    required RuleScorerResult layer1,
    Layer2DistilBertResult? layer2,
    Layer3FallbackResult? layer3,
  }) {
    final List<String> allReasons = [];
    final List<String> flaggedKeywords = [];
    final List<String> maskedLinks = [];

    // Extract hits and links from Layer 1
    for (final hit in layer1.scamHits) {
      allReasons.add('Layer 1 [${hit.category}]: ${hit.match}');
      flaggedKeywords.add(hit.match);
      if (hit.category == 'link_lure' || hit.category == 'domain') {
        maskedLinks.add(hit.match);
      }
    }
    for (final hit in layer1.hamHits) {
      allReasons.add('Layer 1 Ham: ${hit.match}');
    }

    // Add Layer 2 linguistic patterns
    allReasons.addAll(layer2?.linguisticPatterns ?? const []);

    final MessageCategory category;
    final double finalRiskScore;
    final String statusDescription;

    // Route decision from Layer 1 Scorer:
    // "not_scam" (route: deliver) only when Layer 1 is confident it is legit:
    // score <= -0.30 AND scam_score < 0.25.
    if (layer1.route == 'deliver') {
      category = MessageCategory.notSpam;
      finalRiskScore = (layer1.scamScore * 0.1).clamp(0.0, 0.15);
      statusDescription =
          'Low risk: Safe message verified by Layer 1. Delivered directly.';
    } else {
      // Forwarded to Layer 2 ML Model
      final layer2Result = layer2!;
      double combined =
          (layer1.scamScore * 0.45) + (layer2Result.distilBertRiskScore * 0.55);

      if (layer3 != null && layer3.fallbackInvoked) {
        combined += layer3.llmRiskAdjustment;
      }

      combined = combined.clamp(0.0, 1.0);
      finalRiskScore = combined;

      if (combined >= 0.70 || layer1.score >= 0.70) {
        // High Risk -> Red: Warn user & suppress notifications
        category = MessageCategory.spam;
        statusDescription = 'High risk: Spam / fraud blocked before opening. Notifications suppressed.';
      } else if (combined >= 0.30 || layer1.scamScore >= 0.30) {
        // Suspicious -> Yellow: Proceed with caution
        category = MessageCategory.sus;
        statusDescription =
            'Suspicious flags found. Exercise caution before opening links.';
      } else {
        // Cleared by Layer 2 ML -> Green: Safe
        category = MessageCategory.notSpam;
        statusDescription =
            'Low risk: Cleared by on-device ML detector. Safe to open.';
      }
    }

    return ClassificationResult(
      category: category,
      riskScore: finalRiskScore,
      riskPercentage: (finalRiskScore * 100).round(),
      statusDescription: statusDescription,
      reasons: allReasons,
      flaggedKeywords: flaggedKeywords,
      maskedLinks: maskedLinks,
      ruleScore: layer1.score,
      layer1Route: layer1.route,
      layer1Hits: layer1.scamHits
          .map((h) => '${h.category}: ${h.match}')
          .toList(),
      features: layer1.features,
    );
  }
}

/// Production multi-layer classifier connecting Layer 1 Rule Scorer,
/// Layer 2 On-device DistilBERT, and Decision Engine.
class HeuristicMockClassifierService implements SpamClassifierService {
  final Layer1RuleScorer _ruleScorer = Layer1RuleScorer();
  final Layer2OnDeviceDistilBERT _layer2 = Layer2OnDeviceDistilBERT();
  final Layer3OptionalLLMFallback _layer3 = Layer3OptionalLLMFallback();
  final DecisionAndRiskEngine _decisionEngine = DecisionAndRiskEngine();

  static const Map<String, String?> defaultVerifiedSenders = {
    'HDFCBK': 'hdfc',
    'SBINB': 'sbi',
    'ICICIB': 'icici',
    'AXISBK': 'axis',
    'PAYTM': 'paytm',
    'AMZNOT': 'amazon',
    'FLPKRT': 'flipkart',
  };

  @override
  String get modelName => 'Layer 1 Rule Scorer + DistilBERT v4 ONNX';

  @override
  String get modelVersion => 'v4-rules-onnx';

  Layer1RuleScorer get ruleScorer => _ruleScorer;

  @override
  Future<ClassificationResult> classify(
    String text, {
    String? sender,
    Map<String, dynamic>? metadata,
  }) async {
    // 1. Layer 1 – Rule-based scam scorer
    final knownContacts =
        (metadata?['known_contacts'] as Iterable<String>?) ?? const [];
    final verifiedSenders =
        (metadata?['verified_senders'] as Map<String, String?>?) ??
        defaultVerifiedSenders;

    final ruleResult = _ruleScorer.scoreMessage(
      text,
      sender: sender,
      knownContacts: knownContacts,
      verifiedSenders: verifiedSenders,
    );

    // 2. Layer 2 – On-device DistilBERT for messages routed onward by Layer 1
    final layer2Result = ruleResult.route == 'deliver'
        ? null
        : await _layer2.infer(
            text,
            sender: sender,
            features: ruleResult.features,
          );

    // 3. Layer 3 – Optional LLM Fallback (borderline check)
    final layer3Result = layer2Result == null
        ? null
        : await _layer3.evaluateBorderline(
            text,
            combinedConfidence: layer2Result.confidence,
          );

    // 4. Decision and Risk Engine
    return _decisionEngine.resolve(
      layer1: ruleResult,
      layer2: layer2Result,
      layer3: layer3Result,
    );
  }
}
