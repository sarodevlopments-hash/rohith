import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../services/user_service.dart';
import 'main_tab_screen.dart';
import '../theme/app_theme.dart';

class RegistrationScreen extends StatefulWidget {
  final String email;
  final User? firebaseUser; // null if new user, not null if coming from login
  final bool isNewUser; // true if user is creating new account

  const RegistrationScreen({
    super.key,
    this.email = '',
    this.firebaseUser,
    this.isNewUser = false,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.email.isNotEmpty) {
      _emailController.text = widget.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      User? firebaseUser = widget.firebaseUser;
      
      // If new user, create Firebase account first
      if (widget.isNewUser || firebaseUser == null) {
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        firebaseUser = userCredential.user;
        
        if (firebaseUser == null) {
          setState(() {
            _isLoading = false;
          });
          _showError('Failed to create account');
          return;
        }
      }

      final userService = UserService();
      
      // Format phone number if provided
      String? phoneNumber;
      if (_phoneController.text.trim().isNotEmpty) {
        phoneNumber = _phoneController.text.trim();
        if (!phoneNumber.startsWith('+')) {
          phoneNumber = '+91$phoneNumber'; // Default to India (+91)
        }
      }

      // Create or update user profile
      final existingUser = await userService.getUser(firebaseUser.uid);
      final appUser = existingUser?.copyWith(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: phoneNumber ?? existingUser.phoneNumber,
        lastLoginAt: DateTime.now(),
        isRegistered: true,
      ) ?? AppUser(
        uid: firebaseUser.uid,
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: phoneNumber ?? '',
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        isRegistered: true,
      );

      // Save user profile (to both Hive and Firestore)
      print('🔄 Saving user to Hive: ${appUser.uid} (isRegistered: ${appUser.isRegistered})');
      await userService.saveUser(appUser);
      print('✅ User registration saved: ${appUser.uid} (isRegistered: ${appUser.isRegistered})');

      // Verify the user was saved correctly
      final verifyUser = await userService.getUser(firebaseUser.uid);
      if (verifyUser != null) {
        print('✅ Verification: User found in Hive after save');
        print('   - UID: ${verifyUser.uid}');
        print('   - isRegistered: ${verifyUser.isRegistered}');
        print('   - fullName: ${verifyUser.fullName}');
        if (!verifyUser.isRegistered) {
          print('❌ CRITICAL: User saved but isRegistered is FALSE!');
          print('   Attempting to save again with explicit isRegistered: true');
          final correctedUser = verifyUser.copyWith(isRegistered: true);
          await userService.saveUser(correctedUser);
          // Verify again
          final reVerifyUser = await userService.getUser(firebaseUser.uid);
          if (reVerifyUser != null && reVerifyUser.isRegistered) {
            print('✅ User corrected: isRegistered is now TRUE');
          } else {
            print('❌ ERROR: Failed to correct isRegistered flag');
          }
        }
      } else {
        print('❌ CRITICAL: User not found in Hive after save!');
      }

      // Update Firebase user display name
      try {
        await firebaseUser.updateDisplayName(_nameController.text.trim());
      } catch (e) {
        print('⚠️ Failed to update display name: $e');
        // Continue anyway - not critical
      }

      // Wait a moment to ensure data is saved and synced
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Registration successful!'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );

        // Navigate to MainTabScreen instead of HomeScreen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainTabScreen()),
          (route) => false, // Remove all previous routes
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      String errorMessage = 'Registration failed. Please try again.';
      
      if (e.code == 'email-already-in-use') {
        errorMessage = 'An account already exists with this email. Please sign in instead.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak. Please use a stronger password.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address. Please check and try again.';
      } else if (e.message != null) {
        errorMessage = e.message!;
      }
      
      _showError(errorMessage);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Registration failed: $e');
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
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.darkText,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
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
                    Icons.person_add_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Title
                Text(
                  'Create Account',
                  style: AppTheme.heading2.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign up to get started',
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
                      // Full Name
                      TextFormField(
                        controller: _nameController,
                        decoration: AppTheme.getInputDecoration(
                          label: 'Full Name',
                          hint: 'John Doe',
                          prefixIcon: Icons.person_rounded,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your full name';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 20),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        readOnly: !widget.isNewUser && widget.email.isNotEmpty,
                        decoration: AppTheme.getInputDecoration(
                          label: 'Email / Phone Number',
                          hint: 'john.doe@example.com',
                          prefixIcon: Icons.email_rounded,
                        ).copyWith(
                          fillColor: (!widget.isNewUser && widget.email.isNotEmpty)
                              ? AppTheme.backgroundColorAlt
                              : AppTheme.backgroundColorAlt,
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

                      // Password (only for new users)
                      if (widget.isNewUser) ...[
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: AppTheme.getInputDecoration(
                            label: 'Password',
                            hint: 'Create a password',
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
                              return 'Please enter a password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // Confirm Password
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: AppTheme.getInputDecoration(
                            label: 'Confirm Password',
                            hint: 'Re-enter your password',
                            prefixIcon: Icons.lock_outline_rounded,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                color: AppTheme.lightText,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Phone Number (Optional)
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: AppTheme.getInputDecoration(
                          label: 'Phone Number (Optional)',
                          hint: '9876543210',
                          prefixIcon: Icons.phone_rounded,
                        ),
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final phone = value.trim().replaceAll(RegExp(r'[^\d+]'), '');
                            if (phone.length < 10) {
                              return 'Please enter a valid phone number';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Register Button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
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
                                  'Create Account',
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
                const SizedBox(height: 24),
                
                Text(
                  'By registering, you agree to our Terms of Service and Privacy Policy',
                  style: AppTheme.bodySmall.copyWith(
                    fontSize: 12,
                    color: AppTheme.lightText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: AppTheme.bodyMedium.copyWith(
                        fontSize: 14,
                        color: AppTheme.lightText,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Login',
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
