import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/my_team/my_team_provider.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/my_team/screens/subordinate_barikoi_checkpoints_screen.dart';
import 'package:intl/intl.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTeam();
    });
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
    final DateTime? picked = await showDatePicker(
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchTeam();
    }
  }

  @override
  Widget build(BuildContext context) {
    final myTeamProvider = context.watch<MyTeamProvider>();
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Filter local list
    final filteredMembers = myTeamProvider.teamMembers.where((member) {
      return member.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          member.workEmail.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Team',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryStrong),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Panel
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              children: [
                // Date Selector row
                InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderSoft),
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.surfaceTint,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18, color: AppColors.primaryStrong),
                            const SizedBox(width: 10),
                            Text(
                              'Date: ${DateFormat('MMMM dd, yyyy').format(_selectedDate)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search subordinates by name...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceTint,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.borderSoft),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.borderSoft),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primaryStrong),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Main Subordinate list
          Expanded(
            child: myTeamProvider.isLoading && myTeamProvider.teamMembers.isEmpty
                ? const Center(
                    child: LoadingState(message: 'Retrieving team directory...'),
                  )
                : myTeamProvider.error != null && myTeamProvider.teamMembers.isEmpty
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: ErrorPanel(myTeamProvider.error!),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _fetchTeam(),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16.0),
                          children: [
                            if (myTeamProvider.error != null) ...[
                              ErrorPanel(myTeamProvider.error!),
                              const SizedBox(height: 12),
                            ],
                            if (myTeamProvider.isLoading) ...[
                              const LinearProgressIndicator(),
                              const SizedBox(height: 12),
                            ],
                            if (filteredMembers.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.group_off_outlined,
                                      size: 64,
                                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'No subordinates found matching "$_searchQuery".'
                                          : 'No subordinates assigned or active today.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...filteredMembers.map(
                                (member) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildSubordinateCard(context, member, formattedDate),
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

  Widget _buildSubordinateCard(BuildContext context, MyTeamMember member, String dateStr) {
    Color statusColor;
    Color statusBgColor;

    switch (member.attendanceStatus) {
      case 'Active Shift':
        statusColor = const Color(0xFF16A34A); // Green
        statusBgColor = const Color(0xFFDCFCE7);
        break;
      case 'Checked-Out':
        statusColor = AppColors.primaryStrong; // Blue
        statusBgColor = AppColors.primarySoft;
        break;
      default:
        statusColor = AppColors.textSecondary; // Grey
        statusBgColor = AppColors.borderMuted;
    }

    return GestureDetector(
      onTap: () {
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
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSoft),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryTint,
              backgroundImage: member.avatarUrl != null
                  ? NetworkImage('${context.read<AuthProvider>().baseUrl}${member.avatarUrl}')
                  : null,
              child: member.avatarUrl == null
                  ? Text(
                      member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primaryStrong,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // Middle Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (member.workEmail.isNotEmpty)
                    Text(
                      member.workEmail,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.sync, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        member.lastSyncTime != null
                            ? 'Sync: ${member.lastSyncTime}'
                            : 'No sync data',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Right Status Badge and Arrow
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    member.attendanceStatus,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
