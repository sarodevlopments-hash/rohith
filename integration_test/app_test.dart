import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:food_app/main.dart' as app;

import 'helpers/test_helpers.dart';
import 'helpers/page_objects.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E Tests - Food App', () {
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

    testWidgets('Complete User Journey: Registration -> Login -> Browse -> Add Product -> Cart -> Order',
        (WidgetTester tester) async {
      // Start the app
      print('🚀 Starting app...');
      app.main();
      
      // Wait for app to initialize (use pump with timeout instead of pumpAndSettle)
      print('⏳ Waiting for app to initialize...');
      await helpers.waitForUI(tester, seconds: 5);
      
      // Check what's on screen
      print('📱 Checking current screen...');
      final allWidgets = find.byType(Widget);
      print('Found ${allWidgets.evaluate().length} widgets on screen');
      
      // Try to find any text to see what screen we're on
      try {
        final allText = find.byType(Text);
        final textWidgets = allText.evaluate();
        print('Found ${textWidgets.length} text widgets');
        if (textWidgets.isNotEmpty) {
          final firstText = textWidgets.first.widget as Text;
          print('First text found: "${firstText.data}"');
        }
      } catch (e) {
        print('Could not read text widgets: $e');
      }

      // Test Registration
      await helpers.testRegistration(tester, pages);
      
      // Test Login
      await helpers.testLogin(tester, pages);
      
      // Test Product Listing
      await helpers.testProductListing(tester, pages);
      
      // Test Distance Filter
      await helpers.testDistanceFilter(tester, pages);
      
      // Test Add Product
      await helpers.testAddProduct(tester, pages);
      
      // Test Add to Cart
      await helpers.testAddToCart(tester, pages);
      
      // Test Order Placement
      await helpers.testOrderPlacement(tester, pages);
    });
  });
}

