// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'rhythm_visualizer_controller.dart';

/// Pintor de Barras Neón en Modo Ritmo.
///
/// Mejoras: color que se desplaza con el tiempo y el bombo, brillo (glow) real
/// con blur aplicado una sola vez, picos flotantes, línea de horizonte pulsante
/// y todo en muy pocas llamadas de dibujo (2 paths para todas las barras).
class RhythmSymmetricPainter extends CustomPainter {
  final List<double> bars;
  final List<double>? peaks; // controller.symmetricPeaks
  final double bassPulse;
  final double snarePulse;
  final double energy;
  final double colorPhase; // controller.colorPhase
  final Color primaryColor;
  final bool isDark;
  final RhythmVisualizerController? controller;
  int? _cachedHueKey;
  Color? _cachedMain;
  Color? _cachedPink;
  Color? _cachedPurple;

  /// Pasa el controller aquí (`repaint: controller`) para repintar solo el
  /// canvas en cada cuadro sin reconstruir el widget.
  RhythmSymmetricPainter({
    required this.bars,
    required this.bassPulse,
    required this.energy,
    required this.primaryColor,
    required this.isDark,
    this.peaks,
    this.snarePulse = 0.0,
    this.colorPhase = 0.0,
    super.repaint,
  }) : controller = null;

  RhythmSymmetricPainter.fromController({
    required RhythmVisualizerController value,
    required this.primaryColor,
    required this.isDark,
  }) : bars = value.symmetricBars,
       peaks = value.symmetricPeaks,
       bassPulse = value.bassPulse,
       snarePulse = value.snarePulse,
       energy = value.energy,
       colorPhase = value.colorPhase,
       controller = value,
       super(repaint: value);

  static Color _hueShift(Color c, double deg, {double lightAdd = 0.0}) {
    final hsl = HSLColor.fromColor(c);
    final double h = ((hsl.hue + deg) % 360 + 360) % 360;
    final double l = math.min(1.0, math.max(0.0, hsl.lightness + lightAdd));
    return hsl.withHue(h).withLightness(l).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final active = controller;
    final bars = active?.symmetricBars ?? this.bars;
    final peaks = active?.symmetricPeaks ?? this.peaks;
    final bassPulse = active?.bassPulse ?? this.bassPulse;
    final snarePulse = active?.snarePulse ?? this.snarePulse;
    final energy = active?.energy ?? this.energy;
    final colorPhase = active?.colorPhase ?? this.colorPhase;
    final double w = size.width;
    final double h = size.height;
    final int count = bars.length;
    if (w <= 0 || h <= 0 || count == 0) return;

    // ── Paleta viva: el tono oscila lento y se empuja con el bombo ──────────
    final double hueOff =
        math.sin(colorPhase * 2 * math.pi) * 38.0 + bassPulse * 10.0;
    // El cambio de tono es deliberadamente lento; cuantizarlo a 2 grados
    // evita cuatro conversiones HSL por frame sin que el ojo perciba saltos.
    final int hueKey = (hueOff * 0.5).round();
    if (_cachedHueKey != hueKey || _cachedMain == null) {
      final quantizedHue = hueKey / 0.5;
      _cachedHueKey = hueKey;
      _cachedMain = _hueShift(primaryColor, quantizedHue);
      _cachedPink = _hueShift(
        primaryColor,
        quantizedHue - 22.0,
        lightAdd: 0.12,
      );
      _cachedPurple = _hueShift(const Color(0xFF9333EA), quantizedHue * 0.7);
    }
    final Color main = _cachedMain!;
    final Color pink = _cachedPink!;
    final Color purple = _cachedPurple!;
    const Color deep = Color(0xFF3B0764);

    // ── 1. Resplandor ambiental ─────────────────────────────────────────────
    if (energy > 0.03 || bassPulse > 0.03) {
      final glow = Paint()
        ..shader = ui.Gradient.radial(
          Offset(w * 0.5, h * 0.78),
          w * 0.55 * (1.0 + bassPulse * 0.30),
          [
            main.withValues(
              alpha: math.min(0.5, 0.20 * energy + 0.22 * bassPulse),
            ),
            purple.withValues(alpha: 0.12 * energy),
            purple.withValues(alpha: 0.0),
          ],
          const [0.0, 0.55, 1.0],
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), glow);
    }

    // ── 2. Geometría ────────────────────────────────────────────────────────
    final double spacing = math.max(2.0, w * 0.0028);
    final double barW = math.max(1.8, (w - (count - 1) * spacing) / count);
    final double totalW = count * barW + (count - 1) * spacing;
    final double x0 = (w - totalW) / 2;
    final double maxH = h * 0.84;
    final double corner = math.min(barW / 2, 5.0);
    final Radius radius = Radius.circular(corner);

