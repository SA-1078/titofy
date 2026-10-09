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
import '../features/music/playlist_detail_page.dart';
import '../features/settings/settings_page.dart';
import 'nav_rail.dart';
import 'mini_player.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  int? _selectedPlaylistId;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // 1. Si hay un diálogo, modal o ventana abierta sobre la pantalla principal, NO interceptar
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return false;
    }

    // 2. Si el foco actual está en un campo de texto o editor, permitir escribir normalmente
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

    final player = context.read<PlayerService>();
    if (player.currentTrack == null) return false;

    if (event.logicalKey == LogicalKeyboardKey.space) {
      player.playPause();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      player.seekRelative(const Duration(seconds: -10));
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      player.seekRelative(const Duration(seconds: 10));
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      player.changeVolume(0.05);
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      player.changeVolume(-0.05);
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_selectedIndex == 2) {
        setState(() => _selectedIndex = 0);
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const MusicPage(),
      const StudioPage(),
      const ExpandedPlayerView(isEmbedded: true),
      const AlbumsPage(),
      const SettingsPage(),
      const FavoritesPage(),
      const HistoryPage(),
    ];

    final c = context.colors;

    Widget currentContent;
    if (_selectedPlaylistId != null) {
      currentContent = PlaylistDetailPage(
        key: ValueKey('playlist_$_selectedPlaylistId'),
        playlistId: _selectedPlaylistId!,
        onBack: () => setState(() {
          _selectedPlaylistId = null;
          _selectedIndex = 0;
        }),
      );
    } else {
      currentContent = KeyedSubtree(
        key: ValueKey(_selectedIndex),
        child: pages[_selectedIndex.clamp(0, pages.length - 1)],
      );
    }

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
                    Expanded(
                      child: Container(
                        color: c.background,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: currentContent,
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

