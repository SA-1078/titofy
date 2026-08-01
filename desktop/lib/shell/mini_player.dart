import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/colors.dart';
import '../core/services/player_service.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final hasMedia = player.currentMedia != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.glassBg.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── Info Track ────────────────────────────────────────────────
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    // Artwork redondeado premium
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder, width: 1.0),
                        boxShadow: [
                          if (hasMedia && player.currentArtwork != null)
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: hasMedia && player.currentArtwork != null
                            ? Image.memory(player.currentArtwork!, fit: BoxFit.cover)
                            : Container(
                                color: AppColors.surfaceHover,
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Título y artista
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasMedia ? (player.currentTitle ?? 'Sin título') : 'Sin reproducción',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasMedia ? (player.currentArtist ?? 'Desconocido') : 'Escoge tu audio favorito',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Controles ─────────────────────────────────────────────────
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PlayerBtn(
                          icon: Icons.shuffle_rounded,
                          onTap: () {},
                        ),
                        const SizedBox(width: 14),
                        _PlayerBtn(
                          icon: Icons.skip_previous_rounded,
                          onTap: player.previous,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        _PlayPauseBtn(
                          isPlaying: player.isPlaying,
                          onTap: player.playPause,
                        ),
                        const SizedBox(width: 14),
                        _PlayerBtn(
                          icon: Icons.skip_next_rounded,
                          onTap: player.next,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        _PlayerBtn(
                          icon: Icons.repeat_rounded,
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _ProgressBar(player: player),
                  ],
                ),
              ),

              // ── Volumen e IA ──────────────────────────────────────────────
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _PlayerBtn(
                      icon: Icons.mic_external_on_rounded,
                      onTap: () {},
                      isActive: true,
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      player.volume > 0.5
                          ? Icons.volume_up_rounded
                          : player.volume > 0
                              ? Icons.volume_down_rounded
                              : Icons.volume_off_rounded,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 80,
                      child: _VolumeSlider(player: player),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── WIDGETS AUXILIARES REDISEÑADOS ───────────────────────────────────────────

class _PlayPauseBtn extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayPauseBtn({required this.isPlaying, required this.onTap});

  @override
  State<_PlayPauseBtn> createState() => _PlayPauseBtnState();
}

class _PlayPauseBtnState extends State<_PlayPauseBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(_hover ? 0.6 : 0.3),
                blurRadius: _hover ? 14 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool isActive;

  const _PlayerBtn({
    required this.icon,
    required this.onTap,
    this.size = 18,
    this.isActive = false,
  });

  @override
  State<_PlayerBtn> createState() => _PlayerBtnState();
}

class _PlayerBtnState extends State<_PlayerBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _hover ? AppColors.glassHover : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: widget.isActive
                ? AppColors.primaryLight
                : _hover
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final PlayerService player;

  const _ProgressBar({required this.player});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          _fmt(player.position),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9, color: AppColors.textSecondary),
        ),
        Expanded(
          child: Container(
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                activeTrackColor: AppColors.primaryLight,
                inactiveTrackColor: AppColors.glassBorder,
                thumbColor: Colors.white,
                overlayColor: AppColors.primaryGlow,
                trackShape: const RectangularSliderTrackShape(),
              ),
              child: Slider(
                value: player.progress.clamp(0.0, 1.0),
                onChanged: (v) {
                  final pos = Duration(
                    milliseconds: (v * player.duration.inMilliseconds).round(),
                  );
                  player.seekTo(pos);
                },
              ),
            ),
          ),
        ),
        Text(
          _fmt(player.duration),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  final PlayerService player;

  const _VolumeSlider({required this.player});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
        activeTrackColor: AppColors.secondary,
        inactiveTrackColor: AppColors.glassBorder,
        thumbColor: Colors.white,
        overlayColor: AppColors.secondaryGlow,
        trackShape: const RectangularSliderTrackShape(),
      ),
      child: Slider(
        value: player.volume.clamp(0.0, 1.0),
        onChanged: player.setVolume,
      ),
    );
  }
}
