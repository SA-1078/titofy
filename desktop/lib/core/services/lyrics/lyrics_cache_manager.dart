// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/lyric_line.dart';

/// Administrador de caché y resolución en disco para archivos de letras sincronizadas (.lrc)
class LyricsCacheManager {
  /// Busca si ya existe un archivo .lrc en las carpetas estándar de la CLI o del sistema
  static File? findExistingLrc(String audioPath, {String? artist, String? title}) {
    final file = File(audioPath);
    final audioDir = file.parent.path;
    final filename = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : audioPath.split(Platform.pathSeparator).last;
    final nameWithoutExt = filename.contains('.')
        ? filename.substring(0, filename.lastIndexOf('.'))
        : filename;

    final sysTemp = Directory.systemTemp.path;
    final envTemp = Platform.environment['TEMP'];
    final envLocal = Platform.environment['LOCALAPPDATA'];

    final candidateDirs = [
      '$sysTemp/cli/lrc',
      if (envTemp != null) '$envTemp/cli/lrc',
      if (envLocal != null) '$envLocal/Temp/cli/lrc',
      '$sysTemp/titofy/lrc',
      '../cli/lrc',
      'cli/lrc',
      '../backend/lrc',
      'backend/lrc',
      '$audioDir/lyrics',
      '$audioDir/lrc',
      '/home/santiago007/Documentos/titofy/cli/lrc',
      '/home/santiago007/Documentos/titofy/backend/lrc',
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
    final fuzzyDirs = [
      '$sysTemp/cli/lrc',
      if (envTemp != null) '$envTemp/cli/lrc',
      if (envLocal != null) '$envLocal/Temp/cli/lrc',
      '../cli/lrc',
      'cli/lrc',
      '$audioDir/lyrics',
      '/home/santiago007/Documentos/titofy/cli/lrc',
    ];

    for (final cliDir in fuzzyDirs) {
      final d = Directory(cliDir);
      if (d.existsSync()) {
        final cleanBase = nameWithoutExt.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        final cleanArtist = (artist ?? '').toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        final cleanTitle = (title ?? '').toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        try {
          for (final entity in d.listSync()) {
            if (entity is File && entity.path.toLowerCase().endsWith('.lrc')) {
              final fName = entity.uri.pathSegments.last.toLowerCase();
              final cleanFName = fName.substring(0, fName.lastIndexOf('.')).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

              // Coincidencia exacta del nombre base
              if (cleanBase.isNotEmpty && cleanFName == cleanBase) {
                if (entity.lengthSync() > 0) return entity;
              }
              // Coincidencia de artista y título simultáneos
              if (cleanArtist.length >= 3 && cleanTitle.length >= 3) {
                if (cleanFName.contains(cleanArtist) && cleanFName.contains(cleanTitle)) {
                  if (entity.lengthSync() > 0) return entity;
                }
              }
              // Coincidencia estricta de título
              if (cleanTitle.length >= 4 && cleanFName == cleanTitle) {
                if (entity.lengthSync() > 0) return entity;
              }
            }
          }
        } catch (_) {}
      }
    }

    return null;
  }

  /// Retorna si el archivo de audio ya cuenta con un archivo .lrc utilizable
  static bool hasExistingLyrics(String audioPath, {String? artist, String? title}) {
    return findExistingLrc(audioPath, artist: artist, title: title) != null;
  }

  /// Limpia archivos .lrc residuales en la carpeta de música del usuario
  static void cleanStrayMusicLrc(String audioPath) {
    final dotIndex = audioPath.lastIndexOf('.');
    if (dotIndex != -1) {
      final strayMusicLrc = File('${audioPath.substring(0, dotIndex)}.lrc');
      if (strayMusicLrc.existsSync()) {
        try {
          strayMusicLrc.deleteSync();
          debugPrint('[LyricsCacheManager] Eliminado .lrc residual en carpeta de música: ${strayMusicLrc.path}');
        } catch (_) {}
      }
    }
  }

  /// Guarda una letra sincronizada en la caché interna para que su carga futura sea instantánea (<1ms)
  static void saveToCache(
    String audioPath,
    String? artist,
    String? title,
    List<LyricLine> lines, {
    String? by,
  }) {
    if (lines.isEmpty) return;
    try {
      final file = File(audioPath);
      final filename = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : audioPath.split(Platform.pathSeparator).last;
      final nameWithoutExt = filename.contains('.')
          ? filename.substring(0, filename.lastIndexOf('.'))
          : filename;

      final sysTemp = Directory.systemTemp.path;
      final targetDirs = [
        Directory('/home/santiago007/Documentos/titofy/cli/lrc'),
        Directory('$sysTemp/titofy/lrc'),
      ];

      final buffer = StringBuffer();
      if (title != null) buffer.writeln('[ti:$title]');
      if (artist != null) buffer.writeln('[ar:$artist]');
      if (by != null) buffer.writeln('[by:$by]');
      for (final l in lines) {
        final totalMs = l.time.inMilliseconds;
        final minutes = (totalMs ~/ 60000).toString().padLeft(2, '0');
        final seconds = ((totalMs % 60000) ~/ 1000).toString().padLeft(2, '0');
        final hundredths = ((totalMs % 1000) ~/ 10).toString().padLeft(2, '0');
        buffer.writeln('[$minutes:$seconds.$hundredths]${l.text}');
      }
      final lrcContent = buffer.toString();

      for (final dir in targetDirs) {
        try {
          if (!dir.existsSync()) dir.createSync(recursive: true);
          final targetFile = File('${dir.path}/$nameWithoutExt.lrc');
          targetFile.writeAsStringSync(lrcContent, flush: true);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[LyricsCacheManager] Error al guardar caché .lrc: $e');
    }
  }
}
