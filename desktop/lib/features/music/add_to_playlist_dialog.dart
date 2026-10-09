import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/services/database_service.dart';
import '../../core/services/library_service.dart';
import '../../core/services/locale_service.dart';
import 'create_playlist_dialog.dart';

/// Diálogo modal para añadir una canción a una o más listas de reproducción
class AddToPlaylistDialog extends StatelessWidget {
  final Track track;

  const AddToPlaylistDialog({super.key, required this.track});

  static Future<void> show(BuildContext context, Track track) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => AddToPlaylistDialog(track: track),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final loc = context.watch<LocaleService>();
    final db = context.watch<DatabaseService>();
    final playlists = db.playlists;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.glassBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.queue_music_rounded, color: c.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.t('addToPlaylist'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${track.title} - ${track.artist}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Botón rápido de "Crear nueva lista"
            InkWell(
              onTap: () async {
                final created = await CreatePlaylistDialog.show(context);
                if (created != null && context.mounted) {
                  db.addTrackToPlaylist(created.id, track.path);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Añadida a la lista "${created.name}"'),
                      backgroundColor: c.primary,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, color: c.primary, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Crear nueva lista de reproducción',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Listado de listas existentes
            if (playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.playlist_remove_rounded, color: c.textMuted, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'Aún no has creado ninguna lista',
                        style: TextStyle(fontSize: 13, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final pl = playlists[index];
                    final isInPlaylist = db.isTrackInPlaylist(pl.id, track.path);

                    return InkWell(
                      onTap: () {
                        if (isInPlaylist) {
                          db.removeTrackFromPlaylist(pl.id, track.path);
                        } else {
                          db.addTrackToPlaylist(pl.id, track.path);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isInPlaylist ? c.primary.withOpacity(0.12) : c.backgroundAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isInPlaylist ? c.primary.withOpacity(0.4) : c.glassBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.playlist_play_rounded,
                              size: 20,
                              color: isInPlaylist ? c.primary : c.textMuted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pl.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isInPlaylist ? c.textPrimary : c.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '${pl.trackCount} canciones',
                                    style: TextStyle(fontSize: 11, color: c.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isInPlaylist ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                              size: 20,
                              color: isInPlaylist ? c.primary : c.textMuted,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.backgroundAlt,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Listo',
                    style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
