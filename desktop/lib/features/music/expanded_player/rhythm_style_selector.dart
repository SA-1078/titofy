// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../visualizer/rhythm_visualizer_controller.dart';

/// Barra de selección de subtipo de visualizador rítmico (Barras Simétricas vs Onda Radial)
class RhythmStyleSelector extends StatelessWidget {
  final RhythmVisualizerStyle currentStyle;
  final ValueChanged<RhythmVisualizerStyle> onStyleSelected;

  const RhythmStyleSelector({
    super.key,
    required this.currentStyle,
    required this.onStyleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.glassBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChip(
            label: 'Barras Neón',
            icon: Icons.equalizer_rounded,
            isSelected: currentStyle == RhythmVisualizerStyle.symmetricBars,
            onTap: () => onStyleSelected(RhythmVisualizerStyle.symmetricBars),
            c: c,
          ),
          _buildChip(
            label: 'Onda Radial 360°',
            icon: Icons.album_rounded,
            isSelected: currentStyle == RhythmVisualizerStyle.radialShockwave,
            onTap: () => onStyleSelected(RhythmVisualizerStyle.radialShockwave),
            c: c,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeColors c,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? c.primary.withOpacity(0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? c.primary.withOpacity(0.4) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? c.primary : c.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? c.textPrimary : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
