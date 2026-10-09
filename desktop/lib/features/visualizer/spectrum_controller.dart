import 'dart:math' as math;
import 'package:flutter/material.dart';

enum VisualizerMode {
  spectrumOnly, // Modo 1: Espectro Neón Desktop Premium (Pantalla Completa 100%)
  hybrid,       // Modo 2: Espectro Neón con Letra Flotante Activa
  lyricsOnly,   // Modo 3: Karaoke Moderno
  cliSpectrum,  // Modo 4: Espectro Terminal ASCII
  cliClassic,   // Modo 5: Letras Consola
}

enum VisualizerTheme {
  coralNeon,    // Tema Titofy Signature (Púrpura Profundo → Violeta → Coral Neón → Rosa)
  cyberpunk,    // Cyberpunk 2077 (Azul Eléctrico → Púrpura Neón → Cyan)
  rainbow,      // Arcoíris Neón Suave de Alta Resolución
}

/// Motor de simulación espectral musical dinámico (30% más rápido, reactivo al ritmo)
/// - Bajos ampliados (+2 barras de potencia y cuerpo contundente).
/// - Medios rítmicos reales (sincronizados con golpes de tarola/caja, acordes y voz).
/// - Agudos nítidos y percusivos (hi-hats en semicorcheas y brillo crisp).
/// - Físicas 30% más rápidas para acompañar canciones enérgicas sin retraso.
class SpectrumController extends ChangeNotifier {
  static const int numBars = 79; // +5 bajos (24), +5 medios (33), +5 agudos (22) = 79 barras 100% pantalla

  final List<double> _currentHeights = List.filled(numBars, 0.05);
  final List<double> _targetHeights = List.filled(numBars, 0.05);
  final List<double> _peaks = List.filled(numBars, 0.05);

  double _beatEnergy = 0.0;
  double _bassPulse = 0.0;
  double _internalTime = 0.0;

  VisualizerMode _mode = VisualizerMode.spectrumOnly;
  VisualizerTheme _theme = VisualizerTheme.coralNeon;

  VisualizerMode get mode => _mode;
  VisualizerTheme get theme => _theme;
  List<double> get levels => _currentHeights;
  List<double> get peaks => _peaks;
  double get beatEnergy => _beatEnergy;
  double get bassPulse => _bassPulse;

  void setMode(VisualizerMode mode) {
    _mode = mode;
    notifyListeners();
  }

  void setTheme(VisualizerTheme theme) {
    _theme = theme;
    notifyListeners();
  }