    final Path barsPath = Path();
    final Path capsPath = Path();
    final bool hasPeaks = peaks != null && peaks.length == count;
    const double capH = 3.0;
    const double capGap = 3.0;

    for (int i = 0; i < count; i++) {
      final double x = x0 + i * (barW + spacing);
      final double level = math.min(1.0, math.max(0.015, bars[i]));
      final double barH = math.min(maxH, math.max(4.0, level * maxH));

      barsPath.addRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, h - barH, barW, barH),
          topLeft: radius,
          topRight: radius,
        ),
      );

      // Pico flotante (o cresta pegada a la barra si no hay datos de picos).
      final double peakLevel = hasPeaks ? peaks[i] : level;
      if (peakLevel > 0.08) {
        final double peakH = math.min(maxH, peakLevel * maxH);
        final double gap = hasPeaks ? capGap : 0.0;
        final double cy = h - peakH - gap - capH;
        final double capW = barW * 0.85;
        capsPath.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + (barW - capW) / 2, cy, capW, capH),
            const Radius.circular(1.5),
          ),
        );
      }
    }

    // ── 3. Glow ligero sin MaskFilter ───────────────────────────────────────
    // Un blur sobre el path completo de 64 barras fuerza una pasada de
    // rasterizado costosa, especialmente en Linux. El relleno translúcido
    // conserva el halo visual sin crear una superficie desenfocada por frame.
    final double glowA =
        (0.10 + bassPulse * 0.40 + snarePulse * 0.12) * (isDark ? 1.0 : 0.6);
    canvas.drawPath(
      barsPath,
      Paint()
        ..color = main.withValues(alpha: math.min(0.6, glowA))
        ..blendMode = isDark ? BlendMode.plus : BlendMode.srcOver,
    );

    // ── 4. Relleno: gradiente horizontal de color + sombreado vertical ──────
    canvas.drawPath(
      barsPath,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(w, 0),
          [purple, main, pink, main, purple],
          const [0.0, 0.25, 0.5, 0.75, 1.0],
        ),
    );

    canvas.drawPath(
      barsPath,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = ui.Gradient.linear(
          Offset(0, h - maxH),
          Offset(0, h),
          [
            Colors.white.withValues(alpha: 0.22 + snarePulse * 0.15),
            Colors.white.withValues(alpha: 0.0),
            deep.withValues(alpha: 0.0),
            deep.withValues(alpha: isDark ? 0.65 : 0.35),
          ],
          const [0.0, 0.25, 0.55, 1.0],
        ),
    );

    // ── 5. Picos ────────────────────────────────────────────────────────────
    canvas.drawPath(
      capsPath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.92)
            : _hueShift(
                primaryColor,
                hueOff,
                lightAdd: -0.15,
              ).withValues(alpha: 0.95),
    );

    // ── 6. Línea de horizonte pulsante ──────────────────────────────────────
    final Shader lineShader = ui.Gradient.linear(
      const Offset(0, 0),
      Offset(w, 0),
      [
        pink.withValues(alpha: 0.15),
        main.withValues(alpha: math.min(1.0, 0.50 + bassPulse * 0.4)),
        pink.withValues(alpha: 0.15),
      ],
      const [0.0, 0.5, 1.0],
    );
    final Offset a = Offset(0, h - 1.0);
    final Offset b = Offset(w, h - 1.0);

    // El glow de las barras ya usa un único blur. Evitamos un segundo
    // MaskFilter dinámico sobre toda la pantalla para no penalizar el
    // compositor Linux en cada frame.
    canvas.drawLine(
      a,
      b,
      Paint()
        ..shader = lineShader
        ..strokeWidth = 1.6 + bassPulse * 1.2
        ..style = PaintingStyle.stroke,
    );
  }

  // `bars` es una lista mutable compartida: comparar campos no detectaría
  // cambios, así que se repinta siempre (barato: pocas llamadas de dibujo).
  @override
  bool shouldRepaint(covariant RhythmSymmetricPainter oldDelegate) {
    if (controller != null &&
        identical(controller, oldDelegate.controller) &&
        oldDelegate.primaryColor == primaryColor &&
        oldDelegate.isDark == isDark) {
      return false;
    }
    return oldDelegate.bars != bars ||
        oldDelegate.peaks != peaks ||
        oldDelegate.bassPulse != bassPulse ||
        oldDelegate.energy != energy ||
        oldDelegate.colorPhase != colorPhase;
  }
}
