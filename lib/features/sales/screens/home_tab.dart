import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/contacts/distribution_hub.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/features/sales/screens/create_primary_sale_screen.dart';
import 'package:secondary_sales/features/sales/screens/order_detail_screen.dart';
import 'package:secondary_sales/core/widgets/dashboard_cards.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.orderSearchController,
    required this.statusFilter,
    required this.dateFromFilter,
    required this.dateToFilter,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onDateTap,
    required this.onNewOrderTap,
    required this.onProfileTap,
    required this.onBack,
    this.onOpenMenu,
    required this.onClearDate,
    required this.onClearStatus,
    required this.onClearAllFilters,
  });

  final TextEditingController orderSearchController;
  final String statusFilter;
  final DateTime? dateFromFilter;
  final DateTime? dateToFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onDateTap;
  final VoidCallback onNewOrderTap;
  final VoidCallback onProfileTap;
  final VoidCallback onBack;
  final VoidCallback? onOpenMenu;
  final VoidCallback onClearDate;
  final VoidCallback onClearStatus;
  final VoidCallback onClearAllFilters;

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
    final provider = context.watch<PrimarySaleProvider>();
    final orders = provider.recentOrders;

    final bool hasDateFilter = dateFromFilter != null && dateToFilter != null;
    final bool hasStatusFilter = statusFilter != 'all';
    final bool hasAnyFilter = hasDateFilter || hasStatusFilter;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton:
          context.watch<AuthProvider>().canView(AppScreen.createPrimarySale)
              ? SsCreateFab(
                  label: 'New Sales Order',
                  onPressed: onNewOrderTap,
                )
              : null,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: onOpenMenu != null
            ? IconButton(
                tooltip: 'Menu',
                icon: const Icon(
                  Icons.menu,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                onPressed: onOpenMenu,
              )
            : IconButton(
                tooltip: 'Back',
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                onPressed: onBack,
              ),
        title: const Text(
          'Sales Orders',
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
            child: ProfileAvatar(onTap: onProfileTap),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderMuted, height: 1),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              context.read<PrimarySaleProvider>().fetchRecentOrders(
                search: orderSearchController.text,
                status: statusFilter,
                dateFrom: dateFromFilter,
                dateTo: dateToFilter,
              ),
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
                controller: orderSearchController,
                decoration: InputDecoration(
                  hintText: 'Search orders by name or distributor code...',
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
                onChanged: onSearchChanged,
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
                          ? '${ssFormatDate(dateFromFilter!)} - ${ssFormatDate(dateToFilter!)}'
                          : 'Date',
                      onTap: onDateTap,
                    ),
                    const SizedBox(width: 12),
                    PopupMenuButton<String>(
                      initialValue: statusFilter,
                      onSelected: onStatusChanged,
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
                        label: _getStatusLabel(statusFilter),
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
                                '${ssFormatDate(dateFromFilter!)} - ${ssFormatDate(dateToFilter!)}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: onClearDate,
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
                                'Status: ${_getStatusLabel(statusFilter)}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: onClearStatus,
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
                        onPressed: onClearAllFilters,
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

              // Today's Sales Orders Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Today's Sales Orders",
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
                      '${orders.length} ${orders.length == 1 ? "Order" : "Orders"}',
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
              if (provider.error != null) ErrorPanel(provider.error!),
              if (provider.isLoading && orders.isEmpty)
                const LoadingState()
              else if (orders.isEmpty)
                const EmptyPanel(message: 'No orders found')
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return SalesOrderCard(
                      order: order,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OrderDetailScreen(
                              orderId: order.id,
                              fallbackName: order.name,
                            ),
                          ),
                        );
                        if (context.mounted) {
                          context.read<PrimarySaleProvider>().fetchRecentOrders(
                            search: orderSearchController.text,
                            status: statusFilter,
                            dateFrom: dateFromFilter,
                            dateTo: dateToFilter,
                          );
                        }
                      },
                      onEditTap: () async {
                        final hub = provider.hubs.firstWhere(
                          (h) => h.name == order.hubName,
                          orElse: () => DistributionHub(
                            id: 0,
                            name: order.hubName,
                            address: null,
                          ),
                        );
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CreatePrimarySaleScreen(
                              hub: hub,
                              editOrderId: order.id,
                            ),
                          ),
                        );
                        if (context.mounted) {
                          context.read<PrimarySaleProvider>().fetchRecentOrders(
                            search: orderSearchController.text,
                            status: statusFilter,
                            dateFrom: dateFromFilter,
                            dateTo: dateToFilter,
                          );
                        }
                      },
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
