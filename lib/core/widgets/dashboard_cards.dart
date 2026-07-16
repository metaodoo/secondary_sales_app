import 'package:flutter/material.dart';

import 'package:secondary_sales/data/models/contacts/distribution_hub.dart';
import 'package:secondary_sales/data/models/sales/primary_order.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'ss_ui.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ssPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(caption, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class SalesOrderCard extends StatelessWidget {
  const SalesOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.onEditTap,
  });

  final PrimaryOrder order;
  final VoidCallback onTap;
  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    Color badgeBgColor;
    Color badgeTextColor;
    String badgeText;

    switch (order.state.toLowerCase()) {
      case 'draft':
        badgeBgColor = AppColors.borderMuted;
        badgeTextColor = AppColors.textSecondary;
        badgeText = 'DRAFT';
        break;
      case 'sent':
        badgeBgColor = const Color(0xFFFEF3C7);
        badgeTextColor = const Color(0xFFD97706);
        badgeText = 'SENT';
        break;
      case 'sale':
        badgeBgColor = const Color(0xFFDCFCE7);
        badgeTextColor = const Color(0xFF16A34A);
        badgeText = 'CONFIRM';
        break;
      case 'done':
        badgeBgColor = AppColors.primaryTint;
        badgeTextColor = AppColors.primary;
        badgeText = 'DONE';
        break;
      case 'cancel':
        badgeBgColor = const Color(0xFFFEE2E2);
        badgeTextColor = const Color(0xFFEF4444);
        badgeText = 'CANCELLED';
        break;
      default:
        badgeBgColor = AppColors.borderMuted;
        badgeTextColor = AppColors.textSecondary;
        badgeText = order.state.toUpperCase();
    }

    Color delivBgColor;
    Color delivTextColor;
    String delivText;

    switch (order.deliveryStatus.toLowerCase()) {
      case 'full':
        delivBgColor = const Color(0xFFDCFCE7);
        delivTextColor = const Color(0xFF16A34A);
        delivText = 'DELIVERED';
        break;
      case 'partial':
        delivBgColor = const Color(0xFFFEF3C7);
        delivTextColor = const Color(0xFFD97706);
        delivText = 'PARTIAL';
        break;
      case 'no':
      default:
        delivBgColor = AppColors.borderMuted;
        delivTextColor = AppColors.textSecondary;
        delivText = 'PENDING';
        break;
    }

    final orderState = order.state.toLowerCase();
    final delivStatus = order.deliveryStatus.toLowerCase();
    final isEditable =
        (orderState == 'draft' ||
            orderState == 'sent' ||
            orderState == 'quotation') ||
        (orderState == 'sale' &&
            (delivStatus == 'no' ||
                delivStatus == 'pending' ||
                delivStatus.isEmpty));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.hubName.isNotEmpty &&
                    order.hubName != 'Unknown Hub') ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.hubName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (isEditable && onEditTap != null)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          onPressed: onEditTap,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.name,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${order.currencySymbol}${order.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.primaryStrong,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: badgeTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: delivBgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            delivText,
                            style: TextStyle(
                              color: delivTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0,
                            ),
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
      ),
    );
  }
}

class DistributorCard extends StatelessWidget {
  const DistributorCard({super.key, required this.hub, required this.onTap});

  final DistributionHub hub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: ssPanelDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hub.name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              hub.address ?? 'No address',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (hub.mobile != null) ...[
              const SizedBox(height: 6),
              Text(
                hub.mobile!,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
