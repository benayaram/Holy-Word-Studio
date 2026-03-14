import 'dart:ui';

enum LayerType { text, image }

enum TextType {
  englishVerse,
  teluguVerse,
  englishReference,
  teluguReference,
  ministryName,
  speakerName,
  socialMediaHandle,
  contactNumber,
  custom,
}

/// Semantic role an image placeholder plays in a template.
enum ImageType { speakerImage, verseImage, custom }

/// Full representation of one placeholder/layer inside a template.
///
/// Fields are kept immutable; use [copyWith] for updates.
/// [fromJson] / [toJson] are compatible with the JESUS Template 2.json schema.
class LayerModel {
  final String id;
  final LayerType type;

  /// Semantic name from the template JSON (e.g., "verse_te", "logo").
  final String? name;

  /// Absolute anchored position on the canvas.
  final double x;
  final double y;

  /// Bounding box for the placeholder in canvas coordinates.
  final double width;
  final double height;

  /// Z-order; lower numbers render first (behind higher numbers).
  final int layer;

  final bool visible;

  // --- Drag-state fields (not persisted in the JESUS Template format) ---
  /// Accumulated drag delta X applied on top of [x].
  final double dx;

  /// Accumulated drag delta Y applied on top of [dy].
  final double dy;

  /// Scale factor applied during pinch-zoom gesture.
  final double scale;

  // --- Text-specific style fields ---
  final String? text;
  final TextType? textType;
  final double? fontSize;
  final String? fontFamily;
  final Color? color;
  final String? textAlign; // 'left' | 'center' | 'right'
  final String? verticalAlign; // 'top' | 'middle' | 'bottom'
  final bool autoScale;

  final Color? shadowColor;
  final double? shadowBlur;
  final double? shadowOffsetX;
  final double? shadowOffsetY;
  final double? strokeWidth;
  final Color? strokeColor;

  // --- Image-specific style fields ---
  final String? imagePath; // file path or base64 data URI
  final ImageType? imageType;
  final String? imageFit; // 'cover' | 'contain' | 'fill'

  /// Corner radius for image display.
  final double? borderRadius;
  final Color? borderColor;
  final double? borderWidth;
  final String? borderStyle;
  final Color? backgroundColor;

  const LayerModel({
    required this.id,
    required this.type,
    this.name,
    this.x = 0.0,
    this.y = 0.0,
    this.width = 200.0,
    this.height = 60.0,
    this.layer = 1,
    this.visible = true,
    this.dx = 0.0,
    this.dy = 0.0,
    this.scale = 1.0,
    this.text,
    this.textType,
    this.fontSize,
    this.fontFamily,
    this.color,
    this.textAlign,
    this.verticalAlign,
    this.autoScale = false,
    this.shadowColor,
    this.shadowBlur,
    this.shadowOffsetX,
    this.shadowOffsetY,
    this.strokeWidth,
    this.strokeColor,
    this.imagePath,
    this.imageType,
    this.imageFit,
    this.borderRadius,
    this.borderColor,
    this.borderWidth,
    this.borderStyle,
    this.backgroundColor,
  });