  /// Actualización frame a frame sincronizada y ultra reactiva
  void updateFrame(bool isPlaying, double dt, {int? playbackPositionMs}) {
    final double clampedDt = math.min(dt, 0.033);

    if (!isPlaying) {
      // Caída rápida hacia el reposo en pausa
      final double decayFactor = 1.0 - math.exp(-6.0 * clampedDt);
      for (int i = 0; i < numBars; i++) {
        _currentHeights[i] += (0.02 - _currentHeights[i]) * decayFactor;
        _peaks[i] = math.max(_currentHeights[i], _peaks[i] - 1.5 * clampedDt);
      }
      _bassPulse = math.max(0.0, _bassPulse - 4.0 * clampedDt);
      _beatEnergy = math.max(0.0, _beatEnergy - 4.0 * clampedDt);
      notifyListeners();
      return;
    }

    // ── 1. AVANCE DE TIEMPO +30% MÁS RÁPIDO Y DINÁMICO ──────────────────────
    // Aumentamos la velocidad de tiempo en un 30% para emparejar el ritmo real
    _internalTime += clampedDt * 1.30;

    if (playbackPositionMs != null && playbackPositionMs > 0) {
      final double trackSec = (playbackPositionMs / 1000.0) * 1.30;
      final double diff = trackSec - _internalTime;
      if (diff.abs() > 0.45) {
        _internalTime = trackSec;
      } else {
        _internalTime += diff * 0.02;
      }
    }

    final double t = _internalTime;

    // ── 2. RITMO COMPLETO: BOMBO (TIEMPOS 1 Y 3) + TAROLA/CAJA (TIEMPOS 2 Y 4)
    // Compás a ~136 BPM (0.441s por tiempo)
    final double beatPhase = (t / 0.441) % 1.0;

    // A) Golpe de Bombo / Kick (Tiempos fuertes)
    final double kickDecay = math.exp(-beatPhase * 4.5);
    final double kickPower = kickDecay > 0.12 ? kickDecay : 0.0;

    if (kickPower > 0.5) {
      _bassPulse = kickPower;
      _beatEnergy = 0.90;
    } else {
      _bassPulse = math.max(0.0, _bassPulse - 4.0 * clampedDt);
      _beatEnergy = math.max(0.0, _beatEnergy - 3.5 * clampedDt);
    }

    // B) Golpe de Tarola / Caja / Snare / Palmas en Medios (Contratiempo 2 y 4)
    final double snarePhase = (t / 0.441 + 0.5) % 1.0;
    final double snareHit = math.exp(-snarePhase * 5.2);

    // C) Hi-Hats en semicorcheas (cada 1/4 de tiempo, ultra crisp y rítmico)
    final double hiHatPhase = (t / 0.110) % 1.0;
    final double hiHatHit = math.exp(-hiHatPhase * 7.5);

    // D) Nota de bajo que camina por la escala musical
    final double bassCenter = 6.0 + 3.5 * math.sin(t * 1.8) + 2.0 * math.cos(t * 0.9);

    // E) Puntos resonantes vocales y melódicos en medios (formantes vivos F1, F2)
    final double vocalF1 = 32.0 + 6.0 * math.sin(t * 2.2);
    final double vocalF2 = 46.0 + 7.0 * math.cos(t * 2.7);

    // ── 3. DISTRIBUCIÓN DE ENERGÍA POR BANDA ────────────────────────────────
    for (int i = 0; i < numBars; i++) {
      double totalTarget = 0.04;

      if (i <= 23) {
        // ── ZONA DE GRAVES (24 BARRAS DE BAJOS: 0 A 23, +5 BARRAS) ───────────
        // Campana más ancha para que todo el bloque de bajos retumbe con impacto
        final double distBass = (i - bassCenter).abs();
        final double bassBell = math.exp(-(distBass * distBass) / 28.0);
        final double bassEnergy = (kickPower * 0.72 + 0.28) * bassBell * 0.94;

        // Sub-bajo sólido ampliado (barras 0 a 8 para presencia contundente)
        final double subBass = i <= 8
            ? (math.sin(t * 4.5 + i * 0.5) * 0.12 + 0.24 + kickPower * 0.35)
            : 0.0;

        totalTarget += bassEnergy + subBass;
        // Techo de graves: 85% a 95% de altura (impacto potente indiscutible)
        totalTarget = totalTarget.clamp(0.08, 0.96);
      } else if (i <= 56) {
        // ── ZONA DE MEDIOS (33 BARRAS DE MEDIOS: 24 A 56, +5 BARRAS) ─────────
        // Los medios reaccionan a los golpes de caja/tarola (snare) y rasgueos
        final double distF1 = (i - vocalF1).abs();
        final double form1 = math.exp(-(distF1 * distF1) / 14.0) * (0.22 + snareHit * 0.18);

        final double distF2 = (i - vocalF2).abs();
        final double form2 = math.exp(-(distF2 * distF2) / 16.0) * (0.18 + kickPower * 0.14);

        // Pulso rítmico en acordes medios (salta con el compás, no ola estática)
        final double rhythmPulse = (math.sin(t * 8.8 + i * 0.35) * 0.5 + 0.5) * (snareHit * 0.18 + 0.06);

        totalTarget += form1 + form2 + rhythmPulse + (kickPower * 0.08);
        // Techo de medios: 28% a 48% (activo, articulado y rítmico)
        totalTarget = totalTarget.clamp(0.06, 0.48);
      } else {
        // ── ZONA DE AGUDOS (22 BARRAS DE AGUDOS: 57 A 78, +5 BARRAS) ─────────
        final double trebleProgress = (i - 57) / 21.0; // 0.0 a 1.0 hacia el extremo derecho

        // Hi-hats rítmicos que chisporrotean y platillos abiertos
        final double hatSparkle = hiHatHit * (0.16 + trebleProgress * 0.10);

        // Brillo aéreo rápido y limpio
        final double airFlicker = (math.sin(t * 14.0 + i * 1.5) * 0.5 + 0.5) * 0.06 * trebleProgress;

        totalTarget += hatSparkle + airFlicker + (snareHit * 0.08);
        // Techo de agudos: 15% a 32% (rápido, nítido y fino)
        totalTarget = totalTarget.clamp(0.04, 0.32);
      }

      _targetHeights[i] = totalTarget;
    }

    // ── 4. DIFUSIÓN LATERAL MODERADA (CONSERVA PICOS RÍTMICOS NÍTIDOS) ──────
    final List<double> diffused = List<double>.from(_targetHeights);
    for (int i = 1; i < numBars - 1; i++) {
      diffused[i] = _targetHeights[i] * 0.60 +
          (_targetHeights[i - 1] + _targetHeights[i + 1]) * 0.20;
    }

    // ── 5. FILTRADO CON VELOCIDAD +30% (ATAQUE Y CAÍDA MÁS RÁPIDOS) ─────────
    for (int i = 0; i < numBars; i++) {
      final double target = diffused[i];
      final bool isBass = i <= 23;
      final bool isTreble = i > 56;

      if (target > _currentHeights[i]) {
        // Ataque +30% más rápido: salto instantáneo y enérgico
        final double attackSpeed = isBass ? 35.0 : (isTreble ? 38.0 : 28.0);
        final double factor = 1.0 - math.exp(-attackSpeed * clampedDt);
        _currentHeights[i] += (target - _currentHeights[i]) * factor;
      } else {
        // Caída +30% más rápida: barras ágiles que no se quedan flotando
        final double decaySpeed = isBass ? 10.5 : (isTreble ? 12.5 : 8.5);
        final double factor = 1.0 - math.exp(-decaySpeed * clampedDt);
        _currentHeights[i] += (target - _currentHeights[i]) * factor;
      }
    }

    notifyListeners();
  }
}
