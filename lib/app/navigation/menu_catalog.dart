import 'package:flutter/material.dart';

import 'package:secondary_sales/app/navigation/app_shell_config.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';

import 'package:secondary_sales/features/contacts/screens/outlets_list_screen.dart';
import 'package:secondary_sales/features/sales/screens/deliveries_list_screen.dart';
import 'package:secondary_sales/features/sales/screens/secondary_orders_list_screen.dart';
import 'package:secondary_sales/features/returns/screens/returns_list_screen.dart';
import 'package:secondary_sales/features/scraps/screens/scraps_list_screen.dart';
import 'package:secondary_sales/features/routes/screens/visits_list_screen.dart';
import 'package:secondary_sales/features/employees/screens/sales_officer_list_screen.dart';
import 'package:secondary_sales/features/hr/screens/attendance_screen.dart';
import 'package:secondary_sales/features/hr/screens/leave_dashboard_screen.dart';
import 'package:secondary_sales/features/hr/screens/expense_dashboard_screen.dart';
import 'package:secondary_sales/features/hr/screens/location_buffer_screen.dart';

/// Single source of truth for every top-level place the app can navigate to.
///
/// Both the hamburger drawer ([AppDrawer]) and — eventually — the dashboard
/// card grid render from this list, so "what screens exist / who can see them /
/// how you reach them" lives in exactly one file instead of being duplicated
/// across `dashboard_tab.dart`, `settings_tab.dart`, and the bottom nav.
///
/// A destination reaches its screen one of two ways:
///  - [shellIndex] set  → an in-shell tab; the shell switches to it via
///    `_setIndex` (a lateral move that does not grow the back stack).
///  - [builder] set     → a standalone screen pushed above the shell.
///
/// Visibility mirrors today's gating exactly: [visibleWhen] when set (used for
/// the legacy-aware tab getters like `canAccessDealers`), otherwise
/// `canView([screenKey])`, otherwise always visible.
class MenuDestination {
  MenuDestination({
    required this.label,
    required this.icon,
    this.screenKey,
    this.shellIndex,
    this.builder,
    this.visibleWhen,
  }) : assert(
         shellIndex != null || builder != null,
         'A destination must be a shell tab or push a screen.',
       );

  final String label;
  final IconData icon;

  /// RBAC catalog key gating this destination (see [AppScreen]).
  final String? screenKey;

  /// In-shell tab index (see [AppShellIndex]); switched via the shell.
  final int? shellIndex;

  /// Standalone screen to push above the shell.
  final WidgetBuilder? builder;

  /// Custom visibility predicate, used where gating is not a plain
  /// `canView(screenKey)` (e.g. the legacy-aware `canAccessDealers`).
  final bool Function(AuthProvider auth)? visibleWhen;

  bool get isTab => shellIndex != null;

  bool isVisible(AuthProvider auth) {
    if (visibleWhen != null) return visibleWhen!(auth);
    if (screenKey != null) return auth.canView(screenKey!);
    return true;
  }
}

class MenuSection {
  MenuSection(this.title, this.items);

  final String title;
  final List<MenuDestination> items;
}

