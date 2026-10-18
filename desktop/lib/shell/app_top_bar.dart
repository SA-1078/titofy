import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../core/theme/colors.dart';
import '../core/services/api_service.dart';
import '../core/services/database_service.dart';
import '../core/services/library_service.dart';
import '../core/services/locale_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/theme_service.dart';
import 'window_controls.dart';
import 'activity_notifications_modal.dart';

/// Barra Superior Persistente de la Aplicación para todas las pantallas
class AppTopBar extends StatelessWidget {
  final int selectedIndex;
  final int? selectedPlaylistId;
  final VoidCallback onBack;
  final VoidCallback? onForward;

  const AppTopBar({
    super.key,
    required this.selectedIndex,
    this.selectedPlaylistId,
    required this.onBack,
    this.onForward,
  });

  String _getPageTitle(LocaleService loc) {
    if (selectedPlaylistId != null) return 'Lista de reproducción';
    switch (selectedIndex) {
      case 0:
        return loc.t('music');
      case 1:
        return 'Estudio IA & Sincronización';
      case 2:
        return 'Visualizador de Espectro';
      case 3:
        return loc.t('albums');
      case 4:
        return loc.t('settings');
      case 5:
        return loc.t('favorites');
      case 6:
        return 'Historial de Reproducción';
      case 7:
        return 'Toda la biblioteca';
      default:
        return 'Titofy';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final api = context.watch<ApiService>();
    final loc = context.watch<LocaleService>();
    final notifs = context.watch<NotificationService>();
    final library = context.watch<LibraryService>();

    final isSearchingScreen = (selectedPlaylistId == null && (selectedIndex == 0 || selectedIndex == 7));

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: c.background,
          border: Border(bottom: BorderSide(color: c.glassBorder.withOpacity(0.3))),
        ),
        child: Row(
          children: [
            // ── Flechas de Navegación ──────────────────────────────────────
            Row(
              children: [
                IconButton(
                  tooltip: 'Atrás',
                  icon: Icon(
                    Icons.arrow_back_ios_rounded,
                    size: 15,
                    color: (selectedPlaylistId != null || selectedIndex != 0) ? c.textPrimary : c.textMuted.withOpacity(0.5),
                  ),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                  splashRadius: 18,
                  onPressed: (selectedPlaylistId != null || selectedIndex != 0) ? onBack : null,
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Adelante',
                  icon: Icon(Icons.arrow_forward_ios_rounded, size: 15, color: c.textMuted.withOpacity(0.5)),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                  splashRadius: 18,
                  onPressed: onForward,
                ),
              ],
            ),

            const SizedBox(width: 18),

            // ── Título o Buscador según la Pantalla Activa ────────────────
            if (isSearchingScreen)
              Expanded(
                child: Container(
                  height: 38,
                  constraints: const BoxConstraints(maxWidth: 480),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: c.glassBorder),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 18, color: c.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: library.searchController,
                          onChanged: (v) => library.setSearchQuery(v),
                          style: TextStyle(fontSize: 13, color: c.textPrimary),
                          decoration: InputDecoration(
                            hintText: loc.t('searchHint'),
                            hintStyle: TextStyle(fontSize: 12, color: c.textMuted),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (library.searchQuery.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 16, color: c.textMuted),
                          splashRadius: 14,
                          onPressed: () => library.setSearchQuery(''),
                        ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Text(
                  _getPageTitle(loc),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),

            const SizedBox(width: 16),

            // ── Indicador de Microservicio IA FastAPI ─────────────────────
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                if (!api.isOnline) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Iniciando microservicio de IA local (FastAPI en 127.0.0.1:8642)...'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  await api.ensureServerRunning();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (api.isOnline ? AppColors.success : AppColors.error).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (api.isOnline ? AppColors.success : AppColors.error).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6.5,
                      height: 6.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: api.isOnline ? AppColors.success : AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      api.isOnline ? loc.t('iaOnline') : loc.t('iaOffline'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: api.isOnline ? AppColors.success : AppColors.error,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),

            // ── Campana Interactiva de Notificaciones & Actividad ────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'Actividad & Notificaciones',
                  icon: Icon(Icons.notifications_none_rounded, size: 20, color: c.textSecondary),
                  splashRadius: 18,
                  onPressed: () => ActivityNotificationsModal.show(context),
                ),
                if (notifs.hasUnread)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00E5FF),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withOpacity(0.6),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 8),

            // ── Perfil de Usuario y Acceso Rápido a Tema (Estilo UI_titofy_3) ───
            _buildProfilePill(context, c),

            const SizedBox(width: 14),

            // ── Controles de Ventana Nativa (Minimizar, Maximizar, Cerrar) ──
            WindowControls(isDark: c.isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePill(BuildContext context, ThemeColors c) {
    final db = context.watch<DatabaseService>();
    final storedName = db.getSetting('user_display_name', '')?.trim() ?? '';
    final envUser = Platform.environment['USER'] ?? Platform.environment['USERNAME'] ?? 'Usuario';
    final displayName = storedName.isNotEmpty ? storedName : envUser;
    final initialLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return PopupMenuButton<String>(
      tooltip: 'Perfil & Apariencia',
      offset: const Offset(0, 36),
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.glassBorder),
      ),
      onSelected: (val) {
        if (val == 'edit_profile') {
          _showEditProfileDialog(context, db, displayName);
        } else if (val == 'theme') {
          context.read<ThemeService>().toggleTheme();
        } else if (val.startsWith('accent_')) {
          final id = val.replaceFirst('accent_', '');
          context.read<ThemeService>().setAccentColor(id);
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'edit_profile',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 18, color: c.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Editar Nombre', style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                    Text(displayName, style: TextStyle(color: c.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'theme',
          child: Row(
            children: [
              Icon(c.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 18, color: c.primary),
              const SizedBox(width: 10),
              Text(c.isDark ? 'Modo Claro' : 'Modo Oscuro (Obsidian)', style: TextStyle(color: c.textPrimary, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: false,
          child: Text('COLOR DE ACENTO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c.textMuted)),
        ),
        ...AccentPresets.all.map((preset) => PopupMenuItem(
          value: 'accent_${preset.id}',
          child: Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: preset.primary)),
              const SizedBox(width: 10),
              Text(preset.name, style: TextStyle(color: c.textPrimary, fontSize: 12.5)),
            ],
          ),
        )),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: c.primaryGradient,
              ),
              child: Center(
                child: Text(
                  initialLetter,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: c.textMuted),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, DatabaseService db, String currentName) {
    final c = context.colors;
    final controller = TextEditingController(text: currentName == 'Usuario' ? '' : currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.glassBorder),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: c.primaryGradient,
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Nombre de Perfil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Este nombre se mostrará en la aplicación:',
              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: c.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Escribe tu nombre...',
                hintStyle: TextStyle(color: c.textMuted),
                filled: true,
                fillColor: c.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.glassBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.primary, width: 1.5),
                ),
              ),
              onSubmitted: (val) {
                final trimmed = val.trim();
                if (trimmed.isNotEmpty) {
                  db.setSetting('user_display_name', trimmed);
                }
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                db.setSetting('user_display_name', trimmed);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
