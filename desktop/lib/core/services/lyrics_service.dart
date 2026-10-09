import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class LyricLine {
  final Duration time;
  final String text;

  const LyricLine({required this.time, required this.text});

  @override
  String toString() => '[${time.inMinutes}:${(time.inSeconds % 60).toString().padLeft(2, '0')}] $text';
}

/// Administra la carga, parseo y sincronización milimétrica de letras .lrc
class LyricsService extends ChangeNotifier {
  final ApiService _apiService;

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
    if (_sourceType == 'online') {
      return _currentSource ?? 'Online';
    } else if (_sourceType == 'hybrid') {
      return 'Híbrido (Online + IA)';
    } else if (_sourceType == 'local_ai') {
      return 'Whisper IA Local';
    } else if (_sourceType == 'local_file') {
      return 'Archivo Local (.lrc)';
    }
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
      if (position >= _lines[i].time) {
        newIndex = i;
      } else {
        break;
      }
    }

    if (newIndex != _currentIndex) {
      _currentIndex = newIndex;
      notifyListeners();
    }
  }

  /// Limpia las letras actuales
  void clear() {
    _lines = [];
    _currentIndex = -1;
    _currentSource = null;
    _sourceType = null;
    _statusMessage = '';
    _loadedAudioPath = null;
    _loadedArtist = null;
    _loadedTitle = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Busca si ya existe un archivo .lrc en las carpetas estándar de la CLI o del sistema
  static File? findExistingLrc(String audioPath, {String? artist, String? title}) {
    final file = File(audioPath);
    final audioDir = file.parent.path;
    final filename = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : audioPath.split(Platform.pathSeparator).last;
    final nameWithoutExt = filename.contains('.') ? filename.substring(0, filename.lastIndexOf('.')) : filename;

    final candidateDirs = [
      '/home/santiago007/Documentos/titofy/cli/lrc',
      '../cli/lrc',
      'cli/lrc',
      '/home/santiago007/Documentos/titofy/backend/lrc',
      '../backend/lrc',
      'backend/lrc',
      '$audioDir/lyrics',
      '$audioDir/lrc',
    ];

    // 1. Coincidencia exacta de archivo ($baseName.lrc)
    for (final cDir in candidateDirs) {
      final exactCandidate = File('$cDir/$nameWithoutExt.lrc');
      if (exactCandidate.existsSync() && exactCandidate.lengthSync() > 0) {
        return exactCandidate;
      }
      if (artist != null && title != null) {
        final artistTitleCand = File('$cDir/$artist - $title.lrc');
        if (artistTitleCand.existsSync() && artistTitleCand.lengthSync() > 0) {
          return artistTitleCand;
        }
      }
      if (title != null) {
        final titleCand = File('$cDir/$title.lrc');
        if (titleCand.existsSync() && titleCand.lengthSync() > 0) {
          return titleCand;
        }
      }
    }

    // 2. Coincidencia normalizada/difusa en cli/lrc
    for (final cliDir in ['/home/santiago007/Documentos/titofy/cli/lrc', '../cli/lrc', 'cli/lrc', '$audioDir/lyrics']) {
      final d = Directory(cliDir);
      if (d.existsSync()) {
        final cleanBase = nameWithoutExt.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        final cleanTitle = (title ?? '').toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        try {
          for (final entity in d.listSync()) {
            if (entity is File && entity.path.toLowerCase().endsWith('.lrc')) {
              final fName = entity.uri.pathSegments.last.toLowerCase();
              final cleanFName = fName.substring(0, fName.lastIndexOf('.')).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
              if (cleanBase.isNotEmpty && (cleanFName == cleanBase || cleanFName.contains(cleanBase) || cleanBase.contains(cleanFName))) {
                if (entity.lengthSync() > 0) return entity;
              }
              if (cleanTitle.length > 3 && (cleanFName.contains(cleanTitle) || cleanTitle.contains(cleanFName))) {
                if (entity.lengthSync() > 0) return entity;
              }
            }
          }
        } catch (_) {}
      }
    }

    return null;
  }

  /// Retorna si el audio ya tiene un archivo de letra listo
  static bool hasExistingLyrics(String audioPath, {String? artist, String? title}) {
    return findExistingLrc(audioPath, artist: artist, title: title) != null;
  }

  /// Carga letras para un archivo de audio local buscando el .lrc o consultando la API
  Future<void> loadForAudio(String audioPath, {String? artist, String? title}) async {
    _loadedAudioPath = audioPath;
    _loadedArtist = artist;
    _loadedTitle = title;
    _isLoading = true;
    _currentIndex = -1;
    _statusMessage = 'Comprobando archivos .lrc locales...';
    notifyListeners();

    // Eliminar archivo .lrc residual que se haya guardado en la carpeta de música del usuario
    final dotIndex = audioPath.lastIndexOf('.');
    if (dotIndex != -1) {
      final strayMusicLrc = File('${audioPath.substring(0, dotIndex)}.lrc');
      if (strayMusicLrc.existsSync()) {
        try {
          strayMusicLrc.deleteSync();
          debugPrint('[LyricsService] Eliminado .lrc residual en carpeta de música: ${strayMusicLrc.path}');
        } catch (_) {}
      }
    }

    // 1. Verificar si ya existe .lrc en carpeta local o en cli/lrc generada por la CLI
    final existingFile = findExistingLrc(audioPath, artist: artist, title: title);
    if (existingFile != null) {
      try {
        final content = await existingFile.readAsString();
        final parsed = parseLrc(content);
        if (parsed.isNotEmpty) {
          _lines = parsed;
          final isCliCache = existingFile.path.contains('cli/lrc');
          _sourceType = 'local_file';
          final originName = isCliCache ? 'Caché CLI (.lrc)' : 'Archivo .lrc local';
          _currentSource = originName;
          _statusMessage = 'Letra cargada desde archivo local (.lrc)';
          _isLoading = false;
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('[LyricsService] Error leyendo .lrc existente: $e');
      }
    }

    // 2. Si no existe en ningún archivo local, avisar y consultar proveedores online
    _statusMessage = 'Consultando Fuente 1...';
    notifyListeners();

    final stageTimer = Timer.periodic(const Duration(milliseconds: 1400), (t) {
      if (!_isLoading) {
        t.cancel();
        return;
      }
      if (t.tick == 1) {
        _statusMessage = 'Consultando Fuente 2...';
        notifyListeners();
      } else if (t.tick >= 2) {
        _statusMessage = 'Consultando Fuente 3...';
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

      if (res != null && res['lines'] != null && (res['lines'] as List).isNotEmpty) {
        final rawLines = res['lines'] as List<dynamic>;
        _lines = rawLines.map((item) {
          final sec = (item['start'] as num? ?? item['time'] as num? ?? 0.0).toDouble();
          return LyricLine(
            time: Duration(milliseconds: (sec * 1000).round()),
            text: (item['text'] ?? '').toString(),
          );
        }).toList();

        final src = res['source']?.toString().toLowerCase() ?? '';
        final prov = res['provider']?.toString() ?? '';

        if (src == 'online_aligned' || prov.contains('Alineada') || prov.toLowerCase().contains('calibrado')) {
          _sourceType = 'hybrid';
          _currentSource = prov.isNotEmpty ? prov : 'Fuente 1 · Alineada con Audio';
          _statusMessage = 'Letra alineada con el audio local';
        } else if (src == 'ai_generated' || prov.toLowerCase().contains('whisper')) {
          _sourceType = 'local_ai';
          _currentSource = 'Whisper IA (Transcripción)';
          _statusMessage = 'Letra transcrita con IA local';
        } else if (prov.contains('Fuente 1') || prov.toLowerCase().contains('lrclib')) {
          _sourceType = 'online';
          _currentSource = 'Fuente 1';
          _statusMessage = 'Letra sincronizada obtenida de Fuente 1';
        } else if (prov.contains('Fuente 2') || prov.toLowerCase().contains('netease')) {
          _sourceType = 'online';
          _currentSource = 'Fuente 2';
          _statusMessage = 'Letra sincronizada obtenida de Fuente 2';
        } else if (prov.contains('Fuente 3') || prov.toLowerCase().contains('genius') || prov.toLowerCase().contains('lyrist')) {
          _sourceType = 'online';
          _currentSource = 'Fuente 3';
          _statusMessage = 'Letra obtenida de Fuente 3';
        } else {
          _sourceType = 'online';
          _currentSource = prov.isNotEmpty ? prov : 'Fuente 1';
          _statusMessage = 'Letra sincronizada exitosamente';
        }
      } else {
        _sourceType = null;
        _currentSource = null;
        _statusMessage = 'No se encontró letra online ni local';
      }
    } catch (e) {
      stageTimer.cancel();
      debugPrint('[LyricsService] Error al resolver letra online: $e');
      _sourceType = null;
      _currentSource = null;
      _statusMessage = 'Error buscando letra';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fuerza la regeneración de letras mediante Whisper / Alineación
  Future<bool> regenerateWithAI(String audioPath, {String model = 'small'}) async {
    _isLoading = true;
    _statusMessage = 'Transcribiendo audio con Faster-Whisper local ($model)...';
    notifyListeners();

    try {
      final res = await _apiService.resolveLyrics(
        audioPath: audioPath,
        outputPath: null,
        model: model,
        mode: 'ai_only',
        force: true,
      );

      if (res != null && res['lines'] != null && (res['lines'] as List).isNotEmpty) {
        final rawLines = res['lines'] as List<dynamic>;
        _lines = rawLines.map((item) {
          final sec = (item['start'] as num? ?? item['time'] as num? ?? 0.0).toDouble();
          return LyricLine(
            time: Duration(milliseconds: (sec * 1000).round()),
            text: (item['text'] ?? '').toString(),
          );
        }).toList();
        _sourceType = 'local_ai';
        _currentSource = 'Whisper IA Local ($model)';
        _statusMessage = 'Letra generada con Whisper IA Local ($model)';
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (_) {}

    _isLoading = false;
    _statusMessage = 'Error al generar con IA local';
    notifyListeners();
    return false;
  }

  /// Ajusta las marcas de tiempo de la letra actual escuchando el archivo de audio local con Whisper (Forced Alignment)
  Future<bool> realignWithAudio({String model = 'base'}) async {
    if (_loadedAudioPath == null || _loadedAudioPath!.isEmpty) return false;
    final file = File(_loadedAudioPath!);
    if (!file.existsSync()) return false;

    _isLoading = true;
    _statusMessage = 'Alineando letra con el audio local (IA)...';
    notifyListeners();

    try {
      final res = await _apiService.resolveLyrics(
        artist: _loadedArtist,
        title: _loadedTitle,
        audioPath: _loadedAudioPath!,
        outputPath: null,
        model: model,
        mode: 'online_align',
        force: true,
      );

      if (res != null && res['lines'] != null && (res['lines'] as List).isNotEmpty) {
        final rawLines = res['lines'] as List<dynamic>;
        _lines = rawLines.map((item) {
          final sec = (item['start'] as num? ?? item['time'] as num? ?? 0.0).toDouble();
          return LyricLine(
            time: Duration(milliseconds: (sec * 1000).round()),
            text: (item['text'] ?? '').toString(),
          );
        }).toList();

        final prov = res['provider']?.toString() ?? '';
        _sourceType = 'hybrid';
        _currentSource = prov.isNotEmpty ? prov : 'Alineada con Audio (IA)';
        _statusMessage = 'Letra alineada con el audio local';
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[LyricsService] Error al alinear con audio: $e');
    }

    _isLoading = false;
    _statusMessage = 'No se pudo alinear la letra con el audio local';
    notifyListeners();
    return false;
  }

  /// Parsea una cadena de texto en formato LRC estándar de manera tolerante y completa
  static List<LyricLine> parseLrc(String content) {
    final result = <LyricLine>[];
    final lines = content.split('\n');
    double offsetSeconds = 0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Offset [offset:+/-NNN]
      final offsetMatch = RegExp(r'\[offset:([+-]?\d+)\]', caseSensitive: false).firstMatch(trimmed);
      if (offsetMatch != null) {
        offsetSeconds = (int.tryParse(offsetMatch.group(1)!) ?? 0) / 1000.0;
        continue;
      }

      // Metadata tags
      if (trimmed.startsWith('[ti:') || trimmed.startsWith('[ar:') || trimmed.startsWith('[al:') || trimmed.startsWith('[by:')) {
        continue;
      }

      // Check for timestamp matches
      final regExp = RegExp(r'\[(\d+):(\d+)(?:\.(\d+))?\]');
      final matches = regExp.allMatches(trimmed);
      if (matches.isEmpty) continue;

      // Extract text by removing all timestamps
      final text = trimmed.replaceAll(regExp, '').trim();
      if (text.isEmpty) continue;

      for (final match in matches) {
        final minutes = int.tryParse(match.group(1)!) ?? 0;
        final seconds = int.tryParse(match.group(2)!) ?? 0;
        final fracStr = match.group(3);
        final fraction = fracStr != null ? (double.tryParse('0.$fracStr') ?? 0.0) : 0.0;
        final totalSeconds = (minutes * 60 + seconds + fraction + offsetSeconds);
        final totalMs = (totalSeconds * 1000).round();

        result.add(LyricLine(
          time: Duration(milliseconds: totalMs < 0 ? 0 : totalMs),
          text: text,
        ));
      }
    }

    result.sort((a, b) => a.time.compareTo(b.time));

    // Des-colapsar marcas de tiempo idénticas para que ningún grupo de versos se salte al unísono
    if (result.length > 1) {
      int i = 0;
      while (i < result.length) {
        int j = i + 1;
        while (j < result.length && result[j].time == result[i].time) {
          j++;
        }
        final count = j - i;
        if (count > 1) {
          final commonTime = result[i].time;
          final prevTime = (i > 0) ? result[i - 1].time : Duration.zero;
          final availableBeforeMs = commonTime.inMilliseconds - prevTime.inMilliseconds;

          // Si hay espacio previo suficiente (ej. intro largo de 30s), repartir hacia atrás antes de commonTime
          if (i > 0 && availableBeforeMs >= count * 1500) {
            final startMs = commonTime.inMilliseconds - (count - 1) * 2000;
            final actualStartMs = startMs < prevTime.inMilliseconds + 500
                ? prevTime.inMilliseconds + 500
                : startMs;
            final stepMs = ((commonTime.inMilliseconds - actualStartMs) / (count - 1)).round();
            for (int k = 0; k < count - 1; k++) {
              final newMs = actualStartMs + (k * stepMs);
              result[i + k] = LyricLine(time: Duration(milliseconds: newMs), text: result[i + k].text);
            }
          } else {
            // Repartir hacia adelante con mínimo 1.5s entre cada línea duplicada
            for (int k = 1; k < count; k++) {
              final newMs = commonTime.inMilliseconds + (k * 1500);
              result[i + k] = LyricLine(time: Duration(milliseconds: newMs), text: result[i + k].text);
            }
          }
        }
        i = j;
      }
      // Re-ordenar por seguridad y asegurar monotonicidad mínima
      result.sort((a, b) => a.time.compareTo(b.time));
      for (int k = 1; k < result.length; k++) {
        if (result[k].time <= result[k - 1].time) {
          result[k] = LyricLine(
            time: result[k - 1].time + const Duration(milliseconds: 800),
            text: result[k].text,
          );
        }
      }
    }

    return result;
  }
}
