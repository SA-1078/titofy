// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'rhythm_physics.dart';

/// Secuenciador rítmico determinista con síncopas, notas fantasma y redobles
class RhythmSequencer {
  /// Evalúa el compás y semicorchea para calcular la intensidad de bombo, caja y hi-hat
  static (double kick, double snare, double hat) triggerStep(int step) {
    final int bar = step ~/ 16;
    final int s = step % 16;
    final double r = RhythmPhysics.hash(step);
    final double r2 = RhythmPhysics.hash(step + 9973);
    final bool fill = bar % 4 == 3 && s >= 12;

    double kick = 0.0;
    double snare = 0.0;
    double hat = 0.0;

    // Bombo: tiempos 1 y 3 fijos, síncopas dinámicas
    if (s == 0) {
      kick = 1.0;
    } else if (s == 8) {
      kick = 0.92;
    } else if ((s == 6 || s == 10 || s == 14) && r < 0.30) {
      kick = 0.62 + r2 * 0.2;
    }

    // Tarola: contratiempos 2 y 4 con redoble al final de la frase
    if (s == 4 || s == 12) {
      snare = 0.88 + r * 0.12;
    } else if (fill) {
      snare = 0.55 + (s - 12) * 0.14;
    } else if (s == 15 && r < 0.25) {
      snare = 0.40;
    }

    // Hi-hat: corcheas acentuadas y semicorcheas aleatorias
    if (s % 2 == 0) {
      hat = (s % 4 == 2) ? 0.85 : 0.55;
    } else if (r2 < 0.35) {
      hat = 0.30 + r * 0.15;
    }

    return (kick, snare, hat);
  }
}
