import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import '../../core/services/ai_horde_service.dart';
import 'package:auto_size_text/auto_size_text.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/verses_service.dart';
import '../../core/logger/app_logger.dart';
import '../../data/models/layer_model.dart';
import '../../data/models/template_model.dart';
import '../../data/models/verse_data_model.dart';
import '../../logic/providers/template_editor_provider.dart';

// ---------------------------------------------------------------------------
// Batch Generator Screen
// ---------------------------------------------------------------------------

class BatchGeneratorScreen extends StatefulWidget {
  final VoidCallback onCreateNew;
  final VoidCallback? onProceed;

  const BatchGeneratorScreen({
    super.key,
    required this.onCreateNew,
    this.onProceed,
  });

  @override
  State<BatchGeneratorScreen> createState() => _BatchGeneratorScreenState();
}

enum ViewMode { config, grid, list }

class _BatchGeneratorScreenState extends State<BatchGeneratorScreen> {
  TemplateModel? _selectedTemplate;
  String _selectedMonth = DateFormat('MMMM').format(DateTime.now());
  bool _isGenerating = false;
  int _currentDay = 0;
  int _totalDays = 0;
  ViewMode _viewMode = ViewMode.config;

  /// Live status message from the AI Horde queue, shown in the progress overlay.
  String _hordeStatus = '';

  final ScreenshotController _screenshotController = ScreenshotController();

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

  /// Returns the number of days in the selected month for the current year.
  int _daysInMonth() {
    final monthIndex = _months.indexOf(_selectedMonth) + 1;
    return DateTime(DateTime.now().year, monthIndex + 1, 0).day;
  }

  // ---------------------------------------------------------------------------
  // Generation logic
  // ---------------------------------------------------------------------------

