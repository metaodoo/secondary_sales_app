import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_return_request.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/modern_trade/mt_return_provider.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_return_create_screen.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_return_detail_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MtReturnProvider>().fetchReturns(
            returnBucket: widget.returnBucket,
            refresh: true,
          );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<MtReturnProvider>().loadMore(returnBucket: widget.returnBucket);
    }
  }

  void _onCreate() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MtReturnCreateScreen(
          returnBucket: widget.returnBucket,
          title: 'New ${widget.title.replaceAll("Returns", "Return")}',
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
        : AppAction.mtNonSaleableReturnCreate;
    final specificScreenKey = widget.returnBucket == 'saleable'
        ? AppScreen.mtSaleableReturnsCreate
        : AppScreen.mtNonSaleableReturnsCreate;

    final canCreate = auth.canDo(specificActionKey) ||
        (widget.createActionKey != null && auth.canDo(widget.createActionKey!)) ||
        auth.canView(specificScreenKey) ||
        (widget.createScreenKey != null && auth.canView(widget.createScreenKey!));

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
                'New ${widget.returnBucket == "saleable" ? "Saleable" : "Non-Saleable"}',
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
                  onChanged: (val) {
                    setState(() {});
                    provider.setSearchQuery(val, returnBucket: widget.returnBucket);
                  },
                  onSubmitted: (val) => provider.setSearchQuery(val, returnBucket: widget.returnBucket),
                ),
                const SizedBox(height: 10),
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
              color: Colors.black.withOpacity(0.02),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rr.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                _buildStatusBadge(rr.state, rr.stateDisplay),
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
        border: Border.all(color: fg.withOpacity(0.35)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}
