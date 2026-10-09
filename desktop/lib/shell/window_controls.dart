import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Controles circulares de ventana nativa: Minimizar, Maximizar/Restaurar y Cerrar
/// Diseñados con estética limpia según la solicitud del usuario.
class WindowControls extends StatefulWidget {
  final bool isDark;
  const WindowControls({super.key, this.isDark = true});

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _checkMaximized();
  }

  Future<void> _checkMaximized() async {
    try {
      final max = await windowManager.isMaximized();
      if (mounted) setState(() => _isMaximized = max);
    } catch (_) {}
  }

  Future<void> _toggleMaximize() async {
    try {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
        if (mounted) setState(() => _isMaximized = false);
      } else {
        await windowManager.maximize();
        if (mounted) setState(() => _isMaximized = true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final defaultBg = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.black.withOpacity(0.07);
    final iconColor = isDark
        ? Colors.white.withOpacity(0.85)
        : Colors.black.withOpacity(0.75);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Minimizar (-)
        _WindowCircleButton(
          tooltip: 'Minimizar',
          bg: defaultBg,
          hoverBg: isDark ? Colors.white.withOpacity(0.22) : Colors.black.withOpacity(0.15),
          iconColor: iconColor,
          icon: Icons.remove_rounded,
          iconSize: 15,
          onTap: () => windowManager.minimize(),
        ),
        const SizedBox(width: 8),

        // Maximizar / Restaurar (❐)
        _WindowCircleButton(
          tooltip: _isMaximized ? 'Restaurar ventana' : 'Maximizar ventana',
          bg: defaultBg,
          hoverBg: isDark ? Colors.white.withOpacity(0.22) : Colors.black.withOpacity(0.15),
          iconColor: iconColor,
          icon: _isMaximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
          iconSize: 13,
          onTap: _toggleMaximize,
        ),
        const SizedBox(width: 8),

        // Cerrar (✕)
        _WindowCircleButton(
          tooltip: 'Cerrar',
          bg: defaultBg,
          hoverBg: const Color(0xFFEF4444).withOpacity(0.90),
          hoverIconColor: Colors.white,
          iconColor: iconColor,
          icon: Icons.close_rounded,
          iconSize: 15,
          onTap: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _WindowCircleButton extends StatefulWidget {
  final String tooltip;
  final Color bg;
  final Color hoverBg;
  final Color iconColor;
  final Color? hoverIconColor;
  final IconData icon;
  final double iconSize;
  final VoidCallback onTap;

  const _WindowCircleButton({
    required this.tooltip,
    required this.bg,
    required this.hoverBg,
    required this.iconColor,
    this.hoverIconColor,
    required this.icon,
    required this.iconSize,
    required this.onTap,
  });

  @override
  State<_WindowCircleButton> createState() => _WindowCircleButtonState();
}

class _WindowCircleButtonState extends State<_WindowCircleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final currentColor = _isHovered ? widget.hoverBg : widget.bg;
    final currentIconColor = (_isHovered && widget.hoverIconColor != null)
        ? widget.hoverIconColor!
        : widget.iconColor;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: currentColor,
              border: Border.all(
                color: Colors.white.withOpacity(_isHovered ? 0.25 : 0.08),
                width: 0.8,
              ),
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color: currentIconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
