import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// The Daily Design tab shows the generated verse for today.
/// If it doesn't exist, it encourages the user to go to the Generator tab.
class DailyDesignScreen extends StatefulWidget {
  final VoidCallback onGoToGenerator;

  const DailyDesignScreen({super.key, required this.onGoToGenerator});

  @override
  State<DailyDesignScreen> createState() => DailyDesignScreenState();
}

class DailyDesignScreenState extends State<DailyDesignScreen> {
  File? _todayImage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkTodayDesign();
  }

  /// Needs to be public or triggered when the tab becomes active to ensure
  /// it updates if the user just generated it.
  Future<void> _checkTodayDesign() async {
    setState(() => _isLoading = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final today = DateTime.now();
      final monthName = DateFormat('MMMM').format(today);
      final dayNames = ['Day_${today.day}.png', 'Day_${today.day}.jpg'];

      File? foundFile;
      for (final ext in dayNames) {
        final file = File('${directory.path}/HolyCanvas/$monthName/$ext');
        if (await file.exists()) {
          foundFile = file;
          break;
        }
      }

      setState(() {
        _todayImage = foundFile;
      });
    } catch (e) {
      setState(() => _todayImage = null);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Required to allow parent to force refresh.
  void refresh() => _checkTodayDesign();

  Future<void> _shareImage() async {
    if (_todayImage == null) return;
    final xFile = XFile(_todayImage!.path);
    // ignore: deprecated_member_use
    await Share.shareXFiles([xFile], text: 'Today\'s Daily Verse');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_todayImage != null) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(_todayImage!, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _shareImage,
              icon: const Icon(Icons.share),
              label: const Text('Share the Gospel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                textStyle: AppTextStyles.bodyText.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Empty state
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.generating_tokens_outlined,
            size: 80,
            color: AppColors.primary.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 24),
          Text(
            'Today\'s Verse is Not Designed',
            style: AppTextStyles.heading2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Make this Month/Day\'s Design and Share the gospel.',
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: widget.onGoToGenerator,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Go to Generator'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
