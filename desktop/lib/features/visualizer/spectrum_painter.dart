import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import 'spectrum_controller.dart';

/// Pintor de Espectro Neón Desktop Premium
/// Cubre el 100% del ancho de la pantalla, con barras redondeadas continuas,
/// resplandor ambiental reactivo al Beat, gradiente de alta fidelidad y sin guiones flotantes.
class SpectrumPainter extends CustomPainter {
  final List<double> levels;
  final List<double> peaks;
  final double beatEnergy;
  final VisualizerTheme theme;
  final SpectrumController? controller;

  SpectrumPainter({
    required this.levels,
    required this.peaks,
    required this.beatEnergy,
    required this.theme,
  }) : controller = null;

  SpectrumPainter.fromController(SpectrumController value)
    : levels = value.levels,
      peaks = value.peaks,
      beatEnergy = value.beatEnergy,
      theme = value.theme,
      controller = value,
      super(repaint: value);

  @override
  void paint(Canvas canvas, Size size) {
    final active = controller;
    final currentLevels = active?.levels ?? levels;
    final currentBeatEnergy = active?.beatEnergy ?? beatEnergy;
    final currentTheme = active?.theme ?? theme;
    if (size.width <= 0 || size.height <= 0 || currentLevels.isEmpty) return;

    final numBars = currentLevels.length;
    const double barSpacing = 3.0;
    // Ocupa el 100% exacto del ancho de la pantalla sin cortes
    final double barWidth = math.max(
      1.5,
      (size.width - ((numBars - 1) * barSpacing)) / numBars,
    );
    final double maxHeight = size.height * 0.84;

    // ── 1. Resplandor Ambiental Reactivo en el Fondo (Beat Glow) ─────────────
    if (currentBeatEnergy > 0.04) {
      final glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.28, size.height * 0.72),
          size.width * 0.50 * (1.0 + currentBeatEnergy * 0.25),
          [
            AppColors.coral.withOpacity(0.28 * currentBeatEnergy),
            const Color(0xFF8B5CF6).withOpacity(0.12 * currentBeatEnergy),
            Colors.transparent,
          ],
          const [0.0, 0.55, 1.0],
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);
    }

    // ── 2. Paletas de Gradiente Premium ──────────────────────────────────────
    List<Color> gradientColors;

    switch (currentTheme) {
      case VisualizerTheme.coralNeon:
        gradientColors = const [
          Color(0xFFFF8EA3), // Rosa neón brillante en la cima
          Color(0xFFFF4B72), // Coral icónico Titofy
          Color(0xFF9333EA), // Púrpura eléctrico
          Color(0xFF3B0764), // Púrpura oscuro en la base
        ];
        break;
      case VisualizerTheme.cyberpunk:
        gradientColors = const [
          Color(0xFF00F0FF), // Cyan neón en la cúspide
          Color(0xFF7000FF), // Púrpura eléctrico
          Color(0xFF2A0845), // Púrpura oscuro base
        ];
        break;
      case VisualizerTheme.rainbow:
        gradientColors = const [
          Color(0xFFFF1744), // Rojo frambuesa en la cima
          Color(0xFFFF9100), // Naranja neón
          Color(0xFFFFEA00), // Amarillo cálido
          Color(0xFF00E676), // Verde esmeralda
          Color(0xFF00E5FF), // Cyan brillante
          Color(0xFF0052D4), // Azul zafiro en la base
        ];
        break;
    }

    // ── 3. Shaders y Pinturas ────────────────────────────────────────────────
    final stops = List.generate(
      gradientColors.length,
      (index) => index / (gradientColors.length - 1),
    );

    final barShader = (currentTheme == VisualizerTheme.rainbow)
        ? ui.Gradient.linear(
            const Offset(0, 0),
            Offset(size.width, 0),
            gradientColors,
            stops,
          )
        : ui.Gradient.linear(
            Offset(0, size.height - maxHeight),
            Offset(0, size.height),
            gradientColors,
            stops,
          );

    final barPaint = Paint()
      ..shader = barShader
      ..style = PaintingStyle.fill;

    // ── 4. Dibujar Barras Neón Agrupadas en un Solo Path para Máximo Rendimiento ──
    final barsPath = Path();
    for (int i = 0; i < numBars; i++) {
      final double x = i * (barWidth + barSpacing);
      final double level = currentLevels[i].clamp(0.015, 1.0);
      final double barH = (level * maxHeight).clamp(4.0, maxHeight);
      final double y = size.height - barH;

      final radius = Radius.circular(math.min(barWidth / 2, 4.0));
      barsPath.addRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, barWidth, barH),
          topLeft: radius,
          topRight: radius,
        ),
      );
    }
    canvas.drawPath(barsPath, barPaint);

    // ── 5. Línea Base Neón de Horizonte ──────────────────────────────────────
    final baseLinePaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(size.width, 0),
        [
          gradientColors.first.withOpacity(0.15),
          gradientColors[gradientColors.length ~/ 2].withOpacity(0.40),
          gradientColors.last.withOpacity(0.15),
        ],
        const [0.0, 0.5, 1.0], // colorStops válido de 3 puntos
      )
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height - 1.0),
      Offset(size.width, size.height - 1.0),
      baseLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant SpectrumPainter oldDelegate) {
    // Cuando el painter está conectado al controller, éste ya llama a paint
    // mediante `repaint`; no hace falta forzar un segundo repintado cuando el
    // widget padre se reconstruye por otra razón.
    if (controller != null &&
        identical(controller, oldDelegate.controller) &&
        oldDelegate.theme == theme) {
      return false;
    }
    return oldDelegate.levels != levels ||
        oldDelegate.peaks != peaks ||
        oldDelegate.beatEnergy != beatEnergy ||
        oldDelegate.theme != theme;
  }
}
