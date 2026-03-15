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

    final today = DateTime.now();
    final dateStr = DateFormat('MMMM d').format(today);
    final dayStr = 'DAY ${today.day}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Featured Verse Card
          Container(
            height: 380,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFE5D5C5),
                  const Color(0xFFC5B5A5).withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                if (_todayImage != null)
                  Positioned.fill(
                    child: Image.file(_todayImage!, fit: BoxFit.cover),
                  )
                else
                  const Center(
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                // Tags
                Positioned(
                  top: 24,
                  left: 24,
                  child: Row(
                    children: [
                      _buildTag(dateStr, AppColors.primary, Colors.white),
                      const SizedBox(width: 8),
                      _buildTag(dayStr, Colors.white, AppColors.textPrimary),
                    ],
                  ),
                ),
                // Overlay text if no image
                if (_todayImage == null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "TODAY'S VERSE",
                            style: AppTextStyles.heading1.copyWith(
                              fontSize: 24,
                              color: Colors.white,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '"Thy word is a lamp unto my feet, and a light unto my path..."',
                            style: AppTextStyles.bodyText.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                // Bottom Gradient Shade
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 120,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareImage,
                  icon: const Icon(Icons.share_outlined, size: 20),
                  label: const Text('Share Gospel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {}, // TODO: Implement Download
                  icon: const Icon(Icons.download_outlined, size: 20),
                  label: const Text('Download'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 48),

          // Progress Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "THIS MONTH'S PROGRESS",
                style: AppTextStyles.heading2.copyWith(fontSize: 18),
              ),
              Text(
                "14 / 31", // Mock progress
                style: AppTextStyles.heading2.copyWith(
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: 14 / 31,
              minHeight: 12,
              backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "You have illuminated 14 hearts this month through shared designs.",
            style: AppTextStyles.caption.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
          ),

          const SizedBox(height: 48),

          // Quick Actions Section
          Text(
            "QUICK ACTIONS",
            style: AppTextStyles.heading2.copyWith(fontSize: 18, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildQuickActionCard(
            icon: Icons.auto_awesome,
            title: "GENERATE BATCH",
            subtitle: "AI-powered scripture design engine",
            onTap: widget.onGoToGenerator,
          ),
          const SizedBox(height: 16),
          _buildQuickActionCard(
            icon: Icons.palette_outlined,
            title: "DESIGN TEMPLATE",
            subtitle: "Craft a custom sacred manuscript",
            onTap: () {
              // This is a bit tricky since we are inside a widget. 
              // We'll trust the HomeScreen's handle for this.
              // For now, it's a placeholder.
            },
          ),
          const SizedBox(height: 16),
          _buildQuickActionCard(
            icon: Icons.calendar_month_outlined,
            title: "VIEW CALENDAR",
            subtitle: "Schedule your divine inspirations",
            onTap: () {
              // Placeholder
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.heading2.copyWith(
                fontSize: 14,
                color: AppColors.primary,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
