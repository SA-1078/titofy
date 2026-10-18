import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/player_service.dart';
import '../../../core/services/library_service.dart';

/// Barra inferior de controles para el reproductor expandido
class ExpandedPlaybackControls extends StatelessWidget {
  const ExpandedPlaybackControls({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final player = context.read<PlayerService>();
    final isPlaying = context.select<PlayerService, bool>((p) => p.isPlaying);
    final isResolvingStream = context.select<PlayerService, bool>(
      (p) => p.isResolvingStream,
    );
    final currentTrackPath = context.select<PlayerService, String?>(
      (p) => p.currentTrack?.path,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.glassBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.skip_previous_rounded,
              color: c.textPrimary,
              size: 24,
            ),
            onPressed: () => player.previous(),
          ),
          IconButton(
            icon: isResolvingStream
                ? SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: c.primary,
                    ),
                  )
                : Icon(
                    isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: c.primary,
                    size: 36,
                  ),
            onPressed: () => player.playPause(),
          ),
          IconButton(
            icon: Icon(Icons.skip_next_rounded, color: c.textPrimary, size: 24),
            onPressed: () => player.next(),
          ),
          const SizedBox(width: 12),
          const Expanded(child: _ExpandedProgress()),
          if (currentTrackPath != null) ...[
            const SizedBox(width: 8),
            Consumer<LibraryService>(
              builder: (context, lib, _) {
                final track = player.currentTrack!;
                final isFav = lib.isFavorite(track);
                return IconButton(
                  tooltip: isFav
                      ? 'Quitar de favoritos'
                      : 'Añadir a canciones favoritas',
                  icon: Icon(
                    isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFav ? c.primary : c.textSecondary,
                    size: 22,
                  ),
                  splashRadius: 20,
                  onPressed: () => lib.toggleFavorite(track),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpandedProgress extends StatelessWidget {
  const _ExpandedProgress();

  String _formatTime(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final max = player.duration.inSeconds.toDouble() > 0
        ? player.duration.inSeconds.toDouble()
        : 1.0;
    return Row(
      children: [
        Text(
          _formatTime(player.position),
          style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
        ),
        Expanded(
          child: Slider(
            value: player.position.inSeconds.toDouble().clamp(0.0, max),
            max: max,
            activeColor: context.colors.primary,
            inactiveColor: context.colors.glassBorder,
            onChanged: (v) => player.seekTo(Duration(seconds: v.toInt())),
          ),
        ),
        Text(
          _formatTime(player.duration),
          style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
        ),
      ],
    );
  }
}
