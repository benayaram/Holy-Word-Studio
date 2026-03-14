import 'package:flutter/services.dart';

import '../logger/app_logger.dart';

/// All font families bundled as Flutter assets (declared in pubspec.yaml).
const List<String> kBundledFonts = [
  'Aaradhana',
  'Abhilasha',
  'Ajantha',
  'Akshara',
  'Amrutha',
  'Anjali',
  'Annamayya',
  'Anupama',
  'Anusha',
  'Bapu Brush',
  'Bharghava',
  'Bhavya',
  'Brahma',
  'Brahma Script',
  'BV Satyamurty',
  'Chandra Script',
  'Chathura',
  'Deepika',
  'Dharani',
  'Dhurjati',
  'Gidugu',
  'Gurajada',
  'Hiranya',
  'JIMS',
  'Jyothi',
  'Kanakadurga',
  'Lakkireddy',
  'Mallanna',
  'Mandali',
  'Nandakam',
  'NATS',
  'NTR',
  'Peddana',
  'Potti Sreeramulu',
  'Purushothamaa',
  'Ramabhadra',
  'Ramaneeyawin',
  'Ravi Prakash',
  'Roboto',
  'Seelaveerraju',
  'SP Balasubrahmanyam',
  'Sree Krushnadevaraya',
  'Suranna',
  'Suravaram',
  'Syamala Ramana',
];

/// Google Fonts for English text as supplementary options.
const List<String> kGoogleFonts = [
  'Inter',
  'Lato',
  'Montserrat',
  'Oswald',
  'Lora',
  'Playfair Display',
  'Raleway',
  'Open Sans',
  'Philosopher',
  'Poppins',
  'Nunito',
  'Merriweather',
  'Ubuntu',
  'Roboto Mono',
  'Cinzel',
];

/// All font names shown in the font picker (bundled first, then Google Fonts).
List<String> get kAllAvailableFonts => [...kBundledFonts, ...kGoogleFonts];

/// Maps old Netlify/web-editor font names to the correct bundled font family.
///
/// Now that the actual font files are available, most aliases point to the
/// real font. Keys are lowercase-trimmed for case-insensitive matching.
const Map<String, String> kFontAliases = {
  // These are the exact names used in JESUS Template 2.json from the web editor.
  // Now we have the actual TTF files bundled.
  'timmana regular': 'Bharghava', // closest match still
  'potti sreeramulu regular': 'Potti Sreeramulu', // ✅ exact font now bundled
  'belgiano serif 2': 'Suranna', // serif match
  'philosopher-bold': 'Mandali', // closest bold match
  'philosopher-regular': 'NTR', // clean readable sans
  'philosopher': 'NTR',
  // Common shorthand names
  'potti sreeramulu': 'Potti Sreeramulu',
  'ntr': 'NTR',
  'suranna': 'Suranna',
  'mallanna': 'Mallanna',
  'mandali': 'Mandali',
  'gidugu': 'Gidugu',
  'gurajada': 'Gurajada',
  'ramabhadra': 'Ramabhadra',
  'chathura': 'Chathura',
  'dhurjati': 'Dhurjati',
  'annamayya': 'Annamayya',
};

/// Service that resolves and loads custom font families for template rendering.
class FontService {
  FontService._();

  static final FontService instance = FontService._();

  /// Resolves a raw font name from a template JSON to the Flutter font family
  /// string that can be used directly in a [TextStyle].
  ///
  /// Checks [kFontAliases] first (case-insensitive), then checks bundled fonts,
  /// then falls back to the raw name (Google Fonts will attempt resolution).
  String resolveFamily(String? rawName) {
    if (rawName == null || rawName.isEmpty) return 'Roboto';
    final normalized = rawName.trim().toLowerCase();

    if (kFontAliases.containsKey(normalized)) {
      return kFontAliases[normalized]!;
    }

    // Direct match against bundled fonts (case-insensitive)
    final bundled = kBundledFonts.firstWhere(
      (f) => f.toLowerCase() == normalized,
      orElse: () => '',
    );
    if (bundled.isNotEmpty) return bundled;

    // Fall through to google_fonts / system font
    return rawName;
  }

