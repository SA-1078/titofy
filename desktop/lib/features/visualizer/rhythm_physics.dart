// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'dart:math' as math;

/// Motor de simulación física (resortes amortiguados, gravedad de picos y envolventes)
class RhythmPhysics {
  static double pw(double a, double b) => math.pow(a, b).toDouble();

  /// Pseudoaleatorio determinista en [0,1) a partir de un entero.
  static double hash(int n) {
    final double x = math.sin(n * 12.9898 + 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  /// Envolvente exponencial de un golpe, con retardo opcional.
  static double env(double internalTime, double hitT, double vel, double decay, double delay) {
    final double e = internalTime - hitT - delay;
    if (e < 0.0) return 0.0;
    return vel * math.exp(-e * decay);
  }

  /// Seguimiento asimétrico (ataque rápido y decaimiento controlado)
  static double follow(double cur, double target, double d, double up, double down) {
    final double rate = target > cur ? up : down;
    return cur + (target - cur) * (1.0 - math.exp(-rate * d));
  }

  /// Subida: rápida con leve rebote. Bajada: más suave y sobreamortiguada.
  /// Devuelve cuánto se movió la barra (para detectar reposo).
  static double stepSpring(
      List<double> pos, List<double> vel, int i, double target, double d) {
    double x = pos[i];
    double v = vel[i];
    final double x0 = x;

    final bool up = target > x;
    final double k = up ? 520.0 : 190.0;
    final double c = 2.0 * (up ? 0.62 : 0.88) * math.sqrt(k);
    final double h = d * 0.5; // 2 subpasos: estable aun con cuadros lentos

    for (int s = 0; s < 2; s++) {
      v += (k * (target - x) - c * v) * h;
      x += v * h;
    }

    if (x < 0.02) {
      x = 0.02;
      v = 0.0;
    } else if (x > 1.0) {
      x = 1.0;
      v = 0.0;
    }
    pos[i] = x;
    vel[i] = v;
    return (x - x0).abs();
  }

  /// Picos flotantes con gravedad
  static double updatePeaks({
    required List<double> bars,
    required List<double> peaks,
    required List<double> peakHold,
    required List<double> peakVel,
    required int count,
    required double d,
  }) {
    double moved = 0.0;
    for (int i = 0; i < count; i++) {
      final double level = bars[i];
      final double before = peaks[i];
      if (level >= peaks[i]) {
        peaks[i] = level;
        peakHold[i] = 0.16;
        peakVel[i] = 0.0;
      } else if (peakHold[i] > 0.0) {
        peakHold[i] -= d;
      } else {
        peakVel[i] += 2.6 * d; // gravedad
        peaks[i] -= peakVel[i] * d;
        if (peaks[i] < level) {
          peaks[i] = level;
          peakVel[i] = 0.0;
        }
      }
      moved += (peaks[i] - before).abs();
    }
    return moved;
  }
}
