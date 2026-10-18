import 'package:flutter/material.dart';

/// Barra de progreso interactiva con animación hover y target de clic centrado
class HoverProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const HoverProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  State<HoverProgressBar> createState() => _HoverProgressBarState();
}

class _HoverProgressBarState extends State<HoverProgressBar> {
  bool _isHovered = false;
  double? _dragRatio;

  void _seekFromPosition(double localDx, double totalWidth) {
    if (totalWidth <= 0 || widget.duration.inMilliseconds <= 0) return;
    final ratio = (localDx / totalWidth).clamp(0.0, 1.0);
    final targetMs = (ratio * widget.duration.inMilliseconds).toInt();
    widget.onSeek(Duration(milliseconds: targetMs));
  }

  @override
  Widget build(BuildContext context) {
    final durMs = widget.duration.inMilliseconds;
    final posMs = widget.position.inMilliseconds;
    final currentRatio = durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;
    final displayRatio = _dragRatio ?? currentRatio;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _dragRatio = null;
      }),
      cursor: SystemMouseCursors.click,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              _seekFromPosition(details.localPosition.dx, width);
            },
            onHorizontalDragStart: (details) {
              final r = (details.localPosition.dx / width).clamp(0.0, 1.0);
              setState(() => _dragRatio = r);
            },
            onHorizontalDragUpdate: (details) {
              final r = (details.localPosition.dx / width).clamp(0.0, 1.0);
              setState(() => _dragRatio = r);
            },
            onHorizontalDragEnd: (details) {
              if (_dragRatio != null) {
                final targetMs = (_dragRatio! * durMs).toInt();
                widget.onSeek(Duration(milliseconds: targetMs));
                setState(() => _dragRatio = null);
              }
            },
            child: Container(
              height: 36, // Hit-target amplio, centrado verticalmente
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Pista inactiva
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    height: _isHovered ? 6.0 : 4.0,
                    width: width,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  // Pista activa con degradado blanco brillante
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    height: _isHovered ? 6.0 : 4.0,
                    width: (width * displayRatio).clamp(0.0, width),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        if (_isHovered)
                          BoxShadow(
                            color: Colors.white.withOpacity(0.55),
                            blurRadius: 8,
                          ),
                      ],
                    ),
                  ),
                  // Indicador/Thumb luminoso visible al hacer hover
                  if (_isHovered)
                    Positioned(
                      left: (width * displayRatio - 6).clamp(0.0, width > 12 ? width - 12 : 0.0),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
