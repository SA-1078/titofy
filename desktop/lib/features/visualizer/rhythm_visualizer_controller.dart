// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'rhythm_types.dart';
import 'rhythm_physics.dart';
import 'rhythm_sequencer.dart';
import '../../core/services/audio_beat_analysis_service.dart';

export 'rhythm_types.dart';

/// Controlador de simulación rítmica reactiva y dinámica.
///
/// Características avanzadas:
///  * Resortes amortiguados (posición + velocidad) para rebote natural.
///  * Secuenciador rítmico por flancos de semicorchea (independiente de framerate).
///  * Síncopas, notas fantasma y redobles de 4 compases.
///  * Onda de impacto viajando del centro hacia los extremos.
///  * Picos flotantes con gravedad y colorPhase dinámico.
class RhythmVisualizerController extends ChangeNotifier {
  RhythmVisualizerStyle _style = RhythmVisualizerStyle.symmetricBars;
  static const int numSymmetricBars = 64;
  static const int numRadialBars = 52;
  static const int _half = numSymmetricBars ~/ 2;
  double bpm = 126.0;

  // ── Estado de barras ───────────────────────────────────────────────────────
  final List<double> _symmetricBars = List.filled(numSymmetricBars, 0.05);
  final List<double> _symmetricVel = List.filled(numSymmetricBars, 0.0);
  final List<double> _symmetricPeaks = List.filled(numSymmetricBars, 0.05);
  final List<double> _peakHold = List.filled(numSymmetricBars, 0.0);
  final List<double> _peakVel = List.filled(numSymmetricBars, 0.0);
  final List<double> _symTargets = List.filled(_half, 0.0);
  final List<double> _symSeed = List.generate(
    numSymmetricBars,
    (i) => RhythmPhysics.hash(i + 1),
  );
  final List<double> _radialBars = List.filled(numRadialBars, 0.05);
  final List<double> _radialVel = List.filled(numRadialBars, 0.0);
  final List<double> _radialTargets = List.filled(numRadialBars, 0.0);
  final List<double> _radSeed = List.generate(
    numRadialBars,
    (i) => RhythmPhysics.hash(i + 500),
  );
  final List<ShockwaveRipple> _shockwaves = [];

  // ── Pulsos suavizados (0..1) ───────────────────────────────────────────────
  double _bassPulse = 0.0;
  double _snarePulse = 0.0;
  double _hatPulse = 0.0;
  double _energy = 0.0;

  // ── Reloj y golpes ─────────────────────────────────────────────────────────
  double _internalTime = 0.0;
  int _lastStep = -1;
  double _kickT = -100.0, _kickVel = 0.0;
  double _snareT = -100.0, _snareVel = 0.0;
  double _hatT = -100.0, _hatVel = 0.0;
  double _lastAudioTime = -1.0;
  int _audioBeatIndex = 0;
  AudioBeatProfile? _activeAudioProfile;

  // ── Animación de color / giro ──────────────────────────────────────────────
  double _colorPhase = 0.0; // 0..1 para desplazar el tono en el painter
  double _rotation = 0.0; // foco giratorio del modo radial
  Color _accent = const Color(0xFFFF4B72);

  // ── Getters públicos ───────────────────────────────────────────────────────
  RhythmVisualizerStyle get style => _style;
  List<double> get symmetricBars => _symmetricBars;
  List<double> get symmetricPeaks => _symmetricPeaks;
  List<double> get radialBars => _radialBars;
  List<ShockwaveRipple> get shockwaves => _shockwaves;
  double get bassPulse => _bassPulse;
  double get snarePulse => _snarePulse;
  double get hatPulse => _hatPulse;
  double get energy => _energy;
  double get colorPhase => _colorPhase;
  double get rotation => _rotation;
  double get time => _internalTime;
  double get _stepLen => 15.0 / bpm;

  void setStyle(RhythmVisualizerStyle newStyle) {
    if (_style == newStyle) return;
    _style = newStyle;
    notifyListeners();
  }

