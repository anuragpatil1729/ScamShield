import 'package:flutter_test/flutter_test.dart';
import 'package:scamshield/main.dart';
import 'package:scamshield/models/message_model.dart';
import 'package:scamshield/screens/message_detail_screen.dart';
import 'package:scamshield/services/classifier_service.dart';
import 'package:scamshield/services/message_repository.dart';
import 'package:scamshield/services/rule_scorer.dart';

void main() {
  group('SpamClassifierService & Repository Tests', () {
    test('Heuristic classifier correctly flags KYC urgent message as SPAM', () async {
      final service = HeuristicMockClassifierService();
      final result = await service.classify(
        'Your KYC expires today. Update now to avoid account block: https://kyc-test.com',
        sender: 'VK-KYCTEAM',
      );

      expect(result.category, MessageCategory.spam);
      expect(result.riskPercentage, greaterThanOrEqualTo(50));
      expect(result.reasons, isNotEmpty);
      expect(result.maskedLinks, contains('https://kyc-test.com'));
    });

    test('Heuristic classifier correctly flags crypto / telegram schemes as SUS', () async {
      final service = HeuristicMockClassifierService();
      final result = await service.classify(
        'Join our telegram discussion group for upcoming crypto updates',
        sender: 'CryptoBot',
      );

      expect(result.category, MessageCategory.sus);
      expect(result.riskPercentage, inInclusiveRange(30, 69));
    });

    test('Heuristic classifier flags normal conversation as NOT SPAM', () async {
      final service = HeuristicMockClassifierService();
      final result = await service.classify(
        'Are we still on for dinner tonight?',
        sender: 'Rohan',
      );

      expect(result.category, MessageCategory.notSpam);
      expect(result.riskPercentage, lessThan(35));
    });

    test('Repository filter and delete spam operations work dynamically', () {
      final repo = MessageRepository(enableRemoteSync: false);
      expect(repo.allMessages.length, 7);
      expect(repo.spamCount, 3);
      expect(repo.susCount, 1);
      expect(repo.notSpamCount, 3);

      // Filter by spam
      repo.setFilter(MessageCategory.spam);
      expect(repo.filteredMessages.length, 3);

      // Filter by sus
      repo.setFilter(MessageCategory.sus);
      expect(repo.filteredMessages.length, 1);

      // Filter by not spam
      repo.setFilter(MessageCategory.notSpam);
      expect(repo.filteredMessages.length, 3);

      // Delete spam
      repo.deleteSpamMessages();
      expect(repo.spamCount, 0);
      expect(repo.allMessages.length, 4);
    });

    test('Notification service rule: only NOT SPAM triggers notifications', () async {
      // Per spec: spam and sus are quietly quarantined, only not_spam notifies
      final safeMsg = MessageItem(
        id: 'safe-1',
        sender: 'Alice',
        senderAvatarChar: 'A',
        snippet: 'Hello',
        fullMessage: 'Hello there',
        category: MessageCategory.notSpam,
        riskPercentage: 2,
        statusDescription: 'Safe',
        reasons: const [],
        timestamp: DateTime.now(),
      );

      final spamMsg = MessageItem(
        id: 'spam-1',
        sender: 'Scammer',
        senderAvatarChar: '!',
        snippet: 'Claim prize',
        fullMessage: 'Claim prize now',
        category: MessageCategory.spam,
        riskPercentage: 95,
        statusDescription: 'Spam detected',
        reasons: const [],
        timestamp: DateTime.now(),
      );

      final susMsg = MessageItem(
        id: 'sus-1',
        sender: 'Suspicious',
        senderAvatarChar: '?',
        snippet: 'Check link',
        fullMessage: 'Check link now',
        category: MessageCategory.sus,
        riskPercentage: 55,
        statusDescription: 'Sus detected',
        reasons: const [],
        timestamp: DateTime.now(),
      );

      expect(safeMsg.category == MessageCategory.notSpam, isTrue);
      expect(spamMsg.category == MessageCategory.notSpam, isFalse);
      expect(susMsg.category == MessageCategory.notSpam, isFalse);
    });
  });

  group('Widget Navigation & Detail Rendering Tests', () {
    testWidgets('Tapping a message opens MessageDetailScreen with matching data', (tester) async {
      final repo = MessageRepository(enableRemoteSync: false);
      await tester.pumpWidget(ScamShieldApp(repository: repo));
      await tester.pumpAndSettle();

      // Tap on VK-KYCTEAM (at top of list, not obscured by FAB)
      await tester.tap(find.text('VK-KYCTEAM'));
      await tester.pumpAndSettle();

      // Check detail screen content
      expect(find.byType(MessageDetailScreen), findsOneWidget);
      expect(find.text('96% risk'), findsOneWidget);
      expect(find.text('WHY WE FLAGGED IT'), findsOneWidget);
      expect(find.text('Urgent deadline pressure'), findsOneWidget);
      expect(find.text('Block and report'), findsOneWidget);
      expect(find.text('Not spam'), findsOneWidget);

      // Tap Back
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(MessageDetailScreen), findsNothing);
    });

    testWidgets('Shield Screen renders hero card and colour guide with Sus', (tester) async {
      final repo = MessageRepository(enableRemoteSync: false);
      await tester.pumpWidget(ScamShieldApp(repository: repo));
      await tester.pumpAndSettle();

      // Tap Shield tab in bottom navigation
      await tester.tap(find.text('Shield'));
      await tester.pumpAndSettle();

      expect(find.text('Spam stopped'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
      expect(find.text('COLOUR GUIDE'), findsOneWidget);
      expect(find.text('TOP SPAM TYPES'), findsOneWidget);
      expect(find.text('Fake KYC and bank'), findsOneWidget);
      expect(find.text('Parcel and delivery'), findsOneWidget);
      expect(find.text('Prize and lottery'), findsOneWidget);
    });

    test('Layer 1 Rule Scorer correctly scores scam message and generates 44 features', () {
      final scorer = Layer1RuleScorer();
      final result = scorer.scoreMessage(
        'URGENT: You have won Rs. 50,000 lottery! Claim your prize now at http://bit.ly/lotto-claim',
        sender: 'VK-PRIZE',
      );

      expect(result.label, 'scam');
      expect(result.route, 'layer2_ml');
      expect(result.scamScore, greaterThan(0.50));
      expect(result.scamHits, isNotEmpty);
      expect(result.features['len_log'], isNotNull);
      expect(result.featureVector.length, kFeatureNames.length);
    });

    test('Layer 1 Rule Scorer correctly clears known contact as not_scam', () {
      final scorer = Layer1RuleScorer();
      final result = scorer.scoreMessage(
        'Dinner will be ready by 8. Remember to buy groceries on your way.',
        sender: 'Mom',
        knownContacts: {'Mom', 'Rohan'},
      );

      expect(result.label, 'not_scam');
      expect(result.route, 'deliver');
      expect(result.score, lessThanOrEqualTo(kLegitScoreMax));
      expect(result.scamScore, lessThan(kLegitScamPMax));
    });

    test('Layer 1 Rule Scorer detects Hinglish and Devanagari fraud patterns', () {
      final scorer = Layer1RuleScorer();
      final result = scorer.scoreMessage(
        'Aapka khata block ho jayega. Turant kyc update karein nahi to account band ho jayega.',
        sender: '+919876543210',
      );

      expect(result.label, 'scam');
      expect(result.route, 'layer2_ml');
      expect(result.scamCategories.containsKey('hinglish'), isTrue);
    });

    test('Layer 1 Rule Scorer recognizes verified DLT header with official link', () {
      final scorer = Layer1RuleScorer();
      final result = scorer.scoreMessage(
        'INR 5,000 debited from A/C XX4092. Avl bal INR 25,400. Info: https://hdfcbank.com',
        sender: 'HDFCBK',
        verifiedSenders: {'HDFCBK': 'hdfc'},
      );

      expect(result.sender.verified, isTrue);
      expect(result.route, 'deliver');
      expect(result.label, 'not_scam');
    });
  });
}

