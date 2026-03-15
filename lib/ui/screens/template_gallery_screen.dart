import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/template_model.dart';
import '../../logic/providers/template_editor_provider.dart';

/// Gallery screen — shows saved templates and a "Create New" card.
///
/// [onCreateNew] is called when the user taps "Create New", allowing the
/// parent [HomeScreen] to switch to the Maker tab via its own state.
class TemplateGalleryScreen extends StatefulWidget {
  final VoidCallback onCreateNew;

  const TemplateGalleryScreen({super.key, required this.onCreateNew});

  @override
  State<TemplateGalleryScreen> createState() => _TemplateGalleryScreenState();
}

class _TemplateGalleryScreenState extends State<TemplateGalleryScreen> {
  Key _futureKey = UniqueKey();

  Future<List<TemplateModel>> _loadTemplates() =>
      context.read<TemplateEditorProvider>().repository.getSavedTemplates();

  Future<void> _refresh() async {
    // Invalidate the repository cache so we get fresh data, then rebuild.
    context.read<TemplateEditorProvider>().repository.invalidateCache();
    setState(() => _futureKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Search
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TEMPLATE GALLERY',
                  style: AppTextStyles.heading1.copyWith(
                    fontSize: 24,
                    color: AppColors.textPrimary,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 24),
                // Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Search templates...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      icon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Categories
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildCategoryTab('ALL', true),
                _buildCategoryTab('FAVORITES', false),
                _buildCategoryTab('HIS STORY', false),
                _buildCategoryTab('SACRED', false),
                _buildCategoryTab('GRACE', false),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Grid
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primary,
              child: FutureBuilder<List<TemplateModel>>(
                key: _futureKey,
                future: _loadTemplates(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final templates = snapshot.data ?? [];

                  return GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: templates.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildCreateNewCard(context);
                      return _buildTemplateCard(context, templates[index - 1]);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(String label, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: isActive ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.4),
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 20,
              height: 2,
              color: AppColors.primary,
            ),
        ],
      ),
    );
  }

  Widget _buildCreateNewCard(BuildContext context) {
    return GestureDetector(
      // Switch to the Maker tab — no new route pushed.
      onTap: () {
        context.read<TemplateEditorProvider>().resetToNew();
        widget.onCreateNew();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Create New',
              style: AppTextStyles.bodyText.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(BuildContext context, TemplateModel template) {
    return GestureDetector(
      onTap: () {
        context.read<TemplateEditorProvider>().loadTemplate(template);
        widget.onCreateNew(); // re-uses the same "go to Maker" callback
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: AppColors.secondary.withValues(alpha: 0.05),
                child:
                    template.thumbnailPath != null &&
                        File(template.thumbnailPath!).existsSync()
                    ? Image.file(
                        File(template.thumbnailPath!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : Icon(
                        Icons.auto_awesome_mosaic_rounded,
                        color: AppColors.primary.withValues(alpha: 0.2),
                        size: 48,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: AppTextStyles.bodyText.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${template.createdAt.day}/${template.createdAt.month}/${template.createdAt.year}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
