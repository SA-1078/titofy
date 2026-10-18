import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../core/theme/colors.dart';
import '../core/services/locale_service.dart';
import '../core/services/database_service.dart';
import '../core/services/player_service.dart';
import '../features/music/create_playlist_dialog.dart';
import '../features/music/import_youtube_dialog.dart';
import 'nav_rail_widgets.dart';

/// Barra de Navegación Lateral Reorganizada (Estructura Jerárquica Limpia)
/// - DESCUBRIR (Explorar, Álbumes)
/// - MI BIBLIOTECA (Toda la biblioteca, Canciones favoritas, Reproducidos recientemente, Listas desplegables)
/// - HERRAMIENTAS (IA Studio, Visualizador FFT)
/// - AJUSTES (Fijo al pie)
class TitofyNavRail extends StatefulWidget {
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
  State<TitofyNavRail> createState() => _TitofyNavRailState();
}

class _TitofyNavRailState extends State<TitofyNavRail> {
  bool _playlistsExpanded = true;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleService>();
    final db = context.watch<DatabaseService>();
    // El rail solo necesita saber si hay reproducción activa. No debe
    // reconstruirse con cada tick de posición del reproductor.
    final isPlaying = context.select<PlayerService, bool>(
      (player) => player.isPlaying,
    );
    final c = context.colors;
    final playlists = db.playlists;

