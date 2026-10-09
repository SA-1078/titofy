import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/services/database_service.dart';
import '../../core/services/library_service.dart';

/// Diálogo modal para buscar y añadir múltiples canciones de la biblioteca a una lista de reproducción
class SelectTracksDialog extends StatefulWidget {
  final PlaylistModel playlist;

  const SelectTracksDialog({super.key, required this.playlist});

  static Future<void> show(BuildContext context, PlaylistModel playlist) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) => SelectTracksDialog(playlist: playlist),
    );
  }

  @override
  State<SelectTracksDialog> createState() => _SelectTracksDialogState();
}

class _SelectTracksDialogState extends State<SelectTracksDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final db = context.watch<DatabaseService>();
    final library = context.watch<LibraryService>();

    final allTracks = library.tracks;
    final filteredTracks = _searchQuery.isEmpty
        ? allTracks
        : allTracks.where((t) {
            final q = _searchQuery.toLowerCase();
            return t.title.toLowerCase().contains(q) ||
                t.artist.toLowerCase().contains(q) ||
                t.album.toLowerCase().contains(q);
          }).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 580,
        height: 640,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c.glassBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.playlist_add_rounded, color: c.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Añadir canciones a la lista',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: c.textMuted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  splashRadius: 18,
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Barra de búsqueda
            TextField(
              controller: _searchCtrl,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              style: TextStyle(color: c.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar en tu biblioteca por canción, artista...',
                hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: c.textMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: c.textMuted, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: c.backgroundAlt,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.glassBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Lista de canciones
            Expanded(
              child: filteredTracks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.music_off_rounded, color: c.textMuted, size: 40),
                          const SizedBox(height: 10),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No hay canciones en la biblioteca'
                                : 'No se encontraron resultados para "$_searchQuery"',
                            style: TextStyle(color: c.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredTracks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final track = filteredTracks[index];
                        final isInPlaylist = db.isTrackInPlaylist(widget.playlist.id, track.path);

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isInPlaylist ? c.primary.withOpacity(0.08) : c.backgroundAlt.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isInPlaylist ? c.primary.withOpacity(0.3) : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Icono
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: isInPlaylist ? c.primary.withOpacity(0.2) : c.backgroundAlt,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.music_note_rounded,
                                  size: 18,
                                  color: isInPlaylist ? c.primary : c.textMuted,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Info de canción
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isInPlaylist ? c.primary : c.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${track.artist}  •  ${track.durationFormatted}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11, color: c.textMuted),
                                    ),
                                  ],
                                ),
                              ),

                              // Botón Añadir / Quitar
                              InkWell(
                                onTap: () {
                                  if (isInPlaylist) {
                                    db.removeTrackFromPlaylist(widget.playlist.id, track.path);
                                  } else {
                                    db.addTrackToPlaylist(widget.playlist.id, track.path);
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isInPlaylist ? c.primary.withOpacity(0.18) : c.primary,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isInPlaylist ? c.primary.withOpacity(0.4) : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isInPlaylist ? Icons.check_rounded : Icons.add_rounded,
                                        size: 15,
                                        color: isInPlaylist ? c.primary : c.textOnPrimary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isInPlaylist ? 'Añadida' : 'Añadir',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isInPlaylist ? c.primary : c.textOnPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),

            // Pie
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${allTracks.length} canciones en la biblioteca',
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: c.textOnPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Listo', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
