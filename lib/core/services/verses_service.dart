import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../logger/app_logger.dart';
import '../../data/models/verse_data_model.dart';

/// Fetches Telugu + English verse data from the Holy Word API.
///
/// API: https://holyword.vercel.app/api/verses
///
/// All 780 verses are fetched once and cached in memory. Each day in a batch
/// is assigned a verse by cycling through the list: day 1 → verse 1,
/// day 2 → verse 2, etc. If the network call fails, falls back to a small
/// built-in seed set so batch generation never blocks.
class VersesService {
  VersesService._();
  static final VersesService instance = VersesService._();

  static const String _apiUrl = 'https://holyword.vercel.app/api/verses';

  static const String _usedVersesKey = 'used_verses_ids';

  // In-memory cache so we only hit the network once per app session.
  List<VerseDataModel>? _cachedVerses;

  /// Clears the in-memory cache (call before each batch if fresh data needed).
  void invalidateCache() => _cachedVerses = null;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns all verses (fetched from API or cache).
  Future<List<VerseDataModel>> getAllVerses() async {
    if (_cachedVerses != null) return _cachedVerses!;

    final response = await http
        .get(Uri.parse(_apiUrl))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Holy Word API Error: HTTP ${response.statusCode}\nFailed to fetch verses.',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (json['verses'] as List<dynamic>)
        .map((e) => VerseDataModel.fromJson(e as Map<String, dynamic>))
        .toList();

    _cachedVerses = list;
    AppLogger.info('VersesService: loaded ${list.length} verses from API');
    return list;
  }

  /// Returns a strictly unused random verse from the Holy Word API pool.
  /// If all verses have been used, the memory is cleared and it starts over.
  Future<VerseDataModel> _getNextUnusedVerse(int day) async {
    final verses = await getAllVerses();
    final prefs = await SharedPreferences.getInstance();

    List<String> usedIds = prefs.getStringList(_usedVersesKey) ?? [];

    // Filter available verses
    List<VerseDataModel> available = verses
        .where((v) => !usedIds.contains(v.id.toString()))
        .toList();

    if (available.isEmpty) {
      // All verses used, reset
      usedIds.clear();
      await prefs.remove(_usedVersesKey);
      available = List.from(verses);
      AppLogger.info('VersesService: All verses used, resetting used history.');
    }

    // Pick random from available
    final idx = Random().nextInt(available.length);
    final verse = available[idx];

    // Mark as used
    usedIds.add(verse.id.toString());
    await prefs.setStringList(_usedVersesKey, usedIds);

    return VerseDataModel(
      id: day,
      english: verse.english,
      englishReference: verse.englishReference,
      telugu: verse.telugu,
      teluguReference: verse.teluguReference,
      backgroundImage: verse.backgroundImage,
    );
  }

  /// Returns the next unused verse from the API.
  Future<VerseDataModel> getVerseForDay(int day) async {
    return _getNextUnusedVerse(day);
  }

  /// Returns a randomly selected unused verse for on-demand regeneration.
  Future<VerseDataModel> getRandomVerse(int day) async {
    return _getNextUnusedVerse(day);
  }
}
