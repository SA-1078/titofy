import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cliente HTTP para la API de Titofy en localhost:8642
class ApiService {
  static const String _baseUrl = 'http://127.0.0.1:8642';
  final http.Client _client = http.Client();

  // ── /health ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> health() async {
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  // ── /transcribe ───────────────────────────────────────────────────────────
  /// Envía un archivo de audio/video para transcribir.
  /// Retorna el task_id para hacer polling en /status/{id}
  Future<String?> transcribe({
    required String filePath,
    String model = 'small',
    String language = 'es',
    bool wordTimestamps = true,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/transcribe'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'file_path': filePath,
              'model': model,
              'language': language,
              'word_timestamps': wordTimestamps,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 || res.statusCode == 202) {
        final data = jsonDecode(res.body);
        return data['task_id'] as String?;
      }
    } catch (_) {}
    return null;
  }

  // ── /status/{id} ──────────────────────────────────────────────────────────
  /// Retorna el estado de una tarea: pending | processing | done | error
  Future<Map<String, dynamic>?> status(String taskId) async {
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/status/$taskId'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  // ── /align ────────────────────────────────────────────────────────────────
  Future<String?> align({
    required String audioPath,
    required String lyricsText,
    String language = 'es',
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/align'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'audio_path': audioPath,
              'lyrics_text': lyricsText,
              'language': language,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 || res.statusCode == 202) {
        final data = jsonDecode(res.body);
        return data['task_id'] as String?;
      }
    } catch (_) {}
    return null;
  }

  // ── /postprocess ─────────────────────────────────────────────────────────
  Future<String?> postprocess({required String lrcPath}) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/postprocess'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'lrc_path': lrcPath}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 || res.statusCode == 202) {
        final data = jsonDecode(res.body);
        return data['task_id'] as String?;
      }
    } catch (_) {}
    return null;
  }

  void dispose() => _client.close();
}
