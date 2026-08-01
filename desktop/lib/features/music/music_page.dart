import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/services/library_service.dart';
import '../../core/services/player_service.dart';

class MusicPage extends StatelessWidget {
  const MusicPage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: library.tracks.isEmpty
          ? _EmptyState(isScanning: library.isScanning)
          : _LibraryView(tracks: library.tracks, isScanning: library.isScanning),
    );
  }
}

// ── ESTADO VACÍO ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isScanning;
  const _EmptyState({required this.isScanning});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isScanning) ...[
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Escaneando biblioteca...',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Leyendo metadatos de tus archivos de audio',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ] else ...[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary.withOpacity(0.2), AppColors.secondary.withOpacity(0.2)],
                ),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                color: AppColors.primaryLight,
                size: 32,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sin música en tu biblioteca',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Escanea una carpeta para empezar a reproducir',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 28),
            _ScanButton(),
          ],
        ],
      ),
    );
  }
}

// ── VISTA DE BIBLIOTECA CON TRACKS ───────────────────────────────────────────

class _LibraryView extends StatefulWidget {
  final List<Track> tracks;
  final bool isScanning;

  const _LibraryView({required this.tracks, required this.isScanning});

  @override
  State<_LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<_LibraryView> {
  String _query = '';

  List<Track> get _filtered {
    if (_query.isEmpty) return widget.tracks;
    final q = _query.toLowerCase();
    return widget.tracks.where((t) =>
        t.title.toLowerCase().contains(q) ||
        t.artist.toLowerCase().contains(q) ||
        t.album.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Cabecera ─────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mi Música',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.tracks.length} canciones',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(),
                if (widget.isScanning)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                _ScanButton(),
              ],
            ),
          ),
        ),

        // ── Buscador ──────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.glassBg.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder.withOpacity(0.5)),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: '¿Qué quieres escuchar?',
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            ),
          ),
        ),

        // ── Cabecera de tabla ─────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                const SizedBox(width: 32),
                Expanded(
                  flex: 4,
                  child: Text(
                    'TÍTULO',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                          letterSpacing: 1.5,
                        ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'ÁLBUM',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                          letterSpacing: 1.5,
                        ),
                  ),
                ),
                Text(
                  'DURACIÓN',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                        letterSpacing: 1.5,
                      ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
        ),

        // ── Lista de tracks ────────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final track = filtered[index];
                return _TrackRow(track: track, index: index + 1);
              },
              childCount: filtered.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ── BOTÓN ESCANEAR ─────────────────────────────────────────────────────────────

class _ScanButton extends StatefulWidget {
  @override
  State<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<_ScanButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryService>();

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(_hover ? 0.4 : 0.2),
              blurRadius: _hover ? 12 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: library.pickAndScan,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          icon: const Icon(Icons.sync_rounded, size: 15),
          label: const Text(
            'Escanear carpeta',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// ── FILA DE TRACK ─────────────────────────────────────────────────────────────

class _TrackRow extends StatefulWidget {
  final Track track;
  final int index;

  const _TrackRow({required this.track, required this.index});

  @override
  State<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<_TrackRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerService>();
    final current = context.watch<PlayerService>().currentMedia;
    final isPlaying = current?.uri == Uri.file(widget.track.path).toString();

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => player.open(
          widget.track.path,
          title: widget.track.title,
          artist: widget.track.artist,
          artwork: widget.track.artwork,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: isPlaying
                ? AppColors.primary.withOpacity(0.12)
                : _hover
                    ? AppColors.glassHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isPlaying
                  ? AppColors.primary.withOpacity(0.3)
                  : _hover
                      ? AppColors.glassBorder
                      : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Artwork / índice / reproduciendo
              SizedBox(
                width: 36,
                height: 36,
                child: _TrackArtwork(
                  artwork: widget.track.artwork,
                  isPlaying: isPlaying,
                  isHovered: _hover,
                  index: widget.index,
                ),
              ),
              const SizedBox(width: 12),

              // Título + Artista
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isPlaying ? AppColors.primaryLight : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.track.artist,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Álbum
              Expanded(
                flex: 3,
                child: Text(
                  widget.track.album,
                  style: TextStyle(
                    fontSize: 12,
                    color: _hover ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Duración
              Text(
                LibraryService.formatDuration(widget.track.duration),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),

              // Botón rápido de IA
              _AIButton(track: widget.track),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackArtwork extends StatelessWidget {
  final Uint8List? artwork;
  final bool isPlaying;
  final bool isHovered;
  final int index;

  const _TrackArtwork({
    required this.artwork,
    required this.isPlaying,
    required this.isHovered,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    if (isPlaying) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: AppColors.primary.withOpacity(0.2),
        ),
        child: const Icon(Icons.equalizer_rounded, color: AppColors.primaryLight, size: 18),
      );
    }
    if (isHovered) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: AppColors.glassHover,
        ),
        child: const Icon(Icons.play_arrow_rounded, color: AppColors.secondary, size: 20),
      );
    }
    if (artwork != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(artwork!, fit: BoxFit.cover),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: AppColors.surfaceHover,
      ),
      child: Center(
        child: Text(
          index.toString().padLeft(2, '0'),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AIButton extends StatefulWidget {
  final Track track;
  const _AIButton({required this.track});

  @override
  State<_AIButton> createState() => _AIButtonState();
}

class _AIButtonState extends State<_AIButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tooltip(
        message: 'Transcribir con IA',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _hover ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 14,
            color: _hover ? AppColors.primaryLight : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
