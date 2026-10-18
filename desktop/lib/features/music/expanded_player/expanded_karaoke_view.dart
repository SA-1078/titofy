import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/player_service.dart';
import '../../../core/services/lyrics_service.dart';
import '../../../core/services/library_service.dart';
import '../../visualizer/spectrum_controller.dart';
import '../../visualizer/spectrum_painter.dart';

/// Vista interactiva de Karaoke Continuo con portadas, sincronización y fallback al espectro
class ExpandedKaraokeView extends StatelessWidget {
  final PlayerService player;
  final LyricsService lyrics;
  final SpectrumController spectrumController;
  final ScrollController scrollCtrl;
  final bool forceShowLyrics;
  final bool forceShowVisualizer;
  final VoidCallback onToggleForceLyrics;
  final VoidCallback onToggleForceVisualizer;

  const ExpandedKaraokeView({
    super.key,
    required this.player,
    required this.lyrics,
    required this.spectrumController,
    required this.scrollCtrl,
    required this.forceShowLyrics,
    required this.forceShowVisualizer,
    required this.onToggleForceLyrics,
    required this.onToggleForceVisualizer,
  });

  bool _isInstrumental(List<LyricLine> lines) {
    if (lines.isEmpty) return true;
    final vocalLines = lines.where((l) {
      final t = l.text.trim().toLowerCase();
      return t.isNotEmpty &&
          !t.startsWith('(instrumental') &&
          !t.startsWith('[instrumental') &&
          t != 'instrumental' &&
          t != '(música)' &&
          t != '(musica)' &&
          t != '(solo)' &&
          !t.startsWith('transcripción') &&
          !t.startsWith('transcripcion');
    });
    return vocalLines.length <= 1;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = c.isDark;

    // Verificar si las letras cargadas en memoria corresponden a la pista actual
    final bool isMatchingTrack = lyrics.loadedAudioPath == null ||
        player.currentTrack == null ||
        lyrics.loadedAudioPath == player.currentTrack!.path;
    final displayLines = isMatchingTrack ? lyrics.lines : const <LyricLine>[];
    final displayCurrentIndex = isMatchingTrack ? lyrics.currentIndex : -1;

    if (lyrics.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.primary.withOpacity(0.12),
                border: Border.all(color: c.primary.withOpacity(0.35)),
              ),
              child: CircularProgressIndicator(strokeWidth: 3, color: c.primary),
            ),
            const SizedBox(height: 20),
            Text(
              lyrics.statusMessage.isNotEmpty ? lyrics.statusMessage : 'Buscando letras...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Consultando proveedor online (LRCLIB) y motores locales de IA...',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
          ],
        ),
      );
    }

    final isInstrumental = _isInstrumental(displayLines);
    final showVisualizer = (isInstrumental && !forceShowLyrics) || forceShowVisualizer;

    if (player.currentTrack == null || player.currentTitle.isEmpty || player.currentTitle == 'Sin reproducción') {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surface,
                border: Border.all(color: c.glassBorder),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20),
                ],
              ),
              child: Icon(Icons.headphones_rounded, size: 40, color: c.textMuted.withOpacity(0.6)),
            ),
            const SizedBox(height: 20),
            Text(
              'Ninguna pista en reproducción',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Selecciona una canción en tu biblioteca para activar el karaoke y las visualizaciones',
              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Columna Izquierda: Portada y metadatos
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: c.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: c.primary.withOpacity(0.35),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: player.currentArtwork != null
                        ? Image.memory(player.currentArtwork!, fit: BoxFit.cover)
                        : const Center(child: Icon(Icons.music_note_rounded, size: 70, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Column(
                        children: [
                          Text(
                            player.currentTitle,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            player.currentArtist,
                            style: TextStyle(fontSize: 13, color: c.textSecondary, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    if (player.currentTrack != null)
                      Consumer<LibraryService>(
                        builder: (context, lib, _) {
                          final isFav = lib.isFavorite(player.currentTrack!);
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: IconButton(
                              tooltip: isFav ? 'Quitar de favoritos' : 'Añadir a canciones favoritas',
                              icon: Icon(
                                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: isFav ? c.primary : c.textMuted,
                                size: 24,
                              ),
                              splashRadius: 20,
                              onPressed: () => lib.toggleFavorite(player.currentTrack!),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                if (isInstrumental) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.primary.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.graphic_eq_rounded, size: 14, color: c.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Pista Instrumental · Ritmo Activo',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Columna Derecha: Visualizador FFT o Lista de Letras sincronizadas
        if (showVisualizer)
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 36, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.equalizer_rounded, size: 18, color: c.primary),
                          const SizedBox(width: 8),
                          Text(
                            isInstrumental ? 'Visualizador de Ritmo (Sin letra vocal)' : 'Visualizador de Ritmo',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary),
                          ),
                        ],
                      ),
                      if (displayLines.isNotEmpty)
                        TextButton.icon(
                          icon: Icon(Icons.lyrics_rounded, size: 15, color: c.primary),
                          label: Text('Ver Texto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.primary)),
                          onPressed: onToggleForceLyrics,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.surface.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.glassBorder.withOpacity(0.3)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: SpectrumPainter.fromController(spectrumController),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const itemHeight = 56.0;
                      final halfViewport = constraints.maxHeight / 2;
                      final verticalPadding = (halfViewport - (itemHeight / 2)).clamp(40.0, 800.0);

                      return ListView.builder(
                        controller: scrollCtrl,
                        itemExtent: itemHeight,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: verticalPadding,
                        ),
                        physics: const BouncingScrollPhysics(),
                        itemCount: displayLines.length,
                        itemBuilder: (context, index) {
                          final line = displayLines[index];
                          final delta = index - displayCurrentIndex;
                          final isActive = delta == 0;

                          double opacity;
                          double fontSize;
                          FontWeight fontWeight;
                          Color textColor;

                          if (isActive) {
                            opacity = 1.0;
                            fontSize = 24.0;
                            fontWeight = FontWeight.w900;
                            textColor = c.primary;
                          } else if (delta < 0) {
                            final d = -delta;
                            textColor = c.textPrimary;
                            if (d == 1) {
                              opacity = isDark ? 0.65 : 0.75; fontSize = 17.0; fontWeight = FontWeight.w600;
                            } else if (d == 2) {
                              opacity = isDark ? 0.50 : 0.60; fontSize = 16.0; fontWeight = FontWeight.w500;
                            } else if (d == 3) {
                              opacity = isDark ? 0.38 : 0.48; fontSize = 15.0; fontWeight = FontWeight.w500;
                            } else {
                              opacity = isDark ? 0.15 : 0.25; fontSize = 13.0; fontWeight = FontWeight.w400;
                            }
                          } else {
                            final d = delta;
                            textColor = c.textPrimary;
                            if (d == 1) {
                              opacity = isDark ? 0.70 : 0.80; fontSize = 17.0; fontWeight = FontWeight.w600;
                            } else if (d == 2) {
                              opacity = isDark ? 0.55 : 0.65; fontSize = 16.0; fontWeight = FontWeight.w500;
                            } else if (d == 3) {
                              opacity = isDark ? 0.42 : 0.52; fontSize = 15.0; fontWeight = FontWeight.w500;
                            } else {
                              opacity = isDark ? 0.15 : 0.25; fontSize = 13.0; fontWeight = FontWeight.w400;
                            }
                          }

                          return GestureDetector(
                            onTap: () => player.seekTo(line.time),
                            child: SizedBox(
                              height: itemHeight,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeInOutCubic,
                                  padding: EdgeInsets.symmetric(
                                    vertical: isActive ? 8 : 4,
                                    horizontal: isActive ? 16 : 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive ? c.primary.withOpacity(0.18) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                    border: isActive
                                        ? Border.all(color: c.primary.withOpacity(0.55), width: 1.5)
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      if (isActive) ...[
                                        Icon(Icons.graphic_eq_rounded, color: c.primary, size: 18),
                                        const SizedBox(width: 10),
                                      ],
                                      Expanded(
                                        child: AnimatedDefaultTextStyle(
                                          duration: const Duration(milliseconds: 500),
                                          curve: Curves.easeInOutCubic,
                                          style: TextStyle(
                                            fontSize: fontSize,
                                            fontWeight: fontWeight,
                                            color: textColor.withOpacity(opacity),
                                          ),
                                          child: Text(
                                            line.text,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 20,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Ajusta las marcas de tiempo de esta letra escuchando tu archivo de audio con IA (Forced Alignment)',
                        child: TextButton.icon(
                          icon: Icon(Icons.tune_rounded, size: 15, color: c.primary),
                          label: Text('Alinear con Audio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.primary)),
                          onPressed: lyrics.isLoading
                              ? null
                              : () async {
                                  final ok = await lyrics.realignWithAudio();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok
                                            ? 'Letra alineada con el audio local mediante IA.'
                                            : 'No se pudo alinear la letra con el audio local.'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        icon: Icon(Icons.equalizer_rounded, size: 15, color: c.primary),
                        label: Text('Ver Visualizador', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.primary)),
                        onPressed: onToggleForceVisualizer,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
