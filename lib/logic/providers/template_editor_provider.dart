import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:uuid/uuid.dart';

import '../../core/logger/app_logger.dart';
import '../../core/services/font_service.dart';
import '../../data/models/layer_model.dart';
import '../../data/models/template_model.dart';
import '../../data/repositories/template_repository.dart';

class TemplateEditorProvider extends ChangeNotifier {
  final TemplateRepository repository = TemplateRepository();
  final ScreenshotController screenshotController = ScreenshotController();
  final _uuid = const Uuid();

  TemplateModel _currentTemplate = TemplateModel(
    id: const Uuid().v4(),
    name: 'New Template',
    createdAt: DateTime.now(),
  );

  TemplateModel get currentTemplate => _currentTemplate;

  bool _isEditing = false;
  bool get isEditing => _isEditing;

  LayerModel? _selectedLayer;
  LayerModel? get selectedLayer => _selectedLayer;

  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;

  // ---------------------------------------------------------------------------
  // Selection
  // ---------------------------------------------------------------------------

  void selectLayer(String id) {
    _selectedLayer = _currentTemplate.layers.firstWhere(
      (l) => l.id == id,
      orElse: () => _selectedLayer ?? _currentTemplate.layers.first,
    );
    notifyListeners();
  }

  void clearSelection() {
    _selectedLayer = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Template lifecycle
  // ---------------------------------------------------------------------------

  void loadTemplate(TemplateModel template) {
    _currentTemplate = template;
    _selectedLayer = null;
    _isEditing = true;
    notifyListeners();
  }

  void resetToNew() {
    _currentTemplate = TemplateModel(
      id: _uuid.v4(),
      name: 'New Template',
      createdAt: DateTime.now(),
    );
    _selectedLayer = null;
    _isEditing = true;
    notifyListeners();
  }

  void closeTemplate() {
    _isEditing = false;
    _selectedLayer = null;
    notifyListeners();
  }

  void renameTemplate(String newName) {
    _currentTemplate = _currentTemplate.copyWith(name: newName);
    notifyListeners();
  }

  String exportToJson() {
    return jsonEncode(_currentTemplate.toMap());
  }

  /// Parses a JESUS Template 2.json string and loads it as the current
  /// template, resolving font aliases via [FontService].
  void importFromJson(String jsonString) {
    try {
      final template = TemplateModel.fromJesusJson(
        jsonString,
        newId: _uuid.v4(),
      );

      // Resolve font aliases so layers use the correct local bundled family.
      final resolvedLayers = template.layers.map((layer) {
        if (layer.type == LayerType.text && layer.fontFamily != null) {
          final resolved = FontService.instance.resolveFamily(layer.fontFamily);
          return layer.copyWith(fontFamily: resolved);
        }
        return layer;
      }).toList();

      _currentTemplate = template.copyWith(layers: resolvedLayers);
      _selectedLayer = null;
      notifyListeners();
      AppLogger.info('Template imported: ${template.name}');
    } catch (e) {
      AppLogger.error('Failed to import template JSON', e);
    }
  }

  // ---------------------------------------------------------------------------
  // Background
  // ---------------------------------------------------------------------------

  void setBackground(String pathOrBase64) {
    _currentTemplate = _currentTemplate.copyWith(backgroundImage: pathOrBase64);
    notifyListeners();
  }

  void setBackgroundFit(String fit) {
    _currentTemplate = _currentTemplate.copyWith(backgroundFit: fit);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Add layers
  // ---------------------------------------------------------------------------

  void addTextLayer(TextType textType, String initialText) {
    final layer = LayerModel(
      id: _uuid.v4(),
      type: LayerType.text,
      name: textType.name,
      textType: textType,
      text: initialText,
      fontSize: 24,
      color: Colors.black,
      x: 50,
      y: 100,
      width: 300,
      height: 60,
      layer: _nextLayerOrder,
    );
    _currentTemplate = _currentTemplate.copyWith(
      layers: [..._currentTemplate.layers, layer],
    );
    _selectedLayer = layer;
    notifyListeners();
  }

  void addImageLayer(String imagePath, {ImageType? imageType}) {
    final layer = LayerModel(
      id: _uuid.v4(),
      type: LayerType.image,
      name: 'image',
      imagePath: imagePath,
      imageType: imageType,
      x: 100,
      y: 100,
      width: 200,
      height: 200,
      layer: _nextLayerOrder,
    );
    _currentTemplate = _currentTemplate.copyWith(
      layers: [..._currentTemplate.layers, layer],
    );
    _selectedLayer = layer;
    notifyListeners();
  }

  int get _nextLayerOrder => _currentTemplate.layers.isEmpty
      ? 1
      : _currentTemplate.layers
                .map((l) => l.layer)
                .reduce((a, b) => a > b ? a : b) +
            1;

  // ---------------------------------------------------------------------------
  // Layer property updates
  // ---------------------------------------------------------------------------

  void updateLayerText(String id, String text) =>
      _updateLayer(id, (l) => l.copyWith(text: text));

  void updateLayerFont(String id, String family, double size) =>
      _updateLayer(id, (l) => l.copyWith(fontFamily: family, fontSize: size));

  void updateLayerFontFamily(String id, String family) =>
      _updateLayer(id, (l) => l.copyWith(fontFamily: family));

  void updateLayerFontSize(String id, double size) =>
      _updateLayer(id, (l) => l.copyWith(fontSize: size));

  void updateLayerColor(String id, Color color) =>
      _updateLayer(id, (l) => l.copyWith(color: color));

  void updateLayerTextAlign(String id, String align) =>
      _updateLayer(id, (l) => l.copyWith(textAlign: align));

  void updateLayerVerticalAlign(String id, String align) =>
      _updateLayer(id, (l) => l.copyWith(verticalAlign: align));

  void updateLayerAutoScale(String id, {required bool autoScale}) =>
      _updateLayer(id, (l) => l.copyWith(autoScale: autoScale));

  void updateLayerShadow(
    String id, {
    required Color color,
    required double blur,
    required double offsetX,
    required double offsetY,
  }) => _updateLayer(
    id,
    (l) => l.copyWith(
      shadowColor: color,
      shadowBlur: blur,
      shadowOffsetX: offsetX,
      shadowOffsetY: offsetY,
    ),
  );

  void updateLayerStroke(String id, Color color, double width) => _updateLayer(
    id,
    (l) => l.copyWith(strokeColor: color, strokeWidth: width),
  );

  void updateLayerVisibility(String id, {required bool visible}) =>
      _updateLayer(id, (l) => l.copyWith(visible: visible));

  void updateLayerSize(String id, double width, double height) =>
      _updateLayer(id, (l) => l.copyWith(width: width, height: height));

  void updateLayerImageBorder(
    String id, {
    double? borderRadius,
    Color? borderColor,
    double? borderWidth,
  }) => _updateLayer(
    id,
    (l) => l.copyWith(
      borderRadius: borderRadius,
      borderColor: borderColor,
      borderWidth: borderWidth,
    ),
  );

  void updateLayerImagePath(String id, String imagePath) =>
      _updateLayer(id, (l) => l.copyWith(imagePath: imagePath));

  void updateLayerImageFit(String id, String fit) =>
      _updateLayer(id, (l) => l.copyWith(imageFit: fit));

  void updateLayerImageType(String id, ImageType type) =>
      _updateLayer(id, (l) => l.copyWith(imageType: type));

  // ---------------------------------------------------------------------------
  // Drag & scale
  // ---------------------------------------------------------------------------

  void updateLayerPosition(String id, double deltaX, double deltaY) {
    _updateLayer(id, (l) => l.copyWith(dx: l.dx + deltaX, dy: l.dy + deltaY));
  }

  void updateLayerScale(String id, double newScale) =>
      _updateLayer(id, (l) => l.copyWith(scale: newScale));

  // ---------------------------------------------------------------------------
  // Layer management
  // ---------------------------------------------------------------------------

  void removeLayer(String id) {
    final newLayers = _currentTemplate.layers.where((l) => l.id != id).toList();
    _currentTemplate = _currentTemplate.copyWith(layers: newLayers);
    if (_selectedLayer?.id == id) _selectedLayer = null;
    notifyListeners();
  }

  void duplicateLayer(String id) {
    final source = _currentTemplate.layers.firstWhere((l) => l.id == id);
    final copy = source.copyWith(
      id: _uuid.v4(),
      x: source.x + 20,
      y: source.y + 20,
      layer: _nextLayerOrder,
    );
    _currentTemplate = _currentTemplate.copyWith(
      layers: [..._currentTemplate.layers, copy],
    );
    _selectedLayer = copy;
    notifyListeners();
  }

  /// Swaps the selected layer one position forward in the layer list.
  void bringLayerForward(String id) {
    final layers = List<LayerModel>.from(_currentTemplate.layers);
    final idx = layers.indexWhere((l) => l.id == id);
    if (idx < layers.length - 1) {
      // Swap layer order values
      final aOrder = layers[idx].layer;
      final bOrder = layers[idx + 1].layer;
      layers[idx] = layers[idx].copyWith(layer: bOrder);
      layers[idx + 1] = layers[idx + 1].copyWith(layer: aOrder);
      layers.sort((a, b) => a.layer.compareTo(b.layer));
      _currentTemplate = _currentTemplate.copyWith(layers: layers);
      _syncSelectedLayer(id);
      notifyListeners();
    }
  }

  /// Swaps the selected layer one position backward in the layer list.
  void sendLayerBackward(String id) {
    final layers = List<LayerModel>.from(_currentTemplate.layers);
    final idx = layers.indexWhere((l) => l.id == id);
    if (idx > 0) {
      final aOrder = layers[idx].layer;
      final bOrder = layers[idx - 1].layer;
      layers[idx] = layers[idx].copyWith(layer: bOrder);
      layers[idx - 1] = layers[idx - 1].copyWith(layer: aOrder);
      layers.sort((a, b) => a.layer.compareTo(b.layer));
      _currentTemplate = _currentTemplate.copyWith(layers: layers);
      _syncSelectedLayer(id);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> saveTemplate() async {
    try {
      final LayerModel? cachedSelection = _selectedLayer;
      _selectedLayer = null;
      _isCapturing = true; // Hide active boundaries during capture
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 120));

      final imageBytes = await screenshotController.capture(
        delay: const Duration(milliseconds: 100),
      );

      _selectedLayer = cachedSelection;
      _isCapturing = false;
      notifyListeners();

      if (imageBytes != null) {
        final dir = await getApplicationDocumentsDirectory();
        final thumbDir = Directory('${dir.path}/HolyCanvas/Thumbnails');
        if (!await thumbDir.exists()) {
          await thumbDir.create(recursive: true);
        }
        final thumbFile = File(
          '${thumbDir.path}/thumb_${_currentTemplate.id}.png',
        );
        await thumbFile.writeAsBytes(imageBytes);

        _currentTemplate = _currentTemplate.copyWith(
          thumbnailPath: thumbFile.path,
        );
      }
    } catch (e) {
      AppLogger.error('Failed to capture template thumbnail', e);
    }

    AppLogger.info('Saving template: ${_currentTemplate.id}');
    await repository.saveTemplate(_currentTemplate);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _updateLayer(String id, LayerModel Function(LayerModel) updater) {
    final index = _currentTemplate.layers.indexWhere((l) => l.id == id);
    if (index == -1) return;

    final updated = updater(_currentTemplate.layers[index]);
    final newLayers = List<LayerModel>.from(_currentTemplate.layers);
    newLayers[index] = updated;

    _currentTemplate = _currentTemplate.copyWith(layers: newLayers);
    if (_selectedLayer?.id == id) _selectedLayer = updated;
    notifyListeners();
  }

  void _syncSelectedLayer(String id) {
    if (_selectedLayer?.id == id) {
      _selectedLayer = _currentTemplate.layers.firstWhere(
        (l) => l.id == id,
        orElse: () => _selectedLayer!,
      );
    }
  }
}
