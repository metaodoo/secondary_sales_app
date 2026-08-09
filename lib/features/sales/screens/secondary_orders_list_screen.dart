import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/dashboard_cards.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/data/models/sales/primary_order.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/features/sales/screens/order_detail_screen.dart';
import 'package:secondary_sales/features/sales/screens/order_creation_screen.dart';
import 'package:secondary_sales/features/routes/screens/officer_route_selection_screen.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/data/api/api_service.dart';

class SecondaryOrdersListScreen extends StatefulWidget {
  final int? outletId;
  final String? outletName;

  /// When set, shows only the orders placed on this outlet visit
  /// (`sale.order.visit_id`) — used by the "order on the visit" link.
  final int? visitId;

  /// Optional starting date filter (e.g. carried from the dashboard range).
  final DateTime? initialDateFrom;
  final DateTime? initialDateTo;

  /// 'secondary' (default) or 'primary'. Primary opens read-only — create and
  /// edit are secondary-only flows and are hidden.
  final String saleType;

  /// Optional app-bar title override.
  final String? titleOverride;

  const SecondaryOrdersListScreen({
    super.key,
    this.outletId,
    this.outletName,
    this.visitId,
    this.initialDateFrom,
    this.initialDateTo,
    this.saleType = 'secondary',
    this.titleOverride,
  });

  @override
  State<SecondaryOrdersListScreen> createState() =>
      _SecondaryOrdersListScreenState();
}

class _SecondaryOrdersListScreenState extends State<SecondaryOrdersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';
  DateTime? _dateFromFilter;
  DateTime? _dateToFilter;
  List<PrimaryOrder> _orders = [];
  bool _isLoading = false;
  String? _error;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _dateFromFilter = widget.initialDateFrom;
    _dateToFilter = widget.initialDateTo;
    _fetchOrders();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = context.read<PrimarySaleProvider>();
      final fetched = await provider.apiService.getRecentOrders(
        search: _searchController.text,
        status: _statusFilter,
        dateFrom: _dateFromFilter,
        dateTo: _dateToFilter,
        saleType: widget.saleType,
        outletId: widget.outletId,
        visitId: widget.visitId,
      );
      if (mounted) {
        setState(() {
          _orders = fetched;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _fetchOrders);
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
    _fetchOrders();
  }

  void _clearDate() {
    setState(() {
      _dateFromFilter = null;
      _dateToFilter = null;
    });
    _fetchOrders();
  }

  void _clearStatus() {
    setState(() {
      _statusFilter = 'all';
    });
    _fetchOrders();
  }

  void _clearAllFilters() {
    setState(() {
      _statusFilter = 'all';
      _dateFromFilter = null;
      _dateToFilter = null;
    });
    _fetchOrders();
  }

  String _getStatusLabel(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return 'Draft';
      case 'sale':
      case 'confirmed':
        return 'Confirmed';
      case 'delivery_partial':
        return 'Delivery Partially Done';
      case 'delivery_full':
        return 'Delivery Fully Done';
      case 'cancel':
      case 'cancelled':
        return 'Cancelled';
      case 'all':
      default:
        return 'All Status';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDateFilter = _dateFromFilter != null && _dateToFilter != null;
    final bool hasStatusFilter = _statusFilter != 'all';
    final bool hasAnyFilter = hasDateFilter || hasStatusFilter;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
            size: 28,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.titleOverride ??
              (widget.outletName != null
                  ? '${widget.outletName} Orders'
                  : (widget.saleType == 'primary'
                        ? 'Primary Sales Orders'
                        : 'Secondary Sales Orders')),
          style: const TextStyle(
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
      floatingActionButton:
          (widget.saleType == 'secondary' &&
                  context.watch<AuthProvider>().canView(AppScreen.orderCreate))
              ? SsCreateFab(
                  label: 'New Sales Order',
                  onPressed: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => const OfficerRouteSelectionScreen(),
                          ),
                        )
                        .then((_) => _fetchOrders());
                  },
                )
              : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchOrders,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.screen,
              AppSpacing.screen,
              kSsFabScrollPadding,
            ),
            children: [
              // Search Field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search orders...',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: const Icon(
                    Icons.tune,
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

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      icon: Icons.calendar_today_outlined,
                      label: hasDateFilter
                          ? '${ssFormatDate(_dateFromFilter!)} - ${ssFormatDate(_dateToFilter!)}'
                          : 'Date',
                      onTap: _pickDate,
                    ),
                    const SizedBox(width: 12),
                    PopupMenuButton<String>(
                      initialValue: _statusFilter,
                      onSelected: (val) {
                        setState(() => _statusFilter = val);
                        _fetchOrders();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'all', child: Text('All Status')),
                        PopupMenuItem(value: 'draft', child: Text('Draft')),
                        PopupMenuItem(value: 'sale', child: Text('Confirmed')),
                        PopupMenuItem(
                          value: 'delivery_partial',
                          child: Text('Delivery Partially Done'),
                        ),
                        PopupMenuItem(
                          value: 'delivery_full',
                          child: Text('Delivery Fully Done'),
                        ),
                        PopupMenuItem(
                          value: 'cancel',
                          child: Text('Cancelled'),
                        ),
                      ],
                      child: _buildFilterChip(
                        icon: Icons.filter_list,
                        label: _getStatusLabel(_statusFilter),
                      ),
                    ),
                  ],
                ),
              ),

              // Active Filters Row
              if (hasAnyFilter) ...[
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (hasDateFilter) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primaryTint),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${ssFormatDate(_dateFromFilter!)} - ${ssFormatDate(_dateToFilter!)}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: _clearDate,
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (hasStatusFilter) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primaryTint),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Status: ${_getStatusLabel(_statusFilter)}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: _clearStatus,
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      TextButton(
                        onPressed: _clearAllFilters,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Clear all',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Sales Orders",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_orders.length} ${_orders.length == 1 ? "Order" : "Orders"}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // List of Orders
              if (_error != null) ErrorPanel(_error!),
              if (_isLoading && _orders.isNotEmpty) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
              ],
              if (_isLoading && _orders.isEmpty)
                const LoadingState()
              else if (_orders.isEmpty)
                const EmptyPanel(message: 'No secondary orders found')
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return SalesOrderCard(
                      order: order,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OrderDetailScreen(
                              orderId: order.id,
                              fallbackName: order.name,
                              saleType: widget.saleType,
                            ),
                          ),
                        );
                        _fetchOrders();
                      },
                      onEditTap: widget.saleType == 'secondary'
                          ? () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => OrderCreationScreen(
                                    outletId: order.hubId,
                                    customerName: order.hubName,
                                    editOrderId: order.id,
                                  ),
                                ),
                              );
                              _fetchOrders();
                            }
                          : null,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final chipContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.arrow_drop_down,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );

    if (onTap == null) {
      return chipContent;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: chipContent,
    );
  }
}
