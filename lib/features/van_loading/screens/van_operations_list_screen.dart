import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/inventory/virtual_transfer.dart';
import 'package:secondary_sales/features/transfers/transfer_provider.dart';
import 'package:secondary_sales/features/van_loading/screens/van_load_form_screen.dart';
import 'package:secondary_sales/features/transfers/screens/virtual_transfer_detail_screen.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';

class VanOperationsListScreen extends StatefulWidget {
  const VanOperationsListScreen({super.key, this.onProfileTap, this.onBack});

  final VoidCallback? onProfileTap;
  final VoidCallback? onBack;

  @override
  State<VanOperationsListScreen> createState() =>
      _VanOperationsListScreenState();
}

class _VanOperationsListScreenState extends State<VanOperationsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _operationType = 'load';
  DateTime? _dateFromFilter;
  DateTime? _dateToFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchOperations());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOperations() {
    return context.read<TransferProvider>().fetchVirtualTransfers(
      search: _searchController.text,
      vanOperationType: _operationType,
      dateFrom: _dateFromFilter,
      dateTo: _dateToFilter,
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _fetchOperations);
  }

  Future<void> _pickDate() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateFromFilter != null && _dateToFilter != null
          ? DateTimeRange(start: _dateFromFilter!, end: _dateToFilter!)
          : null,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      _dateFromFilter = picked.start;
      _dateToFilter = picked.end;
    });
    _fetchOperations();
  }

  Future<void> _openCreateTransfer(String type) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VanLoadFormScreen(isLoad: type == 'load')),
    );
    if (mounted) {
      _fetchOperations();
    }
  }

  Future<void> _openTransferDetail(VirtualTransfer transfer) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VirtualTransferDetailScreen(initialTransfer: transfer),
      ),
    );
    if (mounted) {
      _fetchOperations();
    }
  }

  String _stateLabel(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return 'Draft';
      case 'done':
        return 'Completed';
      case 'cancel':
        return 'Cancelled';
      case 'assigned':
        return 'Ready';
      case 'confirmed':
        return 'Confirmed';
      default:
        return 'In Progress';
    }
  }

  Color _stateColor(String state) {
    switch (state.toLowerCase()) {
      case 'done':
        return const Color(0xFF10B981);
      case 'cancel':
        return Colors.red;
      case 'assigned':
        return const Color(0xFF2563EB);
      case 'confirmed':
        return const Color(0xFFF59E0B);
      case 'draft':
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _stateIcon(String state) {
    switch (state.toLowerCase()) {
      case 'done':
        return Icons.check_circle;
      case 'cancel':
        return Icons.cancel;
      default:
        return Icons.sync;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransferProvider>();
    final transfers = provider.virtualTransfers;
    final bool hasDateFilter = _dateFromFilter != null && _dateToFilter != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: widget.onBack != null
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                onPressed: widget.onBack,
              )
            : IconButton(
                icon: const Icon(Icons.menu, color: AppColors.textPrimary),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        title: const Text(
          'Van Operations',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.onProfileTap != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ProfileAvatar(onTap: widget.onProfileTap!),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderMuted, height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchOperations,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Search Field
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search operations...',
                        hintStyle: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderSoft),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderSoft),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Selected Date Range',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              hasDateFilter
                                  ? '${ssFormatDate(_dateFromFilter!)} -> ${ssFormatDate(_dateToFilter!)}'
                                  : 'Select Date Range',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (hasDateFilter) ...[
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _dateFromFilter = null;
                                    _dateToFilter = null;
                                  });
                                  _fetchOperations();
                                },
                                child: const Icon(
                                  Icons.close,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Load / Unload Toggle
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E9F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _operationType = 'load');
                                _fetchOperations();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _operationType == 'load'
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Load',
                                  style: TextStyle(
                                    color: _operationType == 'load'
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _operationType = 'unload');
                                _fetchOperations();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _operationType == 'unload'
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Unload',
                                  style: TextStyle(
                                    color: _operationType == 'unload'
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'RECENT OPERATIONS',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          'Show: Today',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (provider.error != null) ErrorPanel(provider.error!),
                    if (provider.isLoading && transfers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (transfers.isEmpty)
                      const EmptyPanel(message: 'No operations found')
                    else ...[
                      if (provider.isLoading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(),
                        ),
                      ...transfers.map(
                        (transfer) => _buildOperationCard(transfer),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.borderSoft),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: provider.isLoading
                          ? null
                          : () => _openCreateTransfer('load'),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'New Load',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: provider.isLoading
                          ? null
                          : () => _openCreateTransfer('unload'),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'New Unload',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationCard(VirtualTransfer transfer) {
    final bool isLoad = transfer.vanOperationType?.toLowerCase() == 'load';
    final bool isScrap = transfer.ssTransferCategory?.toLowerCase() == 'scrap';
    final stateLabel = _stateLabel(transfer.state);
    final stateColor = _stateColor(transfer.state);
    final stateIcon = _stateIcon(transfer.state);

    final badgeBgColor = isLoad
        ? const Color(0xFFE0F2E9)
        : (isScrap ? const Color(0xFFFCE8E6) : const Color(0xFFFDECDA));
    final badgeTextColor = isLoad
        ? const Color(0xFF10B981)
        : (isScrap ? const Color(0xFFEA4335) : const Color(0xFFF59E0B));
    final badgeText = isLoad
        ? 'Load'
        : (isScrap ? 'Scrap Unload' : 'Unload');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E9F2)),
      ),
      child: InkWell(
        onTap: () => _openTransferDetail(transfer),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    transfer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    transfer.scheduledDate ?? 'Unknown date',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              Row(
                children: [
                  Icon(stateIcon, size: 18, color: stateColor),
                  const SizedBox(width: 6),
                  Text(
                    stateLabel,
                    style: TextStyle(
                      color: stateColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
