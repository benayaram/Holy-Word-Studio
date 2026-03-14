import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../logger/app_logger.dart';

/// Encapsulates the full AI Horde async image-generation flow.
///
/// Uses the free anonymous key (`0000000000`). Each call:
///   1. POSTs a generation request to AI Horde.
///   2. Polls the status endpoint every [_pollInterval] until `done == true`
///      or [_timeout] is exceeded.
///   3. Downloads the resulting image bytes and writes them to [savePath].
///
/// On a faulted job or timeout, the service retries once automatically before
/// returning `false` so the caller can gracefully skip that verse image.
///
/// The optional [onStatus] callback receives human-readable queue messages
/// so the caller can surface live progress (e.g. "Waiting ~45s").
class AiHordeService {
  AiHordeService._();
  static final AiHordeService instance = AiHordeService._();

  static const String _baseUrl = 'https://stablehorde.net/api/v2';

  /// Anonymous free-tier API key (10 zeros). No signup required.
  static const String _apiKey = '0000000000';

  /// Seconds between status polls — short enough for responsiveness,
  /// long enough to avoid hammering the server.
  static const Duration _pollInterval = Duration(seconds: 6);

  /// Per-attempt wall-clock budget. On timeout we retry once before skipping.
  /// 8 minutes covers the vast majority of real queue wait times.
  static const Duration _timeout = Duration(minutes: 8);

  /// AI Horde caps anonymous image size. We clamp to 512 px on both axes so
  /// the smallest/fastest worker pool can pick up the job immediately.
  static const int _maxDimension = 512;

  /// Low step-count (8) drastically reduces queue time for anonymous users
  /// while still producing a recognisable background image.
  static const int _steps = 8;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generates one image via AI Horde and saves it to [savePath].
  ///
  /// Returns `true` on success, `false` after all retries are exhausted
  /// (so the batch loop can skip this day gracefully without crashing).
  ///
  /// [onStatus] — optional callback receiving a UI-friendly status string
  /// while polling (e.g. "AI Horde – queue position 5 (~30s remaining)").
  Future<bool> generateAndSaveImage(
    String prompt, {
    required String savePath,
    int width = 512,
    int height = 512,
    void Function(String status)? onStatus,
  }) async {
    // Clamp both axes to _maxDimension and then snap to 64-multiple.
    final w = _snapTo64(width.clamp(64, _maxDimension));
    final h = _snapTo64(height.clamp(64, _maxDimension));

    // Attempt twice: first try, then one automatic retry on fault/timeout.
    for (int attempt = 1; attempt <= 2; attempt++) {
      final tryLabel = attempt == 1 ? '' : ' (retry)';
      AppLogger.info(
        'AiHordeService$tryLabel: Submitting "$prompt" (${w}x$h, $_steps steps)',
      );
      onStatus?.call(
        attempt == 1
            ? 'Submitting to AI Horde…'
            : 'Retrying AI Horde submission…',
      );

      final ok = await _attemptGeneration(
        prompt: prompt,
        savePath: savePath,
        w: w,
        h: h,
        onStatus: onStatus,
      );

      if (ok) return true;

      if (attempt < 2) {
        // Brief pause before retry so we don't immediately re-queue
        await Future.delayed(const Duration(seconds: 3));
      }
    }

    AppLogger.warn('AiHordeService: All attempts exhausted for "$prompt"');
    onStatus?.call('AI Horde: skipping verse image after retry');
    return false;
  }

  // ---------------------------------------------------------------------------
  // Internal — single generation attempt
  // ---------------------------------------------------------------------------

