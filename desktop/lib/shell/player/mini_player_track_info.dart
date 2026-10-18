import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/player_service.dart';
import '../../core/services/lyrics_service.dart';
import '../../core/services/library_service.dart';
import '../../features/music/expanded_player_view.dart';
import '../../features/music/add_to_playlist_dialog.dart';

/// Lado izquierdo del MiniPlayer: Carátula, Título, Artista, Favorito y Atajos
class MiniPlayerTrackInfo extends StatelessWidget {
  const MiniPlayerTrackInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final track = context.select<PlayerService, Track?>((p) => p.currentTrack);
    final isResolvingStream = context.select<PlayerService, bool>(
      (p) => p.isResolvingStream,
    );
    final lyrics = context.watch<LyricsService>();

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ExpandedPlayerView.show(context),
            child: Row(
              children: [
                // Carátula / Thumbnail del Álbum
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    image: track?.artwork != null
                        ? DecorationImage(
                            image: MemoryImage(track!.artwork!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: track?.artwork == null
                      ? (track?.isRemote == true
                            ? const Icon(
                                Icons.smart_display_rounded,
                                color: Colors.white,
                                size: 26,
                              )
                            : const Icon(
                                Icons.music_note_rounded,
                                color: Colors.white,
                                size: 26,
                              ))
                      : null,
                ),
                const SizedBox(width: 14),

                // Título y Artista
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track?.title ?? 'Sin reproducción',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        track?.artist ?? 'Titofy Music',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isResolvingStream) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const SizedBox(
                              width: 9,
                              height: 9,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Conectando audio de YouTube...',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ] else if (lyrics.isLoading) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const SizedBox(
                              width: 9,
                              height: 9,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                lyrics.statusMessage.isNotEmpty
                                    ? lyrics.statusMessage
                                    : 'Buscando letra...',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Botón de Canción Favorita (Corazón)
        if (track != null)
          Consumer<LibraryService>(
            builder: (context, library, _) {
              final selectedTrack = track;
              final isFav = library.isFavorite(selectedTrack);
              return IconButton(
                tooltip: isFav
                    ? 'Quitar de favoritos'
                    : 'Añadir a canciones favoritas',
                icon: Icon(
                  isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFav ? Colors.white : Colors.white70,
                  size: 22,
                ),
                splashRadius: 20,
                onPressed: () => library.toggleFavorite(selectedTrack),
              );
            },
          ),

        // Acceso rápido para añadir a lista
        if (track != null)
          IconButton(
            tooltip: 'Añadir a lista de reproducción (Acceso rápido)',
            icon: const Icon(
              Icons.playlist_add_rounded,
              color: Colors.white,
              size: 24,
            ),
            splashRadius: 20,
            onPressed: () => AddToPlaylistDialog.show(context, track),
          ),
      ],
    );
  }
}
