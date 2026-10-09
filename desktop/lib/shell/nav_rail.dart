import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../core/theme/colors.dart';
import '../core/services/locale_service.dart';
import '../core/services/database_service.dart';
import '../core/services/player_service.dart';
import '../features/music/create_playlist_dialog.dart';

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
                _MacDot(color: const Color(0xFFFF5F56), onTap: () => windowManager.close()),
                const SizedBox(width: 8),
                _MacDot(color: const Color(0xFFFFBD2E), onTap: () => windowManager.minimize()),
                const SizedBox(width: 8),
                _MacDot(
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
                const _SectionHeader(title: 'DESCUBRIR'),
                _NavItem(
                  icon: Icons.explore_rounded,
                  label: loc.t('explore'),
                  isSelected: selectedIndex == 0 && selectedPlaylistId == null,
                  onTap: () => onDestinationSelected(0),
                ),
                _NavItem(
                  icon: Icons.album_rounded,
                  label: loc.t('albums'),
                  isSelected: selectedIndex == 3 && selectedPlaylistId == null,
                  onTap: () => onDestinationSelected(3),
                ),

                const SizedBox(height: 18),

                // ── SECCIÓN 2: STUDIO IA ──
                const _SectionHeader(title: 'STUDIO IA'),
                _NavItem(
                  icon: Icons.auto_awesome_rounded,
                  label: loc.t('studio'),
                  hasBadge: true,
                  isSelected: selectedIndex == 1 && selectedPlaylistId == null,
                  onTap: () => onDestinationSelected(1),
                ),

                const SizedBox(height: 18),

                // ── SECCIÓN 3: MI BIBLIOTECA ──
                _SectionHeader(title: loc.t('myMusic')),
                _NavItem(
                  icon: Icons.favorite_rounded,
                  label: loc.t('favoriteSongs'),
                  isSelected: selectedIndex == 5 && selectedPlaylistId == null,
                  onTap: () => onDestinationSelected(5),
                ),
                _NavItem(
                  icon: Icons.history_rounded,
                  label: loc.t('recentlyPlayed'),
                  isSelected: selectedIndex == 6 && selectedPlaylistId == null,
                  onTap: () => onDestinationSelected(6),
                ),

                const SizedBox(height: 18),

                // ── SECCIÓN 4: EN REPRODUCCIÓN (Contextual Reactivo) ──
                if (hasTrack) ...[
                  _SectionHeader(
                    title: 'EN REPRODUCCIÓN',
                    actionIcon: isPlaying ? Icons.equalizer_rounded : null,
                  ),
                  _NavItem(
                    icon: Icons.graphic_eq_rounded,
                    label: loc.t('visualizer'),
                    isPulsing: isPlaying,
                    isSelected: selectedIndex == 2 && selectedPlaylistId == null,
                    onTap: () => onDestinationSelected(2),
                  ),
                  const SizedBox(height: 18),
                ] else ...[
                  // Visualizador atenuado cuando no hay música activa
                  _SectionHeader(title: 'REPRODUCTOR'),
                  _NavItem(
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
                    _SectionHeader(title: loc.t('playlists'), padding: EdgeInsets.zero),
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
                    return _PlaylistItemWidget(
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
            child: _NavItem(
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsets padding;
  final IconData? actionIcon;

  const _SectionHeader({
    required this.title,
    this.padding = const EdgeInsets.only(left: 8, bottom: 6),
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: c.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          if (actionIcon != null) ...[
            const SizedBox(width: 6),
            Icon(actionIcon, size: 12, color: c.primary),
          ],
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool hasBadge;
  final bool isDisabled;
  final bool isPulsing;
  final String? tooltip;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.hasBadge = false,
    this.isDisabled = false,
    this.isPulsing = false,
    this.tooltip,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isPulsing) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.isPulsing && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected;
    final c = context.colors;
    final disabled = widget.isDisabled;

    Widget item = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? (c.isDark ? c.primary.withOpacity(0.12) : c.primary.withOpacity(0.08))
                : _hovered
                    ? c.surfaceHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Barra vertical sutil indicadora de selección activa
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3,
                height: active ? 16 : 0,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: active ? 8 : 0),

              // Icono
              Icon(
                widget.icon,
                size: 18,
                color: disabled
                    ? c.textMuted.withOpacity(0.4)
                    : active
                        ? c.primary
                        : (_hovered ? c.textPrimary : c.textSecondary),
              ),
              const SizedBox(width: 10),

              // Texto
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: disabled
                        ? c.textMuted.withOpacity(0.4)
                        : active
                            ? (c.isDark ? Colors.white : c.primary)
                            : (_hovered ? c.textPrimary : c.textSecondary),
                  ),
                ),
              ),

              // Badge o indicador animado
              if (widget.isPulsing)
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.primary.withOpacity(0.5 + _pulseCtrl.value * 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: c.primary.withOpacity(0.4 * _pulseCtrl.value),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                )
              else if (widget.hasBadge)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'IA',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: c.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: item,
      );
    }
    return item;
  }
}

class _PlaylistItemWidget extends StatefulWidget {
  final PlaylistModel playlist;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlaylistItemWidget({
    required this.playlist,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PlaylistItemWidget> createState() => _PlaylistItemWidgetState();
}

class _PlaylistItemWidgetState extends State<_PlaylistItemWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(vertical: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
          decoration: BoxDecoration(
            color: active
                ? (c.isDark ? c.primary.withOpacity(0.10) : c.primary.withOpacity(0.06))
                : _hovered
                    ? c.surfaceHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3,
                height: active ? 14 : 0,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: active ? 6 : 0),
              Icon(
                Icons.playlist_play_rounded,
                size: 17,
                color: active ? c.primary : (_hovered ? c.textPrimary : c.textMuted),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? (c.isDark ? Colors.white : c.primary) : (_hovered ? c.textPrimary : c.textSecondary),
                  ),
                ),
              ),
              if (playlist.trackCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: active ? c.primary.withOpacity(0.15) : c.surfaceHover,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${playlist.trackCount}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: active ? c.primary : c.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  PlaylistModel get playlist => widget.playlist;
}

class _MacDot extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  const _MacDot({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
