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
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final currentDir = Directory.current.path;
    final candidates = [
      '$exeDir/backend',
      exeDir,
      '$exeDir/../backend',
      '$currentDir/backend',
      currentDir,
      '$currentDir/../backend',
      '$currentDir/../../backend',
      if (Platform.isWindows && Platform.environment['LOCALAPPDATA'] != null)
        '${Platform.environment['LOCALAPPDATA']}/Programs/Titofy/backend',
      '/home/santiago007/Documentos/titofy/backend',
      '/home/santiago007/.local/share/titofy/backend',
    ];

    for (final c in candidates) {
      final script = File('$c/api_server.py');
      final exe = File('$c/api_server.exe');
      if (script.existsSync() || exe.existsSync()) return Directory(c).absolute.path;
    }
    return null;
  }

  String resolvePythonExecutable(String backendDir) {
    final envPython = Platform.environment['PYTHON'];
    if (envPython != null && File(envPython).existsSync()) return envPython;

    final isWin = Platform.isWindows;
    final venvBin = isWin
        ? '$backendDir/.venv/Scripts/python.exe'
        : '$backendDir/.venv/bin/python';
    if (File(venvBin).existsSync()) return venvBin;

    final venvAlt = isWin
        ? '$backendDir/venv/Scripts/python.exe'
        : '$backendDir/venv/bin/python';
    if (File(venvAlt).existsSync()) return venvAlt;

    return isWin ? 'python' : 'python3';
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

    final isWin = Platform.isWindows;
    final exeServer = File('$backendDir/api_server.exe');

    if (isWin && exeServer.existsSync()) {
      debugPrint('[BackendProcessManager] Iniciando ejecutable autónomo en Windows...');
      _backendProcess = await WindowsBackendService().startBackendProcess(backendDir, pid);
      Future.delayed(
        const Duration(milliseconds: 1500),
        () => syncLocalBackendCodeToTemp(backendDir),
      );
    } else {
      final pythonBin = resolvePythonExecutable(backendDir);
      final serverScript = '$backendDir/api_server.py';
      final venvDir = '$backendDir/.venv';
      final venvBinDir = isWin ? '$backendDir\\.venv\\Scripts' : '$venvDir/bin';
      final pathSep = isWin ? ';' : ':';

      debugPrint('[BackendProcessManager] Iniciando backend: $pythonBin $serverScript (cwd: $backendDir)');

      _backendProcess = await Process.start(
        pythonBin,
        ['-u', serverScript, '--parent-pid', pid.toString()],
        workingDirectory: backendDir,
        environment: {
          'VIRTUAL_ENV': venvDir,
          'PATH': '$venvBinDir$pathSep${Platform.environment['PATH'] ?? ''}',
          'PYTHONPATH': backendDir,
          'PYTHONUNBUFFERED': '1',
        },
        mode: ProcessStartMode.normal,
      );
    }

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
