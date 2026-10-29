import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/util/parse.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/hr/attendance_provider.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

/// Asks before an attendance log-out: it is one tap, and easy to mix up
/// with logging out of the app.
Future<bool> confirmAttendanceLogOut(BuildContext context) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Log out of attendance?'),
      content: const Text('Your log-out time will be saved as now.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Log Out'),
        ),
      ],
    ),
  );
  return yes ?? false;
}

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AttendanceScreenContent();
  }
}

class _AttendanceScreenContent extends StatefulWidget {
  const _AttendanceScreenContent();

  @override
  State<_AttendanceScreenContent> createState() => _AttendanceScreenContentState();
}

class _AttendanceScreenContentState extends State<_AttendanceScreenContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _historyScrollController = ScrollController();
  final ScrollController _teamScrollController = ScrollController();
  final TextEditingController _teamSearchController = TextEditingController();
  DateTime _currentTime = DateTime.now();
  Timer? _clockTimer;
  DateTimeRange? _selectedDateRange;
  DateTimeRange? _selectedTeamDateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _historyScrollController.addListener(_onHistoryScroll);
    _teamScrollController.addListener(_onTeamScroll);
    _clockTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AttendanceProvider>().refresh();
      }
    });
  }

  void _onHistoryScroll() {
    if (!_historyScrollController.hasClients) return;
    if (_historyScrollController.position.pixels >=
        _historyScrollController.position.maxScrollExtent - 200) {
      context.read<AttendanceProvider>().loadMoreHistory();
    }
  }

  void _onTeamScroll() {
    if (!_teamScrollController.hasClients) return;
    if (_teamScrollController.position.pixels >=
        _teamScrollController.position.maxScrollExtent - 200) {
      context.read<AttendanceProvider>().loadMoreTeamHistory();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _historyScrollController.dispose();
    _teamScrollController.dispose();
    _teamSearchController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }

  String _formatDate(DateTime dt) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}";
  }

  String _formatRecordDate(DateTime dt) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${months[dt.month - 1]} ${dt.day}, ${dt.year} (${weekdays[dt.weekday - 1]})";
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
            Text('Attendance Error'),
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
    context.read<AttendanceProvider>().clearError();
  }

  Future<void> _pickDateRange(AttendanceProvider provider) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
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
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  Future<void> _pickTeamDateRange(AttendanceProvider provider) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: _selectedTeamDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
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
      setState(() {
        _selectedTeamDateRange = picked;
      });
      provider.filterTeamHistory(
        startDate: picked.start.toString().split(' ')[0],
        endDate: picked.end.toString().split(' ')[0],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();

    if (provider.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleError(context, provider.errorMessage!);
      });
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Attendance',
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
            child: ProfileAvatar(currentDestinationLabel: 'Attendance'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Log In/Out'),
            Tab(text: 'Own'),
            Tab(text: 'Team'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCheckInOutTab(provider),
          _buildRecordsTab(provider),
          _buildTeamRecordsTab(provider),
        ],
      ),
    );
  }

  Widget _buildCheckInOutTab(AttendanceProvider provider) {
    final isCheckedIn = provider.isCheckedIn;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.large),
              side: const BorderSide(color: AppColors.borderSoft),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatTime(_currentTime),
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(_currentTime),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          ),
                        ],
                      ),
                      if (isCheckedIn)
                        const CircleAvatar(
                          backgroundColor: AppColors.successSoft,
                          radius: 20,
                          child: Icon(Icons.check, color: Colors.green, size: 24),
                        )
                      else
                        const CircleAvatar(
                          backgroundColor: AppColors.warningSoft,
                          radius: 20,
                          child: Icon(Icons.logout, color: Colors.orange, size: 20),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isCheckedIn
                          ? "You are logged in!"
                          : "You are logged out",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isCheckedIn
                          ? "Have a great day at work."
                          : "Click below to log in for attendance.",
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: provider.isActionLoading
                          ? null
                          : () async {
                              if (isCheckedIn && !await confirmAttendanceLogOut(context)) {
                                return;
                              }
                              if (!mounted || !context.mounted) return;
                              provider.performAction(
                                isCheckedIn ? 'check_out' : 'check_in',
                                context: context,
                              );
                            },
                      child: provider.isActionLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                                if (provider.loadingMessage.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      provider.loadingMessage,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : Text(isCheckedIn ? 'Log Out' : 'Log In', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const Divider(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: Colors.green, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Location',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              provider.activeCheckInAddress ?? 'Locating/Not available...',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                        onPressed: provider.refresh,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              "Today's Activity",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 12),
          if (provider.historyLogs.isNotEmpty &&
              provider.historyLogs.first['date'] == _currentTime.toString().split(' ')[0])
            _buildTodayActivityCard(provider.historyLogs.first)
          else
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.borderSoft)),
              child: const Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(Icons.history_toggle_off, size: 36, color: AppColors.textSecondary),
                    SizedBox(height: 8),
                    Text('No activity recorded today', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTodayActivityCard(Map<String, dynamic> todayLog) {
    final checkInVal = todayLog['check_in'];
    final checkOutVal = todayLog['check_out'];
    final checkIn = formatDisplayTime(checkInVal);
    final checkOut = formatDisplayTime(checkOutVal);

    final checkInAddrVal = todayLog['check_in_address'];
    final checkOutAddrVal = todayLog['check_out_address'];
    final checkInAddress = (checkInAddrVal is String && checkInAddrVal.isNotEmpty && checkInAddrVal != 'false')
        ? checkInAddrVal
        : 'No Address';
    final checkOutAddress = (checkOutAddrVal is String && checkOutAddrVal.isNotEmpty && checkOutAddrVal != 'false')
        ? checkOutAddrVal
        : 'No Address';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.large),
        side: const BorderSide(color: AppColors.borderSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.login, color: Colors.green, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Logged In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(checkInAddress, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Text(checkIn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(),
            ),
            Row(
              children: [
                const Icon(Icons.logout, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Logged Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(checkOutAddress, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Text(checkOut, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsTab(AttendanceProvider provider) {
    final logs = _selectedDateRange == null
        ? provider.historyLogs
        : provider.historyLogs.where((log) {
            final logDateStr = log['date'];
            if (logDateStr == null) return false;
            final logDate = DateTime.tryParse(logDateStr);
            if (logDate == null) return false;
            final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
            final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
            return logDate.isAfter(start.subtract(const Duration(seconds: 1))) && logDate.isBefore(end.add(const Duration(seconds: 1)));
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: InkWell(
            onTap: () => _pickDateRange(provider),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderSoft),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedDateRange == null
                          ? 'Select Date Range'
                          : '${_selectedDateRange!.start.toString().split(' ')[0]} to ${_selectedDateRange!.end.toString().split(' ')[0]}',
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  if (_selectedDateRange != null)
                    IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.clear, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _selectedDateRange = null;
                        });
                      },
                    )
                  else
                    const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await provider.refresh();
            },
            child: provider.isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : logs.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 100),
                          _buildEmptyState(),
                        ],
                      )
                    : ListView.builder(
                        controller: _historyScrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: logs.length + (provider.isLoadingMoreHistory ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= logs.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          return _buildRecordCard(logs[index]);
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    // Side padding and centred lines keep long text off the screen edges.
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.find_in_page_outlined, size: 64, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text(
            'No attendance history found',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
          ),
          SizedBox(height: 4),
          Text(
            'Try selecting a different date range',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamRecordsTab(AttendanceProvider provider) {
    final teamLogs = provider.teamHistoryLogs;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _teamSearchController,
                decoration: InputDecoration(
                  hintText: 'Search by employee or outlet...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                  suffixIcon: _teamSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _teamSearchController.clear();
                            setState(() {});
                            provider.filterTeamHistory(
                              search: '',
                              startDate: _selectedTeamDateRange?.start.toString().split(' ')[0],
                              endDate: _selectedTeamDateRange?.end.toString().split(' ')[0],
                            );
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                ),
                onSubmitted: (val) {
                  provider.filterTeamHistory(
                    search: val,
                    startDate: _selectedTeamDateRange?.start.toString().split(' ')[0],
                    endDate: _selectedTeamDateRange?.end.toString().split(' ')[0],
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Date range picker button
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTeamDateRange(provider),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedTeamDateRange != null
                                ? AppColors.primary
                                : AppColors.borderSoft,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          color: _selectedTeamDateRange != null
                              ? AppColors.primarySoft.withValues(alpha: 0.3)
                              : Colors.white,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: _selectedTeamDateRange != null
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedTeamDateRange == null
                                    ? 'All Dates'
                                    : '${_selectedTeamDateRange!.start.month}/${_selectedTeamDateRange!.start.day} - ${_selectedTeamDateRange!.end.month}/${_selectedTeamDateRange!.end.day}',
                                style: TextStyle(
                                  color: _selectedTeamDateRange == null
                                      ? AppColors.textSecondary
                                      : AppColors.primaryStrong,
                                  fontWeight: _selectedTeamDateRange == null
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_selectedTeamDateRange != null)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedTeamDateRange = null;
                                  });
                                  provider.filterTeamHistory(
                                    startDate: '',
                                    endDate: '',
                                  );
                                },
                                child: const Icon(Icons.close, size: 16, color: AppColors.primary),
                              )
                            else
                              const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Employee filter button
                  Expanded(
                    child: InkWell(
                      onTap: () => _showSubordinateFilterSheet(context, provider),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: provider.selectedSubordinateId != null
                                ? AppColors.primary
                                : AppColors.borderSoft,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          color: provider.selectedSubordinateId != null
                              ? AppColors.primarySoft.withValues(alpha: 0.3)
                              : Colors.white,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              color: provider.selectedSubordinateId != null
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                provider.selectedSubordinateName ?? 'All Members',
                                style: TextStyle(
                                  color: provider.selectedSubordinateId == null
                                      ? AppColors.textSecondary
                                      : AppColors.primaryStrong,
                                  fontWeight: provider.selectedSubordinateId == null
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (provider.selectedSubordinateId != null)
                              InkWell(
                                onTap: () {
                                  provider.selectSubordinate(null, null);
                                },
                                child: const Icon(Icons.close, size: 16, color: AppColors.primary),
                              )
                            else
                              const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await provider.loadTeamHistory(reset: true);
            },
            child: provider.isLoadingTeamHistory
                ? const Center(child: CircularProgressIndicator())
                : teamLogs.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          _buildTeamEmptyState(),
                        ],
                      )
                    : ListView.builder(
                        controller: _teamScrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        itemCount: teamLogs.length + (provider.isLoadingMoreTeamHistory ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= teamLogs.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          return _buildRecordCard(teamLogs[index], isTeam: true);
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamEmptyState() {
    // Side padding and centred lines keep long text off the screen edges.
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 64, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text(
            'No team attendance found',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
          ),
          SizedBox(height: 4),
          Text(
            'Try other dates or team members.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _showSubordinateFilterSheet(BuildContext context, AttendanceProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final subordinates = provider.teamSubordinates.where((s) {
              final name = (s['name'] ?? '').toString().toLowerCase();
              return name.contains(query.toLowerCase());
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.people_alt_outlined, color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Filter by Team Member',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryStrong,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search team member...',
                          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.surfaceTint,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.borderSoft),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.borderSoft),
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            query = val;
                          });
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: provider.selectedSubordinateId == null
                                  ? AppColors.primary
                                  : Colors.grey.shade200,
                              radius: 16,
                              child: Icon(
                                Icons.group,
                                size: 18,
                                color: provider.selectedSubordinateId == null
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                            title: const Text(
                              'All Team Members',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            trailing: provider.selectedSubordinateId == null
                                ? const Icon(Icons.check, color: AppColors.primary, size: 20)
                                : null,
                            onTap: () {
                              provider.selectSubordinate(null, null);
                              Navigator.pop(ctx);
                            },
                          ),
                          if (subordinates.isEmpty && query.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(
                                child: Text(
                                  'No team members match search',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              ),
                            )
                          else
                            ...subordinates.map((sub) {
                              final subId = sub['id'] as int;
                              final subName = sub['name']?.toString() ?? 'Unnamed';
                              final isSelected = provider.selectedSubordinateId == subId;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? AppColors.primarySoft
                                      : AppColors.surfaceTint,
                                  radius: 16,
                                  child: Text(
                                    subName.isNotEmpty ? subName.characters.first.toUpperCase() : '?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  subName,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check, color: AppColors.primary, size: 20)
                                    : null,
                                onTap: () {
                                  provider.selectSubordinate(subId, subName);
                                  Navigator.pop(ctx);
                                },
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> log, {bool isTeam = false}) {
    final dateStr = log['date'] ?? 'Unknown Date';
    DateTime? parsedDate = asDateTime(dateStr);
    final formattedDate = parsedDate != null ? _formatRecordDate(parsedDate).split(' (').first : dateStr;

    final checkIn = formatDisplayTime(log['check_in']);
    final checkOut = formatDisplayTime(log['check_out']);
    // The server sends an empty string, not null, while still logged in.
    final isCurrentlyCheckedIn = (log['check_out']?.toString() ?? '').isEmpty;
    final hours = (log['worked_hours'] as num?)?.toStringAsFixed(2) ?? '0.0';
    final checkInAddress = log['check_in_address'];
    final checkOutAddress = log['check_out_address'];
    final distributorName = log['distributor_name'];
    final employeeName = (log['employee_name']?.toString() ?? '').trim();

    final auth = context.read<AuthProvider>();
    final baseUrl = auth.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final rawImageUrl = log['image_url']?.toString();
    final String? fullImageUrl = (rawImageUrl != null && rawImageUrl.isNotEmpty)
        ? (rawImageUrl.startsWith('http') ? rawImageUrl : '$baseUrl$rawImageUrl')
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.large),
        side: const BorderSide(color: AppColors.borderSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isTeam && employeeName.isNotEmpty) ...[
              Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: AppColors.primarySoft,
                    child: Text(
                      employeeName.characters.first.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      employeeName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryStrong,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDate,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCurrentlyCheckedIn ? AppColors.primarySoft : AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCurrentlyCheckedIn ? 'Logged In' : 'Logged Out',
                    style: TextStyle(
                      color: isCurrentlyCheckedIn ? AppColors.primary : Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (fullImageUrl != null) ...[
                  GestureDetector(
                    onTap: () => _showSelfiePreviewDialog(
                      context: context,
                      imageUrl: fullImageUrl,
                      title: isTeam && employeeName.isNotEmpty ? '$employeeName Photo' : 'Check-in Photo',
                      subtitle: '$formattedDate • $checkIn',
                      authHeaders: auth.authHeaders,
                    ),
                    child: Container(
                      width: 52,
                      height: 52,
                      margin: const EdgeInsets.only(right: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryTint, width: 1.5),
                        color: AppColors.surfaceTint,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            fullImageUrl,
                            headers: auth.authHeaders,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey.shade100,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image_outlined, size: 20, color: Colors.grey),
                                  SizedBox(height: 2),
                                  Text('Photo', style: TextStyle(fontSize: 8, color: Colors.grey)),
                                ],
                              ),
                            ),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: Colors.grey.shade100,
                                child: const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            },
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(5),
                                ),
                              ),
                              child: const Icon(
                                Icons.fullscreen_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LOG IN', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(checkIn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LOG OUT', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(checkOut, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
            if (!isCurrentlyCheckedIn) ...[
              const SizedBox(height: 12),
              Text(
                'Work Hours: $hours hrs',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
              ),
            ],
            if (distributorName != null && distributorName is String && distributorName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'At: $distributorName',
                style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
            if (checkInAddress != null && checkInAddress is String && checkInAddress.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'In Address: $checkInAddress',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
            if (checkOutAddress != null && checkOutAddress is String && checkOutAddress.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Out Address: $checkOutAddress',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Within Geofence',
                        style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (fullImageUrl != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showSelfiePreviewDialog(
                      context: context,
                      imageUrl: fullImageUrl,
                      title: isTeam && employeeName.isNotEmpty ? '$employeeName Photo' : 'Check-in Photo',
                      subtitle: '$formattedDate • $checkIn',
                      authHeaders: auth.authHeaders,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primaryTint),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_camera_rounded, color: AppColors.primary, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'View Photo',
                            style: TextStyle(
                              color: AppColors.primaryStrong,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSelfiePreviewDialog({
    required BuildContext context,
    required String imageUrl,
    required String title,
    required String subtitle,
    required Map<String, String> authHeaders,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  imageUrl,
                  headers: authHeaders,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, err, st) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, size: 54, color: Colors.white70),
                      SizedBox(height: 10),
                      Text(
                        'Failed to load check-in photo',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
