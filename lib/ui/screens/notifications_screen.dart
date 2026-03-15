import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'notification_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'NOTIFICATIONS',
          style: AppTextStyles.heading2.copyWith(fontSize: 18, letterSpacing: 2.0),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        itemCount: 5,
        separatorBuilder: (context, index) => Divider(color: Colors.grey.withValues(alpha: 0.1), height: 32),
        itemBuilder: (context, index) {
          final isNew = index < 2;
          return _buildNotificationItem(context, isNew);
        },
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, bool isNew) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationDetailScreen()),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isNew ? AppColors.primary.withValues(alpha: 0.1) : AppColors.secondary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isNew ? Icons.star_rounded : Icons.notifications_none_rounded,
              color: isNew ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.4),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'New Daily Verse Release',
                        style: AppTextStyles.bodyText.copyWith(
                          fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isNew)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Your daily manuscript is ready for review. Check out "His Story" collection...',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '2h ago',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
