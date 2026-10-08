import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:secondary_sales/core/services/master_data_sync_service.dart';
import 'package:secondary_sales/core/services/offline_database_helper.dart';
import 'package:secondary_sales/data/api/api_service.dart';

/// Offline Synchronization Engine governing outbox replay, rate-limiting,
/// reconnection jitter, and causal FIFO execution.
class OfflineSyncEngine with WidgetsBindingObserver {
  OfflineSyncEngine._();

  static final OfflineSyncEngine instance = OfflineSyncEngine._();

  final OfflineDatabaseHelper _dbHelper = OfflineDatabaseHelper.instance;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;
  bool _isOnline = true;
  Timer? _jitterTimer;
  Timer? _periodicTimer;

  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;

  /// Initializes connectivity listeners and sync triggers.
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    // Recover any in-flight operations that were killed mid-sync by OS
    _dbHelper.recoverStaleOperations();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
    );
    // Initial check
    _checkInitialConnectivity();

    // 15-minute background periodic sync when online
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (_isOnline && !_isSyncing) {
        debugPrint('[OfflineSyncEngine] 15-minute periodic sync triggered.');
        triggerSync(withJitter: true);
      }
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _jitterTimer?.cancel();
    _periodicTimer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isOnline) {
      debugPrint('[OfflineSyncEngine] App resumed. Triggering outbox sync.');
      triggerSync(withJitter: false);
    }
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);
    if (_isOnline) {
      triggerSync(withJitter: false);
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final hasConnection = !results.contains(ConnectivityResult.none);
    final previousState = _isOnline;
    _isOnline = hasConnection;

    debugPrint(
      '[OfflineSyncEngine] Connectivity state changed: online=$hasConnection',
    );

    // If transitioned from offline to online, apply jitter before syncing
    if (!previousState && hasConnection) {
      triggerSync(withJitter: true);
    }
  }

  /// Triggers outbox synchronization.
  /// [withJitter]: Adds a 3-18 second randomized delay to prevent thundering herd
  /// DDoS on Odoo Nginx reverse proxies when field network restores.
  void triggerSync({bool withJitter = true}) {
    if (_isSyncing) {
      debugPrint('[OfflineSyncEngine] Sync already in progress, skipping.');
      return;
    }

    _jitterTimer?.cancel();

    if (withJitter) {
      final jitterSeconds = Random().nextInt(15) + 3; // 3 to 18 seconds
      debugPrint(
        '[OfflineSyncEngine] Network restored. Applying jitter: syncing in ${jitterSeconds}s...',
      );
      _jitterTimer = Timer(Duration(seconds: jitterSeconds), () {
        _processOutboxQueue();
      });
    } else {
      _processOutboxQueue();
    }
  }

  /// Direct execution of outbox queue processing (used by MasterDataSyncService).
  Future<void> processOutboxQueueDirect() async {
    await _processOutboxQueue();
  }

  /// Core worker loop that drains the SQLite outbox in causal FIFO order.
  Future<void> _processOutboxQueue() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    debugPrint('[OfflineSyncEngine] Starting outbox replay pass...');

    try {
      final pendingOps = await _dbHelper.getPendingOperations(limit: 50);
      if (pendingOps.isEmpty) {
        debugPrint('[OfflineSyncEngine] No pending operations in outbox.');
        _isSyncing = false;
        unawaited(MasterDataSyncService.instance.triggerDailySync());
        return;
      }

      debugPrint(
        '[OfflineSyncEngine] Processing ${pendingOps.length} pending operations...',
      );

      for (final op in pendingOps) {
        if (!_isOnline) {
          debugPrint('[OfflineSyncEngine] Network lost during sync. Pausing.');
          break;
        }

        final opUuid = op['operation_uuid'] as String;
        final endpoint = op['endpoint'] as String;
        final payloadJsonStr = op['payload_json'] as String;
        final payload = jsonDecode(payloadJsonStr) as Map<String, dynamic>;

        // Rate Limiter: 500ms delay between requests (max 2 req/s)
        await Future.delayed(const Duration(milliseconds: 500));

        final retries = op['retry_count'] is int ? op['retry_count'] as int : 0;
        final entityType = op['entity_type']?.toString() ?? '';
        final success = await _dispatchOperation(
          opUuid,
          endpoint,
          payload,
          entityType: entityType,
          currentRetries: retries,
        );
        if (!success) {
          // If a transient failure occurred (network drop / server down),
          // stop current sync cycle to avoid hammering the server.
          break;
        }
      }
    } catch (e) {
      debugPrint('[OfflineSyncEngine] Error in sync worker loop: $e');
    } finally {
      _isSyncing = false;
      debugPrint('[OfflineSyncEngine] Outbox replay pass finished.');
      final remaining = await _dbHelper.getPendingCount();
      if (remaining == 0 && _isOnline) {
        unawaited(MasterDataSyncService.instance.triggerDailySync());
      }
    }
  }

  static const int kMaxOutboxRetries = 5;

  /// Dispatches a single operation directly via raw network call.
  /// Returns `true` if operation was processed (success or quarantined),
  /// or `false` if transient error occurred and sync loop should pause.
  Future<bool> _dispatchOperation(
    String opUuid,
    String endpoint,
    Map<String, dynamic> payload, {
    String entityType = '',
    int currentRetries = 0,
  }) async {
    await _dbHelper.updateOperationStatus(opUuid, 'SYNCING');

    try {
      // Direct raw execution without triggering offline capture interception.
      // Clean internal routing metadata (e.g. _temp_outlet_id) before transmission.
      final networkPayload = Map<String, dynamic>.from(payload)..remove('_temp_outlet_id');
      final response = await ApiService.instance.executeRawPost(
        endpoint,
        networkPayload,
      );

      final respSuccess = response['success'] == true;
      final errorMsg =
          response['message']?.toString() ?? 'Unknown server rejection';
      final lowerMsg = errorMsg.toLowerCase();

      // Idempotency: If server returns success OR an idempotent state confirmation
      // (e.g. rep already logged in/out, outlet already checked in, duplicate record exists),
      // treat the operation as completed rather than stalling the queue.
      final isIdempotentSuccess = lowerMsg.contains('already logged in') ||
          lowerMsg.contains('already logged out') ||
          lowerMsg.contains('already signed in') ||
          lowerMsg.contains('already signed out') ||
          lowerMsg.contains('already checked in') ||
          lowerMsg.contains('already synced') ||
          lowerMsg.contains('already exists') ||
          lowerMsg.contains('duplicate');

      final isSuccess = respSuccess || isIdempotentSuccess;

      if (isSuccess) {
        // If this operation returned a server-assigned ID (e.g. visit create returned data.id),
        // cascade and patch any pending child operations in the outbox queue.
        final respData = response['data'];
        if (respData is Map) {
          final serverId = int.tryParse(respData['id']?.toString() ?? respData['outlet_id']?.toString() ?? '');
          if (serverId != null && serverId > 0) {
            if (entityType == 'visit') {
              await _dbHelper.patchChildVisitId(opUuid, serverId);
            } else if (entityType == 'outlet') {
              final tempId = payload['_temp_outlet_id'] is int
                  ? payload['_temp_outlet_id'] as int
                  : int.tryParse(payload['_temp_outlet_id']?.toString() ?? '');
              if (tempId != null && tempId > 0) {
                await _dbHelper.patchOutletId(tempId, serverId);
              }
            }
          }
        }

        await _dbHelper.markOperationCompleted(opUuid);
        debugPrint(
          '[OfflineSyncEngine] Operation $opUuid synced successfully'
          '${isIdempotentSuccess ? ' (idempotent duplicate detected)' : ''}.',
        );
        return true;
      } else {
        final isFatalBusinessError = _isNonTransientError(errorMsg);

        if (isFatalBusinessError || currentRetries >= kMaxOutboxRetries) {
          // Non-transient business conflict or retry threshold exceeded -> quarantine so queue doesn't stall
          final reason = currentRetries >= kMaxOutboxRetries
              ? 'Exceeded max retries ($kMaxOutboxRetries). Error: $errorMsg'
              : errorMsg;
          await _dbHelper.markOperationQuarantined(opUuid, reason: reason);
          debugPrint(
            '[OfflineSyncEngine] Quarantined op $opUuid: $reason',
          );
          return true; // continue next item
        } else {
          // Transient error -> leave PENDING and pause sync loop
          await _dbHelper.updateOperationStatus(
            opUuid,
            'PENDING',
            errorMessage: errorMsg,
          );
          return false;
        }
      }
    } catch (e) {
      final errStr = e.toString();
      debugPrint(
        '[OfflineSyncEngine] Network/server exception on $opUuid: $errStr',
      );

      if (_isNonTransientError(errStr) || currentRetries >= kMaxOutboxRetries) {
        final reason = currentRetries >= kMaxOutboxRetries
            ? 'Exceeded max retries ($kMaxOutboxRetries). Error: $errStr'
            : errStr;
        await _dbHelper.markOperationQuarantined(opUuid, reason: reason);
        return true; // continue next item
      } else {
        // Transient network error (timeout, socket exception, 502/503)
        await _dbHelper.updateOperationStatus(
          opUuid,
          'PENDING',
          errorMessage: errStr,
        );
        return false; // pause sync pass
      }
    }
  }

  /// Determines if an error is a permanent business validation failure
  /// (e.g. inactive partner, invalid customer, duplicate constraint) rather
  /// than a temporary connectivity or gateway issue.
  bool _isNonTransientError(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('socket') ||
        lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('handshake') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('504') ||
        lower.contains('token expired')) {
      return false; // Transient
    }

    if (lower.contains('inactive') ||
        lower.contains('does not exist') ||
        lower.contains('archived') ||
        lower.contains('validation') ||
        lower.contains('constraint') ||
        lower.contains('not found') ||
        lower.contains('forbidden') ||
        lower.contains('credit limit') ||
        lower.contains('insufficient stock') ||
        lower.contains('locked') ||
        lower.contains('permission') ||
        lower.contains('unauthorized')) {
      return true; // Permanent business conflict
    }

    return false;
  }
}
