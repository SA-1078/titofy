import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'rhythm_visualizer_controller.dart';

/// Pintor de Ondas de Choque Radiales y Anillo Orbital de 360 Grados
/// Las ondas de choque se expanden concéntricamente al compás de cada golpe del bombo
class RhythmRadialPainter extends CustomPainter {
  final List<double> radialBars;
  final List<ShockwaveRipple> shockwaves;
  final double bassPulse;
  final double energy;
  final Color primaryColor;
  final double centerRadius;
  final bool isDark;
  final RhythmVisualizerController? controller;
  final List<Color> _barPalette;

  static final List<double> _cosAngles = List<double>.generate(
    RhythmVisualizerController.numRadialBars,
    (i) =>
        math.cos((i / RhythmVisualizerController.numRadialBars) * 2 * math.pi),
  );
  static final List<double> _sinAngles = List<double>.generate(
    RhythmVisualizerController.numRadialBars,
    (i) =>
        math.sin((i / RhythmVisualizerController.numRadialBars) * 2 * math.pi),
  );

  static List<Color> _buildPalette(Color primary) => List<Color>.generate(
    32,
    (i) => Color.lerp(
      primary.withOpacity(0.55),
      Colors.white,
      0.35 + (i / 31.0) * 0.45,
    )!,
  );

  RhythmRadialPainter({
    required this.radialBars,
    required this.shockwaves,
    required this.bassPulse,
    required this.energy,
    required this.primaryColor,
    required this.centerRadius,
    required this.isDark,
  }) : controller = null,
       _barPalette = _buildPalette(primaryColor);

  RhythmRadialPainter.fromController({
    required RhythmVisualizerController value,
    required this.primaryColor,
    required this.centerRadius,
    required this.isDark,
  }) : radialBars = value.radialBars,
       shockwaves = value.shockwaves,
       bassPulse = value.bassPulse,
       energy = value.energy,
       controller = value,
       _barPalette = _buildPalette(primaryColor),
       super(repaint: value);

  @override
  void paint(Canvas canvas, Size size) {
    final active = controller;
    final radialBars = active?.radialBars ?? this.radialBars;
    final shockwaves = active?.shockwaves ?? this.shockwaves;
    final bassPulse = active?.bassPulse ?? this.bassPulse;
    final energy = active?.energy ?? this.energy;
    if (size.width <= 0 || size.height <= 0) return;

    final Offset center = Offset(size.width / 2, size.height / 2);

    // ── 1. Resplandor Ambiental Radial de Fondo (Pulse Aura) ────────────────
    if (energy > 0.04) {
      final glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          centerRadius * (1.8 + bassPulse * 0.6),
          [
            primaryColor.withOpacity(0.35 * energy),
            const Color(0xFF9333EA).withOpacity(0.12 * energy),
            Colors.transparent,
          ],
          const [0.0, 0.6, 1.0],
        );
      canvas.drawCircle(
        center,
        centerRadius * (2.2 + bassPulse * 0.6),
        glowPaint,
      );
    }

    // ── 2. Ondas de Choque Concéntricas Expansivas (Shockwave Ripples) ───────
    for (final wave in shockwaves) {
      if (wave.radius > centerRadius) {
        final double waveProgress =
            ((wave.radius - centerRadius) / (wave.maxRadius - centerRadius))
                .clamp(0.0, 1.0);
        final double strokeW = math.max(1.5, 4.5 * (1.0 - waveProgress));

        final Paint ripplePaint = Paint()
          ..color = wave.color.withOpacity(
            (wave.opacity * 0.75).clamp(0.0, 1.0),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW;

        canvas.drawCircle(center, wave.radius, ripplePaint);
      }
    }

    // ── 3. Anillo Base Perimetral (Orbital Ring Rim) ─────────────────────────
    final Paint ringPaint = Paint()
      ..color = primaryColor.withOpacity(0.4 + bassPulse * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, centerRadius + 2.0, ringPaint);

    // ── 4. Barras Radiales en 360 Grados (Solar EQ Rays) ───────────────────
    final int count = radialBars.length;
    if (count == 0) return;

    const double maxBarLen = 54.0;
    final Paint barPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < count; i++) {
      final double level = radialBars[i].clamp(0.05, 1.0);
      final double barLength = (maxBarLen * level) * (0.8 + bassPulse * 0.35);

      final double cosA = _cosAngles[i];
      final double sinA = _sinAngles[i];

      final Offset innerPt = Offset(
        center.dx + cosA * (centerRadius + 6.0),
        center.dy + sinA * (centerRadius + 6.0),
      );

      final Offset outerPt = Offset(
        center.dx + cosA * (centerRadius + 6.0 + barLength),
        center.dy + sinA * (centerRadius + 6.0 + barLength),
      );

      // Un color interpolado por barra conserva el efecto de brillo sin crear
      // un shader lineal nuevo para cada una de las 52 barras por frame.
      barPaint.strokeWidth = math.max(
        2.0,
        (2 * math.pi * centerRadius / count) * 0.65,
      );
      barPaint.shader = null;
      barPaint.color = _barPalette[(level * 31).round().clamp(0, 31)];

      canvas.drawLine(innerPt, outerPt, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RhythmRadialPainter oldDelegate) {
    if (controller != null &&
        identical(controller, oldDelegate.controller) &&
        oldDelegate.primaryColor == primaryColor &&
        oldDelegate.isDark == isDark &&
        oldDelegate.centerRadius == centerRadius) {
      return false;
    }
    return oldDelegate.radialBars != radialBars ||
        oldDelegate.shockwaves != shockwaves ||
        oldDelegate.bassPulse != bassPulse ||
        oldDelegate.energy != energy;
  }
}
