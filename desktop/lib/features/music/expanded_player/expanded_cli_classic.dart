import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/player_service.dart';
import '../../../core/services/lyrics_service.dart';

/// Modo 2: Reproductor Animado Estilo CLI (5 slots con warmup y glow)
class ExpandedCliClassicView extends StatelessWidget {
  final PlayerService player;
  final LyricsService lyrics;
  final Color Function(String? type) getSourceTextColor;

  const ExpandedCliClassicView({
    super.key,
    required this.player,
    required this.lyrics,
    required this.getSourceTextColor,
  });

  String _formatTime(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final idx = lyrics.currentIndex;
    final lines = lyrics.lines;

    final String prev2 = (idx >= 2 && lines.isNotEmpty) ? lines[idx - 2].text : '';
    final String prev1 = (idx >= 1 && lines.isNotEmpty) ? lines[idx - 1].text : '';
    final String curr = (idx >= 0 && idx < lines.length)
        ? lines[idx].text
        : (lines.isNotEmpty ? lines[0].text : 'Esperando audio...');
    final String next1 = (idx + 1 < lines.length) ? lines[idx + 1].text : '';
    final String next2 = (idx + 2 < lines.length) ? lines[idx + 2].text : '';

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
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: getSourceTextColor(lyrics.sourceType),
                        fontWeight: FontWeight.bold,
                      ),
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

            // Slot 0: LÍNEA CENTRAL ACTIVA con relleno carácter a carácter
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
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Color(0xFF39FF14),
                      fontWeight: FontWeight.bold,
                    ),
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
}
