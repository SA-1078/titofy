import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/services/player_service.dart';
import '../../core/services/library_service.dart';
import '../../core/services/lyrics_service.dart';
import '../../core/services/locale_service.dart';
import '../../core/services/database_service.dart';
import '../visualizer/spectrum_controller.dart';
import '../visualizer/spectrum_painter.dart';
import '../visualizer/cli_rainbow_spectrum_painter.dart';
import '../../shell/window_controls.dart';

/// Reproductor Inmersivo con Modos Múltiples (Karaoke Continuo, Modo Clásico CLI y Espectro Neón FFT)
class ExpandedPlayerView extends StatefulWidget {
  final bool isEmbedded;
  final VisualizerMode? initialMode;
  const ExpandedPlayerView({super.key, this.isEmbedded = false, this.initialMode});

  static void show(BuildContext context, {VisualizerMode? initialMode}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ExpandedPlayer',
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, anim1, anim2) => ExpandedPlayerView(isEmbedded: false, initialMode: initialMode),
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

class _ExpandedPlayerViewState extends State<ExpandedPlayerView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final SpectrumController _spectrumController;
  final ScrollController _lyricsScrollCtrl = ScrollController();
  Duration _lastTick = Duration.zero;
  int _lastAutoScrolled = -1;

  bool _forceShowLyrics = false;
  bool _forceShowVisualizer = false;

  @override
  void initState() {
    super.initState();
    _spectrumController = SpectrumController();

    // Restaurar configuracion guardada de tema y modo del espectro
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
        for (final m in VisualizerMode.values) {
          if (m.name == savedMode) {
            _spectrumController.setMode(m);
            break;
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
        _spectrumController.updateFrame(
          player.isPlaying,
          dt.clamp(0.001, 0.05),
          playbackPositionMs: player.position.inMilliseconds,
        );
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
    if (!_lyricsScrollCtrl.hasClients) return;
    _lastAutoScrolled = index;

    const itemHeight = 56.0;
    final target = index * itemHeight;
    _lyricsScrollCtrl.animateTo(
      target.clamp(0.0, _lyricsScrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
    );
  }

  Color _getSourceBadgeBg(String? type) {
    switch (type) {
      case 'online':
        return const Color(0xFF00E5FF).withOpacity(0.12);
      case 'local_ai':
        return const Color(0xFFD580FF).withOpacity(0.12);
      case 'hybrid':
        return Colors.amber.withOpacity(0.12);
      case 'local_file':
        return const Color(0xFF00E676).withOpacity(0.12);
      default:
        return context.colors.primary.withOpacity(0.12);
    }
  }

  Color _getSourceBadgeBorder(String? type) {
    switch (type) {
      case 'online':
        return const Color(0xFF00E5FF).withOpacity(0.5);
      case 'local_ai':
        return const Color(0xFFD580FF).withOpacity(0.5);
      case 'hybrid':
        return Colors.amber.withOpacity(0.5);
      case 'local_file':
        return const Color(0xFF00E676).withOpacity(0.5);
      default:
        return context.colors.primary.withOpacity(0.4);
    }
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

  IconData _getSourceIcon(String? type) {
    switch (type) {
      case 'online':
        return Icons.public_rounded;
      case 'local_ai':
        return Icons.memory_rounded;
      case 'hybrid':
        return Icons.auto_awesome_rounded;
      case 'local_file':
        return Icons.folder_open_rounded;
      default:
        return Icons.lyrics_rounded;
    }
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final lyrics = context.watch<LyricsService>();
    final loc = context.watch<LocaleService>();

    // Scroll automático en modo Karaoke SOLO cuando el verso cambia
    if (lyrics.currentIndex >= 0 && lyrics.currentIndex != _lastAutoScrolled && lyrics.lines.isNotEmpty) {
      final targetIdx = lyrics.currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToActiveLyric(targetIdx);
      });
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
                      icon: Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: c.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  else
                    Icon(Icons.graphic_eq_rounded, color: c.primary, size: 24),

                  const SizedBox(width: 8),

                  // Barra de herramientas integrada (Toolbar estilo Windows 11 / GNOME)
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
                        _buildModeTab('Espectro Neón', Icons.graphic_eq_rounded, VisualizerMode.spectrumOnly, c),
                        _buildModeTab('Híbrido', Icons.auto_awesome_rounded, VisualizerMode.hybrid, c),
                        _buildModeTab('Karaoke', Icons.mic_external_on_rounded, VisualizerMode.lyricsOnly, c),
                        _buildModeTab('Espectro CLI', Icons.terminal_rounded, VisualizerMode.cliSpectrum, c),
                        _buildModeTab('Letras CLI', Icons.code_rounded, VisualizerMode.cliClassic, c),
                      ],
                    ),
                  ),

                  // ── Indicador de Progreso o Fuente de Letras en Barra Superior ──
                  if (lyrics.isLoading) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            lyrics.statusMessage.isNotEmpty ? lyrics.statusMessage : 'Buscando letras...',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.primary),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Selector de Tema cromático para el espectro
                  if (_spectrumController.mode == VisualizerMode.spectrumOnly ||
                      _spectrumController.mode == VisualizerMode.hybrid) ...[
                    PopupMenuButton<VisualizerTheme>(
                      tooltip: 'Paleta del Espectro',
                      icon: Icon(Icons.palette_rounded, color: c.primaryLight, size: 20),
                      color: c.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (t) {
                        setState(() {
                          _spectrumController.setTheme(t);
                        });
                        context.read<DatabaseService>().setSetting('visualizer_theme', t.name);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: VisualizerTheme.coralNeon,
                          child: Text('Coral Neón Titofy', style: TextStyle(fontSize: 12, color: c.textPrimary)),
                        ),
                        PopupMenuItem(
                          value: VisualizerTheme.rainbow,
                          child: Text('Arcoíris Truecolor Winamp', style: TextStyle(fontSize: 12, color: c.textPrimary)),
                        ),
                        PopupMenuItem(
                          value: VisualizerTheme.cyberpunk,
                          child: Text('Cyberpunk Cyan / Violeta', style: TextStyle(fontSize: 12, color: c.textPrimary)),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Botones de ventana de la esquina (Minimizar, Maximizar/Ventana, Cerrar)
                  WindowControls(isDark: isDark),
                ],
              ),
            ),

