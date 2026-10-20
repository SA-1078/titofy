import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'windows/windows_audio_service.dart';

/// Evento percusivo detectado durante el análisis previo de una pista.
class AudioBeatEvent {
  final double time;
  final double strength;

  const AudioBeatEvent({required this.time, required this.strength});

  Map<String, dynamic> toJson() => {'t': time, 's': strength};

  factory AudioBeatEvent.fromJson(Map<String, dynamic> json) => AudioBeatEvent(
    time: (json['t'] as num).toDouble(),
    strength: (json['s'] as num).toDouble(),
  );
}

/// Perfil temporal compacto usado por los visualizadores.
/// Las muestras están separadas 20 ms y no contienen audio reproducible.
class AudioBeatProfile {
  final double frameDuration;
  final List<double> energy;
  final List<double> lowEnergy;
  final List<AudioBeatEvent> beats;

  const AudioBeatProfile({
    required this.frameDuration,
    required this.energy,
    required this.lowEnergy,
    required this.beats,
  });

  double get duration => energy.length * frameDuration;

  double _sample(List<double> values, double time) {
    if (values.isEmpty) return 0.0;
    final position = (time / frameDuration).clamp(0.0, values.length - 1.0);
    final index = position.floor();
    final next = (index + 1).clamp(0, values.length - 1);
    final fraction = position - index;
    return values[index] + (values[next] - values[index]) * fraction;
  }

  double energyAt(double time) => _sample(energy, time);
  double lowEnergyAt(double time) => _sample(lowEnergy, time);

  Iterable<AudioBeatEvent> eventsBetween(double from, double to) sync* {
    for (final event in beats) {
      if (event.time > from && event.time <= to) yield event;
    }
  }

  Map<String, dynamic> toJson() => {
    'frameDuration': frameDuration,
    'energy': energy,
    'lowEnergy': lowEnergy,
    'beats': beats.map((event) => event.toJson()).toList(),
  };

  factory AudioBeatProfile.fromJson(Map<String, dynamic> json) =>
      AudioBeatProfile(
        frameDuration: (json['frameDuration'] as num).toDouble(),
        energy: (json['energy'] as List)
            .map((v) => (v as num).toDouble())
            .toList(),
        lowEnergy: (json['lowEnergy'] as List)
            .map((v) => (v as num).toDouble())
            .toList(),
        beats: (json['beats'] as List)
            .map(
              (v) =>
                  AudioBeatEvent.fromJson(Map<String, dynamic>.from(v as Map)),
            )
            .toList(),
      );
}

class AudioBeatAnalysisService {
  static const _sampleRate = 2000;
  static const _frameSamples = 40; // 20 ms

