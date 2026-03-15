import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class CalendarGridScreen extends StatefulWidget {
  const CalendarGridScreen({super.key});

  @override
  State<CalendarGridScreen> createState() => CalendarGridScreenState();
}

/// Public state class so [HomeScreen] can call [refresh] via a [GlobalKey].
class CalendarGridScreenState extends State<CalendarGridScreen> {
  final String _selectedMonth = DateFormat('MMMM').format(DateTime.now());
  List<File> _images = [];

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  /// Called by [HomeScreen] whenever the Calendar tab becomes active, so the
  /// grid is always up-to-date after a batch generation.
  void refresh() => _loadImages();

  Future<void> _loadImages() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final batchFolder = Directory(
        '${directory.path}/HolyCanvas/$_selectedMonth',
      );

      if (await batchFolder.exists()) {
        final List<FileSystemEntity> entities = await batchFolder
            .list()
            .toList();

        final images = entities
            .whereType<File>()
            .where(
              (file) =>
                  file.path.endsWith('.png') || file.path.endsWith('.jpg'),
            )
            .toList();

        // Sort by day number dynamically by splitting string 'Day_1.png'
        images.sort((a, b) {
          final nameA = a.path
              .split('/')
              .last
              .replaceAll('Day_', '')
              .replaceAll('.png', '');
          final nameB = b.path
              .split('/')
              .last
              .replaceAll('Day_', '')
              .replaceAll('.png', '');
          final numA = int.tryParse(nameA) ?? 0;
          final numB = int.tryParse(nameB) ?? 0;
          return numA.compareTo(numB);
        });

        setState(() {
          _images = images;
        });
      } else {
        setState(() => _images = []);
      }
    } catch (e) {
      // ignore
      setState(() => _images = []);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '${_selectedMonth.toUpperCase()} 2024',
          style: AppTextStyles.heading2.copyWith(fontSize: 18, letterSpacing: 2.0),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Month Selector / Horizontal bar if needed, but grid is main
                   const SizedBox(height: 16),
                   
                   // Day Grid (Circular)
                   Container(
                     height: 380,
                     padding: const EdgeInsets.symmetric(horizontal: 24),
                     child: GridView.builder(
                       physics: const NeverScrollableScrollPhysics(),
                       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                         crossAxisCount: 7,
                         crossAxisSpacing: 10,
                         mainAxisSpacing: 10,
                       ),
                       itemCount: 31, // Hardcoded for design for now
                       itemBuilder: (context, index) {
                         final day = index + 1;
                         final hasImage = day <= _images.length;
                         final isSelected = day == 15; // Placeholder selection

                         return _buildDayCircle(day, hasImage, isSelected);
                       },
                     ),
                   ),

                   const SizedBox(height: 32),
                   
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 24),
                     child: Text(
                       "TODAY'S SELECTION",
                       style: AppTextStyles.caption.copyWith(
                         fontWeight: FontWeight.bold,
                         letterSpacing: 2.0,
                         color: AppColors.textSecondary.withValues(alpha: 0.5),
                       ),
                     ),
                   ),

                   const SizedBox(height: 16),

                   // Featured Daily Card
                   _buildFeaturedDailyCard(),

                   const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildDayCircle(int day, bool hasImage, bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.primary : (hasImage ? AppColors.secondary : Colors.white),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ] : [],
      ),
      child: Center(
        child: Text(
          day.toString(),
          style: TextStyle(
            color: isSelected || hasImage ? Colors.white : AppColors.textPrimary.withValues(alpha: 0.4),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedDailyCard() {
    if (_images.isEmpty) return _buildEmptyHint();
    
    // For now taking the first image or index 14 (Day 15) to match design
    final file = _images.isNotEmpty ? _images[0] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
             // Image area
             AspectRatio(
               aspectRatio: 1,
               child: file != null 
                 ? Image.file(file, fit: BoxFit.cover)
                 : Container(color: AppColors.background, child: const Icon(Icons.image, color: Colors.grey)),
             ),
             // Footer
             Padding(
               padding: const EdgeInsets.all(20),
               child: Row(
                 children: [
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         'DAILY VERSE',
                         style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                       ),
                       Text(
                         'John 3:16 • Bible Verse',
                         style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                       ),
                     ],
                   ),
                   const Spacer(),
                   IconButton(
                     icon: const Icon(Icons.ios_share_outlined, color: AppColors.primary),
                     onPressed: () {},
                   ),
                   IconButton(
                     icon: const Icon(Icons.download_outlined, color: AppColors.primary),
                     onPressed: () {},
                   ),
                 ],
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHint() {
    return const Center(child: Padding(
      padding: EdgeInsets.all(40.0),
      child: Text('No images generated yet for this month.'),
    ));
  }
}
