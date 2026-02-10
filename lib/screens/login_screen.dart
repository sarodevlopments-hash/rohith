import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import 'registration_screen.dart';
import 'main_tab_screen.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = userCredential.user;

      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        _showError('Authentication failed');
        return;
      }

      // Check if user is registered
      final userService = UserService();
      final appUser = await userService.getUser(user.uid);

      if (appUser == null || !appUser.isRegistered) {
        // First-time user - navigate to registration
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RegistrationScreen(
                email: _emailController.text.trim(),
                firebaseUser: user,
              ),
            ),
          );
        }
      } else {
        // Existing user - check if registered
        final appUser = await userService.getUser(user.uid);
        await userService.updateLastLogin(user.uid);
        
        if (mounted) {
          if (appUser != null && appUser.isRegistered) {
            // User is registered, go to main screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainTabScreen()),
            );
          } else {
            // User exists but not registered, complete registration
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => RegistrationScreen(
                  email: user.email ?? '',
                  firebaseUser: user,
                  isNewUser: false,
                ),
              ),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      String errorMessage = 'Login failed. Please try again.';
      
      if (e.code == 'user-not-found') {
        errorMessage = 'No account found with this email. Please register first.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password. Please try again.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address. Please check and try again.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'This account has been disabled.';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Too many failed attempts. Please try again later.';
      } else if (e.message != null) {
        errorMessage = e.message!;
      }
      
      _showError(errorMessage);
      print('Firebase Auth Error: ${e.code} - ${e.message}');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error signing in: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                
                // Logo/Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Title
                Text(
                  'Welcome Back',
                  style: AppTheme.heading2.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Login to continue',
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 16,
                    color: AppTheme.lightText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AppTheme.getCardDecoration(elevated: true),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Email Input
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: AppTheme.getInputDecoration(
                          label: 'Email / Phone Number',
                          hint: 'your.email@example.com',
                          prefixIcon: Icons.email_rounded,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email or phone';
                          }
                          // Check if it's email or phone
                          final isEmail = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value.trim());
                          if (!isEmail && value.trim().length < 10) {
                            return 'Please enter a valid email or phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Password Input
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: AppTheme.getInputDecoration(
                          label: 'Password',
                          hint: 'Enter your password',
                          prefixIcon: Icons.lock_rounded,
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: AppTheme.lightText,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Forgot Password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            _showError('Forgot password feature coming soon!');
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Forgot Password?',
                            style: AppTheme.bodySmall.copyWith(
                              fontSize: 13,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Login Button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ).copyWith(
                            backgroundColor: MaterialStateProperty.resolveWith<Color>(
                              (Set<MaterialState> states) {
                                if (states.contains(MaterialState.disabled)) {
                                  return AppTheme.disabledText;
                                }
                                return AppTheme.primaryColor;
                              },
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  'Login',
                                  style: AppTheme.heading3.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Sign Up Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: AppTheme.bodyMedium.copyWith(
                        fontSize: 14,
                        color: AppTheme.lightText,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RegistrationScreen(
                              email: '',
                              firebaseUser: null,
                              isNewUser: true,
                            ),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Register',
                        style: AppTheme.bodyMedium.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

