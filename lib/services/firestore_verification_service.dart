import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'firestore_helper.dart';

/// Service to verify Firestore database is created and accessible
class FirestoreVerificationService {
  // Try named database first, fallback to default
  static FirebaseFirestore get _db => FirestoreHelper.db;

  /// Verify Firestore database is accessible
  static Future<Map<String, dynamic>> verifyDatabase() async {
    final result = <String, dynamic>{
      'databaseExists': false,
      'isAccessible': false,
      'authentication': false,
      'rulesPublished': false,
      'error': null,
      'details': <String, dynamic>{},
      'databaseId': null,
      'namedDatabaseExists': false,
    };

    try {
      // Check 1: Authentication
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;
      result['authentication'] = currentUser != null;
      result['details']['userId'] = currentUser?.uid;
      result['details']['userEmail'] = currentUser?.email;

      if (currentUser == null) {
        result['error'] = 'User not authenticated';
        return result;
      }

      print('✅ User authenticated: ${currentUser.uid}');

      // Check 1.5: Test if named database exists
      print('🔍 Testing if named database "reqfood" exists...');
      final namedDbExists = await FirestoreHelper.testNamedDatabase();
      result['namedDatabaseExists'] = namedDbExists;
      result['databaseId'] = FirestoreHelper.activeDatabaseId;
      
      if (!namedDbExists) {
        print('⚠️ Named database "reqfood" does not exist - using default database');
        print('   To create it: Firebase Console → Firestore → Create database → Name: "reqfood"');
      } else {
        print('✅ Named database "reqfood" exists');
      }
      print('   Active database: ${FirestoreHelper.activeDatabaseId}');

      // Check 2: Try to read from listings collection (which has rules allowing authenticated reads)
      try {
        print('🔍 Testing Firestore connection...');
        // Use listings collection which has explicit read rules for authenticated users
        await _db
            .collection('listings')
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 10));

        result['databaseExists'] = true;
        result['isAccessible'] = true;
        print('✅ Firestore database is accessible');

        // Check 3: Try to write (test rules) - try creating a test listing with proper key field
        // Note: This will only work if the user is authenticated and has sellerId matching their uid
        try {
          // Create a temporary test listing to verify write permissions
          // Use a negative key to avoid conflicts with real listings
          final testKey = -999999999; // Negative key that won't conflict
          final testListingId = '_verification_test_${DateTime.now().millisecondsSinceEpoch}';
          await _db
              .collection('listings')
              .doc(testListingId)
              .set({
                'key': testKey, // Add key field so it doesn't cause sync warnings
                'sellerId': currentUser.uid,
                'name': '_verification_test',
                'price': 0.01,
                'quantity': 1,
                'type': 'groceries',
                'createdAt': FieldValue.serverTimestamp(),
              })
              .timeout(const Duration(seconds: 10));

          result['rulesPublished'] = true;
          print('✅ Rules are published and working');

          // Clean up test document immediately
          await _db
              .collection('listings')
              .doc(testListingId)
              .delete()
              .timeout(const Duration(seconds: 5));
          
          // Also remove from Hive if it was synced (unlikely but possible)
          try {
            if (Hive.isBoxOpen('listingBox')) {
              final box = Hive.box('listingBox');
              if (box.containsKey(testKey)) {
                await box.delete(testKey);
                print('   ✅ Cleaned up test listing from Hive');
              }
            }
          } catch (e) {
            // Ignore Hive errors - not critical
          }
        } catch (e) {
          result['rulesPublished'] = false;
          result['error'] = 'Write test failed: $e';
          print('❌ Write test failed: $e');
          if (e.toString().contains('permission') || e.toString().contains('Missing')) {
            result['details']['rulesIssue'] = 'Rules are blocking writes - may not be published';
          }
        }
      } on TimeoutException {
        result['error'] = 'Connection timeout - database may not be accessible';
        result['details']['timeout'] = true;
        print('⏱️ Firestore connection timeout');
      } catch (e) {
        result['error'] = 'Connection failed: $e';
        print('❌ Firestore connection failed: $e');
        if (e.toString().contains('unavailable') || e.toString().contains('offline')) {
          result['details']['offline'] = true;
          result['details']['possibleCause'] = 'Rules not published or network issue';
        }
        // Check if it's a database not found error
        if (e.toString().contains('not found') || 
            e.toString().contains('does not exist') ||
            e.toString().contains('NOT_FOUND')) {
          result['details']['databaseNotFound'] = true;
          result['details']['possibleCause'] = 'Database does not exist - create it in Firebase Console';
        }
      }
    } catch (e) {
      result['error'] = 'Verification failed: $e';
      print('❌ Verification failed: $e');
    }

    return result;
  }

  /// Print verification results
  static Future<void> printVerificationReport() async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔍 FIRESTORE DATABASE VERIFICATION');
    print('═══════════════════════════════════════════════════════');
    
    final result = await verifyDatabase();
    
    print('Authentication: ${result['authentication'] ? "✅" : "❌"}');
    if (result['authentication']) {
      print('  User ID: ${result['details']['userId']}');
      final email = result['details']['userEmail'];
      print('  Email: $email');
    }
    
    print('Named Database "reqfood" Exists: ${result['namedDatabaseExists'] ? "✅" : "❌"}');
    print('Active Database: ${result['databaseId'] ?? "unknown"}');
    print('Database Exists: ${result['databaseExists'] ? "✅" : "❌"}');
    print('Database Accessible: ${result['isAccessible'] ? "✅" : "❌"}');
    print('Rules Published: ${result['rulesPublished'] ? "✅" : "❌"}');
    
    if (result['error'] != null) {
      print('Error: ${result['error']}');
    }
    
    if (result['details']['rulesIssue'] != null) {
      print('⚠️ ${result['details']['rulesIssue']}');
    }
    
    if (result['details']['databaseNotFound'] == true) {
      print('⚠️ Database not found - you need to create it');
    }
    
    print('═══════════════════════════════════════════════════════');
    print('');
    
    // Provide recommendations
    if (!result['authentication']) {
      print('💡 Fix: Log in to your app first');
    } else if (result['details']['databaseNotFound'] == true) {
      print('💡 Fix: Create Firestore database in Firebase Console');
      print('   1. Go to: https://console.firebase.google.com/project/resqfood-66b5f/firestore');
      print('   2. Click "Create database"');
      print('   3. Choose "Start in test mode" or "Production mode"');
      print('   4. Select location (e.g., asia-south1)');
      print('   5. If you want named database "reqfood":');
      print('      - After creating default, go to Firestore → Databases');
      print('      - Click "Add database" → Name: "reqfood"');
    } else if (!result['databaseExists']) {
      print('💡 Fix: Go to Firebase Console → Firestore → Create database');
    } else if (!result['isAccessible']) {
      print('💡 Fix: Check network connection and Firestore status');
    } else if (!result['rulesPublished']) {
      print('💡 Fix: Publish security rules in Firebase Console');
      print('   1. Go to: https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules');
      print('   2. Copy rules from firestore.rules file');
      print('   3. Click "Publish"');
    } else {
      print('✅ Everything is working! Firestore is ready to use.');
      print('   Using database: ${result['databaseId']}');
    }
    print('');
  }
}
