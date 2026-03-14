import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/template_model.dart';
import '../../core/logger/app_logger.dart';

class TemplateRepository {
  static const String _localKey = 'saved_templates';

  // In-memory cache for speed
  List<TemplateModel>? _cache;
  Stream<List<TemplateModel>>? _streamCache;

  Stream<List<TemplateModel>> get templatesStream {
    _streamCache ??= FirebaseFirestore.instance
        .collection('templates')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          try {
            final templates = snapshot.docs.map((doc) {
              final data = doc.data();
              if (data['id'] == null) data['id'] = doc.id;
              return TemplateModel.fromMap(data);
            }).toList();
            _cache = templates;
            return templates;
          } catch (e) {
            AppLogger.error('Error mapping templates from Firestore', e);
            return _cache ?? [];
          }
        })
        .asBroadcastStream();
    return _streamCache!;
  }

  Future<void> saveTemplate(TemplateModel template) async {
    // 1. Save Locally
    try {
      final prefs = await SharedPreferences.getInstance();
      final templatesJson = prefs.getStringList(_localKey) ?? [];

      // Remove older version if it exists
      templatesJson.removeWhere((jsonStr) {
        final Map<String, dynamic> map = jsonDecode(jsonStr);
        return map['id'] == template.id;
      });

      templatesJson.add(jsonEncode(template.toMap()));
      await prefs.setStringList(_localKey, templatesJson);

      // Update cache
      if (_cache != null) {
        final index = _cache!.indexWhere((t) => t.id == template.id);
        if (index != -1) {
          _cache![index] = template;
        } else {
          _cache!.add(template);
        }
      }

      AppLogger.info('Template saved locally: ${template.id}');
    } catch (e) {
      AppLogger.error('Failed to save template locally', e);
    }

    // 2. Save to Firestore (Offline-first approach handles cache)
    try {
      await FirebaseFirestore.instance
          .collection('templates')
          .doc(template.id)
          .set(template.toMap(), SetOptions(merge: true));
      AppLogger.info('Template synced to Firestore: ${template.id}');
    } catch (e) {
      AppLogger.error(
        'Firestore sync failed or not configured. Ignoring for now.',
        e,
      );
    }
  }

  Future<List<TemplateModel>> getSavedTemplates() async {
    try {
      if (_cache != null) return _cache!;

      final prefs = await SharedPreferences.getInstance();
      final templatesJson = prefs.getStringList(_localKey) ?? [];

      _cache = templatesJson.map((jsonStr) {
        return TemplateModel.fromMap(jsonDecode(jsonStr));
      }).toList();

      return _cache!;
    } catch (e) {
      AppLogger.error('Failed to load local templates', e);
      return [];
    }
  }

  /// Clears the in-memory cache so the next [getSavedTemplates] call reads
  /// fresh data from SharedPreferences.
  void invalidateCache() {
    _cache = null;
  }
}
