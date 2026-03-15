import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_images.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/font_service.dart';
import '../../data/models/layer_model.dart';
import '../../data/models/template_model.dart';
import '../../logic/providers/template_editor_provider.dart';
import '../widgets/draggable_layer.dart';
import 'template_gallery_screen.dart';

class TemplateMakerScreen extends StatelessWidget {
  const TemplateMakerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TemplateEditorProvider>();
    if (!provider.isEditing) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.primary,
          elevation: 0,
          title: Image.asset(
            AppImages.logo,
            height: 35,
            fit: BoxFit.contain,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Import Template',
              onPressed: () => _importJsonTemplate(context),
            ),
          ],
        ),
        body: TemplateGalleryScreen(onCreateNew: () => provider.resetToNew()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => provider.closeTemplate(),
        ),
        backgroundColor: AppColors.secondary,
        centerTitle: true,
        elevation: 0,
        title: Image.asset(
          AppImages.logo,
          height: 30,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined, color: Colors.white, size: 20),
            onPressed: () => _exportJsonTemplate(context, provider),
          ),
          IconButton(
            icon: const Icon(Icons.layers_outlined, color: Colors.white, size: 20),
            onPressed: () => _showLayerList(context),
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined, color: AppColors.primary, size: 20),
            onPressed: () async {
              await provider.saveTemplate();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Template saved!')),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: _CanvasArea()),
              // Only show EditorPanel if a layer is selected
              if (provider.selectedLayer != null) _EditorPanel(),
              // Padding for bottom toolbar
              const SizedBox(height: 100),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomToolBar(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Import JSON
  // ---------------------------------------------------------------------------

  Future<void> _exportJsonTemplate(
    BuildContext context,
    TemplateEditorProvider provider,
  ) async {
    try {
      final jsonStr = provider.exportToJson();
      final tempDir = await Directory.systemTemp.createTemp();
      final file = File(
        '${tempDir.path}/${provider.currentTemplate.name}.json',
      );
      await file.writeAsString(jsonStr);

      final xFile = XFile(file.path);
      // ignore: deprecated_member_use
      await Share.shareXFiles([xFile], text: 'My Holy Canvas Template');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export: $e')));
      }
    }
  }

  Future<void> _importJsonTemplate(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType
            .any, // Workaround since some Androids don't classify .json cleanly
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonStr = await file.readAsString();

        if (context.mounted) {
          context.read<TemplateEditorProvider>().importFromJson(jsonStr);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Template imported!')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load JSON file')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Add Layer dialog
  // ---------------------------------------------------------------------------

  void _showAddLayerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Add Layer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            _addLayerTile(
              ctx,
              context,
              icon: Icons.image,
              label: 'Set Background Image',
              onTap: () async {
                final picker = ImagePicker();
                final XFile? img = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (img != null && context.mounted) {
                  context.read<TemplateEditorProvider>().setBackground(
                    img.path,
                  );
                }
              },
            ),
            _addLayerTile(
              ctx,
              context,
              icon: Icons.text_fields,
              label: 'Add English Verse',
              onTap: () => context.read<TemplateEditorProvider>().addTextLayer(
                TextType.englishVerse,
                'For God so loved the world...',
              ),
            ),
            _addLayerTile(
              ctx,
              context,
              icon: Icons.text_fields,
              label: 'Add Telugu Verse',
              onTap: () => context.read<TemplateEditorProvider>().addTextLayer(
                TextType.teluguVerse,
                'దేవుడు లోకమును ఎంతో ప్రేమించెను...',
              ),
            ),
            _addLayerTile(
              ctx,
              context,
              icon: Icons.text_fields,
              label: 'Add English Reference',
              onTap: () => context.read<TemplateEditorProvider>().addTextLayer(
                TextType.englishReference,
                'John 3:16',
              ),
            ),
            _addLayerTile(
              ctx,
              context,
              icon: Icons.text_fields,
              label: 'Add Telugu Reference',
              onTap: () => context.read<TemplateEditorProvider>().addTextLayer(
                TextType.teluguReference,
                'యోహాను 3:16',
              ),
            ),
            _addLayerTile(
              ctx,
              context,
              icon: Icons.text_fields,
              label: 'Add Ministry Name',
              onTap: () => context.read<TemplateEditorProvider>().addTextLayer(
                TextType.ministryName,
                'My Ministry',
              ),
            ),
            _addLayerTile(
              ctx,
              context,
              icon: Icons.text_fields,
              label: 'Add Speaker Name',
              onTap: () => context.read<TemplateEditorProvider>().addTextLayer(
                TextType.speakerName,
                'Speaker Name',
              ),
            ),
            _addLayerTile(
              ctx,
              context,
              icon: Icons.image_outlined,
              label: 'Add Logo / Image Layer',
              onTap: () async {
                final picker = ImagePicker();
                final XFile? img = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (img != null && context.mounted) {
                  context.read<TemplateEditorProvider>().addImageLayer(
                    img.path,
                  );
                }
              },
            ),
            _addLayerTile(
              ctx,
              context,
              icon: Icons.add_box_outlined,
              label: 'Add Custom Text',
              onTap: () => context.read<TemplateEditorProvider>().addTextLayer(
                TextType.custom,
                'Custom text',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addLayerTile(
    BuildContext sheetCtx,
    BuildContext screenCtx, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      onTap: () {
        Navigator.pop(sheetCtx);
        onTap();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Layer list
  // ---------------------------------------------------------------------------

  void _showLayerList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Consumer<TemplateEditorProvider>(
            builder: (_, provider, __) {
              final layers = List<LayerModel>.from(provider.currentTemplate.layers)
                ..sort((a, b) => b.layer.compareTo(a.layer));

              return Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TEMPLATE LAYERS',
                          style: AppTextStyles.heading2.copyWith(
                            fontSize: 18,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Search Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              icon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5), size: 18),
                              hintText: 'Search for specific layer',
                              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: layers.length,
                      itemBuilder: (_, i) {
                        final layer = layers[i];
                        final isSelected = provider.selectedLayer?.id == layer.id;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : Colors.transparent,
                              width: 1.5,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ] : [],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.background,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                layer.type == LayerType.text ? Icons.text_fields : Icons.image_outlined,
                                color: isSelected ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.5),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              (layer.name ?? layer.textType?.name ?? 'Layer').toUpperCase(),
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppTextStyles.heading1.color : AppColors.textSecondary,
                                letterSpacing: 1.0,
                              ),
                            ),
                            subtitle: Text(
                              'ORDER: ${layer.layer}',
                              style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    layer.visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    size: 18,
                                    color: layer.visible ? AppColors.primary : Colors.grey,
                                  ),
                                  onPressed: () => provider.updateLayerVisibility(layer.id, visible: !layer.visible),
                                ),
                                Icon(Icons.lock_outline, size: 18, color: Colors.grey.withValues(alpha: 0.3)),
                              ],
                            ),
                            onTap: () {
                              provider.selectLayer(layer.id);
                              Navigator.pop(ctx);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Canvas Area
// =============================================================================

class _CanvasArea extends StatefulWidget {
  @override
  State<_CanvasArea> createState() => _CanvasAreaState();
}

class _CanvasAreaState extends State<_CanvasArea> {
  final TransformationController _transformController =
      TransformationController();

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TemplateEditorProvider>(
      builder: (context, provider, _) {
        final template = provider.currentTemplate;
        final layers = List<LayerModel>.from(template.layers)
          ..sort((a, b) => a.layer.compareTo(b.layer));

        return Column(
          children: [
            // Zoom controls bar
            Container(
              color: Colors.grey.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.zoom_in, color: Colors.white54, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    'Pinch to zoom • Scroll to pan',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _resetZoom,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Reset Zoom',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Canvas
            Expanded(
              child: GestureDetector(
                // Tap outside any layer to deselect
                onTap: () => provider.clearSelection(),
                child: Container(
                  color: Colors.grey.shade800,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: template.canvasWidth / template.canvasHeight,
                      child: LayoutBuilder(
                        builder: (_, constraints) {
                          // The scale factor that maps template-space
                          // coordinates (e.g. 1080px) to screen pixels.
                          final canvasScale =
                              constraints.maxWidth / template.canvasWidth;

                          return InteractiveViewer(
                            transformationController: _transformController,
                            minScale: 0.5,
                            maxScale: 8.0,
                            // Clip so zoomed content doesn't escape the
                            // canvas boundary.
                            clipBehavior: Clip.hardEdge,
                            child: Screenshot(
                              controller: provider.screenshotController,
                              child: ClipRect(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _buildBackground(template),
                                    // Each layer gets the scale factor so
                                    // it can convert template-space coords
                                    // to screen-space pixels correctly.
                                    ...layers.map(
                                      (layer) => DraggableLayer(
                                        key: ValueKey(layer.id),
                                        layer: layer,
                                        canvasScale: canvasScale,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
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

  Widget _buildBackground(TemplateModel template) {
    final bg = template.backgroundImage;
    final fit = template.backgroundFit == 'contain'
        ? BoxFit.contain
        : BoxFit.cover;

    if (bg == null) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image, size: 48, color: Colors.black26),
              SizedBox(height: 8),
              Text(
                'Tap + to add layers',
                style: TextStyle(color: Colors.black38),
              ),
            ],
          ),
        ),
      );
    }

    if (bg.startsWith('data:')) {
      final commaIdx = bg.indexOf(',');
      final bytes = base64Decode(bg.substring(commaIdx + 1));
      return Image.memory(
        bytes,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
      );
    }
    if (bg.startsWith('http')) {
      return Image.network(
        bg,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return Image.file(
      File(bg),
      fit: fit,
      width: double.infinity,
      height: double.infinity,
    );
  }
}

// =============================================================================
// Bottom Editor Panel
// =============================================================================

/// Slides up from the bottom when a layer is selected and provides tabbed
/// editing
class _BottomToolBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: const BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildToolItem(context, Icons.format_list_bulleted_rounded, 'LIST', () => (context.read<TemplateMakerScreen>())._showLayerList(context)),
          _buildToolItem(context, Icons.text_fields_rounded, 'TEXT', () => _showAddTextOptions(context)),
          _buildToolItem(context, Icons.sticky_note_2_outlined, 'STICKER', () {}),
          _buildToolItem(context, Icons.image_outlined, 'IMAGE', () => _showAddImageOptions(context)),
          _buildToolItem(context, Icons.wallpaper_rounded, 'BACKGROUND', () {}),
          _buildToolItem(context, Icons.crop_free_rounded, 'CANVAS', () {}),
        ],
      ),
    );
  }

  Widget _buildToolItem(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 8,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTextOptions(BuildContext context) {
    // Re-use _showAddLayerDialog but filtered for text
    (context.read<TemplateMakerScreen>())._showAddLayerDialog(context);
  }

  void _showAddImageOptions(BuildContext context) {
     (context.read<TemplateMakerScreen>())._showAddLayerDialog(context);
  }
}

class _EditorPanel extends StatefulWidget {
  @override
  State<_EditorPanel> createState() => _EditorPanelState();
}

class _EditorPanelState extends State<_EditorPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TemplateEditorProvider>(
      builder: (ctx, provider, _) {
        final layer = provider.selectedLayer;
        if (layer == null) return const SizedBox.shrink();

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      layer.type == LayerType.text ? Icons.text_fields : Icons.image_outlined,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (layer.name ?? layer.textType?.name ?? 'Layer').toUpperCase(),
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: 1.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.grey, size: 18),
                      onPressed: () => provider.duplicateLayer(layer.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                      onPressed: () => provider.removeLayer(layer.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                      onPressed: () => provider.clearSelection(),
                    ),
                  ],
                ),
              ),
              // Tabs
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.black26,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, fontSize: 10),
                tabs: const [
                  Tab(text: 'STYLE'),
                  Tab(text: 'IMAGE'),
                  Tab(text: 'ARRANGE'),
                ],
              ),
              // Tab content
              SizedBox(
                height: 230,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTextStyleTab(layer, provider),
                    _buildImageStyleTab(layer, provider),
                    _buildArrangeTab(layer, provider),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextStyleTab(LayerModel layer, TemplateEditorProvider provider) {
    if (layer.type != LayerType.text) {
      return const Center(child: Text('Not a text layer'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
           Text('Text Controls Coming Soon', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildImageStyleTab(LayerModel layer, TemplateEditorProvider provider) {
    return const Center(child: Text('Image Controls Coming Soon'));
  }

  Widget _buildArrangeTab(LayerModel layer, TemplateEditorProvider provider) {
    return const Center(child: Text('Layer Arrangement Coming Soon'));
  }
}

// =============================================================================
// Text Edit Tab
// =============================================================================

class _TextEditTab extends StatefulWidget {
  final LayerModel layer;
  final TemplateEditorProvider provider;

  const _TextEditTab({required this.layer, required this.provider});

  @override
  State<_TextEditTab> createState() => _TextEditTabState();
}

class _TextEditTabState extends State<_TextEditTab> {
  late final TextEditingController _textCtrl;
  late double _fontSize;
  late String _selectedFont;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.layer.text ?? '');
    _fontSize = widget.layer.fontSize ?? 24;
    _selectedFont = widget.layer.fontFamily ?? kBundledFonts.first;
  }

  @override
  void didUpdateWidget(_TextEditTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layer.id != widget.layer.id) {
      _textCtrl.text = widget.layer.text ?? '';
      _fontSize = widget.layer.fontSize ?? 24;
      _selectedFont = widget.layer.fontFamily ?? kBundledFonts.first;
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text content
          TextField(
            controller: _textCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Text Content',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            onChanged: (v) =>
                widget.provider.updateLayerText(widget.layer.id, v),
          ),
          const SizedBox(height: 10),
          // Font size row
          Row(
            children: [
              const Text('Size:', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 8,
                  max: 200,
                  divisions: 192,
                  activeColor: AppColors.primary,
                  onChanged: (v) {
                    setState(() => _fontSize = v);
                    widget.provider.updateLayerFontSize(widget.layer.id, v);
                  },
                ),
              ),
              SizedBox(
                width: 38,
                child: Text(
                  _fontSize.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          // Color + Text align row
          Row(
            children: [
              const Text('Color:', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              _ColorButton(
                color: widget.layer.color ?? Colors.black,
                onPick: (c) =>
                    widget.provider.updateLayerColor(widget.layer.id, c),
              ),
              const SizedBox(width: 16),
              const Text('Align:', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              _AlignButtons(layer: widget.layer, provider: widget.provider),
              const SizedBox(width: 8),
              _VerticalAlignButtons(
                layer: widget.layer,
                provider: widget.provider,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Auto Scale Bound row
          Row(
            children: [
              const Text(
                'Auto Scale Bound:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Switch(
                value: widget.layer.autoScale,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => widget.provider.updateLayerAutoScale(
                  widget.layer.id,
                  autoScale: v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Font family picker
          const Text(
            'Font Family:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kAllAvailableFonts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final font = kAllAvailableFonts[i];
                final isSelected = _selectedFont == font;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedFont = font);
                    widget.provider.updateLayerFontFamily(
                      widget.layer.id,
                      font,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? null
                          : Border.all(color: Colors.grey.shade400),
                    ),
                    child: Text(
                      font,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: font,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Shadow controls
          const Text(
            'Text Shadow:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          _ShadowControls(layer: widget.layer, provider: widget.provider),
          const SizedBox(height: 6),
          // Stroke controls
          const Text(
            'Stroke / Outline:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          _StrokeControls(layer: widget.layer, provider: widget.provider),
        ],
      ),
    );
  }
}

// =============================================================================
// Image Edit Tab
// =============================================================================

class _ImageEditTab extends StatefulWidget {
  final LayerModel layer;
  final TemplateEditorProvider provider;

  const _ImageEditTab({required this.layer, required this.provider});

  @override
  State<_ImageEditTab> createState() => _ImageEditTabState();
}

class _ImageEditTabState extends State<_ImageEditTab> {
  late double _borderRadius;
  late double _borderWidth;

  @override
  void initState() {
    super.initState();
    _borderRadius = widget.layer.borderRadius ?? 0;
    _borderWidth = widget.layer.borderWidth ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_library, size: 18),
                label: const Text('Pick Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  final picker = ImagePicker();
                  final XFile? img = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (img != null) {
                    widget.provider.updateLayerImagePath(
                      widget.layer.id,
                      img.path,
                    );
                  }
                },
              ),
              // Image Role Dropdown
              DropdownButton<ImageType>(
                value: widget.layer.imageType ?? ImageType.custom,
                icon: const Icon(Icons.arrow_drop_down, size: 18),
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                    value: ImageType.custom,
                    child: Text('Custom Image'),
                  ),
                  DropdownMenuItem(
                    value: ImageType.speakerImage,
                    child: Text('Speaker Image'),
                  ),
                  DropdownMenuItem(
                    value: ImageType.verseImage,
                    child: Text('Verse (AI) Image'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    widget.provider.updateLayerImageType(widget.layer.id, val);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Image Fit
          Row(
            children: [
              const Text(
                'Image Fit:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: widget.layer.imageFit ?? 'cover',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                isDense: true,
                items: const [
                  DropdownMenuItem(value: 'cover', child: Text('Cover')),
                  DropdownMenuItem(value: 'contain', child: Text('Contain')),
                  DropdownMenuItem(value: 'fill', child: Text('Fill')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    widget.provider.updateLayerImageFit(widget.layer.id, val);
                  }
                },
              ),
            ],
          ),
          const Divider(height: 24),

          // Border Radius
          const Text(
            'Border Radius:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _borderRadius,
                  min: 0,
                  max: 500,
                  activeColor: AppColors.primary,
                  onChanged: (v) {
                    setState(() => _borderRadius = v);
                    widget.provider.updateLayerImageBorder(
                      widget.layer.id,
                      borderRadius: v,
                      borderWidth: widget.layer.borderWidth,
                      borderColor: widget.layer.borderColor,
                    );
                  },
                ),
              ),
              Text(
                _borderRadius.toStringAsFixed(0),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),

          // Border Width
          const Text(
            'Border Width:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _borderWidth,
                  min: 0,
                  max: 50,
                  activeColor: AppColors.primary,
                  onChanged: (v) {
                    setState(() => _borderWidth = v);
                    widget.provider.updateLayerImageBorder(
                      widget.layer.id,
                      borderWidth: v,
                      borderRadius: widget.layer.borderRadius,
                      borderColor: widget.layer.borderColor ?? Colors.white,
                    );
                  },
                ),
              ),
              Text(
                _borderWidth.toStringAsFixed(0),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),

          // Border Color
          Row(
            children: [
              const Text('Border Color:', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              _ColorButton(
                color: widget.layer.borderColor ?? Colors.transparent,
                onPick: (c) => widget.provider.updateLayerImageBorder(
                  widget.layer.id,
                  borderColor: c,
                  borderRadius: widget.layer.borderRadius,
                  borderWidth: _borderWidth > 0 ? _borderWidth : 2.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Layer Edit Tab
// =============================================================================

class _LayerEditTab extends StatefulWidget {
  final LayerModel layer;
  final TemplateEditorProvider provider;

  const _LayerEditTab({required this.layer, required this.provider});

  @override
  State<_LayerEditTab> createState() => _LayerEditTabState();
}

class _LayerEditTabState extends State<_LayerEditTab> {
  late double _width;
  late double _height;

  @override
  void initState() {
    super.initState();
    _width = widget.layer.width;
    _height = widget.layer.height;
  }

  @override
  void didUpdateWidget(_LayerEditTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layer.id != widget.layer.id) {
      _width = widget.layer.width;
      _height = widget.layer.height;
    }
  }

  void _nudge(double dx, double dy) {
    widget.provider.updateLayerPosition(widget.layer.id, dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    final layer = widget.layer;
    final provider = widget.provider;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Visibility ──────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.visibility, size: 18, color: Colors.black54),
              const SizedBox(width: 6),
              const Text('Visible'),
              const Spacer(),
              Switch(
                value: layer.visible,
                activeThumbColor: AppColors.primary,
                onChanged: (v) =>
                    provider.updateLayerVisibility(layer.id, visible: v),
              ),
            ],
          ),
          const Divider(height: 12),

          // ── Z-Order + Quick actions ───────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _iconBtn(
                Icons.flip_to_front,
                'Forward',
                () => provider.bringLayerForward(layer.id),
              ),
              _iconBtn(
                Icons.flip_to_back,
                'Backward',
                () => provider.sendLayerBackward(layer.id),
              ),
              _iconBtn(
                Icons.copy,
                'Duplicate',
                () => provider.duplicateLayer(layer.id),
              ),
              _iconBtn(
                Icons.delete_outline,
                'Delete',
                () => provider.removeLayer(layer.id),
                color: AppColors.error,
              ),
            ],
          ),
          const Divider(height: 12),

          // ── Nudge (position) ─────────────────────────────────────────
          const Text(
            'NUDGE POSITION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Colors.black45,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // X axis nudge
              _nudgeBtn(
                Icons.keyboard_arrow_left,
                () => _nudge(-1, 0),
                () => _nudge(-10, 0),
              ),
              const SizedBox(width: 4),
              Column(
                children: [
                  _nudgeBtn(
                    Icons.keyboard_arrow_up,
                    () => _nudge(0, -1),
                    () => _nudge(0, -10),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'X:${(layer.x + layer.dx).toStringAsFixed(0)}  '
                      'Y:${(layer.y + layer.dy).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _nudgeBtn(
                    Icons.keyboard_arrow_down,
                    () => _nudge(0, 1),
                    () => _nudge(0, 10),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              _nudgeBtn(
                Icons.keyboard_arrow_right,
                () => _nudge(1, 0),
                () => _nudge(10, 0),
              ),
            ],
          ),
          const Divider(height: 12),

          // ── Width & Height ────────────────────────────────────────────
          const Text(
            'SIZE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Colors.black45,
            ),
          ),
          const SizedBox(height: 6),
          // Width
          Row(
            children: [
              const SizedBox(
                width: 18,
                child: Text('W', style: TextStyle(fontSize: 11)),
              ),
              Expanded(
                child: Slider(
                  value: _width.clamp(20, 1080),
                  min: 20,
                  max: 1080,
                  activeColor: AppColors.primary,
                  onChanged: (v) {
                    setState(() => _width = v);
                    provider.updateLayerSize(layer.id, v, _height);
                  },
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  _width.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          // Height
          Row(
            children: [
              const SizedBox(
                width: 18,
                child: Text('H', style: TextStyle(fontSize: 11)),
              ),
              Expanded(
                child: Slider(
                  value: _height.clamp(20, 1080),
                  min: 20,
                  max: 1080,
                  activeColor: AppColors.primary,
                  onChanged: (v) {
                    setState(() => _height = v);
                    provider.updateLayerSize(layer.id, _width, v);
                  },
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  _height.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Arrow nudge button — tap = fine move, long-press = coarse move.
  Widget _nudgeBtn(
    IconData icon,
    VoidCallback onTap,
    VoidCallback onLongPress,
  ) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
    );
  }

  Widget _iconBtn(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color color = AppColors.primary,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: color, size: 22),
          onPressed: onTap,
        ),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
      ],
    );
  }
}

// =============================================================================
// Reusable sub-widgets
// =============================================================================

/// A simple color picker button that opens a color grid dialog.
class _ColorButton extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onPick;

  const _ColorButton({required this.color, required this.onPick});

  static const List<Color> _palette = [
    Colors.white,
    Colors.black,
    Color(0xFFFFFFFF),
    Color(0xFF442221),
    Color(0xFFffc800),
    Color(0xFF14213D),
    Color(0xFFFCA311),
    Color(0xFFD32F2F),
    Color(0xFF388E3C),
    Color(0xFF1565C0),
    Color(0xFF7B1FA2),
    Color(0xFFFF6F00),
    Color(0xFF00838F),
    Colors.pink,
    Colors.teal,
    Colors.cyan,
    Colors.amber,
    Colors.deepOrange,
    Colors.indigo,
    Colors.lime,
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showColorPicker(context),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black26, width: 1.5),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pick Color'),
        content: SizedBox(
          width: 250,
          child: GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: _palette.map((c) {
              return GestureDetector(
                onTap: () {
                  onPick(c);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c == color ? AppColors.primary : Colors.black26,
                      width: c == color ? 3 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// L / C / R alignment buttons for text layers.
class _AlignButtons extends StatelessWidget {
  final LayerModel layer;
  final TemplateEditorProvider provider;

  const _AlignButtons({required this.layer, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(Icons.format_align_left, 'left'),
        _btn(Icons.format_align_center, 'center'),
        _btn(Icons.format_align_right, 'right'),
      ],
    );
  }

  Widget _btn(IconData icon, String align) {
    final isActive = (layer.textAlign ?? 'center') == align;
    return GestureDetector(
      onTap: () => provider.updateLayerTextAlign(layer.id, align),
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isActive ? Colors.white : Colors.black54,
        ),
      ),
    );
  }
}

/// Top / Middle / Bottom vertical alignment buttons for text layers.
class _VerticalAlignButtons extends StatelessWidget {
  final LayerModel layer;
  final TemplateEditorProvider provider;

  const _VerticalAlignButtons({required this.layer, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(Icons.vertical_align_top, 'top'),
        _btn(Icons.vertical_align_center, 'middle'),
        _btn(Icons.vertical_align_bottom, 'bottom'),
      ],
    );
  }

  Widget _btn(IconData icon, String align) {
    // Default vertical alignment to middle if null
    final isActive = (layer.verticalAlign ?? 'middle') == align;
    return GestureDetector(
      onTap: () => provider.updateLayerVerticalAlign(layer.id, align),
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isActive ? Colors.white : Colors.black54,
        ),
      ),
    );
  }
}

/// Shadow controls — color + blur + offset X + offset Y.
class _ShadowControls extends StatefulWidget {
  final LayerModel layer;
  final TemplateEditorProvider provider;

  const _ShadowControls({required this.layer, required this.provider});

  @override
  State<_ShadowControls> createState() => _ShadowControlsState();
}

class _ShadowControlsState extends State<_ShadowControls> {
  late double _blur;
  late double _ox;
  late double _oy;
  late Color _color;

  @override
  void initState() {
    super.initState();
    _blur = widget.layer.shadowBlur ?? 0;
    _ox = widget.layer.shadowOffsetX ?? 0;
    _oy = widget.layer.shadowOffsetY ?? 0;
    _color = widget.layer.shadowColor ?? Colors.black;
  }

  void _apply() {
    widget.provider.updateLayerShadow(
      widget.layer.id,
      color: _color,
      blur: _blur,
      offsetX: _ox,
      offsetY: _oy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Text('Color:', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
            _ColorButton(
              color: _color,
              onPick: (c) {
                setState(() => _color = c);
                _apply();
              },
            ),
            const SizedBox(width: 10),
            const Text('Blur:', style: TextStyle(fontSize: 11)),
            Expanded(
              child: Slider(
                value: _blur,
                min: 0,
                max: 30,
                activeColor: AppColors.primary,
                onChanged: (v) {
                  setState(() => _blur = v);
                  _apply();
                },
              ),
            ),
            Text(
              _blur.toStringAsFixed(0),
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        Row(
          children: [
            const Text('X:', style: TextStyle(fontSize: 11)),
            Expanded(
              child: Slider(
                value: _ox,
                min: -20,
                max: 20,
                activeColor: AppColors.primary,
                onChanged: (v) {
                  setState(() => _ox = v);
                  _apply();
                },
              ),
            ),
            const SizedBox(width: 8),
            const Text('Y:', style: TextStyle(fontSize: 11)),
            Expanded(
              child: Slider(
                value: _oy,
                min: -20,
                max: 20,
                activeColor: AppColors.primary,
                onChanged: (v) {
                  setState(() => _oy = v);
                  _apply();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Stroke / outline width + color controls.
class _StrokeControls extends StatefulWidget {
  final LayerModel layer;
  final TemplateEditorProvider provider;

  const _StrokeControls({required this.layer, required this.provider});

  @override
  State<_StrokeControls> createState() => _StrokeControlsState();
}

class _StrokeControlsState extends State<_StrokeControls> {
  late double _width;
  late Color _color;

  @override
  void initState() {
    super.initState();
    _width = widget.layer.strokeWidth ?? 0;
    _color = widget.layer.strokeColor ?? Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Color:', style: TextStyle(fontSize: 11)),
        const SizedBox(width: 4),
        _ColorButton(
          color: _color,
          onPick: (c) {
            setState(() => _color = c);
            widget.provider.updateLayerStroke(widget.layer.id, _color, _width);
          },
        ),
        const SizedBox(width: 10),
        const Text('Width:', style: TextStyle(fontSize: 11)),
        Expanded(
          child: Slider(
            value: _width,
            min: 0,
            max: 10,
            activeColor: AppColors.primary,
            onChanged: (v) {
              setState(() => _width = v);
              widget.provider.updateLayerStroke(widget.layer.id, _color, v);
            },
          ),
        ),
        Text(_width.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
