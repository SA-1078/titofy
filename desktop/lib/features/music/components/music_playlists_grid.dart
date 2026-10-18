import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/player_service.dart';
import '../../../core/services/library_service.dart';
import '../import_youtube_dialog.dart';

/// Grid de Playlists en 2 columnas estilo UI_titofy_3
class MusicPlaylistsGrid extends StatelessWidget {
  final DatabaseService db;
  final PlayerService player;
  final LibraryService library;
  final ValueChanged<int>? onPlaylistSelected;

  const MusicPlaylistsGrid({
    super.key,
    required this.db,
    required this.player,
    required this.library,
    this.onPlaylistSelected,
  });

  static const List<Map<String, dynamic>> curatedStyles = [
    {
      'title': 'Summer Vibes',
      'subtitle': 'Tropical & Sunset',
      'colors': [Color(0xFFFF5E62), Color(0xFFFF9966)],
      'icon': Icons.wb_sunny_rounded,
    },
    {
      'title': 'Mind Right',
      'subtitle': 'Deep Focus & Ambient',
      'colors': [Color(0xFF8A2387), Color(0xFFE94057)],
      'icon': Icons.self_improvement_rounded,
    },
    {
      'title': 'Ultimate Indie',
      'subtitle': 'Acoustic & Alternative',
      'colors': [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
      'icon': Icons.queue_music_rounded,
    },
    {
      'title': 'Jazzy Dinner',
      'subtitle': 'Smooth Jazz & Lo-Fi',
      'colors': [Color(0xFF11998E), Color(0xFF38EF7D)],
      'icon': Icons.nightlife_rounded,
    },
    {
      'title': 'Pop Hits',
      'subtitle': 'Global & Trending',
      'colors': [Color(0xFFEE0979), Color(0xFFFF6A00)],
      'icon': Icons.bolt_rounded,
    },
    {
      'title': 'Roots Rising',
      'subtitle': 'Classic & Acoustic',
      'colors': [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
      'icon': Icons.radio_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final userPlaylists = db.playlists;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Playlists',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => ImportYouTubeDialog.show(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline_rounded, size: 14, color: c.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Importar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Grid 2 columnas de tarjetas estilizadas
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.1,
          ),
          itemCount: mathMax(userPlaylists.length, 6),
          itemBuilder: (context, index) {
            // Si hay playlist real del usuario, mostrarla con estilo UI_titofy_3
            if (index < userPlaylists.length) {
              final pl = userPlaylists[index];
              final style = curatedStyles[index % curatedStyles.length];
              return _buildPlaylistCard(
                title: pl.name,
                subtitle: '${pl.trackCount} canciones',
                colors: style['colors'] as List<Color>,
                icon: pl.name.toLowerCase().contains('youtube') ||
                        (pl.description?.toLowerCase().contains('youtube') ?? false)
                    ? Icons.video_library_rounded
                    : style['icon'] as IconData,
                onTap: () {
                  if (onPlaylistSelected != null) {
                    onPlaylistSelected!(pl.id);
                  }
                },
                c: c,
              );
            }

            // Si faltan para completar el grid 2x3, mostrar las recomendadas
            final curIndex = index % curatedStyles.length;
            final item = curatedStyles[curIndex];
            return _buildPlaylistCard(
              title: item['title'] as String,
              subtitle: item['subtitle'] as String,
              colors: item['colors'] as List<Color>,
              icon: item['icon'] as IconData,
              onTap: () {
                // Si hace clic en recomendada, reproducir canciones aleatorias o sugeridas
                if (library.tracks.isNotEmpty) {
                  final shuffled = List<Track>.from(library.tracks)..shuffle();
                  player.playTrack(shuffled.first, playlist: shuffled);
                } else {
                  ImportYouTubeDialog.show(context);
                }
              },
              c: c,
            );
          },
        ),
      ],
    );
  }

  int mathMax(int a, int b) => a > b ? a : b;

  Widget _buildPlaylistCard({
    required String title,
    required String subtitle,
    required List<Color> colors,
    required IconData icon,
    required VoidCallback onTap,
    required ThemeColors c,
  }) {
    return _HoverablePlaylistCard(
      title: title,
      subtitle: subtitle,
      colors: colors,
      icon: icon,
      onTap: onTap,
      c: c,
    );
  }
}

class _HoverablePlaylistCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<Color> colors;
  final IconData icon;
  final VoidCallback onTap;
  final ThemeColors c;

  const _HoverablePlaylistCard({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.icon,
    required this.onTap,
    required this.c,
  });

  @override
  State<_HoverablePlaylistCard> createState() => _HoverablePlaylistCardState();
}

class _HoverablePlaylistCardState extends State<_HoverablePlaylistCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..scale(_isHovered ? 1.03 : 1.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: widget.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.colors.first.withOpacity(_isHovered ? 0.45 : 0.22),
                blurRadius: _isHovered ? 18 : 10,
                offset: Offset(0, _isHovered ? 6 : 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Efecto de sombreado inferior
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.08),
                        Colors.black.withOpacity(0.65),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // Contenido de texto e icono
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.85),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _isHovered ? 1.0 : 0.75,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(_isHovered ? 0.95 : 0.25),
                        ),
                        child: Icon(
                          _isHovered ? Icons.play_arrow_rounded : widget.icon,
                          color: _isHovered ? widget.colors.first : Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
