import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_stock_audit.dart';
import 'package:secondary_sales/features/modern_trade/modern_trade_provider.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_sec_order_detail_screen.dart';

class MtSecOrdersListScreen extends StatefulWidget {
  final int? outletId;
  final String? outletName;

  const MtSecOrdersListScreen({
    super.key,
    this.outletId,
    this.outletName,
  });

  @override
  State<MtSecOrdersListScreen> createState() => _MtSecOrdersListScreenState();
}

class _MtSecOrdersListScreenState extends State<MtSecOrdersListScreen> {
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  DateTime? _dateFrom = DateTime.now();
  DateTime? _dateTo = DateTime.now();
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchOrders(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _fetchOrders();
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchOrders(reset: true);
    });
  }

  Future<void> _fetchOrders({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
      _isLoadingMore = false;
    }
    if (!reset && (!_hasMore || _isLoadingMore)) {
      return;
    }

    if (mounted) {
      setState(() {
        if (!reset) _isLoadingMore = true;
      });
    }

    final dateFromStr = _dateFrom != null
        ? DateFormat('yyyy-MM-dd').format(_dateFrom!)
        : null;
    final dateToStr = _dateTo != null
        ? DateFormat('yyyy-MM-dd').format(_dateTo!)
        : null;
    final searchStr = _searchController.text.trim().isNotEmpty
        ? _searchController.text.trim()
        : null;

    final provider = context.read<ModernTradeProvider>();
    await provider.fetchMtSecondarySales(
      page: _page,
      pageSize: _pageSize,
      outletId: widget.outletId,
      dateFrom: dateFromStr,
      dateTo: dateToStr,
      search: searchStr,
    );

    if (mounted) {
      setState(() {
        _hasMore = provider.secSaleOrders.length < provider.secSaleOrdersTotal;
        if (_hasMore) {
          _page += 1;
        }
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final initialStart = _dateFrom ?? now;
    final initialEnd = _dateTo ?? now;
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryStrong,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateFrom = picked.start;
        _dateTo = picked.end;
      });
      _fetchOrders(reset: true);
    }
  }

  void _clearDateFilter() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
    });
    _fetchOrders(reset: true);
  }

  void _resetToToday() {
    setState(() {
      _dateFrom = DateTime.now();
      _dateTo = DateTime.now();
    });
    _fetchOrders(reset: true);
  }

  String get _dateRangeDisplay {
    if (_dateFrom == null && _dateTo == null) {
      return 'All Dates';
    }
    if (_dateFrom != null && _dateTo != null) {
      final isSameDay = _dateFrom!.year == _dateTo!.year &&
          _dateFrom!.month == _dateTo!.month &&
          _dateFrom!.day == _dateTo!.day;
      if (isSameDay) {
        final now = DateTime.now();
        final isToday = _dateFrom!.year == now.year &&
            _dateFrom!.month == now.month &&
            _dateFrom!.day == now.day;
        return isToday
            ? 'Today (${DateFormat('dd MMM').format(_dateFrom!)})'
            : DateFormat('dd MMM yyyy').format(_dateFrom!);
      }
      return '${DateFormat('dd MMM').format(_dateFrom!)} - ${DateFormat('dd MMM').format(_dateTo!)}';
    }
    if (_dateFrom != null) {
      return 'From ${DateFormat('dd MMM').format(_dateFrom!)}';
    }
    return 'Until ${DateFormat('dd MMM').format(_dateTo!)}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ModernTradeProvider>();
    final orders = provider.secSaleOrders;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.outletName != null
              ? '${widget.outletName} - Secondary Orders'
              : 'MT Secondary Sales Orders',
          style: const TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter & Search bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: AppColors.surface,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search order ref, outlet...',
                            hintStyle: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      _fetchOrders(reset: true);
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _selectDateRange,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: (_dateFrom != null || _dateTo != null)
                              ? AppColors.primarySoft
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (_dateFrom != null || _dateTo != null)
                              ? AppColors.primaryStrong
                              : AppColors.borderSoft,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_month,
                              size: 18,
                              color: (_dateFrom != null || _dateTo != null)
                                  ? AppColors.primaryStrong
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _dateRangeDisplay,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: (_dateFrom != null || _dateTo != null)
                                    ? AppColors.primaryStrong
                                    : AppColors.textPrimary,
                              ),
                            ),
                            if (_dateFrom != null || _dateTo != null) ...[
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: _clearDateFilter,
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: AppColors.primaryStrong,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_dateFrom == null && _dateTo == null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: _resetToToday,
                      child: const Text(
                        'Set to Today',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryStrong,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // Orders List
          Expanded(
            child: provider.isLoading && orders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _dateFrom != null || _dateTo != null
                                  ? 'No secondary sales orders for $_dateRangeDisplay'
                                  : 'No secondary sales orders found',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _fetchOrders(reset: true),
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: orders.length + (_isLoadingMore ? 1 : 0),
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index >= orders.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final order = orders[index];
                            return _MtSecOrderCard(
                              order: order,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MtSecOrderDetailScreen(
                                      orderId: order.id,
                                    ),
                                  ),
                                );
                                _fetchOrders(reset: true);
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _MtSecOrderCard extends StatelessWidget {
  final MtSecSaleOrder order;
  final VoidCallback onTap;

  const _MtSecOrderCard({
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = order.date != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(order.date!.toLocal())
        : 'N/A';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'DONE',
                      style: TextStyle(
                        color: Color(0xFF16A34A),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (order.outletName != null) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order.outletName!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              if (order.employeeName != null) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order.employeeName!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.totalLines} items computed',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Sold Qty: ${order.totalSoldQty.toStringAsFixed(1)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryStrong,
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
