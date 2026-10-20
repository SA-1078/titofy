// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'dart:io';
import 'package:path/path.dart' as p;

/// Servicio exclusivo para Windows: resolución y optimización de herramientas de audio (FFmpeg).
class WindowsAudioService {
  static String? _cachedFfmpegPath;

  /// Resuelve la ruta absoluta de ffmpeg.exe en Windows comprobando ejecutables locales y del sistema
  static Future<String?> resolveFfmpeg() async {
    if (!Platform.isWindows) return null;
    if (_cachedFfmpegPath != null && File(_cachedFfmpegPath!).existsSync()) {
      return _cachedFfmpegPath;
    }

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final currentDir = Directory.current.path;
    final candidates = <String>[
      // Bundled / Local repo
      p.join(exeDir, 'ffmpeg.exe'),
      p.join(exeDir, 'bin', 'ffmpeg.exe'),
      p.join(exeDir, 'backend', 'bin', 'ffmpeg.exe'),
      p.join(currentDir, 'backend', 'bin', 'ffmpeg.exe'),
      p.join(currentDir, 'bin', 'ffmpeg.exe'),
      p.join(currentDir, '..', 'backend', 'bin', 'ffmpeg.exe'),
      // ProgramData / Chocolatey
      r'C:\ProgramData\chocolatey\bin\ffmpeg.exe',
      // Program Files & Local AppData
      if (Platform.environment['LOCALAPPDATA'] != null) ...[
        p.join(
          Platform.environment['LOCALAPPDATA']!,
          'Programs',
          'Titofy',
          'backend',
          'bin',
          'ffmpeg.exe',
        ),
        p.join(
          Platform.environment['LOCALAPPDATA']!,
          'Microsoft',
          'WinGet',
          'Links',
          'ffmpeg.exe',
        ),
      ],
      if (Platform.environment['ProgramFiles'] != null)
        p.join(Platform.environment['ProgramFiles']!, 'ffmpeg', 'bin', 'ffmpeg.exe'),
      if (Platform.environment['ProgramFiles(x86)'] != null)
        p.join(Platform.environment['ProgramFiles(x86)']!, 'ffmpeg', 'bin', 'ffmpeg.exe'),
      if (Platform.environment['USERPROFILE'] != null)
        p.join(Platform.environment['USERPROFILE']!, 'scoop', 'shims', 'ffmpeg.exe'),
    ];

    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        _cachedFfmpegPath = candidate;
        return candidate;
      }
    }

    final envPath = Platform.environment['FFMPEG_PATH'];
    if (envPath != null && File(envPath).existsSync()) {
      _cachedFfmpegPath = envPath;
      return envPath;
    }

    // Direct system execution check
    try {
      final directProbe = await Process.run('ffmpeg.exe', ['-version']);
      if (directProbe.exitCode == 0) {
        _cachedFfmpegPath = 'ffmpeg.exe';
        return 'ffmpeg.exe';
      }
    } catch (_) {}

    // where.exe query
    try {
      final probe = await Process.run('where.exe', ['ffmpeg.exe'], runInShell: true);
      if (probe.exitCode == 0) {
        final resolved = probe.stdout
            .toString()
            .trim()
            .split(RegExp(r'\r?\n'))
            .first;
        if (resolved.isNotEmpty && File(resolved).existsSync()) {
          _cachedFfmpegPath = resolved;
          return resolved;
        }
      }
    } catch (_) {}

    return null;
  }
}
