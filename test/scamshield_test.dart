import 'package:flutter_test/flutter_test.dart';
import 'package:scamshield/main.dart';
import 'package:scamshield/models/message_model.dart';
import 'package:scamshield/screens/message_detail_screen.dart';
import 'package:scamshield/services/classifier_service.dart';
import 'package:scamshield/services/message_repository.dart';

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
        'Join our telegram crypto airdrop channel for guaranteed returns',
        sender: 'CryptoBot',
      );

      expect(result.category, MessageCategory.sus);
      expect(result.riskPercentage, inInclusiveRange(35, 69));
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
      final repo = MessageRepository();
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
  });

  group('Widget Navigation & Detail Rendering Tests', () {
    testWidgets('Tapping a message opens MessageDetailScreen with matching data', (tester) async {
      final repo = MessageRepository();
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
      final repo = MessageRepository();
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
  });
}
