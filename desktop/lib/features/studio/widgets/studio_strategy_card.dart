import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import 'model_install_dialog.dart';

/// Tarjeta de Parámetros de Transcripción y Selección de Estrategia
class StudioStrategyCard extends StatelessWidget {
  final String selectedMode;
  final String selectedModel;
  final String selectedLanguage;
  final TextEditingController customLyricsCtrl;
  final Map<String, Map<String, dynamic>> modelsInfo;
  final Function(String mode) onModeChanged;
  final Function(String model) onModelChanged;
  final Function(String language) onLanguageChanged;
  final VoidCallback onRefreshModels;

  static const List<String> availableModels = ['base', 'small', 'turbo'];
  static const Map<String, String> availableLanguages = {
    'auto': 'Auto-detectar',
    'es': 'Español (es)',
    'en': 'Inglés (en)',
    'pt': 'Portugués (pt)',
    'fr': 'Francés (fr)',
  };

  const StudioStrategyCard({
    super.key,
    required this.selectedMode,
    required this.selectedModel,
    required this.selectedLanguage,
    required this.customLyricsCtrl,
    required this.modelsInfo,
    required this.onModeChanged,
    required this.onModelChanged,
    required this.onLanguageChanged,
    required this.onRefreshModels,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

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
              Icon(Icons.tune_rounded, size: 16, color: c.primary),
              const SizedBox(width: 8),
              Text(
                '2. PARÁMETROS Y ESTRATEGIA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.primary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Selector de Estrategia
          Text(
            'Estrategia de resolución:',
            style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStrategyChip('auto', 'Híbrido (Online + Ajuste Local)', Icons.layers_rounded, c),
              _buildStrategyChip('ai_only', 'Transcribir con IA Local', Icons.memory_rounded, c),
              _buildStrategyChip('online_only', 'Solo Online', Icons.cloud_rounded, c),
              _buildStrategyChip('align', 'Alinear con Audio', Icons.format_align_left_rounded, c),
            ],
          ),

          const SizedBox(height: 14),

          // Modelo e Idioma
          Row(
            children: [
              // Selector de Modelo Whisper
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Modelo Whisper:',
                          style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () async {
                            await ModelInstallDialog.show(
                              context,
                              currentModel: selectedModel,
                              onModelSelected: onModelChanged,
                            );
                            onRefreshModels();
                          },
                          child: Text(
                            'Gestionar Modelos',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: c.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: c.backgroundAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.glassBorder),
                      ),
                      child: DropdownButton<String>(
                        value: selectedModel,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        dropdownColor: c.surface,
                        style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                        items: availableModels.map((m) {
                          final label = m == 'turbo'
                              ? 'TURBO (large-v3)'
                              : m == 'small'
                                  ? 'SMALL (Recomendado)'
                                  : 'BASE (Rápido)';
                          return DropdownMenuItem(value: m, child: Text(label));
                        }).toList(),
                        onChanged: (v) => onModelChanged(v ?? 'small'),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Builder(
                      builder: (context) {
                        final info = modelsInfo[selectedModel];
                        final isDownloaded = info?['downloaded'] == true;
                        final sizeStr = info?['size'] ??
                            (selectedModel == 'turbo'
                                ? '~1.5 GB'
                                : selectedModel == 'small'
                                    ? '~460 MB'
                                    : '~140 MB');

                        return Row(
                          children: [
                            Icon(
                              isDownloaded ? Icons.check_circle_rounded : Icons.cloud_download_rounded,
                              size: 13,
                              color: isDownloaded ? AppColors.success : c.accent,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                isDownloaded ? 'Listo en disco ($sizeStr)' : 'Auto-descarga en 1er uso ($sizeStr)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDownloaded ? AppColors.success : c.textMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isDownloaded)
                              InkWell(
                                onTap: () async {
                                  await ModelInstallDialog.show(
                                    context,
                                    currentModel: selectedModel,
                                    onModelSelected: onModelChanged,
                                  );
                                  onRefreshModels();
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text(
                                    'Descargar',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: c.accent,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Selector de Idioma
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Idioma:',
                      style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: c.backgroundAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.glassBorder),
                      ),
                      child: DropdownButton<String>(
                        value: selectedLanguage,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        dropdownColor: c.surface,
                        style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                        items: availableLanguages.entries
                            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (v) => onLanguageChanged(v ?? 'auto'),
                      ),
                    ),
                    const SizedBox(height: 19),
                  ],
                ),
              ),
            ],
          ),

          if (selectedMode == 'align') ...[
            const SizedBox(height: 14),
            Text(
              'Texto plano para Forced Alignment:',
              style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: customLyricsCtrl,
              maxLines: 3,
              style: TextStyle(fontSize: 11.5, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Pega aquí la letra verso por verso...',
                hintStyle: TextStyle(fontSize: 11.5, color: c.textMuted),
                filled: true,
                fillColor: c.backgroundAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStrategyChip(String mode, String label, IconData icon, ThemeColors c) {
    final isSelected = selectedMode == mode;
    return InkWell(
      onTap: () => onModeChanged(mode),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? c.primary : c.backgroundAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? c.primary : c.glassBorder),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: c.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : c.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