  void reset() {
    _internalTime = 0.0;
    _lastStep = -1;
    _kickT = _snareT = _hatT = -100.0;
    _lastAudioTime = -1.0;
    _audioBeatIndex = 0;
    _activeAudioProfile = null;
    _bassPulse = _snarePulse = _hatPulse = _energy = 0.0;
    _shockwaves.clear();
    _symmetricBars.fillRange(0, numSymmetricBars, 0.05);
    _symmetricVel.fillRange(0, numSymmetricBars, 0.0);
    _symmetricPeaks.fillRange(0, numSymmetricBars, 0.05);
    _peakHold.fillRange(0, numSymmetricBars, 0.0);
    _peakVel.fillRange(0, numSymmetricBars, 0.0);
    _radialBars.fillRange(0, numRadialBars, 0.05);
    _radialVel.fillRange(0, numRadialBars, 0.0);
    notifyListeners();
  }

  void updateFrame(
    bool isPlaying,
    double dt, {
    int? playbackPositionMs,
    Color? accentColor,
    AudioBeatProfile? audioProfile,
  }) {
    final double d = math.min(math.max(dt, 0.0), 0.05);
    if (d <= 0.0) return;
    if (accentColor != null) _accent = accentColor;

    if (!isPlaying) {
      _updateIdle(d);
      return;
    }

    if (audioProfile != null && playbackPositionMs != null) {
      final trackSec = playbackPositionMs / 1000.0;
      _advanceAudioClock(trackSec);
      _processAudioBeats(audioProfile, trackSec);
      _updateAudioEnvelopes(audioProfile, d, trackSec);
    } else {
      _advanceClock(d, playbackPositionMs);
      _processSteps();
      _updateEnvelopes(d);
    }
    _updateSymmetric(d);
    _updateRadial(d);
    _shockwaves.removeWhere((w) => !w.update(d));

    _colorPhase = (_colorPhase + d * (0.018 + _bassPulse * 0.05)) % 1.0;
    _rotation = (_rotation + d * (0.25 + _energy * 0.85)) % (2 * math.pi);

    notifyListeners();
  }

  void _advanceAudioClock(double trackSec) {
    if (_lastAudioTime >= 0.0 && trackSec < _lastAudioTime - 0.25) {
      _kickT = _snareT = _hatT = -100.0;
      _kickVel = _snareVel = _hatVel = 0.0;
      _audioBeatIndex = 0;
    }
    _internalTime = trackSec;
  }

  void _processAudioBeats(AudioBeatProfile profile, double trackSec) {
    if (!identical(_activeAudioProfile, profile)) {
      _activeAudioProfile = profile;
      _audioBeatIndex = 0;
      _lastAudioTime = -1.0;
    }
    final from = _lastAudioTime < 0.0 ? trackSec - 0.06 : _lastAudioTime;
    while (_audioBeatIndex < profile.beats.length &&
        profile.beats[_audioBeatIndex].time <= from) {
      _audioBeatIndex++;
    }
    while (_audioBeatIndex < profile.beats.length &&
        profile.beats[_audioBeatIndex].time <= trackSec) {
      final event = profile.beats[_audioBeatIndex++];
      _kickT = event.time;
      _kickVel = event.strength;
      _snareT = event.time;
      _snareVel = event.strength * 0.72;
      _hatT = event.time;
      _hatVel = event.strength * 0.45;
      if (event.strength >= 0.72 && _shockwaves.length < 5) {
        _shockwaves.add(
          ShockwaveRipple(
            radius: 80.0,
            maxRadius: 360.0,
            opacity: 0.85 * event.strength,
            color: _accent,
          ),
        );
      }
    }
    _lastAudioTime = trackSec;
  }

  void _updateAudioEnvelopes(AudioBeatProfile profile, double d, double time) {
    final k = RhythmPhysics.env(time, _kickT, _kickVel, 6.0, 0.0);
    final s = RhythmPhysics.env(time, _snareT, _snareVel, 7.5, 0.0);
    final h = RhythmPhysics.env(time, _hatT, _hatVel, 16.0, 0.0);
    _bassPulse = RhythmPhysics.follow(
      _bassPulse,
      math.max(k, profile.lowEnergyAt(time)),
      d,
      45.0,
      8.0,
    );
    _snarePulse = RhythmPhysics.follow(
      _snarePulse,
      math.max(s, profile.energyAt(time) * 0.75),
      d,
      40.0,
      9.0,
    );
    _hatPulse = RhythmPhysics.follow(
      _hatPulse,
      math.max(h, profile.energyAt(time) * 0.35),
      d,
      50.0,
      14.0,
    );
    final target = math.max(profile.energyAt(time), math.max(k, s * 0.85));
    _energy = RhythmPhysics.follow(_energy, target, d, 10.0, 2.2);
  }

