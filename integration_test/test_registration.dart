import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:food_app/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';

import 'helpers/test_helpers.dart';
import 'helpers/page_objects.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Registration E2E Test', () {
    late TestHelpers helpers;
    late PageObjects pages;

    setUpAll(() async {
      helpers = TestHelpers();
      pages = PageObjects();
      await helpers.setup();
    });

    tearDownAll(() async {
      await helpers.cleanup();
    });

    testWidgets('User can register a new account', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Log out if already logged in
      try {
        await FirebaseAuth.instance.signOut();
        await tester.pumpAndSettle(const Duration(seconds: 2));
      } catch (e) {
        // Already logged out
      }

      // Navigate to registration if needed
      final registerButton = find.text('Register');
      final signUpButton = find.text('Sign Up');
      
      if (registerButton.evaluate().isEmpty && signUpButton.evaluate().isEmpty) {
        // Try to find navigation to registration
        final signUpLink = find.textContaining('Sign Up');
        if (signUpLink.evaluate().isNotEmpty) {
          await tester.tap(signUpLink.first);
          await tester.pumpAndSettle();
        }
      }

      // Fill registration form
      await pages.registrationPage.fillRegistrationForm(
        tester,
        name: helpers.testName,
        email: helpers.testEmail,
        password: helpers.testPassword,
        phone: '1234567890',
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify successful registration - should see dashboard
      expect(find.text('Food'), findsWidgets);
    });
  });
}

