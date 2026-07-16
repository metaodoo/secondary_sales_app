import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secondary_sales/core/theme/app_theme.dart';

/// Diagnostic view of the on-device GPS buffer.
///
/// It does NOT open `locations.db` itself — the background service isolate owns
/// that file, and `sqflite` does not support one database across two isolates
/// (a second connection from the UI isolate locks out the service's own
/// reads/writes and stalls syncing). Instead the service publishes a snapshot
/// and its last sync result to SharedPreferences, which this screen renders.
class LocationBufferScreen extends StatefulWidget {
  const LocationBufferScreen({super.key});

  @override
  State<LocationBufferScreen> createState() => _LocationBufferScreenState();
}

class _LocationBufferScreenState extends State<LocationBufferScreen> {
  int _count = 0;
  List<dynamic> _rows = const [];
  Map<String, dynamic>? _lastSync;
  bool _loading = true;
  DateTime? _lastRefresh;
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefresh = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final recentRaw = prefs.getString('loc_buffer_recent');
      final syncRaw = prefs.getString('loc_last_sync');
      if (!mounted) return;
      setState(() {
        _count = prefs.getInt('loc_buffer_count') ?? 0;
        _rows = recentRaw != null ? (jsonDecode(recentRaw) as List) : const [];
        _lastSync =
            syncRaw != null ? jsonDecode(syncRaw) as Map<String, dynamic> : null;
        _loading = false;
        _lastRefresh = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _forceFlush() {
    final messenger = ScaffoldMessenger.of(context);
    try {
      FlutterBackgroundService().invoke('forceSync');
      messenger.showSnackBar(
        const SnackBar(content: Text('Flush requested — watching for result…')),
      );
      Future.delayed(const Duration(seconds: 3), _load);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Flush failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Location Buffer',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderMuted, height: 1),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: [
              _summaryCard(),
              const SizedBox(height: 14),
              _lastSyncCard(),
              const SizedBox(height: 14),
              _rowsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storage_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                _loading ? '—' : '$_count',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 34,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'points buffered',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Captured on this device but not yet uploaded. Clears after each '
            'successful sync and on checkout.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          if (_lastRefresh != null) ...[
            const SizedBox(height: 6),
            Text(
              'Screen updated ${_fmtTime(_lastRefresh!.toUtc())} UTC · auto-refresh 5s',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _forceFlush,
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('Force flush now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lastSyncCard() {
    final sync = _lastSync;
    final ok = sync?['ok'] == true;
    final Color bg = sync == null
        ? Colors.white
        : (ok ? Colors.green.shade50 : Colors.red.shade50);
    final Color border = sync == null
        ? AppColors.borderSoft
        : (ok ? Colors.green.shade100 : Colors.red.shade100);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                sync == null
                    ? Icons.info_outline
                    : (ok ? Icons.check_circle : Icons.error),
                size: 18,
                color: sync == null
                    ? AppColors.textSecondary
                    : (ok ? Colors.green.shade700 : Colors.red.shade700),
              ),
              const SizedBox(width: 8),
              Text(
                sync == null
                    ? 'No sync attempt yet'
                    : (ok ? 'Last sync: OK' : 'Last sync: FAILED'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: sync == null
                      ? AppColors.textPrimary
                      : (ok ? Colors.green.shade800 : Colors.red.shade800),
                ),
              ),
            ],
          ),
          if (sync != null) ...[
            const SizedBox(height: 6),
            Text(
              '${sync['msg'] ?? ''}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'at ${sync['at'] ?? ''} UTC · batch ${sync['count'] ?? '?'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rowsSection() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: const Center(
          child: Text(
            'Buffer is empty.\nCheck in and move around to capture points.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _rows.length; i++) ...[
            _rowTile(_rows[i] as Map),
            if (i != _rows.length - 1)
              const Divider(height: 1, color: AppColors.borderMuted),
          ],
        ],
      ),
    );
  }

  Widget _rowTile(Map row) {
    final id = row['id'];
    final lat = (row['lat'] as num?)?.toStringAsFixed(6) ?? '?';
    final lng = (row['lng'] as num?)?.toStringAsFixed(6) ?? '?';
    final at = row['at']?.toString() ?? '';
    final isMock = row['mock'] == true;

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.primaryTint,
        child: Text(
          '$id',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        '$lat, $lng',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '$at UTC',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: isMock
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'MOCK',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}
