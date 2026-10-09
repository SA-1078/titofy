import 'package:flutter/material.dart';

/// Preset de color de acento personalizable para la aplicación
class AccentPreset {
  final String id;
  final String name;
  final Color primary;
  final Color light;
  final Color dark;
  final Color glow;
  final Color glowSubtle;

  const AccentPreset({
    required this.id,
    required this.name,
    required this.primary,
    required this.light,
    required this.dark,
    required this.glow,
    required this.glowSubtle,
  });
}

/// Colección de presets de acento curados para Titofy
class AccentPresets {
  AccentPresets._();

  static const AccentPreset coral = AccentPreset(
    id: 'coral',
    name: 'Neón Coral',
    primary: Color(0xFFFF4B72),
    light: Color(0xFFFF5D82),
    dark: Color(0xFFE0385E),
    glow: Color(0x66FF4B72),
    glowSubtle: Color(0x26FF4B72),
  );

  static const AccentPreset purple = AccentPreset(
    id: 'purple',
    name: 'Púrpura Eléctrico',
    primary: Color(0xFF8B5CF6),
    light: Color(0xFFA78BFA),
    dark: Color(0xFF7C3AED),
    glow: Color(0x668B5CF6),
    glowSubtle: Color(0x268B5CF6),
  );

  static const AccentPreset cyan = AccentPreset(
    id: 'cyan',
    name: 'Cyan Cyber',
    primary: Color(0xFF06B6D4),
    light: Color(0xFF22D3EE),
    dark: Color(0xFF0891B2),
    glow: Color(0x6606B6D4),
    glowSubtle: Color(0x2606B6D4),
  );

  static const AccentPreset emerald = AccentPreset(
    id: 'emerald',
    name: 'Verde Esmeralda',
    primary: Color(0xFF10B981),
    light: Color(0xFF34D399),
    dark: Color(0xFF059669),
    glow: Color(0x6610B981),
    glowSubtle: Color(0x2610B981),
  );

  static const AccentPreset blue = AccentPreset(
    id: 'blue',
    name: 'Azul Zafiro',
    primary: Color(0xFF3B82F6),
    light: Color(0xFF60A5FA),
    dark: Color(0xFF2563EB),
    glow: Color(0x663B82F6),
    glowSubtle: Color(0x263B82F6),
  );

  static const AccentPreset amber = AccentPreset(
    id: 'amber',
    name: 'Ámbar Sunset',
    primary: Color(0xFFFF7A00),
    light: Color(0xFFFFA24C),
    dark: Color(0xFFEA580C),
    glow: Color(0x66FF7A00),
    glowSubtle: Color(0x26FF7A00),
  );

  static const AccentPreset crimson = AccentPreset(
    id: 'crimson',
    name: 'Rojo Rubí',
    primary: Color(0xFFEF4444),
    light: Color(0xFFF87171),
    dark: Color(0xFFDC2626),
    glow: Color(0x66EF4444),
    glowSubtle: Color(0x26EF4444),
  );

  static const AccentPreset magenta = AccentPreset(
    id: 'magenta',
    name: 'Hyper Magenta',
    primary: Color(0xFFEC4899),
    light: Color(0xFFF472B6),
    dark: Color(0xFFDB2777),
    glow: Color(0x66EC4899),
    glowSubtle: Color(0x26EC4899),
  );

  static const List<AccentPreset> all = [
    coral,
    purple,
    cyan,
    emerald,
    blue,
    amber,
    crimson,
    magenta,
  ];

  static AccentPreset get defaultPreset => coral;

  static bool has(String id) => all.any((p) => p.id == id);

  static AccentPreset getPreset(String id) {
    return all.firstWhere((p) => p.id == id, orElse: () => defaultPreset);
  }

  static AccentPreset fromColor(Color color) {
    return all.firstWhere(
      (p) => p.primary.value == color.value,
      orElse: () => defaultPreset,
    );
  }
}

class AppColors {
  AppColors._();

  static AccentPreset _activePreset = AccentPresets.coral;
  static void applyAccent(AccentPreset preset) {
    _activePreset = preset;
  }
  static AccentPreset get currentAccent => _activePreset;

  // ── Fondos Base Oscuros (Estilo UI_titofy_3: Midnight Navy & Deep Charcoal) ──
  static const Color background      = Color(0xFF090C15);  // Midnight dark profundo
  static const Color backgroundAlt   = Color(0xFF0D101C);  // Variante oscura
  static const Color surface         = Color(0xFF121626);  // Contenedor principal de tarjetas
  static const Color surfaceLight    = Color(0xFF181D30);  // Tarjetas elevadas
  static const Color surfaceHover    = Color(0xFF20263E);  // Estado hover en ítems

  // ── Acento Dinámico Personalizable de la Aplicación ──────────────────────────
  static Color get coral           => _activePreset.primary;
  static Color get coralLight      => _activePreset.light;
  static Color get coralDark       => _activePreset.dark;
  static Color get coralGlow       => _activePreset.glow;
  static Color get coralGlowSubtle => _activePreset.glowSubtle;

