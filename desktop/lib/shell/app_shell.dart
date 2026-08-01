import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../core/theme/colors.dart';
import '../core/services/player_service.dart';
import '../features/music/music_page.dart';
import '../features/video/video_page.dart';
import '../features/studio/studio_page.dart';
import '../features/settings/settings_page.dart';
import '../shared/widgets/ambient_background.dart';
import 'nav_rail.dart';
import 'mini_player.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    MusicPage(),
    VideoPage(),
    StudioPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Deja ver el AmbientBackground
      body: AmbientBackground(
        child: Column(
          children: [
            // ── TitleBar Minimalista ────────────────────────────────────────
            _TitleBar(),

            // ── Contenido de la Aplicación ──────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Menú lateral de cristal flotante
                    TitofyNavRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (i) =>
                          setState(() => _selectedIndex = i),
                    ),

                    const SizedBox(width: 16),

                    // Área de contenido de cristal flotante
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.glassBg.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.glassBorder.withOpacity(0.4),
                            width: 1.0,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeInOut,
                          switchOutCurve: Curves.easeInOut,
                          child: KeyedSubtree(
                            key: ValueKey(_selectedIndex),
                            child: _pages[_selectedIndex],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Mini Player: solo visible cuando hay reproducción ─────────
            Consumer<PlayerService>(
              builder: (context, player, _) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: player.currentMedia != null
                      ? Padding(
                          key: const ValueKey('player'),
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                          child: const MiniPlayer(),
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) async {
        await windowManager.startDragging();
      },
      child: Container(
        height: 44,
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            // Botones estilo macOS / Neón
            _MacDot(color: const Color(0xFFEF4444), onTap: () async => await windowManager.close()),
            const SizedBox(width: 8),
            _MacDot(
              color: const Color(0xFFF59E0B),
              onTap: () async => await windowManager.minimize(),
            ),
            const SizedBox(width: 8),
            _MacDot(
              color: const Color(0xFF10B981),
              onTap: () async {
                final isMax = await windowManager.isMaximized();
                if (isMax) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            const SizedBox(width: 20),
            Text(
              'Titofy Studio & Player',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    fontSize: 10,
                  ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _MacDot extends StatefulWidget {
  final Color color;
  final VoidCallback onTap;

  const _MacDot({required this.color, required this.onTap});

  @override
  State<_MacDot> createState() => _MacDotState();
}

class _MacDotState extends State<_MacDot> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(_hovered ? 1.0 : 0.6),
            boxShadow: [
              if (_hovered)
                BoxShadow(
                  color: widget.color.withOpacity(0.6),
                  blurRadius: 8,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
