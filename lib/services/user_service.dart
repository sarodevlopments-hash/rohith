import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_user.dart';

class UserService {
  static Box<AppUser>? _userBox;

  Future<Box<AppUser>> _getBox() async {
    _userBox ??= await Hive.openBox<AppUser>('usersBox');
    return _userBox!;
  }

  Future<void> saveUser(AppUser user) async {
    final box = await _getBox();
    await box.put(user.uid, user);
  }

  Future<AppUser?> getUser(String uid) async {
    final box = await _getBox();
    return box.get(uid);
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

