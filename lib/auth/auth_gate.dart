import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/main_tab_screen.dart';
import '../screens/login_screen.dart';
import '../screens/registration_screen.dart';
import '../services/user_firestore_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Cache the future per user to avoid multiple calls
  Future<bool>? _cachedDocumentCheck;
  String? _cachedUserId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking authentication state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user is NOT authenticated → show Login screen
        if (!snapshot.hasData || snapshot.data == null) {
          print('🔐 AuthGate: No authenticated user - showing LoginScreen');
          // Clear cache when user logs out
          _cachedDocumentCheck = null;
          _cachedUserId = null;
          return const LoginScreen();
        }

        // User IS authenticated → check if user document exists in Firestore
        final firebaseUser = snapshot.data!;
        print('🔍 AuthGate: User authenticated (UID: ${firebaseUser.uid})');
        print('   Checking if user document exists in Firestore...');

        // Cache the future per user to avoid multiple calls
        if (_cachedUserId != firebaseUser.uid) {
          _cachedUserId = firebaseUser.uid;
          _cachedDocumentCheck = _checkUserDocumentExists(firebaseUser.uid);
        }

        return FutureBuilder<bool>(
          future: _cachedDocumentCheck,
          builder: (context, docSnapshot) {
            // Show loading while checking Firestore
            if (docSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Check for errors first
            if (docSnapshot.hasError) {
              print('❌ AuthGate: Error checking user document: ${docSnapshot.error}');
              // On error, show registration (safer default)
              return RegistrationScreen(
                email: firebaseUser.email ?? '',
                firebaseUser: firebaseUser,
                isNewUser: true,
              );
            }

            final userDocumentExists = docSnapshot.data ?? false;
            print('🔍 AuthGate: FutureBuilder result - userDocumentExists: $userDocumentExists');
            print('   - hasData: ${docSnapshot.hasData}');
            print('   - data value: ${docSnapshot.data}');

            if (userDocumentExists) {
              // User document exists in Firestore → go directly to Dashboard
              print('✅ AuthGate: User document found - navigating to MainTabScreen');
              return const MainTabScreen();
            } else {
              // User document does NOT exist → show Registration screen
              print('⚠️ AuthGate: User document NOT found - showing RegistrationScreen');
              print('   This is a first-time user or user needs to complete registration');
              return RegistrationScreen(
                email: firebaseUser.email ?? '',
                firebaseUser: firebaseUser,
                isNewUser: true,
              );
            }
          },
        );
      },
    );
  }

  /// Check if user document exists in Firestore userProfiles collection
  /// Returns true if document exists, false otherwise
  static Future<bool> _checkUserDocumentExists(String userId) async {
    try {
      print('🔍 Checking Firestore for user document: $userId');
      
      // Check if user is authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('⚠️ No authenticated user - cannot check Firestore');
        return false;
      }

      // Check Firestore for user document
      DocumentSnapshot<Map<String, dynamic>>? docSnapshot;
      try {
        docSnapshot = await UserFirestoreService.doc(userId)
            .get()
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        if (e is TimeoutException) {
          print('⏱️ Firestore check timeout - assuming document does not exist');
          return false;
        }
        rethrow;
      }

      if (docSnapshot.exists && docSnapshot.data() != null) {
        print('✅ User document EXISTS in Firestore: $userId');
        return true;
      }

      print('ℹ️ User document does NOT exist in Firestore: $userId');
      return false;
    } catch (e) {
      print('❌ Error checking user document existence: $e');
      
      // On permission errors, assume document doesn't exist (safer to show registration)
      if (e.toString().contains('permission') || 
          e.toString().contains('Missing or insufficient')) {
        print('⚠️ Permission denied - assuming document does not exist');
        return false;
      }
      
      // On other errors, also assume document doesn't exist (safer default)
      return false;
    }
  }
}
