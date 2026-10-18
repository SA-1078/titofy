// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'dart:io';
import '../api_service.dart';

/// Coordinador de llamadas a motores locales de IA (Faster-Whisper y Forced Alignment)
class LyricsAiCoordinator {
  /// Obtiene el mejor modelo Whisper disponible en disco
  static Future<String> resolveEffectiveModel(ApiService apiService, {String fallback = 'turbo'}) async {
    try {
      final models = await apiService.getModels();
      const priority = ['turbo', 'small', 'base'];
      for (final id in priority) {
        final match = models.where((m) =>
            m['id']?.toString() == id && m['downloaded'] == true);
        if (match.isNotEmpty) {
          return id;
        }
      }
    } catch (_) {}
    return fallback;
  }

  /// Ejecuta transcripción forzada con Whisper local
  static Future<Map<String, dynamic>?> generateAiLyrics(
    ApiService apiService,
    String audioPath, {
    String model = 'small',
  }) async {
    try {
      return await apiService.resolveLyrics(
        audioPath: audioPath,
        outputPath: null,
        model: model,
        mode: 'ai_only',
        force: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Ejecuta alineación acústica forzada (forced alignment) con audio local
  static Future<Map<String, dynamic>?> alignLyricsWithAudio(
    ApiService apiService, {
    required String audioPath,
    String? artist,
    String? title,
    String? model,
  }) async {
    final file = File(audioPath);
    if (!file.existsSync()) return null;

    final effectiveModel = model ?? await resolveEffectiveModel(apiService);

    try {
      return await apiService.resolveLyrics(
        artist: artist,
        title: title,
        audioPath: audioPath,
        outputPath: null,
        model: effectiveModel,
        mode: 'online_align',
        force: true,
      );
    } catch (_) {
      return null;
    }
  }
}
