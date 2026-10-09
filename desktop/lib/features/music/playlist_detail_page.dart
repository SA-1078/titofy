import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/services/database_service.dart';
import '../../core/services/library_service.dart';
import '../../core/services/player_service.dart';
import '../../core/services/locale_service.dart';
import 'select_tracks_dialog.dart';

/// Vista de Detalle de una Lista de Reproducción
class PlaylistDetailPage extends StatefulWidget {
  final int playlistId;
  final VoidCallback onBack;

  const PlaylistDetailPage({
    super.key,
    required this.playlistId,
    required this.onBack,
  });

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  void _renameDialog(BuildContext context, PlaylistModel pl) {
    final c = context.colors;
    final ctrl = TextEditingController(text: pl.name);
    final descCtrl = TextEditingController(text: pl.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Renombrar lista', style: TextStyle(color: c.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: c.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nombre',
                labelStyle: TextStyle(color: c.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              style: TextStyle(color: c.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Descripción',
                labelStyle: TextStyle(color: c.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<DatabaseService>().renamePlaylist(
                      pl.id,
                      ctrl.text.trim(),
                      descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    );
                Navigator.of(ctx).pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: c.primary),
            child: Text('Guardar', style: TextStyle(color: c.textOnPrimary)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, PlaylistModel pl) {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: c.error, size: 22),
            const SizedBox(width: 8),
            Text('Eliminar lista', style: TextStyle(color: c.textPrimary, fontSize: 16)),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar la lista "${pl.name}"? Tus archivos de música no se borrarán.',
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<DatabaseService>().deletePlaylist(pl.id);
              Navigator.of(ctx).pop();
              widget.onBack();
            },
            style: ElevatedButton.styleFrom(backgroundColor: c.error),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final loc = context.watch<LocaleService>();
    final db = context.watch<DatabaseService>();
    final library = context.watch<LibraryService>();
    final player = context.watch<PlayerService>();

    final playlists = db.playlists;
    final plIndex = playlists.indexWhere((p) => p.id == widget.playlistId);

    if (plIndex == -1) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.playlist_remove_rounded, size: 48, color: c.textMuted),
            const SizedBox(height: 12),
            Text('Lista de reproducción no encontrada', style: TextStyle(color: c.textPrimary, fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Volver'),
              style: ElevatedButton.styleFrom(backgroundColor: c.primary),
            ),
          ],
        ),
      );
    }

    final pl = playlists[plIndex];
    final tracks = library.getTracksForPlaylist(pl.id);

    // Calcular duración total
    final totalDuration = tracks.fold<Duration>(
      Duration.zero,
      (prev, t) => prev + t.duration,
    );
    final totalHours = totalDuration.inHours;
    final totalMinutes = totalDuration.inMinutes.remainder(60);
    final durationStr = totalHours > 0
        ? '$totalHours h $totalMinutes min'
        : '$totalMinutes min';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // ── Cabecera de la Playlist ──────────────────────────────────────
          Container(
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
                  onTap: widget.onBack,
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
                            pl.name,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (pl.description != null && pl.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              pl.description!,
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
                      onPressed: tracks.isEmpty
                          ? null
                          : () {
                              player.playTrack(tracks.first, queue: tracks);
                            },
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
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => SelectTracksDialog.show(context, pl),
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
                      onPressed: () => _renameDialog(context, pl),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: c.error.withOpacity(0.8), size: 20),
                      tooltip: 'Eliminar lista',
                      onPressed: () => _confirmDelete(context, pl),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Lista de Pistas ──────────────────────────────────────────────
          Expanded(
            child: tracks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.queue_music_rounded, size: 48, color: c.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          loc.t('emptyPlaylist'),
                          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Explora tu música o añade canciones directamente a esta lista',
                          style: TextStyle(color: c.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: () => SelectTracksDialog.show(context, pl),
                          icon: const Icon(Icons.playlist_add_rounded, size: 20),
                          label: const Text('Añadir canciones a esta lista'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.primary,
                            foregroundColor: c.textOnPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    physics: const BouncingScrollPhysics(),
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final isCurrent = player.currentTrack?.path == track.path;
                      final isPlaying = isCurrent && player.isPlaying;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isCurrent ? c.primary.withOpacity(0.08) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrent ? c.primary.withOpacity(0.3) : Colors.transparent,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          leading: SizedBox(
                            width: 36,
                            child: Center(
                              child: isPlaying
                                  ? Icon(Icons.volume_up_rounded, color: c.primary, size: 18)
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: isCurrent ? c.primary : c.textMuted,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent ? c.primary : c.textPrimary,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${track.artist}  •  ${track.album}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.textMuted, fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                track.durationFormatted,
                                style: TextStyle(color: c.textMuted, fontSize: 12),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  library.isFavorite(track) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  size: 18,
                                  color: library.isFavorite(track) ? c.primary : c.textMuted,
                                ),
                                splashRadius: 18,
                                onPressed: () => library.toggleFavorite(track),
                              ),
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline_rounded, size: 18, color: c.textMuted),
                                tooltip: 'Quitar de la lista',
                                splashRadius: 18,
                                onPressed: () {
                                  db.removeTrackFromPlaylist(pl.id, track.path);
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            player.playTrack(track, queue: tracks);
                          },
                        ),
                      ),
                    );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
