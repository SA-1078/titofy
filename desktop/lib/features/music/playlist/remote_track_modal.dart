import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/player_service.dart';
import '../../../core/services/library_service.dart';
import '../hybrid_lyrics_dialog.dart';

/// Modal informativo y de acciones para pistas remotas de YouTube
class RemoteTrackModal {
  static void show(
    BuildContext context, {
    required Track track,
    required List<Track> playlist,
    required bool isDownloading,
    required VoidCallback onDownload,
  }) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.smart_display_rounded, color: Colors.redAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        track.artist,
                        style: TextStyle(color: c.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.surfaceLight),
              ),
              child: Row(
                children: [
                  Icon(Icons.stream_rounded, color: c.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pista disponible para reproducción en streaming instantáneo desde YouTube.',
                      style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.read<PlayerService>().playTrack(track, queue: playlist);
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Reproducir ahora'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: c.textOnPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isDownloading
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            onDownload();
                          },
                    icon: isDownloading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download_rounded, size: 18),
                    label: Text(isDownloading ? 'Descargando...' : 'Descargar audio'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.textPrimary,
                      side: BorderSide(color: c.primary.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  HybridLyricsDialog.show(context, track);
                },
                icon: const Icon(Icons.lyrics_rounded, size: 16),
                label: const Text('Buscar / Ver letras'),
                style: TextButton.styleFrom(foregroundColor: c.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