  /// Pre-loads a bundled font via [FontLoader] for programmatic use.
  ///
  /// Bundled fonts declared in pubspec.yaml are loaded automatically by the
  /// Flutter framework — call this only if you need to force-load a font that
  /// was not in the asset bundle at startup.
  Future<void> loadBundledFont(String family) async {
    try {
      final loader = FontLoader(family);
      final assetName = _assetNameForFamily(family);
      if (assetName == null) return;
      loader.addFont(rootBundle.load(assetName));
      await loader.load();
      AppLogger.info('FontService: loaded "$family"');
    } catch (e) {
      AppLogger.error('FontService: failed to load "$family"', e);
    }
  }

  /// Returns the primary asset path for a given bundled family name.
  String? _assetNameForFamily(String family) {
    const mapping = <String, String>{
      'Aaradhana': 'assets/fonts/Aaradhana.ttf',
      'Abhilasha': 'assets/fonts/Abhilasha.ttf',
      'Ajantha': 'assets/fonts/Ajantha.ttf',
      'Akshara': 'assets/fonts/Akshara.ttf',
      'Amrutha': 'assets/fonts/Amrutha.ttf',
      'Anjali': 'assets/fonts/Anjali.ttf',
      'Annamayya': 'assets/fonts/annamayya.otf',
      'Anupama': 'assets/fonts/Anupama-Medium.ttf',
      'Anusha': 'assets/fonts/Anusha.ttf',
      'Bapu Brush': 'assets/fonts/Bapu-Brush.ttf',
      'Bharghava': 'assets/fonts/Bharghava.ttf',
      'Bhavya': 'assets/fonts/Bhavya.ttf',
      'Brahma': 'assets/fonts/Brahma.ttf',
      'Brahma Script': 'assets/fonts/Brahma-Script.ttf',
      'BV Satyamurty': 'assets/fonts/bvsatyamurty.ttf',
      'Chandra Script': 'assets/fonts/Chandra-Script.ttf',
      'Chathura': 'assets/fonts/chathura_regular.ttf',
      'Deepika': 'assets/fonts/Deepika.ttf',
      'Dharani': 'assets/fonts/Dharani.ttf',
      'Dhurjati': 'assets/fonts/dhurjati.otf',
      'Gidugu': 'assets/fonts/gidugu.otf',
      'Gurajada': 'assets/fonts/gurajada.otf',
      'Hiranya': 'assets/fonts/Hiranya.ttf',
      'JIMS': 'assets/fonts/jims.ttf',
      'Jyothi': 'assets/fonts/Jyothi.ttf',
      'Kanakadurga': 'assets/fonts/kanakadurga.otf',
      'Lakkireddy': 'assets/fonts/lakkireddy.ttf',
      'Mallanna': 'assets/fonts/mallanna.otf',
      'Mandali': 'assets/fonts/mandali_regular.ttf',
      'Nandakam': 'assets/fonts/nandakam.otf',
      'NATS': 'assets/fonts/nats.otf',
      'NTR': 'assets/fonts/ntr.otf',
      'Peddana': 'assets/fonts/peddana_regular.ttf',
      'Potti Sreeramulu': 'assets/fonts/potti_sreeramulu.ttf',
      'Purushothamaa': 'assets/fonts/purushothamaa.otf',
      'Ramabhadra': 'assets/fonts/ramabhadra_regular.ttf',
      'Ramaneeyawin': 'assets/fonts/ramaneeyawin.ttf',
      'Ravi Prakash': 'assets/fonts/raviprakash.ttf',
      'Roboto': 'assets/fonts/roboto_regular.ttf',
      'Seelaveerraju': 'assets/fonts/seelaveerraju.ttf',
      'SP Balasubrahmanyam': 'assets/fonts/spbalasubrahmanyam.ttf',
      'Sree Krushnadevaraya': 'assets/fonts/sree_krushnadevaraya.otf',
      'Suranna': 'assets/fonts/suranna_regular.otf',
      'Suravaram': 'assets/fonts/suravaram.otf',
      'Syamala Ramana': 'assets/fonts/syamala_ramana.otf',
    };
    return mapping[family];
  }
}
