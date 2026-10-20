import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'windows/windows_backend_service.dart';

/// Administra la localización del entorno, detección de Python/.venv y ciclo de vida del proceso FastAPI
class BackendProcessManager {
  Process? _backendProcess;
  String? _lastErrorMessage;

  Process? get backendProcess => _backendProcess;
  String? get lastErrorMessage => _lastErrorMessage;

  String? resolveBackendDirectory() {
    if (Platform.isWindows) {
      return WindowsBackendService().resolveBackendDirectory();
    }

    // Rutas estándar para Linux (Ubuntu / POSIX)
    final home = Platform.environment['HOME'] ?? '';
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final currentDir = Directory.current.path;
    final candidates = [
      '$exeDir/backend',
      exeDir,
      '$exeDir/../backend',
      '$currentDir/backend',
      currentDir,
      '$currentDir/../backend',
      if (home.isNotEmpty) '$home/.local/share/titofy/backend',
      if (home.isNotEmpty) '$home/Documentos/titofy/backend',
    ];

    for (final c in candidates) {
      final script = File('$c/api_server.py');
      if (script.existsSync()) return Directory(c).absolute.path;
    }
    return null;
  }

  String resolvePythonExecutable(String backendDir) {
    if (Platform.isWindows) {
      return WindowsBackendService().resolvePythonExecutable(backendDir);
    }

    // Linux / Ubuntu:
    final envPython = Platform.environment['PYTHON'];
    if (envPython != null && File(envPython).existsSync()) return envPython;

    final venvBin = '$backendDir/.venv/bin/python';
    if (File(venvBin).existsSync()) return venvBin;

    final venvAlt = '$backendDir/venv/bin/python';
    if (File(venvAlt).existsSync()) return venvAlt;

    return 'python3';
  }

  Future<void> freePort(int port) async {
    try {
      if (Platform.isWindows) {
        await WindowsBackendService().freePort(port);
      } else {
        await Process.run('fuser', ['-k', '$port/tcp']);
      }
      await Future.delayed(const Duration(milliseconds: 250));
    } catch (_) {}
  }

  void syncLocalBackendCodeToTemp(String backendDir) {
    if (Platform.isWindows) {
      WindowsBackendService().syncAndPatchMei(backendDir);
    }
  }

  Future<Process?> startProcess({
    required String backendDir,
    required void Function(String line) onStdout,
    required void Function(String line) onStderr,
    required void Function(int exitCode) onExit,
  }) async {
    await freePort(8642);

    if (Platform.isWindows) {
      _backendProcess = await WindowsBackendService().startWindowsBackend(
        backendDir: backendDir,
        parentPid: pid,
        onStdout: onStdout,
        onStderr: (data) {
          _lastErrorMessage = data.trim();
          onStderr(data);
        },
        onExit: (code) {
          if (code != 0 && (_lastErrorMessage == null || _lastErrorMessage!.isEmpty)) {
            _lastErrorMessage = 'El backend se cerró inesperadamente (código: $code)';
          }
          onExit(code);
        },
      );
      return _backendProcess;
    }

    // ── Ejecución Nativa en Linux (Ubuntu / POSIX) ───────────────────────────
    final pythonBin = resolvePythonExecutable(backendDir);
    final serverScript = '$backendDir/api_server.py';
    final venvDir = '$backendDir/.venv';
    final venvBinDir = '$venvDir/bin';

    debugPrint('[BackendProcessManager-Linux] Iniciando backend: $pythonBin $serverScript (cwd: $backendDir)');

    _backendProcess = await Process.start(
      pythonBin,
      ['-u', serverScript, '--parent-pid', pid.toString()],
      workingDirectory: backendDir,
      environment: {
        'VIRTUAL_ENV': venvDir,
        'PATH': '$venvBinDir:${Platform.environment['PATH'] ?? ''}',
        'PYTHONPATH': backendDir,
        'PYTHONUNBUFFERED': '1',
      },
      mode: ProcessStartMode.normal,
    );

    _backendProcess?.stdout.transform(utf8.decoder).listen((data) {
      onStdout(data);
    });

    _backendProcess?.stderr.transform(utf8.decoder).listen((data) {
      _lastErrorMessage = data.trim();
      onStderr(data);
    });

    _backendProcess?.exitCode.then((code) {
      if (code != 0 && (_lastErrorMessage == null || _lastErrorMessage!.isEmpty)) {
        _lastErrorMessage = 'El backend se cerró inesperadamente (código: $code)';
      }
      onExit(code);
    });

    return _backendProcess;
  }

  void killProcess() {
    _backendProcess?.kill();
    _backendProcess = null;
  }
}
