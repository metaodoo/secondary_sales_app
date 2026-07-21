import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/features/contacts/screens/distributor_detail_screen.dart';
import 'package:secondary_sales/core/widgets/dashboard_cards.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';

class DealersTab extends StatefulWidget {
  const DealersTab({
    super.key,
    this.onProfileTap,
    this.onBack,
    this.onOpenMenu,
  });

  final VoidCallback? onProfileTap;
  final VoidCallback? onBack;
  final VoidCallback? onOpenMenu;

  @override
  State<DealersTab> createState() => _DealersTabState();
}

class _DealersTabState extends State<DealersTab> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      context.read<PrimarySaleProvider>().searchHubs(value);
    });
  }

  Future<void> _openDistributor(int id) async {
    final distributor = await context
        .read<PrimarySaleProvider>()
        .fetchDistributor(id);
    if (!mounted || distributor == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DistributorDetailScreen(distributor: distributor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrimarySaleProvider>();

    return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            BlueHeader(
              title: 'Dealers',
              subtitle: 'Distributor management',
              leading: widget.onOpenMenu != null
                  ? IconButton(
                      tooltip: 'Menu',
                      onPressed: widget.onOpenMenu,
                      icon: const Icon(Icons.menu, color: Colors.white),
                    )
                  : widget.onBack != null
                  ? IconButton(
                      tooltip: 'Back',
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    )
                  : null,
              trailing: widget.onProfileTap != null
                  ? ProfileAvatar(
                      onTap: widget.onProfileTap!,
                      borderColor: Colors.white.withValues(alpha: 0.6),
                    )
                  : null,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => context.read<PrimarySaleProvider>().searchHubs(
                  _searchController.text,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.section),
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: ssInputDecoration(
                        'Search distributor name or code...',
                        Icons.search,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                    const SizedBox(height: 16),
                    if (provider.error != null) ErrorPanel(provider.error!),
                    if (provider.isLoading && provider.hubs.isNotEmpty) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 16),
                    ],
                    if (provider.isLoading && provider.hubs.isEmpty)
                      const LoadingState()
                    else if (provider.hubs.isEmpty)
                      const EmptyPanel(message: 'No distributors found')
                    else
                      ...provider.hubs.map(
                        (hub) => DistributorCard(
                          hub: hub,
                          onTap: () => _openDistributor(hub.id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
