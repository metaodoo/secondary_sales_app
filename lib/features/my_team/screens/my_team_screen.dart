import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/util/parse.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/my_team/my_team_provider.dart';
import 'package:secondary_sales/features/my_team/screens/subordinate_barikoi_checkpoints_screen.dart';

class MyTeamScreen extends StatefulWidget {
  const MyTeamScreen({super.key});

  @override
  State<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends State<MyTeamScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchTeam());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _fetchTeam() {
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    context.read<MyTeamProvider>().fetchMyTeam(date: formattedDate);
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryStrong,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || picked == _selectedDate) return;
    setState(() => _selectedDate = picked);
    _fetchTeam();
  }

  void _openMapView(MyTeamMember member, String dateStr) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubordinateBarikoiCheckpointsScreen(
          employeeId: member.id,
          employeeName: member.name,
          initialDateStr: dateStr,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MyTeamProvider>();
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final filteredMembers = provider.teamMembers.where((member) {
      final query = _searchQuery.toLowerCase();
      return member.name.toLowerCase().contains(query) ||
          member.workEmail.toLowerCase().contains(query);
    }).toList();

    final onShiftCount = filteredMembers
        .where((member) => member.isActiveToday)
        .length;
    final checkedOutCount = filteredMembers
        .where((member) => member.attendanceStatus == 'Checked-Out')
        .length;
    final withTargetCount = filteredMembers
        .where((member) => member.hasSalesProgress)
        .length;

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
          'My Team',
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
      ),
      body: RefreshIndicator(
        onRefresh: () async => _fetchTeam(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _TeamOverviewCard(
              selectedDate: _selectedDate,
              totalCount: filteredMembers.length,
              onShiftCount: onShiftCount,
              checkedOutCount: checkedOutCount,
              withTargetCount: withTargetCount,
            ),
            const SizedBox(height: 14),
            _FiltersCard(
              selectedDate: _selectedDate,
              searchController: _searchController,
              searchQuery: _searchQuery,
              onSelectDate: () => _selectDate(context),
              onChanged: (value) => setState(() => _searchQuery = value),
              onClear: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
            const SizedBox(height: 16),
            const SectionHeader(title: 'Team Members'),
            const SizedBox(height: 6),
            const Text(
              'Use Open map view to inspect the selected day\'s checkpoints and travel route.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (provider.error != null) ErrorPanel(provider.error!),
            if (provider.isLoading && provider.teamMembers.isEmpty)
              const LoadingState(message: 'Retrieving team directory...')
            else if (filteredMembers.isEmpty)
              _EmptyTeamState(searchQuery: _searchQuery)
            else ...[
              if (provider.isLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
              ],
              for (final member in filteredMembers) ...[
                _SubordinateCard(
                  member: member,
                  dateStr: formattedDate,
                  onOpenMap: () => _openMapView(member, formattedDate),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _TeamOverviewCard extends StatelessWidget {
  const _TeamOverviewCard({
    required this.selectedDate,
    required this.totalCount,
    required this.onShiftCount,
    required this.checkedOutCount,
    required this.withTargetCount,
  });

  final DateTime selectedDate;
  final int totalCount;
  final int onShiftCount;
  final int checkedOutCount;
  final int withTargetCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: ssPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMMM d, yyyy').format(selectedDate),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Team snapshot',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _OverviewStat(
                  label: 'Members',
                  value: totalCount.toString(),
                  bg: AppColors.primarySoft,
                  fg: AppColors.primaryStrong,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewStat(
                  label: 'On Shift',
                  value: onShiftCount.toString(),
                  bg: AppColors.successSoft,
                  fg: const Color(0xFF166534),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewStat(
                  label: 'Checked Out',
                  value: checkedOutCount.toString(),
                  bg: const Color(0xFFEFF6FF),
                  fg: AppColors.primaryStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceTint,
              borderRadius: BorderRadius.circular(AppRadii.medium),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Text(
              '$withTargetCount member${withTargetCount == 1 ? '' : 's'} have sales-vs-target data for this day.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({
    required this.label,
    required this.value,
    required this.bg,
    required this.fg,
  });

  final String label;
  final String value;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: fg.withValues(alpha: 0.85),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.selectedDate,
    required this.searchController,
    required this.searchQuery,
    required this.onSelectDate,
    required this.onChanged,
    required this.onClear,
  });

  final DateTime selectedDate;
  final TextEditingController searchController;
  final String searchQuery;
  final VoidCallback onSelectDate;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ssPanelDecoration(),
      child: Column(
        children: [
          InkWell(
            onTap: onSelectDate,
            borderRadius: BorderRadius.circular(AppRadii.medium),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: BorderRadius.circular(AppRadii.medium),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: AppColors.primaryStrong,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      DateFormat('MMMM d, yyyy').format(selectedDate),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            onChanged: onChanged,
            decoration:
                ssInputDecoration(
                  'Search subordinates by name or email',
                  Icons.search,
                ).copyWith(
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: onClear,
                        )
                      : null,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTeamState extends StatelessWidget {
  const _EmptyTeamState({required this.searchQuery});

  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: ssPanelDecoration(),
      child: Column(
        children: [
          Icon(
            Icons.group_off_outlined,
            size: 56,
            color: AppColors.textSecondary.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 14),
          Text(
            searchQuery.isNotEmpty
                ? 'No subordinates found matching "$searchQuery".'
                : 'No subordinates assigned or active on this date.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubordinateCard extends StatelessWidget {
  const _SubordinateCard({
    required this.member,
    required this.dateStr,
    required this.onOpenMap,
  });

  final MyTeamMember member;
  final String dateStr;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final badge = _statusBadge(member.attendanceStatus);
    final percent = member.salesPercent.round();
    final salesColor = percent >= 85
        ? const Color(0xFF16A34A)
        : percent >= 70
        ? const Color(0xFFD97706)
        : const Color(0xFFDC2626);

    return Container(
      decoration: ssPanelDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryTint,
                backgroundImage: member.avatarUrl != null
                    ? NetworkImage(
                        '${context.read<AuthProvider>().baseUrl}${member.avatarUrl}',
                      )
                    : null,
                child: member.avatarUrl == null
                    ? Text(
                        member.name.isNotEmpty
                            ? member.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.primaryStrong,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (member.workEmail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        member.workEmail,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              badge,
            ],
          ),
          const SizedBox(height: 14),
          if (member.hasSalesProgress) ...[
            Row(
              children: [
                const Text(
                  'Sales vs target',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_fmtQty(member.achievedQty)} / ${_fmtQty(member.targetQty)} units',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: member.salesFraction,
                minHeight: 8,
                backgroundColor: AppColors.borderMuted,
                valueColor: AlwaysStoppedAnimation<Color>(salesColor),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$percent%',
                style: TextStyle(
                  color: salesColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              child: const Text(
                'Sales target data is not available for this member on the selected date.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.sync, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  member.lastSyncTime != null
                      ? 'Sync ${_formatSync(member.lastSyncTime!)}'
                      : 'No sync data',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: onOpenMap,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primarySoft,
                  foregroundColor: AppColors.primaryStrong,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text(
                  'Open map view',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    switch (status) {
      case 'Active Shift':
        return _StatusBadge(
          label: 'On Shift',
          fg: const Color(0xFF166534),
          bg: AppColors.successSoft,
        );
      case 'Checked-Out':
        return const _StatusBadge(
          label: 'Checked Out',
          fg: AppColors.primaryStrong,
          bg: AppColors.primarySoft,
        );
      default:
        return const _StatusBadge(
          label: 'Not Checked-In',
          fg: AppColors.textSecondary,
          bg: AppColors.borderMuted,
        );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.fg, required this.bg});

  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

String _fmtQty(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}

String _formatSync(String raw) {
  final parsed = asDateTime(raw);
  if (parsed == null) return raw;
  return DateFormat('MMM d, h:mm a').format(parsed);
}
