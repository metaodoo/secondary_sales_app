import 'package:flutter/material.dart';

class AppShellIndex {
  static const int dashboard = 0;
  static const int dealers = 1;
  static const int routes = 2;
  static const int sales = 3;
  static const int createOrder = 4;
  static const int profile = 5;
  static const int vanLoading = 6;
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
  });

  final int stackIndex;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool requiresDealerAccess;
  final bool requiresPrimarySalesAccess;
  final bool requiresSecondarySalesAccess;

  bool isVisible(bool canAccessDealers, bool canAccessPrimary, bool canAccessSecondary, String moduleType) {
    if (requiresDealerAccess && !canAccessDealers) return false;
    if (requiresPrimarySalesAccess && !canAccessPrimary) return false;
    if (requiresSecondarySalesAccess && !canAccessSecondary) return false;
    
    // Filter by moduleType
    if (moduleType == 'primary') {
      if (stackIndex == AppShellIndex.routes || stackIndex == AppShellIndex.vanLoading) return false;
    } else if (moduleType == 'secondary') {
      if (stackIndex == AppShellIndex.dealers || stackIndex == AppShellIndex.sales) return false;
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
  ),
  AppShellNavItem(
    stackIndex: AppShellIndex.sales,
    label: 'Primary Sales',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    requiresPrimarySalesAccess: true,
  ),
  AppShellNavItem(
    stackIndex: AppShellIndex.vanLoading,
    label: 'Van Operations',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping,
  ),
];

List<AppShellNavItem> visibleAppShellNavItems(
    bool canAccessDealers, bool canAccessPrimary, bool canAccessSecondary, String moduleType) {
  return appShellNavItems
      .where((item) => item.isVisible(canAccessDealers, canAccessPrimary, canAccessSecondary, moduleType))
      .toList(growable: false);
}

int bottomNavIndexForStackIndex(int stackIndex, 
    bool canAccessDealers, bool canAccessPrimary, bool canAccessSecondary, String moduleType) {
  final items = visibleAppShellNavItems(canAccessDealers, canAccessPrimary, canAccessSecondary, moduleType);
  final selected = items.indexWhere((item) => item.stackIndex == stackIndex);
  if (selected != -1) return selected;

  if (stackIndex == AppShellIndex.createOrder) {
    return items.indexWhere((item) => item.stackIndex == AppShellIndex.sales);
  }
  return items.indexWhere((item) => item.stackIndex == AppShellIndex.dashboard);
}

int stackIndexForBottomNavIndex(int navIndex, 
    bool canAccessDealers, bool canAccessPrimary, bool canAccessSecondary, String moduleType) {
  final items = visibleAppShellNavItems(canAccessDealers, canAccessPrimary, canAccessSecondary, moduleType);
  if (navIndex < 0 || navIndex >= items.length) {
    return AppShellIndex.dashboard;
  }
  return items[navIndex].stackIndex;
}
