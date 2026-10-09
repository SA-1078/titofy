import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Modelo de Lista de Reproducción del usuario
class PlaylistModel {
  final int id;
  final String name;
  final String? description;
  final int createdAt;
  final int updatedAt;
  final int trackCount;

  PlaylistModel({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.trackCount = 0,
  });

  PlaylistModel copyWith({
    int? id,
    String? name,
    String? description,
    int? createdAt,
    int? updatedAt,
    int? trackCount,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      trackCount: trackCount ?? this.trackCount,
    );
  }
}

/// Servicio local de persistencia con SQLite para Titofy
class DatabaseService extends ChangeNotifier {
  Database? _db;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  List<PlaylistModel> _playlists = [];
  List<PlaylistModel> get playlists => _playlists;

  Set<String> _favoritePaths = {};
  Set<String> get favoritePaths => _favoritePaths;

  DatabaseService() {
    init();
  }

  /// Inicializa la base de datos SQLite y crea el esquema necesario
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      Directory appDir;
      try {
        appDir = await getApplicationSupportDirectory();
      } catch (_) {
        final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
        appDir = Directory(p.join(home, '.titofy'));
      }

      if (!appDir.existsSync()) {
        appDir.createSync(recursive: true);
      }

      final dbPath = p.join(appDir.path, 'titofy_library.db');
      _db = sqlite3.open(dbPath);

      _db!.execute('PRAGMA foreign_keys = ON;');
      _db!.execute('PRAGMA journal_mode = WAL;');

      _createTables();
      _loadSettings();
      _loadFavorites();
      _loadPlaylists();

