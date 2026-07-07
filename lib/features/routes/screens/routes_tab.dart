import 'dart:async';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/routes/route.dart';
import 'package:secondary_sales/features/routes/route_provider.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/access/permission_gate.dart';
import 'package:secondary_sales/features/routes/screens/create_route_screen.dart';
import 'package:secondary_sales/features/routes/screens/route_detail_screen.dart';

class RoutesTab extends StatefulWidget {
  const RoutesTab({super.key});

  @override
  State<RoutesTab> createState() => _RoutesTabState();
}

class _RoutesTabState extends State<RoutesTab> {
  final TextEditingController _routeSearchController = TextEditingController();
  final TextEditingController _dealerSearchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RouteProvider>().fetchRoutes();
    });
  }

  @override
  void dispose() {
    _routeSearchController.dispose();
    _dealerSearchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final routeQuery = _routeSearchController.text.trim();
      context.read<RouteProvider>().fetchRoutes(search: routeQuery);
    });
  }

  Future<void> _openCreateRoute() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateRouteScreen()),
    );
    if (created == true && mounted) {
      context.read<RouteProvider>().fetchRoutes(
        search: _routeSearchController.text,
      );
    }
  }

  Future<void> _openEditRoute(RouteModel route) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateRouteScreen(route: route)),
    );
    if (updated == true && mounted) {
      context.read<RouteProvider>().fetchRoutes(
        search: _routeSearchController.text,
      );
    }
  }

  void _viewRouteDetail(RouteModel route) {
    context.read<RouteProvider>().setActiveRoute(route);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RouteDetailScreen(routeId: route.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RouteProvider>();

    // Local filter for dealer name search
    final dealerQuery = _dealerSearchController.text.trim().toLowerCase();
    final displayedRoutes = provider.routes.where((route) {
      if (dealerQuery.isEmpty) return true;
      final dealerName = route.distributorName ?? '';
      return dealerName.toLowerCase().contains(dealerQuery);
    }).toList();

    return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // Standard Premium Blue Header
            BlueHeader(
              title: 'Route List',
              subtitle: 'Manage sales routes and outlets',
              trailing: PermissionGate(
                resourceKey: AppAction.routeCreate,
                child: IconButton(
                  onPressed: _openCreateRoute,
                  icon: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ),

            // Search Area
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _routeSearchController,
                    decoration: ssInputDecoration(
                      'Search by Route Name...',
                      Icons.search,
                    ),
                    onChanged: (_) => _onSearchChanged(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _dealerSearchController,
                    decoration: ssInputDecoration(
                      'Search by Dealer Name...',
                      Icons.storefront_outlined,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),

            // Filter status chip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryStrong,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'All Routes (${displayedRoutes.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Route List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => context.read<RouteProvider>().fetchRoutes(
                  search: _routeSearchController.text,
                ),
                child: provider.isLoading && provider.routes.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : displayedRoutes.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: const [
                          EmptyPanel(message: 'No routes found'),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: displayedRoutes.length + 1,
                        itemBuilder: (context, index) {
                          if (index == displayedRoutes.length) {
                            // End of results indicator
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySoft,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primarySoft,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.archive_outlined,
                                      color: Color(0xFF3B82F6),
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'End of results',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Try refining your search terms.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final route = displayedRoutes[index];
                          // Assign icon pattern based on index to look rich
                          final iconData = (index % 4 == 0)
                              ? Icons.alt_route
                              : (index % 4 == 1)
                              ? Icons.local_shipping
                              : (index % 4 == 2)
                              ? Icons.navigation
                              : Icons.map;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: ssPanelDecoration(),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              onTap: () => _viewRouteDetail(route),
                              leading: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  iconData,
                                  color: const Color(0xFF3B82F6),
                                ),
                              ),
                              title: Text(
                                route.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        route.distributorName ??
                                            'Unassigned Dealer',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: IconButton(
                                onPressed: () => _openEditRoute(route),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.primaryStrong,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
        floatingActionButton:
            context.watch<AuthProvider>().canDo(AppAction.routeCreate)
            ? FloatingActionButton(
                heroTag: null,
                onPressed: _openCreateRoute,
                backgroundColor: AppColors.primaryStrong,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, size: 28),
              )
            : null,
      ),
    );
  }
}
