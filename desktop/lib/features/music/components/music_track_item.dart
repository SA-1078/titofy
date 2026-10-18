import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/library_service.dart';
import '../../../core/services/player_service.dart';
import '../../../core/services/lyrics_service.dart';
import '../hybrid_lyrics_dialog.dart';
import '../add_to_playlist_dialog.dart';

/// Elemento de Pista en Top Charts con Botón Híbrido IA, favoritos y playlist
class MusicTrackItem extends StatelessWidget {
  final Track track;
  final bool isSelected;
  final PlayerService player;
  final LibraryService library;

  const MusicTrackItem({
    super.key,
    required this.track,
    required this.isSelected,
    required this.player,
    required this.library,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return GestureDetector(
      onTap: () => player.playTrack(track, playlist: library.tracks),
      onSecondaryTapDown: (details) {
        showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            details.globalPosition.dx + 1,
            details.globalPosition.dy + 1,
          ),
          color: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          items: [
            PopupMenuItem(
              onTap: () => Future.microtask(() => AddToPlaylistDialog.show(context, track)),
              child: Row(
                children: [
                  Icon(Icons.playlist_add_rounded, size: 20, color: c.primary),
                  const SizedBox(width: 10),
                  Text('Añadir a lista de reproducción', style: TextStyle(color: c.textPrimary, fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              onTap: () => Future.microtask(() => HybridLyricsDialog.show(context, track)),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 18, color: c.primary),
                  const SizedBox(width: 10),
                  Text('Sincronizar Letras (IA)', style: TextStyle(color: c.textPrimary, fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              onTap: () => library.toggleFavorite(track),
              child: Row(
                children: [
                  Icon(
                    track.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 18,
                    color: c.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    track.isFavorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
                    style: TextStyle(color: c.textPrimary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isSelected ? c.primaryGradient : null,
          color: isSelected ? null : Colors.transparent,
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: c.primary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isSelected ? Colors.white.withOpacity(0.2) : c.surface,
                border: Border.all(color: isSelected ? Colors.transparent : c.glassBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: track.artwork != null
                  ? Image.memory(track.artwork!, fit: BoxFit.cover)
                  : Center(
                      child: Icon(
                        Icons.music_note_rounded,
                        size: 18,
                        color: isSelected ? Colors.white : c.textSecondary,
                      ),
                    ),
            ),
            const SizedBox(width: 14),

            // Título y Artista
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : c.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artist,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white.withOpacity(0.85) : c.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Duración
            Text(
              track.durationFormatted,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white.withOpacity(0.9) : c.textMuted,
              ),
            ),

            const SizedBox(width: 8),

            // Botón Letras / Modo Híbrido
            IconButton(
              tooltip: LyricsService.hasExistingLyrics(track.path, artist: track.artist, title: track.title)
                  ? 'Letra sincronizada disponible (.lrc)'
                  : 'Sincronizar Letras con IA (Modo Híbrido)',
              icon: Icon(
                LyricsService.hasExistingLyrics(track.path, artist: track.artist, title: track.title)
                    ? Icons.lyrics_rounded
                    : Icons.auto_awesome_rounded,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : (LyricsService.hasExistingLyrics(track.path, artist: track.artist, title: track.title)
                        ? const Color(0xFF39FF14)
                        : c.primary),
              ),
              splashRadius: 16,
              onPressed: () => HybridLyricsDialog.show(context, track),
            ),

            // Corazón (Favorito)
            IconButton(
              icon: Icon(
                track.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : (track.isFavorite ? c.primary : c.textMuted),
              ),
              splashRadius: 16,
              onPressed: () => library.toggleFavorite(track),
            ),

            // Añadir a Playlist
            IconButton(
              icon: Icon(
                Icons.playlist_add_rounded,
                size: 20,
                color: isSelected ? Colors.white : c.textSecondary,
              ),
              tooltip: 'Añadir a lista de reproducción',
              splashRadius: 18,
              onPressed: () => AddToPlaylistDialog.show(context, track),
            ),
          ],
        ),
      ),
    );
  }
}
