import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/lyrics_service.dart';
import '../../core/services/library_service.dart';
import '../../core/services/player_service.dart';

/// Diálogo interactivo del Motor Híbrido de Titofy (Idéntico al pipeline de la CLI)
class HybridLyricsDialog extends StatefulWidget {
  final Track track;

  const HybridLyricsDialog({super.key, required this.track});

  static Future<void> show(BuildContext context, Track track) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => HybridLyricsDialog(track: track),
    );
  }

  @override
  State<HybridLyricsDialog> createState() => _HybridLyricsDialogState();
}

class _HybridLyricsDialogState extends State<HybridLyricsDialog> {
  String _step = 'Iniciando...';
  String _detail = '';
  double _progress = 0.1;
  bool _isDone = false;
  bool _hasError = false;
  String? _source;
  int _lineCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runHybridResolution();
    });
  }

  Future<void> _runHybridResolution() async {
    final api = context.read<ApiService>();
    final lyricsService = context.read<LyricsService>();

    setState(() {
      _step = 'Paso 1/3: Verificando conexión con el motor de IA...';
      _detail = 'Comprobando FastAPI en localhost:8642';
      _progress = 0.2;
    });

    final isRunning = await api.ensureServerRunning();
    if (!isRunning) {
      setState(() {
        _hasError = true;
        _step = 'No se pudo conectar al microservicio FastAPI';
        _detail = 'Asegúrate de que Python y las dependencias de backend/.venv estén listas.';
      });
      return;
    }

    setState(() {
      _step = 'Paso 2/3: Consultando proveedores remotos y alineando con audio...';
      _detail = 'Buscando: ${widget.track.artist} - ${widget.track.title}';
      _progress = 0.5;
    });

    try {
      final res = await api.resolveLyrics(
        artist: widget.track.artist,
        title: widget.track.title,
        duration: widget.track.duration.inSeconds.toDouble(),
        audioPath: widget.track.path,
        outputPath: null,
        mode: 'auto',
        force: true,
      );

      if (res != null && res['lines'] != null && (res['lines'] as List).isNotEmpty) {
        final lines = res['lines'] as List;
        final src = res['source']?.toString().toLowerCase() ?? '';
        final prov = res['provider']?.toString() ?? '';
        if (src == 'online_aligned' || prov.contains('Alineada') || prov.toLowerCase().contains('calibrado')) {
          _source = 'Modo Híbrido (Online + Alineación con Audio)';
        } else if (src == 'ai_generated' || prov.toLowerCase().contains('whisper')) {
          _source = 'Transcripción Whisper IA Local';
        } else if (prov.toLowerCase().contains('lyrist')) {
          _source = 'Proveedor Online: Fuente 3';
        } else if (prov.toLowerCase().contains('genius')) {
          _source = 'Proveedor Online: Fuente 3';
        } else if (src == 'online_synced' || prov.toLowerCase().contains('lrclib')) {
          _source = 'Proveedor Online: Fuente 1 (Sincronizado)';
        } else {
          _source = prov.isNotEmpty ? prov : (res['source'] ?? 'Motor Híbrido Titofy');
        }

        setState(() {
          _progress = 1.0;
          _isDone = true;
          _step = 'Sincronización completada con éxito';
          _detail = 'Se obtuvieron $_lineCount versos sincronizados y alineados con el audio.\nFuente: $_source\nGuardado en: biblioteca de letras (.lrc)';
        });

        // Recargar letras en el servicio de reproducción
        await lyricsService.loadForAudio(
          widget.track.path,
          artist: widget.track.artist,
          title: widget.track.title,
        );
      } else {
        // Fallback a Whisper puro local si no hubo letras online
        setState(() {
          _step = 'Paso 3/3: Sin coincidencias online. Ejecutando Whisper IA local...';
          _detail = 'Transcribiendo audio offline con aceleración de GPU/CPU...';
          _progress = 0.75;
        });

        final success = await lyricsService.regenerateWithAI(widget.track.path);
        if (success) {
          setState(() {
            _progress = 1.0;
            _isDone = true;
            _step = 'Transcripción con Whisper completada';
            _detail = 'Letras generadas por el modelo local de IA.';
          });
        } else {
          throw Exception('No se encontraron letras ni se pudo transcribir');
        }
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _step = 'Error durante la resolución de letras';
        _detail = e.toString();
      });
    }
  }

  Future<void> _forceRegenerate() async {
    setState(() {
      _isDone = false;
      _hasError = false;
      _progress = 0.3;
      _step = 'Regenerando con Whisper IA Local...';
      _detail = 'Forzando transcripción milimétrica con el modelo local offline...';
    });
    final lyricsService = context.read<LyricsService>();
    final success = await lyricsService.regenerateWithAI(widget.track.path);
    if (success) {
      setState(() {
        _progress = 1.0;
        _isDone = true;
        _step = '¡Regeneración con Whisper completada!';
        _detail = 'El archivo .lrc ha sido actualizado con alineación al audio.';
      });
    } else {
      setState(() {
        _hasError = true;
        _step = 'Error en la transcripción';
        _detail = 'Verifica que backend/.venv tenga faster-whisper instalado.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerService>();
    final c = context.colors;

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: c.glassBorder)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: c.primaryGradient,
                  ),
                  child: const Center(
                    child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Motor Híbrido Titofy',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                      ),
                      Text(
                        '${widget.track.title} · ${widget.track.artist}',
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Estado y detalle
            Text(
              _step,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _hasError ? c.error : (_isDone ? c.success : c.primaryLight),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _detail,
              style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.4),
            ),

            const SizedBox(height: 20),

            // Barra de Progreso
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _hasError ? 0.0 : _progress,
                minHeight: 6,
                backgroundColor: c.backgroundAlt,
                color: _hasError ? c.error : (_isDone ? c.success : c.primary),
              ),
            ),

            const SizedBox(height: 24),

            // Botones de acción
            Row(
              children: [
                if (_isDone)
                  TextButton.icon(
                    icon: Icon(Icons.refresh_rounded, size: 16, color: c.primary),
                    label: Text('Forzar IA (Whisper)', style: TextStyle(color: c.primary, fontSize: 12)),
                    onPressed: _forceRegenerate,
                  ),
                const Spacer(),
                if (_isDone || _hasError)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cerrar', style: TextStyle(color: c.textSecondary)),
                  ),
                if (_isDone) ...[
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Reproducir ahora'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      player.playTrack(widget.track);
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
