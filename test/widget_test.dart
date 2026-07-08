// VESTRA smoke test: verifies the app boots, shows the splash, and routes into
// onboarding on first launch.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vestra/core/providers/shared_preferences_provider.dart';
import 'package:vestra/main.dart';

void main() {
  testWidgets('VESTRA boots to splash then reaches onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const VestraApp(),
      ),
    );
    await tester.pump();

    // Splash shows the brand mark.
    expect(find.text('VESTRA'), findsOneWidget);

    // Advance past the splash timer and settle the navigation transition.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // First onboarding page is visible.
    expect(find.text('Conheça o seu guarda-roupa'), findsOneWidget);
  });
}
