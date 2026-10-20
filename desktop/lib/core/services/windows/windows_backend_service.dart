// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Servicio exclusivo para Windows: gestiona el ciclo de vida, directorios _MEI,
/// sincronización de archivos y parcheo en caliente de FastAPI / faster-whisper.
class WindowsBackendService {
  static final WindowsBackendService _instance = WindowsBackendService._internal();
  factory WindowsBackendService() => _instance;
  WindowsBackendService._internal();

  /// Sincroniza archivos actualizados a las carpetas temporales _MEI de PyInstaller
  /// y aplica el parche para vad y kwargs en faster_whisper.
  void syncAndPatchMei(String backendDir) {
    if (!Platform.isWindows) return;
    try {
      final tempDir = Directory.systemTemp;
      final meiDirs = tempDir
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.contains('_MEI'))
          .toList()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      if (meiDirs.isEmpty) return;

      final filesToSync = [
        'whisper_engine/transcribe.py',
        'whisper_engine/loader.py',
        'whisper_engine/cache.py',
        'whisper_engine/align.py',
        'lyrics/resolver.py',
        'server/tasks.py',
        'server/process.py',
        'windows/__init__.py',
        'windows/whisper_patch.py',
        'windows/process.py',
        'windows/dll_setup.py',
        'api_server.py',
        'config.yaml',
      ];

      for (final targetMei in meiDirs.take(5)) {
        for (final relPath in filesToSync) {
          final src = File('$backendDir/$relPath');
          final dst = File('${targetMei.path}/$relPath');
          if (src.existsSync()) {
            try {
              if (!dst.parent.existsSync()) {
                dst.parent.createSync(recursive: true);
              }
              src.copySync(dst.path);
            } catch (_) {}
          }
          if (relPath.endsWith('.py')) {
            final baseName = relPath.split('/').last.replaceAll('.py', '');
            final pyDir = dst.parent.path;
            final cacheDir = Directory('$pyDir/__pycache__');
            if (cacheDir.existsSync()) {
              try {
                for (final f in cacheDir.listSync().whereType<File>()) {
                  if (f.path.contains(baseName) && f.path.endsWith('.pyc')) {
                    f.deleteSync();
                  }
                }
              } catch (_) {}
            }
          }
        }

      }
      debugPrint('[WindowsBackendService] Código y parches sincronizados en _MEI');
    } catch (e) {
      debugPrint('[WindowsBackendService] Aviso al sincronizar _MEI: $e');
    }
  }

  /// Activa el parche en RAM en api_server.exe forzando la recarga de resolver.py
  Future<void> warmupWindowsPatches(String baseUrl, http.Client client) async {
    if (!Platform.isWindows) return;
    try {
      await client
          .post(
            Uri.parse('$baseUrl/lyrics/resolve'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'title': '__titofy_warmup__',
              'artist': '__titofy_warmup__',
              'mode': 'online_only',
            }),
          )
          .timeout(const Duration(milliseconds: 1200));
    } catch (_) {}
    debugPrint('[WindowsBackendService] Parche en memoria activado en api_server.exe');
  }

  /// Libera el puerto en Windows terminando procesos huérfanos
  Future<void> freePort(int port) async {
    if (!Platform.isWindows) return;
    try {
      final res = await Process.run('cmd', ['/c', 'netstat -ano | findstr :$port']);
      if (res.exitCode == 0 && res.stdout.toString().isNotEmpty) {
        for (final line in res.stdout.toString().split('\n')) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length >= 5 && parts.contains('LISTENING')) {
            final pidStr = parts.last;
            final orphanPid = int.tryParse(pidStr);
            if (orphanPid != null && orphanPid != pid) {
              await Process.run('taskkill', ['/F', '/PID', pidStr]);
            }
          }
        }
      }
    } catch (_) {}
  }

  /// Resuelve la ruta del directorio backend en Windows buscando en instaladores y rutas locales
  String? resolveBackendDirectory() {
    if (!Platform.isWindows) return null;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final currentDir = Directory.current.path;
    final candidates = [
      if (Platform.environment['LOCALAPPDATA'] != null)
        '${Platform.environment['LOCALAPPDATA']}/Programs/Titofy/backend',
      '$exeDir/backend',
      exeDir,
      '$exeDir/../backend',
      '$currentDir/backend',
      currentDir,
      '$currentDir/../backend',
      '$currentDir/../../backend',
    ];

    for (final c in candidates) {
      final script = File('$c/api_server.py');
      final exe = File('$c/api_server.exe');
      if (script.existsSync() || exe.existsSync()) return Directory(c).absolute.path;
    }
    return null;
  }

  /// Resuelve el ejecutable de Python en Windows (.venv local o del sistema)
  String resolvePythonExecutable(String backendDir) {
    final envPython = Platform.environment['PYTHON'];
    if (envPython != null && File(envPython).existsSync()) return envPython;

    final venvBin = '$backendDir/.venv/Scripts/python.exe';
    if (File(venvBin).existsSync()) return venvBin;

    final venvAlt = '$backendDir/venv/Scripts/python.exe';
    if (File(venvAlt).existsSync()) return venvAlt;

    return 'python.exe';
  }

  /// Inicia api_server.exe en Windows con aislamiento y watchdog de proceso padre
  Future<Process?> startBackendProcess(String backendDir, int parentPid) async {
    if (!Platform.isWindows) return null;
    final exeServer = File('$backendDir/api_server.exe');
    if (!exeServer.existsSync()) return null;

    return await Process.start(
      exeServer.path,
      ['--parent-pid', parentPid.toString()],
      workingDirectory: backendDir,
      environment: {
        'PYTHONPATH': backendDir,
        'PYTHONUNBUFFERED': '1',
      },
      mode: ProcessStartMode.normal,
    );
  }

  /// Inicia el backend completo en Windows (usando el ejecutable autónomo o Python local)
  Future<Process?> startWindowsBackend({
    required String backendDir,
    required int parentPid,
    required void Function(String line) onStdout,
    required void Function(String line) onStderr,
    required void Function(int exitCode) onExit,
  }) async {
    if (!Platform.isWindows) return null;

    final exeServer = File('$backendDir/api_server.exe');
    Process? process;

    if (exeServer.existsSync()) {
      debugPrint('[WindowsBackendService] Iniciando ejecutable autónomo api_server.exe...');
      process = await startBackendProcess(backendDir, parentPid);
      Future.delayed(
        const Duration(milliseconds: 1500),
        () => syncAndPatchMei(backendDir),
      );
    } else {
      final pythonBin = resolvePythonExecutable(backendDir);
      final serverScript = '$backendDir/api_server.py';
      final venvDir = '$backendDir/.venv';
      final venvBinDir = '$backendDir\\.venv\\Scripts';

      debugPrint('[WindowsBackendService] Iniciando backend Python: $pythonBin (cwd: $backendDir)');

      process = await Process.start(
        pythonBin,
        ['-u', serverScript, '--parent-pid', parentPid.toString()],
        workingDirectory: backendDir,
        environment: {
          'VIRTUAL_ENV': venvDir,
          'PATH': '$venvBinDir;${Platform.environment['PATH'] ?? ''}',
          'PYTHONPATH': backendDir,
          'PYTHONUNBUFFERED': '1',
        },
        mode: ProcessStartMode.normal,
      );
    }

    if (process != null) {
      process.stdout.transform(utf8.decoder).listen((data) => onStdout(data));
      process.stderr.transform(utf8.decoder).listen((data) => onStderr(data));
      process.exitCode.then((code) => onExit(code));
    }

    return process;
  }
}

