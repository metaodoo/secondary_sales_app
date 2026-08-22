import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/app/navigation/app_shell_config.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/constants.dart';
import 'package:secondary_sales/features/contacts/screens/outlets_list_screen.dart';
import 'package:secondary_sales/features/sales/screens/deliveries_list_screen.dart';
import 'package:secondary_sales/features/returns/screens/returns_list_screen.dart';
import 'package:secondary_sales/features/scraps/screens/scraps_list_screen.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

import 'package:secondary_sales/features/sales/screens/secondary_orders_list_screen.dart';
import 'package:secondary_sales/features/routes/screens/visits_list_screen.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({
    super.key,
    required this.onModuleSelected,
    required this.showDealerModule,
    this.showPrimarySalesModule = true,
    this.showSecondarySalesModule = true,
    required this.moduleType,
    required this.onBackToModules,
    this.onOpenMenu,
  });

  final ValueChanged<int> onModuleSelected;
  final bool showDealerModule;
  final bool showPrimarySalesModule;
  final bool showSecondarySalesModule;
  final String moduleType;
  final VoidCallback onBackToModules;

  /// Opens the global navigation drawer. When provided, the app-bar leading
  /// becomes a hamburger; otherwise it falls back to the back-to-modules arrow.
  final VoidCallback? onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final userName = user?.employeeName ?? user?.name;
    final firstName = firstNameFromName(userName);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: onBackToModules != null
            ? IconButton(
                tooltip: 'Back to modules',
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                onPressed: onBackToModules,
              )
            : null,
        title: Text(
          moduleType == 'primary' ? 'Primary Sales' : 'Secondary Sales',
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
            child: ProfileAvatar(
              onTap: onOpenMenu,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderMuted, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'Welcome back, ${userName ?? 'User'}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a module to manage your activities.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 48),
              Builder(
                builder: (context) {
                  final cards = <Widget>[
                    if (moduleType == 'primary') ...[
                      if (showPrimarySalesModule)
                        _buildModuleCard(
                          title: 'Sales',
                          icon: Icons.bar_chart,
                          iconColor: Colors.white,
                          circleColor: AppColors.primaryStrong,
                          onTap: () => onModuleSelected(AppShellIndex.sales),
                        ),
                      if (showDealerModule)
                        _buildModuleCard(
                          title: 'Dealers',
                          icon: Icons.storefront,
                          iconColor: Colors.white,
                          circleColor: AppColors.primary,
                          onTap: () => onModuleSelected(AppShellIndex.dealers),
                        ),
                      if (auth.canView(AppScreen.deliveriesList))
                        _buildModuleCard(
                          title: 'Delivery',
                          icon: Icons.local_shipping_outlined,
                          iconColor: AppColors.primary,
                          circleColor: AppColors.primarySoft,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DeliveriesListScreen(
                                  moduleType: 'primary',
                                ),
                              ),
                            );
                          },
                        ),
                      if (auth.canView(AppScreen.returnsListFor(moduleType)))
                        _buildModuleCard(
                          title: moduleType == 'primary' ? 'Fresh Return' : 'Return Delivery',
                          icon: Icons.assignment_return_outlined,
                          iconColor: AppColors.primary,
                          circleColor: AppColors.borderMuted,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReturnsListScreen(
                                  moduleType: moduleType,
                                  title: moduleType == 'primary' ? 'Fresh Returns' : 'Returns List',
                                  createLabel: moduleType == 'primary' ? 'New Fresh Return' : 'New Return',
                                  createScreenTitle: moduleType == 'primary' ? 'Fresh Return' : 'Returns',
                                  productSelectionTitle: moduleType == 'primary' ? 'Select Fresh Return Products' : 'Select Return Products',
                                  endpoint: AppConstants.returnsEndpoint,
                                ),
                              ),
                            );
                          },
                        ),
                      if (moduleType == 'primary' && auth.canView(AppScreen.qcReturnsList))
                        _buildModuleCard(
                          title: 'QC Return',
                          icon: Icons.verified_outlined,
                          iconColor: AppColors.primary,
                          circleColor: AppColors.primarySoft,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ReturnsListScreen(
                                  moduleType: 'primary',
                                  title: 'QC Returns',
                                  createLabel: 'New QC Return',
                                  createScreenTitle: 'QC Return',
                                  productSelectionTitle: 'Select QC Return Products',
                                  endpoint: AppConstants.qcReturnsEndpoint,
                                  createActionKey: AppAction.qcReturnCreate,
                                ),
                              ),
                            );
                          },
                        ),
                      if (auth.canView(AppScreen.scrapsListFor(moduleType)))
                        _buildModuleCard(
                          title: moduleType == 'primary' ? 'Damaged Return' : 'Return Scrap',
                          icon: Icons.recycling_outlined,
                          iconColor: AppColors.primary,
                          circleColor: AppColors.borderMuted,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScrapsListScreen(
                                  moduleType: moduleType,
                                  title: moduleType == 'primary' ? 'Damaged Returns' : 'Scraps List',
                                  createLabel: moduleType == 'primary' ? 'New Damaged Return' : 'New Scrap',
                                  createScreenTitle: moduleType == 'primary' ? 'Damaged Return' : 'Scraps',
                                  productSelectionTitle: moduleType == 'primary' ? 'Select Damaged Return Products' : 'Select Scrap Products',
                                ),
                              ),
                            );
                          },
                        ),
                    ] else ...[
                      if (auth.canView(AppScreen.secondaryOrdersList))
                        _buildModuleCard(
                          title: 'Sales (Secondary)',
                          icon: Icons.shopping_bag_outlined,
                          iconColor: AppColors.primary,
                          circleColor: AppColors.primarySoft,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SecondaryOrdersListScreen(),
                              ),
                            );
                          },
                        ),
                      if (auth.canView(AppScreen.routesList))
                        _buildModuleCard(
                          title: 'Routes',
                          icon: Icons.alt_route,
                          iconColor: AppColors.primary,
                          circleColor: AppColors.primaryTint,
                          onTap: () => onModuleSelected(AppShellIndex.routes),
                        ),
                      if (auth.canView(AppScreen.outletsList))
                        _buildModuleCard(
                          title: 'Outlets',
                          icon: Icons.location_on_outlined,
                          iconColor: AppColors.primary,
                          circleColor: AppColors.primarySoft,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const OutletsListScreen(),
                              ),
                            );
                          },
                        ),
                      if (auth.canView(AppScreen.vanOperationsList))
                        _buildModuleCard(
                          title: 'Van Load',
                          icon: Icons.local_shipping_outlined,
                          iconColor: AppColors.primary,
                          circleColor: AppColors.borderMuted,
                          onTap: () => onModuleSelected(AppShellIndex.vanLoad),
                        ),
                      if (auth.canView(AppScreen.vanOperationsList))
                        _buildModuleCard(
                          title: 'Van Unload',
                          icon: Icons.unarchive_outlined,
                          iconColor: AppColors.primary,
                          circleColor: AppColors.borderMuted,
                          onTap: () => onModuleSelected(AppShellIndex.vanUnload),
                        ),
                      if (auth.canView(AppScreen.secondaryDeliveriesList))
                        _buildModuleCard(
                          title: 'Delivery (Secondary)',
                          icon: Icons.inventory_2_outlined,
                          iconColor: AppColors.primary,
                          circleColor: AppColors.primarySoft,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DeliveriesListScreen(
                                  moduleType: 'secondary',
                                ),
                              ),
                            );
                          },
                        ),
                      if (false && auth.canView(AppScreen.secondaryReturnsList))
                        _buildModuleCard(
                          title: 'Return Delivery',
                          icon: Icons.assignment_return_outlined,
                          iconColor: AppColors.primary,
                          circleColor: AppColors.borderMuted,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ReturnsListScreen(
                                  moduleType: 'secondary',
                                ),
                              ),
                            );
                          },
                        ),
                      if (false && auth.canView(AppScreen.secondaryScrapsList))
                        _buildModuleCard(
                          title: 'Return Scrap',
                          icon: Icons.recycling_outlined,
                          iconColor: AppColors.primary,
                          circleColor: AppColors.borderMuted,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ScrapsListScreen(
                                  moduleType: 'secondary',
                                ),
                              ),
                            );
                          },
                        ),
                      if (auth.canView(AppScreen.visitsList))
                        _buildModuleCard(
                          title: 'Visit History',
                          icon: Icons.history_edu,
                          iconColor: AppColors.primary,
                          circleColor: AppColors.primaryTint,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const VisitsListScreen(),
                              ),
                            );
                          },
                        ),
                    ],
                  ];

                  if (cards.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'No modules accessible.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }

                  return GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.05,
                    children: cards,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color circleColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: circleColor,
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
