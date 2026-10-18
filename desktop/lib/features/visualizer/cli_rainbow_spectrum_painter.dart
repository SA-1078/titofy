import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'spectrum_controller.dart';

/// Dibuja el espectro de bloques arcoíris con picos de retención (Peak Hold)
/// Optimizado a 60 FPS sin filtros de máscara pesados ni allocations por frame.
class CliRainbowSpectrumPainter extends CustomPainter {
  final List<double> levels;
  final List<double> peaks;
  final double beatEnergy;
  final SpectrumController? controller;

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
  }) : controller = null;

  CliRainbowSpectrumPainter.fromController(SpectrumController value)
      : levels = value.levels,
        peaks = value.peaks,
        beatEnergy = value.beatEnergy,
        controller = value,
        super(repaint: value);

  @override
  void paint(Canvas canvas, Size size) {
    final active = controller;
    final currentLevels = active?.levels ?? levels;
    final currentPeaks = active?.peaks ?? peaks;
    if (size.width <= 0 || size.height <= 0 || currentLevels.isEmpty) return;

    const int maxRows = 16;
    const double rowSpacing = 2.0;
    final double blockHeight = ((size.height - (maxRows * rowSpacing)) / maxRows).clamp(3.0, 14.0);
    const double colSpacing = 3.5;

    final int numCols = math.min(currentLevels.length, 52);
    final double totalSpacing = (numCols - 1) * colSpacing;
    final double colWidth = ((size.width - totalSpacing) / numCols).clamp(3.0, 18.0);

    final int paletteLen = _cachedBlockPaints.length;
    final blockPaths = List<Path>.generate(paletteLen, (_) => Path());
    final peakPath = Path();
    final peakAuraPath = Path();

    for (int col = 0; col < numCols; col++) {
      final double x = col * (colWidth + colSpacing);
      final double level = currentLevels[col].clamp(0.02, 1.0);
      final int activeRows = (level * maxRows).round().clamp(1, maxRows);

      // ── Bloques de color arcoíris optimizados con pinturas en caché ─────────
      for (int r = 0; r < activeRows; r++) {
        final int colorIdx = ((r / (maxRows - 1)) * (paletteLen - 1)).round().clamp(0, paletteLen - 1);
        final double y = size.height - ((r + 1) * (blockHeight + rowSpacing));
        blockPaths[colorIdx].addRect(Rect.fromLTWH(x, y, colWidth, blockHeight));
      }

      // ── Pico blanco de retención (Peak hold) ultra fluido ───────────────────
      final double peak = currentPeaks[col].clamp(0.02, 1.0);
      final int peakRow = (peak * maxRows).round().clamp(1, maxRows);
      final double peakY = (size.height - (peakRow * (blockHeight + rowSpacing)) - blockHeight - 2.0)
          .clamp(0.0, size.height - 4.0);
      final double peakH = math.max(3.0, blockHeight * 0.75);

      // Aura sin shaders pesados y barra nítida
      peakAuraPath.addRect(Rect.fromLTWH(x - 0.75, peakY - 0.75, colWidth + 1.5, peakH + 1.5));
      peakPath.addRect(Rect.fromLTWH(x, peakY, colWidth, peakH));
    }

    // Un drawPath por color sustituye cientos de drawRect por frame.
    for (int colorIdx = 0; colorIdx < paletteLen; colorIdx++) {
      canvas.drawPath(blockPaths[colorIdx], _cachedBlockPaints[colorIdx]);
    }
    canvas.drawPath(peakAuraPath, _peakAuraPaint);
    canvas.drawPath(peakPath, _peakPaint);
  }

  @override
  bool shouldRepaint(covariant CliRainbowSpectrumPainter oldDelegate) => true;
}
