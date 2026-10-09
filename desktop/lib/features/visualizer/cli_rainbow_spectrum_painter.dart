import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Dibuja el espectro de bloques arcoíris con picos de retención (Peak Hold)
/// Optimizado a 60 FPS sin filtros de máscara pesados ni allocations por frame.
class CliRainbowSpectrumPainter extends CustomPainter {
  final List<double> levels;
  final List<double> peaks;
  final double beatEnergy;

  // Paleta arcoíris idéntica al visualizador de la CLI precompilada
  static const List<Color> _rainbowColors = [
    Color(0xFF0077FF), // Azul en la base
    Color(0xFF00B0FF), // Deep Cyan
    Color(0xFF00E5FF), // Cyan neón
    Color(0xFF00E676), // Verde esmeralda
    Color(0xFF76FF03), // Lima
    Color(0xFFFFEA00), // Amarillo
    Color(0xFFFFAB00), // Ámbar
    Color(0xFFFF6D00), // Naranja
    Color(0xFFFF1744), // Rojo neón en la cima
  ];

  static final List<Paint> _cachedBlockPaints = _rainbowColors
      .map((c) => Paint()..color = c..style = PaintingStyle.fill)
      .toList();

  static final Paint _peakPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  static final Paint _peakAuraPaint = Paint()
    ..color = const Color(0x66FFFFFF) // Brillo translúcido sin Blur para máxima fluidez
    ..style = PaintingStyle.fill;

  const CliRainbowSpectrumPainter({
    required this.levels,
    required this.peaks,
    required this.beatEnergy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || levels.isEmpty) return;

    const int maxRows = 16;
    const double rowSpacing = 2.0;
    final double blockHeight = ((size.height - (maxRows * rowSpacing)) / maxRows).clamp(3.0, 14.0);
    const double colSpacing = 3.5;

    final int numCols = math.min(levels.length, 52);
    final double totalSpacing = (numCols - 1) * colSpacing;
    final double colWidth = ((size.width - totalSpacing) / numCols).clamp(3.0, 18.0);

    final int paletteLen = _cachedBlockPaints.length;

    for (int col = 0; col < numCols; col++) {
      final double x = col * (colWidth + colSpacing);
      final double level = levels[col].clamp(0.02, 1.0);
      final int activeRows = (level * maxRows).round().clamp(1, maxRows);

      // ── Bloques de color arcoíris optimizados con pinturas en caché ─────────
      for (int r = 0; r < activeRows; r++) {
        final int colorIdx = ((r / (maxRows - 1)) * (paletteLen - 1)).round().clamp(0, paletteLen - 1);
        final double y = size.height - ((r + 1) * (blockHeight + rowSpacing));
        canvas.drawRect(Rect.fromLTWH(x, y, colWidth, blockHeight), _cachedBlockPaints[colorIdx]);
      }

      // ── Pico blanco de retención (Peak hold) ultra fluido ───────────────────
      final double peak = peaks[col].clamp(0.02, 1.0);
      final int peakRow = (peak * maxRows).round().clamp(1, maxRows);
      final double peakY = (size.height - (peakRow * (blockHeight + rowSpacing)) - blockHeight - 2.0)
          .clamp(0.0, size.height - 4.0);
      final double peakH = math.max(3.0, blockHeight * 0.75);

      // Aura sin shaders pesados y barra nítida
      canvas.drawRect(Rect.fromLTWH(x - 0.75, peakY - 0.75, colWidth + 1.5, peakH + 1.5), _peakAuraPaint);
      canvas.drawRect(Rect.fromLTWH(x, peakY, colWidth, peakH), _peakPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CliRainbowSpectrumPainter oldDelegate) => true;
}
