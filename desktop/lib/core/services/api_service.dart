import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Servicio de conexión con la API local de Titofy (FastAPI en http://127.0.0.1:8642)
class ApiService extends ChangeNotifier {
  static const String defaultUrl = 'http://127.0.0.1:8642';
  String _baseUrl = defaultUrl;
  final http.Client _client = http.Client();

  bool _isOnline = false;
  bool _isStartingBackend = false;
  Map<String, dynamic>? _lastHealth;
  Timer? _healthTimer;
  Process? _backendProcess;

  bool get isOnline => _isOnline;
  bool get isStartingBackend => _isStartingBackend;
  Map<String, dynamic>? get lastHealth => _lastHealth;
  String get baseUrl => _baseUrl;

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

  // ── Auto-arranque del Backend Python con detección de .venv ──────────────
  Future<bool> ensureServerRunning() async {
    if (await checkHealth() != null) return true;

    _isStartingBackend = true;
    notifyListeners();

    try {
      final backendDir = _resolveBackendDirectory();
      if (backendDir == null) {
        debugPrint('[ApiService] No se pudo encontrar la carpeta backend');
        _isStartingBackend = false;
        notifyListeners();
        return false;
      }

      final pythonBin = _resolvePythonExecutable(backendDir);
      final serverScript = '$backendDir/api_server.py';
      final venvDir = '$backendDir/.venv';

      // Si el puerto está ocupado por un proceso zombie previo que no responde, liberarlo
      await _freePort(8642);

      debugPrint('[ApiService] Iniciando backend: $pythonBin $serverScript (cwd: $backendDir)');

      final isWin = Platform.isWindows;
      final venvBinDir = isWin ? '$backendDir\\.venv\\Scripts' : '$venvDir/bin';
      final pathSep = isWin ? ';' : ':';

      _backendProcess = await Process.start(
        pythonBin,
        ['-u', serverScript],
        workingDirectory: backendDir,
        environment: {
          'VIRTUAL_ENV': venvDir,
          'PATH': '$venvBinDir$pathSep${Platform.environment['PATH'] ?? ''}',
          'PYTHONPATH': backendDir,
          'PYTHONUNBUFFERED': '1',
        },
        mode: ProcessStartMode.normal,
      );

      _backendProcess?.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('[FastAPI-stdout] $data');
      });
      _backendProcess?.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('[FastAPI-stderr] $data');
      });

      _backendProcess?.exitCode.then((code) {
        debugPrint('[ApiService] Backend process finalizó con código: $code');
        _isOnline = false;
        notifyListeners();
      });

      // Esperar hasta 8 segundos a que la API responda
      for (int i = 0; i < 24; i++) {
        await Future.delayed(const Duration(milliseconds: 350));
        if (await checkHealth() != null) {
          _isStartingBackend = false;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('[ApiService] Error al auto-iniciar backend: $e');
    }

    _isStartingBackend = false;
    notifyListeners();
    return false;
  }

  String? _resolveBackendDirectory() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final currentDir = Directory.current.path;
    final candidates = [
      '$exeDir/backend',
      '$exeDir/../backend',
      '$currentDir/backend',
      '$currentDir/../backend',
      '$currentDir/../../backend',
      '/home/santiago007/Documentos/titofy/backend',
      '/home/santiago007/.local/share/titofy/backend',
    ];

    for (final c in candidates) {
      final script = File('$c/api_server.py');
      if (script.existsSync()) return Directory(c).absolute.path;
    }
    return null;
  }

  String _resolvePythonExecutable(String backendDir) {
    // 1. Variable de entorno
    final envPython = Platform.environment['PYTHON'];
    if (envPython != null && File(envPython).existsSync()) return envPython;

    // 2. Virtualenv del backend (.venv)
    final isWin = Platform.isWindows;
    final venvBin = isWin
        ? '$backendDir/.venv/Scripts/python.exe'
        : '$backendDir/.venv/bin/python';
    if (File(venvBin).existsSync()) return venvBin;

    final venvAlt = isWin
        ? '$backendDir/venv/Scripts/python.exe'
        : '$backendDir/venv/bin/python';
    if (File(venvAlt).existsSync()) return venvAlt;

    return isWin ? 'python' : 'python3';
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

  // ── /transcribe (Whisper local en background) ────────────────────────────
  Future<String?> transcribe({
    required String audioPath,
    String model = 'small',
    String language = 'es',
    String? outputPath,
    bool wordMode = true,
  }) async {
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

  /// Descarga / precarga en caché el modelo seleccionado
  Future<bool> preloadModel(String model) async {
    try {
      final res = await _client.post(
        Uri.parse('$_baseUrl/models/preload'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'model': model}),
      ).timeout(const Duration(minutes: 6));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Libera el puerto matando cualquier proceso huérfano si el backend anterior quedó congelado
  Future<void> _freePort(int port) async {
    try {
      if (Platform.isWindows) {
        final res = await Process.run('cmd', ['/c', 'netstat -ano | findstr :$port']);
        if (res.exitCode == 0 && res.stdout.toString().isNotEmpty) {
          for (final line in res.stdout.toString().split('\n')) {
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.length >= 5 && parts.contains('LISTENING')) {
              final pid = parts.last;
              await Process.run('taskkill', ['/F', '/PID', pid]);
            }
          }
        }
      } else {
        // En Linux/macOS, terminar cualquier proceso ocupando el puerto TCP
        await Process.run('fuser', ['-k', '$port/tcp']);
      }
      await Future.delayed(const Duration(milliseconds: 250));
    } catch (_) {}
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _client.close();
    _backendProcess?.kill();
    super.dispose();
  }
}
