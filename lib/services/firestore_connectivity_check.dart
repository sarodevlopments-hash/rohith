import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to check Firestore connectivity and diagnose issues
class FirestoreConnectivityCheck {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Test Firestore connection by attempting a simple read
  static Future<bool> testConnection() async {
    try {
      // Try to read from a test collection (or any existing collection)
      await _db
          .collection('_test')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      print('❌ Firestore connection test failed: $e');
      return false;
    }
  }

  /// Check if Firestore is properly configured
  static Future<Map<String, dynamic>> diagnose() async {
    final diagnostics = <String, dynamic>{
      'connected': false,
      'error': null,
      'details': <String, dynamic>{},
    };

    try {
      // Test 1: Basic connection
      print('🔍 Testing Firestore connection...');
      final testResult = await testConnection();
      diagnostics['connected'] = testResult;

      if (!testResult) {
        diagnostics['error'] = 'Connection timeout or failed';
        diagnostics['details'] = {
          'possible_causes': [
            'Security rules not published',
            'Firestore not enabled',
            'Network connectivity issues',
            'Firebase project misconfiguration',
          ],
          'solutions': [
            'Go to Firebase Console → Firestore → Rules → Publish',
            'Verify Firestore is enabled in Firebase Console',
            'Check internet connection',
            'Verify firebase_options.dart has correct project ID',
          ],
        };
      } else {
        // Test 2: Try reading from actual collections
        try {
          await _db.collection('listings').limit(1).get().timeout(
            const Duration(seconds: 3),
          );
          diagnostics['details']['listings_readable'] = true;
        } catch (e) {
          diagnostics['details']['listings_readable'] = false;
          diagnostics['details']['listings_error'] = e.toString();
        }

        try {
          await _db.collection('orders').limit(1).get().timeout(
            const Duration(seconds: 3),
          );
          diagnostics['details']['orders_readable'] = true;
        } catch (e) {
          diagnostics['details']['orders_readable'] = false;
          diagnostics['details']['orders_error'] = e.toString();
        }

        try {
          await _db.collection('userProfiles').limit(1).get().timeout(
            const Duration(seconds: 3),
          );
          diagnostics['details']['userProfiles_readable'] = true;
        } catch (e) {
          diagnostics['details']['userProfiles_readable'] = false;
          diagnostics['details']['userProfiles_error'] = e.toString();
        }
      }
    } catch (e) {
      diagnostics['error'] = e.toString();
    }

    return diagnostics;
  }
}

