import 'package:flutter/material.dart';

import 'package:secondary_sales/data/models/contacts/distribution_hub.dart';
import 'package:secondary_sales/data/models/sales/primary_order.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'ss_ui.dart';

class StatusBadgeData {
  final String label;
  final Color bgColor;
  final Color textColor;

  const StatusBadgeData({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });
}

StatusBadgeData getPrimaryOrderStatusBadge(String state, String deliveryStatus) {
  final s = state.toLowerCase();
  final d = deliveryStatus.toLowerCase();

  // If a delivery validation has occurred, show delivery state
  if (d == 'full') {
    return const StatusBadgeData(
      label: 'Delivery Fully Done',
      bgColor: Color(0xFFDCFCE7),
      textColor: Color(0xFF16A34A),
    );
  } else if (d == 'partial') {
    return const StatusBadgeData(
      label: 'Delivery Partially Done',
      bgColor: Color(0xFFFEF3C7),
      textColor: Color(0xFFD97706),
    );
  }

  // Otherwise (delivery not validated yet), show sale order status
  if (s == 'draft') {
    return const StatusBadgeData(
      label: 'Draft',
      bgColor: AppColors.borderMuted,
      textColor: AppColors.textSecondary,
    );
  } else if (s == 'cancel') {
    return const StatusBadgeData(
      label: 'Cancelled',
      bgColor: Color(0xFFFEE2E2),
      textColor: Color(0xFFEF4444),
    );
  } else if (s == 'sale' || s == 'done') {
    return const StatusBadgeData(
      label: 'Confirmed',
      bgColor: Color(0xFFDCFCE7),
      textColor: Color(0xFF16A34A),
    );
  }

  return StatusBadgeData(
    label: state.toUpperCase(),
    bgColor: AppColors.borderMuted,
    textColor: AppColors.textSecondary,
  );
}

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
    final statusBadge = getPrimaryOrderStatusBadge(order.state, order.deliveryStatus);

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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBadge.bgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusBadge.label.toUpperCase(),
                        style: TextStyle(
                          color: statusBadge.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.date,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${order.lineCount} ${order.lineCount == 1 ? 'item' : 'items'}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
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
