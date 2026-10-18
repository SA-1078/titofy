// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../core/theme/colors.dart';
import '../../core/services/player_service.dart';
import '../../core/services/lyrics_service.dart';
import '../../core/services/database_service.dart';
import '../visualizer/spectrum_controller.dart';
import '../../shell/window_controls.dart';

import 'expanded_player/expanded_playback_controls.dart';
import 'expanded_player/expanded_spectrum_view.dart';
import 'expanded_player/expanded_rhythm_view.dart';
import 'expanded_player/expanded_karaoke_view.dart';
import 'expanded_player/expanded_cli_spectrum.dart';
import 'expanded_player/expanded_cli_classic.dart';

export 'expanded_player/expanded_playback_controls.dart';
export 'expanded_player/expanded_spectrum_view.dart';
export 'expanded_player/spectrum_style_selector.dart';
export 'expanded_player/expanded_rhythm_view.dart';
export 'expanded_player/expanded_karaoke_view.dart';
export 'expanded_player/expanded_cli_spectrum.dart';
export 'expanded_player/expanded_cli_classic.dart';

/// Reproductor Inmersivo con Modos Múltiples (Karaoke Continuo, Modo Clásico CLI y Espectro Neón FFT)
class ExpandedPlayerView extends StatefulWidget {
  final bool isEmbedded;
  final VisualizerMode? initialMode;
  const ExpandedPlayerView({
    super.key,
    this.isEmbedded = false,
    this.initialMode,
  });

  static void show(BuildContext context, {VisualizerMode? initialMode}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ExpandedPlayer',
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, anim1, anim2) =>
          ExpandedPlayerView(isEmbedded: false, initialMode: initialMode),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  @override
  State<ExpandedPlayerView> createState() => _ExpandedPlayerViewState();
}

