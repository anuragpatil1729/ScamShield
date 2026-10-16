import 'package:flutter_test/flutter_test.dart';
import 'package:scamshield/main.dart';
import 'package:scamshield/services/message_repository.dart';

void main() {
  testWidgets('ScamShield UI smoke test', (WidgetTester tester) async {
    final repository = MessageRepository(enableRemoteSync: false);
    await tester.pumpWidget(ScamShieldApp(repository: repository));
    await tester.pumpAndSettle();

    // Verify app title is displayed
    expect(find.text('ScamShield'), findsOneWidget);

    // Verify filter chips are present
    expect(find.text('All 7'), findsOneWidget);
    expect(find.text('Spam 3'), findsOneWidget);
    expect(find.text('Sus 1'), findsOneWidget);
    expect(find.text('Not spam 3'), findsOneWidget);

    // Verify navigation tabs
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Calls'), findsOneWidget);
    expect(find.text('Shield'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