    if (!_initialized) {
      _playlistsExpanded =
          db.getSetting('nav_playlists_expanded', 'true') == 'true';
      _initialized = true;
    }

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: c.backgroundAlt,
        border: Border(right: BorderSide(color: c.glassBorder, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Botones de ventana nativa (macOS style) ────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 16, bottom: 16),
            child: Row(
              children: [
                MacDot(
                  color: const Color(0xFFFF5F56),
                  onTap: () => windowManager.close(),
                ),
                const SizedBox(width: 8),
                MacDot(
                  color: const Color(0xFFFFBD2E),
                  onTap: () => windowManager.minimize(),
                ),
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
                        color: c.primary.withValues(alpha: 0.35),
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
                // ── SECCIÓN 1: DESCUBRIR ─────────────────────────────────────
                const NavSectionHeader(title: 'DESCUBRIR'),
                NavItem(
                  icon: Icons.explore_rounded,
                  label: loc.t('explore'),
                  isSelected:
                      widget.selectedIndex == 0 &&
                      widget.selectedPlaylistId == null,
                  onTap: () => widget.onDestinationSelected(0),
                ),
                NavItem(
                  icon: Icons.album_rounded,
                  label: loc.t('albums'),
                  isSelected:
                      widget.selectedIndex == 3 &&
                      widget.selectedPlaylistId == null,
                  onTap: () => widget.onDestinationSelected(3),
                ),

                const SizedBox(height: 18),

                // ── SECCIÓN 2: MI BIBLIOTECA ─────────────────────────────────
                NavSectionHeader(title: loc.t('myMusic')),
                NavItem(
                  icon: Icons.queue_music_rounded,
                  label: 'Toda la biblioteca',
                  isSelected:
                      widget.selectedIndex == 7 &&
                      widget.selectedPlaylistId == null,
                  onTap: () => widget.onDestinationSelected(7),
                ),
                NavItem(
                  icon: Icons.favorite_rounded,
                  label: loc.t('favoriteSongs'),
                  isSelected:
                      widget.selectedIndex == 5 &&
                      widget.selectedPlaylistId == null,
                  onTap: () => widget.onDestinationSelected(5),
                ),
                NavItem(
                  icon: Icons.history_rounded,
                  label: loc.t('recentlyPlayed'),
                  isSelected:
                      widget.selectedIndex == 6 &&
                      widget.selectedPlaylistId == null,
                  onTap: () => widget.onDestinationSelected(6),
                ),

                // ── SUB-SECCIÓN: LISTAS DE REPRODUCCIÓN (Desplegable Interactivo)
                const SizedBox(height: 4),
                Container(
                  margin: const EdgeInsets.only(top: 2, bottom: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      // Cabecera interactiva con toggle desplegable
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(
                              () => _playlistsExpanded = !_playlistsExpanded,
                            );
                            db.setSetting(
                              'nav_playlists_expanded',
                              _playlistsExpanded ? 'true' : 'false',
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                AnimatedRotation(
                                  turns: _playlistsExpanded ? 0 : -0.25,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    Icons.expand_more_rounded,
                                    size: 16,
                                    color: c.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    loc.t('playlists').toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: c.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Botón [+] con menú: Crear lista o Importar YouTube
                      PopupMenuButton<String>(
                        tooltip: 'Añadir o importar lista',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 14,
                        icon: Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: c.textMuted,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: c.surface,
                        onSelected: (value) async {
                          if (value == 'create') {
                            final created = await CreatePlaylistDialog.show(
                              context,
                            );
                            if (created != null) {
                              widget.onPlaylistSelected(created.id);
                            }
                          } else if (value == 'youtube') {
                            final created = await ImportYouTubeDialog.show(
                              context,
                            );
                            if (created != null) {
                              widget.onPlaylistSelected(created.id);
                            }
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'create',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.playlist_add_rounded,
                                  size: 18,
                                  color: c.primary,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Nueva lista de reproducción',
                                  style: TextStyle(
                                    color: c.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'youtube',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.smart_display_outlined,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Importar desde YouTube / YT Music',
                                  style: TextStyle(
                                    color: c.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Contenido Desplegable de Listas de Reproducción
                AnimatedCrossFade(
                  firstChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (playlists.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 12,
                            top: 4,
                            bottom: 4,
                          ),
                          child: InkWell(
                            onTap: () async {
                              final created = await CreatePlaylistDialog.show(
                                context,
                              );
                              if (created != null) {
                                widget.onPlaylistSelected(created.id);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add_circle_outline_rounded,
                                    size: 14,
                                    color: c.textMuted,
                                  ),
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
                          ),
                        )
                      else ...[
                        ...playlists.map((pl) {
                          final isSelected = widget.selectedPlaylistId == pl.id;
                          return NavPlaylistItem(
                            playlist: pl,
                            isSelected: isSelected,
                            onTap: () => widget.onPlaylistSelected(pl.id),
                          );
                        }),
                        // Acceso rápido directo dentro del submenú para importar playlist
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 8,
                            top: 4,
                            bottom: 2,
                          ),
                          child: InkWell(
                            onTap: () async {
                              final created = await ImportYouTubeDialog.show(
                                context,
                              );
                              if (created != null) {
                                widget.onPlaylistSelected(created.id);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.smart_display_outlined,
                                    size: 14,
                                    color: Colors.redAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '+ Importar playlist',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: c.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  secondChild: const SizedBox.shrink(),
                  crossFadeState: _playlistsExpanded
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: const Duration(milliseconds: 200),
                ),

                const SizedBox(height: 18),

                // ── SECCIÓN 3: HERRAMIENTAS ──────────────────────────────────
                const NavSectionHeader(title: 'HERRAMIENTAS'),
                NavItem(
                  icon: Icons.auto_awesome_rounded,
                  label: loc.t('studio'),
                  hasBadge: true,
                  isSelected:
                      widget.selectedIndex == 1 &&
                      widget.selectedPlaylistId == null,
                  onTap: () => widget.onDestinationSelected(1),
                ),
                NavItem(
                  icon: Icons.graphic_eq_rounded,
                  label: loc.t('visualizer'),
                  isPulsing: isPlaying,
                  isSelected:
                      widget.selectedIndex == 2 &&
                      widget.selectedPlaylistId == null,
                  onTap: () => widget.onDestinationSelected(2),
                ),

                const SizedBox(height: 14),
              ],
            ),
          ),

          // ── SECCIÓN INFERIOR FIJA: AJUSTES ─────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.glassBorder, width: 0.8)),
            ),
            child: NavItem(
              icon: Icons.settings_rounded,
              label: loc.t('settings'),
              isSelected:
                  widget.selectedIndex == 4 &&
                  widget.selectedPlaylistId == null,
              onTap: () => widget.onDestinationSelected(4),
            ),
          ),
        ],
      ),
    );
  }
}
