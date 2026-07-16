import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/data/models/delivery_item.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/features/sales/screens/validate_delivery_screen.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class DeliveriesListScreen extends StatefulWidget {
  final String moduleType;
  const DeliveriesListScreen({super.key, this.moduleType = 'primary'});

  @override
  State<DeliveriesListScreen> createState() => _DeliveriesListScreenState();
}

class _DeliveriesListScreenState extends State<DeliveriesListScreen> {
  bool _isLoading = false;
  List<DeliveryItem> _deliveries = [];
  String? _error;
  String _currentFilter = 'all';

  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _fetchDeliveries();
  }

  Future<void> _fetchDeliveries([String? query]) async {
    setState(() {
      _isLoading = true;
      _error = null;
      if (query != null) _searchQuery = query;
    });
    try {
      final provider = context.read<PrimarySaleProvider>();
      final items = await provider.apiService.getDeliveries(
        pageSize: 50,
        search: _searchQuery,
        type: widget.moduleType,
      );
      setState(() {
        _deliveries = items;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  int get _pendingCount => _deliveries
      .where(
        (d) =>
            d.state == 'waiting' ||
            d.state == 'confirmed' ||
            d.state == 'assigned',
      )
      .length;
  int get _overdueCount {
    final now = DateTime.now();
    return _deliveries
        .where(
          (d) =>
              (d.state == 'waiting' ||
                  d.state == 'confirmed' ||
                  d.state == 'assigned') &&
              d.scheduledDate != null &&
              d.scheduledDate!.isBefore(now),
        )
        .length;
  }

  List<DeliveryItem> get _filteredDeliveries {
    if (_currentFilter == 'pending') {
      return _deliveries
          .where(
            (d) =>
                d.state == 'waiting' ||
                d.state == 'confirmed' ||
                d.state == 'assigned',
          )
          .toList();
    } else if (_currentFilter == 'overdue') {
      final now = DateTime.now();
      return _deliveries
          .where(
            (d) =>
                (d.state == 'waiting' ||
                    d.state == 'confirmed' ||
                    d.state == 'assigned') &&
                d.scheduledDate != null &&
                d.scheduledDate!.isBefore(now),
          )
          .toList();
    }
    return _deliveries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
        title: const Text(
          'Deliveries',
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
            child: ProfileAvatar(onTap: () {}),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderMuted, height: 1),
        ),
      ),
      body: _isLoading && _deliveries.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final displayed = _filteredDeliveries;
    return RefreshIndicator(
      onRefresh: () => _fetchDeliveries(),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    ErrorPanel(_error!),
                    const SizedBox(height: 16),
                  ],
                  if (_isLoading) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                  ],
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildStatsCards(),
                  const SizedBox(height: 24),
                  const Text(
                    'ACTIVE SHIPMENTS',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (displayed.isEmpty)
            const SliverFillRemaining(
              child: EmptyPanel(message: 'No deliveries found'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return _buildDeliveryCard(displayed[index]);
                }, childCount: displayed.length),
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0),
            child: Icon(Icons.search, color: AppColors.textSecondary),
          ),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search delivery reference...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: AppColors.textSecondary),
              ),
              onSubmitted: (val) {
                _fetchDeliveries(val);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.borderSoft)),
            ),
            child: const Icon(
              Icons.filter_list,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              setState(() {
                _currentFilter = _currentFilter == 'pending'
                    ? 'all'
                    : 'pending';
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: _currentFilter == 'pending'
                    ? Border.all(color: const Color(0xFFB45309), width: 2)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    color: Color(0xFFB45309),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _pendingCount.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB45309),
                    ),
                  ),
                  const Text(
                    'Pending Delivery',
                    style: TextStyle(color: Color(0xFFB45309), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InkWell(
            onTap: () {
              setState(() {
                _currentFilter = _currentFilter == 'overdue'
                    ? 'all'
                    : 'overdue';
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: _currentFilter == 'overdue'
                    ? Border.all(color: const Color(0xFFB91C1C), width: 2)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.timer_outlined, color: Color(0xFFB91C1C)),
                  const SizedBox(height: 12),
                  Text(
                    _overdueCount.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                  const Text(
                    'Overdue Delivery',
                    style: TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryCard(DeliveryItem delivery) {
    String badgeText = delivery.state.toUpperCase();
    Color badgeColor = AppColors.borderMuted;
    Color badgeTextColor = AppColors.textSecondary;

    if (delivery.state == 'done') {
      badgeText = 'DELIVERED';
      badgeColor = const Color(0xFFDCFCE7);
      badgeTextColor = const Color(0xFF15803D);
    } else if (delivery.state == 'cancel') {
      badgeText = 'CANCELLED';
      badgeColor = const Color(0xFFFEE2E2);
      badgeTextColor = const Color(0xFFB91C1C);
    } else if (delivery.state == 'assigned') {
      badgeText = 'READY';
      badgeColor = AppColors.primaryTint;
      badgeTextColor = const Color(0xFF1D4ED8);
    } else if (delivery.state == 'waiting' || delivery.state == 'confirmed') {
      badgeText = 'WAITING';
      badgeColor = const Color(0xFFFEF3C7);
      badgeTextColor = const Color(0xFFB45309);
    }

    final dateStr = _formatDate(delivery.createdDate);
    final estStr = _formatDate(delivery.scheduledDate);

    return InkWell(
      onTap: () {
        if (delivery.saleId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot view details: Missing Sale Order ID'),
            ),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ValidateDeliveryScreen(
              orderId: delivery.saleId!,
              orderName: delivery.saleName ?? '',
              pickingId: delivery.id,
              pickingName: delivery.name,
              pickingState: delivery.state,
              saleType: widget.moduleType,
            ),
          ),
        ).then((_) {
          _fetchDeliveries();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          delivery.name,
                          style: const TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (delivery.saleName != null &&
                            delivery.saleName!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Order Ref: ${delivery.saleName}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                delivery.partnerName ?? 'Unknown Partner',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.borderSoft),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Created Date',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          delivery.state == 'done'
                              ? 'Delivery Date'
                              : 'Est. Delivery',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          delivery.state == 'done'
                              ? _formatDate(delivery.dateDone)
                              : estStr,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
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

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
