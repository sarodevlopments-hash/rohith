import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/main_tab_screen.dart';
import '../screens/login_screen.dart';
import '../screens/registration_screen.dart';
import '../models/app_user.dart';
import '../services/user_service.dart';

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
          // Check if user is registered
          return FutureBuilder<AppUser?>(
            future: UserService().getUser(user.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final appUser = userSnapshot.data;
              
              // If user exists and is registered, go to main screen
              if (appUser != null && appUser.isRegistered) {
                return const MainTabScreen();
              }
              
              // If user is logged in but not registered, show registration
              if (appUser == null || !appUser.isRegistered) {
                return RegistrationScreen(
                  email: user.email ?? '',
                  firebaseUser: user,
                  isNewUser: appUser == null,
                );
              }

              return const MainTabScreen();
            },
          );
        }

        return const LoginScreen(); // ❌ not logged in
      },
    );
  }
}
