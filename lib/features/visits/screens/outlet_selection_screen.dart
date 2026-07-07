import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/core/services/location_service.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class OutletSelectionScreen extends StatefulWidget {
  final int routeId;
  final int visitId;

  const OutletSelectionScreen({
    super.key,
    required this.routeId,
    required this.visitId,
  });

  @override
  State<OutletSelectionScreen> createState() => _OutletSelectionScreenState();
}

class _OutletSelectionScreenState extends State<OutletSelectionScreen> {
  final ApiService _apiService = ApiService.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _outlets = [];
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
      _fetchOutlets();
      _isInit = true;
    }
  }

  Future<void> _fetchOutlets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // You can filter by route_id if backend supports it, or just fetch all
      final outlets = await _apiService.getOutlets(routeId: widget.routeId);
      setState(() {
        _outlets = outlets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _checkIn(int outletId) async {
    setState(() => _isLoading = true);
    try {
      final position = await LocationService.getCurrentPosition();

      if (!mounted) return;

      await _apiService.executeRouteVisitAction(
        visitId: widget.visitId,
        action: 'check_in',
        outletId: outletId,
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

  Future<void> _skipOutlet(int outletId) async {
    final noteController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Outlet'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(hintText: 'Reason for skipping...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, noteController.text),
            child: const Text('Skip'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await _apiService.executeRouteVisitAction(
          visitId: widget.visitId,
          action: 'skip',
          outletId: outletId,
          note: result,
        );
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to skip: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showActionDialog(Map<String, dynamic> outlet) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  outlet['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _checkIn(outlet['id']);
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Check In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryStrong,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _skipOutlet(outlet['id']);
                  },
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Skip Outlet'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          BlueHeader(
            title: 'Select Outlet',
            subtitle: 'Choose an outlet to visit',
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
            Expanded(
              child: _outlets.isEmpty
                  ? const Center(
                      child: Text('No outlets found for this route.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _outlets.length,
                      itemBuilder: (context, index) {
                        final outlet = _outlets[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.primarySoft,
                              child: Icon(
                                Icons.storefront,
                                color: AppColors.primaryStrong,
                              ),
                            ),
                            title: Text(outlet['name'] ?? ''),
                            subtitle: Text(outlet['street'] ?? 'No address'),
                            trailing: const Icon(Icons.more_vert),
                            onTap: () => _showActionDialog(outlet),
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