  LayerModel copyWith({
    String? id,
    LayerType? type,
    String? name,
    double? x,
    double? y,
    double? width,
    double? height,
    int? layer,
    bool? visible,
    double? dx,
    double? dy,
    double? scale,
    String? text,
    TextType? textType,
    double? fontSize,
    String? fontFamily,
    Color? color,
    String? textAlign,
    String? verticalAlign,
    bool? autoScale,
    Color? shadowColor,
    double? shadowBlur,
    double? shadowOffsetX,
    double? shadowOffsetY,
    double? strokeWidth,
    Color? strokeColor,
    String? imagePath,
    ImageType? imageType,
    String? imageFit,
    double? borderRadius,
    Color? borderColor,
    double? borderWidth,
    String? borderStyle,
    Color? backgroundColor,
  }) {
    return LayerModel(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      layer: layer ?? this.layer,
      visible: visible ?? this.visible,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      scale: scale ?? this.scale,
      text: text ?? this.text,
      textType: textType ?? this.textType,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      color: color ?? this.color,
      textAlign: textAlign ?? this.textAlign,
      verticalAlign: verticalAlign ?? this.verticalAlign,
      autoScale: autoScale ?? this.autoScale,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      shadowOffsetX: shadowOffsetX ?? this.shadowOffsetX,
      shadowOffsetY: shadowOffsetY ?? this.shadowOffsetY,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      strokeColor: strokeColor ?? this.strokeColor,
      imagePath: imagePath ?? this.imagePath,
      imageType: imageType ?? this.imageType,
      imageFit: imageFit ?? this.imageFit,
      borderRadius: borderRadius ?? this.borderRadius,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderStyle: borderStyle ?? this.borderStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  /// Serializes to a map compatible with the JESUS Template 2.json
  /// "placeholders" item schema.
  Map<String, dynamic> toJson() {
    final styles = <String, dynamic>{};

    if (type == LayerType.text) {
      if (fontSize != null) styles['fontSize'] = fontSize;
      if (fontFamily != null) styles['fontFamily'] = fontFamily;
      if (color != null) styles['color'] = _colorToHex(color!);
      if (textAlign != null) styles['textAlign'] = textAlign;
      if (shadowColor != null) {
        styles['shadowColor'] = _colorToHex(shadowColor!);
      }
      if (shadowBlur != null) styles['shadowBlur'] = shadowBlur;
      if (shadowOffsetX != null) styles['shadowOffsetX'] = shadowOffsetX;
      if (shadowOffsetY != null) styles['shadowOffsetY'] = shadowOffsetY;
      if (strokeWidth != null) styles['strokeWidth'] = strokeWidth;
      if (strokeColor != null) {
        styles['strokeColor'] = _colorToHex(strokeColor!);
      }
      styles['autoScale'] = autoScale;
      if (verticalAlign != null) styles['verticalAlign'] = verticalAlign;
    } else {
      if (borderRadius != null) styles['borderRadius'] = borderRadius;
      if (borderColor != null) {
        styles['borderColor'] = _colorToHex(borderColor!);
      }
      if (borderWidth != null) styles['borderWidth'] = borderWidth;
      if (borderStyle != null) styles['borderStyle'] = borderStyle;
      if (backgroundColor != null) {
        styles['backgroundColor'] = _colorToHex(backgroundColor!);
      }
      if (imageFit != null) styles['imageFit'] = imageFit;
    }

    return {
      'id': id,
      'type': type.name,
      'name': name,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'layer': layer,
      'visible': visible,
      // Preserve drag state so reloaded templates restore user adjustments
      'dx': dx,
      'dy': dy,
      'scale': scale,
      'text': text,
      'textType': textType?.name,
      'imagePath': imagePath,
      'imageType': imageType?.name,
      'styles': styles,
    };
  }

  /// Parses one item from the "placeholders" array in a JESUS Template JSON.
  factory LayerModel.fromJson(Map<String, dynamic> json) {
    final stylesRaw = json['styles'] as Map<String, dynamic>? ?? {};
    final typeStr = (json['type'] as String?)?.toLowerCase() ?? 'text';
    final type = typeStr == 'image' ? LayerType.image : LayerType.text;

    final String? colorHex = stylesRaw['color'] as String?;
    final String? shadowColorHex = stylesRaw['shadowColor'] as String?;
    final String? strokeColorHex = stylesRaw['strokeColor'] as String?;
    final String? borderColorHex = stylesRaw['borderColor'] as String?;
    final String? bgColorHex = stylesRaw['backgroundColor'] as String?;

    final TextType? textType = _nameToTextType(json['name'] as String?);
    final ImageType? imageType = _nameToImageType(json['name'] as String?);

    return LayerModel(
      id: json['id'] as String? ?? '',
      type: type,
      name: json['name'] as String?,
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble() ?? 200.0,
      height: (json['height'] as num?)?.toDouble() ?? 60.0,
      layer: (json['layer'] as num?)?.toInt() ?? 1,
      visible: (json['visible'] as bool?) ?? true,
      dx: (json['dx'] as num?)?.toDouble() ?? 0.0,
      dy: (json['dy'] as num?)?.toDouble() ?? 0.0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      text: (json['text'] as String?)?.isNotEmpty == true
          ? json['text'] as String
          : (type == LayerType.text
                ? (json['name'] as String? ?? 'Text Layer')
                : null),
      textType: json['textType'] != null
          ? TextType.values.byName(json['textType'] as String)
          : textType,
      imagePath: json['imagePath'] as String?,
      // Text styles
      fontSize: (stylesRaw['fontSize'] as num?)?.toDouble(),
      fontFamily: stylesRaw['fontFamily'] as String?,
      color: colorHex != null ? _hexToColor(colorHex) : null,
      textAlign: stylesRaw['textAlign'] as String?,
      verticalAlign: stylesRaw['verticalAlign'] as String?,
      autoScale: (stylesRaw['autoScale'] as bool?) ?? false,
      shadowColor: shadowColorHex != null ? _hexToColor(shadowColorHex) : null,
      shadowBlur: (stylesRaw['shadowBlur'] as num?)?.toDouble(),
      shadowOffsetX: (stylesRaw['shadowOffsetX'] as num?)?.toDouble(),
      shadowOffsetY: (stylesRaw['shadowOffsetY'] as num?)?.toDouble(),
      strokeWidth: (stylesRaw['strokeWidth'] as num?)?.toDouble(),
      strokeColor: strokeColorHex != null ? _hexToColor(strokeColorHex) : null,
      // Image styles
      imageType: json['imageType'] != null
          ? ImageType.values.byName(json['imageType'] as String)
          : imageType,
      imageFit: stylesRaw['imageFit'] as String?,
      borderRadius: (stylesRaw['borderRadius'] as num?)?.toDouble(),
      borderColor: borderColorHex != null ? _hexToColor(borderColorHex) : null,
      borderWidth: (stylesRaw['borderWidth'] as num?)?.toDouble(),
      borderStyle: stylesRaw['borderStyle'] as String?,
      backgroundColor: bgColorHex != null ? _hexToColor(bgColorHex) : null,
    );
  }

  // --- Helpers ---

  static Color _hexToColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 4) {
      // Short hex like #0000
      final r = int.parse(cleaned[1] + cleaned[1], radix: 16);
      final g = int.parse(cleaned[2] + cleaned[2], radix: 16);
      final b = int.parse(cleaned[3] + cleaned[3], radix: 16);
      final a = int.parse(cleaned[0] + cleaned[0], radix: 16);
      return Color.fromARGB(a, r, g, b);
    }
    final value =
        int.tryParse(cleaned.padLeft(8, 'f'), radix: 16) ?? 0xFFFFFFFF;
    if (cleaned.length <= 6) {
      // No alpha supplied — treat as fully opaque
      return Color(0xFF000000 | int.parse(cleaned.padLeft(6, '0'), radix: 16));
    }
    return Color(value);
  }

