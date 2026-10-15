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
}
