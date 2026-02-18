import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Helper to get Firestore instance with fallback to default database
/// 
/// Tries to use the named database 'reqfood' first.
/// If that fails, falls back to the default database.
class FirestoreHelper {
  static FirebaseFirestore? _cachedInstance;
  static String? _activeDatabaseId;
  
  /// Get Firestore instance, trying named database first, then default
  static FirebaseFirestore get db {
    // If we've already determined which database works, use it
    if (_cachedInstance != null) {
      return _cachedInstance!;
    }
    
    // Try named database first
    try {
      final namedDb = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'reqfood',
      );
      _cachedInstance = namedDb;
      _activeDatabaseId = 'reqfood';
      print('✅ Using named Firestore database: reqfood');
      return namedDb;
    } catch (e) {
      print('⚠️ Named database "reqfood" not available, using default database');
      print('   Error: $e');
      // Fall back to default database
      _cachedInstance = FirebaseFirestore.instance;
      _activeDatabaseId = '(default)';
      print('✅ Using default Firestore database');
      return _cachedInstance!;
    }
  }
  
  /// Get the currently active database ID
  static String? get activeDatabaseId => _activeDatabaseId;
  
  /// Reset cache (useful for testing or reconnection)
  static void reset() {
    _cachedInstance = null;
    _activeDatabaseId = null;
  }
  
  /// Test if named database exists by attempting a read
  static Future<bool> testNamedDatabase() async {
    try {
      final namedDb = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'reqfood',
      );
      // Try a simple read operation
      await namedDb
          .collection('_test')
          .doc('_test')
          .get()
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      // If it's a permission error, the database might exist but rules block it
      // If it's a "not found" or "does not exist" error, the database doesn't exist
      if (e.toString().contains('not found') || 
          e.toString().contains('does not exist') ||
          e.toString().contains('NOT_FOUND')) {
        return false;
      }
      // For other errors (like permission), assume database might exist
      return true;
    }
  }
}

