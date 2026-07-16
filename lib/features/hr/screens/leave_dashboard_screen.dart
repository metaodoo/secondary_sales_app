import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/hr/leave_provider.dart';
import 'package:secondary_sales/features/hr/screens/leave_request_sheet.dart';
import 'package:secondary_sales/features/hr/screens/leave_details_sheet.dart';
import 'package:secondary_sales/core/access/permission_gate.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class LeaveDashboardScreen extends StatelessWidget {
  const LeaveDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LeaveProvider(context.read<AuthProvider>()),
      child: const _LeaveDashboardContent(),
    );
  }
}

class _LeaveDashboardContent extends StatefulWidget {
  const _LeaveDashboardContent();

  @override
  State<_LeaveDashboardContent> createState() => _LeaveDashboardContentState();
}

class _LeaveDashboardContentState extends State<_LeaveDashboardContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['own', 'pending', 'approved', 'rejected', 'all'];
  final List<String> _tabLabels = ['Own', 'Pending', 'Approved', 'Rejected', 'All'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<LeaveProvider>().setActiveTab(_tabs[_tabController.index]);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showLeaveRequestForm(BuildContext context) {
    LeaveRequestSheet.show(context, context.read<LeaveProvider>());
  }

  void _showLeaveDetails(BuildContext context, Map<String, dynamic> leave) {
    LeaveDetailsSheet.show(context, context.read<LeaveProvider>(), leave);
  }

  void _handleError(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Action Error'),
          ],
        ),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    context.read<LeaveProvider>().clearError();
  }

  Future<void> _selectDateRange(BuildContext context, LeaveProvider provider) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: provider.dateFrom != null && provider.dateTo != null
          ? DateTimeRange(
              start: DateTime.parse(provider.dateFrom!),
              end: DateTime.parse(provider.dateTo!),
            )
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final fromStr = picked.start.toString().split(' ')[0];
      final toStr = picked.end.toString().split(' ')[0];
      provider.setDateRange(fromStr, toStr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LeaveProvider>();

    if (provider.actionError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleError(context, provider.actionError!);
      });
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Leave Requests',
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
            child: const ProfileAvatar(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: _tabLabels.map((label) {
            // For Pending, we could add a badge here if we had a separate count API, 
            // but for now we just show the label.
            return Tab(text: label);
          }).toList(),
        ),
      ),
      body: Column(
        children: [
          // Premium Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Unified Search Field
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search employee name or ID...',
                            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                            prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                    onPressed: () {
                                      _searchController.clear();
                                      provider.setSearchQuery(null);
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          style: const TextStyle(fontSize: 14),
                          onChanged: (val) => provider.setSearchQuery(val.isEmpty ? null : val),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Beautiful Filter Trigger Button
                    Container(
                      decoration: BoxDecoration(
                        color: (provider.dateFrom != null)
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (provider.dateFrom != null)
                              ? AppColors.primary
                              : AppColors.borderSoft,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.filter_alt_outlined,
                          color: (provider.dateFrom != null)
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        tooltip: 'Filter by Date Range',
                        onPressed: () => _selectDateRange(context, provider),
                      ),
                    ),
                  ],
                ),
                // Active Filters Chips (e.g. Selected Date Range)
                if (provider.dateFrom != null && provider.dateTo != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        backgroundColor: AppColors.primary.withOpacity(0.08),
                        labelStyle: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500),
                        side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                        avatar: const Icon(Icons.calendar_month, size: 14, color: AppColors.primary),
                        label: Text('${provider.dateFrom} to ${provider.dateTo}'),
                        deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primary),
                        onDeleted: () {
                          provider.setDateRange(null, null);
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: PermissionGate(
              resourceKey: AppAction.leaveCreate,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Request Leave'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _showLeaveRequestForm(context),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await provider.fetchLeaveList();
              },
              child: provider.isLoadingList
                  ? const Center(child: CircularProgressIndicator())
                  : provider.leaveList.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 100),
                            _buildEmptyState(),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.leaveList.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final leave = provider.leaveList[index];
                            return _buildLeaveCard(context, leave, provider);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.umbrella_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
        const SizedBox(height: 16),
        const Text(
          'No Leave Requests',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'No leave requests found for the selected filter.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildLeaveCard(BuildContext context, Map<String, dynamic> leave, LeaveProvider provider) {
    final bool canApprove = leave['can_approve'] ?? false;
    final bool isMyRequest = leave['is_my_request'] ?? false;
    final String status = leave['status'] ?? '';
    
    // Status Badge Color Logic
    Color badgeColor = Colors.grey;
    String badgeText = status.toUpperCase();
    if (status == 'confirm') {
      badgeColor = Colors.orange;
      badgeText = 'TO APPROVE';
    } else if (status == 'validate') {
      badgeColor = Colors.green;
      badgeText = 'APPROVED';
    } else if (status == 'refuse') {
      badgeColor = Colors.red;
      badgeText = 'REJECTED';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderSoft),
      ),
      child: InkWell(
        onTap: () => _showLeaveDetails(context, leave),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMyRequest) ...[
                    CircleAvatar(
                      backgroundColor: AppColors.dangerSoft,
                      child: Text(
                        leave['employee_name']?.substring(0, 2).toUpperCase() ?? '??',
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMyRequest ? "My Leave Request" : (leave['employee_name'] ?? ''),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (!isMyRequest)
                          Text(
                            leave['department'] ?? '',
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: badgeColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Leave Details
              Text(
                leave['leave_type'] ?? 'Leave',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${leave['date_from']} to ${leave['date_to']}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Requested: ${leave['applied_on']}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  if (canApprove)
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => provider.submitLeaveAction(leave['leave_id'], 'reject'),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reject'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            minimumSize: const Size(0, 32),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => provider.submitLeaveAction(leave['leave_id'], 'approve'),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Accept'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            minimumSize: const Size(0, 32),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
