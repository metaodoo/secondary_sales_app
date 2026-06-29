import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/app/navigation/app_shell_config.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/features/dashboard/screens/dashboard_tab.dart';
import 'package:secondary_sales/features/contacts/screens/dealers_tab.dart';
import 'package:secondary_sales/features/van_loading/screens/van_operations_list_screen.dart';
import 'package:secondary_sales/features/sales/screens/home_tab.dart';
import 'package:secondary_sales/features/sales/screens/order_tab.dart';
import 'package:secondary_sales/features/routes/screens/officer_route_selection_screen.dart';
import 'package:secondary_sales/features/settings/screens/settings_tab.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';

class AppShell extends StatefulWidget {
  final String moduleType;
  const AppShell({super.key, required this.moduleType});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final TextEditingController _orderSearchController = TextEditingController();
  final TextEditingController _distributorSearchController =
      TextEditingController();
  int _currentIndex = AppShellIndex.dashboard;
  final List<int> _history = [AppShellIndex.dashboard];
  // Tabs are built lazily: a tab (and its initState network calls) is only
  // created the first time it is opened, then kept alive afterwards.
  final Set<int> _activatedTabs = {AppShellIndex.dashboard};
  String _statusFilter = 'all';
  DateTime? _dateFromFilter;
  DateTime? _dateToFilter;
  Timer? _orderSearchDebounce;
  Timer? _distributorSearchDebounce;

  @override
  void initState() {
    super.initState();
    // Only prefetch primary-sales data for the Primary module. Secondary
    // screens fetch what they need on demand when opened.
    if (widget.moduleType == 'primary') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = context.read<PrimarySaleProvider>();
        provider.fetchRecentOrders();
        provider.fetchInitialData();
      });
    }
  }

  @override
  void dispose() {
    _orderSearchDebounce?.cancel();
    _distributorSearchDebounce?.cancel();
    _orderSearchController.dispose();
    _distributorSearchController.dispose();
    super.dispose();
  }

  void _setIndex(int index, {bool isBack = false}) {
    if (index == AppShellIndex.dealers &&
        !context.read<AuthProvider>().canAccessDealers) {
      index = AppShellIndex.dashboard;
    }
    if (_currentIndex == index) {
      if (index == AppShellIndex.dealers && !isBack) {
        _refreshDealers();
      }
      return;
    }

    setState(() {
      if (!isBack) {
        _history.add(index);
      }
      _currentIndex = index;
      _activatedTabs.add(index);
    });

    if (index == AppShellIndex.dealers) {
      _refreshDealers();
    }
    if (index == AppShellIndex.sales) {
      _refreshOrders();
    }
  }

  void _goBack() {
    if (_history.length > 1) {
      _history.removeLast();
      _setIndex(_history.last, isBack: true);
    } else {
      _setIndex(0, isBack: true);
    }
  }

  void _exitModule() {
    Navigator.of(context).pop();
  }

  void _refreshOrders() {
    context.read<PrimarySaleProvider>().fetchRecentOrders(
      search: _orderSearchController.text,
      status: _statusFilter,
      dateFrom: _dateFromFilter,
      dateTo: _dateToFilter,
    );
  }

  void _refreshDealers() {
    context.read<PrimarySaleProvider>().searchHubs('');
  }

  void _onOrderSearchChanged(String value) {
    _orderSearchDebounce?.cancel();
    _orderSearchDebounce = Timer(
      const Duration(milliseconds: 350),
      _refreshOrders,
    );
  }

  void _onDistributorSearchChanged(String value) {
    _distributorSearchDebounce?.cancel();
    _distributorSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      context.read<PrimarySaleProvider>().searchHubs(value);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateFromFilter != null && _dateToFilter != null
          ? DateTimeRange(start: _dateFromFilter!, end: _dateToFilter!)
          : null,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      _dateFromFilter = picked.start;
      _dateToFilter = picked.end;
    });
    _refreshOrders();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canAccessDealers = auth.canAccessDealers;
    final canAccessPrimary = auth.canAccessPrimarySales;
    final canAccessSecondary = auth.canAccessSecondarySales;

    final currentIndex = !canAccessDealers && _currentIndex == 1
        ? 0
        : (!canAccessPrimary && _currentIndex == AppShellIndex.sales)
        ? 0
        : _currentIndex;
    final navItems = visibleAppShellNavItems(
      canAccessDealers,
      canAccessPrimary,
      canAccessSecondary,
      widget.moduleType,
    );

    // Ensure the tab being shown is always built, even if it was reached
    // through an access-fallback remap rather than a direct selection.
    _activatedTabs.add(currentIndex);

    final tabBuilders = <Widget Function()>[
      () => DashboardTab(
              showDealerModule: canAccessDealers,
              showPrimarySalesModule: canAccessPrimary,
              showSecondarySalesModule: canAccessSecondary,
              moduleType: widget.moduleType,
              onBackToModules: _exitModule,
              onModuleSelected: (index) {
                _setIndex(index);
              },
            ),
      () => DealersTab(onProfileTap: () => _setIndex(5), onBack: _goBack),
      () => OfficerRouteSelectionScreen(
              onProfileTap: () => _setIndex(5),
              onBack: _goBack,
            ),
      () => HomeTab(
              orderSearchController: _orderSearchController,
              statusFilter: _statusFilter,
              dateFromFilter: _dateFromFilter,
              dateToFilter: _dateToFilter,
              onSearchChanged: _onOrderSearchChanged,
              onStatusChanged: (value) {
                setState(() => _statusFilter = value ?? 'all');
                _refreshOrders();
              },
              onDateTap: _pickDate,
              onNewOrderTap: () => _setIndex(4),
              onProfileTap: () => _setIndex(5),
              onBack: _goBack,
              onClearDate: () {
                setState(() {
                  _dateFromFilter = null;
                  _dateToFilter = null;
                });
                _refreshOrders();
              },
              onClearStatus: () {
                setState(() {
                  _statusFilter = 'all';
                });
                _refreshOrders();
              },
              onClearAllFilters: () {
                setState(() {
                  _statusFilter = 'all';
                  _dateFromFilter = null;
                  _dateToFilter = null;
                });
                _refreshOrders();
              },
            ),
      () => OrderTab(
              searchController: _distributorSearchController,
              onSearchChanged: _onDistributorSearchChanged,
              onBack: _goBack,
            ),
      () => SettingsTab(onBack: _goBack),
      () => VanOperationsListScreen(onProfileTap: () => _setIndex(5), onBack: _goBack),
    ];

    return PopScope(
      canPop: _history.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _goBack();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: currentIndex,
          children: List<Widget>.generate(
            tabBuilders.length,
            (i) => _activatedTabs.contains(i)
                ? tabBuilders[i]()
                : const SizedBox.shrink(),
          ),
        ),
        bottomNavigationBar: navItems.length < 2
            ? null
            : NavigationBar(
                selectedIndex: bottomNavIndexForStackIndex(
                  currentIndex,
                  canAccessDealers,
                  canAccessPrimary,
                  canAccessSecondary,
                  widget.moduleType,
                ),
                onDestinationSelected: (index) => _setIndex(
                  stackIndexForBottomNavIndex(
                    index,
                    canAccessDealers,
                    canAccessPrimary,
                    canAccessSecondary,
                    widget.moduleType,
                  ),
                ),
                destinations: navItems
                    .map(
                      (item) => NavigationDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: item.label,
                      ),
                    )
                    .toList(growable: false),
              ),
      ),
    );
  }
}
