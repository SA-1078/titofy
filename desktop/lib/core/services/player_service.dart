import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'library_service.dart';
import 'lyrics_service.dart';
import 'database_service.dart';

/// Servicio global de reproducción multimedia con cola y sincronización de letras
class PlayerService extends ChangeNotifier {
  final Player _player = Player();
  LyricsService? _lyricsService;
  DatabaseService? _dbService;

  // ── Cola de Reproducción ──────────────────────────────────────────────────
  List<Track> _queue = [];
  int _currentIndex = -1;

  // ── Estado ────────────────────────────────────────────────────────────────
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  Track? _currentTrack;

  // ── Getters ───────────────────────────────────────────────────────────────
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  Track? get currentTrack => _currentTrack;
  List<Track> get queue => _queue;
  int get currentIndex => _currentIndex;
  Player get player => _player;

  String get currentTitle => _currentTrack?.title ?? 'Sin reproducción';
  String get currentArtist => _currentTrack?.artist ?? 'Titofy Music';
  Uint8List? get currentArtwork => _currentTrack?.artwork;

  double get progress =>
      _duration.inMilliseconds > 0
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

  final List<dynamic> _subscriptions = [];

  void _subscribeToStreams() {
    _subscriptions.add(_player.stream.playing.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    }));

    _subscriptions.add(_player.stream.position.listen((pos) {
      _position = pos;
      _lyricsService?.updatePosition(pos);
      notifyListeners();
    }));

    _subscriptions.add(_player.stream.duration.listen((dur) {
      _duration = dur;
      notifyListeners();
    }));

    _subscriptions.add(_player.stream.volume.listen((vol) {
      _volume = vol / 100.0;
      notifyListeners();
    }));

    _subscriptions.add(_player.stream.completed.listen((completed) {
      if (completed) next();
    }));
  }

  // ── Reproducción de Pistas ────────────────────────────────────────────────
  Future<void> playTrack(Track track, {List<Track>? playlist, List<Track>? queue}) async {
    final file = File(track.path);
    if (!file.existsSync()) {
      debugPrint('[PlayerService] El archivo no existe en disco: ${track.path}');
      return;
    }

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
    notifyListeners();

    // Registrar reproduccion en la base de datos local SQLite
    _dbService?.recordPlayback(track.path);

    // Cargar letras sincronizadas para la pista
    _lyricsService?.loadForAudio(
      track.path,
      artist: track.artist,
      title: track.title,
    );

    await _player.open(Media(track.path));
    await _player.play();
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
        : (_duration > Duration.zero && target > _duration ? _duration : target);
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
