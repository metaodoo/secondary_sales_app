import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/hr/attendance_provider.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AttendanceProvider(
        context.read<AuthProvider>(),
      ),
      child: const _AttendanceScreenContent(),
    );
  }
}

class _AttendanceScreenContent extends StatefulWidget {
  const _AttendanceScreenContent();

  @override
  State<_AttendanceScreenContent> createState() => _AttendanceScreenContentState();
}

class _AttendanceScreenContentState extends State<_AttendanceScreenContent> {
  Timer? _timer;
  String _elapsedTime = "00:00:00";

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final provider = context.read<AttendanceProvider>();
      if (provider.isCheckedIn && provider.activeCheckInTime != null) {
        final checkInTime = DateTime.tryParse(provider.activeCheckInTime!);
        if (checkInTime != null) {
          final now = DateTime.now();
          final diff = now.difference(checkInTime);
          
          String twoDigits(int n) => n.toString().padLeft(2, '0');
          final hours = twoDigits(diff.inHours);
          final minutes = twoDigits(diff.inMinutes.remainder(60));
          final seconds = twoDigits(diff.inSeconds.remainder(60));
          
          setState(() {
            _elapsedTime = "$hours:$minutes:$seconds";
          });
        }
      }
    });
  }

  void _handleError(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
      ),
    );
    context.read<AttendanceProvider>().clearError();
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
        title: const Text('Attendance'),
      ),
      body: Column(
        children: [
          _buildActionCard(context, provider),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Attendance History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: provider.isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _buildHistoryList(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, AttendanceProvider provider) {
    final isCheckedIn = provider.isCheckedIn;

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (provider.isLoadingStatus)
              const CircularProgressIndicator()
            else ...[
              if (isCheckedIn) ...[
                const Text('Time since check-in', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  _elapsedTime,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                if (provider.activeCheckInAddress != null && provider.activeCheckInAddress!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('Check-in Location', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provider.activeCheckInAddress!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ] else ...[
                const Text('Not currently checked in', style: TextStyle(fontSize: 16)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: provider.isActionLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(isCheckedIn ? Icons.logout : Icons.login),
                  label: Text(isCheckedIn ? 'CHECK OUT' : 'CHECK IN'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCheckedIn ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: provider.isActionLoading
                      ? null
                      : () {
                          provider.performAction(isCheckedIn ? 'check_out' : 'check_in');
                        },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(AttendanceProvider provider) {
    if (provider.historyLogs.isEmpty) {
      return const Center(
        child: Text("No attendance history found."),
      );
    }

    return ListView.separated(
      itemCount: provider.historyLogs.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final log = provider.historyLogs[index];
        final date = log['date'] ?? 'Unknown Date';
        final checkIn = log['check_in']?.toString().split(' ').last ?? '--:--:--';
        final checkOut = log['check_out']?.toString().split(' ').last ?? '--:--:--';
        final hours = (log['worked_hours'] as num?)?.toStringAsFixed(2) ?? '0.0';
        final distributorName = log['distributor_name'];
        final checkInAddress = log['check_in_address'];

        return ListTile(
          leading: const Icon(Icons.access_time),
          title: Text(date),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (distributorName != null && distributorName is String && distributorName.isNotEmpty)
                Text(
                  'At: $distributorName',
                  style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.indigo),
                )
              else if (checkInAddress != null && checkInAddress is String && checkInAddress.isNotEmpty)
                Text(
                  checkInAddress,
                  style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.indigo, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              Text('In: $checkIn | Out: $checkOut'),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$hours hrs', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }
}