      _isInitialized = true;
      notifyListeners();
      debugPrint('[DatabaseService] SQLite inicializado con exito en: $dbPath');
    } catch (e) {
      debugPrint('[DatabaseService] Error al inicializar SQLite: $e');
    }
  }

  void _createTables() {
    if (_db == null) return;

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS tracks (
        path TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT NOT NULL,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        play_count INTEGER NOT NULL DEFAULT 0,
        last_played_at INTEGER,
        added_at INTEGER NOT NULL
      );
    ''');

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS playlist_tracks (
        playlist_id INTEGER NOT NULL,
        track_path TEXT NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        added_at INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, track_path),
        FOREIGN KEY (playlist_id) REFERENCES playlists (id) ON DELETE CASCADE
      );
    ''');

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS playback_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        track_path TEXT NOT NULL,
        played_at INTEGER NOT NULL
      );
    ''');

    _db!.execute('CREATE INDEX IF NOT EXISTS idx_tracks_favorite ON tracks(is_favorite);');
    _db!.execute('CREATE INDEX IF NOT EXISTS idx_tracks_last_played ON tracks(last_played_at);');
    _db!.execute('CREATE INDEX IF NOT EXISTS idx_history_played_at ON playback_history(played_at);');
  }

  // ── CONFIGURACIONES DE USUARIO (SETTINGS) ──────────────────────────────────

  final Map<String, String> _settings = {};

  void _loadSettings() {
    if (_db == null) return;
    try {
      final rows = _db!.select('SELECT key, value FROM app_settings;');
      for (final r in rows) {
        _settings[r['key'] as String] = r['value'] as String;
      }
    } catch (e) {
      debugPrint('[DatabaseService] Error al cargar app_settings: $e');
    }
  }

  String? getSetting(String key, [String? defaultValue]) {
    return _settings[key] ?? defaultValue;
  }

  void setSetting(String key, String value) {
    if (_db == null) return;
    _settings[key] = value;
    try {
      _db!.execute('''
        INSERT INTO app_settings (key, value)
        VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value;
      ''', [key, value]);
      notifyListeners();
    } catch (e) {
      debugPrint('[DatabaseService] Error al guardar setting $key: $e');
    }
  }

  // ── TRACKS & CACHE ────────────────────────────────────────────────────────

  /// Carga todas las pistas registradas en la base de datos
  List<Map<String, dynamic>> getAllTracksRaw() {
    if (_db == null) return [];
    final ResultSet results = _db!.select('SELECT * FROM tracks ORDER BY artist COLLATE NOCASE, title COLLATE NOCASE;');
    return results.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Inserta o actualiza una pista preservando el estado de favorito y contador de reproducciones
  void upsertTrackRaw({
    required String path,
    required String title,
    required String artist,
    required String album,
    required int durationMs,
  }) {
    if (_db == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _db!.execute('''
      INSERT INTO tracks (path, title, artist, album, duration_ms, is_favorite, play_count, added_at)
      VALUES (?, ?, ?, ?, ?, 0, 0, ?)
      ON CONFLICT(path) DO UPDATE SET
        title = excluded.title,
        artist = excluded.artist,
        album = excluded.album,
        duration_ms = excluded.duration_ms;
    ''', [path, title, artist, album, durationMs, now]);
  }

  /// Insercion por lotes en una sola transaccion
  void upsertBatchTracksRaw(List<Map<String, dynamic>> trackMaps) {
    if (_db == null || trackMaps.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    _db!.execute('BEGIN TRANSACTION;');
    try {
      final stmt = _db!.prepare('''
        INSERT INTO tracks (path, title, artist, album, duration_ms, is_favorite, play_count, added_at)
        VALUES (?, ?, ?, ?, ?, 0, 0, ?)
        ON CONFLICT(path) DO UPDATE SET
          title = excluded.title,
          artist = excluded.artist,
          album = excluded.album,
          duration_ms = excluded.duration_ms;
      ''');

      for (final m in trackMaps) {
        stmt.execute([
          m['path'],
          m['title'],
          m['artist'],
          m['album'],
          m['duration_ms'] ?? 0,
          now,
        ]);
      }
      stmt.dispose();
      _db!.execute('COMMIT;');
    } catch (e) {
      _db!.execute('ROLLBACK;');
      debugPrint('[DatabaseService] Error en upsertBatchTracksRaw: $e');
    }
  }

  // ── FAVORITOS ──────────────────────────────────────────────────────────────

  void _loadFavorites() {
    if (_db == null) return;
    final rows = _db!.select('SELECT path FROM tracks WHERE is_favorite = 1;');
    _favoritePaths = rows.map((r) => r['path'] as String).toSet();
  }

  bool isFavorite(String path) => _favoritePaths.contains(path);

  void setFavorite(String path, bool isFav) {
    if (_db == null) return;
    _db!.execute(
      'UPDATE tracks SET is_favorite = ? WHERE path = ?;',
      [isFav ? 1 : 0, path],
    );

    if (isFav) {
      _favoritePaths.add(path);
    } else {
      _favoritePaths.remove(path);
    }
    notifyListeners();
  }

  bool toggleFavorite(String path) {
    final nextState = !_favoritePaths.contains(path);
    setFavorite(path, nextState);
    return nextState;
  }

  List<String> getFavoriteTrackPaths() {
    if (_db == null) return [];
    final rows = _db!.select('SELECT path FROM tracks WHERE is_favorite = 1 ORDER BY title COLLATE NOCASE;');
    return rows.map((r) => r['path'] as String).toList();
  }

  // ── HISTORIAL Y REPRODUCCIONES RECIENTES ───────────────────────────────────

  void recordPlayback(String path) {
    if (_db == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    _db!.execute('''
      UPDATE tracks
      SET play_count = play_count + 1, last_played_at = ?
      WHERE path = ?;
    ''', [now, path]);

    _db!.execute('''
      INSERT INTO playback_history (track_path, played_at)
      VALUES (?, ?);
    ''', [path, now]);

    notifyListeners();
  }

  List<String> getRecentlyPlayedPaths({int limit = 50}) {
    if (_db == null) return [];
    final rows = _db!.select('''
      SELECT path FROM tracks
      WHERE last_played_at IS NOT NULL
      ORDER BY last_played_at DESC
      LIMIT ?;
    ''', [limit]);
    return rows.map((r) => r['path'] as String).toList();
  }

  // ── PLAYLISTS ─────────────────────────────────────────────────────────────

  void _loadPlaylists() {
    if (_db == null) return;
    final rows = _db!.select('''
      SELECT p.id, p.name, p.description, p.created_at, p.updated_at,
             COUNT(pt.track_path) AS track_count
      FROM playlists p
      LEFT JOIN playlist_tracks pt ON p.id = pt.playlist_id
      GROUP BY p.id
      ORDER BY p.name COLLATE NOCASE ASC;
    ''');

    _playlists = rows.map((r) {
      return PlaylistModel(
        id: r['id'] as int,
        name: r['name'] as String,
        description: r['description'] as String?,
        createdAt: r['created_at'] as int,
        updatedAt: r['updated_at'] as int,
        trackCount: r['track_count'] as int,
      );
    }).toList();
  }

  PlaylistModel? createPlaylist(String name, [String? description]) {
    if (_db == null || name.trim().isEmpty) return null;
    final now = DateTime.now().millisecondsSinceEpoch;

    _db!.execute('''
      INSERT INTO playlists (name, description, created_at, updated_at)
      VALUES (?, ?, ?, ?);
    ''', [name.trim(), description?.trim(), now, now]);

    final id = _db!.lastInsertRowId;
    _loadPlaylists();
    notifyListeners();

    return _playlists.firstWhere((p) => p.id == id);
  }

  void renamePlaylist(int id, String newName, [String? newDesc]) {
    if (_db == null || newName.trim().isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    _db!.execute('''
      UPDATE playlists
      SET name = ?, description = ?, updated_at = ?
      WHERE id = ?;
    ''', [newName.trim(), newDesc?.trim(), now, id]);

    _loadPlaylists();
    notifyListeners();
  }

  void deletePlaylist(int id) {
    if (_db == null) return;
    _db!.execute('DELETE FROM playlists WHERE id = ?;', [id]);
    _loadPlaylists();
    notifyListeners();
  }

  bool addTrackToPlaylist(int playlistId, String trackPath) {
    if (_db == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      // Obtener posicion actual maxima
      final maxPosRow = _db!.select(
        'SELECT COALESCE(MAX(position), -1) AS max_pos FROM playlist_tracks WHERE playlist_id = ?;',
        [playlistId],
      );
      final nextPos = (maxPosRow.first['max_pos'] as int) + 1;

      _db!.execute('''
        INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_path, position, added_at)
        VALUES (?, ?, ?, ?);
      ''', [playlistId, trackPath, nextPos, now]);

      _db!.execute(
        'UPDATE playlists SET updated_at = ? WHERE id = ?;',
        [now, playlistId],
      );

      _loadPlaylists();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[DatabaseService] Error al agregar track a playlist: $e');
      return false;
    }
  }

  void removeTrackFromPlaylist(int playlistId, String trackPath) {
    if (_db == null) return;
    _db!.execute('''
      DELETE FROM playlist_tracks
      WHERE playlist_id = ? AND track_path = ?;
    ''', [playlistId, trackPath]);

    final now = DateTime.now().millisecondsSinceEpoch;
    _db!.execute(
      'UPDATE playlists SET updated_at = ? WHERE id = ?;',
      [now, playlistId],
    );

    _loadPlaylists();
    notifyListeners();
  }

  List<String> getPlaylistTrackPaths(int playlistId) {
    if (_db == null) return [];
    final rows = _db!.select('''
      SELECT track_path FROM playlist_tracks
      WHERE playlist_id = ?
      ORDER BY position ASC, added_at ASC;
    ''', [playlistId]);
    return rows.map((r) => r['track_path'] as String).toList();
  }

  bool isTrackInPlaylist(int playlistId, String trackPath) {
    if (_db == null) return false;
    final rows = _db!.select(
      'SELECT 1 FROM playlist_tracks WHERE playlist_id = ? AND track_path = ? LIMIT 1;',
      [playlistId, trackPath],
    );
    return rows.isNotEmpty;
  }

  @override
  void dispose() {
    _db?.dispose();
    super.dispose();
  }
}
