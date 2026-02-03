import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/app_user.dart';

/// Service to sync user profiles with Firestore for cloud persistence
class UserFirestoreService {
  // Use the correct database ID: 'reqfood' (not the default)
  static FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'reqfood',
  );
  static const String _collection = 'userProfiles';

  /// Get document reference for a user
  static DocumentReference<Map<String, dynamic>> doc(String userId) {
    return _db.collection(_collection).doc(userId);
  }

  /// Convert AppUser to Firestore map
  static Map<String, dynamic> toMap(AppUser user) {
    return {
      'uid': user.uid,
      'fullName': user.fullName,
      'email': user.email,
      'phoneNumber': user.phoneNumber,
      'createdAt': user.createdAt.toUtc(),
      'lastLoginAt': user.lastLoginAt?.toUtc(),
      'isRegistered': user.isRegistered,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convert Firestore map back to AppUser
  static AppUser? fromMap(Map<String, dynamic> data) {
    try {
      DateTime _dt(dynamic v) {
        if (v == null) return DateTime.now();
        if (v is Timestamp) return v.toDate();
        if (v is DateTime) return v;
        return DateTime.tryParse(v.toString()) ?? DateTime.now();
      }

      return AppUser(
        uid: data['uid'] as String? ?? '',
        fullName: data['fullName'] as String? ?? '',
        email: data['email'] as String? ?? '',
        phoneNumber: data['phoneNumber'] as String? ?? '',
        createdAt: _dt(data['createdAt']),
        lastLoginAt: data['lastLoginAt'] == null ? null : _dt(data['lastLoginAt']),
        isRegistered: data['isRegistered'] as bool? ?? false,
      );
    } catch (e) {
      print('❌ Error converting Firestore data to AppUser: $e');
      return null;
    }
  }

  /// Save/update user profile to Firestore
  static Future<void> upsertUser(AppUser user) async {
    try {
      // Check authentication
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        print('⚠️ No authenticated user - cannot sync to Firestore');
        return;
      }
      if (currentUser.uid != user.uid) {
        print('⚠️ User UID mismatch - cannot sync to Firestore');
        return;
      }
      
      print('🔍 Syncing user to Firestore: ${user.uid}');
      await doc(user.uid)
          .set(toMap(user), SetOptions(merge: true))
          .timeout(
            const Duration(seconds: 10), // Increased timeout
            onTimeout: () {
              print('⏱️ Firestore user sync timeout for: ${user.uid}');
              throw TimeoutException('Firestore sync timed out');
            },
          );
      print('✅ User profile synced to Firestore: ${user.uid}');
    } on TimeoutException {
      print('⏱️ Firestore user sync timed out - user saved locally only');
      print('💡 Wait 1-2 minutes after publishing rules for propagation');
      _printCriticalInstructions();
    } catch (e) {
      print('❌ Error syncing user to Firestore: $e');
      if (e.toString().contains('unavailable') || e.toString().contains('offline')) {
        print('🔴 CRITICAL: Firestore reports "offline"');
        print('   - Rules may not be published yet');
        print('   - Wait 1-2 minutes after publishing for propagation');
      }
      if (e.toString().contains('permission') || e.toString().contains('Missing or insufficient')) {
        print('🔴 CRITICAL: Permission denied - rules are blocking!');
        print('   - Verify rules are published');
        print('   - Check "Last published" timestamp');
      }
      _printCriticalInstructions();
    }
  }

  /// Get user profile from Firestore
  static Future<AppUser?> getUser(String userId) async {
    try {
      // Check authentication first
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        print('⚠️ No authenticated user - cannot fetch from Firestore');
        return null;
      }
      print('🔍 Fetching user from Firestore (authenticated as: ${currentUser.uid})');
      
      final docSnapshot = await doc(userId)
          .get()
          .timeout(const Duration(seconds: 10)); // Increased timeout for rules propagation
      
      if (docSnapshot.exists && docSnapshot.data() != null) {
        print('✅ User found in Firestore: $userId');
        return fromMap(docSnapshot.data()!);
      }
      print('ℹ️ User not found in Firestore: $userId (this is OK for new users)');
      return null;
    } on TimeoutException {
      print('⏱️ Firestore user fetch timeout for $userId');
      print('💡 Possible causes:');
      print('   1. Rules not published (check "Last published" timestamp)');
      print('   2. Rules propagation delay (wait 1-2 minutes after publishing)');
      print('   3. Network/firewall blocking Firestore');
      _printCriticalInstructions();
      return null;
    } catch (e) {
      print('❌ Error fetching user from Firestore: $e');
      if (e.toString().contains('unavailable') || e.toString().contains('offline')) {
        print('🔴 CRITICAL: Firestore reports "offline"');
        print('   - Rules may not be published yet');
        print('   - Wait 1-2 minutes after publishing for propagation');
      }
      if (e.toString().contains('permission') || e.toString().contains('Missing or insufficient')) {
        print('🔴 CRITICAL: Permission denied - rules are blocking access!');
        print('   - Verify rules are published');
        print('   - Check "Last published" timestamp in Firebase Console');
      }
      _printCriticalInstructions();
      return null;
    }
  }

  static void _printCriticalInstructions() {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔴 RULES NOT PUBLISHED - DO THIS NOW:');
    print('═══════════════════════════════════════════════════════');
    print('1. Go to: https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules');
    print('2. Look for "Publish" button (top right, blue button)');
    print('3. Click "Publish" (NOT "Save"!)');
    print('4. Wait for "Rules published successfully"');
    print('5. Verify: Top of page shows "Last published: [time]"');
    print('6. Wait 1-2 minutes for rules to propagate');
    print('7. Restart your app');
    print('═══════════════════════════════════════════════════════');
    print('');
  }

}

