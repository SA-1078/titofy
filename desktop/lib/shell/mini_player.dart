import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/colors.dart';
import '../core/services/player_service.dart';
import 'player/interactive_audio_waveform.dart';
import 'player/mini_player_track_info.dart';
import 'player/mini_player_controls.dart';

export 'player/hover_progress_bar.dart';
export 'player/interactive_audio_waveform.dart';
export 'player/mini_player_track_info.dart';
export 'player/mini_player_controls.dart';

/// Reproductor inferior con diseño desacoplado y modular
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  @override
  Widget build(BuildContext context) {
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
          // ── LADO IZQUIERDO: Portada, Título, Artista y Acciones Rápidas ───
          const Expanded(flex: 3, child: MiniPlayerTrackInfo()),

          // ── CENTRO: Barra de Progreso de Música Interactiva ──────────────
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const _MiniPlayerProgress(),
            ),
          ),

          // ── LADO DERECHO: Controles, Volumen, Letras y Modos ─────────────
          const Expanded(flex: 4, child: MiniPlayerControls()),
        ],
      ),
    );
  }
}

class _MiniPlayerProgress extends StatelessWidget {
  const _MiniPlayerProgress();

  String _formatTime(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    return Row(
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
        const SizedBox(width: 12),
        Expanded(
          child: InteractiveAudioWaveform(
            position: player.position,
            duration: player.duration,
            isPlaying: player.isPlaying,
            onSeek: player.seekTo,
          ),
        ),
        const SizedBox(width: 12),
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
    );
  }
}