  void _advanceClock(double d, int? posMs) {
    _internalTime += d;
    if (posMs != null && posMs >= 0) {
      final double trackSec = posMs / 1000.0;
      final double drift = trackSec - _internalTime;
      if (drift.abs() > 0.6) {
        _internalTime = trackSec;
        _lastStep = (_internalTime / _stepLen).floor();
        _kickT = _snareT = _hatT = -100.0;
      } else {
        _internalTime += drift * (1.0 - math.exp(-2.5 * d));
      }
    }
  }

  void _processSteps() {
    final int step = (_internalTime / _stepLen).floor();
    if (step == _lastStep) return;
    if (step < _lastStep) {
      _lastStep = step;
      return;
    }
    _lastStep = step;
    _triggerStep(step);
  }

  void _triggerStep(int step) {
    final (kick, snare, hat) = RhythmSequencer.triggerStep(step);

    if (kick > 0.0) {
      _kickT = _internalTime;
      _kickVel = kick;
      if (kick >= 0.9 && _shockwaves.length < 5) {
        _shockwaves.add(
          ShockwaveRipple(
            radius: 80.0,
            maxRadius: 360.0,
            opacity: 0.85 * kick,
            color: _accent,
          ),
        );
      }
    }
    if (snare > 0.0) {
      _snareT = _internalTime;
      _snareVel = snare;
    }
    if (hat > 0.0) {
      _hatT = _internalTime;
      _hatVel = hat;
    }
  }

  void _updateEnvelopes(double d) {
    final double k = RhythmPhysics.env(
      _internalTime,
      _kickT,
      _kickVel,
      6.0,
      0.0,
    );
    final double s = RhythmPhysics.env(
      _internalTime,
      _snareT,
      _snareVel,
      7.5,
      0.0,
    );
    final double h = RhythmPhysics.env(
      _internalTime,
      _hatT,
      _hatVel,
      16.0,
      0.0,
    );

    _bassPulse = RhythmPhysics.follow(_bassPulse, k, d, 45.0, 8.0);
    _snarePulse = RhythmPhysics.follow(_snarePulse, s, d, 40.0, 9.0);
    _hatPulse = RhythmPhysics.follow(_hatPulse, h, d, 50.0, 14.0);

    final double eTarget = math.min(1.0, 0.30 + 0.70 * math.max(k, s * 0.85));
    _energy = RhythmPhysics.follow(_energy, eTarget, d, 10.0, 2.2);
  }

