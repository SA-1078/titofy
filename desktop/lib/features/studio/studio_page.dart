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

  final List<String> _models = ['base', 'small', 'turbo'];
  final Map<String, String> _languages = {
    'auto': 'Auto-detectar',
    'es': 'Español (es)',
    'en': 'Inglés (en)',
    'pt': 'Portugués (pt)',
    'fr': 'Francés (fr)',
  };

  Map<String, Map<String, dynamic>> _modelsInfo = {};
  bool _isDownloadingModel = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadModelsInfo());
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

  Future<void> _downloadSelectedModel() async {
    if (_isDownloadingModel) return;
    setState(() => _isDownloadingModel = true);
    final api = context.read<ApiService>();
    final ok = await api.preloadModel(_selectedModel);
    await _loadModelsInfo();
    if (mounted) {
      setState(() => _isDownloadingModel = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Modelo $_selectedModel descargado y guardado en disco.'
              : 'Error o tiempo de espera agotado al descargar el modelo.'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _customLyricsCtrl.dispose();
    _artistCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg', 'opus', 'wma', 'mp4', 'mkv', 'webm', 'mov', 'avi'],
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
          throw Exception('Por favor pega o escribe la letra de la canción antes de iniciar Forced Alignment.');
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

        Timer? stageTimer;
        stageTimer = Timer.periodic(const Duration(milliseconds: 1400), (t) {
          if (!mounted || !_isProcessing) {
            t.cancel();
            return;
          }
          if (_selectedMode == 'ai_only') {
            if (t.tick == 1) {
              setState(() {
                _progressValue = 0.50;
                _currentStatusText = 'Analizando acústica y voz con Whisper...';
              });
            } else if (t.tick >= 2) {
              setState(() {
                _progressValue = 0.75;
                _currentStatusText = 'Generando marcas de tiempo sincronizadas...';
              });
            }
          } else if (_selectedMode == 'online_only') {
            if (t.tick == 1) {
              setState(() {
                _progressValue = 0.55;
                _currentStatusText = 'Consultando Fuente 2...';
              });
            } else if (t.tick >= 2) {
              setState(() {
                _progressValue = 0.80;
                _currentStatusText = 'Consultando Fuente 3...';
              });
            }
          } else {
            if (t.tick == 1) {
              setState(() {
                _progressValue = 0.50;
                _currentStatusText = 'Verificando fuentes y sincronización...';
              });
            } else if (t.tick >= 2) {
              setState(() {
                _progressValue = 0.75;
                _currentStatusText = 'Alineando versos con el audio local (Whisper)...';
              });
            }
          }
        });

        dynamic res;
        try {
          res = await api.resolveLyrics(
            artist: _artistCtrl.text.trim().isNotEmpty ? _artistCtrl.text.trim() : null,
            title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : null,
            audioPath: _selectedFilePath!,
            mode: _selectedMode,
            model: _selectedModel,
            language: _selectedLanguage,
          );
        } finally {
          stageTimer.cancel();
        }

        if (res != null) {
          final rawProv = res['provider']?.toString() ?? '';
          final rawSrc = res['source']?.toString() ?? '';
          String displaySource = 'Fuente 1';
          if (rawSrc == 'online_aligned' || rawProv.contains('Alineada') || rawProv.contains('calibrado')) {
            displaySource = rawProv.isNotEmpty ? rawProv : 'Fuente 1 · Alineada con Audio';
          } else if (rawSrc == 'ai_generated' || rawProv.toLowerCase().contains('whisper')) {
            displaySource = 'Whisper IA (Transcripción)';
          } else if (rawProv.contains('Fuente 1') || rawProv.toLowerCase().contains('lrclib')) {
            displaySource = 'Fuente 1';
          } else if (rawProv.contains('Fuente 2') || rawProv.toLowerCase().contains('netease')) {
            displaySource = 'Fuente 2';
          } else if (rawProv.contains('Fuente 3') || rawProv.toLowerCase().contains('genius') || rawProv.toLowerCase().contains('lyrist')) {
            displaySource = 'Fuente 3';
          } else {
            displaySource = rawProv.isNotEmpty ? rawProv : rawSrc;
          }

          setState(() {
            _progressValue = 1.0;
            _resultLines = res['lines'] as List? ?? [];
            _resultSource = displaySource;
            _currentStatusText = '¡Proceso completado! (${_resultLines.length} líneas generadas)';
          });

          try {
            final player = context.read<PlayerService>();
            if (player.currentTrack != null && player.currentTrack!.path == _selectedFilePath) {
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
        setState(() {
          _isProcessing = false;
        });
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
    final player = context.watch<PlayerService>();
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

            // ── Disposición de Dos Columnas ─────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── COLUMNA IZQUIERDA: Entrada y Parámetros (flex: 7) ─────────
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAudioSourceCard(c, player),
                      const SizedBox(height: 16),
                      _buildParametersCard(c),
                    ],
                  ),
                ),

                const SizedBox(width: 18),

                // ── COLUMNA DERECHA: Control Hub y Ejecución (flex: 5) ────────
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _buildExecutionControlCard(c, api, player),
                    ],
                  ),
                ),
              ],
            ),

            // ── Resultados de Letras Sincronizadas ──────────────────────────
            if (_resultLines.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildResultsCard(c),
            ],
          ],
        ),
      ),
    );
  }

  // ── Tarjeta de Selección de Archivo ───────────────────────────────────────
  Widget _buildAudioSourceCard(ThemeColors c, PlayerService player) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.glassBorder),
        boxShadow: [
          if (!c.isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.audio_file_rounded, size: 16, color: c.primary),
              const SizedBox(width: 8),
              Text(
                '1. ARCHIVO DE AUDIO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.primary,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              if (player.currentTrack != null)
                TextButton.icon(
                  icon: Icon(Icons.music_note_rounded, size: 13, color: c.primary),
                  label: Text(
                    'Usar pista en reproducción',
                    style: TextStyle(fontSize: 11, color: c.primary, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedFilePath = player.currentTrack!.path;
                      _artistCtrl.text = player.currentTrack!.artist;
                      _titleCtrl.text = player.currentTrack!.title;
                      _currentStatusText = 'Pista cargada: ${player.currentTrack!.artist} - ${player.currentTrack!.title}';
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Zona interactiva de archivo
          InkWell(
            onTap: _pickAudioFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.backgroundAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedFilePath != null ? c.primary.withOpacity(0.5) : c.glassBorder,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.primary.withOpacity(0.12),
                    ),
                    child: Icon(Icons.folder_open_rounded, size: 18, color: c.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFilePath != null
                              ? File(_selectedFilePath!).uri.pathSegments.last
                              : 'Haz clic aquí para seleccionar o arrastrar un archivo de audio',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _selectedFilePath != null ? FontWeight.w700 : FontWeight.w500,
                            color: _selectedFilePath != null ? c.textPrimary : c.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_selectedFilePath != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _selectedFilePath!,
                            style: TextStyle(fontSize: 10.5, color: c.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _pickAudioFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.surfaceHover,
                      foregroundColor: c.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: const Text('Examinar', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),

          if (_selectedFilePath != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _artistCtrl,
                    style: TextStyle(fontSize: 12, color: c.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Artista',
                      labelStyle: TextStyle(fontSize: 11, color: c.textSecondary),
                      filled: true,
                      fillColor: c.backgroundAlt,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _titleCtrl,
                    style: TextStyle(fontSize: 12, color: c.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Título',
                      labelStyle: TextStyle(fontSize: 11, color: c.textSecondary),
                      filled: true,
                      fillColor: c.backgroundAlt,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Tarjeta de Parámetros y Selector de Estrategia ────────────────────────
  Widget _buildParametersCard(ThemeColors c) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.glassBorder),
        boxShadow: [
          if (!c.isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: c.primary),
              SizedBox(width: 8),
              Text(
                '2. PARÁMETROS Y ESTRATEGIA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.primary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Selector de Estrategia Segmentado Moderno
          Text('Estrategia de resolución:', style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStrategyChip('auto', 'Híbrido (Online + Ajuste Local)', Icons.layers_rounded, c),
              _buildStrategyChip('ai_only', 'Transcribir con IA Local', Icons.memory_rounded, c),
              _buildStrategyChip('online_only', 'Solo Online', Icons.cloud_rounded, c),
              _buildStrategyChip('align', 'Alinear con Audio', Icons.format_align_left_rounded, c),
            ],
          ),

          const SizedBox(height: 14),

          // Fila compacta de Modelo e Idioma
          Row(
            children: [
              // Selector de Modelo Whisper
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modelo Whisper:', style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: c.backgroundAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.glassBorder),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedModel,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        dropdownColor: c.surface,
                        style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                        items: _models.map((m) {
                          final label = m == 'turbo' ? 'TURBO (large-v3)' : m == 'small' ? 'SMALL (Recomendado)' : 'BASE (Rápido)';
                          return DropdownMenuItem(value: m, child: Text(label));
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedModel = v ?? 'small'),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Builder(
                      builder: (context) {
                        final info = _modelsInfo[_selectedModel];
                        final isDownloaded = info?['downloaded'] == true;
                        final sizeStr = info?['size'] ?? (_selectedModel == 'turbo' ? '~1.5 GB' : _selectedModel == 'small' ? '~460 MB' : '~140 MB');

                        return Row(
                          children: [
                            Icon(
                              isDownloaded ? Icons.check_circle_rounded : Icons.cloud_download_rounded,
                              size: 13,
                              color: isDownloaded ? Colors.greenAccent : c.accent,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                isDownloaded
                                    ? 'Listo en disco ($sizeStr)'
                                    : 'Auto-descarga en 1er uso ($sizeStr)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDownloaded ? Colors.greenAccent : c.textMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isDownloaded)
                              _isDownloadingModel
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : InkWell(
                                      onTap: _downloadSelectedModel,
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        child: Text(
                                          'Descargar',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: c.accent,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Selector de Idioma
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Idioma:', style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: c.backgroundAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.glassBorder),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedLanguage,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        dropdownColor: c.surface,
                        style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                        items: _languages.entries
                            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedLanguage = v ?? 'auto'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_selectedMode == 'align') ...[
            const SizedBox(height: 14),
            Text('Texto plano para Forced Alignment:', style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _customLyricsCtrl,
              maxLines: 3,
              style: TextStyle(fontSize: 11.5, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Pega aquí la letra verso por verso...',
                hintStyle: TextStyle(fontSize: 11.5, color: c.textMuted),
                filled: true,
                fillColor: c.backgroundAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStrategyChip(String key, String label, IconData icon, ThemeColors c) {
    final isSelected = _selectedMode == key;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _selectedMode = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
        decoration: BoxDecoration(
          color: isSelected ? c.primary : c.backgroundAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? c.primary : c.glassBorder,
            width: 1.2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: c.primary.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? Colors.white : c.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tarjeta de Control Hub y Ejecución (Columna Derecha) ───────────────────
  Widget _buildExecutionControlCard(ThemeColors c, ApiService api, PlayerService player) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.glassBorder),
        boxShadow: [
          if (!c.isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_suggest_rounded, size: 16, color: c.primary),
              const SizedBox(width: 8),
              Text(
                'CENTRO DE PROCESAMIENTO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.primary,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: api.isOnline ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                api.isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: api.isOnline ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Resumen de Parámetros Activos
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.backgroundAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Modelo Activo', _selectedModel.toUpperCase(), Icons.memory_rounded, c),
                const Divider(height: 14, thickness: 0.5),
                _buildSummaryRow(
                  'Estrategia',
                  _selectedMode == 'auto'
                      ? 'Híbrido'
                      : _selectedMode == 'ai_only'
                          ? 'Solo IA'
                          : _selectedMode == 'online_only'
                              ? 'Solo Online'
                              : 'Alignment',
                  Icons.layers_rounded,
                  c,
                ),
                const Divider(height: 14, thickness: 0.5),
                _buildSummaryRow('Idioma', _languages[_selectedLanguage] ?? 'Auto', Icons.language_rounded, c),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Estado Dinámico y Progreso
          Text(
            'Estado:',
            style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            _currentStatusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _isProcessing ? c.primary : c.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          if (_isProcessing || _progressValue > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progressValue > 0 ? _progressValue : null,
                backgroundColor: c.backgroundAlt,
                color: c.primary,
                minHeight: 6,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Botón Prominente de Ejecución
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isProcessing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(
                _isProcessing ? 'PROCESANDO...' : 'INICIAR TRANSCRIPCIÓN',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 6,
                shadowColor: c.primary.withOpacity(0.45),
              ),
              onPressed: _isProcessing ? null : () => _processAudio(api),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon, ThemeColors c) {
    return Row(
      children: [
        Icon(icon, size: 14, color: c.primary),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: c.textPrimary),
        ),
      ],
    );
  }

  // ── Tarjeta de Resultados ─────────────────────────────────────────────────
  Widget _buildResultsCard(ThemeColors c) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.primary.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.subtitles_rounded, size: 16, color: c.primary),
                  const SizedBox(width: 8),
                  Text(
                    'VISTA PREVIA DE LETRAS SINCRONIZADAS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.primary),
                  ),
                  if (_resultSource != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: c.primary.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 12, color: c.primaryLight),
                          const SizedBox(width: 4),
                          Text(
                            _resultSource!,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.primaryLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '${_resultLines.length} líneas generadas',
                style: TextStyle(fontSize: 11, color: c.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _resultLines.length,
              itemBuilder: (context, i) {
                final line = _resultLines[i];
                final sec = (line['start'] as num? ?? line['time'] as num? ?? 0.0).toDouble();
                final m = (sec ~/ 60).toString().padLeft(2, '0');
                final s = (sec % 60).toStringAsFixed(2).padLeft(5, '0');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text('[$m:$s]', style: TextStyle(fontSize: 11, color: c.primary, fontFamily: 'monospace')),
                      const SizedBox(width: 12),
                      Expanded(child: Text(line['text'] ?? '', style: TextStyle(fontSize: 12, color: c.textPrimary))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
