import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/services/api_service.dart';
import 'core/services/lyrics_service.dart';
import 'core/services/player_service.dart';
import 'core/services/database_service.dart';
import 'core/services/library_service.dart';
import 'core/services/theme_service.dart';
import 'core/services/locale_service.dart';
import 'shell/app_shell.dart';

class TitofyApp extends StatelessWidget {
  const TitofyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DatabaseService()),
        ChangeNotifierProxyProvider<DatabaseService, ThemeService>(
          create: (ctx) {
            final t = ThemeService();
            t.attachDatabaseService(ctx.read<DatabaseService>());
            return t;
          },
          update: (ctx, db, t) {
            t?.attachDatabaseService(db);
            return t!;
          },
        ),
        ChangeNotifierProxyProvider<DatabaseService, LocaleService>(
          create: (ctx) {
            final loc = LocaleService();
            loc.attachDatabaseService(ctx.read<DatabaseService>());
            return loc;
          },
          update: (ctx, db, loc) {
            loc?.attachDatabaseService(db);
            return loc!;
          },
        ),
        ChangeNotifierProvider(create: (_) => ApiService()),
        ChangeNotifierProxyProvider<ApiService, LyricsService>(
          create: (ctx) => LyricsService(ctx.read<ApiService>()),
          update: (ctx, api, prev) => prev ?? LyricsService(api),
        ),
        ChangeNotifierProxyProvider2<LyricsService, DatabaseService, PlayerService>(
          create: (ctx) {
            final p = PlayerService();
            p.attachLyricsService(ctx.read<LyricsService>());
            p.attachDatabaseService(ctx.read<DatabaseService>());
            return p;
          },
          update: (ctx, lyrics, db, p) {
            p?.attachLyricsService(lyrics);
            p?.attachDatabaseService(db);
            return p!;
          },
        ),
        ChangeNotifierProxyProvider<DatabaseService, LibraryService>(
          create: (ctx) {
            final lib = LibraryService();
            lib.attachDatabaseService(ctx.read<DatabaseService>());
            return lib;
          },
          update: (ctx, db, lib) {
            lib?.attachDatabaseService(db);
            return lib!;
          },
        ),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            title: 'Titofy Music & IA Lyrics',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(themeService.accentColor),
            darkTheme: AppTheme.darkTheme(themeService.accentColor),
            themeMode: themeService.themeMode,
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
