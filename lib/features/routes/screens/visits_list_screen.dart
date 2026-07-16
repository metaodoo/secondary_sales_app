import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';

class VisitsListScreen extends StatefulWidget {
  final int? routeId;

  const VisitsListScreen({super.key, this.routeId});

  @override
  State<VisitsListScreen> createState() => _VisitsListScreenState();
}

class _VisitsListScreenState extends State<VisitsListScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
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
          bottom: const TabBar(
            labelColor: AppColors.primaryStrong,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryStrong,
            tabs: [
              Tab(text: 'Standard Visits'),
              Tab(text: 'Joint Visits'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _VisitListTab(visitType: 'standard', routeId: widget.routeId),
            _VisitListTab(visitType: 'join', routeId: widget.routeId),
          ],
        ),
      ),
    );
  }
}

class _VisitListTab extends StatefulWidget {
  final String visitType;
  final int? routeId;

  const _VisitListTab({required this.visitType, this.routeId});

  @override
  State<_VisitListTab> createState() => _VisitListTabState();
}

class _VisitListTabState extends State<_VisitListTab> {
  final ApiService _apiService = ApiService.instance;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _visits = [];

  @override
  void initState() {
    super.initState();
    _fetchVisits();
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
        page: 1,
        pageSize: 100, // fetching 100 for simplicity
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
    return RefreshIndicator(
      onRefresh: _fetchVisits,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
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
                  title: Text(
                    '${visit['outlet_name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                        'Employee: ${visit['employee_name']}',
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
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
