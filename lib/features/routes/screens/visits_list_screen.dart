import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/sales/screens/secondary_orders_list_screen.dart';

class VisitsListScreen extends StatefulWidget {
  final int? routeId;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const VisitsListScreen({
    super.key,
    this.routeId,
    this.dateFrom,
    this.dateTo,
  });

  @override
  State<VisitsListScreen> createState() => _VisitsListScreenState();
}

class _VisitsListScreenState extends State<VisitsListScreen> {
  @override
  Widget build(BuildContext context) {
    final canViewJointVisits = context.read<AuthProvider>().canView(
      AppScreen.newJointVisit,
    );
    final tabs = <Tab>[
      const Tab(text: 'Standard Visits'),
      if (canViewJointVisits) const Tab(text: 'Joint Visits'),
    ];
    final tabViews = <Widget>[
      _VisitListTab(
        visitType: 'standard',
        routeId: widget.routeId,
        dateFrom: widget.dateFrom,
        dateTo: widget.dateTo,
      ),
      if (canViewJointVisits)
        _VisitListTab(
          visitType: 'join',
          routeId: widget.routeId,
          dateFrom: widget.dateFrom,
          dateTo: widget.dateTo,
        ),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          title: const Text(
            'Visit History',
            style: TextStyle(
              color: AppColors.primaryStrong,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: ProfileAvatar(),
            ),
          ],
          bottom: TabBar(
            labelColor: AppColors.primaryStrong,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryStrong,
            tabs: tabs,
          ),
        ),
        body: TabBarView(children: tabViews),
      ),
    );
  }
}

class _VisitListTab extends StatefulWidget {
  final String visitType;
  final int? routeId;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const _VisitListTab({
    required this.visitType,
    this.routeId,
    this.dateFrom,
    this.dateTo,
  });

  @override
  State<_VisitListTab> createState() => _VisitListTabState();
}

class _VisitListTabState extends State<_VisitListTab> {
  final ApiService _apiService = ApiService.instance;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isLoading = false;
  String? _error;
  String _scope = 'all'; // 'all', 'own', 'subordinates'
  List<Map<String, dynamic>> _visits = [];

  @override
  void initState() {
    super.initState();
    _fetchVisits();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchVisits();
    });
  }

  Future<void> _fetchVisits() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      _apiService.updateAccessToken(auth.accessToken);
      _apiService.updateSessionId(auth.sessionId);
      _apiService.updateEmployeeId(auth.employeeId);

      final result = await _apiService.getVisits(
        visitType: widget.visitType,
        routeId: widget.routeId,
        search: _searchController.text,
        scope: _scope,
        dateFrom: widget.dateFrom,
        dateTo: widget.dateTo,
        page: 1,
        pageSize: 100,
      );

      if (mounted) {
        setState(() {
          _visits = result['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canOpenOrders = auth.canView(AppScreen.secondaryOrdersList);
    final isSupervisor = auth.canView(AppScreen.newJointVisit);
    final myEmployeeId = auth.employeeId;

    return RefreshIndicator(
      onRefresh: _fetchVisits,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Search Input Field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search outlet or employee...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _fetchVisits();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderSoft),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderSoft),
              ),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 10),

          // Scope Filter Chips for Supervisor/Manager
          if (isSupervisor) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Visits'),
                    selected: _scope == 'all',
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _scope == 'all' ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: _scope == 'all' ? AppColors.primary : AppColors.borderSoft,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _scope = 'all');
                        _fetchVisits();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('My Own Visits'),
                    selected: _scope == 'own',
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _scope == 'own' ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: _scope == 'own' ? AppColors.primary : AppColors.borderSoft,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _scope = 'own');
                        _fetchVisits();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Subordinates'),
                    selected: _scope == 'subordinates',
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _scope == 'subordinates' ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: _scope == 'subordinates' ? AppColors.primary : AppColors.borderSoft,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _scope = 'subordinates');
                        _fetchVisits();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (_error != null) ...[
            ErrorPanel(_error!),
            const SizedBox(height: 16),
          ],
          if (_isLoading && _visits.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_visits.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No visits found.')),
            )
          else ...[
            if (_isLoading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
            ],
            ..._visits.map((visit) {
              final isJoint = widget.visitType == 'join';
              final isMyVisit = visit['employee_id'] == myEmployeeId;
              final empName = visit['employee_name'] ?? 'N/A';
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: AppColors.borderSoft),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isJoint ? const Color(0xFFE2FFE8) : const Color(0xFFE2E8FF),
                    child: Icon(
                      isJoint ? Icons.handshake : Icons.location_on,
                      color: isJoint ? Colors.green : AppColors.primaryStrong,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${visit['outlet_name']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      if (isSupervisor)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isMyVisit ? AppColors.primarySoft : const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isMyVisit ? AppColors.primaryTint : const Color(0xFFFFCC80),
                            ),
                          ),
                          child: Text(
                            isMyVisit ? 'My Visit' : 'Subordinate',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isMyVisit ? AppColors.primary : Colors.orange.shade900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Check-in: ${visit['check_in_time'] ?? 'N/A'}'),
                      if (visit['check_out_time'] != null)
                        Text('Check-out: ${visit['check_out_time']}'),
                      const SizedBox(height: 4),
                      Text(
                        'Employee: $empName',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      if (isJoint && visit['visited_with_name'] != null)
                        Text(
                          'Visited With: ${visit['visited_with_name']}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: canOpenOrders
                      ? const Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        )
                      : null,
                  onTap: canOpenOrders
                      ? () {
                          final visitId = visit['id'];
                          if (visitId is! int) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SecondaryOrdersListScreen(
                                visitId: visitId,
                                outletName: visit['outlet_name']?.toString(),
                              ),
                            ),
                          );
                        }
                      : null,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
