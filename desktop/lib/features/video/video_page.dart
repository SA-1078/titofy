import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class VideoPage extends StatelessWidget {
  const VideoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_rounded, size: 48, color: c.textMuted),
            const SizedBox(height: 12),
            Text('Mis Videos', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Próximamente', style: TextStyle(color: c.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
