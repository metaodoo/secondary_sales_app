import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/modern_trade/modern_trade_provider.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_outlet.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_customer_action_bottom_sheet.dart';

class MtOutletsScreen extends StatefulWidget {
  const MtOutletsScreen({
    super.key,
    this.onBack,
    this.onOpenMenu,
    this.onProfileTap,
  });

  final VoidCallback? onBack;
  final VoidCallback? onOpenMenu;
  final VoidCallback? onProfileTap;

  @override
  State<MtOutletsScreen> createState() => _MtOutletsScreenState();
}

class _MtOutletsScreenState extends State<MtOutletsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ModernTradeProvider>().fetchOutlets();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openActionModalFor(MtOutlet outlet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MtCustomerActionBottomSheet(outlet: outlet),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ModernTradeProvider>();
    final allOutlets = provider.outlets;
    final filtered = allOutlets.where((o) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = o.name.toLowerCase();
      final code = (o.ssCode ?? '').toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'MT Outlets',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.onOpenMenu != null
            ? IconButton(
                onPressed: widget.onOpenMenu,
                icon: const Icon(Icons.menu, color: AppColors.primaryStrong),
              )
            : widget.onBack != null
            ? IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, color: AppColors.primaryStrong),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: ssInputDecoration(
                  'Search store name or code...',
                  Icons.search,
                ),
              ),
            ),
            Expanded(
              child: provider.isLoading && allOutlets.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => provider.fetchOutlets(),
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No Modern Trade outlets found.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (ctx, i) {
                                final outlet = filtered[i];
                                final isCheckedIn = provider.checkedInOutletId == outlet.id || outlet.isActiveCheckedIn;

                                return GestureDetector(
                                  onTap: () => _openActionModalFor(outlet),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isCheckedIn ? const Color(0xFF10B981) : AppColors.borderSoft,
                                        width: isCheckedIn ? 2 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.primarySoft,
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                          child: const Icon(
                                            Icons.storefront,
                                            color: Color(0xFF3B82F6),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      outlet.name,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                        color: AppColors.textPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                  _buildBadge(outlet),
                                                ],
                                              ),
                                              if (outlet.ssCode != null && outlet.ssCode!.trim().isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Code: ${outlet.ssCode!.trim()}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                              if (outlet.street != null && outlet.street!.trim().isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        outlet.street!.trim(),
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
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(MtOutlet outlet) {
    if (outlet.isRecommended) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: 12, color: Color(0xFF065F46)),
            SizedBox(width: 4),
            Text(
              'Recommended',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF065F46),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Allowed',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      );
    }
  }
}
