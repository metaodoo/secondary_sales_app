import 'package:flutter/material.dart';

import 'package:secondary_sales/core/access/access_resources.dart';

class AppShellIndex {
  static const int dashboard = 0;
  static const int dealers = 1;
  static const int routes = 2;
  static const int sales = 3;
  static const int createOrder = 4;
  static const int profile = 5;
  static const int vanLoad = 6;
  static const int vanUnload = 7;
}

class AppShellNavItem {
  const AppShellNavItem({
    required this.stackIndex,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.requiresDealerAccess = false,
    this.requiresPrimarySalesAccess = false,
    this.requiresSecondarySalesAccess = false,
    this.screenKey,
  });

  final int stackIndex;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool requiresDealerAccess;
  final bool requiresPrimarySalesAccess;
  final bool requiresSecondarySalesAccess;

  /// Optional access-catalog screen key gating this nav item. When set, the item
  /// is hidden unless [canView] allows it (backend-driven access config).
  final String? screenKey;

  bool isVisible(
    bool canAccessDealers,
    bool canAccessPrimary,
    bool canAccessSecondary,
    String moduleType, [
    bool Function(String key)? canView,
  ]) {
    if (requiresDealerAccess && !canAccessDealers) return false;
    if (requiresPrimarySalesAccess && !canAccessPrimary) return false;
    if (requiresSecondarySalesAccess && !canAccessSecondary) return false;
    if (screenKey != null && canView != null && !canView(screenKey!)) {
      return false;
    }

    // Filter by moduleType
    if (moduleType == 'primary') {
      if (stackIndex == AppShellIndex.routes ||
          stackIndex == AppShellIndex.vanLoad ||
          stackIndex == AppShellIndex.vanUnload) {
        return false;
      }
    } else if (moduleType == 'secondary') {
      if (stackIndex == AppShellIndex.dealers ||
          stackIndex == AppShellIndex.sales) {
        return false;
      }
    }

    return true;
  }
}

const List<AppShellNavItem> appShellNavItems = [
  AppShellNavItem(
    stackIndex: AppShellIndex.dashboard,
    label: 'Dashboard',
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view,
  ),
  AppShellNavItem(
    stackIndex: AppShellIndex.dealers,
    label: 'Dealers',
    icon: Icons.business_outlined,
    selectedIcon: Icons.business,
    requiresDealerAccess: true,
  ),
  AppShellNavItem(
    stackIndex: AppShellIndex.routes,
    label: 'Routes',
    icon: Icons.alt_route_outlined,
    selectedIcon: Icons.alt_route,
    screenKey: AppScreen.routesList,
  ),
  AppShellNavItem(
    stackIndex: AppShellIndex.sales,
    label: 'Primary Sales',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    requiresPrimarySalesAccess: true,
  ),
  // Load and unload are separate destinations rather than one screen with an
  // in-page toggle. They are different tasks done at different times of day,
  // and the backend lists them separately (van_operation_type on
  // /virtual-transfers). Both are gated by the same access key.
  AppShellNavItem(
    stackIndex: AppShellIndex.vanLoad,
    label: 'Van Load',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping,
    screenKey: AppScreen.vanOperationsList,
  ),
  AppShellNavItem(
    stackIndex: AppShellIndex.vanUnload,
    label: 'Van Unload',
    icon: Icons.unarchive_outlined,
    selectedIcon: Icons.unarchive,
    screenKey: AppScreen.vanOperationsList,
  ),
];

List<AppShellNavItem> visibleAppShellNavItems(
  bool canAccessDealers,
  bool canAccessPrimary,
  bool canAccessSecondary,
  String moduleType, [
  bool Function(String key)? canView,
]) {
  return appShellNavItems
      .where(
        (item) => item.isVisible(
          canAccessDealers,
          canAccessPrimary,
          canAccessSecondary,
          moduleType,
          canView,
        ),
      )
      .toList(growable: false);
}

int bottomNavIndexForStackIndex(
  int stackIndex,
  bool canAccessDealers,
  bool canAccessPrimary,
  bool canAccessSecondary,
  String moduleType, [
  bool Function(String key)? canView,
]) {
  final items = visibleAppShellNavItems(
    canAccessDealers,
    canAccessPrimary,
    canAccessSecondary,
    moduleType,
    canView,
  );
  final selected = items.indexWhere((item) => item.stackIndex == stackIndex);
  if (selected != -1) return selected;

  if (stackIndex == AppShellIndex.createOrder) {
    return items.indexWhere((item) => item.stackIndex == AppShellIndex.sales);
  }
  return items.indexWhere((item) => item.stackIndex == AppShellIndex.dashboard);
}

int stackIndexForBottomNavIndex(
  int navIndex,
  bool canAccessDealers,
  bool canAccessPrimary,
  bool canAccessSecondary,
  String moduleType, [
  bool Function(String key)? canView,
]) {
  final items = visibleAppShellNavItems(
    canAccessDealers,
    canAccessPrimary,
    canAccessSecondary,
    moduleType,
    canView,
  );
  if (navIndex < 0 || navIndex >= items.length) {
    return AppShellIndex.dashboard;
  }
  return items[navIndex].stackIndex;
}
