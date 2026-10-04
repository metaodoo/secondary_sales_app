import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Database helper governing the offline-first outbox and master data caching.
///
/// Configured with Write-Ahead Logging (WAL) and a 5000ms busy timeout to
/// guarantee that background syncing never blocks or locks the UI thread.
class OfflineDatabaseHelper {
  OfflineDatabaseHelper._();

  static final OfflineDatabaseHelper instance = OfflineDatabaseHelper._();

  static const String _dbName = 'offline_store.db';
  static const int _dbVersion = 1;

  static const String tableOutbox = 'outbox_operations';
  static const String tableMasterCache = 'cached_master_data';

  Database? _db;
  final Uuid _uuidGenerator = const Uuid();

  Future<Database> get database async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;

    final dir = await getDatabasesPath();
    final dbPath = p.join(dir, _dbName);

    final db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: (db) async {
        // Enforce Write-Ahead Logging for high concurrency without UI stalls
        await db.execute('PRAGMA journal_mode = WAL;');
        await db.execute('PRAGMA busy_timeout = 5000;');
        await db.execute('PRAGMA synchronous = NORMAL;');
      },
      onCreate: (db, version) async {
        // 1. Outbound Write Queue
        await db.execute('''
          CREATE TABLE $tableOutbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operation_uuid TEXT NOT NULL UNIQUE,
            entity_type TEXT NOT NULL,
            endpoint TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            parent_uuid TEXT,
            created_at TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'PENDING',
            retry_count INTEGER NOT NULL DEFAULT 0,
            error_code TEXT,
            error_message TEXT,
            last_attempt_at TEXT
          );
        ''');

        await db.execute(
          'CREATE INDEX idx_outbox_status ON $tableOutbox(status);',
        );
        await db.execute(
          'CREATE INDEX idx_outbox_uuid ON $tableOutbox(operation_uuid);',
        );
        await db.execute(
          'CREATE INDEX idx_outbox_created ON $tableOutbox(created_at);',
        );

        // 2. Inbound Master Data Cache
        await db.execute('''
          CREATE TABLE $tableMasterCache (
            entity_key TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,
            data_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        await db.execute(
          'CREATE INDEX idx_cache_type ON $tableMasterCache(entity_type);',
        );
      },
    );

    _db = db;
    return db;
  }

  // ---------------------------------------------------------------------------
  // OUTBOX WRITE OPERATIONS
  // ---------------------------------------------------------------------------

  /// Resets any operations stuck in 'SYNCING' state back to 'PENDING' upon app start.
  /// Prevents queue deadlocks caused by sudden process termination or OS killing.
  Future<int> recoverStaleOperations() async {
    final db = await database;
    final count = await db.rawUpdate('''
      UPDATE $tableOutbox
      SET status = 'PENDING'
      WHERE status = 'SYNCING'
    ''');
    if (count > 0) {
      debugPrint('[OfflineDB] Recovered $count stale in-flight operations to PENDING.');
    }
    return count;
  }

  /// Compares two payloads to determine if they represent a duplicate rage-click submission.
  bool _isDuplicatePayload(
    Map<String, dynamic> incoming,
    Map<String, dynamic> existing,
    String entityType,
  ) {
    if (incoming['employee_id'] != existing['employee_id']) return false;

    if (entityType == 'visit') {
      return incoming['outlet_id'] == existing['outlet_id'];
    } else if (entityType == 'order') {
      if (incoming['outlet_id'] != existing['outlet_id']) return false;
      final inLines = incoming['order_lines'] as List?;
      final exLines = existing['order_lines'] as List?;
      if (inLines == null || exLines == null) return false;
      return jsonEncode(inLines) == jsonEncode(exLines);
    } else if (entityType == 'attendance') {
      return incoming['action'] == existing['action'];
    }
    return false;
  }

  /// Enqueues a write transaction atomically into SQLite.
  /// Automatically debounces duplicate rage-clicks within recent operations.
  Future<String> enqueueOperation({
    required String entityType,
    required String endpoint,
    required Map<String, dynamic> payload,
    String? parentUuid,
    String? clientUuid,
  }) async {
    final db = await database;

    // 1. Debounce check: Prevent duplicate submissions from rapid multi-tapping
    final recentOps = await db.query(
      tableOutbox,
      where: 'entity_type = ? AND endpoint = ? AND status IN (?, ?)',
      whereArgs: [entityType, endpoint, 'PENDING', 'SYNCING'],
      orderBy: 'id DESC',
      limit: 3,
    );

    for (final recent in recentOps) {
      final recentPayloadStr = recent['payload_json'] as String?;
      if (recentPayloadStr != null) {
        try {
          final recentPayload = jsonDecode(recentPayloadStr) as Map<String, dynamic>;
          if (_isDuplicatePayload(payload, recentPayload, entityType)) {
            final existingUuid = recent['operation_uuid'] as String;
            debugPrint(
              '[OfflineDB] Debounced duplicate rage-click: reusing $existingUuid',
            );
            return existingUuid;
          }
        } catch (_) {}
      }
    }

    final opUuid = clientUuid ?? _uuidGenerator.v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // Attach UUID into payload for backend idempotency
    final enrichedPayload = Map<String, dynamic>.from(payload);
    enrichedPayload['client_uuid'] = opUuid;
    if (parentUuid != null && parentUuid.isNotEmpty) {
      enrichedPayload['parent_uuid'] = parentUuid;
    }

    await db.insert(
      tableOutbox,
      {
        'operation_uuid': opUuid,
        'entity_type': entityType,
        'endpoint': endpoint,
        'payload_json': jsonEncode(enrichedPayload),
        'parent_uuid': parentUuid,
        'created_at': nowIso,
        'status': 'PENDING',
        'retry_count': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Track active visit for seamless order-parent linking
    if (entityType == 'visit' && payload['outlet_id'] != null) {
      await saveMasterData(
        entityKey: 'active_visit_tracking',
        entityType: 'visit_state',
        data: {
          'visit_uuid': opUuid,
          'outlet_id': payload['outlet_id'],
          'timestamp': nowIso,
        },
      );
    } else if (entityType == 'visit_update') {
      await clearMasterData(entityType: 'visit_state');
    }

    debugPrint(
      '[OfflineDB] Enqueued outbox op: $opUuid [$entityType] -> $endpoint',
    );
    return opUuid;
  }

  /// Retrieves the current active visit UUID if one is currently in-progress offline.
  Future<String?> getActiveVisitUuid() async {
    final data = await getMasterData('active_visit_tracking');
    if (data is Map && data['visit_uuid'] != null) {
      return data['visit_uuid'].toString();
    }
    return null;
  }

  /// Retrieves pending operations sorted chronologically (FIFO).
  Future<List<Map<String, dynamic>>> getPendingOperations({
    int limit = 50,
  }) async {
    final db = await database;
    return db.query(
      tableOutbox,
      where: 'status = ?',
      whereArgs: ['PENDING'],
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  /// Updates status and error details of an operation.
  Future<void> updateOperationStatus(
    String operationUuid,
    String status, {
    String? errorCode,
    String? errorMessage,
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await db.rawUpdate(
      '''
      UPDATE $tableOutbox
      SET status = ?,
          retry_count = retry_count + 1,
          error_code = ?,
          error_message = ?,
          last_attempt_at = ?
      WHERE operation_uuid = ?
    ''',
      [status, errorCode, errorMessage, nowIso, operationUuid],
    );
  }

  /// Marks an operation as successfully synced and removes or flags it COMPLETED.
  Future<void> markOperationCompleted(String operationUuid) async {
    final db = await database;
    await db.delete(
      tableOutbox,
      where: 'operation_uuid = ?',
      whereArgs: [operationUuid],
    );
    debugPrint('[OfflineDB] Completed & purged outbox op: $operationUuid');
  }

  /// Quarantines an operation so fatal non-transient errors (e.g. inactive customer)
  /// never block the remainder of the FIFO outbox queue.
  Future<void> markOperationQuarantined(
    String operationUuid, {
    required String reason,
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await db.update(
      tableOutbox,
      {
        'status': 'QUARANTINED',
        'error_code': 'BUSINESS_CONFLICT',
        'error_message': reason,
        'last_attempt_at': nowIso,
      },
      where: 'operation_uuid = ?',
      whereArgs: [operationUuid],
    );
    debugPrint('[OfflineDB] Quarantined outbox op: $operationUuid ($reason)');
  }

  /// Returns count of pending operations awaiting sync.
  Future<int> getPendingCount() async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $tableOutbox WHERE status = ?',
      ['PENDING'],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Returns count of quarantined operations.
  Future<int> getQuarantinedCount() async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $tableOutbox WHERE status = ?',
      ['QUARANTINED'],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // MASTER DATA CACHING OPERATIONS
  // ---------------------------------------------------------------------------

  /// Stores or updates master data in SQLite.
  Future<void> saveMasterData({
    required String entityKey,
    required String entityType,
    required dynamic data,
  }) async {
    try {
      final db = await database;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final dataStr = jsonEncode(data);

      await db.insert(
        tableMasterCache,
        {
          'entity_key': entityKey,
          'entity_type': entityType,
          'data_json': dataStr,
          'updated_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[OfflineDB] Failed saving master data for $entityKey: $e');
    }
  }

  /// Retrieves cached master data by key.
  Future<dynamic> getMasterData(String entityKey) async {
    try {
      final db = await database;
      final rows = await db.query(
        tableMasterCache,
        where: 'entity_key = ?',
        whereArgs: [entityKey],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final dataStr = rows.first['data_json'] as String?;
      if (dataStr == null || dataStr.isEmpty) return null;
      return jsonDecode(dataStr);
    } catch (e) {
      debugPrint('[OfflineDB] Error reading cached master data $entityKey: $e');
      return null;
    }
  }

  /// Purges cached master data by entity type or all.
  Future<void> clearMasterData({String? entityType}) async {
    final db = await database;
    if (entityType != null) {
      await db.delete(
        tableMasterCache,
        where: 'entity_type = ?',
        whereArgs: [entityType],
      );
    } else {
      await db.delete(tableMasterCache);
    }
  }
}
