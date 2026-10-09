import 'package:flutter/material.dart';
import 'spectrum_controller.dart';
import 'spectrum_painter.dart';

/// Visualizador Desktop Premium de Pantalla Completa
/// Abarca el 100% del ancho disponible sin recortes, con barras continuas neón,
/// jerarquía acústica con bajos prominentes y picos flotantes.
class PlayerFtt extends StatelessWidget {
  final bool isPlaying;
  final int totalBars;
  final double? height;
  final EdgeInsetsGeometry padding;
  final SpectrumController? controller;

  const PlayerFtt({
    super.key,
    this.isPlaying = true,
    this.totalBars = 64,
    this.height,
    this.padding = EdgeInsets.zero,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (controller != null) {
      return AnimatedBuilder(
        animation: controller!,
        builder: (context, _) => CustomPaint(
          size: Size(double.infinity, height ?? double.infinity),
          painter: SpectrumPainter(
            levels: controller!.levels,
            peaks: controller!.peaks,
            beatEnergy: controller!.beatEnergy,
            theme: controller!.theme,
          ),
        ),
      );
    }

    return Container(
      height: height,
      padding: padding,
      child: const SizedBox.expand(),
    );
  }
}

typedef CliSpectrumWidget = PlayerFtt;
