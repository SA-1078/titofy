// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Estilos disponibles dentro del Modo Ritmo
enum RhythmVisualizerStyle {
  symmetricBars,   // Ecualizador simétrico: ondas que salen del centro hacia los bordes
  radialShockwave, // Anillo orbital con ondas de choque y foco giratorio
}

/// Onda de choque concéntrica expansiva (modo radial)
class ShockwaveRipple {
  double radius;
  final double startRadius;
  final double maxRadius;
  double opacity;
  final Color color;

  ShockwaveRipple({
    required this.radius,
    required this.maxRadius,
    required this.opacity,
    required this.color,
  }) : startRadius = radius;

  /// 0.0 (recién nacida) a 1.0 (en el borde). Útil para engrosar/afinar el trazo.
  double get progress =>
      ((radius - startRadius) / (maxRadius - startRadius)).clamp(0.0, 1.0);

  bool update(double dt) {
    // Ease-out: arranca rápido y se frena suave, sin cortarse de golpe.
    radius += (maxRadius - radius) * 2.4 * dt + 70.0 * dt;
    opacity = math.max(0.0, opacity - 0.95 * dt);
    return opacity > 0.01 && radius < maxRadius - 0.5;
  }
}
