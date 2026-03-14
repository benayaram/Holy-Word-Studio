import 'dart:convert';
import 'layer_model.dart';

/// Represents a complete editable template, compatible with the JESUS Template
/// 2.json schema (name, backgroundImage, width, height, placeholders, fonts).
class TemplateModel {
  final String id;
  final String name;

  /// Base64 data URI (e.g., "data:image/jpeg;base64,...") or local file path.
  final String? backgroundImage;
  final String? backgroundFit; // 'cover' | 'contain'

  /// Canvas dimensions as defined in the template JSON.
  final double canvasWidth;
  final double canvasHeight;

  /// Thumbnail path for the gallery (generated on save; not part of JSON export).
  final String? thumbnailPath;

  /// All placeholder layers, sorted by [LayerModel.layer] order when rendered.
  final List<LayerModel> layers;

  /// Custom font declarations from the template JSON: [{name, path}].
  /// Path here is the local asset path (blob URLs are ignored/discarded).
  final List<Map<String, String>> fonts;

  final DateTime createdAt;

  const TemplateModel({
    required this.id,
    required this.name,
    this.backgroundImage,
    this.backgroundFit,
    this.canvasWidth = 1080.0,
    this.canvasHeight = 1080.0,
    this.thumbnailPath,
    this.layers = const [],
    this.fonts = const [],
    required this.createdAt,
  });

  TemplateModel copyWith({
    String? id,
    String? name,
    String? backgroundImage,
    String? backgroundFit,
    double? canvasWidth,
    double? canvasHeight,
    String? thumbnailPath,
    List<LayerModel>? layers,
    List<Map<String, String>>? fonts,
    DateTime? createdAt,
  }) {
    return TemplateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      backgroundFit: backgroundFit ?? this.backgroundFit,
      canvasWidth: canvasWidth ?? this.canvasWidth,
      canvasHeight: canvasHeight ?? this.canvasHeight,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      layers: layers ?? this.layers,
      fonts: fonts ?? this.fonts,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialization — internal app storage format (includes id, createdAt, etc.)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'backgroundImage': backgroundImage,
      'backgroundFit': backgroundFit,
      'canvasWidth': canvasWidth,
      'canvasHeight': canvasHeight,
      'thumbnailPath': thumbnailPath,
      'layers': layers.map((l) => l.toJson()).toList(),
      'fonts': fonts,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TemplateModel.fromMap(Map<String, dynamic> map) {
    return TemplateModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Untitled',
      backgroundImage: map['backgroundImage'] as String?,
      backgroundFit: map['backgroundFit'] as String?,
      canvasWidth: (map['canvasWidth'] as num?)?.toDouble() ?? 1080.0,
      canvasHeight: (map['canvasHeight'] as num?)?.toDouble() ?? 1080.0,
      thumbnailPath: map['thumbnailPath'] as String?,
      layers:
          (map['layers'] as List<dynamic>?)
              ?.map((l) => LayerModel.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
      fonts:
          (map['fonts'] as List<dynamic>?)
              ?.map((f) => Map<String, String>.from(f as Map))
              .toList() ??
          [],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // JESUS Template 2.json import
  // ---------------------------------------------------------------------------

  /// Parses the JESUS Template 2.json schema into a [TemplateModel].
  ///
  /// The [id] is freshly generated; [createdAt] is set to now.
  /// Font blob URLs are discarded — local asset paths should be resolved
  /// separately via [FontService].
  static TemplateModel fromJesusJson(
    String jsonString, {
    required String newId,
  }) {
    final Map<String, dynamic> json =
        jsonDecode(jsonString) as Map<String, dynamic>;

    final placeholders =
        (json['placeholders'] as List<dynamic>? ?? [])
            .map((p) => LayerModel.fromJson(p as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.layer.compareTo(b.layer));

    // Strip dead blob URLs; keep only the font name so FontService can resolve
    // the local asset by matching family name.
    final fonts = (json['fonts'] as List<dynamic>? ?? [])
        .map((f) {
          final fm = f as Map<String, dynamic>;
          return <String, String>{'name': fm['name'] as String? ?? ''};
        })
        .where((f) => f['name']!.isNotEmpty)
        .toList();

    return TemplateModel(
      id: newId,
      name: json['name'] as String? ?? 'Imported Template',
      backgroundImage: json['backgroundImage'] as String?,
      backgroundFit: 'cover',
      canvasWidth: (json['width'] as num?)?.toDouble() ?? 1080.0,
      canvasHeight: (json['height'] as num?)?.toDouble() ?? 1080.0,
      layers: placeholders,
      fonts: fonts,
      createdAt: DateTime.now(),
    );
  }
}
