import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:metadata_god/metadata_god.dart';
import 'database_service.dart';

/// Modelo de pista musical real con metadatos y estado de favoritos
class Track {
  final String path;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final Uint8List? artwork;
  bool isFavorite;

  Track({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.artwork,
    this.isFavorite = false,
  });

  String get durationFormatted {
    if (duration == Duration.zero) return '--:--';
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// Servicio de biblioteca musical exclusivo para archivos locales reales
class LibraryService extends ChangeNotifier {
  List<Track> _tracks = [];
  final Set<String> _favorites = {};
  bool _isScanning = false;
  String? _scanFolder;
  DatabaseService? _dbService;

  List<Track> get tracks => _tracks;
  List<Track> get realTracks => _tracks;
  bool get isScanning => _isScanning;
  String? get scannedFolder => _scanFolder;

  List<Track> get topCharts => _tracks.take(12).toList();
  List<Track> get favoriteTracks => getFavoriteTracks();

  static const Set<String> _audioExtensions = {
    'mp3', 'flac', 'wav', 'aac', 'm4a', 'ogg', 'opus', 'wma',
    'mp4', 'mkv', 'webm', 'mov', 'avi',
  };

  LibraryService() {
    _loadInitialMusicFolder();
  }

  void _loadInitialMusicFolder() {
    // 1. Intentar leer config.yaml del backend si tiene una carpeta guardada
    try {
      final candidates = [
        '../backend/config.yaml',
        'backend/config.yaml'
      ];
      for (final p in candidates) {
        final configFile = File(p);
        if (configFile.existsSync()) {
          final content = configFile.readAsStringSync();
          final match = RegExp(r'''music_folder:\s*['"]?(.+?)['"]?\s*$''', multiLine: true).firstMatch(content);
          if (match != null && match.group(1) != null && match.group(1)!.trim().isNotEmpty) {
            final savedDir = Directory(match.group(1)!.trim());
            if (savedDir.existsSync()) {
              scanFolder(savedDir.path);
              return;
            }
          }
          break;
        }
      }
    } catch (_) {}

    // 2. Si no, buscar en ~/Música o ~/Music del sistema
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null) {
      final musicaDir = Directory('$home/Música');
      final musicDir = Directory('$home/Music');
      if (musicaDir.existsSync()) {
        scanFolder(musicaDir.path);
      } else if (musicDir.existsSync()) {
        scanFolder(musicDir.path);
      }
    }
  }

  void attachDatabaseService(DatabaseService db) {
    _dbService = db;
    // Cargar pistas desde SQLite inmediatamente si estan disponibles
    if (_tracks.isEmpty) {
      final cached = _dbService!.getAllTracksRaw();
      if (cached.isNotEmpty) {
        _tracks = cached.map((m) {
          final isFav = (m['is_favorite'] as int? ?? 0) == 1;
          if (isFav) _favorites.add(m['path'] as String);
          return Track(
            path: m['path'] as String,
            title: m['title'] as String,
            artist: m['artist'] as String,
            album: m['album'] as String,
            duration: Duration(milliseconds: m['duration_ms'] as int? ?? 0),
            isFavorite: isFav,
          );
        }).toList();
        notifyListeners();
      }
    } else {
      // Sincronizar estado de favoritos
      for (final t in _tracks) {
        t.isFavorite = _dbService!.isFavorite(t.path);
        if (t.isFavorite) _favorites.add(t.path);
      }
      notifyListeners();
    }
  }

  List<Track> getFavoriteTracks() {
    if (_dbService != null) {
      final favPaths = _dbService!.favoritePaths;
      return _tracks.where((t) => favPaths.contains(t.path)).toList();
    }
    return _tracks.where((t) => _favorites.contains(t.path)).toList();
  }

  List<Track> getRecentlyPlayedTracks() {
    if (_dbService != null) {
      final recentPaths = _dbService!.getRecentlyPlayedPaths();
      final trackMap = {for (final t in _tracks) t.path: t};
      return recentPaths.map((p) => trackMap[p]).whereType<Track>().toList();
    }
    return [];
  }

  List<Track> getTracksForPlaylist(int playlistId) {
    if (_dbService != null) {
      final paths = _dbService!.getPlaylistTrackPaths(playlistId);
      final trackMap = {for (final t in _tracks) t.path: t};
      return paths.map((p) => trackMap[p]).whereType<Track>().toList();
    }
    return [];
  }

  void toggleFavorite(Track track) {
    if (_dbService != null) {
      final isFav = _dbService!.toggleFavorite(track.path);
      track.isFavorite = isFav;
      if (isFav) {
        _favorites.add(track.path);
      } else {
        _favorites.remove(track.path);
      }
    } else {
      if (_favorites.contains(track.path)) {
        _favorites.remove(track.path);
        track.isFavorite = false;
      } else {
        _favorites.add(track.path);
        track.isFavorite = true;
      }
    }
    notifyListeners();
  }

  bool isFavorite(Track track) {
    if (_dbService != null) {
      return _dbService!.isFavorite(track.path);
    }
    return _favorites.contains(track.path);
  }

  /// Selección interactiva de carpeta desde Ajustes
  Future<void> pickAndScan() async {
    final folder = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Selecciona tu carpeta de música para Titofy',
    );
    if (folder == null) return;
    await scanFolder(folder);
  }

