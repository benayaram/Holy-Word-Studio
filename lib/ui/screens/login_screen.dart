import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_images.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    final cred = await _authService.signInWithGoogle();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (cred != null) {
      // Success -> Navigate to Home
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-in canceled or failed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: Stack(
        children: [
          // Header with Logo
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.45,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    AppColors.secondary,
                  ],
                  radius: 0.8,
                ),
              ),
              child: Center(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 40,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      AppImages.logo,
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Content Card
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: size.height * 0.6,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFE5EBFF), // Light bluish background from design
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                children: [
                  // HandleBar icon shadow
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Welcome to',
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.appName.toUpperCase(),
                    style: AppTextStyles.heading1.copyWith(
                      color: AppColors.primary,
                      fontSize: 32,
                      letterSpacing: 2.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Share the Gospel beautifully every day.',
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 64, thickness: 1, color: Colors.blueGrey),
                  
                  if (_isLoading)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  else ...[
                    // Google Sign In
                    _buildSocialButton(
                      label: 'Continue with Google',
                      icon: Icons.g_mobiledata, // Placeholder for Google Icon
                      backgroundColor: AppColors.secondary,
                      onPressed: _handleGoogleSignIn,
                    ),
                    const SizedBox(height: 16),
                    // Apple Sign In
                    _buildSocialButton(
                      label: 'Sign in with Apple',
                      icon: Icons.apple,
                      backgroundColor: Colors.black,
                      onPressed: () {}, // Dummy
                    ),
                    const Spacer(),
                    // Other options
                    Text(
                      'Continue with email or phone',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Legal links
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        children: const [
                          TextSpan(text: 'By creating an account, you agree to our '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(decoration: TextDecoration.underline),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(decoration: TextDecoration.underline),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 4,
        ),
        icon: Icon(icon, size: 28),
        label: Text(
          label,
          style: AppTextStyles.buttonText.copyWith(fontSize: 14),
        ),
      ),
    );
  }
}
