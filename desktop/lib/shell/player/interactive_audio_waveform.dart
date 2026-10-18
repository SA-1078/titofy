import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Waveform de audio interactivo estilo UI_titofy_3
/// Muestra una onda de audio orgánica y reactiva con soporte de búsqueda (seek)
class InteractiveAudioWaveform extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final ValueChanged<Duration> onSeek;

  const InteractiveAudioWaveform({
    super.key,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.onSeek,
  });

  @override
  State<InteractiveAudioWaveform> createState() =>
      _InteractiveAudioWaveformState();
}

class _InteractiveAudioWaveformState extends State<InteractiveAudioWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  double? _hoverPercent;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    if (widget.isPlaying) {
      _animCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(InteractiveAudioWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_animCtrl.isAnimating) {
      _animCtrl.repeat();
    } else if (!widget.isPlaying && _animCtrl.isAnimating) {
      _animCtrl.stop();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _handleSeek(double localX, double width) {
    if (width <= 0) return;
    final percent = (localX / width).clamp(0.0, 1.0);
    final targetMs = (widget.duration.inMilliseconds * percent).round();
    widget.onSeek(Duration(milliseconds: targetMs));
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.duration.inMilliseconds;
    final currentMs = widget.position.inMilliseconds;
    final progress = totalMs > 0 ? (currentMs / totalMs).clamp(0.0, 1.0) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onHover: (e) {
            setState(() {
              _hoverPercent = (e.localPosition.dx / width).clamp(0.0, 1.0);
            });
          },
          onExit: (_) {
            setState(() => _hoverPercent = null);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (e) => _handleSeek(e.localPosition.dx, width),
            onHorizontalDragUpdate: (e) =>
                _handleSeek(e.localPosition.dx, width),
            child: SizedBox(
              height: 48,
              width: width,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _WaveformPainter(
                    animation: _animCtrl,
                    progress: progress,
                    hoverPercent: _hoverPercent,
                    isPlaying: widget.isPlaying,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final Animation<double> animation;
  final double progress;
  final double? hoverPercent;
  final bool isPlaying;

  _WaveformPainter({
    required this.animation,
    required this.progress,
    required this.hoverPercent,
    required this.isPlaying,
  }) : super(repaint: animation);

  static double _calcY(double normX, double phase, double midY) {
    // Atenuación natural en los extremos de la barra
    final env = math.sin(normX * math.pi);
    // Armónicos estrictamente periódicos con múltiplos enteros exactos de phase (2*pi)
    // Garantiza que cuando animValue hace loop (1.0 -> 0.0), la forma es 100% continua e idéntica sin saltos bruscos
    final wave1 = math.sin(normX * 6 * math.pi + phase) * 11.0;
    final wave2 = math.sin(normX * 12 * math.pi - phase * 2.0) * 5.0;
    final wave3 = math.sin(normX * 18 * math.pi + phase * 3.0) * 2.5;
    return midY + (wave1 + wave2 + wave3) * env;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final midY = h / 2;

    if (w <= 0 || h <= 0) return;

    final wavePath = Path();
    final playedPath = Path();

    const samplePoints = 140;
    final dx = w / samplePoints;
    final phase = isPlaying ? (_animValue * 2 * math.pi) : 0.0;

    final headNorm = progress.clamp(0.0, 1.0);
    final headX = headNorm * w;
    final headY = _calcY(headNorm, phase, midY);

    for (int i = 0; i <= samplePoints; i++) {
      final x = i * dx;
      final normX = i / samplePoints;
      final y = _calcY(normX, phase, midY);

      if (i == 0) {
        wavePath.moveTo(x, y);
      } else {
        wavePath.lineTo(x, y);
      }

      if (normX <= headNorm) {
        if (i == 0) {
          playedPath.moveTo(x, y);
        } else {
          playedPath.lineTo(x, y);
        }
      }
    }

    // Conectar perfectamente la línea activa con el cabezal
    if (progress > 0) {
      playedPath.lineTo(headX, headY);
    }

    // 1. Dibujar onda inactiva (blanco translúcido suave)
    final inactivePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.32)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(wavePath, inactivePaint);

    // 2. Dibujar onda activa (resplandor neón multicapa acelerado por GPU, sin CPU blur)
    if (progress > 0) {
      final glowOuter = Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 5.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(playedPath, glowOuter);

      final glowInner = Paint()
        ..color = Colors.white.withValues(alpha: 0.40)
        ..strokeWidth = 3.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(playedPath, glowInner);

      final activePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(playedPath, activePaint);

      // Cabezal de aguja neón (halo + núcleo blanco brillante)
      final haloPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(headX, headY), 7.5, haloPaint);

      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(headX, headY), 4.5, dotPaint);
    }

    // 3. Indicador de hover
    if (hoverPercent != null) {
      final hoverX = hoverPercent! * w;
      final hoverLinePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.60)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(hoverX, 6), Offset(hoverX, h - 6), hoverLinePaint);
    }
  }

  double get _animValue => animation.value;

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.hoverPercent != hoverPercent ||
        oldDelegate.isPlaying != isPlaying;
  }
}
