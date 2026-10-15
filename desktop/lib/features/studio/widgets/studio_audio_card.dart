import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

/// Tarjeta de Selección de Archivo de Audio (Ancho completo superior - Paso 01)
class StudioAudioCard extends StatefulWidget {
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
  State<StudioAudioCard> createState() => _StudioAudioCardState();
}

class _StudioAudioCardState extends State<StudioAudioCard> {
  bool _showMetadataFields = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasFile = widget.selectedFilePath != null && widget.selectedFilePath!.isNotEmpty;

    String fileName = '';
    String fileExt = 'AUDIO';
    if (hasFile) {
      final f = File(widget.selectedFilePath!);
      fileName = f.uri.pathSegments.isNotEmpty ? f.uri.pathSegments.last : widget.selectedFilePath!;
      final dot = fileName.lastIndexOf('.');
      if (dot != -1) {
        fileExt = fileName.substring(dot + 1).toUpperCase();
        fileName = fileName.substring(0, dot);
      }
    }

    final displayTitle = widget.titleCtrl.text.trim().isNotEmpty
        ? (widget.artistCtrl.text.trim().isNotEmpty
            ? '${widget.titleCtrl.text.trim()} — ${widget.artistCtrl.text.trim()}'
            : widget.titleCtrl.text.trim())
        : (hasFile ? fileName : 'Ningún archivo de audio seleccionado');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          // ── Encabezado del Paso 01 ──────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '01',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: c.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Archivo de audio',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: Icon(Icons.music_note_rounded, size: 14, color: c.primary),
                label: Text(
                  'Usar pista en reproducción',
                  style: TextStyle(fontSize: 11.5, color: c.primary, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: widget.onUseCurrentTrack,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Fila Principal: Icono + Detalles + Botón Cambiar ────────────
          InkWell(
            onTap: widget.onPickFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.backgroundAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasFile ? c.primary.withOpacity(0.4) : c.glassBorder,
                  width: 1.1,
                ),
              ),
              child: Row(
                children: [
                  // Cuadro oscuro con icono de audio
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.isDark ? const Color(0xFF1E222D) : Colors.black87,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      hasFile ? Icons.graphic_eq_rounded : Icons.audio_file_outlined,
                      color: c.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Título, formato y estado
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: hasFile ? c.textPrimary : c.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasFile ? '$fileExt · Archivo seleccionado' : 'Haz clic para examinar pistas en tu equipo',
                          style: TextStyle(
                            fontSize: 11,
                            color: hasFile ? c.textSecondary : c.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (hasFile) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.selectedFilePath!,
                            style: TextStyle(fontSize: 10, color: c.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Botón Cambiar / Examinar
                  OutlinedButton(
                    onPressed: widget.onPickFile,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.textPrimary,
                      side: BorderSide(color: c.glassBorder),
                      backgroundColor: c.surfaceHover,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: Text(
                      hasFile ? 'Cambiar' : 'Examinar',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),

                  if (hasFile) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(
                        _showMetadataFields ? Icons.edit_note_rounded : Icons.edit_outlined,
                        size: 18,
                        color: _showMetadataFields ? c.primary : c.textSecondary,
                      ),
                      tooltip: _showMetadataFields ? 'Ocultar metadatos' : 'Editar artista y título',
                      onPressed: () => setState(() => _showMetadataFields = !_showMetadataFields),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Campos editables de Artista y Título (desplegables) ─────────
          if (hasFile && _showMetadataFields) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.artistCtrl,
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
                    controller: widget.titleCtrl,
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
