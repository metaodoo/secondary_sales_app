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

    final totalSw = Stopwatch()..start();
    final employeeId = _apiService.activeEmployeeId;

    debugPrint('╔════════════════════════════════════════════════════════════════════════════════╗');
    debugPrint('║ [LOGIN-CACHE-HYDRATION] Starting Master Data Hydration Pipeline                ║');
    debugPrint('║ Timestamp:   ${DateTime.now().toIso8601String().padRight(49)} ║');
    debugPrint('║ Employee ID: ${employeeId?.toString().padRight(49) ?? "Unknown"} ║');
    debugPrint('║ Mode:        ${(force ? "FORCED / FIRST LOGIN" : "BACKGROUND PERIODIC").padRight(49)} ║');
    debugPrint('╚════════════════════════════════════════════════════════════════════════════════╝');

    _isSyncing = true;
    _syncProgress = 0.05;
    _syncStatusMessage = 'Checking pending outbox operations...';
    notifyListeners();

    try {
      // -----------------------------------------------------------------------
      // PHASE 1: OUTBOUND OUTBOX FLUSH
      // -----------------------------------------------------------------------
      final phase1Sw = Stopwatch()..start();
      final pendingCount = await _dbHelper.getPendingCount();
      debugPrint('[LOGIN-CACHE-HYDRATION] Phase 1 Check: $pendingCount pending outbox operations.');
      if (pendingCount > 0) {
        _syncStatusMessage = 'Flushing $pendingCount pending outbox operations...';
        notifyListeners();

        // Trigger outbox replay without jitter
        await OfflineSyncEngine.instance.processOutboxQueueDirect();

        final remaining = await _dbHelper.getPendingCount();
        if (remaining > 0) {
          debugPrint(
            '[LOGIN-CACHE-HYDRATION] Phase 1 incomplete: $remaining operations pending. Aborting Phase 2 to protect local data.',
          );
          _syncStatusMessage = '$remaining pending orders could not sync. Master data hydration paused.';
          _isSyncing = false;
          notifyListeners();
          return false;
        }
      }
      phase1Sw.stop();
      debugPrint('[LOGIN-CACHE-HYDRATION] Phase 1 Clear: Completed in ${phase1Sw.elapsedMilliseconds}ms.');

      _syncProgress = 0.25;
      _syncStatusMessage = 'Phase 1 clear. Hydrating daily master data...';
      notifyListeners();

      // -----------------------------------------------------------------------
      // PHASE 2: INBOUND MASTER DATA HYDRATION (ATOMIC SQL TRANSACTION)
      // -----------------------------------------------------------------------
      if (employeeId == null || employeeId <= 0) {
        debugPrint('[LOGIN-CACHE-HYDRATION] No active employee ID. Cannot scope hydration.');
        _isSyncing = false;
        notifyListeners();
        return false;
      }

      // Step 2.1: Fetch assigned distributors
      final step21Sw = Stopwatch()..start();
      _syncStatusMessage = 'Fetching assigned distributors...';
      _syncProgress = 0.35;
      notifyListeners();

      List<Map<String, dynamic>> rawDistributors = [];
      try {
        debugPrint('[LOGIN-CACHE-HYDRATION] Step 2.1 -> POST /api/v1/contacts (customer_type: distributor, employee_id: $employeeId)');
        final distRes = await _apiService.executeRawPost('/api/v1/contacts', {
          'customer_type': 'distributor',
          'employee_id': employeeId,
          'page_size': 100,
        });
        step21Sw.stop();
        if (distRes['success'] == true) {
          final list = distRes['data'] ?? distRes['contacts'] ?? [];
          rawDistributors = List<Map<String, dynamic>>.from(list);
          debugPrint(
            '[LOGIN-CACHE-HYDRATION] Step 2.1 Success (${step21Sw.elapsedMilliseconds}ms): Received ${rawDistributors.length} distributors: '
            '${rawDistributors.map((d) => "${d['name']} (ID: ${d['id']})").join(", ")}',
          );
        } else {
          debugPrint('[LOGIN-CACHE-HYDRATION] Step 2.1 Warning: Server response success=false: $distRes');
        }
      } catch (e) {
        step21Sw.stop();
        debugPrint('[LOGIN-CACHE-HYDRATION] Step 2.1 Failed (${step21Sw.elapsedMilliseconds}ms): $e');
      }

      // Step 2.2: Fetch assigned routes
      final step22Sw = Stopwatch()..start();
      _syncStatusMessage = 'Fetching assigned routes & beats...';
      _syncProgress = 0.45;
      notifyListeners();

      List<Map<String, dynamic>> rawRoutes = [];
      try {
        debugPrint('[LOGIN-CACHE-HYDRATION] Step 2.2 -> POST /api/v1/ss/routes (employee_id: $employeeId)');
        final routesRes = await _apiService.executeRawPost('/api/v1/ss/routes', {
          'employee_id': employeeId,
          'page_size': 100,
        });
        step22Sw.stop();
        if (routesRes['success'] == true) {
          final list = routesRes['data'] ?? [];
          rawRoutes = List<Map<String, dynamic>>.from(list);
          debugPrint(
            '[LOGIN-CACHE-HYDRATION] Step 2.2 Success (${step22Sw.elapsedMilliseconds}ms): Received ${rawRoutes.length} routes: '
            '${rawRoutes.map((r) => "${r['name']} (ID: ${r['id']})").join(", ")}',
          );
        } else {
          debugPrint('[LOGIN-CACHE-HYDRATION] Step 2.2 Warning: Server response success=false: $routesRes');
        }
      } catch (e) {
        step22Sw.stop();
        debugPrint('[LOGIN-CACHE-HYDRATION] Step 2.2 Failed (${step22Sw.elapsedMilliseconds}ms): $e');
      }

      // Step 2.3: Fetch outlets for each route
      final step23Sw = Stopwatch()..start();
      _syncStatusMessage = 'Fetching route outlets...';
      _syncProgress = 0.55;
      notifyListeners();

      final Map<int, List<Map<String, dynamic>>> routeOutletsMap = {};
      int totalOutletsCount = 0;
      for (final r in rawRoutes) {
        final rId = r['id'] is int ? r['id'] as int : int.tryParse(r['id'].toString()) ?? 0;
        final rName = r['name']?.toString() ?? 'Route #$rId';
        if (rId <= 0) continue;

        try {
          final detailRes = await _apiService.executeRawPost('/api/v1/ss/routes/$rId', {
            'employee_id': employeeId,
          });
          if (detailRes['success'] == true && detailRes['data'] is Map) {
            final outlets = detailRes['data']['outlets'] as List? ?? [];
            routeOutletsMap[rId] = List<Map<String, dynamic>>.from(outlets);
            totalOutletsCount += outlets.length;
            debugPrint('[LOGIN-CACHE-HYDRATION]   • Route "$rName" (ID: $rId): ${outlets.length} outlets');
          }
        } catch (e) {
          debugPrint('[LOGIN-CACHE-HYDRATION]   • Route "$rName" (ID: $rId) Error: $e');
        }
      }
      step23Sw.stop();
      debugPrint('[LOGIN-CACHE-HYDRATION] Step 2.3 Success (${step23Sw.elapsedMilliseconds}ms): Total $totalOutletsCount outlets across ${routeOutletsMap.length} routes.');

      // Step 2.4: Fetch virtual van locations
      final step24Sw = Stopwatch()..start();
      _syncStatusMessage = 'Fetching van locations...';
      _syncProgress = 0.70;
      notifyListeners();

      List<Map<String, dynamic>> rawVans = [];
      try {
        debugPrint('[LOGIN-CACHE-HYDRATION] Step 2.4 -> POST /api/v1/virtual-locations (employee_id: $employeeId)');
        final vansRes = await _apiService.executeRawPost('/api/v1/virtual-locations', {
          'employee_id': employeeId,
          'page_size': 100,
        });
        step24Sw.stop();
        if (vansRes['success'] == true) {
          final list = vansRes['data'] ?? [];
          rawVans = List<Map<String, dynamic>>.from(list);
          debugPrint(
            '[LOGIN-CACHE-HYDRATION] Step 2.4 Success (${step24Sw.elapsedMilliseconds}ms): Received ${rawVans.length} vans: '
            '${rawVans.map((v) => "${v['name']} (ID: ${v['id']})").join(", ")}',
          );
        } else {
          debugPrint('[LOGIN-CACHE-HYDRATION] Step 2.4 Warning: Server response success=false: $vansRes');
        }
      } catch (e) {
        step24Sw.stop();
        debugPrint('[LOGIN-CACHE-HYDRATION] Step 2.4 Failed (${step24Sw.elapsedMilliseconds}ms): $e');
      }

      // Step 2.5: Fetch product catalog and stock per assigned distributor
      final step25Sw = Stopwatch()..start();
      _syncStatusMessage = 'Fetching catalog, van stock & distributor stock...';
      _syncProgress = 0.80;
      notifyListeners();

      final List<Map<String, dynamic>> allProducts = [];
      final Map<int, List<Map<String, dynamic>>> distributorStocksMap = {};

      if (rawDistributors.isNotEmpty) {
        for (final dist in rawDistributors) {
          final dId = dist['id'] is int ? dist['id'] as int : int.tryParse(dist['id'].toString()) ?? 0;
          final dName = dist['name']?.toString() ?? 'Distributor #$dId';
          if (dId <= 0) continue;

          try {
            debugPrint('[LOGIN-CACHE-HYDRATION] Step 2.5 -> Fetching products for "$dName" (ID: $dId)...');
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
              debugPrint('[LOGIN-CACHE-HYDRATION]   • "$dName" (ID: $dId): ${typedList.length} stock products mapped');
            }
          } catch (e) {
            debugPrint('[LOGIN-CACHE-HYDRATION]   • "$dName" (ID: $dId) Error: $e');
          }
        }
      } else {
        // Fallback product fetch without distributor partner_id
        try {
          debugPrint('[LOGIN-CACHE-HYDRATION] Step 2.5 -> Fallback generic products fetch (no assigned distributors)...');
          final prodRes = await _apiService.executeRawPost('/api/v1/products', {
            'employee_id': employeeId,
            'sale_type': 'secondary',
            'page_size': 250,
          });
          if (prodRes['success'] == true) {
            final list = prodRes['products'] ?? prodRes['data'] ?? [];
            allProducts.addAll(List<Map<String, dynamic>>.from(list));
            debugPrint('[LOGIN-CACHE-HYDRATION]   • Fallback catalog: ${allProducts.length} products');
          }
        } catch (e) {
          debugPrint('[LOGIN-CACHE-HYDRATION] Fallback product fetch failed: $e');
        }
      }
      step25Sw.stop();
      debugPrint('[LOGIN-CACHE-HYDRATION] Step 2.5 Success (${step25Sw.elapsedMilliseconds}ms): Total ${allProducts.length} catalog products.');

      // Step 2.6: Fetch reference metadata (visit reasons)
      final step26Sw = Stopwatch()..start();
      _syncStatusMessage = 'Fetching operational reference metadata...';
      _syncProgress = 0.90;
      notifyListeners();

      dynamic visitReasonsData;
      try {
        final reasonsRes = await _apiService.executeRawPost('/api/v1/visit-reasons', {});
        step26Sw.stop();
        if (reasonsRes['success'] == true) {
          visitReasonsData = reasonsRes['data'] ?? reasonsRes['reasons'];
          debugPrint('[LOGIN-CACHE-HYDRATION] Step 2.6 Success (${step26Sw.elapsedMilliseconds}ms): Reference visit reasons loaded.');
        }
      } catch (e) {
        step26Sw.stop();
        debugPrint('[LOGIN-CACHE-HYDRATION] Step 2.6 Failed (${step26Sw.elapsedMilliseconds}ms): $e');
      }

      // -----------------------------------------------------------------------
      // ATOMIC TRANSACTION WRITE TO SQLITE
      // -----------------------------------------------------------------------
      final step27Sw = Stopwatch()..start();
      _syncStatusMessage = 'Saving to local offline database...';
      _syncProgress = 0.95;
      notifyListeners();

      debugPrint('[LOGIN-CACHE-HYDRATION] Step 2.7: Executing SQLite atomic transaction batch write...');
      await _dbHelper.runInTransaction((txn) async {
        if (rawDistributors.isNotEmpty) {
          await _dbHelper.saveLocalDistributors(rawDistributors, txn: txn);
        }

        if (rawRoutes.isNotEmpty) {
          await _dbHelper.saveLocalRoutes(rawRoutes, txn: txn);
        }

        for (final entry in routeOutletsMap.entries) {
          final rId = entry.key;
          final r = rawRoutes.firstWhere((route) => route['id'] == rId, orElse: () => {});
          int? distId;
          if (r['distributor'] is Map) {
            distId = int.tryParse(r['distributor']['id']?.toString() ?? '');
          } else if (r['distributor_id'] != null) {
            distId = int.tryParse(r['distributor_id'].toString());
          }
          await _dbHelper.saveLocalOutlets(
            entry.value,
            routeId: rId,
            distributorId: distId,
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
      step27Sw.stop();
      debugPrint('[LOGIN-CACHE-HYDRATION] Step 2.7 SQLite Transaction Committed in ${step27Sw.elapsedMilliseconds}ms.');

      totalSw.stop();
      _lastSyncedAt = DateTime.now();
      _syncProgress = 1.0;
      _syncStatusMessage = 'Daily master data pre-hydrated successfully.';

      debugPrint('╔════════════════════════════════════════════════════════════════════════════════╗');
      debugPrint('║ [LOGIN-CACHE-HYDRATION] COMPLETED SUCCESSFULLY IN ${totalSw.elapsedMilliseconds}ms'.padRight(81) + '║');
      debugPrint('╟────────────────────────────────────────────────────────────────────────────────╢');
      debugPrint('║ • Employee ID:            $employeeId'.padRight(81) + '║');
      debugPrint('║ • Distributors Cached:    ${rawDistributors.length}'.padRight(81) + '║');
      debugPrint('║ • Routes Cached:          ${rawRoutes.length}'.padRight(81) + '║');
      debugPrint('║ • Outlets Cached:         $totalOutletsCount'.padRight(81) + '║');
      debugPrint('║ • Vans Cached:            ${rawVans.length}'.padRight(81) + '║');
      debugPrint('║ • Catalog Products:       ${allProducts.length}'.padRight(81) + '║');
      debugPrint('║ • Distributor Stock Maps: ${distributorStocksMap.values.fold(0, (sum, l) => sum + l.length)} quants'.padRight(81) + '║');
      debugPrint('║ • Reference Metadata:     Visit Reasons Cached'.padRight(81) + '║');
      debugPrint('║ • SQLite Batch Duration:  ${step27Sw.elapsedMilliseconds}ms'.padRight(81) + '║');
      debugPrint('╚════════════════════════════════════════════════════════════════════════════════╝');
      return true;
    } catch (e, stack) {
      totalSw.stop();
      debugPrint('╔════════════════════════════════════════════════════════════════════════════════╗');
      debugPrint('║ [LOGIN-CACHE-HYDRATION] FAILED AFTER ${totalSw.elapsedMilliseconds}ms'.padRight(81) + '║');
      debugPrint('╟────────────────────────────────────────────────────────────────────────────────╢');
      debugPrint('║ Error: $e');
      debugPrint('║ Stack: $stack');
      debugPrint('╚════════════════════════════════════════════════════════════════════════════════╝');
      _syncStatusMessage = 'Sync error: $e';
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