  // ── Compatibilidad de sistema ─────────────────────────────────────────────
  static Color get primary         => _activePreset.primary;
  static Color get primaryLight    => _activePreset.light;
  static Color get primaryGlow     => _activePreset.glow;
  
  static const Color secondary       = Color(0xFF8B5CF6);  // Púrpura eléctrico
  static const Color secondaryLight  = Color(0xFFA78BFA);
  static const Color cyan            = Color(0xFF06B6D4);  // Cyan neón
  static Color get accent          => _activePreset.primary;

  // ── Glassmorphism & Bordes ────────────────────────────────────────────────
  static const Color glassBg         = Color(0x14FFFFFF);  // Vidrio 8%
  static const Color glassBorder     = Color(0x1AFFFFFF);  // Borde fino 10%
  static const Color glassHover      = Color(0x24FFFFFF);  // Hover 14%
  static const Color borderSubtle    = Color(0x1F2A4468);  // Borde sutil azulado

  // ── Textos ────────────────────────────────────────────────────────────────
  static const Color textPrimary     = Color(0xFFF8FAFC);  // Blanco limpio slate 50
  static const Color textSecondary   = Color(0xFF8E9BB5);  // Gris azulado suave
  static const Color textMuted       = Color(0xFF5A6680);  // Texto atenuado/secundario
  static const Color textDisabled    = Color(0xFF384256);  // Deshabilitado

  // ── Estados Semánticos ────────────────────────────────────────────────────
  static const Color success         = Color(0xFF10B981);  // Esmeralda
  static const Color warning         = Color(0xFFF59E0B);  // Ámbar
  static const Color error           = Color(0xFFEF4444);  // Rojo

  // ── Gradientes Dinámicos ──────────────────────────────────────────────────
  static LinearGradient get coralGradient => LinearGradient(
    colors: [_activePreset.light, _activePreset.dark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get playerGradient => LinearGradient(
    colors: [_activePreset.primary, _activePreset.light],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient cardOverlayGradient = LinearGradient(
    colors: [Colors.transparent, Color(0xCC090C15)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient purpleNeonGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFFF7A00), Color(0xFFFF0055)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Sistema de colores dinámico reactivo al tema activo (Dark Mode vs Light Mode)
class ThemeColors {
  final bool isDark;
  final AccentPreset accentPreset;
  const ThemeColors(this.isDark, [this.accentPreset = AccentPresets.coral]);

  Color get background => isDark ? const Color(0xFF090C15) : const Color(0xFFF4F5FB);
  Color get backgroundAlt => isDark ? const Color(0xFF0D101C) : const Color(0xFFEAEBF5);
  Color get surface => isDark ? const Color(0xFF121626) : const Color(0xFFFFFFFF);
  Color get surfaceLight => isDark ? const Color(0xFF181D30) : const Color(0xFFF8F9FE);
  Color get surfaceHover => isDark ? const Color(0xFF20263E) : const Color(0xFFE2E4F0);
  Color get textPrimary => isDark ? const Color(0xFFF8FAFC) : const Color(0xFF111425);
  Color get textSecondary => isDark ? const Color(0xFF8E9BB5) : const Color(0xFF5B667D);
  Color get textMuted => isDark ? const Color(0xFF5A6680) : const Color(0xFF8A94A6);
  Color get textDisabled => isDark ? const Color(0xFF384256) : const Color(0xFFB0B7C6);
  Color get glassBorder => isDark ? const Color(0x1AFFFFFF) : const Color(0x18000000);
  Color get glassBg => isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000);
  Color get borderSubtle => isDark ? const Color(0x1F2A4468) : const Color(0x1FE0E4F0);
  Color get coral => accentPreset.primary;
  Color get coralLight => accentPreset.light;
  Color get coralGlowSubtle => isDark ? accentPreset.glowSubtle : accentPreset.primary.withOpacity(0.12);
  Color get primary => accentPreset.primary;
  Color get primaryLight => accentPreset.light;
  Color get accent => accentPreset.primary;
  Color get error => AppColors.error;
  Color get success => AppColors.success;
  Color get warning => AppColors.warning;
  Color get textOnPrimary => Colors.white;

  LinearGradient get playerGradient => LinearGradient(
    colors: [accentPreset.primary, accentPreset.light],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  LinearGradient get primaryGradient => LinearGradient(
    colors: [accentPreset.light, accentPreset.dark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  LinearGradient get coralGradient => primaryGradient;

  LinearGradient get cardGradient => LinearGradient(
    colors: [accentPreset.primary, accentPreset.dark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  LinearGradient get cardGradientSecondary => LinearGradient(
    colors: [accentPreset.dark, isDark ? const Color(0xFF1B1A30) : const Color(0xFFD0D5E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

extension ThemeColorsExt on BuildContext {
  ThemeColors get colors {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    final primary = Theme.of(this).colorScheme.primary;
    return ThemeColors(isDark, AccentPresets.fromColor(primary));
  }
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
