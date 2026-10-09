import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

/// Tarjeta de Vista Previa y Exportación de Resultados LRC
class StudioResultsCard extends StatelessWidget {
  final List<dynamic> resultLines;
  final String? resultSource;

  const StudioResultsCard({
    super.key,
    required this.resultLines,
    this.resultSource,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.primary.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.subtitles_rounded, size: 16, color: c.primary),
                  const SizedBox(width: 8),
                  Text(
                    'VISTA PREVIA DE LETRAS SINCRONIZADAS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.primary),
                  ),
                  if (resultSource != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: c.primary.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 12, color: c.primaryLight),
                          const SizedBox(width: 4),
                          Text(
                            resultSource!,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.primaryLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '${resultLines.length} líneas generadas',
                style: TextStyle(fontSize: 11, color: c.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: resultLines.length,
              itemBuilder: (context, i) {
                final line = resultLines[i];
                final sec = (line['start'] as num? ?? line['time'] as num? ?? 0.0).toDouble();
                final m = (sec ~/ 60).toString().padLeft(2, '0');
                final s = (sec % 60).toStringAsFixed(2).padLeft(5, '0');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text('[$m:$s]', style: TextStyle(fontSize: 11, color: c.primary, fontFamily: 'monospace')),
                      const SizedBox(width: 12),
                      Expanded(child: Text(line['text'] ?? '', style: TextStyle(fontSize: 12, color: c.textPrimary))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
