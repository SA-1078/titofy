import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/library_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/services/locale_service.dart';
import '../../core/services/database_service.dart';
import '../../shell/window_controls.dart';

/// Pantalla de Configuración, Tema, Idioma, Biblioteca y Diagnóstico del Sistema
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    _urlCtrl = TextEditingController(text: api.baseUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final library = context.watch<LibraryService>();
    final themeService = context.watch<ThemeService>();
    final loc = context.watch<LocaleService>();
    final db = context.watch<DatabaseService>();
    final c = context.colors;
    final currentVizTheme = db.getSetting('visualizer_theme', 'coralNeon');
    final currentVizMode = db.getSetting('visualizer_mode', 'hybrid');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera Principal ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: c.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: c.primary.withOpacity(0.35),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.settings_rounded, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.t('settings'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Personaliza el tema, idioma, biblioteca local y conexión con el motor de IA',
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  WindowControls(isDark: c.isDark),
                ],
              ),

              const SizedBox(height: 24),

              // ── SECCIÓN 1: TEMA VISUAL GLOBAL (Claro / Oscuro & Color de Acento) ──
              _CardContainer(
                title: loc.t('theme').toUpperCase(),
                icon: Icons.palette_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ThemeOptionCard(
                          title: loc.t('themeDark'),
                          subtitle: 'Fondo Medianoche (#090C15) & Acento Dinámico',
                          isSelected: themeService.themeMode == ThemeMode.dark,
                          accentColor: themeService.accentColor,
                          bgColor: const Color(0xFF0D111E),
                          icon: Icons.dark_mode_rounded,
                          onTap: () => themeService.setThemeMode(ThemeMode.dark),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ThemeOptionCard(
                          title: loc.t('themeLight'),
                          subtitle: 'Fondo Claro (#F4F5FB) & Acento Dinámico',
                          isSelected: themeService.themeMode == ThemeMode.light,
                          accentColor: themeService.accentColor,
                          bgColor: const Color(0xFFF1F3F9),
                          icon: Icons.light_mode_rounded,
                          onTap: () => themeService.setThemeMode(ThemeMode.light),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(height: 1, color: c.glassBorder),
                  const SizedBox(height: 18),

                  // ── APARTADO: COLOR DE LA APLICACIÓN ──────────
                  Row(
                    children: [
                      Icon(Icons.color_lens_rounded, size: 18, color: themeService.accentColor),
                      const SizedBox(width: 8),
                      Text(
                        loc.t('appAccentColor'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: themeService.accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: themeService.accentColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          themeService.accentPreset.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: themeService.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.t('appAccentColorDesc'),
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: AccentPresets.all.map((preset) {
                      final isSelected = themeService.accentColorKey == preset.id;
                      return _AccentColorCard(
                        preset: preset,
                        isSelected: isSelected,
                        onTap: () => themeService.setAccentColor(preset.id),
                      );
                    }).toList(),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── SECCIÓN 2: SELECTOR GLOBAL DE IDIOMA ─────────────────────────
              _CardContainer(
                title: loc.t('language').toUpperCase(),
                icon: Icons.translate_rounded,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: LocaleService.supportedLanguages.entries.map((entry) {
                      final isSelected = loc.currentLanguage == entry.key;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => loc.setLanguage(entry.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isSelected ? c.primary : c.backgroundAlt,
                            border: Border.all(
                              color: isSelected ? c.primary : c.glassBorder,
                              width: 1.2,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: c.primary.withOpacity(0.35),
                                  blurRadius: 12,
                                ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.language_rounded,
                                size: 16,
                                color: isSelected ? Colors.white : c.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                entry.value,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : c.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── SECCIÓN 3: VISUALIZADOR Y ESPECTRO DE AUDIO ──────────────────
            _CardContainer(
              title: loc.t('visualizerSettings').toUpperCase(),
              icon: Icons.graphic_eq_rounded,
              children: [
                Text(
                  loc.t('visualizerTheme'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _VisualizerThemeCard(
                        title: 'Coral Neón',
                        subtitle: 'Púrpura y Rosa Titofy',
                        isSelected: currentVizTheme == 'coralNeon',
                        gradientColors: const [
                          Color(0xFF6B21A8),
                          Color(0xFFD946EF),
                          Color(0xFFFF5E62),
                          Color(0xFFFF9966),
                        ],
                        onTap: () => db.setSetting('visualizer_theme', 'coralNeon'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _VisualizerThemeCard(
                        title: 'Cyberpunk',
                        subtitle: 'Cyan Eléctrico & Violeta',
                        isSelected: currentVizTheme == 'cyberpunk',
                        gradientColors: const [
                          Color(0xFF1E1B4B),
                          Color(0xFF6366F1),
                          Color(0xFF06B6D4),
                          Color(0xFFA855F7),
                        ],
                        onTap: () => db.setSetting('visualizer_theme', 'cyberpunk'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _VisualizerThemeCard(
                        title: 'Arcoíris',
                        subtitle: 'Espectro Completo RGB',
                        isSelected: currentVizTheme == 'rainbow',
                        gradientColors: const [
                          Color(0xFF3B82F6),
                          Color(0xFF10B981),
                          Color(0xFFEAB308),
                          Color(0xFFEF4444),
                        ],
                        onTap: () => db.setSetting('visualizer_theme', 'rainbow'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  loc.t('visualizerDefaultMode'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _ModeOptionChip(
                      label: loc.t('hybridMode'),
                      icon: Icons.layers_rounded,
                      isSelected: currentVizMode == 'hybrid',
                      onTap: () => db.setSetting('visualizer_mode', 'hybrid'),
                    ),
                    _ModeOptionChip(
                      label: loc.t('spectrumMode'),
                      icon: Icons.graphic_eq_rounded,
                      isSelected: currentVizMode == 'spectrumOnly',
                      onTap: () => db.setSetting('visualizer_mode', 'spectrumOnly'),
                    ),
                    _ModeOptionChip(
                      label: loc.t('karaokeMode'),
                      icon: Icons.subtitles_rounded,
                      isSelected: currentVizMode == 'lyricsOnly',
                      onTap: () => db.setSetting('visualizer_mode', 'lyricsOnly'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── SECCIÓN 4: BIBLIOTECA DE MÚSICA LOCAL (Carpeta) ──────────────
            _CardContainer(
              title: loc.t('musicFolder').toUpperCase(),
              icon: Icons.folder_rounded,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.backgroundAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.glassBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.primary.withOpacity(0.12),
                        ),
                        child: Icon(Icons.folder_special_rounded, color: c.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Carpeta activa de pistas:',
                              style: TextStyle(fontSize: 12, color: c.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              library.scannedFolder ?? 'Directorio predeterminado del sistema (~/Música)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: c.primary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${library.realTracks.length} archivos de audio reconocidos',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: c.primaryLight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (library.isScanning) ...[
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('Escaneando...', style: TextStyle(fontSize: 11, color: c.textMuted)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.folder_open_rounded, size: 18),
                        label: Text(loc.t('changeFolder')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                        ),
                        onPressed: library.isScanning ? null : () => library.pickAndScan(),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── SECCIÓN 4: MICROSERVICIO FASTAPI (IA LOCAL) ─────────────────
            _CardContainer(
              title: 'MOTOR DE IA LOCAL (FASTAPI & PYTORCH)',
              icon: Icons.memory_rounded,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: api.isOnline ? AppColors.success : AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            api.isOnline
                                ? 'Conexión activa con FastAPI (http://127.0.0.1:8642)'
                                : 'Servidor local no detectado en el puerto 8642',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: api.isOnline ? AppColors.success : AppColors.error,
                            ),
                          ),
                          if (!api.isOnline && api.lastErrorMessage != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              api.lastErrorMessage!,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.error.withOpacity(0.85),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: api.isStartingBackend
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(api.isOnline ? 'Reiniciar Conexión' : 'Iniciar Servidor'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: api.isOnline ? c.surfaceHover : c.primary,
                        foregroundColor: api.isOnline ? c.textPrimary : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: api.isStartingBackend ? null : () => api.restartBackend(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlCtrl,
                        style: TextStyle(fontSize: 13, color: c.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'URL del Microservicio Local',
                          labelStyle: TextStyle(color: c.textSecondary, fontSize: 12),
                          filled: true,
                          fillColor: c.backgroundAlt,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.surfaceHover,
                        foregroundColor: c.textPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      ),
                      onPressed: () => api.updateBaseUrl(_urlCtrl.text.trim()),
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
                if (api.lastHealth != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.backgroundAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.psychology_rounded, size: 20, color: c.primaryLight),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Modelos descargados dis: ${(api.lastHealth!['models_loaded'] as List?)?.join(', ') ?? 'Ninguno cargado aún (se cargan on-demand)'}',
                            style: TextStyle(fontSize: 12, color: c.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            // ── SECCIÓN 5: ACERCA DE TITOFY ─────────────────────────────────
            _CardContainer(
              title: loc.t('about').toUpperCase(),
              icon: Icons.info_outline_rounded,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: c.primary.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Titofy Desktop v1.0.0', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary)),
                        Text('Suite de Letras Sincronizadas & Reproductor con IA Offline', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Desarrollado bajo licencia GNU General Public License v3.0 (GPL-3.0).\n'
                  'Combina la fluidez de Flutter nativo en escritorio con el motor neuronal Whisper y Forced Alignment de PyTorch en Python.\n'
                  '© 2026 Titofy — Santiago Colimba.',
                  style: TextStyle(fontSize: 12, color: c.textMuted, height: 1.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final Color accentColor;
  final Color bgColor;
  final IconData icon;
  final VoidCallback onTap;

  const _ThemeOptionCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.accentColor,
    required this.bgColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cardIsLight = bgColor.computeLuminance() > 0.5;
    final titleColor = isSelected
        ? accentColor
        : (cardIsLight ? const Color(0xFF131728) : const Color(0xFFF8FAFC));
    final subtitleColor = cardIsLight
        ? const Color(0xFF5A6680)
        : const Color(0xFF8E9BB5);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (cardIsLight ? const Color(0x33000000) : c.glassBorder),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: accentColor.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.18),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: accentColor, size: 20),
          ],
        ),
      ),
    );
  }
}

class _AccentColorCard extends StatelessWidget {
  final AccentPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _AccentColorCard({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected ? preset.primary.withOpacity(0.15) : c.backgroundAlt,
          border: Border.all(
            color: isSelected ? preset.primary : c.glassBorder,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: preset.primary.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [preset.light, preset.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: preset.primary.withOpacity(0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              preset.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (c.isDark ? Colors.white : preset.primary)
                    : c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisualizerThemeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _VisualizerThemeCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.backgroundAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? c.primary : c.glassBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: c.primary.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? c.primary : c.textPrimary,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: c.primary, size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: c.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: LinearGradient(colors: gradientColors),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOptionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeOptionChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? c.primary : c.backgroundAlt,
          border: Border.all(
            color: isSelected ? c.primary : c.glassBorder,
            width: 1.2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: c.primary.withOpacity(0.3),
                blurRadius: 10,
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : c.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _CardContainer({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.glassBorder),
        boxShadow: [
          if (!c.isDark)
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
            children: [
              Icon(icon, size: 16, color: c.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.primary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
