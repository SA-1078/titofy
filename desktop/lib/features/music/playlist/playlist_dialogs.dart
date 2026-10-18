// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/services/database_service.dart';

/// Diálogos de gestión para listas de reproducción (Renombrar y Eliminar)
class PlaylistDialogs {
  /// Muestra el diálogo para renombrar y cambiar la descripción de la playlist
  static void showRenameDialog(BuildContext context, PlaylistModel pl) {
    final c = context.colors;
    final ctrl = TextEditingController(text: pl.name);
    final descCtrl = TextEditingController(text: pl.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Renombrar lista', style: TextStyle(color: c.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: c.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nombre',
                labelStyle: TextStyle(color: c.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              style: TextStyle(color: c.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Descripción',
                labelStyle: TextStyle(color: c.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<DatabaseService>().renamePlaylist(
                      pl.id,
                      ctrl.text.trim(),
                      descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    );
                Navigator.of(ctx).pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: c.primary),
            child: Text('Guardar', style: TextStyle(color: c.textOnPrimary)),
          ),
        ],
      ),
    );
  }

  /// Muestra el diálogo de confirmación para eliminar la playlist
  static void showDeleteDialog(BuildContext context, PlaylistModel pl, VoidCallback onDeleted) {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: c.error, size: 22),
            const SizedBox(width: 8),
            Text('Eliminar lista', style: TextStyle(color: c.textPrimary, fontSize: 16)),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar la lista "${pl.name}"? Tus archivos de música no se borrarán.',
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<DatabaseService>().deletePlaylist(pl.id);
              Navigator.of(ctx).pop();
              onDeleted();
            },
            style: ElevatedButton.styleFrom(backgroundColor: c.error),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
