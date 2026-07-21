import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:secondary_sales/features/routes/screens/officer_customer_selection_screen.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/features/employees/employee_provider.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class OfficerRouteSelectionScreen extends StatelessWidget {
  const OfficerRouteSelectionScreen({
    super.key,
    this.onProfileTap,
    this.onBack,
    this.onOpenMenu,
  });

  final VoidCallback? onProfileTap;
  final VoidCallback? onBack;
  final VoidCallback? onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final String todayDate = DateFormat('MMMM d').format(DateTime.now());
    final int todayWeekday = DateTime.now().weekday; // 1 = Mon, 7 = Sun
    // Odoo weekday mapping: 0 = Mon, 6 = Sun
    final String odooToday = (todayWeekday - 1).toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: onOpenMenu != null
            ? IconButton(
                icon: const Icon(
                  Icons.menu,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                onPressed: onOpenMenu,
              )
            : IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                onPressed:
                    onBack ??
                    () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
              ),
        title: const Text(
          'Routes',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          if (onProfileTap != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ProfileAvatar(onTap: onProfileTap!),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderMuted, height: 1),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: Provider.of<EmployeeProvider>(
          context,
          listen: false,
        ).fetchRoutes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final routes = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: () => Provider.of<EmployeeProvider>(
              context,
              listen: false,
            ).fetchRoutes(),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              children: [
                const Text(
                  "TODAY'S ASSIGNMENTS",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select Your Route',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Optimize your visits by selecting the assigned zone for $todayDate.',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ...routes.map((route) {
                  final List<dynamic> plannedDays = route['planned_days'] ?? [];
                  final bool isRecommended = plannedDays.contains(odooToday);
                  final int outletCount = route['outlet_count'] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _buildRouteCard(
                      context,
                      routeId: route['id'],
                      title: route['name'] ?? 'Unnamed Route',
                      outletCount: outletCount,
                      icon: Icons.location_on,
                      isRecommended: isRecommended,
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRouteCard(
    BuildContext context, {
    required int routeId,
    required String title,
    required int outletCount,
    required IconData icon,
    Color iconBgColor = AppColors.primaryStrong,
    Color iconColor = Colors.white,
    bool isRecommended = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OfficerCustomerSelectionScreen(
              routeId: routeId,
              routeName: title,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSoft),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                if (isRecommended)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Color(0xFF10B981),
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Recommended',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$outletCount Outlets',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
