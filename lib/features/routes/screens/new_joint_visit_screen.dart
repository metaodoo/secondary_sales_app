import 'package:flutter/material.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/data/models/employees/sales_employee.dart';

class NewJointVisitScreen extends StatefulWidget {
  final int outletId;
  final String outletName;
  final int? routeId;
  final int? currentVisitId;

  const NewJointVisitScreen({
    super.key,
    required this.outletId,
    required this.outletName,
    this.routeId,
    this.currentVisitId,
  });

  @override
  State<NewJointVisitScreen> createState() => _NewJointVisitScreenState();
}

class _NewJointVisitScreenState extends State<NewJointVisitScreen> {
  final ApiService _apiService = ApiService.instance;
  bool _isLoading = false;
  List<SalesEmployee> _officers = [];
  SalesEmployee? _selectedOfficer;

  @override
  void initState() {
    super.initState();
    _fetchOfficers();
  }

  Future<void> _fetchOfficers() async {
    final auth = context.read<AuthProvider>();
    _apiService.updateAccessToken(auth.accessToken);
    _apiService.updateSessionId(auth.sessionId);
    _apiService.updateEmployeeId(auth.employeeId);

    try {
      final officers = await _apiService.getSubordinateOfficers(
        routeId: widget.routeId,
        outletId: widget.outletId,
      );
      setState(() {
        _officers = officers;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load officers: $e')));
    }
  }

  Future<void> _startJointVisit() async {
    if (_selectedOfficer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Sales Officer')),
      );
      return;
    }

    if (widget.currentVisitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active visit found. Please check-in first.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final auth = context.read<AuthProvider>();
      _apiService.updateAccessToken(auth.accessToken);
      _apiService.updateSessionId(auth.sessionId);
      _apiService.updateEmployeeId(auth.employeeId);

      await _apiService.updateVisit(
        widget.currentVisitId!,
        visitType: 'join',
        visitedWithId: _selectedOfficer!.id,
      );

      if (!mounted) return;
      Navigator.pop(context, true); // Return success
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Joint visit started!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'New Joint Visit',
          style: TextStyle(
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryStrong,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.handshake, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Collaborative Territory Review',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Coordinate with field staff for on-site inspections.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Select Customer
            const Text(
              'Select Customer',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.borderMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storefront, color: AppColors.primaryStrong),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.outletName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${widget.outletId}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.lock_outline,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Select Sales Officer
            const Text(
              'Select Sales Officer',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<SalesEmployee>(
                  isExpanded: true,
                  hint: const Text('Choose assigned officer'),
                  icon: const Icon(Icons.keyboard_arrow_down),
                  value: _selectedOfficer,
                  items: _officers.map((officer) {
                    return DropdownMenuItem<SalesEmployee>(
                      value: officer,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Text(officer.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedOfficer = val;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 48),

            // Start Visit Button
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.timer_outlined,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Session active',
                    style: TextStyle(
                      color: AppColors.primaryStrong,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _startJointVisit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryStrong,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.play_arrow, color: Colors.white),
                label: Text(
                  _isLoading ? 'Starting...' : 'Start Visit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
