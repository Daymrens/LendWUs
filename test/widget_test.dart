import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinking_fund_app/screens/auth/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders title', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('LendWUs'), findsOneWidget);
    });
  });
}
