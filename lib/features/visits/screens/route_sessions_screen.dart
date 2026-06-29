import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/data/models/routes/route.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/visits/screens/visit_details_screen.dart';

class RouteSessionsScreen extends StatefulWidget {
  final RouteModel route;

  const RouteSessionsScreen({super.key, required this.route});

  @override
  State<RouteSessionsScreen> createState() => _RouteSessionsScreenState();
}

class _RouteSessionsScreenState extends State<RouteSessionsScreen> {
  final ApiService _apiService = ApiService.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _visits = [];
  String? _error;

  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final auth = context.read<AuthProvider>();
      _apiService.updateAccessToken(auth.accessToken);
      _apiService.updateSessionId(auth.sessionId);
      _apiService.updateEmployeeId(auth.employeeId);
      _fetchVisits();
      _isInit = true;
    }
  }

  Future<void> _fetchVisits() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final visits = await _apiService.getRouteVisitHistory(widget.route.id);
      setState(() {
        _visits = visits;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _startTodayVisit() async {
    setState(() => _isLoading = true);
    try {
      final visit = await _apiService.startRouteVisit(widget.route.id);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VisitDetailsScreen(
              visitId: visit['visit_id'],
              route: widget.route,
            ),
          ),
        ).then((_) => _fetchVisits());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start visit: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          BlueHeader(
            title: '${widget.route.name} Visits',
            subtitle: "History & Today's Session",
            trailing: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _startTodayVisit,
                icon: const Icon(Icons.play_arrow),
                label: const Text("Start Today's Visit"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryStrong,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _visits.isEmpty
                  ? const Center(child: Text('No previous visits found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _visits.length,
                      itemBuilder: (context, index) {
                        final visit = _visits[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              visit['visit_date'] ?? 'Unknown Date',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text('Status: ${visit['state']}'),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppColors.primaryStrong,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VisitDetailsScreen(
                                    visitId: visit['visit_id'],
                                    route: widget.route,
                                  ),
                                ),
                              ).then((_) => _fetchVisits());
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
