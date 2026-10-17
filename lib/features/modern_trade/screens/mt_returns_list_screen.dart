import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_return_request.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/modern_trade/mt_return_provider.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_return_create_screen.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_return_detail_screen.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_return_type_sheet.dart';

class MtReturnsListScreen extends StatefulWidget {
  final String returnBucket; // 'saleable' or 'non_saleable'
  final String title;
  final String? createScreenKey;
  final String? createActionKey;

  const MtReturnsListScreen({
    super.key,
    required this.returnBucket,
    required this.title,
    this.createScreenKey,
    this.createActionKey,
  });

  @override
  State<MtReturnsListScreen> createState() => _MtReturnsListScreenState();
}

class _MtReturnsListScreenState extends State<MtReturnsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  final List<({String key, String label})> _stages = const [
    (key: 'all', label: 'All'),
    (key: 'kao', label: 'KAO (Draft)'),
    (key: 'dm', label: 'DM Review'),
    (key: 'kas', label: 'KAS Review'),
    (key: 'supply_chain', label: 'Supply Chain'),
    (key: 'qc', label: 'QC Review'),
    (key: 'sales_operation', label: 'Sales Operation'),
    (key: 'confirmed', label: 'Confirmed'),
  ];

  final List<({String key, String label, IconData icon})> _sortOptions = const [
    (key: 'date desc, id desc', label: 'Date: Newest first', icon: Icons.schedule),
    (key: 'date asc, id asc', label: 'Date: Oldest first', icon: Icons.history),
    (key: 'partner_id asc, id desc', label: 'Outlet: A to Z', icon: Icons.sort_by_alpha),
    (key: 'partner_id desc, id desc', label: 'Outlet: Z to A', icon: Icons.sort_by_alpha),
    (key: 'name asc, id desc', label: 'Reference: A to Z', icon: Icons.tag),
    (key: 'name desc, id desc', label: 'Reference: Z to A', icon: Icons.tag),
    (key: 'state asc, date desc', label: 'Status / Stage', icon: Icons.flag_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<MtReturnProvider>();
      p.fetchPrepareContext();
      p.fetchReturns(
        returnBucket: widget.returnBucket,
        refresh: true,
      );
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        context.read<MtReturnProvider>().setSearchQuery(val.trim(), returnBucket: widget.returnBucket);
      }
    });
  }

  Future<void> _selectDateRange() async {
    final provider = context.read<MtReturnProvider>();
    final now = DateTime.now();
    final initialStart = provider.dateFrom ?? now;
    final initialEnd = provider.dateTo ?? now;
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
      provider.setDateRange(picked.start, picked.end, returnBucket: widget.returnBucket);
    }
  }

  void _clearDateFilter() {
    context.read<MtReturnProvider>().setDateRange(null, null, returnBucket: widget.returnBucket);
  }

  String _formatDateRange(DateTime? from, DateTime? to) {
    if (from == null && to == null) return 'All Dates';
    if (from != null && to != null) {
      final isSameDay = from.year == to.year && from.month == to.month && from.day == to.day;
      if (isSameDay) {
        final now = DateTime.now();
        final isToday = from.year == now.year && from.month == now.month && from.day == now.day;
        return isToday ? 'Today (${DateFormat('dd MMM').format(from)})' : DateFormat('dd MMM yyyy').format(from);
      }
      return '${DateFormat('dd MMM').format(from)} - ${DateFormat('dd MMM').format(to)}';
    }
    if (from != null) return 'From ${DateFormat('dd MMM').format(from)}';
    return 'Until ${DateFormat('dd MMM').format(to!)}';
  }

  String _selectedOutletName(MtReturnProvider provider) {
    if (provider.selectedOutletId == null) return 'All Outlets';
    final match = provider.allowedOutlets.firstWhere(
      (o) => o['id'] == provider.selectedOutletId,
      orElse: () => <String, dynamic>{},
    );
    if (match.isNotEmpty) {
      final name = match['name']?.toString() ?? 'Outlet';
      return name.length > 15 ? '${name.substring(0, 13)}...' : name;
    }
    return 'Outlet #${provider.selectedOutletId}';
  }

  void _openOutletFilterModal(MtReturnProvider provider) {
    final outlets = provider.allowedOutlets;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        Timer? modalDebounce;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredOutlets = outlets.where((o) {
              if (searchQuery.isEmpty) return true;
              final name = (o['name'] ?? '').toString().toLowerCase();
              final code = (o['ss_code'] ?? '').toString().toLowerCase();
              final q = searchQuery.toLowerCase();
              return name.contains(q) || code.contains(q);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Filter by Outlet (${outlets.length})',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  modalDebounce?.cancel();
                                  Navigator.pop(ctx);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            onChanged: (val) {
                              modalDebounce?.cancel();
                              modalDebounce = Timer(const Duration(milliseconds: 300), () {
                                setModalState(() {
                                  searchQuery = val.trim();
                                });
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search outlet name or code...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.borderSoft),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filteredOutlets.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final isAllSelected = provider.selectedOutletId == null;
                            return ListTile(
                              leading: const Icon(Icons.storefront_outlined, color: AppColors.primaryStrong),
                              title: const Text('All Allowed Outlets', style: TextStyle(fontWeight: FontWeight.w600)),
                              trailing: isAllSelected
                                  ? const Icon(Icons.check, color: AppColors.primaryStrong)
                                  : null,
                              onTap: () {
                                modalDebounce?.cancel();
                                Navigator.pop(ctx);
                                provider.setOutletFilter(null, returnBucket: widget.returnBucket);
                              },
                            );
                          }
                          final o = filteredOutlets[index - 1];
                          final id = o['id'] as int?;
                          final name = o['name']?.toString() ?? '';
                          final ssCode = o['ss_code']?.toString() ?? '';
                          final isSelected = provider.selectedOutletId == id;

                          return ListTile(
                            leading: Icon(
                              Icons.storefront,
                              color: isSelected ? AppColors.primaryStrong : Colors.grey.shade600,
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? AppColors.primaryStrong : AppColors.textPrimary,
                              ),
                            ),
                            subtitle: ssCode.isNotEmpty
                                ? Text('Code: $ssCode', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
                                : null,
                            trailing: isSelected
                                ? const Icon(Icons.check, color: AppColors.primaryStrong)
                                : null,
                            onTap: () {
                              modalDebounce?.cancel();
                              Navigator.pop(ctx);
                              provider.setOutletFilter(id, returnBucket: widget.returnBucket);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<MtReturnProvider>().loadMore(returnBucket: widget.returnBucket);
    }
  }

  void _onCreate() async {
    if (widget.returnBucket == 'saleable') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MtReturnCreateScreen(
            returnBucket: widget.returnBucket,
            returnType: 'return',
            title: 'New ${widget.title.replaceAll("Returns", "Return")}',
          ),
        ),
      );
      return;
    }

    final selectedType = await showMtReturnTypePicker(
      context,
      returnBucket: widget.returnBucket,
    );

    if (selectedType == null || !mounted) return;

    final typeLabel = selectedType == 'return' ? 'Return' : 'Replacement';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MtReturnCreateScreen(
          returnBucket: widget.returnBucket,
          returnType: selectedType,
          title: 'New ${widget.returnBucket == "quality" ? "Quality" : "Non-Saleable"} ($typeLabel)',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MtReturnProvider>();
    final auth = context.watch<AuthProvider>();

    final specificActionKey = widget.returnBucket == 'saleable'
        ? AppAction.mtSaleableReturnCreate
        : (widget.returnBucket == 'quality'
            ? AppAction.mtQualityReturnCreate
            : AppAction.mtNonSaleableReturnCreate);
    final specificScreenKey = widget.returnBucket == 'saleable'
        ? AppScreen.mtSaleableReturnsCreate
        : (widget.returnBucket == 'quality'
            ? AppScreen.mtQualityReturnsCreate
            : AppScreen.mtNonSaleableReturnsCreate);

    final canCreate = auth.canDo(specificActionKey) ||
        (widget.createActionKey != null && auth.canDo(widget.createActionKey!)) ||
        auth.canView(specificScreenKey) ||
        (widget.createScreenKey != null && auth.canView(widget.createScreenKey!));

    final isDateActive = provider.dateFrom != null || provider.dateTo != null;
    final isOutletActive = provider.selectedOutletId != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _onCreate,
              backgroundColor: AppColors.primaryStrong,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'New ${widget.returnBucket == "saleable" ? "Saleable" : (widget.returnBucket == "quality" ? "Quality" : "Non-Saleable")}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            )
          : null,
      body: Column(
        children: [
          // Search & Filters Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by reference or outlet name...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              provider.setSearchQuery('', returnBucket: widget.returnBucket);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: (val) => provider.setSearchQuery(val.trim(), returnBucket: widget.returnBucket),
                ),
                const SizedBox(height: 8),

                // Date Range, Outlet Filter & Sort Toolbar
                Row(
                  children: [
                    // Date Filter Button
                    Expanded(
                      flex: 4,
                      child: InkWell(
                        onTap: _selectDateRange,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: isDateActive ? AppColors.primarySoft : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDateActive ? AppColors.primaryStrong : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                size: 16,
                                color: isDateActive ? AppColors.primaryStrong : Colors.grey.shade700,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _formatDateRange(provider.dateFrom, provider.dateTo),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isDateActive ? FontWeight.w700 : FontWeight.w500,
                                    color: isDateActive ? AppColors.primaryStrong : AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isDateActive)
                                InkWell(
                                  onTap: _clearDateFilter,
                                  child: const Icon(Icons.close, size: 14, color: AppColors.primaryStrong),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Outlet Filter Button
                    Expanded(
                      flex: 4,
                      child: InkWell(
                        onTap: () => _openOutletFilterModal(provider),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: isOutletActive ? AppColors.primarySoft : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isOutletActive ? AppColors.primaryStrong : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.storefront_outlined,
                                size: 16,
                                color: isOutletActive ? AppColors.primaryStrong : Colors.grey.shade700,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _selectedOutletName(provider),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isOutletActive ? FontWeight.w700 : FontWeight.w500,
                                    color: isOutletActive ? AppColors.primaryStrong : AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isOutletActive)
                                InkWell(
                                  onTap: () => provider.setOutletFilter(null, returnBucket: widget.returnBucket),
                                  child: const Icon(Icons.close, size: 14, color: AppColors.primaryStrong),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Sort Button
                    PopupMenuButton<String>(
                      tooltip: 'Sort returns',
                      initialValue: provider.sortOrder,
                      onSelected: (val) => provider.setSortOrder(val, returnBucket: widget.returnBucket),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (ctx) => _sortOptions.map((opt) {
                        final isSelected = provider.sortOrder == opt.key;
                        return PopupMenuItem<String>(
                          value: opt.key,
                          child: Row(
                            children: [
                              Icon(
                                opt.icon,
                                size: 18,
                                color: isSelected ? AppColors.primaryStrong : Colors.grey.shade700,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  opt.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                    color: isSelected ? AppColors.primaryStrong : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check, size: 16, color: AppColors.primaryStrong),
                            ],
                          ),
                        );
                      }).toList(),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_vert, size: 18, color: AppColors.primaryStrong),
                            SizedBox(width: 2),
                            Text(
                              'Sort',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryStrong),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Status Filter Chips
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _stages.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final stage = _stages[index];
                      final isSelected = provider.selectedStateFilter == stage.key;
                      return ChoiceChip(
                        label: Text(stage.label),
                        selected: isSelected,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                        selectedColor: AppColors.primaryStrong,
                        backgroundColor: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onSelected: (_) => provider.setStateFilter(stage.key, returnBucket: widget.returnBucket),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // List Body
          Expanded(
            child: provider.isLoading && provider.returns.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.returns.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_return_outlined, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No ${widget.title.toLowerCase()} found',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try changing search filters or create a new return request',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => provider.fetchReturns(returnBucket: widget.returnBucket, refresh: true),
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: provider.returns.length + (provider.isLoadingMore ? 1 : 0),
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index == provider.returns.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final rr = provider.returns[index];
                            return _buildReturnCard(rr);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnCard(MtReturnRequest rr) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MtReturnDetailScreen(returnId: rr.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    rr.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!rr.isSaleable) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: rr.isDirectReturn ? Colors.deepOrange.shade50 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: rr.isDirectReturn ? Colors.deepOrange.shade300 : Colors.blue.shade300,
                          ),
                        ),
                        child: Text(
                          rr.returnTypeDisplay,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: rr.isDirectReturn ? Colors.deepOrange.shade800 : Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                    _buildStatusBadge(rr.state, rr.stateDisplay),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              rr.partnerName ?? 'Outlet',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (rr.ssCode != null && rr.ssCode!.isNotEmpty)
              Text('SS Code: ${rr.ssCode}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (rr.date != null) ...[
                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(rr.date!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(width: 12),
                    ],
                    if (rr.pickingCount > 0) ...[
                      const Icon(Icons.local_shipping_outlined, size: 15, color: Colors.indigo),
                      const SizedBox(width: 4),
                      Text(
                        '${rr.pickingCount} Transfers',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigo),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Total: ${rr.totalQty.toStringAsFixed(rr.totalQty.truncateToDouble() == rr.totalQty ? 0 : 2)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryStrong),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String state, String label) {
    Color bg;
    Color fg;
    switch (state.toLowerCase()) {
      case 'confirmed':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case 'sales_operation':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        break;
      case 'qc':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade700;
        break;
      case 'supply_chain':
        bg = Colors.indigo.shade50;
        fg = Colors.indigo.shade700;
        break;
      case 'kas':
        bg = Colors.cyan.shade50;
        fg = Colors.cyan.shade800;
        break;
      case 'dm':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      default: // kao
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}
