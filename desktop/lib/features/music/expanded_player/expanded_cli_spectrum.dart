import 'package:flutter/material.dart';
import '../../../core/services/player_service.dart';
import '../../../core/services/lyrics_service.dart';
import '../../visualizer/spectrum_controller.dart';
import '../../visualizer/cli_rainbow_spectrum_painter.dart';

/// Modo Espectro Arcoíris ASCII CLI (Terminal idéntico a CLI retro con sub-blocks Unicode y picos)
class ExpandedCliSpectrumView extends StatelessWidget {
  final PlayerService player;
  final LyricsService lyrics;
  final SpectrumController spectrumController;
  final Color Function(String? type) getSourceTextColor;

  const ExpandedCliSpectrumView({
    super.key,
    required this.player,
    required this.lyrics,
    required this.spectrumController,
    required this.getSourceTextColor,
  });

  String _formatTime(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
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

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 880),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF1D0921), // Fondo terminal ciruela
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
            // Header con caja de canción
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
                      color: getSourceTextColor(lyrics.sourceType),
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Espectro Arcoíris ASCII
            SizedBox(
              height: 190,
              child: RepaintBoundary(
                child: CustomPaint(
                  size: const Size(double.infinity, 190),
                  painter: CliRainbowSpectrumPainter.fromController(spectrumController),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Línea de base
            Container(
              height: 1.5,
              color: const Color(0xFF00E5FF).withOpacity(0.35),
            ),

            const SizedBox(height: 10),

            // Barra de progreso terminal
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

            // Sección de Letras
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

            // Línea activa con iluminación
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
                        color: Color(0xFF39FF14),
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

            Container(height: 1, color: const Color(0xFF00E5FF).withOpacity(0.2)),
            const SizedBox(height: 10),

            // Atajos de teclado
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
    );
  }
}
