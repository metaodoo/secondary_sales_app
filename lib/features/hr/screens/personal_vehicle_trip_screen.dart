import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/util/dialog_helper.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/hr/expense_provider.dart';
import 'package:secondary_sales/features/hr/screens/personal_vehicle_trip_sheet.dart';
import 'package:secondary_sales/features/hr/screens/personal_vehicle_trip_details_sheet.dart';

class PersonalVehicleTripScreen extends StatelessWidget {
  const PersonalVehicleTripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ExpenseProvider(context.read<AuthProvider>()),
      child: const _PersonalVehicleTripContent(),
    );
  }
}

class _PersonalVehicleTripContent extends StatefulWidget {
  const _PersonalVehicleTripContent();

  @override
  State<_PersonalVehicleTripContent> createState() => _PersonalVehicleTripContentState();
}

class _PersonalVehicleTripContentState extends State<_PersonalVehicleTripContent> {
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<ExpenseProvider>();
    await Future.wait([
      provider.fetchCategories(),
      provider.fetchDrafts(),
      provider.fetchVehicleExpenses(
        startDate: _filterStartDate != null ? _filterStartDate!.toString().split(' ')[0] : null,
        endDate: _filterEndDate != null ? _filterEndDate!.toString().split(' ')[0] : null,
      ),
    ]);
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Map<String, dynamic>? get _activeTrip {
    final provider = context.read<ExpenseProvider>();
    return provider.drafts.cast<Map<String, dynamic>?>().firstWhere(
      (d) {
        if (d == null) return false;
        if (d['is_personal_vehicle'] != true) return false;
        final endOdo = (d['odometer_day_end'] as num?)?.toDouble() ?? 0.0;
        final hasEndImg = d['has_odometer_end_image'] == true;
        // Trip is active/in-progress only if not completed yet
        return endOdo <= 0.0 || !hasEndImg;
      },
      orElse: () => null,
    );
  }

  Future<void> _openTripEntrySheet({
    Map<String, dynamic>? activeTrip,
    DateTime? initialDate,
  }) async {
    final provider = context.read<ExpenseProvider>();
    final result = await PersonalVehicleTripSheet.show(
      context,
      activeTrip: activeTrip,
      initialDate: initialDate,
      provider: provider,
    );
    if (result == true) {
      _loadData();
    }
  }

