import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/services/api_service.dart';

/// Tarjeta de Procesamiento y Resumen de Ejecución (Paso 03)
/// Muestra estado del motor, resumen de la configuración elegida,
/// estado de ejecución con manejo limpio de errores técnicos y botón de inicio al fondo.
class StudioControlCard extends StatefulWidget {
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
  State<StudioControlCard> createState() => _StudioControlCardState();
}

class _StudioControlCardState extends State<StudioControlCard> {
  bool _showErrorDetails = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // ── Resumen de Configuración Elegida ──────────────────────────────
    final modeLabel = switch (widget.selectedMode) {
      'hybrid' => 'Híbrido',
      'ai_only' => 'IA local',
      'online_only' => 'Solo online',
      'align' => 'Alinear',
      _ => 'Híbrido',
    };

    final langLabel = switch (widget.selectedLanguage) {
      'auto' => 'Automático',
      'es' => 'Español',
      'en' => 'Inglés',
      'pt' => 'Portugués',
      'fr' => 'Francés',
      _ => widget.selectedLanguage,
    };

    final configSummary = widget.selectedMode == 'online_only'
        ? 'Solo online · Búsqueda web directa'
        : '$modeLabel · ${widget.selectedModel.toUpperCase()} · $langLabel';

    // ── Estado y Errores ──────────────────────────────────────────────
    final isError = widget.currentStatusText.toLowerCase().contains('error') ||
        widget.currentStatusText.toLowerCase().contains('fallo');
    final isDone = widget.currentStatusText.toLowerCase().contains('completad');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
          // ── Encabezado Paso 03 ──────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '03',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: c.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Procesamiento',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              // Indicador de disponibilidad del motor
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.api.isOnline ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    size: 14,
                    color: widget.api.isOnline ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.api.isOnline ? 'Motor disponible' : 'Backend offline',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.api.isOnline ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Configuración Elegida ───────────────────────────────────────
          Text(
            'Configuración elegida',
            style: TextStyle(
              fontSize: 11.5,
              color: c.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            configSummary,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 16),

          // ── Tarjeta de Estado del Proceso ──────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.backgroundAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isError
                    ? AppColors.error.withOpacity(0.3)
                    : isDone
                        ? AppColors.success.withOpacity(0.3)
                        : c.glassBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Estado',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isError
                            ? AppColors.error
                            : isDone
                                ? AppColors.success
                                : c.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    if (widget.isProcessing)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: c.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                if (widget.isProcessing) ...[
                  Text(
                    'Procesando audio...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.currentStatusText,
                    style: TextStyle(fontSize: 11, color: c.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: widget.progressValue > 0 ? widget.progressValue : null,
                      minHeight: 5,
                      backgroundColor: c.surface,
                      color: c.primary,
                    ),
                  ),
                ] else if (isError) ...[
                  Text(
                    'No se pudo completar la transcripción',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Revisa los parámetros o consulta el detalle técnico a continuación.',
                    style: TextStyle(fontSize: 11, color: c.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => setState(() => _showErrorDetails = !_showErrorDetails),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showErrorDetails ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            size: 14,
                            color: c.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showErrorDetails ? 'Ocultar detalles' : 'Ver detalles técnicos',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: c.textSecondary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showErrorDetails) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.glassBorder),
                      ),
                      child: SelectableText(
                        widget.currentStatusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: c.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ] else if (isDone) ...[
                  Text(
                    'Transcripción finalizada',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.currentStatusText,
                    style: TextStyle(fontSize: 11, color: c.textSecondary),
                  ),
                ] else ...[
                  Text(
                    'Listo para comenzar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'El resultado aparecerá aquí.',
                    style: TextStyle(fontSize: 11, color: c.textMuted),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Botón Principal de Inicio ────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: widget.isProcessing ? widget.onCancelProcessing : widget.onStartProcessing,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                shadowColor: c.primary.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isProcessing
                        ? Icons.stop_circle_outlined
                        : switch (widget.selectedMode) {
                            'online_only' => Icons.cloud_download_rounded,
                            'align' => Icons.sync_rounded,
                            _ => Icons.play_circle_fill_rounded,
                          },
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isProcessing
                        ? 'CANCELAR PROCESO'
                        : switch (widget.selectedMode) {
                            'online_only' => 'BUSCAR LETRA ONLINE',
                            'align' => 'INICIAR ALINEACIÓN',
                            _ => 'INICIAR TRANSCRIPCIÓN',
                          },
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
