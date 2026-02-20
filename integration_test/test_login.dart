import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:food_app/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';

import 'helpers/test_helpers.dart';
import 'helpers/page_objects.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Login E2E Test', () {
    late TestHelpers helpers;
    late PageObjects pages;

    setUpAll(() async {
      helpers = TestHelpers();
      pages = PageObjects();
      await helpers.setup();
      
      // Create test user first
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: helpers.testEmail,
          password: helpers.testPassword,
        );
      } catch (e) {
        // User might already exist
        print('Test user might already exist: $e');
      }
    });

    tearDownAll(() async {
      await helpers.cleanup();
    });

    testWidgets('User can login with valid credentials', (WidgetTester tester) async {
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

      // Fill login form
      await pages.loginPage.fillLoginForm(
        tester,
        email: helpers.testEmail,
        password: helpers.testPassword,
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify successful login - should see dashboard
      expect(find.text('Food'), findsWidgets);
    });
  });
}

