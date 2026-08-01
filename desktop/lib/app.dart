import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/services/player_service.dart';
import 'core/services/api_service.dart';
import 'core/services/library_service.dart';
import 'shell/app_shell.dart';

class TitofyApp extends StatelessWidget {
  const TitofyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerService()),
        ChangeNotifierProvider(create: (_) => LibraryService()),
        Provider(create: (_) => ApiService()),
      ],
      child: MaterialApp(
        title: 'Titofy',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const AppShell(),
      ),
    );
  }
}
