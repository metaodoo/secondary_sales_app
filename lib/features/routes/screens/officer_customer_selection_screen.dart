import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/features/routes/route_provider.dart';
import 'package:secondary_sales/data/models/routes/route.dart';
import 'package:secondary_sales/features/routes/screens/customer_action_bottom_sheet.dart';
import 'package:secondary_sales/features/routes/screens/create_outlet_screen.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class OfficerCustomerSelectionScreen extends StatefulWidget {
  final int routeId;
  final String routeName;
  const OfficerCustomerSelectionScreen({
    super.key,
    required this.routeId,
    required this.routeName,
  });

  @override
  State<OfficerCustomerSelectionScreen> createState() =>
      _OfficerCustomerSelectionScreenState();
}

class _OfficerCustomerSelectionScreenState
    extends State<OfficerCustomerSelectionScreen> {
  int? selectedOutletId;
  String? selectedOutletName;
  late Future<RouteModel?> _routeFuture;

  @override
  void initState() {
    super.initState();
    _routeFuture = Provider.of<RouteProvider>(
      context,
      listen: false,
    ).fetchRouteDetail(widget.routeId);
  }

  void _openActionModalFor(
    int outletId,
    String outletName, {
    String? phone,
    String? mobile,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomerActionBottomSheet(
        customerName: outletName,
        outletId: outletId,
        phone: phone,
        mobile: mobile,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final localDt = dt.toLocal();
    final hour = localDt.hour > 12
        ? localDt.hour - 12
        : (localDt.hour == 0 ? 12 : localDt.hour);
    final min = localDt.minute.toString().padLeft(2, '0');
    final ampm = localDt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.routeName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: FutureBuilder<RouteModel?>(
        future: _routeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final routeModel = snapshot.data;

          return Consumer<RouteProvider>(
            builder: (context, routeProvider, child) {
              if (routeProvider.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'Backend Error: ${routeProvider.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final outlets = routeModel?.outlets ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Find an outlet...',
                        hintStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.borderSoft,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.borderSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      'AVAILABLE OUTLETS',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (outlets.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'No outlets assigned to this route.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: outlets.length,
                        itemBuilder: (context, index) {
                          final outlet = outlets[index];
                          final routeProv = routeProvider;
                          final auth = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          final employeeId = auth.employeeId;

                          final isCheckedIn =
                              routeProv.checkedInOutletId == outlet.id;

                          final isCheckedOut = routeProv.checkedOutOutletIds
                              .contains(outlet.id);

                          return GestureDetector(
                            onTap: () {
                              _openActionModalFor(
                                outlet.id,
                                outlet.name,
                                phone: outlet.phone,
                                mobile: outlet.mobile,
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCheckedIn
                                      ? const Color(0xFF10B981)
                                      : AppColors.borderSoft,
                                  width: isCheckedIn ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySoft,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: const Icon(
                                      Icons.storefront,
                                      color: Color(0xFF3B82F6),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          outlet.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          outlet.street ??
                                              'No address provided',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (isCheckedIn) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF10B981),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                routeProv.checkInTime != null
                                                    ? 'Checked In at ${_formatTime(routeProv.checkInTime!)}'
                                                    : 'Checked In',
                                                style: const TextStyle(
                                                  color: Color(0xFF10B981),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else if (isCheckedOut) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color:
                                                      AppColors.textSecondary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Text(
                                                'Checked Out',
                                                style: TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (isCheckedIn) ...[
                                    ElevatedButton(
                                      onPressed: () async {
                                        try {
                                          await routeProv.checkOut();
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Checked out successfully',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Checkout failed: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFEF4444,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Check Out',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    ElevatedButton(
                                      onPressed: () async {
                                        if (employeeId == null) return;
                                        if (routeProv.checkedInOutletId !=
                                            null) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Please check out from current outlet first',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        try {
                                          await routeProv.checkIn(
                                            employeeId,
                                            outlet.id,
                                          );
                                          _openActionModalFor(
                                            outlet.id,
                                            outlet.name,
                                          );
                                        } catch (e) {
                                          if (context.mounted) {
                                            ssShowLocationErrorDialog(
                                              context,
                                              e.toString().replaceAll('Exception: ', ''),
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.primaryStrong,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Check In',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          onPressed: () async {
                            final created = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateOutletScreen(
                                  routeId: widget.routeId,
                                  routeName: widget.routeName,
                                  distributorName:
                                      routeModel?.distributorName ??
                                      'Unassigned',
                                ),
                              ),
                            );
                            if (created == true) {
                              setState(() {
                                _routeFuture = Provider.of<RouteProvider>(
                                  context,
                                  listen: false,
                                ).fetchRouteDetail(widget.routeId);
                              });
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryStrong,
                            side: const BorderSide(
                              color: AppColors.primaryStrong,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Create New Outlet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.person_add_alt_1_outlined, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