/// Full (unfiltered) destination catalog for a module. Order and grouping here
/// define the drawer layout. Gating is applied later by [visibleMenuSections].
List<MenuSection> buildMenuSections(String moduleType) {
  final sections = <MenuSection>[];

  if (moduleType == 'primary') {
    sections.add(
      MenuSection('Sales', [
        MenuDestination(
          label: 'Dashboard',
          icon: Icons.grid_view_rounded,
          shellIndex: AppShellIndex.dashboard,
        ),
        MenuDestination(
          label: 'Primary Sales',
          icon: Icons.receipt_long_outlined,
          shellIndex: AppShellIndex.sales,
          visibleWhen: (a) => a.canView(AppScreen.primarySalesList),
        ),
        MenuDestination(
          label: 'Dealers',
          icon: Icons.storefront_outlined,
          shellIndex: AppShellIndex.dealers,
          visibleWhen: (a) => a.canAccessDealers,
        ),
      ]),
    );
    sections.add(
      MenuSection('Fulfillment', [
        MenuDestination(
          label: 'Delivery',
          icon: Icons.local_shipping_outlined,
          screenKey: AppScreen.deliveriesList,
          builder: (_) => const DeliveriesListScreen(moduleType: 'primary'),
        ),
        MenuDestination(
          label: 'Return Delivery',
          icon: Icons.assignment_return_outlined,
          screenKey: AppScreen.returnsList,
          builder: (_) => const ReturnsListScreen(moduleType: 'primary'),
        ),
        MenuDestination(
          label: 'Return Scrap',
          icon: Icons.recycling_outlined,
          screenKey: AppScreen.scrapsList,
          builder: (_) => const ScrapsListScreen(moduleType: 'primary'),
        ),
      ]),
    );
  } else {
    sections.add(
      MenuSection('Sales', [
        MenuDestination(
          label: 'Dashboard',
          icon: Icons.grid_view_rounded,
          shellIndex: AppShellIndex.dashboard,
        ),
        MenuDestination(
          label: 'Sales',
          icon: Icons.shopping_bag_outlined,
          screenKey: AppScreen.secondaryOrdersList,
          builder: (_) => const SecondaryOrdersListScreen(),
        ),
        MenuDestination(
          label: 'Outlets',
          icon: Icons.location_on_outlined,
          screenKey: AppScreen.outletsList,
          builder: (_) => const OutletsListScreen(),
        ),
        MenuDestination(
          label: 'Routes',
          icon: Icons.alt_route_outlined,
          shellIndex: AppShellIndex.routes,
          visibleWhen: (a) => a.canView(AppScreen.routesList),
        ),
      ]),
    );
    sections.add(
      MenuSection('Field & Inventory', [
        MenuDestination(
          label: 'Van Operations',
          icon: Icons.local_shipping_outlined,
          shellIndex: AppShellIndex.vanLoading,
          visibleWhen: (a) => a.canView(AppScreen.vanOperationsList),
        ),
        MenuDestination(
          label: 'Delivery',
          icon: Icons.inventory_2_outlined,
          screenKey: AppScreen.secondaryDeliveriesList,
          builder: (_) => const DeliveriesListScreen(moduleType: 'secondary'),
        ),
        MenuDestination(
          label: 'Scrap Operation',
          icon: Icons.recycling_outlined,
          screenKey: AppScreen.secondaryScrapsList,
          builder: (_) => const ScrapsListScreen(moduleType: 'secondary'),
        ),
        MenuDestination(
          label: 'Visit History',
          icon: Icons.history_edu_outlined,
          screenKey: AppScreen.visitsList,
          builder: (_) => const VisitsListScreen(),
        ),
      ]),
    );
  }

  // Shared across both modules (mirrors settings_tab.dart entries).
  sections.add(
    MenuSection('Workforce', [
      MenuDestination(
        label: 'Attendance',
        icon: Icons.access_time_filled_outlined,
        screenKey: AppScreen.moduleAttendance,
        builder: (_) => const AttendanceScreen(),
      ),
      MenuDestination(
        label: 'Leave Request',
        icon: Icons.event_busy_outlined,
        screenKey: AppScreen.moduleLeave,
        builder: (_) => const LeaveDashboardScreen(),
      ),
      MenuDestination(
        label: 'Expense',
        icon: Icons.receipt_long_outlined,
        screenKey: AppScreen.moduleExpense,
        builder: (_) => const ExpenseDashboardScreen(),
      ),
      MenuDestination(
        label: 'Sales Officers',
        icon: Icons.people_outline,
        screenKey: AppScreen.salesOfficerList,
        builder: (_) => const SalesOfficerListScreen(),
      ),
      MenuDestination(
        label: 'Location Buffer',
        icon: Icons.storage_outlined,
        builder: (_) => const LocationBufferScreen(),
      ),
    ]),
  );

  sections.add(
    MenuSection('Account', [
      MenuDestination(
        label: 'Settings',
        icon: Icons.settings_outlined,
        shellIndex: AppShellIndex.profile,
      ),
    ]),
  );

  return sections;
}

/// The catalog with each destination RBAC-filtered for [auth], dropping any
/// section left empty. This is what the drawer renders.
List<MenuSection> visibleMenuSections(String moduleType, AuthProvider auth) {
  return buildMenuSections(moduleType)
      .map(
        (s) => MenuSection(
          s.title,
          s.items.where((d) => d.isVisible(auth)).toList(growable: false),
        ),
      )
      .where((s) => s.items.isNotEmpty)
      .toList(growable: false);
}
