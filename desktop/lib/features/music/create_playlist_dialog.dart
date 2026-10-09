import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/services/database_service.dart';
import '../../core/services/locale_service.dart';

/// Diálogo modal estilizado para crear una nueva Lista de Reproducción
class CreatePlaylistDialog extends StatefulWidget {
  const CreatePlaylistDialog({super.key});

  static Future<PlaylistModel?> show(BuildContext context) {
    return showDialog<PlaylistModel>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => const CreatePlaylistDialog(),
    );
  }

  @override
  State<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() {
      final valid = _nameCtrl.text.trim().isNotEmpty;
      if (valid != _canSubmit) {
        setState(() => _canSubmit = valid);
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final db = context.read<DatabaseService>();
    final created = db.createPlaylist(name, _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim());
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final loc = context.watch<LocaleService>();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.glassBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
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
                    color: c.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.playlist_add_rounded, color: c.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.t('createPlaylist'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Organiza tu música en listas personalizadas',
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Campo: Nombre de la lista
            Text(
              loc.t('playlistName'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: TextStyle(color: c.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ej. Favoritas de Rock, Mix de Estudio...',
                hintStyle: TextStyle(color: c.textMuted.withOpacity(0.7), fontSize: 13),
                filled: true,
                fillColor: c.backgroundAlt,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.glassBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.primary, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),

            // Campo: Descripcion opcional
            Text(
              loc.t('playlistDescription'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              style: TextStyle(color: c.textPrimary, fontSize: 13),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Breve descripción de esta lista (opcional)',
                hintStyle: TextStyle(color: c.textMuted.withOpacity(0.7), fontSize: 12),
                filled: true,
                fillColor: c.backgroundAlt,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.glassBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    loc.t('cancel'),
                    style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    disabledBackgroundColor: c.primary.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text(
                    loc.t('create'),
                    style: TextStyle(
                      color: _canSubmit ? c.textOnPrimary : c.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
