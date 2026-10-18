import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/services/library_service.dart';
import '../../core/services/player_service.dart';
import '../../core/services/locale_service.dart';
import 'add_to_playlist_dialog.dart';
import 'hybrid_lyrics_dialog.dart';

/// Vista completa de "Toda la biblioteca" con buscador integrado y controles de reproducción
class AllTracksPage extends StatefulWidget {
  const AllTracksPage({super.key});

  @override
  State<AllTracksPage> createState() => _AllTracksPageState();
}

class _AllTracksPageState extends State<AllTracksPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final loc = context.watch<LocaleService>();
    final library = context.watch<LibraryService>();
    final player = context.watch<PlayerService>();

    final allTracks = library.tracks;
    final effectiveQuery = (_query.isNotEmpty ? _query : library.searchQuery).trim().toLowerCase();
    final filtered = allTracks.where((t) {
      if (effectiveQuery.isEmpty) return true;
      return t.title.toLowerCase().contains(effectiveQuery) ||
          t.artist.toLowerCase().contains(effectiveQuery) ||
          t.album.toLowerCase().contains(effectiveQuery);
    }).toList();

    // Duración total acumulada
    final totalDuration = filtered.fold<Duration>(
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
          // ── Cabecera de la Colección ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.primary.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Icono carátula
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [c.primary, c.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: c.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.queue_music_rounded, size: 48, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Información
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BIBLIOTECA LOCAL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: c.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Toda la biblioteca',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.music_note_rounded, size: 14, color: c.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                '${filtered.length} canciones',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
                              ),
                              if (filtered.isNotEmpty) ...[
                                Text('  •  ', style: TextStyle(color: c.textMuted)),
                                Text(
                                  durationStr,
                                  style: TextStyle(fontSize: 12, color: c.textMuted),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Botones de acción
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: filtered.isEmpty
                                    ? null
                                    : () {
                                        player.playTrack(filtered.first, queue: filtered);
                                      },
                                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                label: Text(loc.t('playAll')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: c.primary,
                                  foregroundColor: c.textOnPrimary,
                                  disabledBackgroundColor: c.primary.withValues(alpha: 0.3),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: () => library.pickAndScan(),
                                icon: const Icon(Icons.folder_open_rounded, size: 17),
                                label: Text(loc.t('changeFolder')),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: c.textPrimary,
                                  side: BorderSide(color: c.glassBorder),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Buscador en vivo
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.glassBorder),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _query = val.trim()),
                    style: TextStyle(fontSize: 13, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Buscar canciones, artistas o álbumes...',
                      hintStyle: TextStyle(fontSize: 12, color: c.textMuted),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: c.textMuted),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Lista de Pistas ──────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.queue_music_rounded, size: 48, color: c.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          _query.isNotEmpty ? 'No se encontraron resultados' : 'Tu biblioteca está vacía',
                          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _query.isNotEmpty
                              ? 'Prueba buscando con otro término'
                              : 'Selecciona una carpeta para sincronizar tus canciones locales',
                          style: TextStyle(color: c.textMuted, fontSize: 13),
                        ),
                        if (_query.isEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => library.pickAndScan(),
                            icon: const Icon(Icons.folder_open_rounded, size: 18),
                            label: Text(loc.t('changeFolder')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.primary,
                              foregroundColor: c.textOnPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final track = filtered[index];
                      final isCurrent = player.currentTrack?.path == track.path;
                      final isPlaying = isCurrent && player.isPlaying;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 5),
                        decoration: BoxDecoration(
                          color: isCurrent ? c.primary.withValues(alpha: 0.08) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrent ? c.primary.withValues(alpha: 0.3) : Colors.transparent,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            leading: SizedBox(
                              width: 34,
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
                                  icon: Icon(Icons.lyrics_outlined, size: 18, color: c.textMuted),
                                  tooltip: 'Letras sincronizadas',
                                  splashRadius: 18,
                                  onPressed: () => HybridLyricsDialog.show(context, track),
                                ),
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
                                  icon: Icon(Icons.playlist_add_rounded, size: 20, color: c.textMuted),
                                  tooltip: loc.t('addToPlaylist'),
                                  splashRadius: 18,
                                  onPressed: () => AddToPlaylistDialog.show(context, track),
                                ),
                              ],
                            ),
                            onTap: () {
                              player.playTrack(track, queue: filtered);
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
