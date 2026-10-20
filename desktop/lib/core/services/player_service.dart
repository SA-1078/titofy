import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'library_service.dart';
import 'lyrics_service.dart';
import 'database_service.dart';
import 'api_service.dart';
import 'audio_beat_analysis_service.dart';

/// Servicio global de reproducción multimedia con cola y sincronización de letras
class PlayerService extends ChangeNotifier {
  final Player _player = Player();
  final AudioBeatAnalysisService _audioAnalysis = AudioBeatAnalysisService();
  LyricsService? _lyricsService;
  DatabaseService? _dbService;
  ApiService? _apiService;

  // ── Cola de Reproducción ──────────────────────────────────────────────────
  List<Track> _queue = [];
  int _currentIndex = -1;

  // ── Estado ────────────────────────────────────────────────────────────────
  bool _isPlaying = false;
  bool _isResolvingStream = false;
  int _streamRequestId = 0;
  int _analysisRequestId = 0;
  bool _analysisInProgress = false;
  String? _analysisPath;
  AudioBeatProfile? _audioBeatProfile;
  Duration _position = Duration.zero;
  Duration? _lastPositionNotification;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  Track? _currentTrack;

  // ── Getters ───────────────────────────────────────────────────────────────
  bool get isPlaying => _isPlaying;
  bool get isResolvingStream => _isResolvingStream;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  Track? get currentTrack => _currentTrack;
  List<Track> get queue => _queue;
  int get currentIndex => _currentIndex;
  Player get player => _player;
  AudioBeatProfile? get audioBeatProfile => _audioBeatProfile;

  String get currentTitle => _currentTrack?.title ?? 'Sin reproducción';
  String get currentArtist => _currentTrack?.artist ?? 'Titofy Music';
  Uint8List? get currentArtwork => _currentTrack?.artwork;

  double get progress => _duration.inMilliseconds > 0
      ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
      : 0.0;

  PlayerService() {
    _subscribeToStreams();
  }

  void attachLyricsService(LyricsService service) {
    _lyricsService = service;
  }

  void attachDatabaseService(DatabaseService service) {
    _dbService = service;
  }

  void attachApiService(ApiService service) {
    _apiService = service;
  }

  final List<dynamic> _subscriptions = [];

