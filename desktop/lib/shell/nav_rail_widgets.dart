import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/services/database_service.dart';

class MacDot extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  const MacDot({super.key, required this.color, required this.onTap});

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

class NavSectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsets padding;
  final IconData? actionIcon;

  const NavSectionHeader({
    super.key,
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

class NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool hasBadge;
  final bool isDisabled;
  final bool isPulsing;
  final String? tooltip;
  final VoidCallback onTap;

  const NavItem({
    super.key,
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
  State<NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<NavItem> with SingleTickerProviderStateMixin {
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
  void didUpdateWidget(NavItem oldWidget) {
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

class NavPlaylistItem extends StatefulWidget {
  final PlaylistModel playlist;
  final bool isSelected;
  final VoidCallback onTap;

  const NavPlaylistItem({
    super.key,
    required this.playlist,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<NavPlaylistItem> createState() => _NavPlaylistItemState();
}

class _NavPlaylistItemState extends State<NavPlaylistItem> {
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
                  widget.playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? (c.isDark ? Colors.white : c.primary) : (_hovered ? c.textPrimary : c.textSecondary),
                  ),
                ),
              ),
              if (widget.playlist.trackCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: active ? c.primary.withOpacity(0.15) : c.surfaceHover,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${widget.playlist.trackCount}',
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
}
