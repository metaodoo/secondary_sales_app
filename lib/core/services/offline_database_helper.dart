import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:secondary_sales/data/api/api_service.dart';
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
  static const int _dbVersion = 4;

  static const String tableOutbox = 'outbox_operations';
  static const String tableMasterCache = 'cached_master_data';

  // Master Data Relational Tables (v2)
  static const String tableDistributors = 'local_distributors';
  static const String tableRoutes = 'local_routes';
  static const String tableOutlets = 'local_outlets';
  static const String tableProductsStock = 'local_products_stock';
  static const String tableDistributorStocks = 'local_distributor_stocks';
  static const String tableVans = 'local_vans';
  static const String tableReferenceMetadata = 'local_reference_metadata';

  // Caching & Domain Alignment Tables (v4 - MF-40, MF-52, MF-56, MF-57)
  static const String tableSecondaryOrdersCache = 'local_secondary_orders_cache';
  static const String tableMtSessionAudits = 'local_mt_session_stock_audits';
  static const String tableMtJourneyPlans = 'local_mt_journey_plans';

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
        try {
          await db.rawQuery('PRAGMA journal_mode = WAL');
          await db.rawQuery('PRAGMA busy_timeout = 5000');
          await db.rawQuery('PRAGMA synchronous = NORMAL');
        } catch (_) {}
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
            employee_id INTEGER NOT NULL DEFAULT 0,
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
        await db.execute(
          'CREATE INDEX idx_outbox_emp ON $tableOutbox(employee_id, status);',
        );

        // 2. Inbound Document Master Data Cache
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

        // 3. Relational Master Tables (v2, v3, & v4)
        await _createV2Tables(db);
        await _upgradeToV3(db);
        await _upgradeToV4(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createV2Tables(db);
        }
        if (oldVersion < 3) {
          await _upgradeToV3(db);
        }
        if (oldVersion < 4) {
          await _upgradeToV4(db);
        }
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
    if (entityType == 'order') {
      enrichedPayload['client_order_uuid'] = opUuid;
    }
    if (parentUuid != null && parentUuid.isNotEmpty) {
      enrichedPayload['parent_uuid'] = parentUuid;
    }

    int empId = 0;
    if (payload['employee_id'] is int) {
      empId = payload['employee_id'] as int;
    } else if (payload['employee_id'] != null) {
      empId = int.tryParse(payload['employee_id'].toString()) ?? 0;
    }
    if (empId == 0) {
      empId = ApiService.instance.activeEmployeeId ?? 0;
    }

    await db.insert(
      tableOutbox,
      {
        'operation_uuid': opUuid,
        'entity_type': entityType,
        'endpoint': endpoint,
        'payload_json': jsonEncode(enrichedPayload),
        'parent_uuid': parentUuid,
        'employee_id': empId,
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
    } else if (entityType == 'attendance') {
      final action = payload['action']?.toString() ?? 'check_in';
      await saveMasterData(
        entityKey: 'active_attendance_state',
        entityType: 'attendance_state',
        data: {
          'action': action,
          'is_checked_in': action == 'check_in',
          'timestamp': nowIso,
        },
      );
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
    int? employeeId,
  }) async {
    final db = await database;
    if (employeeId != null && employeeId > 0) {
      return db.query(
        tableOutbox,
        where: 'status = ? AND employee_id = ?',
        whereArgs: ['PENDING', employeeId],
        orderBy: 'id ASC',
        limit: limit,
      );
    }
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

  /// When a parent visit syncs and receives a server-assigned visit ID,
  /// this method cascades and patches all pending child operations (e.g. secondary orders)
  /// that reference this parent_uuid, replacing their synthetic visit_id with the real serverVisitId.
  Future<void> patchChildVisitId(String parentUuid, int serverVisitId) async {
    final db = await database;
    final children = await db.query(
      tableOutbox,
      where: 'parent_uuid = ?',
      whereArgs: [parentUuid],
    );

    for (final child in children) {
      final childUuid = child['operation_uuid'] as String;
      final payloadJsonStr = child['payload_json'] as String;
      try {
        final payload = jsonDecode(payloadJsonStr) as Map<String, dynamic>;
        payload['visit_id'] = serverVisitId;
        await db.update(
          tableOutbox,
          {'payload_json': jsonEncode(payload)},
          where: 'operation_uuid = ?',
          whereArgs: [childUuid],
        );
        debugPrint(
          '[OfflineDB] Patched child op $childUuid with real server visit_id: $serverVisitId',
        );
      } catch (e) {
        debugPrint('[OfflineDB] Error patching child payload for $childUuid: $e');
      }
    }
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
      if (rows.isNotEmpty) {
        final dataStr = rows.first['data_json'] as String?;
        if (dataStr != null && dataStr.isNotEmpty) {
          return jsonDecode(dataStr);
        }
      }

      // Relational tables fallback bridge (v2/v3 schema)
      if (entityKey.startsWith('routes')) {
        final local = await getLocalRoutes();
        if (local.isNotEmpty) return local;
      } else if (entityKey == 'catalog_products' || entityKey.startsWith('products')) {
        final local = await getLocalProducts();
        if (local.isNotEmpty) return local;
      } else if (entityKey.startsWith('contacts_route_')) {
        final suffix = entityKey.replaceFirst('contacts_route_', '');
        final rId = int.tryParse(suffix);
        final local = await getLocalOutlets(routeId: rId);
        if (local.isNotEmpty) return local;
      } else if (entityKey == 'distributors') {
        final local = await getLocalDistributors();
        if (local.isNotEmpty) return local;
      } else if (entityKey == 'visit_reasons') {
        final local = await getReferenceMetadata('visit_reasons');
        if (local != null) return local;
      }

      return null;
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
      await db.delete(tableDistributors);
      await db.delete(tableRoutes);
      await db.delete(tableOutlets);
      await db.delete(tableVans);
      await db.delete(tableProductsStock);
      await db.delete(tableDistributorStocks);
      await db.delete(tableReferenceMetadata);
    }
  }

  /// Retrieves all outbox operations optionally filtered by status.
  Future<List<Map<String, dynamic>>> getAllOutboxOperations({
    String? status,
  }) async {
    final db = await database;
    if (status != null && status.isNotEmpty) {
      return db.query(
        tableOutbox,
        where: 'status = ?',
        whereArgs: [status],
        orderBy: 'id DESC',
      );
    }
    return db.query(tableOutbox, orderBy: 'id DESC');
  }

  /// Retries a quarantined or failed operation by marking it PENDING and resetting retries.
  Future<void> retryQuarantinedOperation(String operationUuid) async {
    final db = await database;
    await db.update(
      tableOutbox,
      {
        'status': 'PENDING',
        'retry_count': 0,
        'error_code': null,
        'error_message': null,
      },
      where: 'operation_uuid = ?',
      whereArgs: [operationUuid],
    );
  }

  /// Deletes a specific outbox operation permanently.
  Future<void> deleteOutboxOperation(String operationUuid) async {
    final db = await database;
    await db.delete(
      tableOutbox,
      where: 'operation_uuid = ?',
      whereArgs: [operationUuid],
    );
  }

  /// Retrieves all cached master data metadata entries, including relational tables and legacy cache.
  Future<List<Map<String, dynamic>>> getAllMasterData() async {
    final db = await database;
    final List<Map<String, dynamic>> results = [];

    // 1. Relational Outlets
    final outlets = await getLocalOutlets();
    if (outlets.isNotEmpty) {
      final latest = await db.query(tableOutlets, columns: ['updated_at'], orderBy: 'updated_at DESC', limit: 1);
      results.add({
        'entity_key': 'outlets',
        'entity_type': 'Outlets',
        'updated_at': latest.isNotEmpty ? latest.first['updated_at'] : DateTime.now().toIso8601String(),
        'data_json': jsonEncode(outlets),
      });
    }

    // 2. Relational Routes
    final routes = await getLocalRoutes();
    if (routes.isNotEmpty) {
      final latest = await db.query(tableRoutes, columns: ['updated_at'], orderBy: 'updated_at DESC', limit: 1);
      results.add({
        'entity_key': 'routes',
        'entity_type': 'Routes & Beats',
        'updated_at': latest.isNotEmpty ? latest.first['updated_at'] : DateTime.now().toIso8601String(),
        'data_json': jsonEncode(routes),
      });
    }

    // 3. Relational Products
    final products = await getLocalProducts();
    if (products.isNotEmpty) {
      final latest = await db.query(tableProductsStock, columns: ['updated_at'], orderBy: 'updated_at DESC', limit: 1);
      results.add({
        'entity_key': 'products',
        'entity_type': 'Products & Catalog',
        'updated_at': latest.isNotEmpty ? latest.first['updated_at'] : DateTime.now().toIso8601String(),
        'data_json': jsonEncode(products),
      });
    }

    // 4. Relational Distributors
    final distributors = await getLocalDistributors();
    if (distributors.isNotEmpty) {
      final latest = await db.query(tableDistributors, columns: ['updated_at'], orderBy: 'updated_at DESC', limit: 1);
      results.add({
        'entity_key': 'distributors',
        'entity_type': 'Distributors',
        'updated_at': latest.isNotEmpty ? latest.first['updated_at'] : DateTime.now().toIso8601String(),
        'data_json': jsonEncode(distributors),
      });
    }

    // 5. Relational Distributor Stocks
    final distStocks = await db.query(tableDistributorStocks, limit: 500);
    if (distStocks.isNotEmpty) {
      final latest = await db.query(tableDistributorStocks, columns: ['updated_at'], orderBy: 'updated_at DESC', limit: 1);
      results.add({
        'entity_key': 'distributor_stocks',
        'entity_type': 'Distributor Warehouse Stock',
        'updated_at': latest.isNotEmpty ? latest.first['updated_at'] : DateTime.now().toIso8601String(),
        'data_json': jsonEncode(distStocks),
      });
    }

    // 6. Relational Vans
    final vans = await getLocalVans();
    if (vans.isNotEmpty) {
      final latest = await db.query(tableVans, columns: ['updated_at'], orderBy: 'updated_at DESC', limit: 1);
      results.add({
        'entity_key': 'vans',
        'entity_type': 'Delivery Vans',
        'updated_at': latest.isNotEmpty ? latest.first['updated_at'] : DateTime.now().toIso8601String(),
        'data_json': jsonEncode(vans),
      });
    }

    // 7. Reference Metadata
    final refMeta = await db.query(tableReferenceMetadata);
    if (refMeta.isNotEmpty) {
      final latest = await db.query(tableReferenceMetadata, columns: ['updated_at'], orderBy: 'updated_at DESC', limit: 1);
      results.add({
        'entity_key': 'visit_reasons',
        'entity_type': 'Reference Metadata',
        'updated_at': latest.isNotEmpty ? latest.first['updated_at'] : DateTime.now().toIso8601String(),
        'data_json': jsonEncode(refMeta),
      });
    }

    // Legacy tableMasterCache entries
    final legacy = await db.query(
      tableMasterCache,
      columns: ['entity_key', 'entity_type', 'updated_at', 'data_json'],
      orderBy: 'updated_at DESC',
    );
    results.addAll(legacy);

    return results;
  }

  /// Deletes a specific cached master data key.
  Future<void> deleteMasterDataKey(String entityKey) async {
    final db = await database;
    if (entityKey == 'outlets') {
      await db.delete(tableOutlets);
    } else if (entityKey == 'routes') {
      await db.delete(tableRoutes);
    } else if (entityKey == 'products') {
      await db.delete(tableProductsStock);
    } else if (entityKey == 'distributors') {
      await db.delete(tableDistributors);
    } else if (entityKey == 'distributor_stocks') {
      await db.delete(tableDistributorStocks);
    } else if (entityKey == 'vans') {
      await db.delete(tableVans);
    } else if (entityKey == 'visit_reasons') {
      await db.delete(tableReferenceMetadata);
    }
    await db.delete(
      tableMasterCache,
      where: 'entity_key = ?',
      whereArgs: [entityKey],
    );
  }

  // ---------------------------------------------------------------------------
  // V2 MASTER DATA RELATIONAL TABLES SCHEMA & OPERATIONS
  // ---------------------------------------------------------------------------

  static Future<void> _createV2Tables(Database db) async {
    // 1. Local Distributors
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableDistributors (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        mobile TEXT,
        warehouse_id INTEGER,
        warehouse_name TEXT,
        updated_at TEXT NOT NULL
      );
    ''');

    // 2. Local Routes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableRoutes (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        distributor_id INTEGER NOT NULL,
        outlet_count INTEGER DEFAULT 0,
        sequence INTEGER DEFAULT 10,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_routes_dist ON $tableRoutes(distributor_id);',
    );

    // 3. Local Outlets
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableOutlets (
        id INTEGER PRIMARY KEY,
        route_id INTEGER NOT NULL,
        distributor_id INTEGER,
        name TEXT NOT NULL,
        code TEXT,
        owner_name TEXT,
        phone TEXT,
        street TEXT,
        latitude REAL,
        longitude REAL,
        radius_meters REAL DEFAULT 150.0,
        sequence INTEGER DEFAULT 10,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_outlets_route ON $tableOutlets(route_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_outlets_dist ON $tableOutlets(distributor_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_outlets_name ON $tableOutlets(name);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_outlets_coords ON $tableOutlets(latitude, longitude);',
    );

    // 4. Local Products & Van Stock
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableProductsStock (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        default_code TEXT,
        barcode TEXT,
        unit_price REAL NOT NULL DEFAULT 0.0,
        uom_name TEXT,
        category_id INTEGER,
        category_name TEXT,
        van_stock REAL NOT NULL DEFAULT 0.0,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_code ON $tableProductsStock(default_code);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_cat ON $tableProductsStock(category_id);',
    );

    // 5. Local Distributor Stocks
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableDistributorStocks (
        distributor_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        stock_qty REAL NOT NULL DEFAULT 0.0,
        nearest_expiry TEXT,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (distributor_id, product_id)
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dist_stock_d ON $tableDistributorStocks(distributor_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dist_stock_p ON $tableDistributorStocks(product_id);',
    );

    // 6. Local Vans
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableVans (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        employee_id INTEGER NOT NULL,
        distributor_id INTEGER,
        updated_at TEXT NOT NULL
      );
    ''');

    // 7. Local Reference Metadata
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableReferenceMetadata (
        key TEXT PRIMARY KEY,
        group_name TEXT NOT NULL,
        data_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ref_group ON $tableReferenceMetadata(group_name);',
    );
  }

  Future<void> _upgradeToV3(Database db) async {
    try {
      await db.execute('ALTER TABLE $tableOutbox ADD COLUMN employee_id INTEGER NOT NULL DEFAULT 0;');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_outbox_emp ON $tableOutbox(employee_id, status);');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE $tableOutlets ADD COLUMN distributor_id INTEGER;');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_outlets_dist ON $tableOutlets(distributor_id);');
    } catch (_) {}
  }

  Future<void> _upgradeToV4(Database db) async {
    // 1. Secondary Orders 30-Day Cache (MF-40)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSecondaryOrdersCache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        client_order_uuid TEXT UNIQUE,
        name TEXT NOT NULL,
        partner_id INTEGER NOT NULL,
        partner_name TEXT,
        distributor_id INTEGER,
        date_order TEXT NOT NULL,
        amount_total REAL NOT NULL DEFAULT 0.0,
        state TEXT NOT NULL DEFAULT 'draft',
        sync_status TEXT NOT NULL DEFAULT 'SYNCED',
        sale_type TEXT DEFAULT 'secondary',
        business_type TEXT DEFAULT 'gt',
        lines_json TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sec_orders_partner ON $tableSecondaryOrdersCache(partner_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sec_orders_date ON $tableSecondaryOrdersCache(date_order);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sec_orders_dist ON $tableSecondaryOrdersCache(distributor_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sec_orders_status ON $tableSecondaryOrdersCache(sync_status);');

    // 2. MT Stock Audits Session Cache (MF-56, MF-57)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMtSessionAudits (
        id TEXT PRIMARY KEY,
        outlet_id INTEGER NOT NULL,
        outlet_name TEXT,
        type TEXT NOT NULL DEFAULT 'opening_stock',
        type_label TEXT,
        state TEXT NOT NULL DEFAULT 'draft',
        date TEXT NOT NULL,
        visit_id INTEGER,
        notes TEXT,
        total_lines INTEGER DEFAULT 0,
        total_stock_count REAL DEFAULT 0.0,
        lines_json TEXT,
        created_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mt_audit_outlet ON $tableMtSessionAudits(outlet_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mt_audit_created ON $tableMtSessionAudits(created_at);');

    // 3. MT Journey Plans & Outlets (MF-52)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMtJourneyPlans (
        outlet_id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        ss_code TEXT,
        owner_name TEXT,
        phone TEXT,
        street TEXT,
        latitude REAL,
        longitude REAL,
        radius_meters REAL DEFAULT 150.0,
        pjp_id INTEGER,
        planned_date TEXT,
        sequence INTEGER DEFAULT 10,
        requires_justification INTEGER DEFAULT 0,
        raw_json TEXT,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mt_jp_pjp ON $tableMtJourneyPlans(pjp_id);');
  }

  /// Runs an atomic batch transaction across SQLite tables.
  Future<T> runInTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }

  // --- DISTRIBUTORS ---

  Future<void> saveLocalDistributors(
    List<Map<String, dynamic>> distributors, {
    Transaction? txn,
  }) async {
    final executor = txn ?? await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    for (final d in distributors) {
      final id = d['id'] is int ? d['id'] as int : int.tryParse(d['id'].toString()) ?? 0;
      if (id <= 0) continue;

      await executor.insert(
        tableDistributors,
        {
          'id': id,
          'name': d['name']?.toString() ?? '',
          'phone': d['phone']?.toString(),
          'mobile': d['mobile']?.toString(),
          'warehouse_id': d['warehouse_id'] is int ? d['warehouse_id'] : null,
          'warehouse_name': d['warehouse_name']?.toString(),
          'updated_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getLocalDistributors() async {
    final db = await database;
    return db.query(tableDistributors, orderBy: 'name ASC');
  }

  Future<Map<String, dynamic>?> getLocalDistributorById(int distributorId) async {
    final db = await database;
    final rows = await db.query(
      tableDistributors,
      where: 'id = ?',
      whereArgs: [distributorId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  // --- ROUTES ---

  Future<void> saveLocalRoutes(
    List<Map<String, dynamic>> routes, {
    Transaction? txn,
  }) async {
    final executor = txn ?? await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    for (final r in routes) {
      final id = r['id'] is int ? r['id'] as int : int.tryParse(r['id'].toString()) ?? 0;
      if (id <= 0) continue;

      int distId = 0;
      if (r['distributor'] is Map && r['distributor']['id'] != null) {
        distId = int.tryParse(r['distributor']['id'].toString()) ?? 0;
      } else if (r['distributor_id'] != null) {
        distId = int.tryParse(r['distributor_id'].toString()) ?? 0;
      }

      await executor.insert(
        tableRoutes,
        {
          'id': id,
          'name': r['name']?.toString() ?? '',
          'distributor_id': distId,
          'outlet_count': r['outlet_count'] is int ? r['outlet_count'] : 0,
          'sequence': r['sequence'] is int ? r['sequence'] : 10,
          'updated_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getLocalRoutes({int? distributorId}) async {
    final db = await database;
    if (distributorId != null && distributorId > 0) {
      return db.query(
        tableRoutes,
        where: 'distributor_id = ?',
        whereArgs: [distributorId],
        orderBy: 'sequence ASC, name ASC',
      );
    }
    return db.query(tableRoutes, orderBy: 'sequence ASC, name ASC');
  }

  Future<Map<String, dynamic>?> getLocalRouteById(int routeId) async {
    final db = await database;
    final rows = await db.query(
      tableRoutes,
      where: 'id = ?',
      whereArgs: [routeId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  // --- OUTLETS ---

  Future<void> saveLocalOutlets(
    List<Map<String, dynamic>> outlets, {
    required int routeId,
    int? distributorId,
    Transaction? txn,
  }) async {
    final executor = txn ?? await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    for (final o in outlets) {
      final id = o['id'] is int ? o['id'] as int : int.tryParse(o['id'].toString()) ?? 0;
      if (id <= 0) continue;

      int? distId = distributorId;
      if (distId == null && o['distributor_id'] != null) {
        distId = o['distributor_id'] is int
            ? o['distributor_id'] as int
            : int.tryParse(o['distributor_id'].toString());
      }
      if (distId == null && o['distributor'] is Map) {
        distId = int.tryParse(o['distributor']['id']?.toString() ?? '');
      }

      await executor.insert(
        tableOutlets,
        {
          'id': id,
          'route_id': routeId,
          'distributor_id': distId,
          'name': o['name']?.toString() ?? '',
          'code': o['code']?.toString() ?? o['ss_code']?.toString(),
          'owner_name': o['owner_name']?.toString(),
          'phone': o['phone']?.toString() ?? o['mobile']?.toString(),
          'street': o['street']?.toString(),
          'latitude': (o['partner_latitude'] as num?)?.toDouble(),
          'longitude': (o['partner_longitude'] as num?)?.toDouble(),
          'radius_meters': (o['outlet_radius'] as num?)?.toDouble() ?? 150.0,
          'sequence': o['sequence'] is int ? o['sequence'] : 10,
          'updated_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getLocalOutlets({
    int? routeId,
    String? search,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (routeId != null && routeId > 0) {
      conditions.add('route_id = ?');
      args.add(routeId);
    }

    if (search != null && search.trim().isNotEmpty) {
      final q = '%${search.trim().toLowerCase()}%';
      conditions.add('(LOWER(name) LIKE ? OR LOWER(code) LIKE ? OR LOWER(owner_name) LIKE ?)');
      args.addAll([q, q, q]);
    }

    final whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    return db.query(
      tableOutlets,
      where: whereClause,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'sequence ASC, name ASC',
    );
  }

  Future<Map<String, dynamic>?> getLocalOutletById(int outletId) async {
    final db = await database;
    final rows = await db.query(
      tableOutlets,
      where: 'id = ?',
      whereArgs: [outletId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<void> deleteLocalOutlet(int outletId) async {
    final db = await database;
    await db.delete(
      tableOutlets,
      where: 'id = ?',
      whereArgs: [outletId],
    );
  }

  /// When an offline-created outlet syncs and receives a server-assigned outlet ID,
  /// this method cascades and patches all pending child operations (e.g. visits, orders)
  /// that reference this temporary fake ID, replacing it with the real serverOutletId.
  Future<void> patchOutletId(int temporaryOutletId, int serverOutletId) async {
    final db = await database;
    // 1. Update pending operations in outbox
    final pending = await db.query(
      tableOutbox,
      where: 'status = ?',
      whereArgs: ['PENDING'],
    );

    for (final op in pending) {
      final opUuid = op['operation_uuid'] as String;
      final payloadJsonStr = op['payload_json'] as String;
      try {
        final payload = jsonDecode(payloadJsonStr) as Map<String, dynamic>;
        bool modified = false;
        if (payload['outlet_id'] == temporaryOutletId ||
            payload['outlet_id']?.toString() == temporaryOutletId.toString()) {
          payload['outlet_id'] = serverOutletId;
          modified = true;
        }
        if (modified) {
          await db.update(
            tableOutbox,
            {'payload_json': jsonEncode(payload)},
            where: 'operation_uuid = ?',
            whereArgs: [opUuid],
          );
          debugPrint('[OfflineDB] Patched outlet_id=$serverOutletId on op $opUuid');
        }
      } catch (e) {
        debugPrint('[OfflineDB] Failed to patch op $opUuid: $e');
      }
    }

    // 2. Update local_outlets table
    await db.rawUpdate('''
      UPDATE $tableOutlets
      SET id = ?
      WHERE id = ?
    ''', [serverOutletId, temporaryOutletId]);
  }

  // --- PRODUCTS & STOCK ---

  Future<void> saveLocalProducts(
    List<Map<String, dynamic>> products, {
    Transaction? txn,
  }) async {
    final executor = txn ?? await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    for (final p in products) {
      final id = p['id'] is int ? p['id'] as int : int.tryParse(p['id'].toString()) ?? 0;
      if (id <= 0) continue;

      int? catId;
      String? catName;
      if (p['category'] is Map) {
        catId = int.tryParse(p['category']['id'].toString());
        catName = p['category']['name']?.toString();
      } else if (p['category_id'] != null) {
        catId = int.tryParse(p['category_id'].toString());
        catName = p['category_name']?.toString();
      }

      final vanStock = (p['qty_available'] as num?)?.toDouble() ??
          (p['stock'] as num?)?.toDouble() ??
          (p['van_stock'] as num?)?.toDouble() ??
          0.0;

      await executor.insert(
        tableProductsStock,
        {
          'id': id,
          'name': p['name']?.toString() ?? '',
          'default_code': p['default_code']?.toString(),
          'barcode': p['barcode']?.toString(),
          'unit_price': (p['list_price'] as num?)?.toDouble() ??
              (p['price'] as num?)?.toDouble() ??
              0.0,
          'uom_name': p['uom_name']?.toString() ?? 'Unit',
          'category_id': catId,
          'category_name': catName,
          'van_stock': vanStock,
          'updated_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getLocalProducts({
    int? categoryId,
    String? search,
    bool inStockOnly = false,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (categoryId != null && categoryId > 0) {
      conditions.add('category_id = ?');
      args.add(categoryId);
    }

    if (search != null && search.trim().isNotEmpty) {
      final q = '%${search.trim().toLowerCase()}%';
      conditions.add('(LOWER(name) LIKE ? OR LOWER(default_code) LIKE ? OR LOWER(barcode) LIKE ?)');
      args.addAll([q, q, q]);
    }

    if (inStockOnly) {
      conditions.add('(van_stock > 0 OR id IN (SELECT product_id FROM $tableDistributorStocks WHERE stock_qty > 0))');
    }

    final whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    return db.query(
      tableProductsStock,
      where: whereClause,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'name ASC',
    );
  }

  Future<Map<String, dynamic>?> getLocalProductById(int productId) async {
    final db = await database;
    final rows = await db.query(
      tableProductsStock,
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  // --- DISTRIBUTOR STOCKS ---

  Future<void> saveDistributorStocks(
    int distributorId,
    List<Map<String, dynamic>> products, {
    Transaction? txn,
  }) async {
    final executor = txn ?? await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    for (final p in products) {
      final pId = p['id'] is int ? p['id'] as int : int.tryParse(p['id'].toString()) ?? 0;
      if (pId <= 0) continue;

      final distQty = (p['distributor_qty_available'] as num?)?.toDouble() ??
          (p['distributor_stock'] as num?)?.toDouble() ??
          0.0;

      await executor.insert(
        tableDistributorStocks,
        {
          'distributor_id': distributorId,
          'product_id': pId,
          'stock_qty': distQty,
          'nearest_expiry': p['nearest_expiry']?.toString(),
          'updated_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<double> getDistributorStock(int distributorId, int productId) async {
    final db = await database;
    final rows = await db.query(
      tableDistributorStocks,
      columns: ['stock_qty'],
      where: 'distributor_id = ? AND product_id = ?',
      whereArgs: [distributorId, productId],
      limit: 1,
    );
    if (rows.isEmpty) return 0.0;
    return (rows.first['stock_qty'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> updateSingleDistributorStock(
    int distributorId,
    int productId,
    double newQty,
  ) async {
    final db = await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await db.insert(
      tableDistributorStocks,
      {
        'distributor_id': distributorId,
        'product_id': productId,
        'stock_qty': newQty,
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Atomically decrements local stock (van or distributor) upon placing an order offline.
  Future<void> decrementLocalStock({
    required int productId,
    required double quantity,
    int? distributorId,
    bool isVanDelivery = true,
    Transaction? txn,
  }) async {
    final executor = txn ?? await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    if (isVanDelivery) {
      await executor.rawUpdate('''
        UPDATE $tableProductsStock
        SET van_stock = MAX(0.0, van_stock - ?), updated_at = ?
        WHERE id = ?
      ''', [quantity, nowIso, productId]);
    } else if (distributorId != null && distributorId > 0) {
      await executor.rawUpdate('''
        UPDATE $tableDistributorStocks
        SET stock_qty = MAX(0.0, stock_qty - ?), updated_at = ?
        WHERE distributor_id = ? AND product_id = ?
      ''', [quantity, nowIso, distributorId, productId]);
    }
  }

  // --- VANS ---

  Future<void> saveLocalVans(
    List<Map<String, dynamic>> vans, {
    Transaction? txn,
  }) async {
    final executor = txn ?? await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    for (final v in vans) {
      final id = v['id'] is int ? v['id'] as int : int.tryParse(v['id'].toString()) ?? 0;
      if (id <= 0) continue;

      await executor.insert(
        tableVans,
        {
          'id': id,
          'name': v['name']?.toString() ?? '',
          'employee_id': v['assigned_employee_id'] is int ? v['assigned_employee_id'] : 0,
          'distributor_id': v['assigned_distributor_id'] is int ? v['assigned_distributor_id'] : null,
          'updated_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getLocalVans() async {
    final db = await database;
    return db.query(tableVans, orderBy: 'name ASC');
  }

  // --- REFERENCE METADATA ---

  Future<void> saveReferenceMetadata(
    String key,
    String groupName,
    dynamic data, {
    Transaction? txn,
  }) async {
    final executor = txn ?? await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await executor.insert(
      tableReferenceMetadata,
      {
        'key': key,
        'group_name': groupName,
        'data_json': jsonEncode(data),
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<dynamic> getReferenceMetadata(String key) async {
    final db = await database;
    final rows = await db.query(
      tableReferenceMetadata,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final dataStr = rows.first['data_json'] as String?;
    if (dataStr == null || dataStr.isEmpty) return null;
    return jsonDecode(dataStr);
  }

  // ---------------------------------------------------------------------------
  // SECONDARY ORDERS 30-DAY CACHE (MF-40)
  // ---------------------------------------------------------------------------

  Future<void> saveCachedSecondaryOrders(
    List<Map<String, dynamic>> orders, {
    Transaction? txn,
  }) async {
    final executor = txn ?? await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    for (final o in orders) {
      final sId = o['id'] is int ? o['id'] as int : int.tryParse(o['id']?.toString() ?? '') ?? 0;
      if (sId <= 0 && o['name'] == null) continue;

      final hub = o['distributor'] ?? o['customer'];
      final partnerId = hub is Map
          ? (hub['id'] is int ? hub['id'] as int : int.tryParse(hub['id']?.toString() ?? '') ?? 0)
          : (o['partner_id'] is int ? o['partner_id'] as int : int.tryParse(o['partner_id']?.toString() ?? '') ?? 0);
      final partnerName = hub is Map ? (hub['name']?.toString() ?? '') : (o['partner_name']?.toString() ?? '');
      final distId = o['distributor_id'] is int ? o['distributor_id'] as int : int.tryParse(o['distributor_id']?.toString() ?? '') ?? 0;
      final dateOrder = o['date_order']?.toString() ?? nowIso;
      final amountTotal = (o['amount_total'] as num?)?.toDouble() ?? (o['amount'] as num?)?.toDouble() ?? 0.0;
      final state = o['state']?.toString() ?? 'draft';
      final saleType = o['sale_type']?.toString() ?? 'secondary';
      final businessType = o['business_type']?.toString() ?? 'gt';
      final linesJson = o['lines'] != null ? jsonEncode(o['lines']) : (o['lines_json']?.toString());
      final uuid = o['client_order_uuid']?.toString() ?? o['client_uuid']?.toString();

      await executor.insert(
        tableSecondaryOrdersCache,
        {
          if (sId > 0) 'server_id': sId,
          'client_order_uuid': uuid,
          'name': o['name']?.toString() ?? 'SO-$sId',
          'partner_id': partnerId,
          'partner_name': partnerName,
          'distributor_id': distId,
          'date_order': dateOrder,
          'amount_total': amountTotal,
          'state': state,
          'sync_status': 'SYNCED',
          'sale_type': saleType,
          'business_type': businessType,
          'lines_json': linesJson,
          'created_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> saveOptimisticSecondaryOrder({
    required String clientOrderUuid,
    required int outletId,
    required String outletName,
    required int distributorId,
    required double amountTotal,
    required List<dynamic> lines,
    String saleType = 'secondary',
    String businessType = 'gt',
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final nowEpoch = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      tableSecondaryOrdersCache,
      {
        'server_id': null,
        'client_order_uuid': clientOrderUuid,
        'name': 'OFF-$nowEpoch',
        'partner_id': outletId,
        'partner_name': outletName,
        'distributor_id': distributorId,
        'date_order': nowIso,
        'amount_total': amountTotal,
        'state': 'draft',
        'sync_status': 'PENDING',
        'sale_type': saleType,
        'business_type': businessType,
        'lines_json': jsonEncode(lines),
        'created_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCachedSecondaryOrders({
    int? outletId,
    int? distributorId,
    String? search,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? saleType,
    String? businessType,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (outletId != null && outletId > 0) {
      whereClauses.add('partner_id = ?');
      whereArgs.add(outletId);
    }
    if (distributorId != null && distributorId > 0) {
      whereClauses.add('distributor_id = ?');
      whereArgs.add(distributorId);
    }
    if (saleType != null && saleType.isNotEmpty) {
      whereClauses.add('sale_type = ?');
      whereArgs.add(saleType);
    }
    if (businessType != null && businessType.isNotEmpty) {
      whereClauses.add('business_type = ?');
      whereArgs.add(businessType);
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      whereClauses.add('state = ?');
      whereArgs.add(status);
    }
    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(name LIKE ? OR partner_name LIKE ?)');
      whereArgs.add('%${search.trim()}%');
      whereArgs.add('%${search.trim()}%');
    }
    if (dateFrom != null) {
      whereClauses.add('date_order >= ?');
      whereArgs.add(dateFrom.toIso8601String().split('T').first);
    }
    if (dateTo != null) {
      whereClauses.add('date_order <= ?');
      whereArgs.add('${dateTo.toIso8601String().split('T').first}T23:59:59');
    }

    final whereStr = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final rows = await db.query(
      tableSecondaryOrdersCache,
      where: whereStr,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date_order DESC, id DESC',
      limit: limit,
      offset: offset,
    );

    return rows.map((r) {
      List<dynamic> lines = [];
      if (r['lines_json'] != null) {
        try {
          lines = jsonDecode(r['lines_json'] as String) as List<dynamic>;
        } catch (_) {}
      }
      return {
        'id': r['server_id'] ?? r['id'],
        'name': r['name'],
        'date_order': r['date_order'],
        'partner_id': r['partner_id'],
        'partner_name': r['partner_name'],
        'customer': {'id': r['partner_id'], 'name': r['partner_name'] ?? ''},
        'distributor_id': r['distributor_id'],
        'amount_total': r['amount_total'],
        'state': r['state'],
        'sync_status': r['sync_status'],
        'sale_type': r['sale_type'],
        'business_type': r['business_type'],
        'lines': lines,
        'line_count': lines.length,
        'delivery_status': 'no',
        'currency_symbol': '৳',
      };
    }).toList();
  }

  /// Strict 30-day rolling window: Purges any synced orders older than 30 days
  /// to protect device storage and keep SQLite index scans under 2ms.
  Future<int> pruneSecondaryOrdersOlderThan30Days() async {
    final db = await database;
    final count = await db.rawDelete('''
      DELETE FROM $tableSecondaryOrdersCache
      WHERE date_order < datetime('now', '-30 days')
      AND sync_status = 'SYNCED'
    ''');
    if (count > 0) {
      debugPrint('[OfflineDB] Pruned $count historical orders older than 30 days.');
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // MT STOCK AUDITS SESSION CACHE (MF-56, MF-57)
  // ---------------------------------------------------------------------------

  Future<void> saveMtSessionStockAudit(Map<String, dynamic> audit) async {
    final db = await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final auditId = audit['id']?.toString() ?? audit['client_uuid']?.toString() ?? const Uuid().v4();
    final outletId = audit['outlet_id'] is int ? audit['outlet_id'] as int : int.tryParse(audit['outlet_id']?.toString() ?? '') ?? 0;
    final lines = audit['lines'] as List? ?? [];

    await db.insert(
      tableMtSessionAudits,
      {
        'id': auditId,
        'outlet_id': outletId,
        'outlet_name': audit['outlet_name'] ?? audit['outlet']?['name'] ?? '',
        'type': audit['type'] ?? 'opening_stock',
        'type_label': audit['type_label'] ?? audit['type'] ?? '',
        'state': audit['state'] ?? 'draft',
        'date': audit['date'] ?? audit['audit_date'] ?? nowIso,
        'visit_id': audit['visit_id'] is int ? audit['visit_id'] as int : int.tryParse(audit['visit_id']?.toString() ?? ''),
        'notes': audit['notes'] ?? audit['remarks'] ?? '',
        'total_lines': lines.length,
        'total_stock_count': (audit['total_stock_count'] as num?)?.toDouble() ?? 0.0,
        'lines_json': jsonEncode(lines),
        'created_at': nowIso,
        'is_synced': audit['is_synced'] == 1 ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getMtSessionStockAudits({
    int? outletId,
    String? type,
    String? state,
    String? search,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (outletId != null && outletId > 0) {
      whereClauses.add('outlet_id = ?');
      whereArgs.add(outletId);
    }
    if (type != null && type.isNotEmpty && type != 'all') {
      whereClauses.add('type = ?');
      whereArgs.add(type);
    }
    if (state != null && state.isNotEmpty && state != 'all') {
      whereClauses.add('state = ?');
      whereArgs.add(state);
    }
    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(outlet_name LIKE ? OR notes LIKE ?)');
      whereArgs.add('%${search.trim()}%');
      whereArgs.add('%${search.trim()}%');
    }

    final whereStr = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final rows = await db.query(
      tableMtSessionAudits,
      where: whereStr,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
    );

    return rows.map((r) {
      List<dynamic> lines = [];
      if (r['lines_json'] != null) {
        try {
          lines = jsonDecode(r['lines_json'] as String) as List<dynamic>;
        } catch (_) {}
      }
      return {
        'id': int.tryParse(r['id'] as String) ?? (r['id'].hashCode.abs() % 1000000),
        'name': 'AUDIT-${r['id']}',
        'type': r['type'],
        'type_label': r['type_label'],
        'state': r['state'],
        'date': r['date'],
        'outlet_id': r['outlet_id'],
        'outlet': {'id': r['outlet_id'], 'name': r['outlet_name']},
        'visit_id': r['visit_id'],
        'notes': r['notes'],
        'total_lines': r['total_lines'],
        'total_stock_count': r['total_stock_count'],
        'lines': lines,
        'pending_sync': r['is_synced'] == 0,
      };
    }).toList();
  }

  /// Purges session audits older than 24 hours to prevent storage leaks.
  Future<int> pruneOldMtSessionStockAudits() async {
    final db = await database;
    final count = await db.rawDelete('''
      DELETE FROM $tableMtSessionAudits
      WHERE created_at < datetime('now', '-24 hours')
    ''');
    if (count > 0) {
      debugPrint('[OfflineDB] Pruned $count session MT stock audits older than 24 hours.');
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // MT JOURNEY PLANS & OUTLETS (MF-52)
  // ---------------------------------------------------------------------------

  Future<void> saveMtJourneyPlans(
    List<Map<String, dynamic>> outlets, {
    Transaction? txn,
  }) async {
    final executor = txn ?? await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    for (final o in outlets) {
      final id = o['id'] is int ? o['id'] as int : int.tryParse(o['id']?.toString() ?? '') ?? 0;
      if (id <= 0) continue;

      await executor.insert(
        tableMtJourneyPlans,
        {
          'outlet_id': id,
          'name': o['name']?.toString() ?? 'MT Outlet #$id',
          'ss_code': o['ss_code']?.toString() ?? o['code']?.toString() ?? '',
          'owner_name': o['owner_name']?.toString() ?? '',
          'phone': o['phone']?.toString() ?? o['mobile']?.toString() ?? '',
          'street': o['street']?.toString() ?? '',
          'latitude': (o['latitude'] as num?)?.toDouble() ?? (o['partner_latitude'] as num?)?.toDouble() ?? 0.0,
          'longitude': (o['longitude'] as num?)?.toDouble() ?? (o['partner_longitude'] as num?)?.toDouble() ?? 0.0,
          'radius_meters': (o['radius_meters'] as num?)?.toDouble() ?? (o['outlet_radius'] as num?)?.toDouble() ?? 150.0,
          'pjp_id': o['pjp_id'] is int ? o['pjp_id'] as int : int.tryParse(o['pjp_id']?.toString() ?? ''),
          'planned_date': o['planned_date']?.toString(),
          'sequence': (o['sequence'] as num?)?.toInt() ?? 10,
          'requires_justification': o['requires_justification'] == true ? 1 : 0,
          'raw_json': jsonEncode(o),
          'updated_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getMtJourneyPlans({String? searchQuery}) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(name LIKE ? OR ss_code LIKE ? OR street LIKE ?)');
      whereArgs.add('%${searchQuery.trim()}%');
      whereArgs.add('%${searchQuery.trim()}%');
      whereArgs.add('%${searchQuery.trim()}%');
    }

    final whereStr = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final rows = await db.query(
      tableMtJourneyPlans,
      where: whereStr,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'sequence ASC, name ASC',
    );

    return rows.map((r) {
      if (r['raw_json'] != null) {
        try {
          final decoded = jsonDecode(r['raw_json'] as String) as Map<String, dynamic>;
          return decoded;
        } catch (_) {}
      }
      return {
        'id': r['outlet_id'],
        'name': r['name'],
        'ss_code': r['ss_code'],
        'owner_name': r['owner_name'],
        'phone': r['phone'],
        'mobile': r['phone'],
        'street': r['street'],
        'latitude': r['latitude'],
        'longitude': r['longitude'],
        'outlet_radius': r['radius_meters'],
        'pjp_id': r['pjp_id'],
        'planned_date': r['planned_date'],
        'sequence': r['sequence'],
        'requires_justification': r['requires_justification'] == 1,
      };
    }).toList();
  }
}
