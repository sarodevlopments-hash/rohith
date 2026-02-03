import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_user.dart';
import 'user_firestore_service.dart';

class UserService {
  static Box<AppUser>? _userBox;

  Future<Box<AppUser>> _getBox() async {
    _userBox ??= await Hive.openBox<AppUser>('usersBox');
    return _userBox!;
  }

  Future<void> saveUser(AppUser user) async {
    try {
      final box = await _getBox();
      
      // Log before saving
      print('🔄 UserService.saveUser called:');
      print('   - UID: ${user.uid}');
      print('   - isRegistered: ${user.isRegistered}');
      print('   - fullName: ${user.fullName}');
      print('   - email: ${user.email}');
      
      // Save to Hive
      await box.put(user.uid, user);
      print('✅ User saved to Hive: ${user.uid} (isRegistered: ${user.isRegistered})');
      
      // Force flush to ensure data is written to disk
      await box.flush();
      print('✅ Hive box flushed to disk');
      
      // Verify it was saved correctly
      final savedUser = box.get(user.uid);
      if (savedUser != null) {
        print('✅ Verified user in Hive:');
        print('   - UID: ${savedUser.uid}');
        print('   - isRegistered: ${savedUser.isRegistered}');
        print('   - fullName: ${savedUser.fullName}');
        
        // Critical check: ensure isRegistered flag is correct
        if (savedUser.isRegistered != user.isRegistered) {
          print('❌ CRITICAL MISMATCH: Saved user has isRegistered=${savedUser.isRegistered}, but expected ${user.isRegistered}');
          print('   Attempting to correct by saving again...');
          // Save again with explicit isRegistered value
          final correctedUser = savedUser.copyWith(isRegistered: user.isRegistered);
          await box.put(user.uid, correctedUser);
          await box.flush();
          // Verify again
          final reSavedUser = box.get(user.uid);
          if (reSavedUser != null && reSavedUser.isRegistered == user.isRegistered) {
            print('✅ User corrected: isRegistered is now ${reSavedUser.isRegistered}');
          } else {
            print('❌ ERROR: Failed to correct isRegistered flag');
          }
        } else {
          print('✅ isRegistered flag matches expected value: ${savedUser.isRegistered}');
        }
      } else {
        print('❌ ERROR: User not found in Hive after saving!');
        print('   Box length: ${box.length}');
        print('   Box keys: ${box.keys.toList()}');
      }
      
      // ✅ Sync to Firestore for cloud persistence (non-blocking)
      UserFirestoreService.upsertUser(user).catchError((e) {
        print('⚠️ Firestore user sync failed (user saved locally): $e');
      });
    } catch (e) {
      print('❌ Error saving user to Hive: $e');
      rethrow;
    }
  }

  Future<AppUser?> getUser(String uid) async {
    try {
      print('🔍 UserService.getUser called for UID: $uid');
      final box = await _getBox();
      print('   Box opened successfully, length: ${box.length}');
      
      final user = box.get(uid);
      if (user != null) {
        print('✅ User found in Hive:');
        print('   - UID: ${user.uid}');
        print('   - isRegistered: ${user.isRegistered}');
        print('   - fullName: ${user.fullName}');
        print('   - email: ${user.email}');
        print('   - createdAt: ${user.createdAt}');
        print('   - lastLoginAt: ${user.lastLoginAt}');
      } else {
        print('⚠️ User not found in Hive: $uid');
        // Debug: List all users in box
        print('   Total users in Hive: ${box.length}');
        if (box.length > 0) {
          print('   Users in box:');
          for (var key in box.keys) {
            final u = box.get(key);
            if (u != null) {
              print('   - Key: $key, UID: ${u.uid}, isRegistered: ${u.isRegistered}, fullName: ${u.fullName}');
            }
          }
        } else {
          print('   Box is empty');
        }
      }
      return user;
    } catch (e) {
      print('❌ Error getting user from Hive: $e');
      return null;
    }
  }

  Future<AppUser?> getCurrentUser() async {
    final box = await _getBox();
    if (box.isEmpty) return null;
    // Get the most recently logged in user
    AppUser? latestUser;
    DateTime? latestLogin;
    
    for (var user in box.values) {
      if (user.lastLoginAt != null) {
        if (latestLogin == null || user.lastLoginAt!.isAfter(latestLogin)) {
          latestLogin = user.lastLoginAt;
          latestUser = user;
        }
      }
    }
    
    return latestUser ?? box.values.firstOrNull;
  }

  Future<void> updateLastLogin(String uid) async {
    final user = await getUser(uid);
    if (user != null) {
      final updatedUser = user.copyWith(lastLoginAt: DateTime.now());
      await saveUser(updatedUser);
    }
  }

  Future<void> updateUser(AppUser user) async {
    await saveUser(user);
  }

  Future<bool> isUserRegistered(String uid) async {
    final user = await getUser(uid);
    return user?.isRegistered ?? false;
  }

  Future<void> deleteUser(String uid) async {
    final box = await _getBox();
    await box.delete(uid);
  }
}

