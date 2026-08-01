import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Servicio global de reproducción — audio y video via media_kit
class PlayerService extends ChangeNotifier {
  final Player _player = Player();
  late final VideoController videoController;

  // ── Estado ────────────────────────────────────────────────────────────────
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  Media? _currentMedia;
  String? _currentTitle;
  String? _currentArtist;
  Uint8List? _currentArtwork;   // bytes de la carátula

  // ── Getters ───────────────────────────────────────────────────────────────
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  Media? get currentMedia => _currentMedia;
  String? get currentTitle => _currentTitle;
  String? get currentArtist => _currentArtist;
  Uint8List? get currentArtwork => _currentArtwork;
  Player get player => _player;

  double get progress =>
      _duration.inMilliseconds > 0
          ? _position.inMilliseconds / _duration.inMilliseconds
          : 0.0;

  PlayerService() {
    videoController = VideoController(_player);
    _subscribeToStreams();
  }

  void _subscribeToStreams() {
    _player.stream.playing.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });
    _player.stream.position.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    _player.stream.duration.listen((dur) {
      _duration = dur;
      notifyListeners();
    });
    _player.stream.volume.listen((vol) {
      _volume = vol / 100.0;
      notifyListeners();
    });
  }

  // ── Controles ─────────────────────────────────────────────────────────────
  Future<void> open(String path, {
    String? title,
    String? artist,
    Uint8List? artwork,
  }) async {
    _currentTitle = title ?? path.split('/').last;
    _currentArtist = artist;
    _currentArtwork = artwork;
    _currentMedia = Media(path);
    await _player.open(_currentMedia!);
    notifyListeners();
  }

  Future<void> playPause() async {
    await _player.playOrPause();
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setVolume(double vol) async {
    await _player.setVolume(vol * 100);
  }

  Future<void> next() async {
    await _player.next();
  }

  Future<void> previous() async {
    await _player.previous();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
