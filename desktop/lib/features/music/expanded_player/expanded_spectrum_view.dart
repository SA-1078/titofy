// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/player_service.dart';
import '../../../core/services/lyrics_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/library_service.dart';
import '../../visualizer/spectrum_controller.dart';
import '../../visualizer/spectrum_painter.dart';
import 'spectrum_style_selector.dart';

/// Vista de Espectro Neón Desktop a pantalla completa con soporte integrado para letra flotante
class ExpandedSpectrumView extends StatefulWidget {
  final PlayerService player;
  final LyricsService lyrics;
  final SpectrumController spectrumController;
  final bool? showFloatingLyric;

  const ExpandedSpectrumView({
    super.key,
    required this.player,
    required this.lyrics,
    required this.spectrumController,
    this.showFloatingLyric,
  });

  @override
  State<ExpandedSpectrumView> createState() => _ExpandedSpectrumViewState();
}

class _ExpandedSpectrumViewState extends State<ExpandedSpectrumView> {
  bool _showLyrics = false;

  @override
  void initState() {
    super.initState();
    if (widget.showFloatingLyric != null) {
      _showLyrics = widget.showFloatingLyric!;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final db = context.read<DatabaseService>();
        final saved = db.getSetting('spectrum_show_lyrics');
        if (saved != null) {
          setState(() {
            _showLyrics = saved == 'true';
          });
        }
      });
    }
  }

  void _onToggleLyrics(bool value) {
    setState(() {
      _showLyrics = value;
    });
    context.read<DatabaseService>().setSetting('spectrum_show_lyrics', value ? 'true' : 'false');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final player = widget.player;
    final lyrics = widget.lyrics;

    return Stack(
      children: [
        // ── 1. Espectro Neón Desktop Premium que ocupa el 100% del ancho ────
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: RepaintBoundary(
              child: CustomPaint(
                painter: SpectrumPainter.fromController(widget.spectrumController),
                size: Size.infinite,
              ),
            ),
          ),
        ),

        // ── 2. Selector de Estilo de Espectro (Sin Letras vs Con Letras) ──────
        Positioned(
          top: 18,
          right: 28,
          child: SpectrumStyleSelector(
            showLyrics: _showLyrics,
            onToggleLyrics: _onToggleLyrics,
          ),
        ),

        // ── 3. Metadatos de la Pista (Esquina Superior Izquierda) ────────────
        Positioned(
          top: 18,
          left: 28,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.graphic_eq_rounded, size: 16, color: c.primary),
                const SizedBox(width: 8),
                Text(
                  player.currentTrack != null
                      ? '${player.currentTitle} · ${player.currentArtist}'
                      : 'Espectro Neón Activo',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
                if (player.currentTrack != null) ...[
                  const SizedBox(width: 8),
                  Consumer<LibraryService>(
                    builder: (context, lib, _) {
                      final isFav = lib.isFavorite(player.currentTrack!);
                      return InkWell(
                        onTap: () => lib.toggleFavorite(player.currentTrack!),
                        child: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
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

        // ── 4. Letra Flotante Sincronizada (Cuando Con Letras está activo) ───
        if (_showLyrics && lyrics.currentLine != null)
          Positioned(
            top: 72,
            left: 48,
            right: 48,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(lyrics.currentLine!.text),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: c.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.primary.withValues(alpha: 0.45)),
                    boxShadow: [
                      BoxShadow(color: c.primary.withValues(alpha: 0.25), blurRadius: 20),
                    ],
                  ),
                  child: Text(
                    lyrics.currentLine!.text,
                    style: TextStyle(
                      fontSize: 20,
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
          ),
      ],
    );
  }
}
