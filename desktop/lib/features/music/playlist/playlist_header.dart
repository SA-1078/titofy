import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/library_service.dart';
import '../../../core/services/locale_service.dart';

/// Cabecera de la vista de playlist: Carátula, Título, Estadísticas y Botones de acción
class PlaylistHeader extends StatelessWidget {
  final PlaylistModel playlist;
  final List<Track> tracks;
  final String durationStr;
  final VoidCallback onBack;
  final VoidCallback onPlayAll;
  final VoidCallback onAddTracks;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback? onDownloadAll;
  final bool isDownloadingAll;
  final int downloadedCount;
  final int totalToDownload;

  const PlaylistHeader({
    super.key,
    required this.playlist,
    required this.tracks,
    required this.durationStr,
    required this.onBack,
    required this.onPlayAll,
    required this.onAddTracks,
    required this.onRename,
    required this.onDelete,
    this.onDownloadAll,
    this.isDownloadingAll = false,
    this.downloadedCount = 0,
    this.totalToDownload = 0,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final loc = context.watch<LocaleService>();
    final remoteTracks = tracks.where((t) => t.isRemote).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            c.primary.withOpacity(0.18),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botón volver
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded, size: 18, color: c.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Volver a la biblioteca',
                    style: TextStyle(fontSize: 13, color: c.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Icono carátula de Playlist
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.primary, c.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: c.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.queue_music_rounded, size: 54, color: Colors.white),
                ),
              ),
              const SizedBox(width: 22),

              // Información
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LISTA DE REPRODUCCIÓN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: c.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      playlist.name,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (playlist.description != null && playlist.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        playlist.description!,
                        style: TextStyle(fontSize: 13, color: c.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.music_note_rounded, size: 15, color: c.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${tracks.length} canciones',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
                        ),
                        if (tracks.isNotEmpty) ...[
                          Text('  •  ', style: TextStyle(color: c.textMuted)),
                          Text(
                            durationStr,
                            style: TextStyle(fontSize: 12, color: c.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Barra de Acciones
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: tracks.isEmpty ? null : onPlayAll,
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: Text(loc.t('playAll')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: c.textOnPrimary,
                  disabledBackgroundColor: c.primary.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              if (remoteTracks.isNotEmpty) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: isDownloadingAll ? null : onDownloadAll,
                  icon: isDownloadingAll
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_for_offline_rounded, size: 18),
                  label: Text(
                    isDownloadingAll
                        ? 'Descargando ($downloadedCount/$totalToDownload)...'
                        : 'Descargar todas (${remoteTracks.length})',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.primary,
                    side: BorderSide(color: c.primary.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onAddTracks,
                icon: const Icon(Icons.playlist_add_rounded, size: 20),
                label: const Text('Añadir canciones'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.textPrimary,
                  side: BorderSide(color: c.primary.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(Icons.edit_rounded, color: c.textSecondary, size: 20),
                tooltip: 'Renombrar lista',
                onPressed: onRename,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: c.error.withOpacity(0.8), size: 20),
                tooltip: 'Eliminar lista',
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
