import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../models/lyric_line.dart';
import 'lyrics/lrc_parser.dart';
import 'lyrics/lyrics_cache_manager.dart';
import 'lyrics/lyrics_ai_coordinator.dart';

export '../models/lyric_line.dart';
export 'lyrics/lrc_parser.dart';
export 'lyrics/lyrics_cache_manager.dart';
export 'lyrics/lyrics_ai_coordinator.dart';

/// Administra la carga, parseo y sincronización milimétrica de letras .lrc
class LyricsService extends ChangeNotifier {
  final ApiService _apiService;
  int _activeRequestId = 0;

  List<LyricLine> _lines = [];
  int _currentIndex = -1;
  bool _isLoading = false;
  String _statusMessage = '';
  String? _sourceType; // 'online', 'hybrid', 'local_ai', 'local_file'
  String? _currentSource;
  String? _loadedAudioPath;
  String? _loadedArtist;
  String? _loadedTitle;

  List<LyricLine> get lines => _lines;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;
  String? get sourceType => _sourceType;
  String? get currentSource => _currentSource;
  String? get loadedAudioPath => _loadedAudioPath;
  String? get loadedArtist => _loadedArtist;
  String? get loadedTitle => _loadedTitle;

  /// Retorna un texto amigable y claro de la procedencia de la letra (sin emojis)
  String get sourceLabel {
    if (_sourceType == 'online') return _currentSource ?? 'Online';
    if (_sourceType == 'hybrid') return 'Híbrido (Online + IA)';
    if (_sourceType == 'local_ai') return 'Whisper IA Local';
    if (_sourceType == 'local_file') return 'Archivo Local (.lrc)';
    return _currentSource ?? '';
  }

  LyricLine? get currentLine =>
      (_currentIndex >= 0 && _currentIndex < _lines.length) ? _lines[_currentIndex] : null;

  LyricsService(this._apiService);

  /// Actualiza la línea activa según la posición de reproducción
  void updatePosition(Duration position) {
    if (_lines.isEmpty) return;
    int newIndex = -1;
    for (int i = 0; i < _lines.length; i++) {
      if (position >= _lines[i].time) newIndex = i; else break;
    }
    if (newIndex != _currentIndex) {
      _currentIndex = newIndex;
      notifyListeners();
    }
  }

  /// Limpia las letras actuales
  void clear() {
    _activeRequestId++;
    _lines = [];
    _currentIndex = -1;
    _currentSource = _sourceType = _loadedAudioPath = _loadedArtist = _loadedTitle = null;
    _statusMessage = '';
    _isLoading = false;
    notifyListeners();
  }

  /// Busca si ya existe un archivo .lrc en las carpetas estándar de la CLI o del sistema
  static File? findExistingLrc(String audioPath, {String? artist, String? title}) =>
      LyricsCacheManager.findExistingLrc(audioPath, artist: artist, title: title);

  /// Retorna si el audio ya tiene un archivo de letra listo
  static bool hasExistingLyrics(String audioPath, {String? artist, String? title}) =>
      LyricsCacheManager.hasExistingLyrics(audioPath, artist: artist, title: title);

