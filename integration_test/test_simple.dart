import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:integration_test/integration_test.dart';
import 'package:food_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Simple App Load Test', (WidgetTester tester) async {
    print('🚀 Starting simple test...');
    
    // Start the app
    app.main();
    
    // Wait for app to initialize
    print('⏳ Waiting for app to initialize...');
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
      print('  Pumped ${i + 1}/5');
    }
    
    // Check what's on screen
    print('📱 Checking screen...');
    final allText = find.byType(Text);
    final textWidgets = allText.evaluate();
    print('Found ${textWidgets.length} text widgets');
    
    // Print first few text widgets
    int count = 0;
    for (final element in textWidgets) {
      if (count >= 10) break;
      try {
        final text = element.widget as Text;
        if (text.data != null && text.data!.isNotEmpty) {
          print('  Text $count: "${text.data}"');
        }
        count++;
      } catch (e) {
        // Skip if not a Text widget
      }
    }
    
    // Try to find common UI elements
    print('🔍 Looking for common UI elements...');
    final loginButton = find.text('Login');
    final registerButton = find.text('Register');
    final createAccountButton = find.text('Create Account');
    
    if (loginButton.evaluate().isNotEmpty) {
      print('✅ Found Login button');
    }
    if (registerButton.evaluate().isNotEmpty) {
      print('✅ Found Register button');
    }
    if (createAccountButton.evaluate().isNotEmpty) {
      print('✅ Found Create Account button');
    }
    
    print('✅ Simple test completed!');
  });
}

