import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/app/navigation/app_shell_config.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
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
  });

  final ValueChanged<int> onModuleSelected;
  final bool showDealerModule;
  final bool showPrimarySalesModule;
  final bool showSecondarySalesModule;
  final String moduleType;
  final VoidCallback onBackToModules;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final userName = user?.employeeName ?? user?.name ?? 'User';
    final firstName = userName.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back to modules',
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
            size: 28,
          ),
          onPressed: onBackToModules,
        ),
        title: const Text(
          'Dashboard',
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
            child: ProfileAvatar(
              onTap: () => onModuleSelected(AppShellIndex.profile),
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
                'Welcome back, $firstName',
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
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.05,
                children: [
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
                    _buildModuleCard(
                      title: 'Delivery',
                      icon: Icons.local_shipping_outlined,
                      iconColor: AppColors.primary,
                      circleColor: AppColors.primarySoft,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DeliveriesListScreen(moduleType: 'primary'),
                          ),
                        );
                      },
                    ),
                    _buildModuleCard(
                      title: 'Return Delivery',
                      icon: Icons.assignment_return_outlined,
                      iconColor: AppColors.primary,
                      circleColor: AppColors.borderMuted,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReturnsListScreen(moduleType: 'primary'),
                          ),
                        );
                      },
                    ),
                    _buildModuleCard(
                      title: 'Return Scrap',
                      icon: Icons.recycling_outlined,
                      iconColor: AppColors.primary,
                      circleColor: AppColors.borderMuted,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScrapsListScreen(moduleType: 'primary'),
                          ),
                        );
                      },
                    ),
                  ] else ...[
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
                    _buildModuleCard(
                      title: 'Routes',
                      icon: Icons.alt_route,
                      iconColor: AppColors.primary,
                      circleColor: AppColors.primaryTint,
                      onTap: () => onModuleSelected(AppShellIndex.routes),
                    ),
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
                    _buildModuleCard(
                      title: 'Van Operations',
                      icon: Icons.local_shipping_outlined,
                      iconColor: AppColors.primary,
                      circleColor: AppColors.borderMuted,
                      onTap: () => onModuleSelected(AppShellIndex.vanLoading),
                    ),
                    _buildModuleCard(
                      title: 'Delivery (Secondary)',
                      icon: Icons.inventory_2_outlined,
                      iconColor: AppColors.primary,
                      circleColor: AppColors.primarySoft,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DeliveriesListScreen(moduleType: 'secondary'),
                          ),
                        );
                      },
                    ),
                    _buildModuleCard(
                      title: 'Scrap Operation',
                      icon: Icons.recycling_outlined,
                      iconColor: AppColors.primary,
                      circleColor: AppColors.borderMuted,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScrapsListScreen(moduleType: 'secondary'),
                          ),
                        );
                      },
                    ),
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
                ],
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
