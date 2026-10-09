import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/services/library_service.dart';
import '../../core/services/player_service.dart';
import '../../core/services/locale_service.dart';
import 'add_to_playlist_dialog.dart';

/// Vista de Álbumes y Artistas de la biblioteca local
class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  int _tabIndex = 0; // 0: Álbumes, 1: Artistas
  String? _selectedKey;

  final List<List<Color>> _coverGradients = [
    [const Color(0xFFFF5277), const Color(0xFF79155B)],
    [const Color(0xFF3B1E54), const Color(0xFFD63484)],
    [const Color(0xFF1B1A55), const Color(0xFF535C91)],
    [const Color(0xFF005B41), const Color(0xFF008170)],
    [const Color(0xFF4A148C), const Color(0xFF880E4F)],
    [const Color(0xFF222831), const Color(0xFF393E46)],
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final loc = context.watch<LocaleService>();
    final library = context.watch<LibraryService>();
    final player = context.watch<PlayerService>();

    // Agrupacion por Album
    final Map<String, List<Track>> albumGroups = {};
    for (final t in library.tracks) {
      final key = (t.album.isNotEmpty && t.album != 'Álbum local') ? t.album : 'Varios';
      albumGroups.putIfAbsent(key, () => []).add(t);
    }

    // Agrupacion por Artista
    final Map<String, List<Track>> artistGroups = {};
    for (final t in library.tracks) {
      final key = t.artist.isNotEmpty ? t.artist : 'Desconocido';
      artistGroups.putIfAbsent(key, () => []).add(t);
    }

    final activeGroups = _tabIndex == 0 ? albumGroups : artistGroups;

    // Si hay un grupo seleccionado, mostrar sus canciones
    if (_selectedKey != null && activeGroups.containsKey(_selectedKey)) {
      final selectedTracks = activeGroups[_selectedKey!]!;
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.primary.withOpacity(0.15), Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => setState(() => _selectedKey = null),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_rounded, size: 18, color: c.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            _tabIndex == 0 ? 'Volver a Álbumes' : 'Volver a Artistas',
                            style: TextStyle(fontSize: 13, color: c.textSecondary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _coverGradients[_selectedKey.hashCode.abs() % _coverGradients.length],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Icon(
                            _tabIndex == 0 ? Icons.album_rounded : Icons.person_rounded,
                            size: 42,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _tabIndex == 0 ? 'ÁLBUM' : 'ARTISTA',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.textMuted, letterSpacing: 1.2),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedKey!,
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${selectedTracks.length} canciones',
                              style: TextStyle(fontSize: 12, color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => player.playTrack(selectedTracks.first, queue: selectedTracks),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: Text(loc.t('playAll')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: c.textOnPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                physics: const BouncingScrollPhysics(),
                itemCount: selectedTracks.length,
                itemBuilder: (context, idx) {
                  final t = selectedTracks[idx];
                  final isCurrent = player.currentTrack?.path == t.path;
                  final isPlaying = isCurrent && player.isPlaying;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: SizedBox(
                      width: 32,
                      child: Center(
                        child: isPlaying
                            ? Icon(Icons.volume_up_rounded, color: c.primary, size: 18)
                            : Text('${idx + 1}', style: TextStyle(color: c.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    title: Text(
                      t.title,
                      style: TextStyle(color: isCurrent ? c.primary : c.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text('${t.artist}  •  ${t.album}', style: TextStyle(color: c.textMuted, fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.durationFormatted, style: TextStyle(color: c.textMuted, fontSize: 12)),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: library.isFavorite(t) ? 'Quitar de favoritos' : 'Añadir a canciones favoritas',
                          icon: Icon(
                            library.isFavorite(t) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: library.isFavorite(t) ? c.primary : c.textMuted,
                            size: 18,
                          ),
                          splashRadius: 18,
                          onPressed: () => library.toggleFavorite(t),
                        ),
                        IconButton(
                          tooltip: 'Añadir a lista de reproducción',
                          icon: Icon(Icons.playlist_add_rounded, color: c.textMuted, size: 20),
                          splashRadius: 18,
                          onPressed: () => AddToPlaylistDialog.show(context, t),
                        ),
                      ],
                    ),
                    onTap: () => player.playTrack(t, queue: selectedTracks),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Selector de Pestañas ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
            child: Row(
              children: [
                _TabButton(
                  title: loc.t('albums'),
                  icon: Icons.album_rounded,
                  isSelected: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                const SizedBox(width: 10),
                _TabButton(
                  title: loc.t('artists'),
                  icon: Icons.person_rounded,
                  isSelected: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
                const Spacer(),
                Text(
                  '${activeGroups.length} ${_tabIndex == 0 ? 'álbumes' : 'artistas'}',
                  style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // ── Grid de Contenido ────────────────────────────────────────────
          Expanded(
            child: activeGroups.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.library_music_rounded, size: 48, color: c.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No hay pistas escaneadas en la biblioteca',
                          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ve a Ajustes para escanear tu carpeta de música',
                          style: TextStyle(color: c.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(28, 4, 28, 24),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                    ),
                    itemCount: activeGroups.length,
                    itemBuilder: (context, index) {
                      final key = activeGroups.keys.elementAt(index);
                      final tracks = activeGroups[key]!;
                      final grad = _coverGradients[key.hashCode.abs() % _coverGradients.length];

                      return InkWell(
                        onTap: () => setState(() => _selectedKey = key),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: c.glassBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: grad),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      _tabIndex == 0 ? Icons.album_rounded : Icons.person_rounded,
                                      size: 44,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${tracks.length} canciones',
                                style: TextStyle(fontSize: 12, color: c.textMuted),
                              ),
                            ],
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

class _TabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? c.primary.withOpacity(0.15) : c.backgroundAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? c.primary.withOpacity(0.4) : c.glassBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? c.primary : c.textMuted),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? c.primary : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
