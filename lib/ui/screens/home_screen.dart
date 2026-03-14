import 'package:flutter/material.dart';

import 'daily_design_screen.dart';
import 'batch_generator_screen.dart';
import 'calendar_grid_screen.dart';
import 'template_maker_screen.dart';
import '../../core/services/auth_service.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // GlobalKey lets us call refresh() on the calendar state directly when the
  // user switches to the Calendar tab — instant sync after batch generation.
  final GlobalKey<CalendarGridScreenState> _calendarKey =
      GlobalKey<CalendarGridScreenState>();
  final GlobalKey<DailyDesignScreenState> _dailyDesignKey =
      GlobalKey<DailyDesignScreenState>();

  void switchToMaker() {
    setState(() => _currentIndex = 3);
  }

  void switchToGenerator() {
    setState(() => _currentIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      DailyDesignScreen(
        key: _dailyDesignKey,
        onGoToGenerator: switchToGenerator,
      ),
      BatchGeneratorScreen(
        onCreateNew: switchToMaker,
        // After user reviews in Grid View and clicks "Proceed", switch to Calendar
        onProceed: () {
          setState(() => _currentIndex = 2); // Switch to Calendar tab
          _calendarKey.currentState?.refresh();
          _dailyDesignKey.currentState?.refresh();
        },
      ),
      CalendarGridScreen(key: _calendarKey),
      const TemplateMakerScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(switch (_currentIndex) {
          1 => AppStrings.navGenerate,
          2 => AppStrings.navCalendar,
          3 => 'EDITOR',
          _ => AppStrings.navDesign,
        }, style: AppTextStyles.heading2.copyWith(color: AppColors.primary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.primary),
            onPressed: () async => AuthService().signOut(),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.glassShadow.withValues(alpha: 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            if (index == 0) {
              _dailyDesignKey.currentState?.refresh();
            } else if (index == 2) {
              _calendarKey.currentState?.refresh();
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.palette_outlined),
              activeIcon: Icon(Icons.palette),
              label: 'Design',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_outlined),
              activeIcon: Icon(Icons.auto_awesome),
              label: 'Generate',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.edit_outlined),
              activeIcon: Icon(Icons.edit),
              label: 'Maker',
            ),
          ],
        ),
      ),
    );
  }
}
