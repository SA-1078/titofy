import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/services/player_service.dart';

/// Tarjeta de Selección de Archivo de Audio y Metadatos para IA Studio
class StudioAudioCard extends StatelessWidget {
  final String? selectedFilePath;
  final TextEditingController artistCtrl;
  final TextEditingController titleCtrl;
  final VoidCallback onPickFile;
  final VoidCallback onUseCurrentTrack;

  const StudioAudioCard({
    super.key,
    required this.selectedFilePath,
    required this.artistCtrl,
    required this.titleCtrl,
    required this.onPickFile,
    required this.onUseCurrentTrack,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.glassBorder),
        boxShadow: [
          if (!c.isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.audio_file_rounded, size: 16, color: c.primary),
              const SizedBox(width: 8),
              Text(
                '1. ARCHIVO DE AUDIO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.primary,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: Icon(Icons.music_note_rounded, size: 13, color: c.primary),
                label: Text(
                  'Usar pista en reproducción',
                  style: TextStyle(fontSize: 11, color: c.primary, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onUseCurrentTrack,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Zona interactiva de archivo
          InkWell(
            onTap: onPickFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.backgroundAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedFilePath != null ? c.primary.withOpacity(0.5) : c.glassBorder,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.primary.withOpacity(0.12),
                    ),
                    child: Icon(Icons.folder_open_rounded, size: 18, color: c.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedFilePath != null
                              ? File(selectedFilePath!).uri.pathSegments.last
                              : 'Haz clic aquí para seleccionar un archivo de audio',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: selectedFilePath != null ? FontWeight.w700 : FontWeight.w500,
                            color: selectedFilePath != null ? c.textPrimary : c.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (selectedFilePath != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            selectedFilePath!,
                            style: TextStyle(fontSize: 10.5, color: c.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: onPickFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.surfaceHover,
                      foregroundColor: c.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: const Text('Examinar', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),

          if (selectedFilePath != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: artistCtrl,
                    style: TextStyle(fontSize: 12, color: c.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Artista',
                      labelStyle: TextStyle(fontSize: 11, color: c.textSecondary),
                      filled: true,
                      fillColor: c.backgroundAlt,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: titleCtrl,
                    style: TextStyle(fontSize: 12, color: c.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Título',
                      labelStyle: TextStyle(fontSize: 11, color: c.textSecondary),
                      filled: true,
                      fillColor: c.backgroundAlt,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