  Future<bool> _attemptGeneration({
    required String prompt,
    required String savePath,
    required int w,
    required int h,
    void Function(String)? onStatus,
  }) async {
    // ── Step 1: Submit ──────────────────────────────────────────────────────
    final String jobId;
    try {
      final submitResponse = await http
          .post(
            Uri.parse('$_baseUrl/generate/async'),
            headers: {'apikey': _apiKey, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'prompt': prompt,
              'params': {
                'n': 1,
                'width': w,
                'height': h,
                // Low step count = much shorter queue wait for anonymous users
                'steps': _steps,
                // Euler A is fast and works well at low step counts
                'sampler_name': 'k_euler_a',
              },
              // Prefer workers that have handled recent jobs (faster pickup)
              'slow_workers': false,
              // Return image inline as base64 — avoids R2 URL auth issues
              // that cause blank/white images for anonymous users.
              'r2': false,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (submitResponse.statusCode != 202) {
        AppLogger.warn(
          'AiHordeService: Submit failed HTTP ${submitResponse.statusCode}: '
          '${submitResponse.body}',
        );
        onStatus?.call('AI Horde submit failed');
        return false;
      }

      jobId =
          (jsonDecode(submitResponse.body) as Map<String, dynamic>)['id']
              as String;
      AppLogger.info('AiHordeService: Job accepted, id=$jobId');
    } catch (e) {
      AppLogger.error('AiHordeService: Submit exception', e);
      onStatus?.call('AI Horde unreachable');
      return false;
    }

    // ── Step 2: Poll ────────────────────────────────────────────────────────
    final deadline = DateTime.now().add(_timeout);
    final statusUrl = Uri.parse('$_baseUrl/generate/status/$jobId');

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(_pollInterval);

      try {
        final statusResponse = await http
            .get(statusUrl)
            .timeout(const Duration(seconds: 15));

        if (statusResponse.statusCode != 200) {
          AppLogger.warn(
            'AiHordeService: Poll HTTP ${statusResponse.statusCode} — will retry',
          );
          continue;
        }

        final data = jsonDecode(statusResponse.body) as Map<String, dynamic>;

        if (data['faulted'] == true) {
          // Worker dropped the job — outer loop will retry
          AppLogger.warn('AiHordeService: Job faulted, id=$jobId');
          onStatus?.call('Worker faulted — will retry…');
          return false;
        }

        if (data['done'] == true) {
          return await _downloadAndSave(data, savePath, onStatus);
        }

        // Still queued — surface live wait info
        final waitTime = data['wait_time'] as int? ?? 0;
        final queuePos = data['queue_position'] as int? ?? 0;
        final msg = queuePos > 0
            ? 'AI Horde – queue position $queuePos (~${waitTime}s remaining)'
            : 'AI Horde – generating… (~${waitTime}s remaining)';
        AppLogger.debug('AiHordeService: $msg');
        onStatus?.call(msg);
      } catch (e) {
        // Network hiccup — not fatal, keep polling
        AppLogger.warn('AiHordeService: Poll error — $e');
      }
    }

    AppLogger.warn('AiHordeService: Timed out for jobId=$jobId');
    onStatus?.call('AI Horde timed out');
    return false;
  }

  // ── Step 3: Decode & persist ──────────────────────────────────────────────

  Future<bool> _downloadAndSave(
    Map<String, dynamic> data,
    String savePath,
    void Function(String)? onStatus,
  ) async {
    final generations = data['generations'] as List<dynamic>?;
    if (generations == null || generations.isEmpty) {
      AppLogger.warn('AiHordeService: Done but generations list is empty');
      return false;
    }

    final imgField =
        (generations.first as Map<String, dynamic>)['img'] as String?;
    if (imgField == null || imgField.isEmpty) {
      AppLogger.warn('AiHordeService: No img field in generation response');
      return false;
    }

    try {
      List<int> bytes;

      if (imgField.startsWith('http://') || imgField.startsWith('https://')) {
        // Hosted URL — download normally
        AppLogger.info('AiHordeService: Downloading from URL $imgField');
        onStatus?.call('Downloading generated verse image…');
        final imgResponse = await http
            .get(Uri.parse(imgField))
            .timeout(const Duration(minutes: 2));
        if (imgResponse.statusCode != 200) {
          AppLogger.warn(
            'AiHordeService: Download failed HTTP ${imgResponse.statusCode}',
          );
          return false;
        }
        bytes = imgResponse.bodyBytes;
      } else {
        // Inline base64 — anonymous users always get this format.
        // The field may optionally be prefixed with a data-URI header
        // ("data:image/webp;base64,...") — strip it if present.
        AppLogger.info('AiHordeService: Decoding inline base64 image');
        onStatus?.call('Decoding verse image…');
        final b64 = imgField.contains(',') ? imgField.split(',').last : imgField;
        bytes = base64Decode(b64);
      }

      await File(savePath).writeAsBytes(bytes);
      AppLogger.info('AiHordeService: Saved → $savePath');
      return true;
    } catch (e) {
      AppLogger.error('AiHordeService: Image save exception', e);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Snaps [value] to the nearest multiple of 64 (AI Horde requirement).
  int _snapTo64(int value) {
    final snapped = (value / 64).round() * 64;
    return snapped.clamp(64, 1024);
  }
}
