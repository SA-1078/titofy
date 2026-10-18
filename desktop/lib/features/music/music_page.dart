// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/colors.dart';
import '../../core/services/library_service.dart';
import '../../core/services/player_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/locale_service.dart';

import 'components/music_album_carousel.dart';
import 'components/music_mood_pills.dart';
import 'components/music_playlists_grid.dart';
import 'components/music_top_charts_section.dart';
import 'components/music_folder_status.dart';
import 'components/music_floating_track_button.dart';

export 'components/music_top_bar.dart';
export 'components/music_album_carousel.dart';
export 'components/music_track_item.dart';
export 'components/music_mood_pills.dart';
export 'components/music_playlists_grid.dart';
export 'components/music_quick_access_panel.dart';
export 'components/music_top_charts_section.dart';
export 'components/music_folder_status.dart';
export 'components/music_floating_track_button.dart';

/// Pantalla Principal / Explorador (Fiel al Diseño UI_titofy_3, adaptable a Tema Claro / Oscuro)
class MusicPage extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  final ValueChanged<int>? onPlaylistSelected;

  const MusicPage({
    super.key,
    this.onNavigate,
    this.onPlaylistSelected,
  });

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _playingTrackKey = GlobalKey();
  String _selectedMood = 'all';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentTrack(List<Track> tracks, PlayerService player, LibraryService library) {
    if (player.currentTrack == null) return;

    if (!tracks.any((t) => t.path == player.currentTrack!.path)) {
      if (_selectedMood != 'all' || library.searchQuery.isNotEmpty) {
        setState(() => _selectedMood = 'all');
        library.setSearchQuery('');
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyContext = _playingTrackKey.currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
          alignment: 0.35,
        );
        return;
      }

      final idx = library.tracks.indexWhere((t) => t.path == player.currentTrack!.path);
      if (idx != -1 && _scrollController.hasClients) {
        final targetOffset = 320.0 + (idx * 60.0);
        _scrollController.animateTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final player = context.watch<PlayerService>();
    final db = context.watch<DatabaseService>();
    final loc = context.watch<LocaleService>();
    final c = context.colors;

    final effectiveQuery = library.searchQuery.trim().toLowerCase();
    final mood = _selectedMood;

    final filtered = library.tracks.where((t) {
      if (effectiveQuery.isNotEmpty) {
        final matches = t.title.toLowerCase().contains(effectiveQuery) ||
            t.artist.toLowerCase().contains(effectiveQuery) ||
            t.album.toLowerCase().contains(effectiveQuery);
        if (!matches) return false;
      }
      if (mood == 'all') return true;
      final fullText = '${t.title} ${t.artist} ${t.album}'.toLowerCase();
      if (mood == 'chill') return fullText.contains('chill') || fullText.contains('slow') || fullText.contains('sunset') || fullText.contains('relax');
      if (mood == 'urbana') return fullText.contains('trap') || fullText.contains('reggaeton') || fullText.contains('urban') || fullText.contains('jam') || fullText.contains('bad');
      if (mood == 'lofi') return fullText.contains('lofi') || fullText.contains('lo-fi') || fullText.contains('beat') || fullText.contains('study');
      if (mood == 'rock') return fullText.contains('rock') || fullText.contains('indie') || fullText.contains('guitar');
      if (mood == 'synthwave') return fullText.contains('synth') || fullText.contains('wave') || fullText.contains('80') || fullText.contains('neon');
      if (mood == 'pop') return fullText.contains('pop') || fullText.contains('hits') || fullText.contains('dance');
      if (mood == 'party') return fullText.contains('party') || fullText.contains('mix') || fullText.contains('remix') || fullText.contains('electro');
      return true;
    }).toList();

    final displayTracks = (filtered.isEmpty && mood != 'all' && effectiveQuery.isEmpty)
        ? library.tracks
        : filtered;

    // Respetar estrictamente el orden natural de la biblioteca sin mover la pista activa
    final List<Track> topChartTracks = displayTracks;
    final isPlayingInLibrary = player.currentTrack != null &&
        library.tracks.any((t) => t.path == player.currentTrack!.path);

    final Map<String, List<Track>> albumGroups = {};
    for (final t in library.tracks) {
      final key = (t.album.isNotEmpty && t.album != 'Álbum local') ? t.album : t.artist;
      albumGroups.putIfAbsent(key, () => []).add(t);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isPlayingInLibrary
          ? MusicFloatingTrackButton(
              player: player,
              onTap: () => _scrollToCurrentTrack(topChartTracks, player, library),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.only(left: 28, right: 28, top: 14, bottom: 84),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── SECCIÓN 1: Álbumes / Destacados Estilo UI_titofy_3 ───────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loc.t('newAlbums'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                if (library.tracks.isNotEmpty)
                  Text(
                    '${albumGroups.length} ${loc.t('albums').toLowerCase()}',
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            MusicAlbumCarousel(
              library: library,
              player: player,
              loc: loc,
              albumGroups: albumGroups,
            ),

            const SizedBox(height: 22),

            // ── SECCIÓN 2: Filtros Rápidos de Estado de Ánimo (Mood Pills) ───
            MusicMoodPills(
              selectedMood: _selectedMood,
              onMoodSelected: (m) => setState(() => _selectedMood = m),
            ),

            const SizedBox(height: 24),

            // ── SECCIÓN 3: Split Columns (Top Charts & Playlists Grid) ────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // COLUMNA IZQUIERDA: Top Charts con orden natural y botón de localización
                Expanded(
                  flex: 6,
                  child: MusicTopChartsSection(
                    topChartTracks: topChartTracks,
                    player: player,
                    library: library,
                    loc: loc,
                    playingTrackKey: _playingTrackKey,
                    isPlayingInLibrary: isPlayingInLibrary,
                    onLocatePlayingTrack: () => _scrollToCurrentTrack(topChartTracks, player, library),
                  ),
                ),

                const SizedBox(width: 28),

                // COLUMNA DERECHA: Grid 2x3 de Playlists y Estado de Colección
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MusicPlaylistsGrid(
                        db: db,
                        player: player,
                        library: library,
                        onPlaylistSelected: widget.onPlaylistSelected,
                      ),
                      const SizedBox(height: 18),
                      MusicFolderStatus(library: library),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
