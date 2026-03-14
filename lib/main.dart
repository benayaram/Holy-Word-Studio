import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/logger/app_logger.dart';

import 'core/constants/app_text_styles.dart';
import 'logic/providers/template_editor_provider.dart';
import 'ui/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.info('Firebase initialized successfully.');
  } catch (e) {
    AppLogger.error('Firebase initialization failed or missing options.', e);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TemplateEditorProvider()),
      ],
      child: const HolyCanvasApp(),
    ),
  );
}

class HolyCanvasApp extends StatelessWidget {
  const HolyCanvasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'Inter',
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          error: AppColors.error,
          surface: AppColors.surface,
          onPrimary: Colors.black,
          onSecondary: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.secondary,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: AppTextStyles.heading2.copyWith(
            color: AppColors.primary,
            letterSpacing: 2,
          ),
          iconTheme: const IconThemeData(color: AppColors.primary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Color(0xFF94A3B8),
          type: BottomNavigationBarType.fixed,
          elevation: 10,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
