import 'package:sqlite3/sqlite3.dart';

/// Creación y migración de tablas para la base de datos SQLite de Titofy
class DatabaseSchema {
  static void createTables(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    db.execute('''
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

    db.execute('''
      CREATE TABLE IF NOT EXISTS playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS playlist_tracks (
        playlist_id INTEGER NOT NULL,
        track_path TEXT NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        added_at INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, track_path),
        FOREIGN KEY (playlist_id) REFERENCES playlists (id) ON DELETE CASCADE
      );
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS playback_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        track_path TEXT NOT NULL,
        played_at INTEGER NOT NULL
      );
    ''');

    db.execute('CREATE INDEX IF NOT EXISTS idx_tracks_favorite ON tracks(is_favorite);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_tracks_last_played ON tracks(last_played_at);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_history_played_at ON playback_history(played_at);');
  }
}
