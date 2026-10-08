import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';

/// Shows a bottom sheet to select the Modern Trade Return Type
/// ('return' or 'replacement') for Non-Saleable and Quality returns.
Future<String?> showMtReturnTypePicker(
  BuildContext context, {
  required String returnBucket,
  String? currentType,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _MtReturnTypeSheetContent(
      returnBucket: returnBucket,
      currentType: currentType,
    ),
  );
}

class _MtReturnTypeSheetContent extends StatelessWidget {
  final String returnBucket;
  final String? currentType;

  const _MtReturnTypeSheetContent({
    required this.returnBucket,
    this.currentType,
  });

  String get _bucketTitle {
    if (returnBucket == 'quality') return 'Quality Return';
    return 'Non-Saleable Return';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Return Type',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _bucketTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Option 1: Return (Scrap only)
            _buildOption(
              context: context,
              title: 'Return',
              subtitle: 'Damaged/Defect items returned to scrap. No physical replacement goods will be delivered.',
              typeKey: 'return',
              badge: 'Scrap Only',
              icon: Icons.assignment_return_outlined,
              primaryColor: const Color(0xFFE65100),
              bgColor: const Color(0xFFFFF3E0),
            ),
            const SizedBox(height: 12),

            // Option 2: Replacement (Scrap + Delivery)
            _buildOption(
              context: context,
              title: 'Replacement',
              subtitle: 'Return damaged items and generate a fresh replacement delivery order for the outlet.',
              typeKey: 'replacement',
              badge: 'Scrap + Delivery',
              icon: Icons.published_with_changes_outlined,
              primaryColor: const Color(0xFF0288D1),
              bgColor: const Color(0xFFE1F5FE),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String typeKey,
    required String badge,
    required IconData icon,
    required Color primaryColor,
    required Color bgColor,
  }) {
    final isCurrent = typeKey == currentType;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, typeKey),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: isCurrent ? 0.65 : 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrent ? primaryColor : primaryColor.withValues(alpha: 0.35),
              width: isCurrent ? 1.8 : 1.2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
                ),
                child: Icon(icon, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check, size: 10, color: Colors.green.shade800),
                                const SizedBox(width: 2),
                                Text(
                                  'Current',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isCurrent ? Icons.check_circle : Icons.chevron_right,
                color: isCurrent ? primaryColor : primaryColor.withValues(alpha: 0.7),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
