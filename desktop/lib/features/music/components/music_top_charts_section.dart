// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/library_service.dart';
import '../../../core/services/player_service.dart';
import '../../../core/services/locale_service.dart';
import 'music_track_item.dart';

/// Sección de Pistas y Canciones (Top Charts) con soporte de localización y orden natural
class MusicTopChartsSection extends StatelessWidget {
  final List<Track> topChartTracks;
  final PlayerService player;
  final LibraryService library;
  final LocaleService loc;
  final GlobalKey playingTrackKey;
  final bool isPlayingInLibrary;
  final VoidCallback onLocatePlayingTrack;

  const MusicTopChartsSection({
    super.key,
    required this.topChartTracks,
    required this.player,
    required this.library,
    required this.loc,
    required this.playingTrackKey,
    required this.isPlayingInLibrary,
    required this.onLocatePlayingTrack,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              loc.t('topCharts'),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            Row(
              children: [
                if (topChartTracks.isNotEmpty)
                  Text(
                    '${topChartTracks.length} canciones',
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (isPlayingInLibrary) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Desplazar hasta la canción en reproducción',
                    child: InkWell(
                      onTap: onLocatePlayingTrack,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.primary.withOpacity(0.35), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.my_location_rounded, size: 13, color: c.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Localizar',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Recargar biblioteca',
                  icon: library.isScanning
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                        )
                      : Icon(Icons.sync_rounded, size: 16, color: c.textMuted),
                  splashRadius: 16,
                  onPressed: library.isScanning
                      ? null
                      : () => library.scanFolder(library.scannedFolder ?? '/home/santiago007/Música'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (topChartTracks.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.glassBorder),
            ),
            child: Center(
              child: Text(
                library.tracks.isEmpty
                    ? loc.t('noMusicFound')
                    : 'No se encontraron resultados para "${library.searchQuery}"',
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topChartTracks.length,
            itemBuilder: (context, index) {
              final track = topChartTracks[index];
              final isSelected = player.currentTrack?.path == track.path;
              return Container(
                key: isSelected ? playingTrackKey : ValueKey(track.path),
                child: MusicTrackItem(
                  track: track,
                  isSelected: isSelected,
                  player: player,
                  library: library,
                ),
              );
            },
          ),
      ],
    );
  }
}
