import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/services/lyrics_service.dart';
import '../../core/services/player_service.dart';

/// Vista de Karaoke y Letras Sincronizadas en Tiempo Real (Estilo Neón Titofy)
class LyricsOverlay extends StatefulWidget {
  const LyricsOverlay({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LyricsOverlay(),
    );
  }

  @override
  State<LyricsOverlay> createState() => _LyricsOverlayState();
}

class _LyricsOverlayState extends State<LyricsOverlay> {
  final ScrollController _scrollController = ScrollController();
  int _lastAutoScrolledIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActive(int index, int totalLines) {
    if (index == _lastAutoScrolledIndex || !_scrollController.hasClients) return;
    _lastAutoScrolledIndex = index;

    // Aproximación de 60px por línea
    const itemHeight = 64.0;
    final targetOffset = (index * itemHeight) - 200.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = context.watch<LyricsService>();
    final player = context.watch<PlayerService>();
    final c = context.colors;

    // Scroll automático a la línea activa
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (lyrics.currentIndex >= 0 && lyrics.lines.isNotEmpty) {
        _scrollToActive(lyrics.currentIndex, lyrics.lines.length);
      }
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: c.background.withOpacity(0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: c.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Barra superior con tirador y controles ────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: c.glassBorder,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Carátula pequeña o icono
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: c.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: c.primary.withOpacity(0.3),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.lyrics_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.currentTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                flex: 2,
                                child: Text(
                                  player.currentArtist,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: c.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Botón para regenerar con IA
                    IconButton(
                      tooltip: 'Regenerar con Whisper IA',
                      icon: lyrics.isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                            )
                          : Icon(Icons.auto_awesome_rounded, color: c.primaryLight),
                      onPressed: lyrics.isLoading || player.currentTrack == null
                          ? null
                          : () {
                              lyrics.regenerateWithAI(player.currentTrack!.path);
                            },
                    ),
                    const SizedBox(width: 8),
                    // Cerrar
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.glassBorder),

          // ── Cuerpo: Lista de Letras Sincronizadas ──────────────────────────
          Expanded(
            child: lyrics.isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: c.primary),
                        const SizedBox(height: 16),
                        Text(
                          lyrics.statusMessage.isNotEmpty ? lyrics.statusMessage : 'Buscando letras...',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Consultando LRCLIB online o acelerador Whisper...',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : lyrics.lines.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mic_none_rounded, size: 48, color: c.textMuted.withOpacity(0.6)),
                            const SizedBox(height: 14),
                            Text(
                              'Sin letras sincronizadas disponibles',
                              style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Haz clic en el icono de IA para transcribir con Whisper local',
                              style: TextStyle(color: c.textSecondary, fontSize: 12),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                              label: const Text('Transcribir con Whisper IA'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: c.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              onPressed: player.currentTrack == null
                                  ? null
                                  : () => lyrics.regenerateWithAI(player.currentTrack!.path),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                        itemCount: lyrics.lines.length,
                        itemBuilder: (context, index) {
                          final line = lyrics.lines[index];
                          final isActive = index == lyrics.currentIndex;

                          return GestureDetector(
                            onTap: () => player.seekTo(line.time),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? c.primary.withOpacity(0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isActive
                                      ? c.primary.withOpacity(0.4)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                line.text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isActive ? 22 : 16,
                                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                                  color: isActive
                                      ? (context.isDarkMode ? Colors.white : c.primary)
                                      : c.textSecondary.withOpacity(0.7),
                                  shadows: isActive
                                      ? [
                                          Shadow(
                                            color: c.primary.withOpacity(0.8),
                                            blurRadius: context.isDarkMode ? 20 : 6,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
