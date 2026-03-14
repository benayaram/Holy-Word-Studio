import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import 'viewer_screen.dart';

class CalendarGridScreen extends StatefulWidget {
  const CalendarGridScreen({super.key});

  @override
  State<CalendarGridScreen> createState() => CalendarGridScreenState();
}

/// Public state class so [HomeScreen] can call [refresh] via a [GlobalKey].
class CalendarGridScreenState extends State<CalendarGridScreen> {
  String _selectedMonth = DateFormat('MMMM').format(DateTime.now());
  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  List<File> _images = [];
  bool _isLoading = false;
  bool _isSaving = false;
  int _saveProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  /// Called by [HomeScreen] whenever the Calendar tab becomes active, so the
  /// grid is always up-to-date after a batch generation.
  void refresh() => _loadImages();

  Future<void> _loadImages() async {
    setState(() => _isLoading = true);
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
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAllToGallery() async {
    if (_images.isEmpty) return;

    setState(() {
      _isSaving = true;
      _saveProgress = 0;
    });

    int successCount = 0;
    for (final file in _images) {
      final success = await GallerySaver.saveImage(
        file.path,
        albumName: 'Holy Word Studio',
      );
      if (success == true) {
        successCount++;
      }
      setState(() => _saveProgress++);
    }

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully exported $successCount images to Native Gallery!',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generated Content'),
        actions: [
          if (_images.isNotEmpty && !_isSaving)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Save All to Gallery',
              onPressed: _saveAllToGallery,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isSaving ? null : _loadImages,
          ),
        ],
      ),
      body: _isSaving
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                    ),
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Exporting to Gallery...',
                    style: AppTextStyles.heading1.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Progress: $_saveProgress / ${_images.length}',
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedMonth,
                        dropdownColor: AppColors.secondary,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.primary,
                        ),
                        style: AppTextStyles.bodyText.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        items: _months.map((String month) {
                          return DropdownMenuItem<String>(
                            value: month,
                            child: Text(month),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedMonth = newValue;
                              _loadImages();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _images.isEmpty
                      ? Center(
                          child: Text(
                            'No generated batches found for $_selectedMonth.',
                            style: AppTextStyles.bodyText,
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadImages,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(20),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 20,
                                  childAspectRatio: 0.85,
                                ),
                            itemCount: _images.length,
                            itemBuilder: (context, index) {
                              final file = _images[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ViewerScreen(imageFile: file),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(file, fit: BoxFit.cover),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: [
                                                Colors.black.withValues(
                                                  alpha: 0.6,
                                                ),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                          child: Text(
                                            'DAY ${index + 1}',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.5,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
