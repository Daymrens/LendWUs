import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sinking_fund_app/app.dart';

void main() {
  testWidgets('App builds and shows login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: SinkingFundApp(),
      ),
    );

    // Wait for the login screen animation and potential routing
    await tester.pumpAndSettle();

    // Verify that login screen is shown
    // Using findsAtLeastNWidgets because there might be multiple 'LendWUs' (header and title)
    expect(find.text('LendWUs'), findsAtLeastNWidgets(1));
    expect(find.text('Sign In'), findsOneWidget);
  });
}
