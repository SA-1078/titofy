import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/colors.dart';
import '../core/services/player_service.dart';
import '../core/services/library_service.dart';
import '../core/services/lyrics_service.dart';
import '../features/music/lyrics_overlay.dart';
import '../features/music/expanded_player_view.dart';
import '../features/music/add_to_playlist_dialog.dart';
import '../features/visualizer/spectrum_controller.dart';

/// Reproductor inferior con Barra de Progreso Interactiva
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  String _formatTime(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final lyrics = context.watch<LyricsService>();
    final c = context.colors;

    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        gradient: c.playerGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: c.primary.withOpacity(0.45),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── LADO IZQUIERDO: Portada, Título, Artista y Estado ────────────────
          Expanded(
            flex: 3,
            child: Row(
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
                            image: player.currentArtwork != null
                                ? DecorationImage(
                                    image: MemoryImage(player.currentArtwork!),
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
                          child: player.currentArtwork == null
                              ? const Icon(Icons.music_note_rounded, color: Colors.white, size: 26)
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
                                player.currentTitle,
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
                                player.currentArtist,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (lyrics.isLoading) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 9,
                                      height: 9,
                                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white70),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        lyrics.statusMessage.isNotEmpty ? lyrics.statusMessage : 'Buscando letra...',
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
                if (player.currentTrack != null)
                  Consumer<LibraryService>(
                    builder: (context, library, _) {
                      final track = player.currentTrack!;
                      final isFav = library.isFavorite(track);
                      return IconButton(
                        tooltip: isFav ? 'Quitar de favoritos' : 'Añadir a canciones favoritas',
                        icon: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? Colors.white : Colors.white70,
                          size: 22,
                        ),
                        splashRadius: 20,
                        onPressed: () => library.toggleFavorite(track),
                      );
                    },
                  ),

                // Acceso rápido / Atajo para añadir la canción en reproducción a una lista
                if (player.currentTrack != null)
                  IconButton(
                    tooltip: 'Añadir a lista de reproducción (Acceso rápido)',
                    icon: const Icon(
                      Icons.playlist_add_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    splashRadius: 20,
                    onPressed: () => AddToPlaylistDialog.show(context, player.currentTrack!),
                  ),
              ],
            ),
          ),

          // ── CENTRO: Barra de Progreso de la Música Interactiva ───────────────
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    _formatTime(player.position),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HoverProgressBar(
                      position: player.position,
                      duration: player.duration,
                      onSeek: (target) => player.seekTo(target),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatTime(player.duration),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── LADO DERECHO: Controles, Botones y Letras ─────────────────────────
          Expanded(
            flex: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Anterior
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 24),
                  splashRadius: 20,
                  onPressed: () => player.previous(),
                ),

                // Play / Pausa en botón circular blanco
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: c.primary,
                      size: 22,
                    ),
                    onPressed: () => player.playPause(),
                  ),
                ),

                // Siguiente
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 24),
                  splashRadius: 20,
                  onPressed: () => player.next(),
                ),

                const SizedBox(width: 8),

                // Botón de Letras / Karaoke
                IconButton(
                  tooltip: 'Letras sincronizadas (Karaoke)',
                  icon: Icon(
                    lyrics.lines.isNotEmpty ? Icons.lyrics_rounded : Icons.lyrics_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  splashRadius: 20,
                  onPressed: () => LyricsOverlay.show(context),
                ),

                // Volumen
                PopupMenuButton<double>(
                  tooltip: 'Volumen',
                  icon: Icon(
                    player.volume == 0
                        ? Icons.volume_off_rounded
                        : player.volume < 0.5
                            ? Icons.volume_down_rounded
                            : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: false,
                      child: StatefulBuilder(
                        builder: (context, setState) => Row(
                          children: [
                            Icon(Icons.volume_down_rounded, color: c.primary, size: 20),
                            Expanded(
                              child: Slider(
                                value: player.volume,
                                min: 0.0,
                                max: 1.0,
                                activeColor: c.primary,
                                onChanged: (v) {
                                  player.setVolume(v);
                                  setState(() {});
                                },
                              ),
                            ),
                            Text(
                              '${(player.volume * 100).round()}%',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Botón dedicado para el Visualizador de Espectro Neón Desktop
                IconButton(
                  tooltip: 'Visualizador de Espectro Neón Desktop',
                  icon: const Icon(
                    Icons.graphic_eq_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  splashRadius: 20,
                  onPressed: () => ExpandedPlayerView.show(context, initialMode: VisualizerMode.spectrumOnly),
                ),

                // Botón de Expansión a Pantalla Completa
                IconButton(
                  tooltip: 'Abrir Reproductor Completo (Karaoke / Espectro / Híbrido)',
                  icon: const Icon(
                    Icons.open_in_full_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  splashRadius: 20,
                  onPressed: () => ExpandedPlayerView.show(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de progreso interactiva con animación hover y target de clic centrado
class _HoverProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const _HoverProgressBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  State<_HoverProgressBar> createState() => _HoverProgressBarState();
}

class _HoverProgressBarState extends State<_HoverProgressBar> {
  bool _isHovered = false;
  double? _dragRatio;

  void _seekFromPosition(double localDx, double totalWidth) {
    if (totalWidth <= 0 || widget.duration.inMilliseconds <= 0) return;
    final ratio = (localDx / totalWidth).clamp(0.0, 1.0);
    final targetMs = (ratio * widget.duration.inMilliseconds).toInt();
    widget.onSeek(Duration(milliseconds: targetMs));
  }

  @override
  Widget build(BuildContext context) {
    final durMs = widget.duration.inMilliseconds;
    final posMs = widget.position.inMilliseconds;
    final currentRatio = durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;
    final displayRatio = _dragRatio ?? currentRatio;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _dragRatio = null;
      }),
      cursor: SystemMouseCursors.click,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              _seekFromPosition(details.localPosition.dx, width);
            },
            onHorizontalDragStart: (details) {
              final r = (details.localPosition.dx / width).clamp(0.0, 1.0);
              setState(() => _dragRatio = r);
            },
            onHorizontalDragUpdate: (details) {
              final r = (details.localPosition.dx / width).clamp(0.0, 1.0);
              setState(() => _dragRatio = r);
            },
            onHorizontalDragEnd: (details) {
              if (_dragRatio != null) {
                final targetMs = (_dragRatio! * durMs).toInt();
                widget.onSeek(Duration(milliseconds: targetMs));
                setState(() => _dragRatio = null);
              }
            },
            child: Container(
              height: 36, // Hit-target amplio, centrado verticalmente
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Pista inactiva
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    height: _isHovered ? 6.0 : 4.0,
                    width: width,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  // Pista activa con degradado blanco brillante
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    height: _isHovered ? 6.0 : 4.0,
                    width: (width * displayRatio).clamp(0.0, width),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        if (_isHovered)
                          BoxShadow(
                            color: Colors.white.withOpacity(0.55),
                            blurRadius: 8,
                          ),
                      ],
                    ),
                  ),
                  // Indicador/Thumb luminoso visible al hacer hover
                  if (_isHovered)
                    Positioned(
                      left: (width * displayRatio - 6).clamp(0.0, width > 12 ? width - 12 : 0.0),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
