import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/services/library_service.dart';
import '../../core/services/player_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/lyrics_service.dart';
import '../../core/services/locale_service.dart';
import 'hybrid_lyrics_dialog.dart';
import 'add_to_playlist_dialog.dart';
import '../../shell/window_controls.dart';

/// Pantalla Principal / Explorador (Fiel al Diseño UI_titofy_3, adaptable a Tema Claro / Oscuro)
class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  List<List<Color>> _getCoverGradients(ThemeColors c) => [
    [c.primary, c.accentPreset.dark],
    [c.accentPreset.light, c.primary],
    [const Color(0xFF1B1A55), const Color(0xFF535C91)],
    [const Color(0xFF005B41), const Color(0xFF008170)],
    [const Color(0xFF4A148C), const Color(0xFF880E4F)],
    [const Color(0xFF222831), const Color(0xFF393E46)],
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final player = context.watch<PlayerService>();
    final api = context.watch<ApiService>();
    final loc = context.watch<LocaleService>();
    final c = context.colors;

    final displayTracks = library.tracks.where((t) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return t.title.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q) ||
          t.album.toLowerCase().contains(q);
    }).toList();

    // Agrupar pistas por Álbum
    final Map<String, List<Track>> albumGroups = {};
    for (final t in library.tracks) {
      final key = (t.album.isNotEmpty && t.album != 'Álbum local') ? t.album : t.artist;
      albumGroups.putIfAbsent(key, () => []).add(t);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // ── Barra Superior: Navegación, Buscador, Estado IA ──────────────
          _buildTopBar(context, library, api, loc, c),

          // ── Contenido con Scroll ─────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── SECCIÓN 1: Álbumes / Destacados ───────────────────────
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

                  if (library.tracks.isEmpty)
                    _buildEmptyLibraryPrompt(context, library, loc, c)
                  else
                    SizedBox(
                      height: 195,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: albumGroups.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 18),
                        itemBuilder: (context, index) {
                          final albumName = albumGroups.keys.elementAt(index);
                          final tracks = albumGroups[albumName]!;
                          final isFeatured = index == 0;
                          final albumGradients = _getCoverGradients(c);
                          return _buildRealAlbumCard(
                            albumName: albumName,
                            tracks: tracks,
                            isFeatured: isFeatured,
                            gradientIndex: index % albumGradients.length,
                            player: player,
                            c: c,
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 28),

                  // ── SECCIÓN 2: Split Columns (Top Charts & Colección) ─────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // COLUMNA IZQUIERDA: Pistas y Canciones
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  loc.t('topCharts'),
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: c.textPrimary,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (displayTracks.isNotEmpty)
                                      Text(
                                        '${displayTracks.length} canciones',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: c.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      tooltip: 'Recargar biblioteca',
                                      icon: library.isScanning
                                          ? SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                                            )
                                          : Icon(Icons.sync_rounded, size: 16, color: c.textMuted),
                                      splashRadius: 16,
                                      onPressed: library.isScanning || library.scannedFolder == null
                                          ? null
                                          : () => library.scanFolder(library.scannedFolder!),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (displayTracks.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: c.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: c.glassBorder),
                                  boxShadow: [
                                    if (!c.isDark)
                                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    library.tracks.isEmpty
                                        ? loc.t('noMusicFound')
                                        : 'No se encontraron resultados para "$_searchQuery"',
                                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: displayTracks.take(15).length,
                                itemBuilder: (context, index) {
                                  final track = displayTracks[index];
                                  final isSelected = player.currentTrack?.path == track.path;
                                  return _buildTrackItem(context, track, isSelected, player, library, c);
                                },
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 28),

                      // COLUMNA DERECHA: Resumen de Biblioteca y Modo Híbrido IA
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.t('playlists'),
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildInfoPanelCard(context, library, api, loc, c),
                            const SizedBox(height: 14),
                            _buildQuickFilterCards(library, player, c),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tarjeta de Estado Vacío de Biblioteca ─────────────────────────────────
  Widget _buildEmptyLibraryPrompt(BuildContext context, LibraryService library, LocaleService loc, ThemeColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.glassBorder),
        boxShadow: [
          if (!c.isDark)
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.primary.withOpacity(0.12),
            ),
            child: Icon(Icons.music_off_rounded, color: c.primary, size: 36),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.t('noMusicFound'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Elige la carpeta donde tienes tus archivos MP3, FLAC o WAV para comenzar a reproducir y sincronizar letras.',
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            onPressed: () => library.pickAndScan(),
          ),
        ],
      ),
    );
  }

  // ── Barra Superior (Limpia: sin icono duplicado de carpeta) ───────────────
  Widget _buildTopBar(BuildContext context, LibraryService library, ApiService api, LocaleService loc, ThemeColors c) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          // Flechas decorativas de navegación
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_rounded, size: 15, color: c.textSecondary),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
                splashRadius: 18,
                onPressed: () {},
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.arrow_forward_ios_rounded, size: 15, color: c.textMuted),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
                splashRadius: 18,
                onPressed: () {},
              ),
            ],
          ),

          const SizedBox(width: 24),

          // Buscador central redondeado
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.glassBorder),
                boxShadow: [
                  if (!c.isDark)
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 18, color: c.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
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
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 16, color: c.textMuted),
                      splashRadius: 14,
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 20),

          // Indicador interactivo de estado de API FastAPI
          InkWell(
            borderRadius: BorderRadius.circular(16),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (api.isOnline ? AppColors.success : AppColors.error).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (api.isOnline ? AppColors.success : AppColors.error).withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: api.isOnline ? AppColors.success : AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    api.isOnline ? loc.t('iaOnline') : loc.t('iaOffline'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: api.isOnline ? AppColors.success : AppColors.error,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Campana de notificaciones con punto
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_none_rounded, size: 20, color: c.textSecondary),
                splashRadius: 18,
                onPressed: () {},
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 14),

          // Botones de ventana nativa (Minimizar, Maximizar, Cerrar)
          WindowControls(isDark: c.isDark),
        ],
      ),
    );
  }

  // ── Tarjeta de Álbum Real ─────────────────────────────────────────────────
  Widget _buildRealAlbumCard({
    required String albumName,
    required List<Track> tracks,
    required bool isFeatured,
    required int gradientIndex,
    required PlayerService player,
    required ThemeColors c,
  }) {
    final firstTrack = tracks.first;
    final colors = _getCoverGradients(c)[gradientIndex];

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => player.playTrack(firstTrack, playlist: tracks),
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: isFeatured ? c.primary : Colors.transparent,
                  width: isFeatured ? 2.5 : 0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.first.withOpacity(isFeatured ? 0.45 : 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  if (firstTrack.artwork != null)
                    Image.memory(firstTrack.artwork!, width: 130, height: 130, fit: BoxFit.cover)
                  else
                    Center(
                      child: Icon(
                        Icons.album_rounded,
                        size: 44,
                        color: Colors.white.withOpacity(0.65),
                      ),
                    ),
                  // Botón central de Play
                  Center(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.92),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: c.primary,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              albumName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isFeatured ? c.primary : c.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              '${tracks.first.artist} · ${tracks.length} tracks',
              style: TextStyle(fontSize: 10, color: c.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Elemento de Pista en Top Charts con Botón Híbrido IA ───────────────────
  Widget _buildTrackItem(BuildContext context, Track track, bool isSelected, PlayerService player, LibraryService library, ThemeColors c) {
    return GestureDetector(
      onTap: () => player.playTrack(track, playlist: library.tracks),
      onSecondaryTapDown: (details) {
        showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            details.globalPosition.dx + 1,
            details.globalPosition.dy + 1,
          ),
          color: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          items: [
            PopupMenuItem(
              onTap: () => Future.microtask(() => AddToPlaylistDialog.show(context, track)),
              child: Row(
                children: [
                  Icon(Icons.playlist_add_rounded, size: 20, color: c.primary),
                  const SizedBox(width: 10),
                  Text('Añadir a lista de reproducción', style: TextStyle(color: c.textPrimary, fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              onTap: () => Future.microtask(() => HybridLyricsDialog.show(context, track)),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 18, color: c.primary),
                  const SizedBox(width: 10),
                  Text('Sincronizar Letras (IA)', style: TextStyle(color: c.textPrimary, fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              onTap: () => library.toggleFavorite(track),
              child: Row(
                children: [
                  Icon(
                    track.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 18,
                    color: c.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    track.isFavorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
                    style: TextStyle(color: c.textPrimary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isSelected ? c.primaryGradient : null,
          color: isSelected ? null : Colors.transparent,
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: c.primary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isSelected ? Colors.white.withOpacity(0.2) : c.surface,
                border: Border.all(color: isSelected ? Colors.transparent : c.glassBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: track.artwork != null
                  ? Image.memory(track.artwork!, fit: BoxFit.cover)
                  : Center(
                      child: Icon(
                        Icons.music_note_rounded,
                        size: 18,
                        color: isSelected ? Colors.white : c.textSecondary,
                      ),
                    ),
            ),
            const SizedBox(width: 14),

            // Título y Artista
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : c.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artist,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white.withOpacity(0.85) : c.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Duración
            Text(
              track.durationFormatted,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white.withOpacity(0.9) : c.textMuted,
              ),
            ),

            const SizedBox(width: 8),

            // Botón Letras / Modo Híbrido
            IconButton(
              tooltip: LyricsService.hasExistingLyrics(track.path, artist: track.artist, title: track.title)
                  ? 'Letra sincronizada disponible (.lrc)'
                  : 'Sincronizar Letras con IA (Modo Híbrido)',
              icon: Icon(
                LyricsService.hasExistingLyrics(track.path, artist: track.artist, title: track.title)
                    ? Icons.lyrics_rounded
                    : Icons.auto_awesome_rounded,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : (LyricsService.hasExistingLyrics(track.path, artist: track.artist, title: track.title)
                        ? const Color(0xFF39FF14)
                        : c.primary),
              ),
              splashRadius: 16,
              onPressed: () => HybridLyricsDialog.show(context, track),
            ),

            // Corazón (Favorito)
            IconButton(
              icon: Icon(
                track.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : (track.isFavorite ? c.primary : c.textMuted),
              ),
              splashRadius: 16,
              onPressed: () => library.toggleFavorite(track),
            ),

            // Añadir a Playlist
            IconButton(
              icon: Icon(
                Icons.playlist_add_rounded,
                size: 20,
                color: isSelected ? Colors.white : c.textSecondary,
              ),
              tooltip: 'Añadir a lista de reproducción',
              splashRadius: 18,
              onPressed: () => AddToPlaylistDialog.show(context, track),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tarjeta Informativa de Colección ──────────────────────────────────────
  Widget _buildInfoPanelCard(BuildContext context, LibraryService library, ApiService api, LocaleService loc, ThemeColors c) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.glassBorder),
        boxShadow: [
          if (!c.isDark)
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on_rounded, color: c.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                loc.t('syncLyricsHybrid').toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: c.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'El Modo Híbrido consulta fuentes online para letras oficiales y ejecuta Forced Alignment local con Whisper para alineación milimétrica con el audio local.',
            style: TextStyle(fontSize: 11, color: c.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatusPill(
                label: '${library.realTracks.length} canciones',
                icon: Icons.audio_file_rounded,
                c: c,
              ),
              const SizedBox(width: 8),
              _StatusPill(
                label: api.isOnline ? 'FastAPI 8642' : 'IA Offline',
                icon: Icons.memory_rounded,
                c: c,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Playlists / Filtros Rápidos en Grid ───────────────────────────────────
  Widget _buildQuickFilterCards(LibraryService library, PlayerService player, ThemeColors c) {
    final filters = [
      {
        'title': 'Favoritos',
        'count': '${library.favoriteTracks.length} canciones',
        'gradient': [c.primary, c.accentPreset.dark],
        'icon': Icons.favorite_rounded,
        'action': () {
          if (library.favoriteTracks.isNotEmpty) {
            player.playTrack(library.favoriteTracks.first, playlist: library.favoriteTracks);
          }
        },
      },
      {
        'title': 'Toda la Biblioteca',
        'count': '${library.realTracks.length} canciones',
        'gradient': [c.accentPreset.dark, c.backgroundAlt],
        'icon': Icons.queue_music_rounded,
        'action': () {
          if (library.realTracks.isNotEmpty) {
            player.playTrack(library.realTracks.first, playlist: library.realTracks);
          }
        },
      },
    ];

    return Row(
      children: filters.map((f) {
        final colors = f['gradient'] as List<Color>;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: f['action'] as VoidCallback,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(f['icon'] as IconData, color: Colors.white, size: 22),
                    const SizedBox(height: 10),
                    Text(
                      f['title'] as String,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      f['count'] as String,
                      style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final ThemeColors c;
  const _StatusPill({required this.label, required this.icon, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.backgroundAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c.primaryLight),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