            // ── Área Central: Modo Activo ─────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildActiveContent(player, lyrics, loc),
              ),
            ),

            // ── Barra de Controles Inferior (Solo si es modal flotante) ──
            if (!widget.isEmbedded) _buildPlaybackControls(player, lyrics),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(String label, IconData icon, VisualizerMode mode, ThemeColors c) {
    final isSelected = _spectrumController.mode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _spectrumController.setMode(mode);
        });
        context.read<DatabaseService>().setSetting('visualizer_mode', mode.name);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (c.isDark ? c.primary.withOpacity(0.20) : c.primary.withOpacity(0.12))
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
                color: isSelected ? (c.isDark ? Colors.white : c.primary) : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveContent(PlayerService player, LyricsService lyrics, LocaleService loc) {
    switch (_spectrumController.mode) {
      case VisualizerMode.spectrumOnly:
        return _buildSpectrumView(player, lyrics, showFloatingLyric: false);
      case VisualizerMode.hybrid:
        return _buildSpectrumView(player, lyrics, showFloatingLyric: true);
      case VisualizerMode.lyricsOnly:
        return _buildKaraokeView(player, lyrics, loc);
      case VisualizerMode.cliSpectrum:
        return _buildCliSpectrumPlayer(player, lyrics);
      case VisualizerMode.cliClassic:
        return _buildCliClassicPlayer(player, lyrics);
    }
  }

  bool _isInstrumental(LyricsService lyrics) {
    if (lyrics.lines.isEmpty) return true;
    final vocalLines = lyrics.lines.where((l) {
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

  // ── MODO 1: Karaoke Moderno Continuo ────────────────────────────────────────
  Widget _buildKaraokeView(PlayerService player, LyricsService lyrics, LocaleService loc) {
    final c = context.colors;
    final isDark = c.isDark;

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

    final isInstrumental = _isInstrumental(lyrics);
    final showVisualizer = (isInstrumental && !_forceShowLyrics) || _forceShowVisualizer;

    // Estado vacío elegante cuando no hay música reproduciéndose
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
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Icon(
                Icons.headphones_rounded,
                size: 40,
                color: c.textMuted.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Ninguna pista en reproducción',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Selecciona una canción en tu biblioteca para activar el karaoke y las visualizaciones',
              style: TextStyle(
                fontSize: 12.5,
                color: c.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Portada
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
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
                        SizedBox(width: 6),
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

        // Área Derecha: Visualizador FFT Dinámico o Lista de Letras
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
                      if (lyrics.lines.isNotEmpty)
                        TextButton.icon(
                          icon: Icon(Icons.lyrics_rounded, size: 15, color: c.primary),
                          label: Text('Ver Texto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.primary)),
                          onPressed: () {
                            setState(() {
                              _forceShowLyrics = true;
                              _forceShowVisualizer = false;
                            });
                          },
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
                      child: AnimatedBuilder(
                        animation: _spectrumController,
                        builder: (context, _) => CustomPaint(
                          painter: SpectrumPainter(
                            levels: _spectrumController.levels,
                            peaks: _spectrumController.peaks,
                            beatEnergy: _spectrumController.beatEnergy,
                            theme: _spectrumController.theme,
                          ),
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
                        controller: _lyricsScrollCtrl,
                        itemExtent: itemHeight,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: verticalPadding,
                        ),
                        physics: const BouncingScrollPhysics(),
                        itemCount: lyrics.lines.length,
                        itemBuilder: (context, index) {
                          final line = lyrics.lines[index];
                          final delta = index - lyrics.currentIndex;
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
                                  if (mounted) {
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
                        onPressed: () {
                          setState(() {
                            _forceShowVisualizer = true;
                            _forceShowLyrics = false;
                          });
                        },
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


  // ── MODO 1: Espectro Arcoíris ASCII CLI (Terminal idéntico a foto CLI) ─────
  Widget _buildCliSpectrumPlayer(PlayerService player, LyricsService lyrics) {
    const int totalBlocks = 44;
    final int filledBlocks = (player.progress * totalBlocks).round().clamp(0, totalBlocks);
    final int emptyBlocks = totalBlocks - filledBlocks;
    final String asciiBar = '█' * filledBlocks + '░' * emptyBlocks;

    final idx = lyrics.currentIndex;
    final lines = lyrics.lines;
    final String curr = (idx >= 0 && idx < lines.length)
        ? lines[idx].text
        : (lines.isNotEmpty ? lines[0].text : 'Esperando que comience la letra...');

    double lineProgress = 0.0;
    if (idx >= 0 && idx < lines.length) {
      final lineStart = lines[idx].time;
      final lineEnd = (idx + 1 < lines.length) ? lines[idx + 1].time : (lineStart + const Duration(seconds: 4));
      final lineDuration = (lineEnd - lineStart).inMilliseconds;
      if (lineDuration > 0) {
        final elapsedInLine = (player.position - lineStart).inMilliseconds;
        lineProgress = (elapsedInLine / lineDuration).clamp(0.0, 1.0);
      }
    }
    final splitIndex = (curr.length * lineProgress).round().clamp(0, curr.length);
    final sungText = curr.substring(0, splitIndex);
    final unsungText = curr.substring(splitIndex);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final route = ModalRoute.of(context);
          if (route != null && !route.isCurrent) {
            return KeyEventResult.ignored;
          }

          final primaryFocus = FocusManager.instance.primaryFocus;
          if (primaryFocus != null) {
            final debugLabel = primaryFocus.debugLabel?.toLowerCase() ?? '';
            if (debugLabel.contains('editable') || debugLabel.contains('textfield')) {
              return KeyEventResult.ignored;
            }
            final ctx = primaryFocus.context;
            if (ctx != null && (ctx.widget is EditableText || ctx.findAncestorWidgetOfExactType<EditableText>() != null)) {
              return KeyEventResult.ignored;
            }
          }

          if (event.logicalKey == LogicalKeyboardKey.space) {
            player.playPause();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            player.seekTo(player.position - const Duration(seconds: 10));
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            player.seekTo(player.position + const Duration(seconds: 10));
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            player.setVolume((player.volume + 0.05).clamp(0.0, 1.0));
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            player.setVolume((player.volume - 0.05).clamp(0.0, 1.0));
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.escape || event.logicalKey == LogicalKeyboardKey.keyQ) {
            if (!widget.isEmbedded) Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 880),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1D0921), // Fondo terminal ciruela de la foto CLI
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4A1A54), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header: Caja redondeada con ♫ Título de Canción ────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00E5FF), width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.music_note_rounded, color: Color(0xFF00E5FF), size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        player.currentTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      lyrics.isLoading
                          ? 'BUSCANDO...'
                          : (lyrics.sourceLabel.isNotEmpty ? lyrics.sourceLabel : 'SYNCED LRC'),
                      style: TextStyle(
                        color: _getSourceTextColor(lyrics.sourceType),
                        fontSize: 10,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Espectro Arcoíris ASCII con Sub-Blocks Unicode y Picos Blancos ──
              SizedBox(
                height: 190,
                child: AnimatedBuilder(
                  animation: _spectrumController,
                  builder: (context, _) => CustomPaint(
                    size: const Size(double.infinity, 190),
                    painter: CliRainbowSpectrumPainter(
                      levels: _spectrumController.levels,
                      peaks: _spectrumController.peaks,
                      beatEnergy: _spectrumController.beatEnergy,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Línea de Base del Espectro
              Container(
                height: 1.5,
                color: const Color(0xFF00E5FF).withOpacity(0.35),
              ),

              const SizedBox(height: 10),

              // ── Barra de Progreso Terminal: ▶ ██████░░░░ 00:13 / 03:23 ─────
              Row(
                children: [
                  Text(
                    player.isPlaying ? '▶ ' : '⏸ ',
                    style: TextStyle(
                      color: player.isPlaying ? const Color(0xFF00E676) : Colors.amber,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      asciiBar,
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 12,
                        fontFamily: 'monospace',
                        letterSpacing: 1.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_formatTime(player.position)} / ${_formatTime(player.duration)}',
                    style: const TextStyle(
                      color: Color(0xFFFFEA00),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Sección de Letras: ── Letras ───────── [Vol: 100%] ─────────
              Row(
                children: [
                  const Text('── Letras ', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontFamily: 'monospace')),
                  Expanded(child: Container(height: 1, color: const Color(0xFF00E5FF).withOpacity(0.35))),
                  Text(
                    ' [Vol: ${(player.volume * 100).round()}%]',
                    style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Línea activa de Letra con Iluminación Sílaba a Sílaba
              RichText(
                text: TextSpan(
                  children: [
                    const WidgetSpan(
                      child: Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.music_note_rounded, color: Color(0xFF00E5FF), size: 14),
                      ),
                      alignment: PlaceholderAlignment.middle,
                    ),
                    if (sungText.isNotEmpty)
                      TextSpan(
                        text: sungText,
                        style: const TextStyle(
                          color: Color(0xFF39FF14), // Verde Neón activo
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    TextSpan(
                      text: unsungText,
                      style: TextStyle(
                        color: idx >= 0 ? const Color(0xFFA093B0) : const Color(0xFF6B5878),
                        fontSize: 14,
                        fontStyle: idx >= 0 ? FontStyle.normal : FontStyle.italic,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 16),

              // Separador inferior
              Container(height: 1, color: const Color(0xFF00E5FF).withOpacity(0.2)),

              const SizedBox(height: 10),

              // ── Atajos de Teclado de la CLI ─────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('[Espacio]', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontFamily: 'monospace')),
                  Text(' Pausar   ', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                  Text('[← →]', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontFamily: 'monospace')),
                  Text(' ±10 seg   ', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                  Text('[↑ ↓]', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontFamily: 'monospace')),
                  Text(' Volumen   ', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                  Text('[Esc]', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontFamily: 'monospace')),
                  Text(' Salir', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── MODO 2: Reproductor Animado Estilo CLI (5 slots con warmup y glow) ─────
  Widget _buildCliClassicPlayer(PlayerService player, LyricsService lyrics) {
    final idx = lyrics.currentIndex;
    final lines = lyrics.lines;

    final String prev2 = (idx >= 2 && lines.isNotEmpty) ? lines[idx - 2].text : '';
    final String prev1 = (idx >= 1 && lines.isNotEmpty) ? lines[idx - 1].text : '';
    final String curr = (idx >= 0 && idx < lines.length)
        ? lines[idx].text
        : (lines.isNotEmpty ? lines[0].text : 'Esperando audio...');
    final String next1 = (idx + 1 < lines.length) ? lines[idx + 1].text : '';
    final String next2 = (idx + 2 < lines.length) ? lines[idx + 2].text : '';

    // Progreso exacto de la línea activa para efecto de llenado por sílabas/letras (renderProgressLine)
    double lineProgress = 0.0;
    if (idx >= 0 && idx < lines.length) {
      final lineStart = lines[idx].time;
      final lineEnd = (idx + 1 < lines.length)
          ? lines[idx + 1].time
          : (lineStart + const Duration(seconds: 4));
      final lineDuration = (lineEnd - lineStart).inMilliseconds;
      if (lineDuration > 0) {
        final elapsedInLine = (player.position - lineStart).inMilliseconds;
        lineProgress = (elapsedInLine / lineDuration).clamp(0.0, 1.0);
      }
    }

    final splitIndex = (curr.length * lineProgress).round().clamp(0, curr.length);
    final sungText = curr.substring(0, splitIndex);
    final unsungText = curr.substring(splitIndex);

    // Barra de bloques ASCII estilo CLI (████████░░░░░░░░)
    const int totalBlocks = 32;
    final int filledBlocks = (player.progress * totalBlocks).round().clamp(0, totalBlocks);
    final int emptyBlocks = totalBlocks - filledBlocks;
    final String asciiBar = '█' * filledBlocks + '░' * emptyBlocks;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 860),
        padding: const EdgeInsets.all(28),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF070A12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF39FF14).withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF39FF14).withOpacity(0.08),
              blurRadius: 35,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header estilo consola retro ASCII Titofy CLI
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1524),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF39FF14).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.terminal_rounded, size: 16, color: Color(0xFF39FF14)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '╔═ TITOFY CLI PLAYER // ${player.currentTitle} - ${player.currentArtist} ═╗',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Color(0xFF39FF14),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF39FF14).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      lyrics.isLoading
                          ? 'BUSCANDO EN LRCLIB...'
                          : (lyrics.sourceLabel.isNotEmpty ? lyrics.sourceLabel : 'OFFLINE / SYNCED'),
                      style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: _getSourceTextColor(lyrics.sourceType), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Slot -2 (Fade lejano)
            Text(
              prev2.isNotEmpty ? prev2 : ' ',
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: Colors.white.withOpacity(0.25),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Slot -1 (Anterior reciente)
            Text(
              prev1.isNotEmpty ? prev1 : ' ',
              style: TextStyle(
                fontSize: 15,
                fontFamily: 'monospace',
                color: Colors.white.withOpacity(0.55),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),

            // Slot 0: LÍNEA CENTRAL ACTIVA con relleno carácter a carácter (renderProgressLine)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF39FF14).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF39FF14).withOpacity(0.6), width: 1.2),
              ),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    // Texto ya cantado en verde neón brillante y resplandor
                    TextSpan(
                      text: sungText,
                      style: const TextStyle(
                        fontSize: 22,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF39FF14),
                        shadows: [
                          Shadow(color: Color(0xFF39FF14), blurRadius: 16),
                        ],
                      ),
                    ),
                    // Texto pendiente en gris suave
                    TextSpan(
                      text: unsungText,
                      style: TextStyle(
                        fontSize: 22,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Slot +1 (Warmup siguiente línea en amarillo suave)
            Text(
              next1.isNotEmpty ? next1 : ' ',
              style: const TextStyle(
                fontSize: 15,
                fontFamily: 'monospace',
                color: Color(0xFFFFE066),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Slot +2 (Fade futuro)
            Text(
              next2.isNotEmpty ? next2 : ' ',
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: Colors.white.withOpacity(0.25),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 28),

            // Barra de progreso con Bloques ASCII (█░)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1524),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    player.isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: const Color(0xFF39FF14),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(player.position),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF39FF14), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      asciiBar,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                        color: Color(0xFF39FF14),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    _formatTime(player.duration),
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── MODO 3 / 4: Visualizador de Espectro Neón FFT ───────────────────────────
  Widget _buildSpectrumView(PlayerService player, LyricsService lyrics, {required bool showFloatingLyric}) {
    return Stack(
      children: [
        // Espectro Neón Desktop Premium que ocupa el 100% del ancho de la pantalla
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: AnimatedBuilder(
              animation: _spectrumController,
              builder: (context, _) => CustomPaint(
                painter: SpectrumPainter(
                  levels: _spectrumController.levels,
                  peaks: _spectrumController.peaks,
                  beatEnergy: _spectrumController.beatEnergy,
                  theme: _spectrumController.theme,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),

        // Letra flotante sincronizada en modo Híbrido
        if (showFloatingLyric && lyrics.currentLine != null)
          Positioned(
            top: 24,
            left: 32,
            right: 32,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.backgroundAlt.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.primary.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(color: context.colors.primary.withOpacity(0.3), blurRadius: 20),
                  ],
                ),
                child: Text(
                  lyrics.currentLine!.text,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

        // Nombre de la canción en la esquina superior izquierda
        if (player.currentTrack != null)
          Positioned(
            top: 16,
            left: 28,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: context.colors.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.glassBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.graphic_eq_rounded, size: 16, color: context.colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    '${player.currentTitle} · ${player.currentArtist}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                  ),
                ],
              ),
            ),
          )
        else
          Positioned(
            top: 16,
            left: 28,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: context.colors.surface.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.glassBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.graphic_eq_rounded, size: 16, color: context.colors.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    'Reproduce una canción para modular el espectro',
                    style: TextStyle(fontSize: 12, color: context.colors.textMuted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Controles Inferiores (solo para ventana flotante) ───────────────────────
  Widget _buildPlaybackControls(PlayerService player, LyricsService lyrics) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.glassBorder)),
      ),
      child: Row(
        children: [
          IconButton(icon: Icon(Icons.skip_previous_rounded, color: c.textPrimary, size: 24), onPressed: () => player.previous()),
          IconButton(
            icon: Icon(player.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: c.primary, size: 36),
            onPressed: () => player.playPause(),
          ),
          IconButton(icon: Icon(Icons.skip_next_rounded, color: c.textPrimary, size: 24), onPressed: () => player.next()),
          const SizedBox(width: 12),
          Text(_formatTime(player.position), style: TextStyle(fontSize: 11, color: c.textSecondary)),
          Expanded(
            child: Slider(
              value: player.position.inSeconds.toDouble().clamp(0.0, player.duration.inSeconds.toDouble() > 0 ? player.duration.inSeconds.toDouble() : 1.0),
              max: player.duration.inSeconds.toDouble() > 0 ? player.duration.inSeconds.toDouble() : 1.0,
              activeColor: c.primary,
              inactiveColor: c.glassBorder,
              onChanged: (v) => player.seekTo(Duration(seconds: v.toInt())),
            ),
          ),
          Text(_formatTime(player.duration), style: TextStyle(fontSize: 11, color: c.textSecondary)),
          if (player.currentTrack != null) ...[
            const SizedBox(width: 8),
            Consumer<LibraryService>(
              builder: (context, lib, _) {
                final isFav = lib.isFavorite(player.currentTrack!);
                return IconButton(
                  tooltip: isFav ? 'Quitar de favoritos' : 'Añadir a canciones favoritas',
                  icon: Icon(
                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFav ? c.primary : c.textSecondary,
                    size: 22,
                  ),
                  splashRadius: 20,
                  onPressed: () => lib.toggleFavorite(player.currentTrack!),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

