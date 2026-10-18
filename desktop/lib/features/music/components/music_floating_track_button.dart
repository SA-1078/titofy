// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/player_service.dart';

/// Botón flotante para localizar y desplazarse suavemente a la canción en reproducción
class MusicFloatingTrackButton extends StatelessWidget {
  final PlayerService player;
  final VoidCallback onTap;

  const MusicFloatingTrackButton({
    super.key,
    required this.player,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (player.currentTrack == null) return const SizedBox.shrink();
    final c = context.colors;

    return Material(
      color: Colors.transparent,
      elevation: 8,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: c.surface.withOpacity(0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: c.primary.withOpacity(0.4), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: c.primary.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  gradient: c.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Ir a canción activa',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  player.currentTrack!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.primary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_downward_rounded,
                size: 14,
                color: c.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
