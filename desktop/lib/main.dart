// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar media_kit y metadata_god con protección de fallback
  MediaKit.ensureInitialized();
  try {
    await MetadataGod.initialize();
  } catch (e) {
    debugPrint('[Titofy] MetadataGod no disponible, usando analizador de nombres: $e');
  }

  // Configurar ventana nativa
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(900, 600),
    center: true,
    title: 'Titofy',
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Color(0x000A0A0F),
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const TitofyApp());
}