  void _updateSymmetric(double d) {
    final double t = _internalTime;
    final double swell =
        0.88 + 0.12 * math.sin(t / (_stepLen * 16.0) * 2 * math.pi);
    final double hatE = RhythmPhysics.env(
      _internalTime,
      _hatT,
      _hatVel,
      16.0,
      0.0,
    );

    for (int i = 0; i < _half; i++) {
      final double p = i / (_half - 1);
      final double seed = _symSeed[i];

      final double kickE = RhythmPhysics.env(
        _internalTime,
        _kickT,
        _kickVel,
        6.0,
        p * 0.075,
      );
      final double snareE = RhythmPhysics.env(
        _internalTime,
        _snareT,
        _snareVel,
        7.5,
        p * 0.03,
      );
      final double bell = math.exp(-RhythmPhysics.pw(p - 0.55, 2.0) / 0.045);

      final double idle =
          0.06 +
          _energy * 0.05 +
          (math.sin(t * (1.6 + seed * 2.4) + seed * 6.283 + p * 5.0) * 0.5 +
                  0.5) *
              (0.03 + _energy * 0.09);

      final double target =
          (kickE * (0.20 + 0.70 * RhythmPhysics.pw(1.0 - p, 1.25)) +
              snareE * bell * 0.80 +
              hatE * (0.10 + 0.45 * p) * (0.5 + seed) +
              idle) *
          swell;

      _symTargets[i] = math.min(1.0, math.max(0.04, target));
    }

    for (int i = 0; i < _half; i++) {
      final double a = _symTargets[math.max(0, i - 1)];
      final double b = _symTargets[math.min(_half - 1, i + 1)];
      final double smooth = _symTargets[i] * 0.6 + (a + b) * 0.2;

      final int leftIdx = _half - 1 - i;
      final int rightIdx = _half + i;
      RhythmPhysics.stepSpring(
        _symmetricBars,
        _symmetricVel,
        leftIdx,
        smooth,
        d,
      );
      _symmetricBars[rightIdx] = _symmetricBars[leftIdx];
      _symmetricVel[rightIdx] = _symmetricVel[leftIdx];
    }

    RhythmPhysics.updatePeaks(
      bars: _symmetricBars,
      peaks: _symmetricPeaks,
      peakHold: _peakHold,
      peakVel: _peakVel,
      count: numSymmetricBars,
      d: d,
    );
  }

  void _updateRadial(double d) {
    final double t = _internalTime;
    final double kickE = RhythmPhysics.env(
      _internalTime,
      _kickT,
      _kickVel,
      5.5,
      0.0,
    );
    final double snareE = RhythmPhysics.env(
      _internalTime,
      _snareT,
      _snareVel,
      7.5,
      0.0,
    );
    final double hatE = RhythmPhysics.env(
      _internalTime,
      _hatT,
      _hatVel,
      16.0,
      0.0,
    );

    for (int i = 0; i < numRadialBars; i++) {
      final double a = (i / numRadialBars) * 2 * math.pi;
      final double seed = _radSeed[i];
      final double spot = RhythmPhysics.pw(
        math.max(0.0, math.cos(a - _rotation * 1.7)),
        3.0,
      );

      final double target =
          kickE * 0.62 +
          snareE * (0.15 + 0.55 * spot) +
          hatE * 0.18 * (0.4 + seed) +
          (math.sin(a * 4.0 + t * 3.2) * 0.5 + 0.5) * (0.04 + _energy * 0.12) +
          spot * _energy * 0.08 +
          0.07;
      _radialTargets[i] = math.min(1.0, math.max(0.04, target));
    }

    for (int i = 0; i < numRadialBars; i++) {
      final double a = _radialTargets[(i - 1 + numRadialBars) % numRadialBars];
      final double b = _radialTargets[(i + 1) % numRadialBars];
      final double smooth = _radialTargets[i] * 0.6 + (a + b) * 0.2;
      RhythmPhysics.stepSpring(_radialBars, _radialVel, i, smooth, d);
    }
  }

  void _updateIdle(double d) {
    final double decay = 1.0 - math.exp(-5.0 * d);
    _bassPulse += (0.0 - _bassPulse) * decay;
    _snarePulse += (0.0 - _snarePulse) * decay;
    _hatPulse += (0.0 - _hatPulse) * decay;
    _energy += (0.0 - _energy) * decay;

    double moved = 0.0;
    for (int i = 0; i < numSymmetricBars; i++) {
      moved += RhythmPhysics.stepSpring(
        _symmetricBars,
        _symmetricVel,
        i,
        0.04,
        d,
      );
    }
    for (int i = 0; i < numRadialBars; i++) {
      moved += RhythmPhysics.stepSpring(_radialBars, _radialVel, i, 0.03, d);
    }
    moved += RhythmPhysics.updatePeaks(
      bars: _symmetricBars,
      peaks: _symmetricPeaks,
      peakHold: _peakHold,
      peakVel: _peakVel,
      count: numSymmetricBars,
      d: d,
    );
    _shockwaves.removeWhere((w) => !w.update(d));

    if (moved < 0.0004 &&
        _shockwaves.isEmpty &&
        _bassPulse < 0.002 &&
        _energy < 0.002) {
      return;
    }
    notifyListeners();
  }
}
