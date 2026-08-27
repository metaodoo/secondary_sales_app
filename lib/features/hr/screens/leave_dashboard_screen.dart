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
  final List<String> _tabs = ['own', 'pending'];
  final List<String> _tabLabels = ['My Leaves', 'Team Approvals'];
  final TextEditingController _searchController = TextEditingController();

  final Map<String, String?> _statusFilters = {
    'All': null,
    'Pending': 'pending',
    'Approved': 'approved',
    'Rejected': 'rejected',
  };
  String _selectedStatusLabel = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final tab = _tabs[_tabController.index];
        setState(() {
          _selectedStatusLabel = 'All';
        });
        context.read<LeaveProvider>().setActiveTab(tab);
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

    final int totalRequests = provider.leaveList.length;
    final int pendingRequests = provider.leaveList.where((item) => item['status'] == 'confirm').length;
    final int approvedRequests = provider.leaveList.where((item) => item['status'] == 'validate').length;

    return Scaffold(
      floatingActionButton: PermissionGate(
        resourceKey: AppAction.leaveCreate,
        child: SsCreateFab(
          label: 'Request Leave',
          onPressed: () => _showLeaveRequestForm(context),
        ),
      ),
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
            child: ProfileAvatar(currentDestinationLabel: 'Leave Request'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: _tabLabels.map((label) {
            return Tab(text: label);
          }).toList(),
        ),
      ),
      body: Column(
        children: [
          // Stat cards header (Matching Expense Dashboard 1:1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _buildStatCard(
                  'Total',
                  '$totalRequests',
                  Colors.indigo,
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  'Pending',
                  '$pendingRequests',
                  Colors.amber[800]!,
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  'Approved',
                  '$approvedRequests',
                  Colors.green,
                ),
              ],
            ),
          ),
          // Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Search Field
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
                    // Date Filter Trigger Button
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
                const SizedBox(height: 12),
                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusFilters.keys.map((label) {
                      final isSelected = _selectedStatusLabel == label;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(label),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          selectedColor: AppColors.primary,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : AppColors.borderSoft,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedStatusLabel = label;
                              });
                              provider.setStatusFilter(_statusFilters[label]);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Active Filters Chips (Date Range)
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
                          padding: const EdgeInsets.fromLTRB(
                              16, 16, 16, kSsFabScrollPadding),
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

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
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
    Color badgeColor = Colors.grey[700]!;
    String badgeText = status.toUpperCase();
    if (status == 'confirm') {
      badgeColor = Colors.amber[800]!;
      badgeText = 'TO APPROVE';
    } else if (status == 'validate') {
      badgeColor = Colors.green;
      badgeText = 'APPROVED';
    } else if (status == 'refuse') {
      badgeColor = Colors.red;
      badgeText = 'REJECTED';
    }
    final Color badgeBgColor = badgeColor.withOpacity(0.1);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderSoft),
      ),
      child: InkWell(
        onTap: () => _showLeaveDetails(context, leave),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMyRequest ? (leave['leave_type'] ?? "Leave Request") : (leave['employee_name'] ?? ''),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                        ),
                        if (!isMyRequest) ...[
                          const SizedBox(height: 2),
                          Text(
                            leave['department'] ?? '',
                            style: const TextStyle(color: AppColors.primaryStrong, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isMyRequest) ...[
                Text(
                  leave['leave_type'] ?? 'Leave',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                '${leave['date_from']} to ${leave['date_to']} • (${leave['duration'] ?? '1 day'})',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              if (leave['reason'] != null && leave['reason'].toString().isNotEmpty) ...[
                const Divider(height: 20),
                Text(
                  leave['reason'],
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Applied: ${leave['applied_on']}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  if (canApprove)
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            foregroundColor: Colors.red,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => provider.submitLeaveAction(leave['leave_id'], 'reject'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => provider.submitLeaveAction(leave['leave_id'], 'approve'),
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
