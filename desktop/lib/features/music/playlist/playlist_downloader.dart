// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/library_service.dart';
import '../../../core/services/notification_service.dart';

/// Coordinador de descargas de YouTube para pistas remotas en Playlists
class PlaylistDownloader {
  /// Descarga una pista remota individual
  static Future<void> downloadSingleTrack(
    BuildContext context,
    Track track, {
    required Function(String videoId) onStart,
    required Function(String videoId) onFinish,
  }) async {
    final videoId = track.remoteId;
    if (videoId == null) return;

    onStart(videoId);

    final api = context.read<ApiService>();
    final db = context.read<DatabaseService>();
    final library = context.read<LibraryService>();
    final notifs = context.read<NotificationService>();
    final targetFolder = library.scannedFolder ?? '/home/santiago007/Música';

    try {
      final res = await api.downloadYouTubeTrack(
        videoId: videoId,
        title: track.title,
        artist: track.artist,
        targetFolder: targetFolder,
      );

      if (res != null && res['file_path'] != null) {
        final localPath = res['file_path'] as String;
        final durationMs = (res['duration_ms'] as num?)?.toInt() ?? track.duration.inMilliseconds;

        db.updateTrackLocalPath(
          oldRemotePath: track.path,
          newLocalPath: localPath,
          durationMs: durationMs,
          title: track.title,
          artist: track.artist,
          album: track.album,
        );

        final newTrack = Track(
          path: localPath,
          title: track.title,
          artist: track.artist,
          album: track.album,
          duration: Duration(milliseconds: durationMs),
          isFavorite: track.isFavorite,
        );
        library.replaceRemoteTrack(oldRemotePath: track.path, newTrack: newTrack);
        await library.scanFolder(targetFolder);

        notifs.add(
          title: 'Canción descargada',
          message: '"${track.title}" guardada en $targetFolder',
          type: NotificationType.download,
          filePath: localPath,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Descargada: "${track.title}"', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Carpeta: $targetFolder', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar "${track.title}": $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      onFinish(videoId);
    }
  }

  /// Descarga un lote de canciones remotas pendientes
  static Future<void> downloadAllPendingTracks(
    BuildContext context,
    List<Track> remoteTracks, {
    required Function(int total) onStart,
    required Function(String videoId, int count) onTrackComplete,
    required VoidCallback onFinish,
  }) async {
    if (remoteTracks.isEmpty) return;

    onStart(remoteTracks.length);

    final api = context.read<ApiService>();
    final db = context.read<DatabaseService>();
    final library = context.read<LibraryService>();
    final notifs = context.read<NotificationService>();
    final targetFolder = library.scannedFolder ?? '/home/santiago007/Música';

    int downloadedCount = 0;

    for (final track in remoteTracks) {
      if (!context.mounted) break;
      final videoId = track.remoteId;
      if (videoId == null) continue;

      try {
        final res = await api.downloadYouTubeTrack(
          videoId: videoId,
          title: track.title,
          artist: track.artist,
          targetFolder: targetFolder,
        );

        if (res != null && res['file_path'] != null) {
          final localPath = res['file_path'] as String;
          final durationMs = (res['duration_ms'] as num?)?.toInt() ?? track.duration.inMilliseconds;

          db.updateTrackLocalPath(
            oldRemotePath: track.path,
            newLocalPath: localPath,
            durationMs: durationMs,
            title: track.title,
            artist: track.artist,
            album: track.album,
          );

          final newTrack = Track(
            path: localPath,
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: Duration(milliseconds: durationMs),
            isFavorite: track.isFavorite,
          );
          library.replaceRemoteTrack(oldRemotePath: track.path, newTrack: newTrack);
        }
      } catch (e) {
        debugPrint('[PlaylistDownloader] Error descargando ${track.title}: $e');
      } finally {
        downloadedCount++;
        onTrackComplete(videoId, downloadedCount);
      }
    }

    await library.scanFolder(targetFolder);

    notifs.add(
      title: 'Lote descargado',
      message: 'Se descargaron $downloadedCount canciones en $targetFolder',
      type: NotificationType.download,
    );

    if (context.mounted) {
      onFinish();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Descarga completada en: $targetFolder'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
