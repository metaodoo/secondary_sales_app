import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';

class LeaveRequestScreen extends StatelessWidget {
  const LeaveRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Request'),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: const Center(
        child: Text(
          'Leave Request Module',
          style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
