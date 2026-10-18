// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/services/database_service.dart';
import '../../core/services/library_service.dart';
import '../../core/services/player_service.dart';
import '../../core/services/locale_service.dart';
import 'select_tracks_dialog.dart';
import 'playlist/playlist_header.dart';
import 'playlist/playlist_track_tile.dart';
import 'playlist/remote_track_modal.dart';
import 'playlist/playlist_dialogs.dart';
import 'playlist/playlist_downloader.dart';

export 'playlist/playlist_header.dart';
export 'playlist/playlist_track_tile.dart';
export 'playlist/remote_track_modal.dart';
export 'playlist/playlist_dialogs.dart';
export 'playlist/playlist_downloader.dart';

/// Vista principal de Detalle de una Lista de Reproducción
class PlaylistDetailPage extends StatefulWidget {
  final int playlistId;
  final VoidCallback onBack;

  const PlaylistDetailPage({
    super.key,
    required this.playlistId,
    required this.onBack,
  });

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  final Set<String> _downloadingTrackIds = {};
  bool _isDownloadingAll = false;
  int _downloadedCount = 0;
  int _totalToDownload = 0;

  void _downloadSingleTrack(Track track) {
    PlaylistDownloader.downloadSingleTrack(
      context,
      track,
      onStart: (id) => setState(() => _downloadingTrackIds.add(id)),
      onFinish: (id) {
        if (mounted) setState(() => _downloadingTrackIds.remove(id));
      },
    );
  }

  void _downloadAllPendingTracks(List<Track> remoteTracks) {
    if (_isDownloadingAll || remoteTracks.isEmpty) return;
    PlaylistDownloader.downloadAllPendingTracks(
      context,
      remoteTracks,
      onStart: (total) {
        setState(() {
          _isDownloadingAll = true;
          _totalToDownload = total;
          _downloadedCount = 0;
        });
      },
      onTrackComplete: (id, count) {
        if (mounted) {
          setState(() {
            _downloadingTrackIds.remove(id);
            _downloadedCount = count;
          });
        }
      },
      onFinish: () {
        if (mounted) {
          setState(() {
            _isDownloadingAll = false;
            _totalToDownload = 0;
            _downloadedCount = 0;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final loc = context.watch<LocaleService>();
    final db = context.watch<DatabaseService>();
    final library = context.watch<LibraryService>();
    final player = context.watch<PlayerService>();

    final playlists = db.playlists;
    final plIndex = playlists.indexWhere((p) => p.id == widget.playlistId);

    if (plIndex == -1) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.playlist_remove_rounded, size: 48, color: c.textMuted),
            const SizedBox(height: 12),
            Text('Lista de reproducción no encontrada', style: TextStyle(color: c.textPrimary, fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Volver'),
              style: ElevatedButton.styleFrom(backgroundColor: c.primary),
            ),
          ],
        ),
      );
    }

    final pl = playlists[plIndex];
    final tracks = library.getTracksForPlaylist(pl.id);
    final remoteTracks = tracks.where((t) => t.isRemote).toList();

    // Calcular duración total
    final totalDuration = tracks.fold<Duration>(
      Duration.zero,
      (prev, t) => prev + t.duration,
    );
    final totalHours = totalDuration.inHours;
    final totalMinutes = totalDuration.inMinutes.remainder(60);
    final durationStr = totalHours > 0
        ? '$totalHours h $totalMinutes min'
        : '$totalMinutes min';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          PlaylistHeader(
            playlist: pl,
            tracks: tracks,
            durationStr: durationStr,
            onBack: widget.onBack,
            onPlayAll: () => player.playTrack(tracks.first, queue: tracks),
            onAddTracks: () => SelectTracksDialog.show(context, pl),
            onRename: () => PlaylistDialogs.showRenameDialog(context, pl),
            onDelete: () => PlaylistDialogs.showDeleteDialog(context, pl, widget.onBack),
            onDownloadAll: () => _downloadAllPendingTracks(remoteTracks),
            isDownloadingAll: _isDownloadingAll,
            downloadedCount: _downloadedCount,
            totalToDownload: _totalToDownload,
          ),
          Expanded(
            child: tracks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.queue_music_rounded, size: 48, color: c.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          loc.t('emptyPlaylist'),
                          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Explora tu música o añade canciones directamente a esta lista',
                          style: TextStyle(color: c.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: () => SelectTracksDialog.show(context, pl),
                          icon: const Icon(Icons.playlist_add_rounded, size: 20),
                          label: const Text('Añadir canciones a esta lista'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.primary,
                            foregroundColor: c.textOnPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    physics: const BouncingScrollPhysics(),
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final isCurrent = player.currentTrack?.path == track.path;
                      final isPlaying = isCurrent && player.isPlaying;
                      final isResolving = isCurrent && player.isResolvingStream;
                      final isDownloading = _downloadingTrackIds.contains(track.remoteId);

                      return PlaylistTrackTile(
                        track: track,
                        index: index,
                        isCurrent: isCurrent,
                        isPlaying: isPlaying,
                        isResolving: isResolving,
                        isDownloading: isDownloading,
                        onTap: () => player.playTrack(track, queue: tracks),
                        onLongPress: () {
                          if (track.isRemote) {
                            RemoteTrackModal.show(
                              context,
                              track: track,
                              playlist: tracks,
                              isDownloading: isDownloading,
                              onDownload: () => _downloadSingleTrack(track),
                            );
                          }
                        },
                        onDownload: () => _downloadSingleTrack(track),
                        onRemove: () => db.removeTrackFromPlaylist(pl.id, track.path),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
