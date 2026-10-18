import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'backend_process_manager.dart';
import 'windows/windows_backend_service.dart';

/// Servicio de conexión con la API local de Titofy (FastAPI en http://127.0.0.1:8642)
class ApiService extends ChangeNotifier {
  static const String defaultUrl = 'http://127.0.0.1:8642';
  String _baseUrl = defaultUrl;
  final http.Client _client = http.Client();
  final BackendProcessManager _processManager = BackendProcessManager();

  bool _isOnline = false;
  bool _isStartingBackend = false;
  Map<String, dynamic>? _lastHealth;
  Timer? _healthTimer;
  String? _lastErrorMessage;

  bool get isOnline => _isOnline;
  bool get isStartingBackend => _isStartingBackend;
  Map<String, dynamic>? get lastHealth => _lastHealth;
  String get baseUrl => _baseUrl;
  String? get lastErrorMessage => _lastErrorMessage ?? _processManager.lastErrorMessage;

  ApiService({String? baseUrl}) {
    if (baseUrl != null) _baseUrl = baseUrl;
    // Intentar conectar o auto-arrancar backend inmediatamente
    _initBackend();
    // Sondeo de estado cada 4 segundos
    _healthTimer = Timer.periodic(const Duration(seconds: 4), (_) => checkHealth());
  }

  Future<void> _initBackend() async {
    final health = await checkHealth();
    if (health != null) {
      // Reiniciar backend para asegurar que ejecute el código más reciente
      await restartBackend();
    } else {
      await ensureServerRunning();
    }
  }

  void updateBaseUrl(String newUrl) {
    _baseUrl = newUrl;
    checkHealth();
  }