class _ExpandedPlayerViewState extends State<ExpandedPlayerView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final SpectrumController _spectrumController;
  final ScrollController _lyricsScrollCtrl = ScrollController();
  Duration _lastTick = Duration.zero;
  bool _lastPlaying = false;
  int _lastAutoScrolled = -1;
  int _scheduledAutoScroll = -1;

  bool _forceShowLyrics = false;
  bool _forceShowVisualizer = false;

  @override
  void initState() {
    super.initState();
    _spectrumController = SpectrumController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final db = context.read<DatabaseService>();
      final savedTheme = db.getSetting('visualizer_theme');
      if (savedTheme != null) {
        for (final t in VisualizerTheme.values) {
          if (t.name == savedTheme) {
            _spectrumController.setTheme(t);
            break;
          }
        }
      }

      final savedMode = db.getSetting('visualizer_mode');
      if (savedMode != null && widget.initialMode == null) {
        if (savedMode == 'hybrid') {
          _spectrumController.setMode(VisualizerMode.spectrumOnly);
          db.setSetting('visualizer_mode', VisualizerMode.spectrumOnly.name);
          db.setSetting('spectrum_show_lyrics', 'true');
        } else {
          for (final m in VisualizerMode.values) {
            if (m.name == savedMode) {
              _spectrumController.setMode(m);
              break;
            }
          }
        }
      }
    });

    if (widget.initialMode != null) {
      _spectrumController.setMode(widget.initialMode!);
    }

    _ticker = createTicker((elapsed) {
      if (_lastTick != Duration.zero) {
        final dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
        final player = context.read<PlayerService>();
        final playing = player.isPlaying;
        // En pausa basta con un frame de decaimiento; después no hay trabajo
        // visual que recalcular. El modo Ritmo tiene su propio ticker;
        // Karaoke y Letras CLI tampoco consumen este controlador.
        final modeUsesSpectrum =
            _spectrumController.mode == VisualizerMode.spectrumOnly ||
            _spectrumController.mode == VisualizerMode.hybrid ||
            _spectrumController.mode == VisualizerMode.cliSpectrum;
        if (modeUsesSpectrum && (playing || _lastPlaying)) {
          _spectrumController.updateFrame(
            playing,
            dt.clamp(0.001, 0.05),
            playbackPositionMs: player.position.inMilliseconds,
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
    _spectrumController.dispose();
    _lyricsScrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToActiveLyric(int index) {
    _scheduledAutoScroll = -1;
    if (!_lyricsScrollCtrl.hasClients) return;
    _lastAutoScrolled = index;

    const itemHeight = 56.0;
    final target = index * itemHeight;
    _lyricsScrollCtrl.animateTo(
      target.clamp(0.0, _lyricsScrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Color _getSourceTextColor(String? type) {
    switch (type) {
      case 'online':
        return const Color(0xFF00E5FF);
      case 'local_ai':
        return const Color(0xFFD580FF);
      case 'hybrid':
        return Colors.amberAccent;
      case 'local_file':
        return const Color(0xFF00E676);
      default:
        return context.colors.primaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    // La posición se consume en los tickers/painters y en los controles. Si
    // escuchamos todo PlayerService aquí, reconstruimos toda la vista cada
    // 100 ms aunque la pista no haya cambiado.
    context.select<PlayerService, String?>(
      (player) => player.currentTrack?.path,
    );
    final player = context.read<PlayerService>();
    final lyrics = context.watch<LyricsService>();

    if (lyrics.currentIndex >= 0 &&
        lyrics.currentIndex != _lastAutoScrolled &&
        lyrics.lines.isNotEmpty) {
      final targetIdx = lyrics.currentIndex;
      if (_scheduledAutoScroll != targetIdx) {
        _scheduledAutoScroll = targetIdx;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToActiveLyric(targetIdx);
        });
      }
    }

    final c = context.colors;
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: widget.isEmbedded ? Colors.transparent : c.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Barra Superior: Conmutador de Modo y Opciones ─────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  if (!widget.isEmbedded)
                    IconButton(
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 28,
                        color: c.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  else
                    Icon(Icons.graphic_eq_rounded, color: c.primary, size: 24),

                  const SizedBox(width: 8),

                  Container(
                    height: 38,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.glassBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeTab(
                          'Espectro Neón',
                          Icons.graphic_eq_rounded,
                          VisualizerMode.spectrumOnly,
                          c,
                        ),
                        _buildModeTab(
                          'Modo Ritmo',
                          Icons.bolt_rounded,
                          VisualizerMode.rhythm,
                          c,
                        ),
                        _buildModeTab(
                          'Karaoke',
                          Icons.mic_external_on_rounded,
                          VisualizerMode.lyricsOnly,
                          c,
                        ),
                        _buildModeTab(
                          'Espectro CLI',
                          Icons.terminal_rounded,
                          VisualizerMode.cliSpectrum,
                          c,
                        ),
                        _buildModeTab(
                          'Letras CLI',
                          Icons.code_rounded,
                          VisualizerMode.cliClassic,
                          c,
                        ),
                      ],
                    ),
                  ),

                  if (lyrics.isLoading) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: c.primary.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.primary.withOpacity(0.45)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            lyrics.statusMessage.isNotEmpty
                                ? lyrics.statusMessage
                                : 'Buscando letras...',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: c.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  if (_spectrumController.mode == VisualizerMode.spectrumOnly ||
                      _spectrumController.mode == VisualizerMode.hybrid) ...[
                    PopupMenuButton<VisualizerTheme>(
                      tooltip: 'Paleta del Espectro',
                      icon: Icon(
                        Icons.palette_rounded,
                        color: c.primaryLight,
                        size: 20,
                      ),
                      color: c.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (t) {
                        setState(() {
                          _spectrumController.setTheme(t);
                        });
                        context.read<DatabaseService>().setSetting(
                          'visualizer_theme',
                          t.name,
                        );
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: VisualizerTheme.coralNeon,
                          child: Text(
                            'Coral Neón Titofy',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: VisualizerTheme.rainbow,
                          child: Text(
                            'Arcoíris Truecolor Winamp',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: VisualizerTheme.cyberpunk,
                          child: Text(
                            'Cyberpunk Cyan / Violeta',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],

                  if (!widget.isEmbedded) WindowControls(isDark: isDark),
                ],
              ),
            ),

            // ── Área Central: Modo Activo ─────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildActiveContent(player, lyrics),
              ),
            ),

            // ── Barra de Controles Inferior (Solo si es modal flotante) ──
            if (!widget.isEmbedded) const ExpandedPlaybackControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(
    String label,
    IconData icon,
    VisualizerMode mode,
    ThemeColors c,
  ) {
    final isSelected = _spectrumController.mode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _spectrumController.setMode(mode);
        });
        context.read<DatabaseService>().setSetting(
          'visualizer_mode',
          mode.name,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (c.isDark
                    ? c.primary.withOpacity(0.20)
                    : c.primary.withOpacity(0.12))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: isSelected
              ? Border.all(color: c.primary.withOpacity(0.35), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13.5,
              color: isSelected ? c.primary : c.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (c.isDark ? Colors.white : c.primary)
                    : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveContent(PlayerService player, LyricsService lyrics) {
    switch (_spectrumController.mode) {
      case VisualizerMode.spectrumOnly:
      case VisualizerMode.hybrid:
        return ExpandedSpectrumView(
          player: player,
          lyrics: lyrics,
          spectrumController: _spectrumController,
        );
      case VisualizerMode.rhythm:
        return ExpandedRhythmView(player: player, lyrics: lyrics);
      case VisualizerMode.lyricsOnly:
        return ExpandedKaraokeView(
          player: player,
          lyrics: lyrics,
          spectrumController: _spectrumController,
          scrollCtrl: _lyricsScrollCtrl,
          forceShowLyrics: _forceShowLyrics,
          forceShowVisualizer: _forceShowVisualizer,
          onToggleForceLyrics: () {
            setState(() {
              _forceShowLyrics = true;
              _forceShowVisualizer = false;
            });
          },
          onToggleForceVisualizer: () {
            setState(() {
              _forceShowVisualizer = true;
              _forceShowLyrics = false;
            });
          },
        );
      case VisualizerMode.cliSpectrum:
        return ExpandedCliSpectrumView(
          player: player,
          lyrics: lyrics,
          spectrumController: _spectrumController,
          getSourceTextColor: _getSourceTextColor,
        );
      case VisualizerMode.cliClassic:
        return ExpandedCliClassicView(
          player: player,
          lyrics: lyrics,
          getSourceTextColor: _getSourceTextColor,
        );
    }
  }
}
