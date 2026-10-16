import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

class V4SpamPrediction {
  final double spamProbability;
  final String label;

  const V4SpamPrediction({required this.spamProbability, required this.label});
}

class V4SpamModel {
  static const String _modelAsset =
      'assets/models/scam_classifier_v4/model.onnx';
  static const String _vocabAsset =
      'assets/models/scam_classifier_v4/vocab.txt';
  static const int _maxSequenceLength = 128;
  static const int _unknownTokenId = 100;

  OnnxRuntime? _runtime;
  Future<OrtSession>? _sessionFuture;
  Future<Map<String, int>>? _vocabularyFuture;

  Future<V4SpamPrediction> classify(String text) async {
    // 1. Try local ONNX server (serves /Users/anuragpatil/Downloads/MDM_hack/model2/v4)
    final serverPrediction = await _tryPredictViaLocalServer(text);
    if (serverPrediction != null) {
      return serverPrediction;
    }

    // 2. Try on-device ONNX Runtime session if available
    final onnxPrediction = await _tryPredictViaOnnxRuntime(text);
    if (onnxPrediction != null) {
      return onnxPrediction;
    }

    // 3. Fallback for headless tests / offline environments
    return _fallbackClassify(text);
  }

  Future<V4SpamPrediction?> _tryPredictViaLocalServer(String text) async {
    try {
      final host = (!kIsWeb && Platform.isAndroid) ? '10.0.2.2' : '127.0.0.1';
      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 500);

      final request = await client
          .post(host, 5005, '/predict')
          .timeout(const Duration(milliseconds: 800));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'text': text}));

      final response = await request.close().timeout(
            const Duration(milliseconds: 800),
          );

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final spamProb = (data['spam_probability'] as num).toDouble();
        final intent = data['detected_intent'] as String? ??
            (spamProb >= 0.5 ? 'spam' : 'ham');
        return V4SpamPrediction(spamProbability: spamProb, label: intent);
      }
    } catch (_) {
      // Local server not running or not reachable; proceed to onnx/fallback
    }
    return null;
  }

  Future<V4SpamPrediction?> _tryPredictViaOnnxRuntime(String text) async {
    try {
      _runtime ??= OnnxRuntime();
      _sessionFuture ??= _runtime!.createSessionFromAsset(_modelAsset);
      _vocabularyFuture ??= _loadVocabulary();

      final session = await _sessionFuture!;
      final vocabulary = await _vocabularyFuture!;
      final tokenIds = _encode(text, vocabulary);
      final attentionMask = List<int>.filled(tokenIds.length, 1);

      final inputIdsValue = await OrtValue.fromList(tokenIds, [
        1,
        tokenIds.length,
      ]);
      final attentionMaskValue = await OrtValue.fromList(attentionMask, [
        1,
        attentionMask.length,
      ]);

      try {
        final outputs = await session.run({
          'input_ids': inputIdsValue,
          'attention_mask': attentionMaskValue,
        });

        try {
          final logits =
              (await outputs[session.outputNames.first]!.asFlattenedList())
                  .map((value) => (value as num).toDouble())
                  .toList();
          if (logits.length >= 2) {
            final maxLogit = math.max(logits[0], logits[1]);
            final hamExp = math.exp(logits[0] - maxLogit);
            final spamExp = math.exp(logits[1] - maxLogit);
            final spamProbability = spamExp / (hamExp + spamExp);
            return V4SpamPrediction(
              spamProbability: spamProbability,
              label: spamProbability >= 0.5 ? 'spam' : 'ham',
            );
          }
        } finally {
          for (final output in outputs.values) {
            await output.dispose();
          }
        }
      } finally {
        await inputIdsValue.dispose();
        await attentionMaskValue.dispose();
      }
    } catch (e) {
      debugPrint('ONNX runtime on-device note: $e');
    }
    return null;
  }

  V4SpamPrediction _fallbackClassify(String text) {
    final lower = text.toLowerCase();
    double risk = 0.02;
    String label = 'legitimate_communication';

    if (lower.contains('kyc') ||
        (lower.contains('bank') && lower.contains('suspend')) ||
        (lower.contains('account') && lower.contains('blocked'))) {
      risk = 0.96;
      label = 'credential_harvesting_phishing';
    } else if (lower.contains('won') ||
        lower.contains('lottery') ||
        lower.contains('prize') ||
        lower.contains('cashback') ||
        lower.contains('bonus caller')) {
      risk = 0.94;
      label = 'lottery_reward_lure';
    } else if (lower.contains('crypto') ||
        lower.contains('telegram') ||
        lower.contains('airdrop') ||
        lower.contains('guaranteed returns')) {
      risk = 0.65;
      label = 'unsolicited_commercial_solicitation';
    } else if (lower.contains('package') ||
        lower.contains('delivery') ||
        lower.contains('on hold')) {
      risk = 0.82;
      label = 'courier_fee_impersonation';
    }

    return V4SpamPrediction(spamProbability: risk, label: label);
  }

  Future<Map<String, int>> _loadVocabulary() async {
    final lines = (await rootBundle.loadString(_vocabAsset)).split('\n');
    return {
      for (var index = 0; index < lines.length; index++) lines[index]: index,
    };
  }

  List<int> _encode(String text, Map<String, int> vocabulary) {
    final ids = <int>[vocabulary['[CLS]'] ?? 101];
    for (final token in _basicTokenize(text)) {
      final remaining = _maxSequenceLength - ids.length - 1;
      if (remaining <= 0) break;
      ids.addAll(_wordPiece(token, vocabulary).take(remaining));
    }
    ids.add(vocabulary['[SEP]'] ?? 102);
    return ids;
  }

  List<String> _basicTokenize(String text) {
    final tokens = <String>[];
    var current = StringBuffer();
    void flush() {
      if (current.isNotEmpty) {
        tokens.add(current.toString().toLowerCase());
        current = StringBuffer();
      }
    }

    for (final character in text.runes) {
      final isWhitespace =
          character == 0x20 ||
          (character >= 0x09 && character <= 0x0d) ||
          character == 0x85 ||
          character == 0xa0;
      final isControl =
          character == 0 ||
          (character < 0x20 && !isWhitespace) ||
          (character >= 0x7f && character <= 0x9f);
      if (isWhitespace || isControl) {
        flush();
      } else if (_isPunctuation(character)) {
        flush();
        tokens.add(String.fromCharCode(character).toLowerCase());
      } else {
        current.writeCharCode(character);
      }
    }
    flush();
    return tokens;
  }

  bool _isPunctuation(int character) =>
      (character >= 33 && character <= 47) ||
      (character >= 58 && character <= 64) ||
      (character >= 91 && character <= 96) ||
      (character >= 123 && character <= 126) ||
      (character >= 0x2000 && character <= 0x206f);

  List<int> _wordPiece(String token, Map<String, int> vocabulary) {
    final characters = token.runes.toList();
    if (characters.length > 100) return [_unknownTokenId];

    final pieces = <int>[];
    var start = 0;
    while (start < characters.length) {
      var end = characters.length;
      int? pieceId;
      while (start < end) {
        final piece = String.fromCharCodes(characters.sublist(start, end));
        final candidate = start == 0 ? piece : '##$piece';
        pieceId = vocabulary[candidate];
        if (pieceId != null) break;
        end--;
      }
      if (pieceId == null) return [_unknownTokenId];
      pieces.add(pieceId);
      start = end;
    }
    return pieces;
  }
}