  void _handleFabPress(Map<String, dynamic>? activeTrip) {
    if (activeTrip == null) {
      _openTripEntrySheet(activeTrip: null);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'New Trip Entry',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'An active trip started on ${activeTrip['date'] ?? 'today'} is currently in progress.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
              ),
              tileColor: AppColors.primary.withOpacity(0.05),
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.history, color: Colors.white, size: 20),
              ),
              title: const Text('Record Back-Dated Trip', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Create a vehicle expense for a previous date with start & end readings.'),
              onTap: () {
                Navigator.pop(ctx);
                _openTripEntrySheet(
                  activeTrip: null,
                  initialDate: DateTime.now().subtract(const Duration(days: 1)),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.teal[300]!),
              ),
              tileColor: Colors.teal[50],
              leading: CircleAvatar(
                backgroundColor: Colors.teal[700],
                child: const Icon(Icons.timer_outlined, color: Colors.white, size: 20),
              ),
              title: const Text('Continue Active Trip', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Enter end odometer for today\'s trip (Start: ${activeTrip['odometer_day_start'] ?? 0.0} KM).'),
              onTap: () {
                Navigator.pop(ctx);
                _openTripEntrySheet(activeTrip: activeTrip);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createExpenseSheet(int expenseId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Expense Sheet', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Create and submit an Expense Sheet for "$title"? It will be sent to your manager for approval.'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create & Submit'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = context.read<ExpenseProvider>();
    final result = await provider.submitVehicleExpenseSheet(expenseId: expenseId);

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Expense Sheet "${result['sheet_title']}" created and submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    } else if (mounted && provider.requestError != null) {
      showValidationErrorDialog(context, provider.requestError!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final activeTrip = _activeTrip;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Personal Vehicle',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ProfileAvatar(currentDestinationLabel: 'Vehicle Trip'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _handleFabPress(activeTrip),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Trip Entry',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  // Active Trip in Progress Banner if any
                  if (activeTrip != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Material(
                        color: Colors.teal[50],
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openTripEntrySheet(activeTrip: activeTrip),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.teal[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.two_wheeler, color: Colors.teal[800], size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Active Vehicle Trip in Progress',
                                        style: TextStyle(
                                          color: Colors.teal[900],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Start: ${(activeTrip['odometer_day_start'] ?? 0.0)} KM • Tap to finish & record end meter',
                                        style: TextStyle(
                                          color: Colors.teal[700],
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.teal[800]),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Date Filter Bar
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now(),
                                initialDateRange: (_filterStartDate != null && _filterEndDate != null)
                                    ? DateTimeRange(start: _filterStartDate!, end: _filterEndDate!)
                                    : null,
                              );
                              if (picked != null) {
                                setState(() {
                                  _filterStartDate = picked.start;
                                  _filterEndDate = picked.end;
                                });
                                provider.fetchVehicleExpenses(
                                  startDate: picked.start.toString().split(' ')[0],
                                  endDate: picked.end.toString().split(' ')[0],
                                );
                              }
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    (_filterStartDate != null && _filterEndDate != null)
                                        ? '${_filterStartDate!.toString().split(' ')[0]} to ${_filterEndDate!.toString().split(' ')[0]}'
                                        : 'Filter trips by date range',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: (_filterStartDate != null) ? FontWeight.bold : FontWeight.normal,
                                      color: (_filterStartDate != null) ? AppColors.textPrimary : AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_filterStartDate != null)
                          IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _filterStartDate = null;
                                _filterEndDate = null;
                              });
                              provider.fetchVehicleExpenses();
                            },
                          ),
                      ],
                    ),
                  ),

                  // Trips List
                  Expanded(
                    child: provider.isLoadingVehicleExpenses
                        ? const Center(child: CircularProgressIndicator())
                        : provider.vehicleExpenses.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.directions_bike_outlined, size: 54, color: Colors.grey[400]),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No personal vehicle trips found.',
                                      style: TextStyle(color: Colors.grey, fontSize: 14),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Tap "New Trip Entry" below to record today\'s or back-dated trips.',
                                      style: TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                                itemCount: provider.vehicleExpenses.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = provider.vehicleExpenses[index];
                                  final hasSheet = item['sheet_id'] != null;
                                  final sheetTitle = item['sheet_title'] ?? '';
                                  final isCompleted = (item['odometer_day_end'] as num?)?.toDouble() != null &&
                                      (item['odometer_day_end'] as num).toDouble() > 0 &&
                                      item['has_odometer_end_image'] == true;

                                  return Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () async {
                                        final action = await PersonalVehicleTripDetailsSheet.show(
                                          context,
                                          item,
                                          provider: provider,
                                        );
                                        if (action == 'complete') {
                                          _openTripEntrySheet(activeTrip: item);
                                        } else {
                                          _loadData();
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: AppColors.borderSoft),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.03),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Title & Status Badge
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item['title'] ?? 'Personal Vehicle Trip',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: hasSheet
                                                        ? Colors.green.withOpacity(0.12)
                                                        : isCompleted
                                                            ? Colors.blue.withOpacity(0.12)
                                                            : Colors.amber.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    hasSheet
                                                        ? 'Sheet: $sheetTitle'
                                                        : isCompleted
                                                            ? 'Completed (Unreported)'
                                                            : 'In Progress',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: hasSheet
                                                          ? Colors.green[800]
                                                          : isCompleted
                                                              ? Colors.blue[800]
                                                              : Colors.amber[900],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),

                                            // Trip date & Readings
                                            Row(
                                              children: [
                                                const Icon(Icons.calendar_today, size: 13, color: AppColors.textSecondary),
                                                const SizedBox(width: 4),
                                                Text(
                                                  item['date'] ?? '',
                                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                ),
                                                const SizedBox(width: 16),
                                                const Icon(Icons.speed, size: 14, color: AppColors.textSecondary),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${(item['total_km_run'] ?? 0.0)} KM (${(item['odometer_day_start'] ?? 0.0)} → ${(item['odometer_day_end'] ?? 0.0)})',
                                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),

                                            // Amount & Create Sheet button
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '৳${((item['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    if (!hasSheet && !isCompleted)
                                                      ElevatedButton.icon(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.teal[700],
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                        ),
                                                        onPressed: () => _openTripEntrySheet(activeTrip: item),
                                                        icon: const Icon(Icons.timer_outlined, size: 15),
                                                        label: const Text('Finish Trip', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                      ),
                                                    if (!hasSheet && isCompleted)
                                                      ElevatedButton.icon(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFF0D9488),
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                        ),
                                                        onPressed: provider.isSubmitting
                                                            ? null
                                                            : () => _createExpenseSheet(item['id'], item['title'] ?? 'Vehicle Trip'),
                                                        icon: const Icon(Icons.post_add, size: 15),
                                                        label: const Text('Create Sheet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                      ),
                                                    const SizedBox(width: 6),
                                                    const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textSecondary),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
    );
  }
}
