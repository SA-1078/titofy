import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:metadata_god/metadata_god.dart';

/// Un track de audio con sus metadatos
class Track {
  final String path;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final Uint8List? artwork;

  const Track({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.artwork,
  });
}

/// Servicio de biblioteca musical — escaneo y acceso a tracks locales
class LibraryService extends ChangeNotifier {
  List<Track> _tracks = [];
  bool _isScanning = false;
  String? _scanFolder;

  // ── Getters ────────────────────────────────────────────────────────────────
  List<Track> get tracks => _tracks;
  bool get isScanning => _isScanning;
  String? get scanFolder => _scanFolder;

  // Extensiones de audio soportadas
  static const Set<String> _audioExtensions = {
    'mp3', 'flac', 'wav', 'aac', 'm4a', 'ogg', 'opus', 'wma',
  };

  /// Abre un diálogo para elegir una carpeta y escanea su contenido
  Future<void> pickAndScan() async {
    final folder = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Selecciona tu carpeta de música',
    );
    if (folder == null) return;
    await scanFolder(folder);
  }

  /// Escanea una carpeta específica en busca de archivos de audio
  Future<void> scanFolder(String folderPath) async {
    _isScanning = true;
    _scanFolder = folderPath;
    notifyListeners();

    final newTracks = await compute(_scanFolderIsolate, folderPath);

    _tracks = newTracks;
    _isScanning = false;
    notifyListeners();
  }

  /// Función que corre en un isolate secundario para no bloquear la UI
  static Future<List<Track>> _scanFolderIsolate(String folderPath) async {
    final dir = Directory(folderPath);
    final tracks = <Track>[];

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      final ext = entity.path.split('.').last.toLowerCase();
      if (!_audioExtensions.contains(ext)) continue;

      try {
        final metadata = await MetadataGod.readMetadata(file: entity.path);
        final artworkData = metadata.picture?.data;

        tracks.add(Track(
          path: entity.path,
          title: metadata.title ?? _filenameWithoutExt(entity.path),
          artist: metadata.artist ?? 'Artista desconocido',
          album: metadata.album ?? 'Álbum desconocido',
          duration: metadata.duration != null
              ? Duration(milliseconds: (metadata.duration! * 1000).round())
              : Duration.zero,
          artwork: artworkData != null ? Uint8List.fromList(artworkData) : null,
        ));
      } catch (_) {
        // Si la lectura de metadata falla, registrar con datos mínimos
        tracks.add(Track(
          path: entity.path,
          title: _filenameWithoutExt(entity.path),
          artist: 'Artista desconocido',
          album: 'Álbum desconocido',
          duration: Duration.zero,
        ));
      }
    }

    // Ordenar alfabéticamente por artista + título
    tracks.sort((a, b) {
      final cmp = a.artist.compareTo(b.artist);
      return cmp != 0 ? cmp : a.title.compareTo(b.title);
    });

    return tracks;
  }

  static String _filenameWithoutExt(String path) {
    final base = path.split('/').last;
    final dot = base.lastIndexOf('.');
    return dot != -1 ? base.substring(0, dot) : base;
  }

  /// Formatea duración como m:ss
  static String formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
