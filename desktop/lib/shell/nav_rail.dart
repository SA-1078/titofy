import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../core/theme/colors.dart';
import '../core/services/locale_service.dart';
import '../core/services/database_service.dart';
import '../core/services/player_service.dart';
import '../features/music/create_playlist_dialog.dart';
import 'nav_rail_widgets.dart';

class TitofyNavRail extends StatelessWidget {
  final int selectedIndex;
  final int? selectedPlaylistId;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<int> onPlaylistSelected;

  const TitofyNavRail({
    super.key,
    required this.selectedIndex,
    this.selectedPlaylistId,
    required this.onDestinationSelected,
    required this.onPlaylistSelected,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleService>();
    final db = context.watch<DatabaseService>();
    final player = context.watch<PlayerService>();
    final c = context.colors;
    final playlists = db.playlists;

    final isPlaying = player.isPlaying;
    final hasTrack = player.currentTrack != null;

    return Container(
      width: 224,
      decoration: BoxDecoration(
        color: c.backgroundAlt,
        border: Border(
          right: BorderSide(color: c.glassBorder, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Botones de ventana nativa (macOS style) ────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 16, bottom: 16),
            child: Row(
              children: [
                MacDot(color: const Color(0xFFFF5F56), onTap: () => windowManager.close()),
                const SizedBox(width: 8),
                MacDot(color: const Color(0xFFFFBD2E), onTap: () => windowManager.minimize()),
                const SizedBox(width: 8),
                MacDot(
                  color: const Color(0xFF27C93F),
                  onTap: () async {
                    if (await windowManager.isMaximized()) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                ),
              ],
            ),
          ),

          // ── Logo y Marca Titofy ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 18, right: 18, bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: c.primary.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Titofy',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // ── Lista de Navegación ────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                // ── SECCIÓN 1: DESCUBRIR ──
                const NavSectionHeader(title: 'DESCUBRIR'),
                NavItem(
                  icon: Icons.explore_rounded,
                  label: loc.t('explore'),
                  isSelected: selectedIndex == 0 && selectedPlaylistId == null,
                  onTap: () => onDestinationSelected(0),
                ),
                NavItem(
                  icon: Icons.album_rounded,
                  label: loc.t('albums'),
                  isSelected: selectedIndex == 3 && selectedPlaylistId == null,
                  onTap: () => onDestinationSelected(3),
                ),

                const SizedBox(height: 18),

                // ── SECCIÓN 2: STUDIO IA ──
                const NavSectionHeader(title: 'STUDIO IA'),
                NavItem(
                  icon: Icons.auto_awesome_rounded,
                  label: loc.t('studio'),
                  hasBadge: true,
                  isSelected: selectedIndex == 1 && selectedPlaylistId == null,
                  onTap: () => onDestinationSelected(1),
                ),

                const SizedBox(height: 18),

                // ── SECCIÓN 3: MI BIBLIOTECA ──
                NavSectionHeader(title: loc.t('myMusic')),
                NavItem(
                  icon: Icons.favorite_rounded,
                  label: loc.t('favoriteSongs'),
                  isSelected: selectedIndex == 5 && selectedPlaylistId == null,
                  onTap: () => onDestinationSelected(5),
                ),
                NavItem(
                  icon: Icons.history_rounded,
                  label: loc.t('recentlyPlayed'),
                  isSelected: selectedIndex == 6 && selectedPlaylistId == null,
                  onTap: () => onDestinationSelected(6),
                ),

                const SizedBox(height: 18),

                // ── SECCIÓN 4: EN REPRODUCCIÓN (Contextual Reactivo) ──
                if (hasTrack) ...[
                  NavSectionHeader(
                    title: 'EN REPRODUCCIÓN',
                    actionIcon: isPlaying ? Icons.equalizer_rounded : null,
                  ),
                  NavItem(
                    icon: Icons.graphic_eq_rounded,
                    label: loc.t('visualizer'),
                    isPulsing: isPlaying,
                    isSelected: selectedIndex == 2 && selectedPlaylistId == null,
                    onTap: () => onDestinationSelected(2),
                  ),
                  const SizedBox(height: 18),
                ] else ...[
                  // Visualizador atenuado cuando no hay música activa
                  const NavSectionHeader(title: 'REPRODUCTOR'),
                  NavItem(
                    icon: Icons.graphic_eq_rounded,
                    label: loc.t('visualizer'),
                    isDisabled: true,
                    tooltip: 'Se activa al reproducir música',
                    isSelected: selectedIndex == 2 && selectedPlaylistId == null,
                    onTap: () => onDestinationSelected(2),
                  ),
                  const SizedBox(height: 18),
                ],

                // ── SECCIÓN 5: LISTAS DE REPRODUCCIÓN ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    NavSectionHeader(title: loc.t('playlists'), padding: EdgeInsets.zero),
                    IconButton(
                      icon: Icon(Icons.add_rounded, size: 18, color: c.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 14,
                      tooltip: loc.t('createPlaylist'),
                      onPressed: () async {
                        final created = await CreatePlaylistDialog.show(context);
                        if (created != null) {
                          onPlaylistSelected(created.id);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (playlists.isEmpty)
                  InkWell(
                    onTap: () async {
                      final created = await CreatePlaylistDialog.show(context);
                      if (created != null) {
                        onPlaylistSelected(created.id);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline_rounded, size: 14, color: c.textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '+ Crear primera lista',
                              style: TextStyle(
                                color: c.textMuted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...playlists.map((pl) {
                    final isSelected = selectedPlaylistId == pl.id;
                    return NavPlaylistItem(
                      playlist: pl,
                      isSelected: isSelected,
                      onTap: () => onPlaylistSelected(pl.id),
                    );
                  }),

                const SizedBox(height: 14),
              ],
            ),
          ),

          // ── SECCIÓN INFERIOR FIJA: AJUSTES ─────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: c.glassBorder, width: 0.8),
              ),
            ),
            child: NavItem(
              icon: Icons.settings_rounded,
              label: loc.t('settings'),
              isSelected: selectedIndex == 4 && selectedPlaylistId == null,
              onTap: () => onDestinationSelected(4),
            ),
          ),
        ],
      ),
    );
  }
}
