import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secondary_sales/core/services/offline_database_helper.dart';
import 'package:secondary_sales/core/services/offline_sync_engine.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';

/// Screen allowing sales reps and admins to visually inspect and manage:
/// 1. Outbox: Data created while offline (Orders, Visits, Outlets, Returns, Scraps)
/// 2. Cache: Master data cached on-device for offline operation.
class OfflineDataScreen extends StatefulWidget {
  const OfflineDataScreen({super.key});

  @override
  State<OfflineDataScreen> createState() => _OfflineDataScreenState();
}

class _OfflineDataScreenState extends State<OfflineDataScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OfflineDatabaseHelper _dbHelper = OfflineDatabaseHelper.instance;
  final OfflineSyncEngine _syncEngine = OfflineSyncEngine.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _outboxList = [];
  List<Map<String, dynamic>> _masterDataList = [];
  int _pendingCount = 0;
  int _quarantinedCount = 0;
  String _selectedFilter = 'ALL'; // 'ALL', 'PENDING', 'QUARANTINED'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final allOutbox = await _dbHelper.getAllOutboxOperations();
      final allMaster = await _dbHelper.getAllMasterData();
      final pending = await _dbHelper.getPendingCount();
      final quarantined = await _dbHelper.getQuarantinedCount();

      if (!mounted) return;
      setState(() {
        _outboxList = allOutbox;
        _masterDataList = allMaster;
        _pendingCount = pending;
        _quarantinedCount = quarantined;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading offline data: $e')),
      );
    }
  }

  void _triggerSync() {
    final messenger = ScaffoldMessenger.of(context);
    if (!_syncEngine.isOnline) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Cannot sync: Device is currently offline.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _syncEngine.triggerSync(withJitter: false);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Synchronization started in background…'),
        duration: Duration(seconds: 2),
      ),
    );

    // Refresh after a brief delay to show updated status
    Future.delayed(const Duration(seconds: 2), _loadData);
  }

  List<Map<String, dynamic>> get _filteredOutbox {
    if (_selectedFilter == 'ALL') return _outboxList;
    return _outboxList
        .where((op) => op['status'] == _selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _syncEngine.isOnline;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Offline & Sync Center',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Created Offline (Outbox)'),
                  if (_pendingCount > 0 || _quarantinedCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _quarantinedCount > 0
                            ? Colors.red
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pendingCount + _quarantinedCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Cached Master Data'),
                  if (_masterDataList.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.borderSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_masterDataList.length}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status bar overview
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isOnline ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
              child: Row(
                children: [
                  Icon(
                    isOnline ? Icons.wifi : Icons.wifi_off,
                    size: 16,
                    color: isOnline ? const Color(0xFF059669) : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isOnline ? 'Online (Ready to sync)' : 'Offline (Buffering locally)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOnline ? const Color(0xFF059669) : const Color(0xFFD97706),
                    ),
                  ),
                  const Spacer(),
                  if (_pendingCount > 0)
                    TextButton.icon(
                      onPressed: isOnline ? _triggerSync : null,
                      icon: const Icon(Icons.sync, size: 14),
                      label: const Text('Sync Now', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.primaryStrong,
                      ),
                    ),
                ],
              ),
            ),
            // Tab contents
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOutboxTab(),
                  _buildMasterCacheTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: OUTBOX OPERATIONS
  // ---------------------------------------------------------------------------

  Widget _buildOutboxTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _filterChip('ALL', 'All (${_outboxList.length})'),
                const SizedBox(width: 8),
                _filterChip('PENDING', 'Pending ($_pendingCount)'),
                const SizedBox(width: 8),
                _filterChip('QUARANTINED', 'Quarantined ($_quarantinedCount)'),
              ],
            ),
          ),
          const Divider(height: 12, color: AppColors.borderMuted),
          // Items list
          Expanded(
            child: _filteredOutbox.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: Colors.green.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No offline operations in outbox',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'All offline created data has synced to Odoo.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredOutbox.length,
                    itemBuilder: (context, index) {
                      return _buildOutboxCard(_filteredOutbox[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.borderSoft,
      ),
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
    );
  }

  Widget _buildOutboxCard(Map<String, dynamic> op) {
    final entityType = op['entity_type']?.toString() ?? 'generic';
    final endpoint = op['endpoint']?.toString() ?? '';
    final status = op['status']?.toString() ?? 'PENDING';
    final createdAt = op['created_at']?.toString() ?? '';
    final retries = op['retry_count'] ?? 0;
    final errorMessage = op['error_message']?.toString();
    final opUuid = op['operation_uuid']?.toString() ?? '';

    Color statusBg;
    Color statusFg;
    if (status == 'PENDING') {
      statusBg = const Color(0xFFFFFBEB);
      statusFg = const Color(0xFFD97706);
    } else if (status == 'SYNCING') {
      statusBg = const Color(0xFFEFF6FF);
      statusFg = const Color(0xFF2563EB);
    } else if (status == 'QUARANTINED') {
      statusBg = const Color(0xFFFEF2F2);
      statusFg = const Color(0xFFDC2626);
    } else {
      statusBg = const Color(0xFFECFDF5);
      statusFg = const Color(0xFF059669);
    }

    IconData entityIcon;
    switch (entityType.toLowerCase()) {
      case 'order':
        entityIcon = Icons.shopping_bag_outlined;
        break;
      case 'visit':
      case 'visit_update':
        entityIcon = Icons.location_on_outlined;
        break;
      case 'outlet':
        entityIcon = Icons.storefront_outlined;
        break;
      case 'return':
        entityIcon = Icons.assignment_return_outlined;
        break;
      case 'scrap':
        entityIcon = Icons.recycling_outlined;
        break;
      case 'attendance':
        entityIcon = Icons.access_time_outlined;
        break;
      case 'expense':
        entityIcon = Icons.receipt_long_outlined;
        break;
      default:
        entityIcon = Icons.cloud_upload_outlined;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: status == 'QUARANTINED'
              ? Colors.red.shade200
              : AppColors.borderSoft,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showOutboxDetailModal(op),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(entityIcon, size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entityType.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          endpoint,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusFg.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusFg,
                      ),
                    ),
                  ),
                ],
              ),
              if (errorMessage != null && errorMessage.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Error: $errorMessage',
                    style: TextStyle(fontSize: 11, color: Colors.red.shade800),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Created: ${_formatIsoDate(createdAt)}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (retries > 0)
                    Text(
                      'Retries: $retries',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (status == 'QUARANTINED') ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () async {
                        await _dbHelper.retryQuarantinedOperation(opUuid);
                        _loadData();
                        _triggerSync();
                      },
                      child: const Text(
                        'RETRY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOutboxDetailModal(Map<String, dynamic> op) {
    final payloadJson = op['payload_json']?.toString() ?? '{}';
    String formattedPayload = payloadJson;
    try {
      final decoded = jsonDecode(payloadJson);
      formattedPayload = const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {}

    final opUuid = op['operation_uuid']?.toString() ?? '';
    final status = op['status']?.toString() ?? 'PENDING';
    final errorMsg = op['error_message']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    children: [
                      Text(
                        '${op['entity_type']?.toString().toUpperCase()} Operation',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  _detailRow('UUID', opUuid),
                  _detailRow('Endpoint', op['endpoint']?.toString() ?? ''),
                  _detailRow('Status', status),
                  _detailRow('Created', _formatIsoDate(op['created_at']?.toString() ?? '')),
                  _detailRow('Retries', '${op['retry_count'] ?? 0}'),
                  if (errorMsg != null && errorMsg.isNotEmpty)
                    _detailRow('Error Reason', errorMsg, isError: true),
                  const SizedBox(height: 12),
                  const Text(
                    'Payload JSON:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      formattedPayload,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (status == 'QUARANTINED')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await _dbHelper.retryQuarantinedOperation(opUuid);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadData();
                              _triggerSync();
                            },
                            icon: const Icon(Icons.replay, size: 16),
                            label: const Text('Retry Op'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      if (status == 'QUARANTINED') const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('Delete Operation?'),
                                content: const Text(
                                  'Are you sure you want to discard this offline record? It will not be synced to Odoo.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx, true),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await _dbHelper.deleteOutboxOperation(opUuid);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadData();
                            }
                          },
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          label: const Text(
                            'Discard Op',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: CACHED MASTER DATA
  // ---------------------------------------------------------------------------

  Widget _buildMasterCacheTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.folder_copy_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '${_masterDataList.length} Cached Master Datasets',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_masterDataList.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Clear All Master Cache?'),
                          content: const Text(
                            'This will clear local product catalogs, routes, and reasons cache. The app will re-fetch them next time you open those screens while online.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: const Text('Clear All', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await _dbHelper.clearMasterData();
                        _loadData();
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                    child: const Text('Clear Cache', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderMuted),
          Expanded(
            child: _masterDataList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_download_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No cached master data yet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Open Catalogs, Routes, or Outlets while online to warm cache.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _masterDataList.length,
                    itemBuilder: (context, index) {
                      return _buildMasterCacheCard(_masterDataList[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterCacheCard(Map<String, dynamic> item) {
    final entityKey = item['entity_key']?.toString() ?? '';
    final entityType = item['entity_type']?.toString() ?? 'master';
    final updatedAt = item['updated_at']?.toString() ?? '';
    final dataJson = item['data_json']?.toString() ?? '';

    int recordCount = 0;
    try {
      final decoded = jsonDecode(dataJson);
      if (decoded is List) {
        recordCount = decoded.length;
      } else if (decoded is Map) {
        recordCount = decoded.keys.length;
      }
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderSoft),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showMasterCacheDetailModal(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.data_object_outlined,
                  size: 18,
                  color: AppColors.primaryStrong,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entityKey,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Type: $entityType · $recordCount records (${(dataJson.length / 1024).toStringAsFixed(1)} KB)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Updated: ${_formatIsoDate(updatedAt)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                tooltip: 'Delete this cache',
                onPressed: () async {
                  await _dbHelper.deleteMasterDataKey(entityKey);
                  _loadData();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMasterCacheDetailModal(Map<String, dynamic> item) {
    final entityKey = item['entity_key']?.toString() ?? '';
    final dataJson = item['data_json']?.toString() ?? '{}';

    String formatted = dataJson;
    try {
      final decoded = jsonDecode(dataJson);
      formatted = const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Cache: $entityKey',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copy JSON',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: formatted));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to clipboard')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  _detailRow('Entity Key', entityKey),
                  _detailRow('Entity Type', item['entity_type']?.toString() ?? ''),
                  _detailRow('Updated At', _formatIsoDate(item['updated_at']?.toString() ?? '')),
                  const SizedBox(height: 12),
                  const Text(
                    'Cached JSON Content:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      formatted,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isError ? Colors.red.shade700 : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatIsoDate(String iso) {
    if (iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
  }
}
