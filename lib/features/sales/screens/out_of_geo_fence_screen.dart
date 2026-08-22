import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/data/models/sales/order_line_entry.dart';
import 'package:secondary_sales/features/sales/screens/order_creation_screen.dart';
import 'package:secondary_sales/features/sales/screens/product_selection_screen.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class OutOfGeoFenceScreen extends StatefulWidget {
  final int outletId;
  final String customerName;
  final String? customerCode;
  final int? routeId;
  final int? visitId;

  const OutOfGeoFenceScreen({
    super.key,
    required this.outletId,
    required this.customerName,
    this.customerCode,
    this.routeId,
    this.visitId,
  });

  @override
  State<OutOfGeoFenceScreen> createState() => _OutOfGeoFenceScreenState();
}

class _OutOfGeoFenceScreenState extends State<OutOfGeoFenceScreen> {
  final ApiService _apiService = ApiService.instance;
  
  List<Map<String, dynamic>> _mediums = [];
  bool _isLoading = true;
  String? _error;
  
  int? _selectedMediumId;

  @override
  void initState() {
    super.initState();
    _fetchMediums();
  }

  Future<void> _fetchMediums() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      _apiService.updateAccessToken(auth.accessToken);
      _apiService.updateSessionId(auth.sessionId);
      _apiService.updateEmployeeId(auth.employeeId);

      final mediums = await _apiService.getMediums();
      if (mounted) {
        setState(() {
          _mediums = mediums;
          if (mediums.isNotEmpty) {
            _selectedMediumId = mediums.first['id'] as int?;
          }
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

  IconData _getIconForMedium(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('whatsapp')) return Icons.chat_bubble_outline;
    if (lower.contains('call') || lower.contains('phone')) return Icons.phone_outlined;
    if (lower.contains('sms') || lower.contains('text')) return Icons.message_outlined;
    return Icons.more_horiz;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Secondary Sales'),
        centerTitle: true,
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: ProfileAvatar(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.error_outline, color: Colors.red, size: 24),
              ),
              const SizedBox(height: 16),
              
              // Warning Text
              const Text(
                'Out of Geo-Fence Range',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You are currently not at the customer\'s physical location. Please select an alternative order method to proceed.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              
              // Section Title
              const Text(
                'SELECT ORDER TYPE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              
              // Mediums List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text('Error: $_error\n\nMake sure the "utm" module is installed in Odoo and records exist.', textAlign: TextAlign.center))
                        : _mediums.isEmpty
                            ? const Center(child: Text('No order mediums configured.'))
                            : ListView.separated(
                                itemCount: _mediums.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final medium = _mediums[index];
                                  final isSelected = _selectedMediumId == medium['id'];
                                  
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedMediumId = medium['id'];
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFFE8EAF6) : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? AppColors.primaryStrong : AppColors.borderSoft,
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            _getIconForMedium(medium['name']),
                                            color: AppColors.primaryStrong,
                                            size: 24,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            medium['name'],
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
              
              // Bottom Buttons
              ElevatedButton(
                onPressed: _selectedMediumId != null
                    ? () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductSelectionScreen(
                              saleType: 'secondary',
                              partnerId: widget.outletId,
                              customerName: widget.customerName,
                              customerCode: widget.customerCode,
                              mediumId: _selectedMediumId,
                              routeId: widget.routeId,
                              visitId: widget.visitId,
                            ),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryStrong,
                  disabledBackgroundColor: AppColors.borderSoft,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Proceed to Order',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.send_outlined, color: Colors.white, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Back to Dashboard',
                    style: TextStyle(
                      color: AppColors.primaryStrong,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
