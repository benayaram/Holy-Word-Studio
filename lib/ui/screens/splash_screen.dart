import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_images.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    // Artificial delay for the splash animation
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final User? user = _authService.currentUser;

    if (user != null) {
      // Authenticated -> Home Screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      // Not Authenticated -> Login Screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  AppImages.logo,
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 48),
                // App Name
                Text(
                  AppStrings.appName.toUpperCase(),
                  style: AppTextStyles.heading1.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 4.0,
                  ),
                ),
                const SizedBox(height: 12),
                // Subtitle
                Text(
                  'ELEGANCE IN EVERY VERSE',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 80),
                // Loading Indicator
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          // Footer
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'EST. MMXXIV',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.3),
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
