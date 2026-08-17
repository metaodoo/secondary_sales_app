import 'dart:async';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/constants.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/features/returns/return_provider.dart';
import 'package:secondary_sales/data/models/return_scrap_summary.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/returns/screens/create_return_screen.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/core/access/access_resources.dart';

class ReturnsListScreen extends StatefulWidget {
  final String moduleType;
  final String title;
  final String createLabel;
  final String createScreenTitle;
  final String productSelectionTitle;
  final String endpoint;
  final String? createActionKey;

  const ReturnsListScreen({
    super.key,
    this.moduleType = 'primary',
    this.title = 'Returns List',
    this.createLabel = 'New Return',
    this.createScreenTitle = 'Returns',
    this.productSelectionTitle = 'Select Return Products',
    this.endpoint = AppConstants.returnsEndpoint,
    this.createActionKey,
  });

  @override
  State<ReturnsListScreen> createState() => _ReturnsListScreenState();
}

class _ReturnsListScreenState extends State<ReturnsListScreen> {
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  String _state = 'all';
  String? _returnReciptStatus;
  List<ReturnScrapSummary> _returns = [];
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get _isPrimary =>
      widget.moduleType.toLowerCase() == 'primary' || widget.moduleType.isEmpty;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchReturns(reset: true));
  }

  Future<void> _fetchReturns({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
      _isLoadingMore = false;
    }
    if (!reset && (!_hasMore || _isLoadingMore)) {
      return;
    }

    if (!mounted) return;
    setState(() {
      if (!reset) {
        _isLoadingMore = true;
      }
    });

    final provider = context.read<ReturnProvider>();
    final results = await provider.fetchReturns(
      page: _page,
      pageSize: _pageSize,
      search: _searchController.text,
      state: _state,
      returnReciptStatus: _returnReciptStatus,
      type: widget.moduleType,
      endpoint: widget.endpoint,
    );
    if (mounted) {
      setState(() {
        if (reset) {
          _returns = results;
        } else {
          _returns.addAll(results);
        }
        _hasMore = results.length == _pageSize;
        if (_hasMore) {
          _page += 1;
        }
        _isLoadingMore = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _fetchReturns(reset: true),
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _fetchReturns();
    }
  }

  Future<void> _openCreateReturn() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateReturnScreen(
          moduleType: widget.moduleType,
          title: widget.createScreenTitle,
          productSelectionTitle: widget.productSelectionTitle,
          endpoint: widget.endpoint,
        ),
      ),
    );
    if (mounted) {
      _fetchReturns(reset: true);
    }
  }

  bool _isPendingFilterActive = false;

  int get _pendingCount => _returns.where((r) => r.state != 'done').length;

  List<ReturnScrapSummary> get _displayedReturns {
    if (_isPendingFilterActive) {
      return _returns.where((r) => r.state != 'done').toList();
    }
    return _returns;
  }

  Color _stateColor(String state, String? returnReciptStatus) {
    if (state == 'done') return const Color(0xFF10B981);
    if (state == 'cancel') return Colors.red;
    if (state == 'draft') return AppColors.textSecondary;

    if (_isPrimary &&
        (state == 'assigned' ||
            state == 'waiting' ||
            state == 'confirmed' ||
            state == 'ready')) {
      if (returnReciptStatus == 'sales_operation_receipt') {
        return const Color(0xFF1D4ED8); // Blue 700
      }
      return const Color(0xFFD97706); // Amber 600
    }
    return switch (state) {
      'assigned' => const Color(0xFFF59E0B),
      'waiting' => const Color(0xFFF59E0B),
      'confirmed' => const Color(0xFFF59E0B),
      _ => AppColors.textSecondary,
    };
  }

  Color _stateBgColor(String state, String? returnReciptStatus) {
    if (state == 'done') return const Color(0xFFD1FAE5);
    if (state == 'cancel') return const Color(0xFFFEE2E2);
    if (state == 'draft') return AppColors.borderMuted;

    if (_isPrimary &&
        (state == 'assigned' ||
            state == 'waiting' ||
            state == 'confirmed' ||
            state == 'ready')) {
      if (returnReciptStatus == 'sales_operation_receipt') {
        return const Color(0xFFDBEAFE); // Blue 100
      }
      return const Color(0xFFFEF3C7); // Amber 100
    }
    return switch (state) {
      'assigned' => const Color(0xFFFEF3C7),
      'waiting' => const Color(0xFFFEF3C7),
      'confirmed' => const Color(0xFFFEF3C7),
      _ => AppColors.borderMuted,
    };
  }

  String _stateLabel(String state, String? returnReciptStatus) {
    if (state == 'done') return 'DELIVERED';
    if (state == 'cancel') return 'CANCELLED';
    if (state == 'draft') return 'DRAFT';

    if (_isPrimary &&
        (state == 'assigned' ||
            state == 'waiting' ||
            state == 'confirmed' ||
            state == 'ready')) {
      if (returnReciptStatus == 'sales_operation_receipt') {
        return 'SALES OPERATION RECEIPT';
      }
      return 'WAREHOUSE RECEIPT';
    }
    return switch (state) {
      'assigned' => 'READY',
      'waiting' => 'WAITING',
      'confirmed' => 'CONFIRMED',
      _ => state.toUpperCase(),
    };
  }

  void _showFilterDialog() {
    final currentFilterValue = _returnReciptStatus ?? _state;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter ${widget.title}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: currentFilterValue,
                decoration: ssInputDecoration('Status', Icons.filter_list),
                items: _isPrimary
                    ? const [
                        DropdownMenuItem(value: 'all', child: Text('All Status')),
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(
                          value: 'warehouse_receipt',
                          child: Text('Warehouse Receipt'),
                        ),
                        DropdownMenuItem(
                          value: 'sales_operation_receipt',
                          child: Text('Sales Operation Receipt'),
                        ),
                        DropdownMenuItem(
                          value: 'done',
                          child: Text('Delivered'),
                        ),
                        DropdownMenuItem(
                          value: 'cancel',
                          child: Text('Cancelled'),
                        ),
                      ]
                    : const [
                        DropdownMenuItem(value: 'all', child: Text('All Status')),
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(
                          value: 'assigned',
                          child: Text('Pending (Ready)'),
                        ),
                        DropdownMenuItem(
                          value: 'done',
                          child: Text('Processed (Done)'),
                        ),
                        DropdownMenuItem(
                          value: 'cancel',
                          child: Text('Cancelled'),
                        ),
                      ],
                onChanged: (value) {
                  if (value != null) {
                    if (value == 'warehouse_receipt' ||
                        value == 'sales_operation_receipt') {
                      setState(() {
                        _state = 'all';
                        _returnReciptStatus = value;
                      });
                    } else {
                      setState(() {
                        _state = value;
                        _returnReciptStatus = null;
                      });
                    }
                    _fetchReturns(reset: true);
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReturnProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: const ProfileAvatar(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderMuted, height: 1),
        ),
      ),
      floatingActionButton: auth.canDo(widget.createActionKey ?? AppAction.returnCreateFor(widget.moduleType))
          ? SsCreateFab(label: widget.createLabel, onPressed: _openCreateReturn)
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _fetchReturns(reset: true),
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, kSsFabScrollPadding),
            children: [
              // Search Field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search reference or customer',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: InkWell(
                    onTap: _showFilterDialog,
                    child: const Icon(
                      Icons.filter_list,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
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
              const SizedBox(height: 24),

              // Summary Card
              InkWell(
                onTap: () {
                  setState(() {
                    _isPendingFilterActive = !_isPendingFilterActive;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: _isPendingFilterActive
                        ? Border.all(color: const Color(0xFFB45309), width: 2)
                        : Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE68A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.pending_actions_outlined,
                          color: Color(0xFFB45309),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_pendingCount'.padLeft(2, '0'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB45309),
                            ),
                          ),
                          const Text(
                            'Pending',
                            style: TextStyle(
                              color: Color(0xFFB45309),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (provider.isLoading && _returns.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_displayedReturns.isEmpty)
                const EmptyPanel(message: 'No returns found')
              else ...[
                if (provider.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),
                ..._displayedReturns.map((ret) {
                  final origin = ret.origin?.toString() ?? '-';
                  // In standard odoo origin may look like 'Return from Distributor A'
                  final customerName = origin.replaceAll('Return from ', '');
                  final date = ret.scheduledDate == null
                      ? '-'
                      : '${ret.scheduledDate!.year.toString().padLeft(4, '0')}-${ret.scheduledDate!.month.toString().padLeft(2, '0')}-${ret.scheduledDate!.day.toString().padLeft(2, '0')}';

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateReturnScreen(
                            returnId: ret.id,
                            moduleType: widget.moduleType,
                            title: widget.createScreenTitle,
                            productSelectionTitle: widget.productSelectionTitle,
                            endpoint: widget.endpoint,
                          ),
                        ),
                      ).then((_) => _fetchReturns(reset: true));
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDDE6F2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '#${ret.name}',
                                style: const TextStyle(
                                  color: Color(0xFF0038A8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _stateBgColor(ret.state, ret.returnReciptStatus),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _stateLabel(ret.state, ret.returnReciptStatus),
                                  style: TextStyle(
                                    color: _stateColor(ret.state, ret.returnReciptStatus),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            customerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          if (ret.returnBookNumber != null || ret.returnBookPage != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.menu_book, size: 14, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  '${ret.returnBookNumber ?? '-'} (Pg ${ret.returnBookPage ?? '-'})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(
                              height: 1,
                              color: AppColors.borderMuted,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 16,
                                    color: Colors.black54,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    date,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 16,
                                    color: Colors.black54,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'View Details',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (_isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
