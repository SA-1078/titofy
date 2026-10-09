import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/services/api_service.dart';

/// Tarjeta de Centro de Control y Ejecución de Transcripción
class StudioControlCard extends StatelessWidget {
  final bool isProcessing;
  final double progressValue;
  final String currentStatusText;
  final String selectedMode;
  final String selectedModel;
  final String selectedLanguage;
  final ApiService api;
  final VoidCallback onStartProcessing;
  final VoidCallback onCancelProcessing;

  const StudioControlCard({
    super.key,
    required this.isProcessing,
    required this.progressValue,
    required this.currentStatusText,
    required this.selectedMode,
    required this.selectedModel,
    required this.selectedLanguage,
    required this.api,
    required this.onStartProcessing,
    required this.onCancelProcessing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final modeLabel = {
      'auto': 'Híbrido',
      'ai_only': 'Solo IA',
      'online_only': 'Solo Online',
      'align': 'Alinear',
    }[selectedMode] ?? 'Híbrido';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.glassBorder),
        boxShadow: [
          if (!c.isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.precision_manufacturing_rounded, size: 16, color: c.primary),
              const SizedBox(width: 8),
              Text(
                'CENTRO DE PROCESAMIENTO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.primary,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: api.isOnline ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                api.isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: api.isOnline ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Resumen de Parámetros Activos
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.backgroundAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildInfoRow('Modelo Activo', selectedModel.toUpperCase(), Icons.memory_rounded, c),
                const SizedBox(height: 8),
                _buildInfoRow('Estrategia', modeLabel, Icons.layers_rounded, c),
                const SizedBox(height: 8),
                _buildInfoRow('Idioma', selectedLanguage, Icons.language_rounded, c),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Estado Dinámico y Progreso
          Text(
            'Estado:',
            style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            currentStatusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: currentStatusText.toLowerCase().contains('error') ? AppColors.error : c.textPrimary,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          if (isProcessing) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progressValue > 0 ? progressValue : null,
                minHeight: 6,
                backgroundColor: c.backgroundAlt,
                color: c.primary,
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Botón Principal
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              icon: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(
                isProcessing ? 'PROCESANDO AUDIO...' : 'INICIAR TRANSCRIPCIÓN',
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
              ),
              onPressed: isProcessing ? onCancelProcessing : onStartProcessing,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, ThemeColors c) {
    return Row(
      children: [
        Icon(icon, size: 13, color: c.primary),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: c.textSecondary)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.textPrimary)),
      ],
    );
  }
}
