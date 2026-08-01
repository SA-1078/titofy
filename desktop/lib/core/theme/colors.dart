import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Fondos Base ───────────────────────────────────────────────────────────
  static const Color background      = Color(0xFF040406);  // Negro puro OLED para contraste
  static const Color surface         = Color(0xFF0A0A0F);  // Negro morado oscuro
  static const Color surfaceHover    = Color(0xFF161622);  // Hover en paneles
  
  // ── Glassmorphism ─────────────────────────────────────────────────────────
  static const Color glassBg         = Color(0x12FFFFFF);  // Blended glass background (white 7%)
  static const Color glassBorder     = Color(0x1CFFFFFF);  // Fine border (white 11%)
  static const Color glassSelected   = Color(0x28FFFFFF);  // Selected glass state (white 16%)
  static const Color glassHover      = Color(0x1FFFFFFF);  // Hover glass state

  // ── Acentos Premium ───────────────────────────────────────────────────────
  static const Color primary         = Color(0xFF8B5CF6);  // Violeta eléctrico vibrante
  static const Color primaryLight    = Color(0xFFA78BFA);  // Violeta suave para glows
  static const Color primaryGlow     = Color(0x3D8B5CF6);  // Glow primario (24% opacity)
  
  static const Color secondary       = Color(0xFF06B6D4);  // Cyan neón vibrante
  static const Color secondaryLight  = Color(0xFF22D3EE);  // Cyan neón claro
  static const Color secondaryGlow   = Color(0x3D06B6D4);  // Glow secundario

  static const Color accent          = Color(0xFFEC4899);  // Rosa magenta neón
  static const Color accentGlow      = Color(0x3DEC4899);

  // ── Texto ─────────────────────────────────────────────────────────────────
  static const Color textPrimary     = Color(0xFFF8FAFC);  // Blanco limpio (slate 50)
  static const Color textSecondary   = Color(0xFF94A3B8);  // Gris suave elegante (slate 400)
  static const Color textMuted       = Color(0xFF475569);  // Gris oscuro/apagado (slate 600)
  static const Color textDisabled    = Color(0xFF334155);

  // ── Estados Semánticos ────────────────────────────────────────────────────
  static const Color success         = Color(0xFF10B981);  // Esmeralda
  static const Color warning         = Color(0xFFF59E0B);  // Ámbar
  static const Color error           = Color(0xFFEF4444);  // Rojo

  // ── Gradientes ────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF6366F1)], // De violeta a índigo
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [primary, secondary], // De violeta a cyan
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pinkGradient = LinearGradient(
    colors: [accent, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x1AFFFFFF), Color(0x05FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
