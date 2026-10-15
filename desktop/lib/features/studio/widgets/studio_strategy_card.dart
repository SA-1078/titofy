import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import 'model_install_dialog.dart';

/// Tarjeta de Configuración de Transcripción (Paso 02)
/// Optimizada para ser compacta, evitar desorden visual y adaptarse
/// armoniosamente a los cambios entre estrategias sin desproporcionar la interfaz.
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.glassBorder),
        boxShadow: [
          if (!c.isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Encabezado Paso 02 ──────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '02',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: c.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Configuración',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Selector de Estrategia de Resolución ────────────────────────
          Text(
            'Estrategia de resolución',
            style: TextStyle(
              fontSize: 11,
              color: c.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),

          // 4 opciones compactas y estilizadas
          Column(
            children: [
              _buildOption(
                mode: 'hybrid',
                title: 'Híbrido',
                subtitle: 'Online + ajuste acústico local',
                icon: Icons.layers_rounded,
                c: c,
              ),
              const SizedBox(height: 5),
              _buildOption(
                mode: 'ai_only',
                title: 'Transcribir con IA local',
                subtitle: 'Whisper local en GPU sin conexión',
                icon: Icons.memory_rounded,
                c: c,
              ),
              const SizedBox(height: 5),
              _buildOption(
                mode: 'online_only',
                title: 'Solo online',
                subtitle: 'Búsqueda web directa en fuentes online',
                icon: Icons.cloud_rounded,
                c: c,
              ),
              const SizedBox(height: 5),
              _buildOption(
                mode: 'align',
                title: 'Alinear con audio',
                subtitle: 'Sincroniza texto existente con el audio',
                icon: Icons.format_align_left_rounded,
                c: c,
              ),
            ],
          ),

          // ── Breve línea explicativa dinámica (sin caja pesada) ───────────
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4, left: 2),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 12.5, color: c.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _getExplanation(selectedMode),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: c.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // ── Campo de texto condicional SOLO para 'align' ─────────────────
          if (selectedMode == 'align') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: c.backgroundAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.primary.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note_rounded, size: 14, color: c.primary),
                      const SizedBox(width: 5),
                      Text(
                        'Texto para Forced Alignment',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: customLyricsCtrl,
                    maxLines: 3,
                    style: TextStyle(fontSize: 11, color: c.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      hintText: 'Pega aquí la letra verso por verso para sincronizarla...',
                      hintStyle: TextStyle(fontSize: 10.5, color: c.textMuted),
                      filled: true,
                      fillColor: c.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: c.glassBorder),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          Divider(height: 1, thickness: 0.8, color: c.glassBorder.withOpacity(0.6)),
          const SizedBox(height: 10),

          // ── Sección Inferior: Modelo e Idioma o Aviso Informativo ─────────
          if (selectedMode == 'online_only')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.backgroundAlt.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.glassBorder.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_done_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Solo Online descarga la letra directamente desde internet. No requiere Whisper ni tarjeta gráfica.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: c.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna 1: Modelo de IA
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Modelo de IA',
                            style: TextStyle(
                              fontSize: 11,
                              color: c.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
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
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: c.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Gestionar',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: c.backgroundAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.glassBorder),
                        ),
                        child: DropdownButton<String>(
                          value: selectedModel,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          dropdownColor: c.surface,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
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
                      const SizedBox(height: 4),
                      _buildModelStatus(c),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Columna 2: Idioma
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Idioma',
                        style: TextStyle(
                          fontSize: 11,
                          color: c.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: c.backgroundAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.glassBorder),
                        ),
                        child: DropdownButton<String>(
                          value: selectedLanguage,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          dropdownColor: c.surface,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                          items: availableLanguages.entries
                              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                              .toList(),
                          onChanged: (v) => onLanguageChanged(v ?? 'auto'),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Detección automática recomendada',
                        style: TextStyle(fontSize: 9.5, color: c.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required String mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeColors c,
  }) {
    final isSelected = selectedMode == mode;

    return InkWell(
      onTap: () => onModeChanged(mode),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? c.primary : c.backgroundAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? c.primary : c.glassBorder,
            width: isSelected ? 1.3 : 1.0,
          ),
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
          children: [
            Icon(
              icon,
              size: 16.5,
              color: isSelected ? Colors.white : c.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : c.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: isSelected
                          ? Colors.white.withOpacity(0.9)
                          : c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: Colors.white,
              ),
          ],
        ),
      ),
    );
  }

  String _getExplanation(String mode) {
    return switch (mode) {
      'hybrid' => 'Combina la resolución online con el ajuste acústico de Whisper si es necesario.',
      'ai_only' => 'Transcribe el audio localmente con Whisper, sin conexión a Internet.',
      'online_only' => 'Descarga la letra de fuentes online sin procesar el audio ni usar IA.',
      'align' => 'Sincroniza un texto previamente proporcionado con el audio mediante IA.',
      _ => '',
    };
  }

  Widget _buildModelStatus(ThemeColors c) {
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
          size: 11,
          color: isDownloaded ? AppColors.success : c.accent,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            isDownloaded ? 'En disco ($sizeStr)' : 'Descarga en 1er uso ($sizeStr)',
            style: TextStyle(
              fontSize: 9.5,
              color: isDownloaded ? AppColors.success : c.textMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