  static String _colorToHex(Color color) {
    final r = (color.r * 255.0).round();
    final g = (color.g * 255.0).round();
    final b = (color.b * 255.0).round();
    final a = (color.a * 255.0).round();
    if (a == 255) return '#${_hex(r)}${_hex(g)}${_hex(b)}';
    return '#${_hex(a)}${_hex(r)}${_hex(g)}${_hex(b)}';
  }

  static String _hex(int v) => v.toRadixString(16).padLeft(2, '0');

  /// Maps the semantic placeholder name from the JESUS Template schema to a
  /// [TextType] enum value so the editor knows what data belongs in this slot.
  static TextType? _nameToTextType(String? name) {
    switch (name) {
      case 'verse_en':
        return TextType.englishVerse;
      case 'verse_te':
        return TextType.teluguVerse;
      case 'verse_en_ref':
        return TextType.englishReference;
      case 'verse_te_ref':
        return TextType.teluguReference;
      case 'ministry_name':
        return TextType.ministryName;
      case 'speaker_name':
        return TextType.speakerName;
      case 'social_media_handle':
        return TextType.socialMediaHandle;
      case 'contact_number':
        return TextType.contactNumber;
      default:
        return null;
    }
  }

  /// Maps semantic placeholder name to an ImageType
  static ImageType? _nameToImageType(String? name) {
    if (name == null) return null;
    final lower = name.toLowerCase();
    if (lower.contains('speaker')) return ImageType.speakerImage;
    if (lower.contains('verse') && lower.contains('image')) {
      return ImageType.verseImage;
    }
    return null;
  }
}
