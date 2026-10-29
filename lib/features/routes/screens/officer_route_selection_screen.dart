import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:secondary_sales/features/routes/screens/officer_customer_selection_screen.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/features/employees/employee_provider.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

/// Sorts routes placing today's recommended routes (planned for today's weekday)
/// at the top, followed by other routes in alphabetical order.
List<Map<String, dynamic>> sortRoutesByRecommendation(
  List<Map<String, dynamic>> routes,
  String odooToday,
) {
  final sorted = List<Map<String, dynamic>>.from(routes);
  sorted.sort((a, b) {
    final aDays = (a['planned_days'] as List<dynamic>? ?? []);
    final bDays = (b['planned_days'] as List<dynamic>? ?? []);
    final aRec = aDays.any((d) => d.toString() == odooToday);
    final bRec = bDays.any((d) => d.toString() == odooToday);
    if (aRec && !bRec) return -1;
    if (!aRec && bRec) return 1;
    final aName = (a['name'] as String? ?? '').toLowerCase();
    final bName = (b['name'] as String? ?? '').toLowerCase();
    return aName.compareTo(bName);
  });
  return sorted;
}

class OfficerRouteSelectionScreen extends StatefulWidget {
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
  State<OfficerRouteSelectionScreen> createState() =>
      _OfficerRouteSelectionScreenState();
}

class _OfficerRouteSelectionScreenState
    extends State<OfficerRouteSelectionScreen> {
  bool _sortByRecommended = true;
  // Loaded once, not on every build: a load started in build ran again on
  // each rebuild and notified listeners while the screen was building.
  late Future<List<Map<String, dynamic>>> _routes = _loadRoutes();

  Future<List<Map<String, dynamic>>> _loadRoutes() {
    final employees = context.read<EmployeeProvider>();
    // After the current build, so its notifyListeners does not land in it.
    return Future(employees.fetchRoutes);
  }

  Future<void> _refresh() async {
    setState(() => _routes = _loadRoutes());
    await _routes;
  }

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
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
            size: 28,
          ),
          onPressed:
              widget.onBack ??
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
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ProfileAvatar(onTap: widget.onOpenMenu),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderMuted, height: 1),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _routes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final routes = snapshot.data ?? [];
          final displayRoutes = _sortByRecommended
              ? sortRoutesByRecommendation(routes, odooToday)
              : routes;

          return RefreshIndicator(
            onRefresh: _refresh,
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${displayRoutes.length} Routes',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() => _sortByRecommended = !_sortByRecommended);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _sortByRecommended
                              ? const Color(0xFF10B981)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _sortByRecommended
                                ? const Color(0xFF10B981)
                                : AppColors.borderSoft,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _sortByRecommended ? Icons.check_circle : Icons.sort,
                              size: 15,
                              color: _sortByRecommended ? Colors.white : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _sortByRecommended ? 'Recommended First' : 'Default Order',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _sortByRecommended ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (displayRoutes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Center(
                      child: Text(
                        'No routes assigned.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ...displayRoutes.map((route) {
                  final List<dynamic> plannedDays = route['planned_days'] ?? [];
                  final bool isRecommended = plannedDays.any((d) => d.toString() == odooToday);
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                height: 1.25,
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
