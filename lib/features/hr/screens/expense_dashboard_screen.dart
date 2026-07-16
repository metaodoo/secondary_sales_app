import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/hr/expense_provider.dart';
import 'package:secondary_sales/features/hr/screens/expense_create_sheet.dart';
import 'package:secondary_sales/features/hr/screens/expense_details_sheet.dart';
import 'package:secondary_sales/core/access/permission_gate.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class ExpenseDashboardScreen extends StatelessWidget {
  const ExpenseDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ExpenseProvider(context.read<AuthProvider>()),
      child: const _ExpenseDashboardContent(),
    );
  }
}

class _ExpenseDashboardContent extends StatefulWidget {
  const _ExpenseDashboardContent();

  @override
  State<_ExpenseDashboardContent> createState() => _ExpenseDashboardContentState();
}

class _ExpenseDashboardContentState extends State<_ExpenseDashboardContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final List<String> _tabs = ['My Expenses', 'Approvals'];
  
  // Status filter state for both tabs
  final Map<String, String?> _statusFilters = {
    'All': null,
    'To Approve': 'submit',
    'Approved': 'approve',
    'Refused': 'cancel',
  };
  String _selectedStatusLabel = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final mode = _tabController.index == 0 ? 'own' : 'pending';
        setState(() {
          _selectedStatusLabel = 'All';
        });
        context.read<ExpenseProvider>().setActiveTab(mode);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approve':
      case 'approved':
      case 'post':
      case 'done':
        return Colors.green;
      case 'submit':
      case 'submitted':
        return Colors.blue;
      case 'cancel':
      case 'refused':
        return Colors.red;
      case 'draft':
      default:
        return Colors.grey;
    }
  }

  Color _getStatusBgColor(String status) {
    return _getStatusColor(status).withOpacity(0.1);
  }

  Future<void> _selectDateRange(BuildContext context, ExpenseProvider provider) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      initialDateRange: provider.dateFrom != null && provider.dateTo != null
          ? DateTimeRange(
              start: DateTime.parse(provider.dateFrom!),
              end: DateTime.parse(provider.dateTo!),
            )
          : null,
    );

    if (picked != null) {
      final from = picked.start.toLocal().toString().split(' ')[0];
      final to = picked.end.toLocal().toString().split(' ')[0];
      provider.setDateRange(from, to);
    }
  }

  void _showRefuseDialog(BuildContext context, ExpenseProvider provider, int sheetId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuse Expense Report'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for refusal',
            hintText: 'Enter reason...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a reason for refusal.')),
                );
                return;
              }
              Navigator.pop(ctx);
              final success = await provider.refuseSheet(sheetId, reason);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Expense report refused successfully.')),
                );
              } else if (context.mounted && provider.actionError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(provider.actionError!)),
                );
              }
            },
            child: const Text('Refuse'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    // Totals calculated from fetched list
    final double totalSubmitted = provider.myExpenses.fold(0.0, (sum, item) => sum + (item['amount'] as double));
    final double pendingAmount = provider.myExpenses
        .where((item) => item['status'] == 'submit')
        .fold(0.0, (sum, item) => sum + (item['amount'] as double));
    final double approvedAmount = provider.myExpenses
        .where((item) => ['approve', 'post', 'done'].contains(item['status']))
        .fold(0.0, (sum, item) => sum + (item['amount'] as double));

    return Scaffold(
      backgroundColor: AppColors.background,
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
          'Expenses',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: const ProfileAvatar(),
          ),
        ],
      ),
      floatingActionButton: provider.activeTab == 'own'
          ? PermissionGate(
              resourceKey: AppAction.expenseCreate,
              child: FloatingActionButton.extended(
                onPressed: () => ExpenseCreateSheet.show(context, provider),
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => provider.fetchSheetList(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stat cards header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  _buildStatCard(
                    'Submitted',
                    '৳${totalSubmitted.toStringAsFixed(0)}',
                    Colors.indigo,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    'Pending',
                    '৳${pendingAmount.toStringAsFixed(0)}',
                    Colors.amber[800]!,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    'Approved',
                    '৳${approvedAmount.toStringAsFixed(0)}',
                    Colors.green,
                  ),
                ],
              ),
            ),

            // Status filter dropdown (for both tabs)
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatusLabel,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedStatusLabel = val;
                          });
                          provider.setStateFilter(_statusFilters[val]);
                        }
                      },
                      items: _statusFilters.keys.map((String label) {
                        return DropdownMenuItem<String>(
                          value: label,
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: label == 'All'
                                    ? Colors.grey
                                    : label == 'Draft'
                                        ? Colors.grey
                                        : label == 'To Approve'
                                            ? Colors.blue
                                            : label == 'Approved'
                                                ? Colors.green
                                                : label == 'Paid'
                                                    ? Colors.teal
                                                    : Colors.red,
                              ),
                              const SizedBox(width: 10),
                              Text(label),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

            // Search & Filter Row (same as leave request)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Unified Search Field
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderSoft),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search expenses...',
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
                            onChanged: (val) {
                              provider.setSearchQuery(val.trim().isEmpty ? null : val.trim());
                            },
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

            // Tab content list view (Unified as in Leave Dashboard Screen)
            Expanded(
              child: _buildExpenseList(
                provider.sheetsList,
                provider,
                isApprovalList: provider.activeTab == 'pending',
                isLoading: provider.isLoadingList,
              ),
            ),
          ],
        ),
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

  Widget _buildExpenseList(List<Map<String, dynamic>> items, ExpenseProvider provider, {required bool isApprovalList, required bool isLoading}) {
    // If search query is present, filter client-side
    var filteredItems = items;
    if (provider.searchQuery != null && provider.searchQuery!.isNotEmpty) {
      final q = provider.searchQuery!.toLowerCase();
      filteredItems = items.where((i) {
        final title = (i['title'] ?? '').toString().toLowerCase();
        final desc = (i['description'] ?? '').toString().toLowerCase();
        final emp = (i['employee_name'] ?? '').toString().toLowerCase();
        return title.contains(q) || desc.contains(q) || emp.contains(q);
      }).toList();
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (filteredItems.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                isApprovalList ? 'No pending approval requests' : 'No expenses found',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return InkWell(
          onTap: () => ExpenseDetailsSheet.show(context, item),
          child: _buildExpenseCard(item, provider, isApprovalList: isApprovalList),
        );
      },
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> item, ExpenseProvider provider, {required bool isApprovalList}) {
    final statusColor = _getStatusColor(item['status']);
    final statusBgColor = _getStatusBgColor(item['status']);
    final sheetId = item['id'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Report ID: #$sheetId',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item['status_label'] ?? 'DRAFT',
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item['title'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
            ),
            if (isApprovalList && item.containsKey('employee_name')) ...[
              const SizedBox(height: 4),
              Text(
                'By: ${item['employee_name']}',
                style: const TextStyle(fontSize: 12, color: AppColors.primaryStrong, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date: ${item['date']}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                Text(
                  '৳${(item['amount'] as double).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
                ),
              ],
            ),
            if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                item['description'],
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
              ),
            ],
            if (isApprovalList && item['can_approve'] == true) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () => _showRefuseDialog(context, provider, sheetId),
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
                    onPressed: () async {
                      final success = await provider.approveSheet(sheetId);
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Expense report approved successfully.')),
                        );
                      } else if (context.mounted && provider.actionError != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(provider.actionError!)),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
