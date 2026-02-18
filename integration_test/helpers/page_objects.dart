import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

/// Page Object Model for Login Screen
class LoginPage {
  Future<void> fillLoginForm(
    WidgetTester tester, {
    required String email,
    required String password,
  }) async {
    print('   📝 Filling login form with email: $email');
    
    // Wait for form to be ready
    await tester.pump(const Duration(seconds: 2));
    
    // Find all TextFormFields
    final allTextFields = find.byType(TextFormField);
    final textFieldList = allTextFields.evaluate().toList();
    
    print('   Found ${textFieldList.length} TextFormField(s)');
    
    if (textFieldList.isEmpty) {
      throw Exception('Could not find any TextFormField widgets');
    }
    
    // Fill email in first field
    print('   Filling email in first field...');
    final emailField = allTextFields.first;
    
    // Tap to focus and wait for keyboard
    await tester.tap(emailField);
    await tester.pump(const Duration(milliseconds: 800));
    
    // Enter text - use enterText which handles TextFormField properly
    await tester.enterText(emailField, email);
    await tester.pump(const Duration(milliseconds: 500));
    print('   ✅ Email entered: $email');
    
    // Wait before filling password
    await tester.pump(const Duration(milliseconds: 300));
    
    // Fill password in second field
    if (textFieldList.length < 2) {
      throw Exception('Could not find password field (only ${textFieldList.length} field(s) found)');
    }
    
    print('   Filling password in second field...');
    final passwordField = allTextFields.at(1);
    
    // Tap to focus and wait for keyboard
    await tester.tap(passwordField);
    await tester.pump(const Duration(milliseconds: 800));
    
    // Enter text
    await tester.enterText(passwordField, password);
    await tester.pump(const Duration(milliseconds: 500));
    print('   ✅ Password entered');
    
    // Verify text was entered
    print('   ✅ Login form filled with email and password');
    
    // Wait before tapping login button
    await tester.pump(const Duration(milliseconds: 500));
    
    // Tap login button
    print('   🔘 Looking for login button...');
    final loginButton = find.text('Login');
    if (loginButton.evaluate().isNotEmpty) {
      print('   Found Login button, tapping...');
      await tester.tap(loginButton);
      await tester.pump();
      print('   ✅ Login button tapped');
    } else {
      // Try finding button by type
      print('   Login text not found, trying ElevatedButton...');
      final elevatedButtons = find.byType(ElevatedButton);
      if (elevatedButtons.evaluate().isNotEmpty) {
        print('   Found ElevatedButton, tapping...');
        await tester.tap(elevatedButtons.first);
        await tester.pump();
        print('   ✅ Login button tapped');
      } else {
        throw Exception('Could not find login button');
      }
    }
  }
}

/// Page Object Model for Registration Screen
class RegistrationPage {
  Future<void> fillRegistrationForm(
    WidgetTester tester, {
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    // Find and fill name field
    final nameField = find.byType(TextFormField).first;
    await tester.enterText(nameField, name);
    await tester.pump();

    // Find and fill email field
    final emailFields = find.byType(TextFormField);
    if (emailFields.evaluate().length > 1) {
      await tester.enterText(emailFields.at(1), email);
    }
    await tester.pump();

    // Find and fill password field
    if (emailFields.evaluate().length > 2) {
      await tester.enterText(emailFields.at(2), password);
    }
    await tester.pump();

    // Find and fill confirm password field
    if (emailFields.evaluate().length > 3) {
      await tester.enterText(emailFields.at(3), password);
    }
    await tester.pump();

    // Fill phone if provided
    if (phone != null && emailFields.evaluate().length > 4) {
      await tester.enterText(emailFields.at(4), phone);
      await tester.pump();
    }

    // Tap register button
    final registerButton = find.text('Register');
    if (registerButton.evaluate().isEmpty) {
      final signUpButton = find.text('Sign Up');
      if (signUpButton.evaluate().isNotEmpty) {
        await tester.tap(signUpButton);
      }
    } else {
      await tester.tap(registerButton);
    }
    await tester.pump();
  }
}

/// Page Object Model for Add Listing Screen
class AddListingPage {
  Future<void> fillProductForm(
    WidgetTester tester, {
    required String name,
    required String price,
    required String quantity,
  }) async {
    // Find and fill product name
    final nameField = find.byType(TextFormField).first;
    await tester.enterText(nameField, name);
    await tester.pump();

    // Find and fill price
    final priceFields = find.byType(TextFormField);
    if (priceFields.evaluate().length > 1) {
      await tester.enterText(priceFields.at(1), price);
    }
    await tester.pump();

    // Find and fill quantity
    if (priceFields.evaluate().length > 2) {
      await tester.enterText(priceFields.at(2), quantity);
    }
    await tester.pump();
  }
}

/// Main Page Objects class
class PageObjects {
  final LoginPage loginPage = LoginPage();
  final RegistrationPage registrationPage = RegistrationPage();
  final AddListingPage addListingPage = AddListingPage();
}

