import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/library_service.dart';
import '../../../core/services/player_service.dart';
import '../../../core/services/locale_service.dart';

/// Carrusel de álbumes y estado vacío para MusicPage
class MusicAlbumCarousel extends StatelessWidget {
  final LibraryService library;
  final PlayerService player;
  final LocaleService loc;
  final Map<String, List<Track>> albumGroups;

  const MusicAlbumCarousel({
    super.key,
    required this.library,
    required this.player,
    required this.loc,
    required this.albumGroups,
  });

  List<List<Color>> _getCoverGradients(ThemeColors c) => [
    [c.primary, c.accentPreset.dark],
    [c.accentPreset.light, c.primary],
    [const Color(0xFF1B1A55), const Color(0xFF535C91)],
    [const Color(0xFF005B41), const Color(0xFF008170)],
    [const Color(0xFF4A148C), const Color(0xFF880E4F)],
    [const Color(0xFF222831), const Color(0xFF393E46)],
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (library.tracks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.glassBorder),
          boxShadow: [
            if (!c.isDark)
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.primary.withOpacity(0.12),
              ),
              child: Icon(Icons.music_off_rounded, color: c.primary, size: 36),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.t('noMusicFound'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Elige la carpeta donde tienes tus archivos MP3, FLAC o WAV para comenzar a reproducir y sincronizar letras.',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: Text(loc.t('changeFolder')),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              onPressed: () => library.pickAndScan(),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 195,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: albumGroups.length,
        separatorBuilder: (context, index) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final albumName = albumGroups.keys.elementAt(index);
          final tracks = albumGroups[albumName]!;
          final isFeatured = index == 0;
          final albumGradients = _getCoverGradients(c);
          return _buildRealAlbumCard(
            albumName: albumName,
            tracks: tracks,
            isFeatured: isFeatured,
            gradientIndex: index % albumGradients.length,
            c: c,
          );
        },
      ),
    );
  }

  Widget _buildRealAlbumCard({
    required String albumName,
    required List<Track> tracks,
    required bool isFeatured,
    required int gradientIndex,
    required ThemeColors c,
  }) {
    final colors = _getCoverGradients(c)[gradientIndex];
    return _HoverableAlbumCard(
      albumName: albumName,
      tracks: tracks,
      isFeatured: isFeatured,
      colors: colors,
      c: c,
      onTap: () => player.playTrack(tracks.first, playlist: tracks),
    );
  }
}

class _HoverableAlbumCard extends StatefulWidget {
  final String albumName;
  final List<Track> tracks;
  final bool isFeatured;
  final List<Color> colors;
  final ThemeColors c;
  final VoidCallback onTap;

  const _HoverableAlbumCard({
    required this.albumName,
    required this.tracks,
    required this.isFeatured,
    required this.colors,
    required this.c,
    required this.onTap,
  });

  @override
  State<_HoverableAlbumCard> createState() => _HoverableAlbumCardState();
}

class _HoverableAlbumCardState extends State<_HoverableAlbumCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final firstTrack = widget.tracks.first;
    final active = widget.isFeatured || _hovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..scale(_hovered ? 1.05 : 1.0),
          width: 135,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 135,
                height: 135,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: widget.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: active ? widget.c.primary : Colors.transparent,
                    width: active ? 2.5 : 0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: active ? widget.c.primary.withOpacity(0.45) : widget.colors.first.withOpacity(0.2),
                      blurRadius: active ? 22 : 12,
                      offset: Offset(0, active ? 8 : 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    if (firstTrack.artwork != null)
                      Image.memory(firstTrack.artwork!, width: 135, height: 135, fit: BoxFit.cover)
                    else
                      Center(
                        child: Icon(
                          Icons.album_rounded,
                          size: 46,
                          color: Colors.white.withOpacity(0.65),
                        ),
                      ),
                    Center(
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 180),
                        scale: _hovered ? 1.15 : 1.0,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.95),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: widget.c.primary,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.albumName,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: active ? widget.c.primary : widget.c.textPrimary,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                '${widget.tracks.first.artist} · ${widget.tracks.length} tracks',
                style: TextStyle(fontSize: 10.5, color: widget.c.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
