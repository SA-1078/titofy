import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/player_service.dart';
import '../../core/services/lyrics_service.dart';
import '../../shell/window_controls.dart';
import 'widgets/studio_audio_card.dart';
import 'widgets/studio_strategy_card.dart';
import 'widgets/studio_control_card.dart';
import 'widgets/studio_results_card.dart';
import 'widgets/model_install_dialog.dart';

/// Estudio de Inteligencia Artificial para Transcripción y Alineación
class StudioPage extends StatefulWidget {
  const StudioPage({super.key});

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  String? _selectedFilePath;
  String _selectedModel = 'small';
  String _selectedLanguage = 'auto';
  String _selectedMode = 'auto'; // 'auto', 'ai_only', 'online_only', 'align'

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

    setState(() {
      _isProcessing = true;
      _progressValue = 0.15;
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
          final rawProv = res['provider']?.toString() ?? '';
          final rawSrc = res['source']?.toString() ?? '';
          String displaySource = 'Fuente 1';
          if (rawSrc == 'online_aligned' ||
              rawProv.contains('Alineada') ||
              rawProv.contains('calibrado')) {
            displaySource = rawProv.isNotEmpty ? rawProv : 'Fuente 1 · Alineada con Audio';
          } else if (rawSrc == 'ai_generated' || rawProv.toLowerCase().contains('whisper')) {
            displaySource = 'Whisper IA (Transcripción)';
          } else if (rawProv.contains('Fuente 1') || rawProv.toLowerCase().contains('lrclib')) {
            displaySource = 'Fuente 1';
          } else if (rawProv.contains('Fuente 2') || rawProv.toLowerCase().contains('netease')) {
            displaySource = 'Fuente 2';
          } else if (rawProv.contains('Fuente 3') ||
              rawProv.toLowerCase().contains('genius') ||
              rawProv.toLowerCase().contains('lyrist')) {
            displaySource = 'Fuente 3';
          } else {
            displaySource = rawProv.isNotEmpty ? rawProv : rawSrc;
          }

          setState(() {
            _progressValue = 1.0;
            _resultLines = res?['lines'] as List? ?? [];
            _resultSource = displaySource;
            _currentStatusText =
                '¡Proceso completado! (${_resultLines.length} líneas generadas)';
          });

          try {
            final player = context.read<PlayerService>();
            if (player.currentTrack != null &&
                player.currentTrack!.path == _selectedFilePath) {
              await context.read<LyricsService>().loadForAudio(
                    player.currentTrack!.path,
                    title: player.currentTrack!.title,
                    artist: player.currentTrack!.artist,
                  );
            }
          } catch (_) {}
        } else {
          throw Exception('No se obtuvieron resultados para los parámetros seleccionados');
        }
      }
    } catch (e) {
      if (mounted) {
        final cleanMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
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
    final api = context.watch<ApiService>();
    final c = context.colors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera Principal ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: c.primary.withOpacity(0.35),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Titofy IA Studio',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      api.isOnline
                          ? 'Motor FastAPI conectado (localhost:8642) · Whisper con aceleración local'
                          : 'Aviso: Servidor local no detectado en el puerto 8642',
                      style: TextStyle(
                        fontSize: 12,
                        color: api.isOnline ? AppColors.success : AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                WindowControls(isDark: c.isDark),
              ],
            ),

            const SizedBox(height: 22),

            // ── Disposición Modular de Dos Columnas ─────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Columna Izquierda: Audio y Parámetros (flex: 7) ───────────
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StudioAudioCard(
                        selectedFilePath: _selectedFilePath,
                        artistCtrl: _artistCtrl,
                        titleCtrl: _titleCtrl,
                        onPickFile: _pickAudioFile,
                        onUseCurrentTrack: _useCurrentTrack,
                      ),
                      const SizedBox(height: 16),
                      StudioStrategyCard(
                        selectedMode: _selectedMode,
                        selectedModel: _selectedModel,
                        selectedLanguage: _selectedLanguage,
                        customLyricsCtrl: _customLyricsCtrl,
                        modelsInfo: _modelsInfo,
                        onModeChanged: (mode) => setState(() => _selectedMode = mode),
                        onModelChanged: (model) => setState(() => _selectedModel = model),
                        onLanguageChanged: (lang) => setState(() => _selectedLanguage = lang),
                        onRefreshModels: _loadModelsInfo,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 18),

                // ── Columna Derecha: Control Hub y Ejecución (flex: 5) ────────
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      StudioControlCard(
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
                      ),
                    ],
                  ),
                ),
              ],
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
