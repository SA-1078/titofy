import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/colors.dart';
import '../core/services/notification_service.dart';
import '../core/services/library_service.dart';
import '../core/services/player_service.dart';

/// Modal interactivo del Centro de Notificaciones y Actividad de Titofy
class ActivityNotificationsModal {
  static void show(BuildContext context) {
    final notifService = context.read<NotificationService>();
    notifService.markAllAsRead();

    final c = context.colors;

    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Consumer2<NotificationService, LibraryService>(
        builder: (context, notifs, library, _) {
          final items = notifs.notifications;
          final musicFolder = library.scannedFolder ?? '/home/santiago007/Música';

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header con Título y Botón Limpiar ──────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: c.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.notifications_active_rounded, color: c.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Actividad & Notificaciones',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                            ),
                          ),
                          Text(
                            'Descargas, sincronizaciones y estado de tu biblioteca',
                            style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (items.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.clear_all_rounded, size: 16),
                        label: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: c.textMuted),
                        onPressed: () => notifs.clearAll(),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: c.textMuted,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Tarjeta de Estado: Carpeta activa de música ───────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.glassBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.folder_special_rounded, color: c.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CARPETA ACTIVA DE MÚSICA',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: c.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              musicFolder,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${library.realTracks.length} archivos de audio reconocidos',
                              style: TextStyle(fontSize: 11, color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        icon: library.isScanning
                            ? SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary))
                            : const Icon(Icons.sync_rounded, size: 15),
                        label: Text(library.isScanning ? 'Escaneando...' : 'Escanear', style: const TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(foregroundColor: c.primary),
                        onPressed: library.isScanning ? null : () => library.scanFolder(musicFolder),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Lista de Notificaciones Recientes ──────────────────────
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.notifications_none_rounded, size: 48, color: c.textMuted.withOpacity(0.4)),
                              const SizedBox(height: 12),
                              Text(
                                'Sin notificaciones pendientes',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Las descargas de YouTube y sincronizaciones de IA aparecerán aquí.',
                                style: TextStyle(fontSize: 12, color: c.textMuted),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _NotificationCard(notification: item, c: c);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final ThemeColors c;

  const _NotificationCard({required this.notification, required this.c});

  IconData _getIcon() {
    switch (notification.type) {
      case NotificationType.download:
        return Icons.download_done_rounded;
      case NotificationType.lyrics:
        return Icons.auto_awesome_rounded;
      case NotificationType.scan:
        return Icons.folder_open_rounded;
      case NotificationType.system:
        return Icons.info_outline_rounded;
      case NotificationType.error:
        return Icons.error_outline_rounded;
    }
  }

  Color _getColor() {
    switch (notification.type) {
      case NotificationType.download:
        return const Color(0xFF00E676);
      case NotificationType.lyrics:
        return const Color(0xFFD580FF);
      case NotificationType.scan:
        return const Color(0xFF00E5FF);
      case NotificationType.system:
        return c.primary;
      case NotificationType.error:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final timeStr = '${notification.timestamp.hour.toString().padLeft(2, '0')}:${notification.timestamp.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceLight.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.glassBorder.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(_getIcon(), color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: c.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(timeStr, style: TextStyle(fontSize: 10, color: c.textMuted)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  notification.message,
                  style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                ),
                if (notification.filePath != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.insert_drive_file_rounded, size: 12, color: c.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          notification.filePath!,
                          style: TextStyle(fontSize: 10, color: c.textMuted, fontFamily: 'monospace'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (File(notification.filePath!).existsSync())
                        InkWell(
                          onTap: () {
                            final player = context.read<PlayerService>();
                            final lib = context.read<LibraryService>();
                            final match = lib.tracks.where((t) => t.path == notification.filePath).firstOrNull;
                            if (match != null) {
                              player.playTrack(match, playlist: lib.tracks);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Text('Reproducir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.primary)),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
