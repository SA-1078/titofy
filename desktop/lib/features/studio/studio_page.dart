import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class StudioPage extends StatefulWidget {
  const StudioPage({super.key});

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  String _selectedModel = 'small';
  String _selectedLanguage = 'es';
  bool _wordTimestamps = true;
  bool _isProcessing = false;
  double _progressValue = 0.0;
  String _currentStep = 'Esperando archivo...';

  final List<String> _whisperModels = ['base', 'small', 'turbo'];
  final Map<String, String> _languages = {
    'auto': 'Auto-detectar',
    'es': 'Español',
    'en': 'Inglés',
    'pt': 'Portugués',
    'fr': 'Francés',
  };

  void _startTranscription() async {
    setState(() {
      _isProcessing = true;
      _progressValue = 0.1;
      _currentStep = 'Iniciando pipeline de IA...';
    });

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _progressValue = 0.3;
      _currentStep = 'Dividiendo pistas de audio y detectando música...';
    });

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() {
      _progressValue = 0.6;
      _currentStep = 'Transcribiendo con Whisper local (Small Model)...';
    });

    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    setState(() {
      _progressValue = 0.85;
      _currentStep = 'Alineando texto (Forced Alignment) y limpiando alucinaciones...';
    });

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _progressValue = 1.0;
      _currentStep = '¡Completado! Archivo .lrc guardado en /lrc';
    });

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _progressValue = 0.0;
      _currentStep = 'Esperando archivo...';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera elegante
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Titofy IA Studio',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Transcribe tus audios o videos locales a letras sincronizadas (.lrc) en segundos',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Layout de Paneles
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drop Zone / Progreso (Izquierda)
                  Expanded(
                    flex: 5,
                    child: _isProcessing ? _buildProgressPanel() : _buildDropZone(),
                  ),
                  const SizedBox(width: 20),
                  // Configuración (Derecha)
                  Expanded(
                    flex: 3,
                    child: _buildConfigPanel(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigPanel() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.glassBg.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.settings_suggest_rounded, color: AppColors.primaryLight, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Parámetros del Motor',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.glassBorder),
          const SizedBox(height: 16),

          // Selección de Modelo
          Text(
            'MODELO LOCAL WHISPER',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedModel,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                items: _whisperModels.map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text(
                      'Whisper ${m[0].toUpperCase()}${m.substring(1)}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    ),
                  );
                }).toList(),
                onChanged: _isProcessing ? null : (v) => setState(() => _selectedModel = v!),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Selección de Idioma
          Text(
            'IDIOMA DE TRANSCRIPCIÓN',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLanguage,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                items: _languages.entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      e.value,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    ),
                  );
                }).toList(),
                onChanged: _isProcessing ? null : (v) => setState(() => _selectedLanguage = v!),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Timestamps Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Palabra por palabra',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Requerido para Karaoke',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
              Switch(
                value: _wordTimestamps,
                activeColor: AppColors.secondary,
                onChanged: _isProcessing ? null : (v) => setState(() => _wordTimestamps = v),
              ),
            ],
          ),

          const Spacer(),

          // Botón de Inicio
          SizedBox(
            width: double.infinity,
            height: 46,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: _isProcessing ? null : AppColors.primaryGradient,
                boxShadow: _isProcessing
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _startTranscription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Iniciar Procesamiento',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropZone() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassBg.withOpacity(0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder.withOpacity(0.5), width: 1.5),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Círculo glowing premium
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary.withOpacity(0.15), AppColors.secondary.withOpacity(0.15)],
                ),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: const Center(
                child: Icon(
                  Icons.drive_folder_upload_rounded,
                  color: AppColors.primaryLight,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Arrastra tu pista de audio o video aquí',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Formatos soportados: MP3, WAV, FLAC, MP4, MKV...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.glassBg.withOpacity(0.08),
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.glassBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: const Text('Examinar Archivos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressPanel() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.glassBg.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: _progressValue,
              strokeWidth: 3,
              backgroundColor: AppColors.glassBorder,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Ejecutando Titofy IA Engine',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            _currentStep,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 28),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 260,
              height: 4,
              child: LinearProgressIndicator(
                value: _progressValue,
                color: AppColors.primaryLight,
                backgroundColor: AppColors.glassBorder,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_progressValue * 100).round()}%',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
