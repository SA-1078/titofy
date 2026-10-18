// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/library_service.dart';

/// Widget informativo de estado de la carpeta de música activa
class MusicFolderStatus extends StatelessWidget {
  final LibraryService library;

  const MusicFolderStatus({
    super.key,
    required this.library,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final folderPath = library.scannedFolder ?? '/home/santiago007/Música';
    final folderName = folderPath.split('/').where((s) => s.isNotEmpty).lastOrNull ?? folderPath;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.folder_special_rounded, color: c.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BIBLIOTECA ACTIVA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: c.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  folderName,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '${library.tracks.length} pistas',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
