import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/features/sales/screens/create_primary_sale_screen.dart';
import 'package:secondary_sales/core/widgets/dashboard_cards.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class OrderTab extends StatelessWidget {
  const OrderTab({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    this.onBack,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrimarySaleProvider>();
    final hubs = provider.hubs;

    return SafeArea(
      child: Column(
        children: [
          BlueHeader(
            title: 'New Order',
            subtitle: 'Create sales order',
            leading: onBack != null
                ? IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  )
                : null,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await provider.searchHubs(searchController.text);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: searchController,
                    decoration: ssInputDecoration(
                      'Search customer name or code...',
                      Icons.search,
                    ),
                    onChanged: onSearchChanged,
                  ),
                  const SizedBox(height: 16),
                  if (provider.error != null) ErrorPanel(provider.error!),
                  if (provider.isLoading && hubs.isNotEmpty) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                  ],
                  if (provider.isLoading && hubs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (hubs.isEmpty)
                    const EmptyPanel(message: 'No distributors found')
                  else
                    ...hubs.map(
                      (hub) => DistributorCard(
                        hub: hub,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreatePrimarySaleScreen(hub: hub),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
