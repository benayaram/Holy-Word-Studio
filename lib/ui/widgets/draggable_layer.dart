import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:auto_size_text/auto_size_text.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/font_service.dart';
import '../../../data/models/layer_model.dart';
import '../../../logic/providers/template_editor_provider.dart';

/// Renders and handles interaction (drag + pinch-scale) for a single template
/// layer. Supports the full JESUS Template 2.json style spec — text shadows,
/// stroke, alignment, auto-scale, image borders, and base64 image sources.
///
/// [canvasScale] maps template-space coordinates (1080px) to the current
/// rendered canvas pixel size so layers always appear in the correct position
/// relative to the background image.
class DraggableLayer extends StatelessWidget {
  final LayerModel layer;

  /// Scale factor = renderedCanvasWidth / templateCanvasWidth.
  /// Passed from [_CanvasArea] via [LayoutBuilder].
  final double canvasScale;

  const DraggableLayer({
    super.key,
    required this.layer,
    this.canvasScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TemplateEditorProvider>();
    final isSelected = context.select<TemplateEditorProvider, bool>(
      (p) => p.selectedLayer?.id == layer.id,
    );
    final isCapturing = context.select<TemplateEditorProvider, bool>(
      (p) => p.isCapturing,
    );

    if (!layer.visible) return const SizedBox.shrink();

    // All coordinates and sizes in the provider/model are in template-space
    // (e.g. 1080×1080). Multiply by canvasScale to get screen pixels.
    final s = canvasScale;

    final child = layer.type == LayerType.text
        ? _TextLayerContent(layer: layer, canvasScale: s)
        : _ImageLayerContent(layer: layer, canvasScale: s);

    return Positioned(
      left: (layer.x + layer.dx) * s,
      top: (layer.y + layer.dy) * s,
      child: GestureDetector(
        onTap: () => provider.selectLayer(layer.id),
        onScaleStart: (_) => provider.selectLayer(layer.id),
        onScaleUpdate: (details) {
          if (details.scale == 1.0) {
            // Divide screen-space delta by scale to keep model in template
            // space so nudge arrows and sliders remain consistent.
            provider.updateLayerPosition(
              layer.id,
              details.focalPointDelta.dx / s,
              details.focalPointDelta.dy / s,
            );
          } else {
            provider.updateLayerScale(layer.id, layer.scale * details.scale);
          }
        },
        child: Transform.scale(
          scale: layer.scale,
          alignment: Alignment.topLeft,
          // Container border keeps the selection indicator INSIDE the layer
          // bounds — no overflow into adjacent layers or canvas edges.
          child: Container(
            decoration: isSelected
                ? BoxDecoration(
                    border: Border.all(color: AppColors.primary, width: 2),
                  )
                : (!isCapturing
                      ? BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.4),
                            width: 1,
                            style: BorderStyle.solid,
                          ),
                        )
                      : null),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text layer
// ---------------------------------------------------------------------------

class _TextLayerContent extends StatelessWidget {
  final LayerModel layer;
  final double canvasScale;

  const _TextLayerContent({required this.layer, this.canvasScale = 1.0});

  @override
  Widget build(BuildContext context) {
    final resolved = FontService.instance.resolveFamily(layer.fontFamily);
    // Scale font size from template-space to screen-space. AutoSizeText only scales DOWN,
    // so if autoScale is enabled, start from a massive size.
    final double baseFontSize = layer.autoScale
        ? 2000.0
        : (layer.fontSize ?? 24).toDouble();
    final fontSize = baseFontSize * canvasScale;
    final align = _parseTextAlign(layer.textAlign);
    final vertAlign = layer.verticalAlign ?? 'middle';

    // Try loading as a bundled/system font first; fall back to google_fonts.
    TextStyle style;
    try {
      style = GoogleFonts.getFont(
        resolved,
        textStyle: TextStyle(
          fontSize: fontSize,
          color: layer.color ?? Colors.black,
          shadows: _buildShadows(),
          fontFamily: resolved,
        ),
      );
    } catch (_) {
      style = TextStyle(
        fontFamily: resolved,
        fontSize: fontSize,
        color: layer.color ?? Colors.black,
        shadows: _buildShadows(),
      );
    }

    // Stroke requires a CustomPainter approach; build a stack with outlined text.
    // softWrap + overflow ensure text wraps within the bounding box like Canva.
    Widget textWidget = AutoSizeText(
      layer.text ?? '',
      textAlign: align,
      softWrap: true,
      overflow: TextOverflow.clip,
      style: style,
      minFontSize: layer.autoScale ? 8 : fontSize.truncateToDouble(),
      maxFontSize: layer.autoScale ? 2000 : fontSize.truncateToDouble(),
      wrapWords: true, // Enable dynamic wrapping
    );

    // Apply text stroke via a foreground-behind trick: render outline first.
    if ((layer.strokeWidth ?? 0) > 0) {
      textWidget = Stack(
        children: [
          AutoSizeText(
            layer.text ?? '',
            textAlign: align,
            style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = (layer.strokeWidth ?? 0) * 2
                ..color = layer.strokeColor ?? Colors.black,
            ),
            minFontSize: layer.autoScale ? 8 : fontSize.truncateToDouble(),
            maxFontSize: layer.autoScale ? 2000 : fontSize.truncateToDouble(),
            wrapWords: true, // Enable dynamic wrapping
          ),
          AutoSizeText(
            layer.text ?? '',
            textAlign: align,
            style: style,
            minFontSize: layer.autoScale ? 8 : fontSize.truncateToDouble(),
            maxFontSize: layer.autoScale ? 2000 : fontSize.truncateToDouble(),
            wrapWords: true, // Enable dynamic wrapping
          ),
        ],
      );
    }
    return SizedBox(
      width: layer.width * canvasScale,
      height: layer.height * canvasScale,
      child: Align(
        alignment: _getAlignment(align, vertAlign),
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

  List<Shadow>? _buildShadows() {
    final blur = (layer.shadowBlur ?? 0) * canvasScale;
    final ox = (layer.shadowOffsetX ?? 0) * canvasScale;
    final oy = (layer.shadowOffsetY ?? 0) * canvasScale;
    final color = layer.shadowColor;
    if (color == null || (blur == 0 && ox == 0 && oy == 0)) return null;
    return [Shadow(color: color, blurRadius: blur, offset: Offset(ox, oy))];
  }

  static TextAlign _parseTextAlign(String? align) {
    switch (align) {
      case 'right':
        return TextAlign.right;
      case 'left':
        return TextAlign.left;
      default:
        return TextAlign.center;
    }
  }
}

// ---------------------------------------------------------------------------
// Image layer
// ---------------------------------------------------------------------------

class _ImageLayerContent extends StatelessWidget {
  final LayerModel layer;
  final double canvasScale;

  const _ImageLayerContent({required this.layer, this.canvasScale = 1.0});

  @override
  Widget build(BuildContext context) {
    final path = layer.imagePath;
    final s = canvasScale;

    final fit = _parseImageFit(layer.imageFit);

    Widget imageWidget;
    if (path == null || path.isEmpty) {
      imageWidget = Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.image, color: Colors.grey, size: 40),
        ),
      );
    } else if (path.startsWith('data:')) {
      try {
        final commaIdx = path.indexOf(',');
        final bytes = base64Decode(path.substring(commaIdx + 1));
        imageWidget = Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (_, __, ___) => _errorPlaceholder(),
        );
      } catch (e) {
        imageWidget = _errorPlaceholder();
      }
    } else if (path.startsWith('http')) {
      imageWidget = Image.network(
        path,
        fit: fit,
        errorBuilder: (_, __, ___) => _errorPlaceholder(),
      );
    } else {
      // Safe guard against massive raw base64 strings accidentally hitting Image.file
      if (path.length > 1000 && !path.contains('/')) {
        try {
          final bytes = base64Decode(path);
          imageWidget = Image.memory(
            bytes,
            fit: fit,
            errorBuilder: (_, __, ___) => _errorPlaceholder(),
          );
        } catch (e) {
          imageWidget = _errorPlaceholder();
        }
      } else {
        imageWidget = Image.file(
          File(path),
          fit: fit,
          errorBuilder: (_, __, ___) => _errorPlaceholder(),
        );
      }
    }

    // Scale all border values alongside the layer dimensions.
    final radius = (layer.borderRadius ?? 0) * s;
    final borderWidth = (layer.borderWidth ?? 0) * s;
    final borderColor = layer.borderColor;
    final bg = layer.backgroundColor;

    return Container(
      width: layer.width * s,
      height: layer.height * s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: borderWidth > 0 && borderColor != null
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
        color: bg,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageWidget,
    );
  }

  Widget _errorPlaceholder() => Container(
    color: Colors.grey.shade300,
    child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
  );

  static BoxFit _parseImageFit(String? fit) {
    switch (fit) {
      case 'contain':
        return BoxFit.contain;
      case 'fill':
        return BoxFit.fill;
      case 'cover':
      default:
        return BoxFit.cover;
    }
  }
}
