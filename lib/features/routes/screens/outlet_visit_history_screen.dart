import 'package:flutter/material.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/data/api/api_service.dart';

class OutletVisitHistoryScreen extends StatefulWidget {
  final int outletId;
  final String outletName;

  const OutletVisitHistoryScreen({
    super.key,
    required this.outletId,
    required this.outletName,
  });

  @override
  State<OutletVisitHistoryScreen> createState() =>
      _OutletVisitHistoryScreenState();
}

class _OutletVisitHistoryScreenState extends State<OutletVisitHistoryScreen> {
  final ApiService _apiService = ApiService.instance;
  bool _isLoading = true;
  String? _error;
  List<dynamic> _visitLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final auth = context.read<AuthProvider>();
      _apiService.updateAccessToken(auth.accessToken);
      _apiService.updateSessionId(auth.sessionId);
      _apiService.updateEmployeeId(auth.employeeId);

      final data = await _apiService.getOutletVisitHistory(widget.outletId);
      setState(() {
        _visitLogs = data['visit_logs'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          '${widget.outletName} History',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: ProfileAvatar(),
          ),
        ],
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          : _buildVisitLogsTab(),
    );
  }

  Widget _buildVisitLogsTab() {
    if (_visitLogs.isEmpty) {
      return const Center(child: Text('No visit logs found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _visitLogs.length,
      itemBuilder: (context, index) {
        final visit = _visitLogs[index];
        final type =
            visit['visit_type']?.toString().toUpperCase() ?? 'STANDARD';
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.borderSoft),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE2E8FF),
              child: Icon(Icons.location_on, color: AppColors.primaryStrong),
            ),
            title: Text(
              'Check-in: ${visit['check_in_time'] ?? 'N/A'}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Check-out: ${visit['check_out_time'] ?? 'N/A'}',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Type: $type | Employee: ${visit['employee_name']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }


}
