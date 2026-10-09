import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/services/library_service.dart';
import '../../core/services/player_service.dart';
import '../../core/services/locale_service.dart';
import 'add_to_playlist_dialog.dart';

/// Vista de Reproducidos Recientemente (Historial persistente en SQLite)
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final loc = context.watch<LocaleService>();
    final library = context.watch<LibraryService>();
    final player = context.watch<PlayerService>();

    final tracks = library.getRecentlyPlayedTracks();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // ── Cabecera ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.accent.withOpacity(0.18),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Icono carátula
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.accent, c.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: c.accent.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.history_rounded, size: 52, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 22),

                // Información
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HISTORIAL DE REPRODUCCIÓN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: c.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        loc.t('recentlyPlayed'),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 15, color: c.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '${tracks.length} canciones reproducidas',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Botón reproducir todo
                      ElevatedButton.icon(
                        onPressed: tracks.isEmpty
                            ? null
                            : () {
                                player.playTrack(tracks.first, queue: tracks);
                              },
                        icon: const Icon(Icons.play_arrow_rounded, size: 22),
                        label: Text(loc.t('playAll')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: c.textOnPrimary,
                          disabledBackgroundColor: c.primary.withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Lista de Pistas ──────────────────────────────────────────────
          Expanded(
            child: tracks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 48, color: c.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          loc.t('emptyHistory'),
                          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'A medida que escuches canciones se registrarán automáticamente aquí',
                          style: TextStyle(color: c.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final isCurrent = player.currentTrack?.path == track.path;
                      final isPlaying = isCurrent && player.isPlaying;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isCurrent ? c.primary.withOpacity(0.08) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrent ? c.primary.withOpacity(0.3) : Colors.transparent,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          leading: SizedBox(
                            width: 36,
                            child: Center(
                              child: isPlaying
                                  ? Icon(Icons.volume_up_rounded, color: c.primary, size: 18)
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: isCurrent ? c.primary : c.textMuted,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent ? c.primary : c.textPrimary,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${track.artist}  •  ${track.album}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.textMuted, fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                track.durationFormatted,
                                style: TextStyle(color: c.textMuted, fontSize: 12),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  library.isFavorite(track) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  size: 18,
                                  color: library.isFavorite(track) ? c.primary : c.textMuted,
                                ),
                                splashRadius: 18,
                                onPressed: () => library.toggleFavorite(track),
                              ),
                              IconButton(
                                icon: Icon(Icons.playlist_add_rounded, size: 20, color: c.textMuted),
                                tooltip: loc.t('addToPlaylist'),
                                splashRadius: 18,
                                onPressed: () => AddToPlaylistDialog.show(context, track),
                              ),
                            ],
                          ),
                          onTap: () {
                            player.playTrack(track, queue: tracks);
                          },
                        ),
                      ),
                    );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