  void _subscribeToStreams() {
    _subscriptions.add(
      _player.stream.playing.listen((playing) {
        _isPlaying = playing;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _player.stream.position.listen((pos) {
        _position = pos;
        _lyricsService?.updatePosition(pos);

        // La letra se actualiza siempre, pero la UI no necesita reconstruirse
        // con cada evento de posición emitido por media_kit.
        final previous = _lastPositionNotification;
        final delta = previous == null ? Duration.zero : pos - previous;
        if (previous == null ||
            delta.abs() >= const Duration(milliseconds: 100)) {
          _lastPositionNotification = pos;
          notifyListeners();
        }
      }),
    );

    _subscriptions.add(
      _player.stream.duration.listen((dur) {
        _duration = dur;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _player.stream.volume.listen((vol) {
        _volume = vol / 100.0;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _player.stream.completed.listen((completed) {
        if (completed) next();
      }),
    );
  }

  // ── Reproducción de Pistas ────────────────────────────────────────────────
  Future<void> playTrack(
    Track track, {
    List<Track>? playlist,
    List<Track>? queue,
  }) async {
    final targetList = playlist ?? queue;
    if (targetList != null) {
      _queue = List.from(targetList);
      _currentIndex = _queue.indexOf(track);
    } else if (!_queue.contains(track)) {
      _queue.add(track);
      _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = _queue.indexOf(track);
    }

    _currentTrack = track;
    ++_analysisRequestId;
    _analysisPath = null;
    _analysisInProgress = false;
    _audioBeatProfile = null;
    // Limpiar inmediatamente letras anteriores para no mezclar letras entre canciones
    _lyricsService?.clear();
    notifyListeners();

    // ── Caso 1: Pista remota de YouTube (Streaming instantáneo vía backend) ──
    if (track.isRemote) {
      final videoId = track.remoteId;
      if (videoId == null || videoId.isEmpty) {
        debugPrint(
          '[PlayerService] Track remoto sin ID de vídeo válido: ${track.path}',
        );
        return;
      }

      if (_apiService == null) {
        debugPrint('[PlayerService] ApiService no disponible para streaming.');
        return;
      }

      final currentReq = ++_streamRequestId;
      _isResolvingStream = true;
      notifyListeners();

      try {
        final streamUrl = await _apiService!.getYouTubeStreamUrl(videoId);
        if (_streamRequestId != currentReq) {
          // El usuario seleccionó otra canción antes de resolver esta
          return;
        }

        _isResolvingStream = false;
        notifyListeners();

        if (streamUrl == null || streamUrl.isEmpty) {
          debugPrint('[PlayerService] No se pudo obtener stream para $videoId');
          return;
        }

        // Registrar reproducción en base de datos local SQLite
        _dbService?.recordPlayback(track.path);

        // Cargar letras sincronizadas para la pista remota
        _lyricsService?.loadForAudio(
          track.path,
          artist: track.artist,
          title: track.title,
        );

        await _player.open(Media(streamUrl));
        await _player.play();
        prepareAudioBeatProfile(directAudioSource: streamUrl);
      } catch (e) {
        if (_streamRequestId == currentReq) {
          _isResolvingStream = false;
          notifyListeners();
        }
        debugPrint(
          '[PlayerService] Error al reproducir streaming de YouTube: $e',
        );
      }
      return;
    }

    // ── Caso 2: Pista con archivo físico en disco local ──────────────────────
    final file = File(track.path);
    if (!file.existsSync()) {
      debugPrint(
        '[PlayerService] El archivo no existe en disco: ${track.path}',
      );
      return;
    }

    // Registrar reproducción en la base de datos local SQLite
    _dbService?.recordPlayback(track.path);

    // Cargar letras sincronizadas para la pista
    _lyricsService?.loadForAudio(
      track.path,
      artist: track.artist,
      title: track.title,
    );

    await _player.open(Media(track.path));
    await _player.play();
    prepareAudioBeatProfile();
  }

  /// Solicita el perfil acústico de la pista en reproducción de manera asíncrona.
  /// La operación usa caché en disco y nunca bloquea la reproducción.
  Future<void> prepareAudioBeatProfile({String? directAudioSource}) async {
    final track = _currentTrack;
    if (track == null) return;
    final source = directAudioSource ?? track.path;
    if (!track.isRemote && !File(source).existsSync()) return;
    if (_analysisPath == track.path &&
        (_audioBeatProfile != null || _analysisInProgress)) {
      return;
    }
    _analysisPath = track.path;
    _analysisInProgress = true;
    final requestId = ++_analysisRequestId;
    _audioBeatProfile = null;
    await _prepareAudioProfile(source, requestId, cacheKey: track.path);
  }

  Future<void> _prepareAudioProfile(
    String source,
    int requestId, {
    String? cacheKey,
  }) async {
    final profile = await _audioAnalysis.analyze(source, cacheKeyId: cacheKey);
    if (requestId != _analysisRequestId) return;
    _analysisInProgress = false;
    if (profile == null) return;
    _audioBeatProfile = profile;
    notifyListeners();
  }

  Future<void> playPause() async {
    if (_currentTrack == null) {
      if (_queue.isNotEmpty) {
        await playTrack(_queue.first);
      }
      return; // No reproducir nada si no hay canción cargada ni en cola
    }
    await _player.playOrPause();
  }

  Future<void> seekTo(Duration position) async {
    if (_currentTrack == null) return;
    await _player.seek(position);
  }

  Future<void> seekRelative(Duration delta) async {
    if (_currentTrack == null) return;
    final target = _position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && target > _duration
              ? _duration
              : target);
    await seekTo(clamped);
  }

  Future<void> setVolume(double vol) async {
    await _player.setVolume((vol * 100).clamp(0, 100));
  }

  Future<void> changeVolume(double delta) async {
    final newVol = (_volume + delta).clamp(0.0, 1.0);
    await setVolume(newVol);
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    if (_currentIndex + 1 < _queue.length) {
      _currentIndex++;
      await playTrack(_queue[_currentIndex]);
    } else if (_queue.isNotEmpty) {
      _currentIndex = 0;
      await playTrack(_queue[0]);
    }
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_position.inSeconds > 3) {
      await seekTo(Duration.zero);
      return;
    }
    if (_currentIndex - 1 >= 0) {
      _currentIndex--;
      await playTrack(_queue[_currentIndex]);
    } else {
      await seekTo(Duration.zero);
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      try {
        s.cancel();
      } catch (_) {}
    }
    _subscriptions.clear();
    _player.dispose();
    super.dispose();
  }
}
