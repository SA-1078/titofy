import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/player_service.dart';
import '../../../core/services/lyrics_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/library_service.dart';
import '../../visualizer/rhythm_visualizer_controller.dart';
import '../../visualizer/rhythm_symmetric_painter.dart';
import '../../visualizer/rhythm_radial_painter.dart';
import 'rhythm_style_selector.dart';
import '../../../core/services/windows/windows_performance.dart';

/// Vista de Modo Ritmo interactiva con soporte para ambos estilos:
/// 1. Barras Simétricas bombeando en bloque al beat
/// 2. Ondas de Choque Radiales con portada central pulsante en 360°
class ExpandedRhythmView extends StatefulWidget {
  final PlayerService player;
  final LyricsService lyrics;

  const ExpandedRhythmView({
    super.key,
    required this.player,
    required this.lyrics,
  });

  @override
  State<ExpandedRhythmView> createState() => _ExpandedRhythmViewState();
}

class _ExpandedRhythmViewState extends State<ExpandedRhythmView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final RhythmVisualizerController _rhythmController;
  Duration _lastTick = Duration.zero;
  bool _lastPlaying = false;
  String? _analysisTrackPath;
  final bool _showFloatingLyrics = true;

  @override
  void initState() {
    super.initState();
    _rhythmController = RhythmVisualizerController();

    // Cargar estilo preferido desde SQLite
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final db = context.read<DatabaseService>();
      final savedStyle = db.getSetting('rhythm_visualizer_style');
      if (savedStyle != null) {
        for (final s in RhythmVisualizerStyle.values) {
          if (s.name == savedStyle) {
            _rhythmController.setStyle(s);
            break;
          }
        }
      }
    });

    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      if (_lastTick != Duration.zero) {
        final rawDt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
        final dt = WindowsPerformance.clampDelta(rawDt);
        final c = context.colors;
        final playing = widget.player.isPlaying;
        final trackPath = widget.player.currentTrack?.path;
        if (trackPath != null && trackPath != _analysisTrackPath) {
          _analysisTrackPath = trackPath;
          widget.player.prepareAudioBeatProfile();
        }
        if (playing || _lastPlaying) {
          _rhythmController.updateFrame(
            playing,
            dt,
            playbackPositionMs: widget.player.position.inMilliseconds,
            accentColor: c.primary,
            audioProfile: widget.player.audioBeatProfile,
          );
        }
        _lastPlaying = playing;
      }
      _lastTick = elapsed;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _rhythmController.dispose();
    super.dispose();
  }

  void _onSelectStyle(RhythmVisualizerStyle style) {
    setState(() {
      _rhythmController.setStyle(style);
    });
    context.read<DatabaseService>().setSetting(
      'rhythm_visualizer_style',
      style.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = c.isDark;
    final player = widget.player;
    final lyrics = widget.lyrics;
    const centerRadius = 96.0;
    final cover = RepaintBoundary(
      child: Container(
        width: centerRadius * 2,
        height: centerRadius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: c.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: c.primary.withOpacity(0.40),
              blurRadius: WindowsPerformance.shouldSimplifyDynamicEffects ? 12 : 28,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: player.currentArtwork != null
            ? Image.memory(player.currentArtwork!, fit: BoxFit.cover)
            : const Center(
                child: Icon(
                  Icons.music_note_rounded,
                  size: 54,
                  color: Colors.white,
                ),
              ),
      ),
    );

    return Stack(
      children: [
        // ── 1. Fondo Visualizador Activo (Simétrico o Radial) ───────────────
        Positioned.fill(
          child: RepaintBoundary(
            child:
                _rhythmController.style == RhythmVisualizerStyle.symmetricBars
                ? CustomPaint(
                    painter: RhythmSymmetricPainter.fromController(
                      value: _rhythmController,
                      primaryColor: c.primary,
                      isDark: isDark,
                    ),
                    size: Size.infinite,
                  )
                : Stack(
                    // Modo Radial: El radio de la portada central es ~100px
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        painter: RhythmRadialPainter.fromController(
                          value: _rhythmController,
                          primaryColor: c.primary,
                          centerRadius: centerRadius,
                          isDark: isDark,
                        ),
                        size: Size.infinite,
                      ),
                      // Portada Central Pulsante con física elástica (Bounce)
                      AnimatedBuilder(
                        animation: _rhythmController,
                        child: cover,
                        builder: (context, child) => Transform.scale(
                          scale: 1.0 + (_rhythmController.bassPulse * 0.10),
                          child: child,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        // ── 2. Selector de Estilo Rítmico (Barras Simétricas vs Onda Radial) ─
        Positioned(
          top: 18,
          right: 28,
          child: RhythmStyleSelector(
            currentStyle: _rhythmController.style,
            onStyleSelected: _onSelectStyle,
          ),
        ),

        // ── 3. Metadatos de la Pista (Esquina Superior Izquierda) ────────────
        Positioned(
          top: 18,
          left: 28,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: c.surface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 16, color: c.primary),
                const SizedBox(width: 8),
                Text(
                  player.currentTrack != null
                      ? '${player.currentTitle} · ${player.currentArtist}'
                      : 'Modo Ritmo Activo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                if (player.currentTrack != null) ...[
                  const SizedBox(width: 8),
                  Consumer<LibraryService>(
                    builder: (context, lib, _) {
                      final isFav = lib.isFavorite(player.currentTrack!);
                      return InkWell(
                        onTap: () => lib.toggleFavorite(player.currentTrack!),
                        child: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 15,
                          color: isFav ? c.primary : c.textMuted,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── 4. Letra Flotante Activa (Parte Inferior Central) ────────────────
        if (_showFloatingLyrics && lyrics.currentLine != null)
          Positioned(
            bottom: 30,
            left: 40,
            right: 40,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: c.surface.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.primary.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: c.primary.withOpacity(0.25),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Text(
                  lyrics.currentLine!.text,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