  // ── /health ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> checkHealth() async {
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(milliseconds: 2500));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        _isOnline = data['status'] == 'ok';
        _lastHealth = data;
        notifyListeners();
        return data;
      }
    } catch (_) {
      _isOnline = false;
      notifyListeners();
    }
    return null;
  }

  /// Reinicia el backend de FastAPI para recargar código actualizado
  Future<bool> restartBackend() async {
    try {
      await _client.post(Uri.parse('$_baseUrl/shutdown')).timeout(const Duration(milliseconds: 600));
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 500));
    return await ensureServerRunning();
  }

  // ── Auto-arranque del Backend Python ──────────────────────────────────────
  Future<bool> ensureServerRunning() async {
    if (await checkHealth() != null) return true;

    _isStartingBackend = true;
    notifyListeners();

    try {
      final backendDir = _processManager.resolveBackendDirectory();
      if (backendDir == null) {
        debugPrint('[ApiService] No se pudo encontrar la carpeta backend');
        _isStartingBackend = false;
        notifyListeners();
        return false;
      }

      await _processManager.startProcess(
        backendDir: backendDir,
        onStdout: (data) => debugPrint('[FastAPI-stdout] $data'),
        onStderr: (data) {
          debugPrint('[FastAPI-stderr] $data');
          _lastErrorMessage = data.trim();
          notifyListeners();
        },
        onExit: (code) {
          debugPrint('[ApiService] Backend finalizó con código: $code');
          _isOnline = false;
          notifyListeners();
        },
      );

      // Esperar hasta 15 segundos a que la API responda
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await checkHealth() != null) {
          _processManager.syncLocalBackendCodeToTemp(backendDir);
          if (Platform.isWindows) {
            await WindowsBackendService().warmupWindowsPatches(_baseUrl, _client);
          }
          _isStartingBackend = false;
          _lastErrorMessage = null;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      _lastErrorMessage = e.toString();
      debugPrint('[ApiService] Error al auto-iniciar backend: $e');
    }

    _isStartingBackend = false;
    notifyListeners();
    return false;
  }

  // ── /lyrics/resolve (Motor Híbrido: LRCLIB → Lyrics.ovh + Align → Whisper) ──
  Future<Map<String, dynamic>?> resolveLyrics({
    String? artist,
    String? title,
    double? duration,
    String? audioPath,
    String mode = 'auto',
    String model = 'small',
    String language = 'auto',
    String? outputPath,
    bool force = false,
  }) async {
    final bDir = _processManager.resolveBackendDirectory();
    if (bDir != null) _processManager.syncLocalBackendCodeToTemp(bDir);
    try {
      final payload = {
        'artist': artist,
        'title': title,
        'duration': duration,
        'audio_path': audioPath,
        'mode': mode,
        'model': model,
        'language': language,
        'output_path': outputPath,
        'force': force,
      };

      final res = await _client
          .post(
            Uri.parse('$_baseUrl/lyrics/resolve'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(minutes: 5));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      } else {
        try {
          final errBody = jsonDecode(utf8.decode(res.bodyBytes));
          if (errBody is Map && errBody['detail'] != null) {
            throw Exception(errBody['detail'].toString());
          }
        } on Exception catch (e) {
          if (!e.toString().contains('FormatException')) rethrow;
        }
        throw Exception('El servidor backend respondió con código ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] Error en resolveLyrics: $e');
      rethrow;
    }
  }

  // ── /youtube/playlist (Extracción de metadatos de YouTube / YT Music) ──────
  Future<Map<String, dynamic>?> extractYouTubePlaylist(String url) async {
    final bDir = _processManager.resolveBackendDirectory();
    if (bDir != null) _processManager.syncLocalBackendCodeToTemp(bDir);

    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/youtube/playlist'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'url': url.trim()}),
          )
          .timeout(const Duration(seconds: 40));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      } else {
        try {
          final errData = jsonDecode(utf8.decode(res.bodyBytes));
          throw Exception(errData['detail'] ?? 'Error al procesar el enlace de YouTube');
        } catch (e) {
          if (!e.toString().contains('FormatException')) rethrow;
          throw Exception('Error del servidor (${res.statusCode})');
        }
      }
    } catch (e) {
      debugPrint('[ApiService] Error en extractYouTubePlaylist: $e');
      rethrow;
    }
  }

  // ── /youtube/stream (Obtención de URL de streaming directo de audio) ───────
  Future<String?> getYouTubeStreamUrl(String videoId) async {
    final cleanId = videoId.replaceFirst('youtube:', '').trim();
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/youtube/stream'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'video_id': cleanId}),
          )
          .timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return data['stream_url'] as String?;
      } else {
        final err = jsonDecode(utf8.decode(res.bodyBytes));
        throw Exception(err['detail'] ?? 'Error al obtener flujo de audio');
      }
    } catch (e) {
      debugPrint('[ApiService] Error en getYouTubeStreamUrl: $e');
      rethrow;
    }
  }

  // ── /youtube/download (Descarga de audio en segundo plano) ─────────────────
  Future<Map<String, dynamic>?> downloadYouTubeTrack({
    required String videoId,
    String? title,
    String? artist,
    String? targetFolder,
  }) async {
    final cleanId = videoId.replaceFirst('youtube:', '').trim();
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/youtube/download'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'video_id': cleanId,
              'title': title,
              'artist': artist,
              'target_folder': targetFolder,
            }),
          )
          .timeout(const Duration(minutes: 5));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(utf8.decode(res.bodyBytes));
        throw Exception(err['detail'] ?? 'Error al descargar audio');
      }
    } catch (e) {
      debugPrint('[ApiService] Error en downloadYouTubeTrack: $e');
      rethrow;
    }
  }

  // ── /transcribe (Whisper local en background) ────────────────────────────
  Future<String?> transcribe({
    required String audioPath,
    String model = 'small',
    String language = 'es',
    String? outputPath,
    bool wordMode = true,
  }) async {
    final bDir = _processManager.resolveBackendDirectory();
    if (bDir != null) _processManager.syncLocalBackendCodeToTemp(bDir);
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/transcribe'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'audio_path': audioPath,
              'model': model,
              'language': language,
              'output_path': outputPath,
              'word_mode': wordMode,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        return data['task_id'] as String?;
      }
    } catch (e) {
      debugPrint('[ApiService] Error en transcribe: $e');
    }
    return null;
  }

  // ── /align (Forced Alignment local) ───────────────────────────────────────
  Future<String?> align({
    required String audioPath,
    required String lyricsText,
    String model = 'base',
    String language = 'es',
    String? outputPath,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/align'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'audio_path': audioPath,
              'lyrics_text': lyricsText,
              'model': model,
              'language': language,
              'output_path': outputPath,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        return data['task_id'] as String?;
      }
    } catch (e) {
      debugPrint('[ApiService] Error en align: $e');
    }
    return null;
  }

  // ── /status/{id} (Consulta de progreso para tareas en cola) ───────────────
  Future<Map<String, dynamic>?> status(String taskId) async {
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/status/$taskId'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
    } catch (_) {}
    return null;
  }

  // ── /postprocess (Limpieza algorítmica de timestamps) ─────────────────────
  Future<Map<String, dynamic>?> postprocess({
    required String lrcPath,
    int threshold = 85,
    String? outputPath,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/postprocess'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'lrc_path': lrcPath,
              'threshold': threshold,
              'output_path': outputPath,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
    } catch (_) {}
    return null;
  }

  /// Consulta la lista de modelos Whisper disponibles y su estado de descarga local
  Future<List<Map<String, dynamic>>> getModels() async {
    try {
      final res = await _client.get(Uri.parse('$_baseUrl/models')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final list = data['models'] as List<dynamic>?;
        if (list != null) {
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Descarga / precarga en caché el modelo seleccionado con sondeo no bloqueante
  Future<bool> preloadModel(String model) async {
    try {
      final res = await _client.post(
        Uri.parse('$_baseUrl/models/preload'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'model': model}),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return false;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body['status'] == 'ready') return true;

      // Sondear /models/status/$model periódicamente (hasta 15 minutos)
      for (int i = 0; i < 300; i++) {
        await Future.delayed(const Duration(seconds: 3));
        try {
          final statusRes = await _client
              .get(Uri.parse('$_baseUrl/models/status/$model'))
              .timeout(const Duration(seconds: 5));
          if (statusRes.statusCode == 200) {
            final st = jsonDecode(utf8.decode(statusRes.bodyBytes));
            if (st['status'] == 'ready') return true;
            if (st['status'] == 'error') {
              _lastErrorMessage = st['error']?.toString() ?? 'Error al descargar el modelo';
              notifyListeners();
              return false;
            }
          }
        } catch (_) {}
      }
      return false;
    } catch (e) {
      _lastErrorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _client.close();
    _processManager.killProcess();
    super.dispose();
  }
}
