import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/data/models/routes/route.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/visits/screens/outlet_selection_screen.dart';
import 'package:secondary_sales/features/visits/screens/check_in_screen.dart';

class VisitDetailsScreen extends StatefulWidget {
  final int visitId;
  final RouteModel route;

  const VisitDetailsScreen({
    super.key,
    required this.visitId,
    required this.route,
  });

  @override
  State<VisitDetailsScreen> createState() => _VisitDetailsScreenState();
}

class _VisitDetailsScreenState extends State<VisitDetailsScreen> {
  final ApiService _apiService = ApiService.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _visitDetails;
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
      _fetchDetails();
      _isInit = true;
    }
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final details = await _apiService.getRouteVisitDetails(widget.visitId);
      setState(() {
        _visitDetails = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _completeVisit() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.executeRouteVisitAction(
        visitId: widget.visitId,
        action: 'complete',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route completed!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _openOutletSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OutletSelectionScreen(
          routeId: widget.route.id,
          visitId: widget.visitId,
        ),
      ),
    ).then((_) => _fetchDetails());
  }

  void _openActiveCheckIn(Map<String, dynamic> line) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckInScreen(
          visitId: widget.visitId,
          lineId: line['line_id'],
          outletName: line['outlet_name'],
          outletId: line['outlet_id'],
        ),
      ),
    ).then((_) => _fetchDetails());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          BlueHeader(
            title: 'Visit Details',
            subtitle: widget.route.name,
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
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openOutletSelection,
                      icon: const Icon(Icons.add_location_alt),
                      label: const Text('+ New Visit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryStrong,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (_visitDetails!['state'] != 'done') ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _completeVisit,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Finish Route'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: (_visitDetails!['visit_lines'] as List).isEmpty
                  ? const Center(child: Text('No outlets visited yet.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: (_visitDetails!['visit_lines'] as List).length,
                      itemBuilder: (context, index) {
                        final line = _visitDetails!['visit_lines'][index];
                        final isCheckedIn = line['state'] == 'checked_in';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isCheckedIn
                                ? const BorderSide(
                                    color: AppColors.primaryStrong,
                                    width: 2,
                                  )
                                : BorderSide.none,
                          ),
                          elevation: isCheckedIn ? 4 : 1,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              line['outlet_name'] ?? 'Unknown Outlet',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Status: ${line['state']}\n'
                                'Check-in: ${line['check_in_time'] ?? '-'}\n'
                                'Check-out: ${line['check_out_time'] ?? '-'}',
                              ),
                            ),
                            trailing: isCheckedIn
                                ? const ElevatedButton(
                                    onPressed: null,
                                    child: Text('Active'),
                                  )
                                : Icon(
                                    line['state'] == 'skipped'
                                        ? Icons.block
                                        : Icons.check_circle,
                                    color: line['state'] == 'skipped'
                                        ? Colors.orange
                                        : Colors.green,
                                  ),
                            onTap: isCheckedIn
                                ? () => _openActiveCheckIn(line)
                                : null,
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
