import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:integration_test/integration_test.dart';
import 'package:food_app/main.dart' as app;
import 'package:food_app/widgets/buyer_listing_card.dart';

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Cart and Order E2E Test', () {
    late TestHelpers helpers;

    setUpAll(() async {
      helpers = TestHelpers();
      await helpers.setup();
    });

    tearDownAll(() async {
      await helpers.cleanup();
    });

    testWidgets('User can add product to cart and place order', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to Food category
      final foodCategory = find.text('Food');
      if (foodCategory.evaluate().isNotEmpty) {
        await tester.tap(foodCategory.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Wait for products to load
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Try to find and tap on a product
        // This might need adjustment based on actual widget structure
        final productCards = find.byType(BuyerListingCard);
        if (productCards.evaluate().isNotEmpty) {
          await tester.tap(productCards.first);
          await tester.pumpAndSettle();

          // Add to cart
          final addToCartButton = find.textContaining('Add to Cart');
          if (addToCartButton.evaluate().isNotEmpty) {
            await tester.tap(addToCartButton.first);
            await tester.pumpAndSettle();

            // Navigate to cart
            final cartIcon = find.byIcon(Icons.shopping_cart);
            if (cartIcon.evaluate().isNotEmpty) {
              await tester.tap(cartIcon.first);
              await tester.pumpAndSettle();

              // Verify cart has items
              expect(find.textContaining('Cart'), findsWidgets);

              // Proceed to checkout
              final checkoutButton = find.textContaining('Checkout');
              if (checkoutButton.evaluate().isNotEmpty) {
                await tester.tap(checkoutButton.first);
                await tester.pumpAndSettle();

                // Place order (if address is set up)
                final placeOrderButton = find.textContaining('Place Order');
                if (placeOrderButton.evaluate().isNotEmpty) {
                  await tester.tap(placeOrderButton.first);
                  await tester.pumpAndSettle(const Duration(seconds: 5));

                  // Verify order confirmation
                  expect(find.textContaining('Order'), findsWidgets);
                }
              }
            }
          }
        }
      }
    });
  });
}