  /// Escanea una carpeta específica en segundo plano
  Future<void> scanFolder(String folderPath) async {
    _isScanning = true;
    _scanFolder = folderPath;
    notifyListeners();

    // Guardar en config.yaml para persistencia compartida con CLI y Desktop
    try {
      final candidates = [
        '../backend/config.yaml',
        'backend/config.yaml',
        '/home/santiago007/Documentos/titofy/backend/config.yaml',
      ];
      for (final p in candidates) {
        final configFile = File(p);
        if (configFile.existsSync()) {
          var content = configFile.readAsStringSync();
          content = content.replaceAll(
            RegExp(r'''music_folder:\s*['"]?.*?['"]?\s*$''', multiLine: true),
            "music_folder: '$folderPath'",
          );
          configFile.writeAsStringSync(content);
          break;
        }
      }
    } catch (_) {}

    try {
      final newTracks = await compute(_scanFolderIsolate, folderPath);
      _tracks = newTracks;

      // Guardar pistas en SQLite de forma persistente
      if (_dbService != null && newTracks.isNotEmpty) {
        final trackMaps = newTracks.map((t) => {
          'path': t.path,
          'title': t.title,
          'artist': t.artist,
          'album': t.album,
          'duration_ms': t.duration.inMilliseconds,
        }).toList();
        _dbService!.upsertBatchTracksRaw(trackMaps);

        // Restaurar estado de favoritos desde la base de datos
        for (final t in _tracks) {
          t.isFavorite = _dbService!.isFavorite(t.path);
          if (t.isFavorite) _favorites.add(t.path);
        }
      }
    } catch (e) {
      debugPrint('[LibraryService] Error escaneando carpeta: $e');
    }

    _isScanning = false;
    notifyListeners();
  }

  static Future<List<Track>> _scanFolderIsolate(String folderPath) async {
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return [];

    try {
      await MetadataGod.initialize();
    } catch (_) {}

    final tracks = <Track>[];

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      final ext = entity.path.split('.').last.toLowerCase();
      if (!_audioExtensions.contains(ext)) continue;

      final filename = _filenameWithoutExt(entity.path);
      final parsed = _parseArtistAndTitle(filename);

      try {
        final metadata = await MetadataGod.readMetadata(file: entity.path);
        final artworkData = metadata.picture?.data;

        final title = (metadata.title != null && metadata.title!.trim().isNotEmpty)
            ? metadata.title!.trim()
            : parsed['title']!;

        final artist = (metadata.artist != null && metadata.artist!.trim().isNotEmpty)
            ? metadata.artist!.trim()
            : parsed['artist']!;

        tracks.add(Track(
          path: entity.path,
          title: title,
          artist: artist,
          album: metadata.album ?? 'Álbum local',
          duration: metadata.duration ?? Duration.zero,
          artwork: artworkData != null ? Uint8List.fromList(artworkData) : null,
        ));
      } catch (_) {
        tracks.add(Track(
          path: entity.path,
          title: parsed['title']!,
          artist: parsed['artist']!,
          album: 'Álbum local',
          duration: Duration.zero,
        ));
      }
    }

    tracks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return tracks;
  }

  static String _filenameWithoutExt(String path) {
    final base = path.split(Platform.pathSeparator).last;
    final dot = base.lastIndexOf('.');
    return dot != -1 ? base.substring(0, dot) : base;
  }

  /// Normaliza y extrae artista y título del nombre de archivo (limpiando tags de YouTube / rip)
  static Map<String, String> _parseArtistAndTitle(String filename) {
    var clean = filename
        .replaceAll(RegExp(r'\((?:Official\s*(?:Video|Audio|Music\s*Video)|Video\s*Oficial|Audio\s*Oficial)\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[(?:Official\s*(?:Video|Audio|Music\s*Video)|Video\s*Oficial|Audio\s*Oficial)\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\((?:Video\s*Lyric|Lyric\s*Video|Letra|Lyrics)\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[(?:Video\s*Lyric|Lyric\s*Video|Letra|Lyrics)\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(Audio\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[Audio\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\(\[](?:mp3|flac|wav|m4a|aac|ogg|wma)[_\-\s]*\d+k?\w*[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\(\[]\d+p[_\-\w]*[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\(\[](?:1080p|720p|480p|360p|4k|hd|hq)[_\-\w]*[\)\]]', caseSensitive: false), '')
        .trim();

    if (clean.contains(' - ')) {
      final parts = clean.split(' - ');
      final rawArtist = parts[0].trim();
      final artist = rawArtist.replaceAll('_', ', ').replaceAll(RegExp(r'\s+'), ' ').trim();
      final title = parts.sublist(1).join(' - ').trim();
      return {'artist': artist.isNotEmpty ? artist : 'Artista local', 'title': title.isNotEmpty ? title : clean};
    } else if (clean.contains('_ ')) {
      final parts = clean.split('_ ');
      final artist = parts[0].trim();
      final title = parts.sublist(1).join('_ ').trim();
      return {'artist': artist.isNotEmpty ? artist : 'Artista local', 'title': title.isNotEmpty ? title : clean};
    }

    return {'artist': 'Artista local', 'title': clean};
  }
}
