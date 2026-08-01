import 'package:flutter/material.dart';
import '../core/theme/colors.dart';

class TitofyNavRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const TitofyNavRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.music_note_rounded, label: 'Mi Música'),
    _NavItem(icon: Icons.movie_rounded, label: 'Mis Videos'),
    _NavItem(icon: Icons.auto_awesome_rounded, label: 'IA Studio'),
    _NavItem(icon: Icons.settings_rounded, label: 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppColors.glassBg.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.glassBorder.withOpacity(0.4),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 20, bottom: 20),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Titofy',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: AppColors.textPrimary,
                      ),
                ),
              ],
            ),
          ),

          // Nav items en scroll por si acaso
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 6),
                    child: Text(
                      'BIBLIOTECA',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                            letterSpacing: 1.5,
                          ),
                    ),
                  ),
                  _buildNavItem(0),
                  _buildNavItem(1),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 6),
                    child: Text(
                      'MOTOR IA',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                            letterSpacing: 1.5,
                          ),
                    ),
                  ),
                  _buildNavItem(2),
                  _buildNavItem(3),
                ],
              ),
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Engine: Local',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final item = _items[index];
    final isSelected = selectedIndex == index;
    return _NavTile(
      icon: item.icon,
      label: item.label,
      selected: isSelected,
      onTap: () => onDestinationSelected(index),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _NavTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: widget.selected
                ? AppColors.glassSelected
                : _isHovered
                    ? AppColors.glassHover
                    : Colors.transparent,
            border: Border.all(
              color: widget.selected
                  ? AppColors.glassBorder
                  : _isHovered
                      ? AppColors.glassBorder.withOpacity(0.5)
                      : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.selected
                    ? AppColors.primaryLight
                    : _isHovered
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: widget.selected
                            ? AppColors.textPrimary
                            : _isHovered
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                        fontWeight: widget.selected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                      ),
                ),
              ),
              if (widget.selected)
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryLight,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
