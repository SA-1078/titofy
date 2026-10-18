import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/library_service.dart';
import '../hybrid_lyrics_dialog.dart';

/// Elemento de lista para cada pista dentro de la vista de playlist
class PlaylistTrackTile extends StatelessWidget {
  final Track track;
  final int index;
  final bool isCurrent;
  final bool isPlaying;
  final bool isResolving;
  final bool isDownloading;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDownload;
  final VoidCallback onRemove;

  const PlaylistTrackTile({
    super.key,
    required this.track,
    required this.index,
    required this.isCurrent,
    required this.isPlaying,
    required this.isResolving,
    required this.isDownloading,
    required this.onTap,
    required this.onLongPress,
    required this.onDownload,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final library = context.watch<LibraryService>();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isCurrent ? c.primary.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent ? c.primary.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: SizedBox(
            width: 36,
            child: Center(
              child: isResolving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.primary,
                      ),
                    )
                  : isPlaying
                      ? Icon(Icons.volume_up_rounded, color: c.primary, size: 18)
                      : (track.isRemote
                          ? const Icon(Icons.smart_display_outlined, color: Colors.redAccent, size: 18)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isCurrent ? c.primary : c.textMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            )),
            ),
          ),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCurrent ? c.primary : c.textPrimary,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
          subtitle: Row(
            children: [
              if (track.isRemote) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'YouTube',
                    style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              Expanded(
                child: Text(
                  '${track.artist}  •  ${track.album}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (track.isRemote) ...[
                if (isDownloading) ...[
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                      ),
                    ),
                  ),
                ] else ...[
                  IconButton(
                    icon: Icon(Icons.download_rounded, size: 18, color: c.primary),
                    tooltip: 'Descargar audio en tu equipo',
                    splashRadius: 18,
                    onPressed: onDownload,
                  ),
                ],
              ] else ...[
                Tooltip(
                  message: 'Audio descargado en tu equipo',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.greenAccent.shade400.withOpacity(0.8)),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Text(
                track.durationFormatted,
                style: TextStyle(color: c.textMuted, fontSize: 12),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.lyrics_outlined, size: 18, color: c.textMuted),
                tooltip: 'Ver letras',
                splashRadius: 18,
                onPressed: () => HybridLyricsDialog.show(context, track),
              ),
              IconButton(
                icon: Icon(
                  library.isFavorite(track) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 18,
                  color: library.isFavorite(track) ? c.primary : c.textMuted,
                ),
                splashRadius: 18,
                onPressed: () => library.toggleFavorite(track),
              ),
              IconButton(
                icon: Icon(Icons.remove_circle_outline_rounded, size: 18, color: c.textMuted),
                tooltip: 'Quitar de la lista',
                splashRadius: 18,
                onPressed: onRemove,
              ),
            ],
          ),
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
    );
  }
}
