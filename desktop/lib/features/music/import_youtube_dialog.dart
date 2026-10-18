import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/database_service.dart';

/// Diálogo modal interactivo para importar playlists y vídeos desde YouTube / YouTube Music
class ImportYouTubeDialog extends StatefulWidget {
  const ImportYouTubeDialog({super.key});

  static Future<PlaylistModel?> show(BuildContext context) {
    return showDialog<PlaylistModel>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) => const ImportYouTubeDialog(),
    );
  }

  @override
  State<ImportYouTubeDialog> createState() => _ImportYouTubeDialogState();
}

class _ImportYouTubeDialogState extends State<ImportYouTubeDialog> {
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();

  bool _isAnalyzing = false;
  bool _isImporting = false;
  String? _errorMessage;

  Map<String, dynamic>? _extractedData;
  List<Map<String, dynamic>> _extractedTracks = [];
  Set<int> _selectedIndices = {};
  PlaylistModel? _existingDuplicate;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyzeUrl() async {
    final rawUrl = _urlCtrl.text.trim();
    if (rawUrl.isEmpty) {
      setState(() => _errorMessage = 'Por favor ingresa un enlace de YouTube o YouTube Music');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _extractedData = null;
      _existingDuplicate = null;
    });

    try {
      final api = context.read<ApiService>();
      final db = context.read<DatabaseService>();
      final data = await api.extractYouTubePlaylist(rawUrl);

      if (!mounted) return;

      if (data == null || data['tracks'] == null || (data['tracks'] as List).isEmpty) {
        throw Exception('No se encontraron canciones en el enlace proporcionado.');
      }

      final tracks = List<Map<String, dynamic>>.from(data['tracks']);
      final canonicalUrl = data['canonical_url'] as String? ?? rawUrl;
      final defaultTitle = data['title'] as String? ?? 'Playlist de YouTube';

      // Verificar duplicados existentes en SQLite
      final duplicate = db.findPlaylistBySourceUrl(canonicalUrl);

      setState(() {
        _isAnalyzing = false;
        _extractedData = data;
        _extractedTracks = tracks;
        _selectedIndices = Set<int>.from(List.generate(tracks.length, (i) => i));
        _nameCtrl.text = defaultTitle;
        _existingDuplicate = duplicate;
      });
    } catch (e) {
      String msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('SocketException') || msg.contains('Connection refused')) {
        msg = 'No se pudo conectar con el motor local de Titofy. Verifica que el backend esté activo.';
      }
      setState(() {
        _isAnalyzing = false;
        _errorMessage = msg;
      });
    }
  }

  Future<void> _confirmImport() async {
    if (_extractedData == null || _selectedIndices.isEmpty) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'La lista debe tener un nombre');
      return;
    }

    final selectedTracks = _selectedIndices.map((i) => _extractedTracks[i]).toList();
    final canonicalUrl = _extractedData!['canonical_url'] as String? ?? _urlCtrl.text.trim();

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    try {
      final db = context.read<DatabaseService>();
      final created = db.importYouTubePlaylist(
        name: name,
        sourceUrl: canonicalUrl,
        description: 'Importada desde YouTube (${selectedTracks.length} canciones)',
        tracks: selectedTracks,
      );

      if (created != null) {
        // Disparar búsqueda de letras en segundo plano sin bloquear
        _triggerBackgroundLyricsSearch(selectedTracks);
        if (mounted) {
          Navigator.of(context).pop(created);
        }
      } else {
        throw Exception('No se pudo guardar la lista de reproducción en SQLite');
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _errorMessage = 'Error al guardar la lista: $e';
      });
    }
  }

  /// Busca letras online en segundo plano con concurrencia controlada
  void _triggerBackgroundLyricsSearch(List<Map<String, dynamic>> tracks) {
    final api = context.read<ApiService>();

    Future.microtask(() async {
      // Procesar en lotes de 2 para no saturar proveedores
      for (int i = 0; i < tracks.length; i += 2) {
        final batch = tracks.skip(i).take(2).toList();
        await Future.wait(batch.map((t) async {
          final title = t['title'] as String?;
          final artist = t['artist'] as String?;
          final durationSec = ((t['duration_ms'] as int?) ?? 0) / 1000.0;

          if (title != null && artist != null) {
            try {
              await api.resolveLyrics(
                artist: artist,
                title: title,
                duration: durationSec > 0 ? durationSec : null,
                mode: 'online_only',
              );
            } catch (_) {
              // Silenciar errores individuales para que el lote continúe
            }
          }
        }));
        await Future.delayed(const Duration(milliseconds: 250));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Encabezado ────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.smart_display_rounded, color: Colors.redAccent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Importar de YouTube / YT Music',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Metadatos y letras automáticas sin descargas de audio',
                          style: TextStyle(color: c.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: c.textSecondary, size: 20),
                    splashRadius: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Campo de URL o Vista Previa ────────────────────────────────
              if (_extractedData == null) ...[
                Text(
                  'Pega el enlace de una lista o vídeo:',
                  style: TextStyle(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlCtrl,
                        autofocus: true,
                        style: TextStyle(color: c.textPrimary, fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'https://music.youtube.com/playlist?list=...',
                          hintStyle: TextStyle(color: c.textMuted.withOpacity(0.6)),
                          filled: true,
                          fillColor: c.surfaceLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: c.surfaceLight),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: c.surfaceLight),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: c.primary, width: 1.5),
                          ),
                        ),
                        onSubmitted: (_) => _analyzeUrl(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isAnalyzing ? null : _analyzeUrl,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: c.textOnPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isAnalyzing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Analizar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ] else ...[
                // Resumen y nombre editable
                TextField(
                  controller: _nameCtrl,
                  style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Nombre de la Lista en Titofy',
                    labelStyle: TextStyle(color: c.textMuted),
                    filled: true,
                    fillColor: c.surfaceLight,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),

                // Aviso de duplicado si aplica
                if (_existingDuplicate != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Esta lista ya existe como "${_existingDuplicate!.name}". Puedes reimportarla o cancelar.',
                            style: const TextStyle(color: Colors.amber, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Barra de selección
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedIndices.length} de ${_extractedTracks.length} canciones seleccionadas',
                      style: TextStyle(color: c.textMuted, fontSize: 12.5),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedIndices.length == _extractedTracks.length) {
                            _selectedIndices.clear();
                          } else {
                            _selectedIndices = Set<int>.from(List.generate(_extractedTracks.length, (i) => i));
                          }
                        });
                      },
                      child: Text(
                        _selectedIndices.length == _extractedTracks.length ? 'Deseleccionar todas' : 'Seleccionar todas',
                        style: TextStyle(color: c.primary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],

              // ── Mensaje de error si aplica ─────────────────────────────────
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.error.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: c.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: c.error, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Lista de canciones detectadas ──────────────────────────────
              if (_extractedTracks.isNotEmpty) ...[
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.surfaceLight.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.surfaceLight),
                    ),
                    child: ListView.builder(
                      itemCount: _extractedTracks.length,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemBuilder: (ctx, idx) {
                        final t = _extractedTracks[idx];
                        final isSelected = _selectedIndices.contains(idx);
                        final durationSec = ((t['duration_ms'] as int?) ?? 0) ~/ 1000;
                        final durationStr = durationSec > 0
                            ? '${durationSec ~/ 60}:${(durationSec % 60).toString().padLeft(2, '0')}'
                            : '--:--';

                        return CheckboxListTile(
                          value: isSelected,
                          dense: true,
                          activeColor: c.primary,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          title: Text(
                            t['title'] as String? ?? 'Sin título',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected ? c.textPrimary : c.textMuted,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            t['artist'] as String? ?? 'Artista desconocido',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.textMuted, fontSize: 11.5),
                          ),
                          secondary: Text(
                            durationStr,
                            style: TextStyle(color: c.textMuted, fontSize: 11.5),
                          ),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIndices.add(idx);
                              } else {
                                _selectedIndices.remove(idx);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ── Botones de acción ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancelar', style: TextStyle(color: c.textSecondary)),
                  ),
                  if (_extractedData != null) ...[
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: (_isImporting || _selectedIndices.isEmpty) ? null : _confirmImport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: c.textOnPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: _isImporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.playlist_add_check_rounded, size: 18),
                      label: Text(
                        _isImporting ? 'Guardando...' : 'Importar (${_selectedIndices.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
