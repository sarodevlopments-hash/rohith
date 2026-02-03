import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/main_tab_screen.dart';
import '../screens/login_screen.dart';
import '../screens/registration_screen.dart';
import '../models/app_user.dart';
import '../services/user_service.dart';
import '../services/user_firestore_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          // Check if user is registered (try Hive first, then Firestore)
          return FutureBuilder<AppUser?>(
            future: _getUserWithFallback(user.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final appUser = userSnapshot.data;
              
              // Debug logging
              print('🔍 AuthGate: Checking user registration status');
              print('   - Firebase UID: ${user.uid}');
              print('   - AppUser found: ${appUser != null}');
              if (appUser != null) {
                print('   - AppUser UID: ${appUser.uid}');
                print('   - isRegistered: ${appUser.isRegistered}');
                print('   - fullName: ${appUser.fullName}');
                print('   - email: ${appUser.email}');
              } else {
                print('   - AppUser is null - user not found in storage');
              }
              
              // If user exists and is registered, go to main screen
              if (appUser != null && appUser.isRegistered) {
                print('✅ User is registered - navigating to MainTabScreen');
                return const MainTabScreen();
              }
              
              // If user is logged in but not registered, show registration
              if (appUser == null || !appUser.isRegistered) {
                print('⚠️ User not registered - showing RegistrationScreen');
                print('   - appUser == null: ${appUser == null}');
                if (appUser != null) {
                  print('   - isRegistered value: ${appUser.isRegistered}');
                }
                return RegistrationScreen(
                  email: user.email ?? '',
                  firebaseUser: user,
                  isNewUser: appUser == null,
                );
              }

              print('✅ Default: navigating to MainTabScreen');
              return const MainTabScreen();
            },
          );
        }

        return const LoginScreen(); // ❌ not logged in
      },
    );
  }

  /// Get user from Hive, fallback to Firestore if not found
  static Future<AppUser?> _getUserWithFallback(String uid) async {
    final userService = UserService();
    
    try {
      // Try Hive first (fast)
      final localUser = await userService.getUser(uid);
      if (localUser != null) {
        print('✅ User found in local storage: $uid (registered: ${localUser.isRegistered})');
        // Also sync to Firestore in background (non-blocking)
        UserFirestoreService.upsertUser(localUser).catchError((e) {
          print('⚠️ Background Firestore sync failed: $e');
        });
        return localUser;
      }
      
      // If not in Hive, try Firestore (cloud backup)
      print('🔄 User not found locally, checking Firestore...');
      try {
        final firestoreUser = await UserFirestoreService.getUser(uid)
            .timeout(const Duration(seconds: 5), onTimeout: () {
          print('⏱️ Firestore user fetch timeout - using local data only');
          return null;
        });
        
        if (firestoreUser != null) {
          // Save to Hive for next time
          await userService.saveUser(firestoreUser);
          print('✅ User restored from Firestore: $uid (registered: ${firestoreUser.isRegistered})');
          return firestoreUser;
        }
      } catch (e) {
        print('⚠️ Error fetching user from Firestore: $e');
        print('   Continuing with local data only');
      }
    } catch (e) {
      print('❌ Error in _getUserWithFallback: $e');
    }
    
    print('⚠️ User not found in local storage or Firestore: $uid');
    return null;
  }
}
