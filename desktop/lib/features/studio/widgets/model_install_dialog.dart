import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/services/api_service.dart';

/// Diálogo y gestor de instalación / descarga de Modelos Whisper Offline
class ModelInstallDialog extends StatefulWidget {
  final String currentModel;
  final Function(String selectedModel)? onModelSelected;

  const ModelInstallDialog({
    super.key,
    required this.currentModel,
    this.onModelSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentModel,
    Function(String selectedModel)? onModelSelected,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ModelInstallDialog(
        currentModel: currentModel,
        onModelSelected: onModelSelected,
      ),
    );
  }

  @override
  State<ModelInstallDialog> createState() => _ModelInstallDialogState();
}

class _ModelInstallDialogState extends State<ModelInstallDialog> {
  Map<String, Map<String, dynamic>> _modelsInfo = {};
  String? _downloadingModelId;
  String? _errorMessage;

  final List<Map<String, String>> _availableModels = [
    {
      'id': 'base',
      'name': 'BASE (Ultra Rápido)',
      'size': '~140 MB',
      'desc': 'Ideal para CPUs modestas y pruebas rápidas. Precisión estándar.',
      'vram': '≥ 1 GB VRAM / RAM',
    },
    {
      'id': 'small',
      'name': 'SMALL (Recomendado)',
      'size': '~460 MB',
      'desc': 'El equilibrio perfecto entre fidelidad lírica y velocidad.',
      'vram': '≥ 2 GB VRAM / RAM',
    },
    {
      'id': 'turbo',
      'name': 'TURBO (Large-v3 Turbo)',
      'size': '~1.5 GB',
      'desc': 'Máxima precisión neuronal en voces complejas y coros superpuestos.',
      'vram': '≥ 4 GB VRAM / RAM',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchModelsStatus();
  }

  Future<void> _fetchModelsStatus() async {
    try {
      final api = context.read<ApiService>();
      final list = await api.getModels();
      if (mounted && list.isNotEmpty) {
        final map = <String, Map<String, dynamic>>{};
        for (final m in list) {
          map[m['id']?.toString() ?? ''] = m;
        }
        setState(() => _modelsInfo = map);
      }
    } catch (_) {}
  }

  Future<void> _installModel(String modelId) async {
    if (_downloadingModelId != null) return;
    setState(() {
      _downloadingModelId = modelId;
      _errorMessage = null;
    });

    final api = context.read<ApiService>();
    final success = await api.preloadModel(modelId);
    await _fetchModelsStatus();

    if (mounted) {
      setState(() {
        _downloadingModelId = null;
        if (!success) {
          _errorMessage = api.lastErrorMessage ?? 'Tiempo de espera agotado o error de red al descargar el modelo.';
        }
      });

      if (success) {
        widget.onModelSelected?.call(modelId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Modelo "$modelId" instalado y verificado en caché local.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        width: 600,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.glassBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.primary.withOpacity(0.12),
                    ),
                    child: Icon(Icons.cloud_download_rounded, color: c.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GESTIÓN DE MODELOS WHISPER IA',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Descarga e instala modelos neuronales para transcripción 100% offline.',
                          style: TextStyle(fontSize: 12, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: c.textMuted, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.glassBorder),

            // Mensaje de Error si existió
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),

            // Lista de Modelos
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: _availableModels.map((m) {
                  final id = m['id']!;
                  final isCurrent = widget.currentModel == id;
                  final info = _modelsInfo[id];
                  final isDownloaded = info?['downloaded'] == true;
                  final isBusy = _downloadingModelId == id;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCurrent ? c.primary.withOpacity(0.08) : c.backgroundAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCurrent ? c.primary.withOpacity(0.4) : c.glassBorder,
                        width: isCurrent ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Radio<String>(
                          value: id,
                          groupValue: widget.currentModel,
                          activeColor: c.primary,
                          onChanged: (_) {
                            widget.onModelSelected?.call(id);
                            Navigator.of(context).pop();
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    m['name']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: c.surfaceHover,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      m['size']!,
                                      style: TextStyle(fontSize: 10, color: c.textSecondary, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m['desc']!,
                                style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.memory_rounded, size: 12, color: c.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    m['vram']!,
                                    style: TextStyle(fontSize: 10.5, color: c.textMuted),
                                  ),
                                  const Spacer(),
                                  if (isDownloaded)
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Instalado',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Botón de instalación / acción
                        if (!isDownloaded)
                          ElevatedButton.icon(
                            icon: isBusy
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.download_rounded, size: 14),
                            label: Text(isBusy ? 'Descargando...' : 'Descargar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            onPressed: _downloadingModelId != null ? null : () => _installModel(id),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
