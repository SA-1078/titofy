// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'dart:io';

/// Optimizaciones de rendimiento y renderizado exclusivas para Windows (Direct3D 11 / ANGLE).
class WindowsPerformance {
  /// Retorna un delta de tiempo normalizado y seguro para el bucle de animación en Windows.
  /// En pantallas de alta frecuencia (120Hz, 144Hz, 240Hz en GPUs NVIDIA),
  /// evita saltos bruscos por pausas de GC o demoras del compositor de Windows.
  static double clampDelta(double dt) {
    if (!Platform.isWindows) return dt.clamp(0.001, 0.05);
    return dt.clamp(0.001, 0.033);
  }

  /// Indica si Windows debe usar efectos de sombra y brillo optimizados
  /// para reducir la sobrecarga del rasterizador Direct3D y evitar caídas de FPS.
  static bool get shouldSimplifyDynamicEffects => Platform.isWindows;
}

