import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Fondo base negro puro OLED
        Container(color: AppColors.background),

        // 2. Globo brillante 1 (Violeta)
        Positioned(
          top: -80,
          left: -40,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.18),
            ),
          ),
        ),

        // 3. Globo brillante 2 (Cyan)
        Positioned(
          bottom: 100,
          right: -80,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withOpacity(0.14),
            ),
          ),
        ),

        // 4. Globo brillante 3 (Rosa / Acento)
        Positioned(
          top: 250,
          right: 150,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withOpacity(0.08),
            ),
          ),
        ),

        // 5. Filtro de desenfoque gaussiano masivo para difuminar los globos
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
            child: Container(color: Colors.transparent),
          ),
        ),

        // 6. El contenido real de la app por encima del fondo
        SafeArea(
          child: child,
        ),
      ],
    );
  }
}