  Future<void> _generateBatch() async {
    if (_selectedTemplate == null) return;
    // Capture context before any await so all downstream uses are lint-safe.
    final ctx = context;
    final template = _selectedTemplate!;
    final days = _daysInMonth();

    setState(() {
      _isGenerating = true;
      _currentDay = 0;
      _totalDays = days;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      // Save to a temp folder first; user must click Proceed to commit to calendar
      final tempDir = Directory('${directory.path}/HolyCanvas/TempBatch');
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      await tempDir.create(recursive: true);

      for (int day = 1; day <= days; day++) {
        // Fetch real verse data from VersesService (API + offline fallback)
        final verse = await VersesService.instance.getVerseForDay(day);

        final updatedLayers = <LayerModel>[];
        for (var layer in template.layers) {
          if (layer.type == LayerType.text) {
            final text = _resolveText(layer, verse, day);
            updatedLayers.add(
              text != null ? layer.copyWith(text: text) : layer,
            );
          } else if (layer.type == LayerType.image &&
              layer.imageType == ImageType.verseImage) {
            if (verse.backgroundImage != null &&
                verse.backgroundImage!.isNotEmpty) {
              final savePath = '${tempDir.path}/verse_bg_$day.jpg';
              final ok = await AiHordeService.instance.generateAndSaveImage(
                verse.backgroundImage!,
                savePath: savePath,
                width: layer.width.toInt(),
                height: layer.height.toInt(),
                onStatus: (msg) {
                  if (mounted) setState(() => _hordeStatus = msg);
                },
              );
              if (ok) {
                updatedLayers.add(layer.copyWith(imagePath: savePath));
                continue;
              }
            }
            updatedLayers.add(layer);
          } else {
            updatedLayers.add(layer);
          }
        }

        final updatedTemplate = template.copyWith(layers: updatedLayers);

        setState(() {
          _currentDay = day;
          _hordeStatus = '';
        });

        if (!mounted) break;

        final imageBytes = await _preloadTemplateImages(updatedTemplate);
        // ctx is captured before any await in this method (see top of _generateBatch).
        // _captureTemplate is non-async and non-navigation — using BuildContext here is safe.
        // ignore: use_build_context_synchronously
        final captureFuture = _captureTemplate(ctx, updatedTemplate, imageBytes);
        final bytes = await captureFuture;

        final filePath = '${tempDir.path}/Day_$day.png';
        await File(filePath).writeAsBytes(bytes);

        // Yield to the event loop so the main thread (UI) can process
        // frames, preventing "Application Not Responding" (ANR) crash
        // when generating 30 high-resolution images back-to-back.
        await Future.delayed(const Duration(milliseconds: 150));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$days images generated for $_selectedMonth!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _viewMode = ViewMode.grid; // Switch to review mode after generating
        });
      }
    }
  }

  Future<void> _regenerateDay(int day) async {
    if (_selectedTemplate == null) return;
    // Capture context before any await so all downstream uses are lint-safe.
    final ctx = context;

    // Create an ephemeral 'generating' state for just this day
    setState(() {
      _isGenerating = true;
      _currentDay = day;
      _totalDays = 1; // Single day regen
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      // Regeneration also saves to TempBatch so it stays consistent with the review view
      final tempDir = Directory('${directory.path}/HolyCanvas/TempBatch');

      // Get a new random verse
      final verse = await VersesService.instance.getRandomVerse(day);

      final template = _selectedTemplate!;
      final updatedLayers = <LayerModel>[];
      for (var layer in template.layers) {
        if (layer.type == LayerType.text) {
          final text = _resolveText(layer, verse, day);
          updatedLayers.add(text != null ? layer.copyWith(text: text) : layer);
        } else if (layer.type == LayerType.image &&
            layer.imageType == ImageType.verseImage) {
          if (verse.backgroundImage != null &&
              verse.backgroundImage!.isNotEmpty) {
            final savePath = '${tempDir.path}/verse_bg_$day.jpg';
            final ok = await AiHordeService.instance.generateAndSaveImage(
              verse.backgroundImage!,
              savePath: savePath,
              width: layer.width.toInt(),
              height: layer.height.toInt(),
              onStatus: (msg) {
                if (mounted) setState(() => _hordeStatus = msg);
              },
            );
            if (ok) {
              updatedLayers.add(layer.copyWith(imagePath: savePath));
              continue;
            }
          }
          updatedLayers.add(layer);
        } else {
          updatedLayers.add(layer);
        }
      }

      final updatedTemplate = template.copyWith(layers: updatedLayers);

      if (!mounted) return;

      final imageBytes = await _preloadTemplateImages(updatedTemplate);
      // ctx is captured before any await in this method (see top of _regenerateDay).
      // _captureTemplate is non-async and non-navigation — using BuildContext here is safe.
      // ignore: use_build_context_synchronously
      final captureFuture = _captureTemplate(ctx, updatedTemplate, imageBytes);
      final bytes = await captureFuture;

      final filePath = '${tempDir.path}/Day_$day.png';

      await File(filePath).writeAsBytes(bytes);

      // Force cache eviction so the new image is shown.
      await FileImage(File(filePath)).evict();

      // Force UI refresh
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to regenerate: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  /// Maps the layer's [textType] or layer name to verse content.
  String? _resolveText(LayerModel layer, VerseDataModel verse, int day) {
    final type = (layer.textType?.name ?? '').toLowerCase();
    final name = (layer.name ?? '').toLowerCase();

    // 1. Exact match for imported JSON template 'name' fields
    if (name == 'verse_te') return verse.telugu;
    if (name == 'verse_en') return verse.english;
    if (name == 'verse_te_ref') return verse.teluguReference;
    if (name == 'verse_en_ref') return verse.englishReference;

    // 2. Fallbacks for TextType enums and custom Maker layers
    if (type == 'teluguverse' ||
        name.contains('telugu') && name.contains('verse')) {
      return verse.telugu;
    }
    if (type == 'englishverse' ||
        name.contains('english') && name.contains('verse') ||
        name.contains('verse')) {
      return verse.english;
    }
    if (type == 'telugureference' ||
        name.contains('telugu') && name.contains('ref')) {
      return verse.teluguReference;
    }
    if (type == 'englishreference' ||
        name.contains('reference') ||
        name.contains('ref')) {
      return verse.englishReference;
    }
    if (type == 'day' || name == 'day' || name.contains('day')) {
      return day.toString().padLeft(2, '0');
    }
    if (type == 'date' || name.contains('date')) {
      final monthIndex = _months.indexOf(_selectedMonth) + 1;
      return '$day/${monthIndex.toString().padLeft(2, '0')}';
    }
    return null;
  }

  /// Fetches all image bytes that [template] references (background + every
  /// image layer) and returns them keyed by their source string (URL or path).
  ///
  /// Using [Image.memory] from these pre-fetched bytes inside [_TemplateRenderer]
  /// guarantees the widget tree is fully painted on the very first frame, which
  /// is what [ScreenshotController.captureFromWidget] captures.
  Future<Map<String, Uint8List>> _preloadTemplateImages(
    TemplateModel template,
  ) async {
    final result = <String, Uint8List>{};

    // Collect all distinct image sources (background + layer imagePaths)
    final sources = <String>{};
    if (template.backgroundImage != null &&
        template.backgroundImage!.isNotEmpty &&
        !template.backgroundImage!.startsWith('data:')) {
      sources.add(template.backgroundImage!);
    }
    for (final layer in template.layers) {
      final p = layer.imagePath;
      if (p != null && p.isNotEmpty) sources.add(p);
    }

    for (final src in sources) {
      try {
        if (src.startsWith('http')) {
          final res = await http
              .get(Uri.parse(src))
              .timeout(const Duration(seconds: 20));
          if (res.statusCode == 200) result[src] = res.bodyBytes;
        } else {
          final file = File(src);
          if (await file.exists()) result[src] = await file.readAsBytes();
        }
      } catch (e) {
        AppLogger.warn('_preloadTemplateImages: failed to load "$src" — $e');
      }
    }

    return result;
  }

  /// Captures a screenshot of [template] using pre-loaded [imageBytes].
  ///
  /// [context] is accepted as an explicit parameter so the call site has
  /// already resolved it synchronously—avoiding the
  /// `use_build_context_synchronously` lint when context is used after an await.
  Future<Uint8List> _captureTemplate(
    BuildContext context,
    TemplateModel template,
    Map<String, Uint8List> imageBytes,
  ) {
    return _screenshotController.captureFromWidget(
      _TemplateRenderer(template: template, preloadedImages: imageBytes),
      context: context,
      // Minimal delay — all images are already in memory as bytes.
      delay: const Duration(milliseconds: 200),
      targetSize: Size(template.canvasWidth, template.canvasHeight),
    );
  }


  /// Moves all temporary batch images to the actual calendar month folder,
  /// then notifies HomeScreen to switch to the Calendar tab.
  Future<void> _proceedToCalendar() async {
    setState(() => _isGenerating = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final tempDir = Directory('${dir.path}/HolyCanvas/TempBatch');
      final monthDir = Directory('${dir.path}/HolyCanvas/$_selectedMonth');

      if (!await monthDir.exists()) await monthDir.create(recursive: true);

      if (await tempDir.exists()) {
        for (final file in tempDir.listSync().whereType<File>()) {
          await file.copy('${monthDir.path}/${file.uri.pathSegments.last}');
        }
        await tempDir.delete(recursive: true);
      }

      if (mounted) {
        setState(() => _viewMode = ViewMode.config);
        widget.onProceed?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'BATCH GENERATOR',
          style: AppTextStyles.heading2.copyWith(fontSize: 18, color: AppColors.primary, letterSpacing: 2.0),
        ),
        centerTitle: true,
        actions: _buildAppBarActions(),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: _isGenerating
            ? _buildProgressOverlay()
            : (_viewMode == ViewMode.config
                ? _buildConfigUI()
                : _buildReviewUI()),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    if (_viewMode == ViewMode.config) return [];

    return [
      IconButton(
        icon: Icon(
          _viewMode == ViewMode.grid ? Icons.view_list : Icons.grid_view,
          color: AppColors.primary,
        ),
        onPressed: () {
          setState(() {
            _viewMode = _viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid;
          });
        },
      ),
      IconButton(
        icon: const Icon(Icons.settings, color: AppColors.primary),
        onPressed: () => setState(() => _viewMode = ViewMode.config),
        tooltip: 'Back to Configurator',
      ),
      const SizedBox(width: 8),
    ];
  }

  Widget _buildConfigUI() {
    return Column(
      children: [
        // Stepper
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStepIndicator('01.', 'CONTEXT', true),
              _buildStepDivider(),
              _buildStepIndicator('02.', 'ART STYLE', false),
              _buildStepDivider(),
              _buildStepIndicator('03.', 'REVIEW', false),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STEP 01/03',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Select Current Context',
                  style: AppTextStyles.heading1.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 24),
                
                // Context Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _buildContextCard('MOURNING', Icons.water_drop_outlined, false),
                    _buildContextCard('JOY', Icons.sentiment_very_satisfied, false),
                    _buildContextCard('PEACE', Icons.wb_sunny_outlined, true), // Featured/Active
                    _buildContextCard('FAITH', Icons.auto_awesome, false),
                    _buildContextCard('STRENGTH', Icons.fitness_center, false),
                    _buildContextCard('WISDOM', Icons.lightbulb_outline, false),
                  ],
                ),

                const SizedBox(height: 48),
                _buildSectionTitle('Select Month'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                  ),
                  initialValue: _selectedMonth,
                  items: _months
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedMonth = val!),
                ),
                const SizedBox(height: 24),
                
                // Template dropdown remains for functional purposes but styled
                _buildSectionTitle('Visual Foundation'),
                const SizedBox(height: 16),
                FutureBuilder<List<TemplateModel>>(
                  future: context.read<TemplateEditorProvider>().repository.getSavedTemplates(),
                  builder: (context, snapshot) {
                    final templates = snapshot.data ?? [];
                    if (templates.isEmpty) return _buildNoTemplatesHint();
                    
                    return DropdownButtonFormField<TemplateModel>(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                      ),
                      isExpanded: true,
                      hint: const Text('Choose a visual template…'),
                      initialValue: templates.contains(_selectedTemplate) ? _selectedTemplate : null,
                      items: templates.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                      onChanged: (val) => setState(() => _selectedTemplate = val),
                    );
                  },
                ),
                
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _selectedTemplate == null ? null : _generateBatch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      'PROCEED TO STYLE',
                      style: AppTextStyles.buttonText.copyWith(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator(String num, String label, bool isActive) {
    return Column(
      children: [
        Text(
          num,
          style: AppTextStyles.caption.copyWith(
            color: isActive ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.3),
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isActive ? AppColors.textPrimary : AppColors.textSecondary.withValues(alpha: 0.3),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider() {
    return Container(
      width: 40,
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.textSecondary.withValues(alpha: 0.1),
    );
  }

  Widget _buildContextCard(String label, IconData icon, bool isActive) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? AppColors.secondary : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isActive ? Border.all(color: AppColors.primary, width: 2) : Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.4),
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: isActive ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.heading2.copyWith(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.5)),
    );
  }

  Widget _buildReviewUI() {
    return FutureBuilder<Directory>(
      future: getApplicationDocumentsDirectory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Read from the temporary folder, not the final calendar folder
        final tempDir = Directory(
          '${snapshot.data!.path}/HolyCanvas/TempBatch',
        );
        if (!tempDir.existsSync()) {
          return const Center(
            child: Text('No batch ready for review. Generate one first.'),
          );
        }

        final files = tempDir.listSync().whereType<File>().toList();
        // Sort files by day number
        files.sort((a, b) {
          final aNum =
              int.tryParse(a.path.split('_').last.split('.').first) ?? 0;
          final bNum =
              int.tryParse(b.path.split('_').last.split('.').first) ?? 0;
          return aNum.compareTo(bNum);
        });

        if (files.isEmpty) {
          return const Center(
            child: Text('No batch ready for review. Generate one first.'),
          );
        }

        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => setState(() {}),
                child: _viewMode == ViewMode.grid
                    ? _buildGridView(files)
                    : _buildListView(files),
              ),
            ),
            // Proceed bar — sticky at the bottom
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.glassShadow.withValues(alpha: 0.1),
                    offset: const Offset(0, -3),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _proceedToCalendar,
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text(
                    'Proceed to Calendar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGridView(List<File> files) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) =>
          _buildImageCard(files[index], isGrid: true),
    );
  }

  Widget _buildListView(List<File> files) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildImageCard(files[index], isGrid: false),
        );
      },
    );
  }

  Widget _buildImageCard(File file, {required bool isGrid}) {
    final dayStr = file.path.split('_').last.split('.').first;
    final dayInt = int.tryParse(dayStr) ?? 1;

    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  file,
                  key: ValueKey(
                    file.lastModifiedSync().millisecondsSinceEpoch,
                  ), // force reload if regenerated
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black45,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Regenerate this day',
                      onPressed: () => _regenerateDay(dayInt),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Day $dayStr',
                  style: AppTextStyles.bodyText.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTemplatesHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No templates saved yet. Create one in the Maker tab first.',
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: widget.onCreateNew,
            child: const Text('Maker →'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressOverlay() {
    final pct = _totalDays == 0 ? 0.0 : _currentDay / _totalDays;
    return Container(
      color: AppColors.background,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: pct,
                  strokeWidth: 8,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
                Text(
                  '${(pct * 100).toInt()}%',
                  style: AppTextStyles.heading2.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'GENERATING BATCH',
            style: AppTextStyles.heading2.copyWith(
              letterSpacing: 4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Day $_currentDay of $_totalDays — $_selectedMonth',
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (_hordeStatus.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _hordeStatus,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

}

// ---------------------------------------------------------------------------
// Off-screen template renderer (used by captureFromWidget)
// ---------------------------------------------------------------------------

/// Renders the full template at its native resolution for screenshot capture.
/// This widget is never shown on screen — it is only passed to
/// [ScreenshotController.captureFromWidget].
///
/// All images are supplied via [preloadedImages] as raw bytes, so the widget
/// tree is fully painted on the very first frame. This prevents the race
/// condition where [Image.network] / [Image.file] finish decoding after the
/// screenshot is already taken, which produced all-white output.
class _TemplateRenderer extends StatelessWidget {
  final TemplateModel template;

  /// Bytes keyed by the original source string (URL or file path).
  /// Base-64 backgrounds are decoded inline and do not appear here.
  final Map<String, Uint8List> preloadedImages;

  const _TemplateRenderer({
    required this.template,
    required this.preloadedImages,
  });

  @override
  Widget build(BuildContext context) {
    final layers = List<LayerModel>.from(template.layers)
      ..sort((a, b) => a.layer.compareTo(b.layer));

    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: template.canvasWidth,
          height: template.canvasHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background (fully synchronous — bytes already loaded)
              _buildBackground(),
              // Layers at full 1:1 template resolution
              ...layers.where((l) => l.visible).map(_buildLayer),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    final bg = template.backgroundImage;
    const fit = BoxFit.cover;

    if (bg == null || bg.isEmpty) return const ColoredBox(color: Colors.white);

    // Base-64 data URI — decode inline (no network call needed)
    if (bg.startsWith('data:')) {
      final commaIdx = bg.indexOf(',');
      if (commaIdx != -1) {
        try {
          final bytes = base64Decode(bg.substring(commaIdx + 1));
          return Image.memory(
            bytes,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
          );
        } catch (e) {
          AppLogger.warn(
            '_TemplateRenderer: base64 background decode error — $e',
          );
        }
      }
    }

    // URL or file path — use pre-loaded bytes if available
    final bytes = preloadedImages[bg];
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
      );
    }

    // Fallback: source wasn't pre-loaded (shouldn't happen in normal flow)
    return const ColoredBox(color: Colors.white);
  }

  Widget _buildLayer(LayerModel layer) {
    return Positioned(
      left: layer.x + layer.dx,
      top: layer.y + layer.dy,
      width: layer.width,
      height: layer.height,
      child: _buildLayerContent(layer),
    );
  }

  Widget _buildLayerContent(LayerModel layer) {
    if (layer.type == LayerType.image) {
      final path = layer.imagePath;
      if (path == null || path.isEmpty) return const SizedBox.shrink();

      final bytes = preloadedImages[path];
      if (bytes == null) return const SizedBox.shrink();

      return ClipRRect(
        borderRadius: BorderRadius.circular(layer.borderRadius ?? 0),
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: layer.width,
          height: layer.height,
        ),
      );
    }

    // Text layer
    final textStyle = TextStyle(
      fontFamily: layer.fontFamily,
      fontSize: layer.autoScale ? 2000.0 : (layer.fontSize ?? 24).toDouble(),
      color: layer.color ?? Colors.black,
      shadows: layer.shadowColor != null
          ? [
              Shadow(
                color: layer.shadowColor!,
                blurRadius: layer.shadowBlur ?? 0,
                offset: Offset(
                  layer.shadowOffsetX ?? 0,
                  layer.shadowOffsetY ?? 0,
                ),
              ),
            ]
          : null,
    );

    final align = _textAlign(layer.textAlign);

    Widget textWidget = AutoSizeText(
      layer.text ?? '',
      textAlign: align,
      softWrap: true,
      overflow: TextOverflow.clip,
      style: textStyle,
      minFontSize: layer.autoScale
          ? 8
          : (layer.fontSize ?? 24).truncateToDouble(),
      maxFontSize: layer.autoScale
          ? 2000
          : (layer.fontSize ?? 24).truncateToDouble(),
      wrapWords: true,
      maxLines: layer.autoScale ? null : 1,
    );

    // Apply text stroke via a foreground-behind trick: render outline first.
    if ((layer.strokeWidth ?? 0) > 0) {
      textWidget = Stack(
        children: [
          AutoSizeText(
            layer.text ?? '',
            textAlign: align,
            style: textStyle.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = (layer.strokeWidth ?? 0) * 2
                ..color = layer.strokeColor ?? Colors.black,
            ),
            minFontSize: layer.autoScale
                ? 8
                : (layer.fontSize ?? 24).truncateToDouble(),
            maxFontSize: layer.autoScale
                ? 2000
                : (layer.fontSize ?? 24).truncateToDouble(),
            wrapWords: true,
            maxLines: layer.autoScale ? null : 1,
          ),
          AutoSizeText(
            layer.text ?? '',
            textAlign: align,
            style: textStyle,
            minFontSize: layer.autoScale
                ? 8
                : (layer.fontSize ?? 24).truncateToDouble(),
            maxFontSize: layer.autoScale
                ? 2000
                : (layer.fontSize ?? 24).truncateToDouble(),
            wrapWords: true,
            maxLines: layer.autoScale ? null : 1,
          ),
        ],
      );
    }

    return SizedBox(
      width: layer.width,
      height: layer.height,
      child: Align(
        alignment: _getAlignment(align, layer.verticalAlign ?? 'middle'),
        child: textWidget,
      ),
    );
  }

  Alignment _getAlignment(TextAlign align, String vertAlign) {
    if (vertAlign == 'top') {
      if (align == TextAlign.left) return Alignment.topLeft;
      if (align == TextAlign.right) return Alignment.topRight;
      return Alignment.topCenter;
    } else if (vertAlign == 'bottom') {
      if (align == TextAlign.left) return Alignment.bottomLeft;
      if (align == TextAlign.right) return Alignment.bottomRight;
      return Alignment.bottomCenter;
    } else {
      if (align == TextAlign.left) return Alignment.centerLeft;
      if (align == TextAlign.right) return Alignment.centerRight;
      return Alignment.center;
    }
  }

  TextAlign _textAlign(String? ta) {
    switch (ta) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.center;
    }
  }
}
