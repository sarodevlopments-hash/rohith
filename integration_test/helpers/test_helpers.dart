import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_app/widgets/buyer_listing_card.dart';

import 'page_objects.dart';

class TestHelpers {
  final String testEmail = 'test_${DateTime.now().millisecondsSinceEpoch}@test.com';
  final String testPassword = 'Test123456!';
  final String testName = 'Test User';
  final PageObjects pages = PageObjects();

  /// Wait for UI to stabilize with timeout (safer than pumpAndSettle)
  Future<void> waitForUI(WidgetTester tester, {int seconds = 3}) async {
    for (int i = 0; i < seconds; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  /// Handle notification permission dialog if it appears
  Future<void> handleNotificationPermission(WidgetTester tester) async {
    print('🔔 Checking for notification permission dialog...');
    // Force output flush
    debugPrint('🔔 Checking for notification permission dialog...');
    
    // Wait a bit for dialog to appear
    await tester.pump(const Duration(seconds: 1));
    
    // Look for "Allow" button in notification permission dialog
    final allowButton = find.text('Allow');
    if (allowButton.evaluate().isNotEmpty) {
      print('   Found notification permission dialog, tapping Allow...');
      debugPrint('   Found notification permission dialog, tapping Allow...');
      await tester.tap(allowButton);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      print('   ✅ Notification permission granted');
      debugPrint('   ✅ Notification permission granted');
    } else {
      // Also try finding by text containing "Allow"
      final allowText = find.textContaining('Allow');
      if (allowText.evaluate().isNotEmpty) {
        print('   Found notification permission dialog, tapping Allow...');
        debugPrint('   Found notification permission dialog, tapping Allow...');
        await tester.tap(allowText.first);
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        print('   ✅ Notification permission granted');
        debugPrint('   ✅ Notification permission granted');
      }
    }
  }

  Future<void> setup() async {
    // Initialize Firebase and Hive if needed
    // This is usually done in main.dart, but we ensure it's ready
  }

  Future<void> cleanup() async {
    // Clean up test data
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Delete test user from Firebase Auth
        await user.delete();
      }

      // Delete test data from Firestore
      final firestore = FirebaseFirestore.instance;
      final userDocs = await firestore
          .collection('userProfiles')
          .where('email', isEqualTo: testEmail)
          .get();

      for (var doc in userDocs.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Cleanup error (expected if no test data): $e');
    }
  }

  Future<void> testRegistration(WidgetTester tester, PageObjects pages) async {
    print('🧪 Testing Registration...');
    
    // Wait for app to load (use pump with timeout instead of pumpAndSettle)
    print('⏳ Waiting for UI to stabilize...');
    await waitForUI(tester, seconds: 3);
    
    // Check if we're on login or registration screen
    final loginButton = find.text('Login');
    final registerButton = find.text('Register');
    
    if (registerButton.evaluate().isNotEmpty) {
      // We're on registration screen
      await pages.registrationPage.fillRegistrationForm(
        tester,
        name: testName,
        email: testEmail,
        password: testPassword,
        phone: '1234567890',
      );
      
      await tester.pumpAndSettle(const Duration(seconds: 5));
      
      // Verify we're logged in (should see dashboard)
      expect(find.text('Food'), findsWidgets);
    } else if (loginButton.evaluate().isNotEmpty) {
      // Navigate to registration
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      
      await pages.registrationPage.fillRegistrationForm(
        tester,
        name: testName,
        email: testEmail,
        password: testPassword,
        phone: '1234567890',
      );
      
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }
    
    print('✅ Registration test completed');
  }

  Future<void> loginUser(
    WidgetTester tester, {
    required String email,
    required String password,
  }) async {
    print('🔐 Logging in with email: $email');
    
    // If already logged in, log out first
    try {
      await FirebaseAuth.instance.signOut();
      await waitForUI(tester, seconds: 2);
    } catch (e) {
      // Already logged out
    }
    
    // Handle notification permission dialog if it appears
    await handleNotificationPermission(tester);
    
    // Wait for login screen to be ready
    await waitForUI(tester, seconds: 2);
    
    // Fill and submit login form
    await pages.loginPage.fillLoginForm(tester, email: email, password: password);
    
    // Wait for login to process
    await waitForUI(tester, seconds: 5);
    
    // Handle notification permission again in case it appears after login
    await handleNotificationPermission(tester);
    
    print('✅ Login completed');
  }

  Future<void> testLogin(WidgetTester tester, PageObjects pages) async {
    print('🧪 Testing Login...');
    
    await loginUser(tester, email: testEmail, password: testPassword);
    
    // Verify we're on dashboard
    expect(find.text('Food'), findsWidgets);
    
    print('✅ Login test completed');
  }

  Future<void> testProductListing(WidgetTester tester, PageObjects pages) async {
    print('🧪 Testing Product Listing...');
    
    // Navigate to Food category
    await tester.tap(find.text('Food').first);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    
    // Verify we're on category listing screen
    expect(find.text('Food'), findsWidgets);
    
    // Wait for products to load
    await tester.pumpAndSettle(const Duration(seconds: 3));
    
      // Verify products are displayed
      final productCards = find.byType(BuyerListingCard);
      expect(productCards, findsWidgets);
    
    print('✅ Product listing test completed');
  }

  Future<void> testDistanceFilter(WidgetTester tester, PageObjects pages) async {
    print('🧪 Testing Distance Filter...');
    
    // Tap filter icon
    final filterIcon = find.byIcon(Icons.tune);
    if (filterIcon.evaluate().isNotEmpty) {
      await tester.tap(filterIcon);
      await tester.pumpAndSettle();
      
      // Select distance filter (5 km)
      await tester.tap(find.text('5 km'));
      await tester.pumpAndSettle();
      
      // Apply filters
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      // Verify distance indicator is shown
      expect(find.textContaining('Within'), findsWidgets);
    }
    
    print('✅ Distance filter test completed');
  }

  Future<void> testAddProduct(WidgetTester tester, PageObjects pages) async {
    print('🧪 Testing Add Product...');
    
    // Navigate back to home
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    
    // Navigate to "Start Selling" or Add Listing
    final startSellingButton = find.textContaining('Start Selling');
    if (startSellingButton.evaluate().isEmpty) {
      // Try finding by icon or other means
      final addIcon = find.byIcon(Icons.add);
      if (addIcon.evaluate().isNotEmpty) {
        await tester.tap(addIcon.first);
        await tester.pumpAndSettle();
      }
    } else {
      await tester.tap(startSellingButton.first);
      await tester.pumpAndSettle();
    }
    
    // Select category (e.g., Groceries)
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    
    // Fill product form
    await pages.addListingPage.fillProductForm(
      tester,
      name: 'Test Product ${DateTime.now().millisecondsSinceEpoch}',
      price: '100',
      quantity: '10',
    );
    
    // Submit
    await tester.tap(find.text('Post Item'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    
    print('✅ Add product test completed');
  }

  Future<void> testAddToCart(WidgetTester tester, PageObjects pages) async {
    print('🧪 Testing Add to Cart...');
    
    // Navigate to home
    await tester.tap(find.byIcon(Icons.home).first);
    await tester.pumpAndSettle();
    
    // Navigate to Food category
    await tester.tap(find.text('Food').first);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    
    // Tap on first product
        final productCards = find.byType(BuyerListingCard);
    if (productCards.evaluate().isNotEmpty) {
      await tester.tap(productCards.first);
      await tester.pumpAndSettle();
      
      // Add to cart
      final addToCartButton = find.textContaining('Add to Cart');
      if (addToCartButton.evaluate().isNotEmpty) {
        await tester.tap(addToCartButton.first);
        await tester.pumpAndSettle();
        
        // Verify cart icon shows item count
        expect(find.byIcon(Icons.shopping_cart), findsWidgets);
      }
    }
    
    print('✅ Add to cart test completed');
  }

  Future<void> testOrderPlacement(WidgetTester tester, PageObjects pages) async {
    print('🧪 Testing Order Placement...');
    
    // Navigate to cart
    final cartIcon = find.byIcon(Icons.shopping_cart);
    if (cartIcon.evaluate().isNotEmpty) {
      await tester.tap(cartIcon.first);
      await tester.pumpAndSettle();
      
      // Proceed to checkout
      final checkoutButton = find.textContaining('Checkout');
      if (checkoutButton.evaluate().isNotEmpty) {
        await tester.tap(checkoutButton.first);
        await tester.pumpAndSettle();
        
        // Select address or add new
        final selectAddressButton = find.textContaining('Select Address');
        if (selectAddressButton.evaluate().isNotEmpty) {
          await tester.tap(selectAddressButton.first);
          await tester.pumpAndSettle();
        }
        
        // Place order
        final placeOrderButton = find.textContaining('Place Order');
        if (placeOrderButton.evaluate().isNotEmpty) {
          await tester.tap(placeOrderButton.first);
          await tester.pumpAndSettle(const Duration(seconds: 5));
          
          // Verify order confirmation
          expect(find.textContaining('Order'), findsWidgets);
        }
      }
    }
    
    print('✅ Order placement test completed');
  }
}

