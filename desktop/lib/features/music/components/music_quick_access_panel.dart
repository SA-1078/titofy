import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/library_service.dart';
import '../../../core/services/player_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/locale_service.dart';

/// Panel lateral de Acceso Rápido y estado de la colección local
class MusicQuickAccessPanel extends StatelessWidget {
  final LibraryService library;
  final PlayerService player;
  final ApiService api;
  final LocaleService loc;
  final ValueChanged<int>? onNavigate;

  const MusicQuickAccessPanel({
    super.key,
    required this.library,
    required this.player,
    required this.api,
    required this.loc,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Acceso rápido',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              'Tu música',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildQuickFilterCards(c),
        const SizedBox(height: 14),
        _buildCollectionStatusCard(context, c),
      ],
    );
  }

  Widget _buildCollectionStatusCard(BuildContext context, ThemeColors c) {
    final folderPath = library.scannedFolder ?? 'Sin carpeta asignada';
    final folderName = folderPath.split('/').where((s) => s.isNotEmpty).lastOrNull ?? folderPath;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.glassBorder),
        boxShadow: [
          if (!c.isDark)
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.folder_special_rounded, color: c.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CARPETA LOCAL',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: c.primary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      folderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                tooltip: loc.t('changeFolder'),
                color: c.textMuted,
                onPressed: () => library.pickAndScan(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            folderPath,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: c.textMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatusPill(
                label: '${library.realTracks.length} canciones',
                icon: Icons.audio_file_rounded,
                c: c,
              ),
              const SizedBox(width: 8),
              _StatusPill(
                label: api.isOnline ? 'IA Conectada' : 'IA Offline',
                icon: Icons.memory_rounded,
                c: c,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterCards(ThemeColors c) {
    final filters = [
      {
        'title': 'Toda la biblioteca',
        'count': '${library.realTracks.length} canciones',
        'gradient': [c.primary, c.accentPreset.dark],
        'icon': Icons.queue_music_rounded,
        'action': () {
          if (onNavigate != null) {
            onNavigate!(7);
          } else if (library.realTracks.isNotEmpty) {
            player.playTrack(library.realTracks.first, playlist: library.realTracks);
          }
        },
      },
      {
        'title': 'Favoritos',
        'count': '${library.favoriteTracks.length} canciones',
        'gradient': const [Color(0xFFE91E63), Color(0xFFFF5252)],
        'icon': Icons.favorite_rounded,
        'action': () {
          if (onNavigate != null) {
            onNavigate!(5);
          } else if (library.favoriteTracks.isNotEmpty) {
            player.playTrack(library.favoriteTracks.first, playlist: library.favoriteTracks);
          }
        },
      },
    ];

    return Row(
      children: filters.map((f) {
        final colors = f['gradient'] as List<Color>;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: f['action'] as VoidCallback,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(f['icon'] as IconData, color: Colors.white, size: 22),
                    const SizedBox(height: 10),
                    Text(
                      f['title'] as String,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      f['count'] as String,
                      style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final ThemeColors c;
  const _StatusPill({required this.label, required this.icon, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.backgroundAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c.primaryLight),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
