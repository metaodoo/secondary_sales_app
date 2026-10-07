import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:secondary_sales/core/services/offline_database_helper.dart';
import 'package:secondary_sales/core/services/offline_sync_engine.dart';
import 'package:secondary_sales/data/api/api_service.dart';

/// Orchestrates proactive daily master data pre-hydration and periodic refresh.
///
/// Implements a strict Two-Phase synchronization pipeline:
/// - Phase 1: Flush outbox completely (FIFO replay to Odoo).
/// - Phase 2: Inbound master data hydration (routes, outlets, van stock,
///   distributor stock) executed atomically in SQLite ONLY after Phase 1 passes.
class MasterDataSyncService with ChangeNotifier {
  MasterDataSyncService._();

  static final MasterDataSyncService instance = MasterDataSyncService._();

  final OfflineDatabaseHelper _dbHelper = OfflineDatabaseHelper.instance;
  final ApiService _apiService = ApiService.instance;

  bool _isSyncing = false;
  String? _syncStatusMessage;
  DateTime? _lastSyncedAt;
  double _syncProgress = 0.0;

  bool get isSyncing => _isSyncing;
  String? get syncStatusMessage => _syncStatusMessage;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  double get syncProgress => _syncProgress;

  /// Triggers the full two-phase daily synchronization pipeline.
  Future<bool> triggerDailySync({bool force = false}) async {
    if (_isSyncing) {
      debugPrint('[MasterDataSyncService] Sync already in progress. Skipping.');
      return false;
    }

    if (!OfflineSyncEngine.instance.isOnline && !force) {
      debugPrint('[MasterDataSyncService] Device is offline. Cannot hydrate from server.');
      return false;
    }

    _isSyncing = true;
    _syncProgress = 0.05;
    _syncStatusMessage = 'Checking pending outbox operations...';
    notifyListeners();

    try {
      // -----------------------------------------------------------------------
      // PHASE 1: OUTBOUND OUTBOX FLUSH
      // -----------------------------------------------------------------------
      final pendingCount = await _dbHelper.getPendingCount();
      if (pendingCount > 0) {
        _syncStatusMessage = 'Flushing $pendingCount pending outbox operations...';
        notifyListeners();

        // Trigger outbox replay without jitter
        await OfflineSyncEngine.instance.processOutboxQueueDirect();

        final remaining = await _dbHelper.getPendingCount();
        if (remaining > 0) {
          debugPrint(
            '[MasterDataSyncService] Phase 1 incomplete: $remaining operations pending. Aborting Phase 2 to protect local data.',
          );
          _syncStatusMessage = '$remaining pending orders could not sync. Master data hydration paused.';
          _isSyncing = false;
          notifyListeners();
          return false;
        }
      }

      _syncProgress = 0.25;
      _syncStatusMessage = 'Phase 1 clear. Hydrating daily master data...';
      notifyListeners();

      // -----------------------------------------------------------------------
      // PHASE 2: INBOUND MASTER DATA HYDRATION (ATOMIC SQL TRANSACTION)
      // -----------------------------------------------------------------------
      final employeeId = _apiService.activeEmployeeId;
      if (employeeId == null || employeeId <= 0) {
        debugPrint('[MasterDataSyncService] No active employee ID. Cannot scope hydration.');
        _isSyncing = false;
        notifyListeners();
        return false;
      }

      // Step 2.1: Fetch assigned distributors
      _syncStatusMessage = 'Fetching assigned distributors...';
      _syncProgress = 0.35;
      notifyListeners();

      List<Map<String, dynamic>> rawDistributors = [];
      try {
        final distRes = await _apiService.executeRawPost('/api/v1/contacts', {
          'customer_type': 'distributor',
          'employee_id': employeeId,
          'page_size': 100,
        });
        if (distRes['success'] == true) {
          final list = distRes['data'] ?? distRes['contacts'] ?? [];
          rawDistributors = List<Map<String, dynamic>>.from(list);
        }
      } catch (e) {
        debugPrint('[MasterDataSyncService] Failed fetching distributors: $e');
      }

      // Step 2.2: Fetch assigned routes
      _syncStatusMessage = 'Fetching assigned routes & beats...';
      _syncProgress = 0.45;
      notifyListeners();

      List<Map<String, dynamic>> rawRoutes = [];
      try {
        final routesRes = await _apiService.executeRawPost('/api/v1/ss/routes', {
          'employee_id': employeeId,
          'page_size': 100,
        });
        if (routesRes['success'] == true) {
          final list = routesRes['data'] ?? [];
          rawRoutes = List<Map<String, dynamic>>.from(list);
        }
      } catch (e) {
        debugPrint('[MasterDataSyncService] Failed fetching routes: $e');
      }

      // Step 2.3: Fetch outlets for each route
      _syncStatusMessage = 'Fetching route outlets...';
      _syncProgress = 0.55;
      notifyListeners();

      final Map<int, List<Map<String, dynamic>>> routeOutletsMap = {};
      for (final r in rawRoutes) {
        final rId = r['id'] is int ? r['id'] as int : int.tryParse(r['id'].toString()) ?? 0;
        if (rId <= 0) continue;

        try {
          final detailRes = await _apiService.executeRawPost('/api/v1/ss/routes/$rId', {
            'employee_id': employeeId,
          });
          if (detailRes['success'] == true && detailRes['data'] is Map) {
            final outlets = detailRes['data']['outlets'] as List? ?? [];
            routeOutletsMap[rId] = List<Map<String, dynamic>>.from(outlets);
          }
        } catch (e) {
          debugPrint('[MasterDataSyncService] Failed fetching outlets for route $rId: $e');
        }
      }

      // Step 2.4: Fetch virtual van locations
      _syncStatusMessage = 'Fetching van locations...';
      _syncProgress = 0.70;
      notifyListeners();

      List<Map<String, dynamic>> rawVans = [];
      try {
        final vansRes = await _apiService.executeRawPost('/api/v1/virtual-locations', {
          'employee_id': employeeId,
          'page_size': 100,
        });
        if (vansRes['success'] == true) {
          final list = vansRes['data'] ?? [];
          rawVans = List<Map<String, dynamic>>.from(list);
        }
      } catch (e) {
        debugPrint('[MasterDataSyncService] Failed fetching vans: $e');
      }

      // Step 2.5: Fetch product catalog and stock per assigned distributor
      _syncStatusMessage = 'Fetching catalog, van stock & distributor stock...';
      _syncProgress = 0.80;
      notifyListeners();

      final List<Map<String, dynamic>> allProducts = [];
      final Map<int, List<Map<String, dynamic>>> distributorStocksMap = {};

      if (rawDistributors.isNotEmpty) {
        for (final dist in rawDistributors) {
          final dId = dist['id'] is int ? dist['id'] as int : int.tryParse(dist['id'].toString()) ?? 0;
          if (dId <= 0) continue;

          try {
            final prodRes = await _apiService.executeRawPost('/api/v1/products', {
              'employee_id': employeeId,
              'sale_type': 'secondary',
              'partner_id': dId,
              'page_size': 250,
            });
            if (prodRes['success'] == true) {
              final list = prodRes['products'] ?? prodRes['data'] ?? [];
              final typedList = List<Map<String, dynamic>>.from(list);
              distributorStocksMap[dId] = typedList;
              if (allProducts.isEmpty) {
                allProducts.addAll(typedList);
              }
            }
          } catch (e) {
            debugPrint('[MasterDataSyncService] Failed fetching products for distributor $dId: $e');
          }
        }
      } else {
        // Fallback product fetch without distributor partner_id
        try {
          final prodRes = await _apiService.executeRawPost('/api/v1/products', {
            'employee_id': employeeId,
            'sale_type': 'secondary',
            'page_size': 250,
          });
          if (prodRes['success'] == true) {
            final list = prodRes['products'] ?? prodRes['data'] ?? [];
            allProducts.addAll(List<Map<String, dynamic>>.from(list));
          }
        } catch (e) {
          debugPrint('[MasterDataSyncService] Fallback product fetch failed: $e');
        }
      }

      // Step 2.6: Fetch reference metadata (visit reasons)
      _syncStatusMessage = 'Fetching operational reference metadata...';
      _syncProgress = 0.90;
      notifyListeners();

      dynamic visitReasonsData;
      try {
        final reasonsRes = await _apiService.executeRawPost('/api/v1/visits/reasons', {});
        if (reasonsRes['success'] == true) {
          visitReasonsData = reasonsRes['data'] ?? reasonsRes['reasons'];
        }
      } catch (_) {}

      // -----------------------------------------------------------------------
      // ATOMIC TRANSACTION WRITE TO SQLITE
      // -----------------------------------------------------------------------
      _syncStatusMessage = 'Saving to local offline database...';
      _syncProgress = 0.95;
      notifyListeners();

      await _dbHelper.runInTransaction((txn) async {
        if (rawDistributors.isNotEmpty) {
          await _dbHelper.saveLocalDistributors(rawDistributors, txn: txn);
        }

        if (rawRoutes.isNotEmpty) {
          await _dbHelper.saveLocalRoutes(rawRoutes, txn: txn);
        }

        for (final entry in routeOutletsMap.entries) {
          await _dbHelper.saveLocalOutlets(
            entry.value,
            routeId: entry.key,
            txn: txn,
          );
        }

        if (rawVans.isNotEmpty) {
          await _dbHelper.saveLocalVans(rawVans, txn: txn);
        }

        if (allProducts.isNotEmpty) {
          await _dbHelper.saveLocalProducts(allProducts, txn: txn);
        }

        for (final entry in distributorStocksMap.entries) {
          await _dbHelper.saveDistributorStocks(
            entry.key,
            entry.value,
            txn: txn,
          );
        }

        if (visitReasonsData != null) {
          await _dbHelper.saveReferenceMetadata(
            'visit_reasons',
            'reasons',
            visitReasonsData,
            txn: txn,
          );
        }
      });

      _lastSyncedAt = DateTime.now();
      _syncProgress = 1.0;
      _syncStatusMessage = 'Daily master data pre-hydrated successfully.';
      debugPrint('[MasterDataSyncService] Master data hydration complete.');
      return true;
    } catch (e, stack) {
      debugPrint('[MasterDataSyncService] Error during hydration: $e\n$stack');
      _syncStatusMessage = 'Sync error: $e';
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
