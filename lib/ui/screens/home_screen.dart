import 'package:flutter/material.dart';

import 'daily_design_screen.dart';
import 'batch_generator_screen.dart';
import 'calendar_grid_screen.dart';
import 'template_maker_screen.dart';
import 'notifications_screen.dart';
import '../../core/constants/app_images.dart';
import '../../core/constants/app_colors.dart';

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
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.primary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Image.asset(
          AppImages.logo,
          height: 30,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.primary, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: AppColors.primary, size: 22),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
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
