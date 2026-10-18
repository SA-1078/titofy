import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/services/player_service.dart';
import '../../core/services/lyrics_service.dart';
import '../../features/music/lyrics_overlay.dart';
import '../../features/music/expanded_player_view.dart';
import '../../features/visualizer/spectrum_controller.dart';

/// Lado derecho del MiniPlayer: Controles de reproducción, volumen, letras y modos
class MiniPlayerControls extends StatelessWidget {
  const MiniPlayerControls({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerService>();
    final isPlaying = context.select<PlayerService, bool>((p) => p.isPlaying);
    final isResolvingStream = context.select<PlayerService, bool>(
      (p) => p.isResolvingStream,
    );
    final volume = context.select<PlayerService, double>((p) => p.volume);
    final lyrics = context.watch<LyricsService>();
    final c = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Anterior
        IconButton(
          icon: const Icon(
            Icons.skip_previous_rounded,
            color: Colors.white,
            size: 24,
          ),
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
          child: isResolvingStream
              ? Padding(
                  padding: const EdgeInsets.all(9.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: c.primary,
                  ),
                )
              : IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: c.primary,
                    size: 22,
                  ),
                  onPressed: () => player.playPause(),
                ),
        ),

        // Siguiente
        IconButton(
          icon: const Icon(
            Icons.skip_next_rounded,
            color: Colors.white,
            size: 24,
          ),
          splashRadius: 20,
          onPressed: () => player.next(),
        ),

        const SizedBox(width: 8),

        // Botón de Letras / Karaoke
        IconButton(
          tooltip: 'Letras sincronizadas (Karaoke)',
          icon: Icon(
            lyrics.lines.isNotEmpty
                ? Icons.lyrics_rounded
                : Icons.lyrics_outlined,
            color: Colors.white,
            size: 22,
          ),
          splashRadius: 20,
          onPressed: () => LyricsOverlay.show(context),
        ),

        // Control de Volumen emergente
        PopupMenuButton<double>(
          tooltip: 'Volumen',
          icon: Icon(
            volume == 0
                ? Icons.volume_off_rounded
                : volume < 0.5
                ? Icons.volume_down_rounded
                : Icons.volume_up_rounded,
            color: Colors.white,
            size: 22,
          ),
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: StatefulBuilder(
                builder: (context, setState) => Row(
                  children: [
                    Icon(Icons.volume_down_rounded, color: c.primary, size: 20),
                    Expanded(
                      child: Slider(
                        value: volume,
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
                      '${(volume * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Botón dedicado para Visualizador de Espectro Neón Desktop
        IconButton(
          tooltip: 'Visualizador de Espectro Neón Desktop',
          icon: const Icon(
            Icons.graphic_eq_rounded,
            color: Colors.white,
            size: 22,
          ),
          splashRadius: 20,
          onPressed: () => ExpandedPlayerView.show(
            context,
            initialMode: VisualizerMode.spectrumOnly,
          ),
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
    );
  }
}
