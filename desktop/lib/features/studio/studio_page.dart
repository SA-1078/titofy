import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/player_service.dart';
import '../../core/services/lyrics_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/library_service.dart';
import 'widgets/studio_header.dart';
import 'widgets/studio_audio_card.dart';
import 'widgets/studio_strategy_card.dart';
import 'widgets/studio_control_card.dart';
import 'widgets/studio_results_card.dart';

/// Estudio de Inteligencia Artificial para Transcripción y Alineación
class StudioPage extends StatefulWidget {
  const StudioPage({super.key});

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  String? _selectedFilePath;
  String _selectedModel = 'small';
  String _selectedLanguage = 'auto';
  String _selectedMode = 'hybrid'; // 'hybrid', 'ai_only', 'online_only', 'align'

  bool _isProcessing = false;
  double _progressValue = 0.0;
  String _currentStatusText = 'Listo para procesar';
  List<dynamic> _resultLines = [];
  String? _resultSource;

  final TextEditingController _customLyricsCtrl = TextEditingController();
  final TextEditingController _artistCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();

  Map<String, Map<String, dynamic>> _modelsInfo = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadModelsInfo());
  }

  @override
  void dispose() {
    _customLyricsCtrl.dispose();
    _artistCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadModelsInfo() async {
    try {
      final api = context.read<ApiService>();
      final list = await api.getModels();
      if (mounted && list.isNotEmpty) {
        final map = <String, Map<String, dynamic>>{};
        for (final m in list) {
          map[m['id']?.toString() ?? ''] = m;
        }
        setState(() => _modelsInfo = map);
      }
    } catch (_) {}
  }

  Future<void> _pickAudioFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg', 'opus', 'wma', 'mp4', 'mkv', 'webm', 'mov', 'avi'
      ],
      dialogTitle: 'Selecciona una pista para IA Studio',
    );
    if (res != null && res.files.single.path != null) {
      final path = res.files.single.path!;
      final player = context.read<PlayerService>();
      setState(() {
        _selectedFilePath = path;
        _currentStatusText = 'Archivo seleccionado: ${res.files.single.name}';
        if (player.currentTrack != null && player.currentTrack!.path == path) {
          _artistCtrl.text = player.currentTrack!.artist;
          _titleCtrl.text = player.currentTrack!.title;
        } else {
          final name = res.files.single.name;
          final clean = name
              .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
              .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
              .trim();
          if (clean.contains(' - ')) {
            final parts = clean.split(' - ');
            _artistCtrl.text = parts[0].trim();
            _titleCtrl.text = parts.sublist(1).join(' - ').trim();
          } else {
            _titleCtrl.text = clean;
          }
        }
      });
    }
  }

  void _useCurrentTrack() {
    final player = context.read<PlayerService>();
    if (player.currentTrack != null) {
      setState(() {
        _selectedFilePath = player.currentTrack!.path;
        _artistCtrl.text = player.currentTrack!.artist;
        _titleCtrl.text = player.currentTrack!.title;
        _currentStatusText =
            'Pista cargada: ${player.currentTrack!.artist} - ${player.currentTrack!.title}';
      });
    }
  }

  Future<void> _processAudio(ApiService api) async {
    if (_selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona un archivo de audio primero'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Si la pista proviene de YouTube, descargar automáticamente antes de procesar con Whisper
    if (_selectedFilePath!.startsWith('youtube:')) {
      setState(() {
        _isProcessing = true;
        _progressValue = 0.10;
        _currentStatusText = 'Descargando audio de YouTube a tu biblioteca...';
        _resultLines = [];
      });

      final lib = context.read<LibraryService>();
      final targetFolder = lib.scannedFolder ?? '/home/santiago007/Música';
      try {
        final dlRes = await api.downloadYouTubeTrack(
          videoId: _selectedFilePath!,
          title: _titleCtrl.text.isNotEmpty ? _titleCtrl.text : null,
          artist: _artistCtrl.text.isNotEmpty ? _artistCtrl.text : null,
          targetFolder: targetFolder,
        );
        if (dlRes != null && dlRes['file_path'] != null) {
          final localPath = dlRes['file_path'] as String;
          _selectedFilePath = localPath;
          lib.scanFolder(targetFolder);
          try {
            context.read<NotificationService>().add(
              title: 'Descarga de YouTube completada',
              message: '${dlRes['title'] ?? 'Pista'} guardada en $targetFolder',
              type: NotificationType.download,
              filePath: localPath,
            );
          } catch (_) {}
        }
      } catch (e) {
        if (_selectedMode != 'online_only') {
          setState(() {
            _isProcessing = false;
            _currentStatusText = 'Error descargando pista de YouTube: $e';
          });
          return;
        }
      }
    }

    setState(() {
      _isProcessing = true;
      _progressValue = 0.20;
      _currentStatusText = 'Conectando con motor de IA local...';
      _resultLines = [];
    });

    try {
      if (_selectedMode == 'align') {
        if (_customLyricsCtrl.text.trim().isEmpty) {
          throw Exception(
              'Por favor pega o escribe la letra de la canción antes de iniciar Forced Alignment.');
        }
        setState(() {
          _progressValue = 0.35;
          _currentStatusText = 'Enviando audio y texto para Forced Alignment...';
        });

        final taskId = await api.align(
          audioPath: _selectedFilePath!,
          lyricsText: _customLyricsCtrl.text.trim(),
          model: _selectedModel,
          language: _selectedLanguage == 'auto' ? 'es' : _selectedLanguage,
        );

        if (taskId != null) {
          await _pollTask(api, taskId);
        } else {
          throw Exception('No se pudo iniciar la tarea de alineación en el backend');
        }
      } else {
        String initialStatus;
        if (_selectedMode == 'ai_only') {
          initialStatus = 'Transcribiendo con Whisper IA Local...';
        } else if (_selectedMode == 'online_only') {
          initialStatus = 'Consultando Fuente 1...';
        } else {
          initialStatus = 'Buscando letra y calibrando con audio...';
        }

        setState(() {
          _progressValue = 0.25;
          _currentStatusText = initialStatus;
        });

        Map<String, dynamic>? res;
        if (_selectedMode == 'ai_only') {
          final taskId = await api.transcribe(
            audioPath: _selectedFilePath!,
            model: _selectedModel,
            language: _selectedLanguage == 'auto' ? 'es' : _selectedLanguage,
          );
          if (taskId != null) {
            await _pollTask(api, taskId);
            return;
          } else {
            throw Exception('No se pudo iniciar la transcripción con Whisper');
          }
        } else {
          final songTitle = _titleCtrl.text.trim();
          final artistName = _artistCtrl.text.trim();

          res = await api.resolveLyrics(
            audioPath: _selectedFilePath!,
            title: songTitle.isNotEmpty ? songTitle : null,
            artist: artistName.isNotEmpty ? artistName : null,
            mode: _selectedMode,
            model: _selectedModel,
            language: _selectedLanguage == 'auto' ? 'es' : _selectedLanguage,
          );
        }

        if (res != null) {
          final displaySource = _resolveDisplaySource(res);
          setState(() {
            _progressValue = 1.0;
            _resultLines = res?['lines'] as List? ?? [];
            _resultSource = displaySource;
            _currentStatusText = '¡Proceso completado! (${_resultLines.length} líneas generadas)';
          });

          final trackName = (_titleCtrl.text.isNotEmpty && _artistCtrl.text.isNotEmpty)
              ? '${_artistCtrl.text} - ${_titleCtrl.text}'
              : (_titleCtrl.text.isNotEmpty ? _titleCtrl.text : (_selectedFilePath?.split('/').last ?? 'Canción'));

          try {
            context.read<NotificationService>().add(
              title: 'Sincronización IA completada',
              message: '$trackName (${_resultLines.length} líneas generadas con $displaySource)',
              type: NotificationType.lyrics,
              filePath: _selectedFilePath,
            );
          } catch (_) {}

          if (!mounted) return;
          try {
            final player = context.read<PlayerService>();
            if (player.currentTrack != null && player.currentTrack!.path == _selectedFilePath) {
              context.read<LyricsService>().applyResolvedResponse(res);
            }
          } catch (_) {}
        } else {
          throw Exception('No se obtuvieron resultados para los parámetros seleccionados');
        }
      }
    } catch (e) {
      final cleanMsg = _humanizeErrorMessage(e);
      try {
        context.read<NotificationService>().add(
          title: 'Error en proceso de IA',
          message: cleanMsg,
          type: NotificationType.error,
          filePath: _selectedFilePath,
        );
      } catch (_) {}
      if (mounted) {
        setState(() {
          _currentStatusText = 'Error: $cleanMsg';
          _progressValue = 0.0;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _resolveDisplaySource(Map<String, dynamic> res) {
    final p = res['provider']?.toString() ?? '';
    final s = res['source']?.toString() ?? '';
    if (s == 'online_aligned' || p.contains('Alineada') || p.contains('calibrado')) {
      return p.isNotEmpty ? p : 'Fuente 1 · Alineada con Audio';
    } else if (s == 'ai_generated' || p.toLowerCase().contains('whisper')) {
      return 'Whisper IA (Transcripción)';
    } else if (p.contains('Fuente 1') || p.toLowerCase().contains('lrclib')) {
      return 'Fuente 1';
    } else if (p.contains('Fuente 2') || p.toLowerCase().contains('netease')) {
      return 'Fuente 2';
    } else if (p.contains('Fuente 3') || p.toLowerCase().contains('genius') || p.toLowerCase().contains('lyrist')) {
      return 'Fuente 3';
    }
    return p.isNotEmpty ? p : s;
  }

  String _humanizeErrorMessage(dynamic error) {
    final str = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    final lower = str.toLowerCase();
    if (lower.contains('socketexception') || lower.contains('refused') || lower.contains('8642')) {
      return 'No se pudo conectar con el motor local de IA (puerto 8642).';
    }
    if (lower.contains('timeout')) {
      return 'La operación tardó demasiado tiempo en responder. Prueba con un modelo más rápido (ej. "base").';
    }
    if (lower.contains('out of memory')) {
      return 'Memoria VRAM insuficiente. Selecciona un modelo más ligero o cambia a CPU.';
    }
    if (lower.contains('no se encontraron letras') || lower.contains('404')) {
      return 'No se encontraron letras en línea. Prueba con el modo IA Local.';
    }
    return str;
  }

  Future<void> _pollTask(ApiService api, String taskId) async {
    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      final statusData = await api.status(taskId);
      if (statusData != null) {
        final st = statusData['status'];
        final prog = (statusData['progress'] as num?)?.toDouble() ?? 50.0;

        if (mounted) {
          setState(() {
            _progressValue = (prog / 100).clamp(0.1, 0.95);
            _currentStatusText = 'Procesando en segundo plano ($st: ${prog.toInt()}%)...';
          });
        }

        if (st == 'done') {
          final trackName = (_titleCtrl.text.isNotEmpty && _artistCtrl.text.isNotEmpty)
              ? '${_artistCtrl.text} - ${_titleCtrl.text}'
              : (_titleCtrl.text.isNotEmpty ? _titleCtrl.text : (_selectedFilePath?.split('/').last ?? 'Canción'));

          try {
            context.read<NotificationService>().add(
              title: 'Alineación IA completada',
              message: '$trackName: letras y audio sincronizados con éxito',
              type: NotificationType.lyrics,
              filePath: _selectedFilePath,
            );
          } catch (_) {}

          if (mounted) {
            setState(() {
              _progressValue = 1.0;
              _currentStatusText = '¡Alineación completada exitosamente!';
            });
          }
          break;
        } else if (st == 'error') {
          throw Exception(statusData['error'] ?? 'Fallo desconocido en la tarea');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final api = context.watch<ApiService>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StudioHeader(api: api),

            const SizedBox(height: 22),

            // ── Zona 01: Archivo de Audio (Ancho Completo Superior) ──────────
            StudioAudioCard(
              selectedFilePath: _selectedFilePath,
              artistCtrl: _artistCtrl,
              titleCtrl: _titleCtrl,
              onPickFile: _pickAudioFile,
              onUseCurrentTrack: _useCurrentTrack,
            ),

            const SizedBox(height: 18),

            // ── Zona 02 y Zona 03: Configuración (60%) y Procesamiento (40%) ──
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 780;

                final strategyWidget = StudioStrategyCard(
                  selectedMode: _selectedMode,
                  selectedModel: _selectedModel,
                  selectedLanguage: _selectedLanguage,
                  customLyricsCtrl: _customLyricsCtrl,
                  modelsInfo: _modelsInfo,
                  onModeChanged: (mode) => setState(() => _selectedMode = mode),
                  onModelChanged: (model) => setState(() => _selectedModel = model),
                  onLanguageChanged: (lang) => setState(() => _selectedLanguage = lang),
                  onRefreshModels: _loadModelsInfo,
                );

                final controlWidget = StudioControlCard(
                  isProcessing: _isProcessing,
                  progressValue: _progressValue,
                  currentStatusText: _currentStatusText,
                  selectedMode: _selectedMode,
                  selectedModel: _selectedModel,
                  selectedLanguage: _selectedLanguage,
                  api: api,
                  onStartProcessing: () => _processAudio(api),
                  onCancelProcessing: () {
                    setState(() {
                      _isProcessing = false;
                      _progressValue = 0.0;
                      _currentStatusText = 'Cancelado por el usuario';
                    });
                  },
                );

                if (!isWide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      strategyWidget,
                      const SizedBox(height: 18),
                      controlWidget,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna Izquierda: Configuración (aprox 60%)
                    Expanded(
                      flex: 6,
                      child: strategyWidget,
                    ),
                    const SizedBox(width: 18),
                    // Columna Derecha: Procesamiento (aprox 40%)
                    Expanded(
                      flex: 4,
                      child: controlWidget,
                    ),
                  ],
                );
              },
            ),

            // ── Resultados de Letras Sincronizadas ──────────────────────────
            if (_resultLines.isNotEmpty) ...[
              const SizedBox(height: 20),
              StudioResultsCard(
                resultLines: _resultLines,
                resultSource: _resultSource,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