  Future<AudioBeatProfile?> analyze(
    String audioSource, {
    String? cacheKeyId,
  }) async {
    final isRemote =
        audioSource.startsWith('http://') || audioSource.startsWith('https://');
    final keyId = cacheKeyId ?? audioSource;

    FileStat? stat;
    if (!isRemote) {
      final file = File(audioSource);
      if (!file.existsSync()) return null;
      stat = await file.stat();
    }

    final cacheFile = await _cacheFile(keyId, stat);
    try {
      if (await cacheFile.exists()) {
        return AudioBeatProfile.fromJson(
          jsonDecode(await cacheFile.readAsString()) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Una caché corrupta se regenera sin afectar la reproducción.
    }

    final ffmpeg = await _resolveFfmpeg();
    if (ffmpeg == null) return null;

    try {
      final process = await Process.start(ffmpeg, [
        '-v',
        'error',
        '-i',
        audioSource,
        '-vn',
        '-ac',
        '1',
        '-ar',
        '$_sampleRate',
        '-f',
        'f32le',
        'pipe:1',
      ]);
      final bytes = await process.stdout.fold<List<int>>(<int>[], (all, chunk) {
        all.addAll(chunk);
        return all;
      });
      await process.stderr.drain();
      final exitCode = await process.exitCode;
      if (exitCode != 0 || bytes.isEmpty) return null;

      final profile = await Isolate.run(
        () => _profileFromPcm(
          Uint8List.fromList(bytes),
          _sampleRate,
          _frameSamples,
        ),
      );
      await cacheFile.parent.create(recursive: true);
      await cacheFile.writeAsString(jsonEncode(profile.toJson()));
      return profile;
    } catch (_) {
      return null;
    }
  }

  Future<File> _cacheFile(String keyId, FileStat? stat) async {
    final root = await getApplicationSupportDirectory();
    final statPart = stat != null
        ? '|${stat.size}|${stat.modified.millisecondsSinceEpoch}'
        : '';
    final key = _stableHash('$keyId$statPart');
    return File(p.join(root.path, 'audio_analysis', '$key.json'));
  }

  Future<String?> _resolveFfmpeg() async {
    if (Platform.isWindows) {
      return WindowsAudioService.resolveFfmpeg();
    }

    // Entorno Linux (Ubuntu / POSIX):
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[
      p.join(exeDir, 'ffmpeg'),
      p.join(exeDir, 'bin', 'ffmpeg'),
      p.join(exeDir, 'backend', 'bin', 'ffmpeg'),
      p.join(Directory.current.path, 'backend', 'bin', 'ffmpeg'),
      p.join(Directory.current.path, 'bin', 'ffmpeg'),
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) return candidate;
    }

    final pathName = Platform.environment['FFMPEG_PATH'];
    if (pathName != null && File(pathName).existsSync()) return pathName;
    try {
      final probe = await Process.run('which', ['ffmpeg']);
      if (probe.exitCode == 0) {
        final resolved = probe.stdout
            .toString()
            .trim()
            .split(RegExp(r'\r?\n'))
            .first;
        if (resolved.isNotEmpty) return resolved;
      }
    } catch (_) {}
    return null;
  }

  static int _stableHash(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash;
  }
}

AudioBeatProfile _profileFromPcm(
  Uint8List bytes,
  int sampleRate,
  int frameSamples,
) {
  final data = bytes.buffer.asFloat32List(
    bytes.offsetInBytes,
    bytes.lengthInBytes ~/ 4,
  );
  final frameDuration = frameSamples / sampleRate;
  final rawEnergy = <double>[];
  final rawLow = <double>[];

  for (
    var offset = 0;
    offset + frameSamples <= data.length;
    offset += frameSamples
  ) {
    var sum = 0.0;
    var lowSum = 0.0;
    for (var i = 0; i < frameSamples; i++) {
      final sample = data[offset + i].abs();
      sum += sample * sample;
      if (i > 0) {
        final diff = (data[offset + i] - data[offset + i - 1]).abs();
        lowSum += diff;
      }
    }
    final rms = mathSqrt(sum / frameSamples);
    // RMS + envolvente de transitorios: barato y suficiente para pulsos visuales.
    final transient = mathSqrt(lowSum / frameSamples);
    rawEnergy.add(rms);
    rawLow.add(rms * 0.72 + transient * 0.28);
  }

  final energy = _normalize(rawEnergy);
  final lowEnergy = _normalize(rawLow);
  final beats = <AudioBeatEvent>[];
  for (var i = 2; i < energy.length - 2; i++) {
    final local = energy[i];
    final average =
        (energy[i - 2] + energy[i - 1] + energy[i + 1] + energy[i + 2]) / 4.0;
    final flux = energy[i] - energy[i - 1];
    final previousBeat = beats.isEmpty ? -1.0 : beats.last.time;
    final time = i * frameDuration;
    if (local > 0.48 &&
        local > average * 1.16 &&
        flux > 0.025 &&
        time - previousBeat >= 0.18) {
      beats.add(AudioBeatEvent(time: time, strength: local.clamp(0.35, 1.0)));
    }
  }
  return AudioBeatProfile(
    frameDuration: frameDuration,
    energy: energy,
    lowEnergy: lowEnergy,
    beats: beats,
  );
}

List<double> _normalize(List<double> values) {
  if (values.isEmpty) return values;
  final sorted = [...values]..sort();
  final floor = sorted[(sorted.length * 0.08).floor()];
  final ceiling = sorted[(sorted.length * 0.96).floor()];
  final range = (ceiling - floor).abs() < 0.00001 ? 1.0 : ceiling - floor;
  return values
      .map((value) => ((value - floor) / range).clamp(0.0, 1.0))
      .toList();
}

double mathSqrt(double value) {
  // Newton-Raphson evita importar dart:math dentro del entrypoint del isolate.
  if (value <= 0) return 0.0;
  var result = value > 1 ? value : 1.0;
  for (var i = 0; i < 8; i++) {
    result = (result + value / result) * 0.5;
  }
  return result;
}
