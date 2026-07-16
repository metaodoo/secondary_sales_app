import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite buffer for GPS coordinates captured by [LocationTrackingService].
///
/// Coordinates are logged here (fast, ACID, crash-safe) while a shift is active,
/// then flushed to Odoo in periodic batches. SQLite — not SharedPreferences —
/// because writes are frequent and must survive an unexpected process kill
/// without corrupting the whole store.
///
/// This helper is opened lazily inside whichever isolate touches it. The
/// background service runs in its own isolate, so the connection is established
/// there (not shared from the UI isolate).
class LocationDbHelper {
  LocationDbHelper._();

  /// Shared instance. `sqflite` keeps one native connection per open path, so a
  /// singleton per isolate avoids redundant opens.
  static final LocationDbHelper instance = LocationDbHelper._();

  static const String _dbName = 'locations.db';
  static const String _table = 'buffered_locations';

  Database? _db;

  Future<Database> get _database async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;

    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            recorded_at TEXT NOT NULL,
            is_mock INTEGER NOT NULL
          )
        ''');
      },
    );
    _db = db;
    return db;
  }

  /// Quick, non-blocking insert of a single captured coordinate.
  /// [recordedAt] must already be a server-compatible datetime string
  /// (UTC, `YYYY-MM-DD HH:MM:SS`).
  Future<void> insertLocation({
    required double latitude,
    required double longitude,
    required String recordedAt,
    required bool isMock,
  }) async {
    final db = await _database;
    await db.insert(_table, {
      'latitude': latitude,
      'longitude': longitude,
      'recorded_at': recordedAt,
      'is_mock': isMock ? 1 : 0,
    });
  }

  /// All buffered rows, oldest first (chronological / by insertion order).
  Future<List<Map<String, Object?>>> getBufferedLocations() async {
    final db = await _database;
    return db.query(_table, orderBy: 'id ASC');
  }

  /// Deletes every row up to and including [maxId] — called after a batch has
  /// been accepted by the server. No anchor is retained: the backend orders
  /// checkpoints by timestamp per attendance, so batches join up on their own,
  /// and retaining a row would re-upload it into a duplicate server row.
  Future<void> deleteUpToId(int maxId) async {
    final db = await _database;
    await db.delete(_table, where: 'id <= ?', whereArgs: [maxId]);
  }

  /// Number of unsynced coordinates currently buffered.
  Future<int> getLocationsCount() async {
    final db = await _database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM $_table');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
