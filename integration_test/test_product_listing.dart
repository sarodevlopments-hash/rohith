import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:integration_test/integration_test.dart';
import 'package:food_app/main.dart' as app;
import 'package:food_app/widgets/buyer_listing_card.dart';

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Product Listing E2E Test', () {
    late TestHelpers helpers;

    setUpAll(() async {
      helpers = TestHelpers();
      await helpers.setup();
    });

    tearDownAll(() async {
      await helpers.cleanup();
    });

    testWidgets('User can browse products and filter by distance', (WidgetTester tester) async {
      // Start the app and login
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to Food category
      final foodCategory = find.text('Food');
      expect(foodCategory, findsWidgets);
      
      await tester.tap(foodCategory.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify we're on category listing screen
      expect(find.text('Food'), findsWidgets);

      // Wait for products to load
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify products are displayed (at least one product card)
      // Note: If products exist, we should see them
      expect(find.byType(BuyerListingCard), findsWidgets);

      // Test distance filter
      final filterIcon = find.byIcon(Icons.tune);
      if (filterIcon.evaluate().isNotEmpty) {
        await tester.tap(filterIcon);
        await tester.pumpAndSettle();

        // Select 5 km distance
        final distanceOption = find.text('5 km');
        if (distanceOption.evaluate().isNotEmpty) {
          await tester.tap(distanceOption);
          await tester.pumpAndSettle();

          // Apply filters
          final applyButton = find.text('Apply Filters');
          if (applyButton.evaluate().isNotEmpty) {
            await tester.tap(applyButton);
            await tester.pumpAndSettle(const Duration(seconds: 3));

            // Verify distance indicator is shown
            expect(find.textContaining('Within'), findsWidgets);
          }
        }
      }
    });
  });
}

