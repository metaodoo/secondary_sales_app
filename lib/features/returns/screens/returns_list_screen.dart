import 'dart:async';
import 'package:secondary_sales/core/theme/app_theme.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/features/returns/return_provider.dart';
import 'package:secondary_sales/data/models/return_scrap_summary.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/returns/screens/create_return_screen.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/core/access/access_resources.dart';

class ReturnsListScreen extends StatefulWidget {
  final String moduleType;
  const ReturnsListScreen({super.key, this.moduleType = 'primary'});

  @override
  State<ReturnsListScreen> createState() => _ReturnsListScreenState();
}

class _ReturnsListScreenState extends State<ReturnsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _state = 'all';
  List<ReturnScrapSummary> _returns = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchReturns());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchReturns() async {
    final provider = context.read<ReturnProvider>();
    final results = await provider.fetchReturns(
      search: _searchController.text,
      state: _state,
      type: widget.moduleType,
    );
    if (mounted) {
      setState(() {
        _returns = results;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _fetchReturns);
  }

  Future<void> _openCreateReturn() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateReturnScreen(moduleType: widget.moduleType),
      ),
    );
    if (mounted) {
      _fetchReturns();
    }
  }

  int get _activeCount =>
      _returns.where((r) => r.state != 'done' && r.state != 'cancel').length;
  int get _pendingCount => _returns
      .where((r) => r.state == 'assigned' || r.state == 'waiting')
      .length;

  Color _stateColor(String state) {
    return switch (state) {
      'done' => const Color(0xFF10B981),
      'cancel' => Colors.red,
      'assigned' => const Color(0xFFF59E0B),
      'waiting' => const Color(0xFFF59E0B),
      'confirmed' => const Color(0xFFF59E0B),
      _ => AppColors.textSecondary,
    };
  }

  Color _stateBgColor(String state) {
    return switch (state) {
      'done' => const Color(0xFFD1FAE5),
      'cancel' => const Color(0xFFFEE2E2),
      'assigned' => const Color(0xFFFEF3C7),
      'waiting' => const Color(0xFFFEF3C7),
      'confirmed' => const Color(0xFFFEF3C7),
      _ => AppColors.borderMuted,
    };
  }

  String _stateLabel(String state) {
    return switch (state) {
      'done' => 'DONE',
      'cancel' => 'CANCELLED',
      'assigned' => 'READY',
      'waiting' => 'WAITING',
      'confirmed' => 'CONFIRMED',
      'draft' => 'DRAFT',
      _ => state.toUpperCase(),
    };
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Returns',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _state,
                decoration: ssInputDecoration('Status', Icons.filter_list),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Status')),
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(
                    value: 'assigned',
                    child: Text('Pending (Ready)'),
                  ),
                  DropdownMenuItem(
                    value: 'done',
                    child: Text('Processed (Done)'),
                  ),
                  DropdownMenuItem(value: 'cancel', child: Text('Cancelled')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _state = value);
                    _fetchReturns();
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReturnProvider>();
    final auth = context.watch<AuthProvider>();

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
          'Returns List',
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderMuted, height: 1),
        ),
      ),
      floatingActionButton: auth.canDo(AppAction.returnCreateFor(widget.moduleType))
          ? SsCreateFab(label: 'New Return', onPressed: _openCreateReturn)
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchReturns,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, kSsFabScrollPadding),
            children: [
              // Search Field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search reference or customer',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: InkWell(
                    onTap: _showFilterDialog,
                    child: const Icon(
                      Icons.filter_list,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 24),

              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL ACTIVE',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_activeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDEE5FC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PENDING REVIEW',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_pendingCount',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (provider.isLoading && _returns.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_returns.isEmpty)
                const EmptyPanel(message: 'No returns found')
              else ...[
                if (provider.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),
                ..._returns.map((ret) {
                  final origin = ret.origin?.toString() ?? '-';
                  // In standard odoo origin may look like 'Return from Distributor A'
                  final customerName = origin.replaceAll('Return from ', '');
                  final date =
                      ret.scheduledDate?.toString().split(' ')[0] ?? '-';

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateReturnScreen(
                            returnId: ret.id,
                            moduleType: widget.moduleType,
                          ),
                        ),
                      ).then((_) => _fetchReturns());
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDDE6F2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '#${ret.name}',
                                style: const TextStyle(
                                  color: Color(0xFF0038A8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _stateBgColor(ret.state),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _stateLabel(ret.state),
                                  style: TextStyle(
                                    color: _stateColor(ret.state),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            customerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(
                              height: 1,
                              color: AppColors.borderMuted,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 16,
                                    color: Colors.black54,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    date,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 16,
                                    color: Colors.black54,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'View Details',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
