import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/core/services/location_service.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class CheckInScreen extends StatefulWidget {
  final int visitId;
  final int lineId;
  final String outletName;
  final int outletId;

  const CheckInScreen({
    super.key,
    required this.visitId,
    required this.lineId,
    required this.outletName,
    required this.outletId,
  });

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final ApiService _apiService = ApiService.instance;
  bool _isLoading = false;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final auth = context.read<AuthProvider>();
      _apiService.updateAccessToken(auth.accessToken);
      _apiService.updateSessionId(auth.sessionId);
      _apiService.updateEmployeeId(auth.employeeId);
      _isInit = true;
    }
  }

  Future<void> _checkOut() async {
    setState(() => _isLoading = true);
    try {
      final position = await LocationService.getCurrentPosition();

      if (!mounted) return;

      await _apiService.executeRouteVisitAction(
        visitId: widget.visitId,
        action: 'check_out',
        lineId: widget.lineId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ssShowLocationErrorDialog(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _takeOrder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Secondary Order creation coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          BlueHeader(
            title: 'Checked In',
            subtitle: widget.outletName,
            trailing: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.store_mall_directory,
                      size: 100,
                      color: AppColors.primaryStrong,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'You are actively visiting\\n${widget.outletName}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton.icon(
                      onPressed: _takeOrder,
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('Take Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (context.watch<AuthProvider>().canDo(
                      AppAction.visitCheckOut,
                    ))
                      ElevatedButton.icon(
                        onPressed: _checkOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Check Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryStrong,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
