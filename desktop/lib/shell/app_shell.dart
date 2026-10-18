import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../core/theme/colors.dart';
import '../core/services/player_service.dart';
import '../features/music/music_page.dart';
import '../features/studio/studio_page.dart';
import '../features/music/expanded_player_view.dart';
import '../features/music/albums_page.dart';
import '../features/music/favorites_page.dart';
import '../features/music/history_page.dart';
import '../features/music/all_tracks_page.dart';
import '../features/music/playlist_detail_page.dart';
import '../features/settings/settings_page.dart';
import 'nav_rail.dart';
import 'mini_player.dart';
import 'app_top_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  int? _selectedPlaylistId;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _pages = [
      MusicPage(
        onNavigate: (index) => setState(() {
          _selectedIndex = index;
          _selectedPlaylistId = null;
        }),
        onPlaylistSelected: (plId) => setState(() {
          _selectedPlaylistId = plId;
          _selectedIndex = -1;
        }),
      ),
      const StudioPage(),
      const ExpandedPlayerView(isEmbedded: true),
      const AlbumsPage(),
      const SettingsPage(),
      const FavoritesPage(),
      const HistoryPage(),
      const AllTracksPage(),
    ];
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final player = context.read<PlayerService>();

    // ── 1. TECLAS MULTIMEDIA DE HARDWARE (Siempre activas, incluso con modales o foco) ──
    if (event.logicalKey == LogicalKeyboardKey.mediaPlayPause ||
        event.logicalKey == LogicalKeyboardKey.mediaPlay ||
        event.logicalKey == LogicalKeyboardKey.mediaPause) {
      player.playPause();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.mediaTrackNext ||
        event.logicalKey == LogicalKeyboardKey.mediaFastForward) {
      player.next();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.mediaTrackPrevious ||
        event.logicalKey == LogicalKeyboardKey.mediaRewind) {
      player.previous();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
      player.changeVolume(0.05);
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
      player.changeVolume(-0.05);
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.audioVolumeMute) {
      player.setVolume(player.volume > 0.0 ? 0.0 : 0.8);
      return true;
    }

    // ── 2. PROTECCIÓN DE EDICIÓN DE TEXTO ──
    // Si el usuario escribe en un campo de texto (buscador, crear playlist, etc.), no interceptar teclas normales
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null) {
      final debugLabel = primaryFocus.debugLabel?.toLowerCase() ?? '';
      if (debugLabel.contains('editable') || debugLabel.contains('textfield')) {
        return false;
      }
      final ctx = primaryFocus.context;
      if (ctx != null) {
        if (ctx.widget is EditableText || ctx.findAncestorWidgetOfExactType<EditableText>() != null) {
          return false;
        }
      }
    }

    // ── 3. TECLA ESCAPE (Cierra modales o regresa a la pantalla principal) ──
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        return true;
      } else if (_selectedIndex != 0) {
        setState(() => _selectedIndex = 0);
        return true;
      }
      return false;
    }

    if (player.currentTrack == null) return false;

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    // ── 4. ATAJOS DE TECLADO GENERALES ──
    if (event.logicalKey == LogicalKeyboardKey.space) {
      player.playPause();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      player.changeVolume(0.05);
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      player.changeVolume(-0.05);
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (isCtrl || isShift) {
        player.previous();
      } else {
        player.seekRelative(const Duration(seconds: -10));
      }
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (isCtrl || isShift) {
        player.next();
      } else {
        player.seekRelative(const Duration(seconds: 10));
      }
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.keyN) {
      player.next();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.keyP) {
      player.previous();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
      player.setVolume(player.volume > 0.0 ? 0.0 : 0.8);
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      body: GestureDetector(
        onPanStart: (e) {
          // Si hace clic en la parte superior, permitir arrastrar ventana nativa
          if (e.localPosition.dy < 40) {
            windowManager.startDragging();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.glassBorder.withOpacity(0.4), width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra Lateral Estilo UI_titofy_3
              TitofyNavRail(
                selectedIndex: _selectedIndex,
                selectedPlaylistId: _selectedPlaylistId,
                onDestinationSelected: (i) {
                  setState(() {
                    _selectedIndex = i;
                    _selectedPlaylistId = null;
                  });
                },
                onPlaylistSelected: (plId) {
                  setState(() {
                    _selectedPlaylistId = plId;
                    _selectedIndex = -1;
                  });
                },
              ),

              // Área Central de Visualización y Reproductor Inferior
              Expanded(
                child: Column(
                  children: [
                    // ── Barra Superior Persistente en TODAS las pantallas ───
                    AppTopBar(
                      selectedIndex: _selectedIndex,
                      selectedPlaylistId: _selectedPlaylistId,
                      onBack: () {
                        setState(() {
                          _selectedPlaylistId = null;
                          _selectedIndex = 0;
                        });
                      },
                    ),

                    Expanded(
                      child: Container(
                        color: c.background,
                        child: Stack(
                          children: [
                            IndexedStack(
                              index: _selectedIndex.clamp(0, _pages.length - 1),
                              children: [
                                for (var i = 0; i < _pages.length; i++)
                                  // IndexedStack conserva sus hijos montados.
                                  // Silenciar el ticker del reproductor cuando
                                  // esa página no está visible evita trabajo
                                  // continuo en segundo plano.
                                  i == 2
                                      ? TickerMode(
                                          enabled: _selectedIndex == 2,
                                          child: _pages[i],
                                        )
                                      : _pages[i],
                              ],
                            ),
                            if (_selectedPlaylistId != null)
                              Positioned.fill(
                                child: Container(
                                  color: c.background,
                                  child: PlaylistDetailPage(
                                    key: ValueKey('playlist_$_selectedPlaylistId'),
                                    playlistId: _selectedPlaylistId!,
                                    onBack: () => setState(() {
                                      _selectedPlaylistId = null;
                                      _selectedIndex = 0;
                                    }),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // ── Reproductor Inferior Flotante (Waveform Neón Coral) ───
                    const Padding(
                      padding: EdgeInsets.fromLTRB(18, 0, 18, 14),
                      child: MiniPlayer(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