  /// Carga letras para un archivo de audio local buscando el .lrc o consultando la API
  Future<void> loadForAudio(String audioPath, {String? artist, String? title}) async {
    final reqId = ++_activeRequestId;
    _loadedAudioPath = audioPath;
    _loadedArtist = artist;
    _loadedTitle = title;
    _lines = [];
    _currentIndex = -1;
    _sourceType = _currentSource = null;
    _isLoading = true;
    _statusMessage = 'Comprobando archivos .lrc locales...';
    notifyListeners();

    // Eliminar archivo .lrc residual que se haya guardado en la carpeta de música del usuario
    LyricsCacheManager.cleanStrayMusicLrc(audioPath);

    // 1. Verificar si ya existe .lrc en carpeta local o en caché interna (cli/lrc o titofy/lrc)
    final existingFile = findExistingLrc(audioPath, artist: artist, title: title);
    if (existingFile != null) {
      try {
        final content = await existingFile.readAsString();
        final parsed = parseLrc(content);
        if (parsed.isNotEmpty) {
          if (_activeRequestId != reqId) return;
          _lines = parsed;

          final lower = content.toLowerCase();
          final isAi = lower.contains('ai_generated') || lower.contains('whisper');
          final isHybrid = lower.contains('online_aligned') ||
              lower.contains('alineada con audio') ||
              lower.contains('calibrado');

          if (isHybrid) {
            _sourceType = 'hybrid';
            _currentSource = 'Alineada con Audio (Caché)';
            _statusMessage = 'Letra sincronizada en caché';
          } else if (isAi) {
            _sourceType = 'local_ai';
            _currentSource = 'Whisper IA (Guardada)';
            _statusMessage = 'Letra generada previamente por IA';
          } else {
            _sourceType = 'local_file';
            _currentSource = 'Archivo .lrc guardado';
            _statusMessage = 'Letra cargada desde archivo local (.lrc)';
          }

          _isLoading = false;
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('[LyricsService] Error leyendo .lrc existente: $e');
      }
    }

    // 2. Si no existe en ningún archivo local, avisar y consultar proveedores online
    if (_activeRequestId != reqId) return;
    _statusMessage = 'Consultando Fuente 1...';
    notifyListeners();

    final stageTimer = Timer.periodic(const Duration(milliseconds: 1400), (t) {
      if (!_isLoading || _activeRequestId != reqId) {
        t.cancel();
      } else {
        _statusMessage = 'Consultando Fuente ${t.tick + 1}...';
        notifyListeners();
      }
    });

    try {
      final res = await _apiService.resolveLyrics(
        artist: artist,
        title: title,
        audioPath: audioPath,
        outputPath: null,
        mode: 'auto',
        force: false,
      );
      stageTimer.cancel();
      if (_activeRequestId != reqId) return;

      if (res != null && res['lines'] != null && (res['lines'] as List).isNotEmpty) {
        applyResolvedResponse(res);
        _cacheLrc(audioPath, artist, title, _lines, by: _currentSource);
        _isLoading = false;
        notifyListeners();
        return;
      } else {
        _lines = [];
        _currentIndex = -1;
        _sourceType = null;
        _currentSource = null;
        _statusMessage = 'No se encontró letra online ni local';
      }
    } catch (e) {
      stageTimer.cancel();
      if (_activeRequestId != reqId) return;
      debugPrint('[LyricsService] Error al resolver letra online: $e');
      _lines = [];
      _currentIndex = -1;
      _sourceType = null;
      _currentSource = null;
      _statusMessage = 'Error buscando letra';
    }

    if (_activeRequestId == reqId) {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Aplica directamente una respuesta del backend sin volver a leer la caché.
  /// Es importante después de una alineación: la caché puede contener el LRC
  /// online anterior y no debe pisar el resultado recién calibrado.
  bool applyResolvedResponse(Map<String, dynamic> res) {
    final raw = res['lines'];
    if (raw is! List || raw.isEmpty) return false;

    _lines = raw.map((item) {
      final map = item as Map;
      final sec = (map['start'] as num? ?? map['time'] as num? ?? 0.0).toDouble();
      return LyricLine(
        time: Duration(milliseconds: (sec * 1000).round()),
        text: (map['text'] ?? '').toString(),
      );
    }).toList();

    final src = res['source']?.toString().toLowerCase() ?? '';
    final prov = res['provider']?.toString() ?? '';
    final lowerProv = prov.toLowerCase();
    if (src == 'online_aligned' || lowerProv.contains('alineada') || lowerProv.contains('calibrado')) {
      _sourceType = 'hybrid';
      _currentSource = prov.isNotEmpty ? prov : 'Fuente 1 · Alineada con Audio';
      _statusMessage = 'Letra alineada con el audio local';
    } else if (src == 'ai_generated' || lowerProv.contains('whisper')) {
      _sourceType = 'local_ai';
      _currentSource = 'Whisper IA (Transcripción)';
      _statusMessage = 'Letra transcrita con IA local';
    } else {
      _sourceType = 'online';
      _currentSource = prov.isNotEmpty ? prov : (lowerProv.contains('netease') ? 'Fuente 2' : 'Fuente 1');
      _statusMessage = 'Letra sincronizada obtenida de $_currentSource';
    }
    return true;
  }

  /// Fuerza la regeneración de letras mediante Whisper local
  Future<bool> regenerateWithAI(String audioPath, {String model = 'small'}) async {
    _isLoading = true;
    _statusMessage = 'Transcribiendo audio con Faster-Whisper local ($model)...';
    notifyListeners();

    final res = await LyricsAiCoordinator.generateAiLyrics(_apiService, audioPath, model: model);
    if (res != null && res['lines'] != null && (res['lines'] as List).isNotEmpty) {
      applyResolvedResponse(res);
      _sourceType = 'local_ai';
      _currentSource = 'Whisper IA Local ($model)';
      _statusMessage = 'Letra generada con Whisper IA Local ($model)';
      _cacheLrc(audioPath, _loadedArtist, _loadedTitle, _lines, by: _currentSource);
      _isLoading = false;
      notifyListeners();
      return true;
    }

    _isLoading = false;
    _statusMessage = 'Error al generar con IA local';
    notifyListeners();
    return false;
  }

  /// Ajusta las marcas de tiempo de la letra actual escuchando el archivo de audio local con Whisper (Forced Alignment)
  Future<bool> realignWithAudio({String? model}) async {
    if (_loadedAudioPath == null || _loadedAudioPath!.isEmpty) return false;

    _isLoading = true;
    _statusMessage = 'Alineando letra con el audio local (IA)...';
    notifyListeners();

    final res = await LyricsAiCoordinator.alignLyricsWithAudio(
      _apiService,
      audioPath: _loadedAudioPath!,
      artist: _loadedArtist,
      title: _loadedTitle,
      model: model,
    );

    if (res != null && res['lines'] != null && (res['lines'] as List).isNotEmpty) {
      applyResolvedResponse(res);
      final prov = res['provider']?.toString() ?? '';
      _sourceType = 'hybrid';
      _currentSource = prov.isNotEmpty ? prov : 'Alineada con Audio (IA)';
      _statusMessage = 'Letra alineada con el audio local';
      _cacheLrc(_loadedAudioPath!, _loadedArtist, _loadedTitle, _lines, by: _currentSource);
      _isLoading = false;
      notifyListeners();
      return true;
    }

    _isLoading = false;
    _statusMessage = 'No se pudo alinear la letra con el audio local';
    notifyListeners();
    return false;
  }

  /// Guarda una letra sincronizada en caché interna para que su carga futura sea instantánea (offline y sin esperas)
  void _cacheLrc(String audioPath, String? artist, String? title, List<LyricLine> lines, {String? by}) =>
      LyricsCacheManager.saveToCache(audioPath, artist, title, lines, by: by);

  /// Parsea una cadena de texto en formato LRC estándar de manera tolerante y completa
  static List<LyricLine> parseLrc(String content) => LrcParser.parse(content);
}
