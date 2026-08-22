import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';

import 'package:secondary_sales/data/models/contacts/distribution_hub.dart';
import 'package:secondary_sales/data/models/sales/order_line_entry.dart';
import 'package:secondary_sales/data/models/sales/product.dart';
import 'ss_ui.dart';

class SelectedDistributorCard extends StatelessWidget {
  const SelectedDistributorCard({super.key, required this.hub});

  final DistributionHub hub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ssPanelDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hub.displayNameWithCode,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  hub.address ?? 'No address',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class OrderLineCard extends StatelessWidget {
  const OrderLineCard({
    super.key,
    required this.line,
    required this.onChanged,
    required this.onRemove,
  });

  final OrderLineEntry line;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onRemove,
              ),
            ],
          ),
          Text(
            'Stock: ${line.product.stock?.toInt() ?? 0}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const Divider(height: 24, color: AppColors.borderSoft),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Price',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '৳${line.product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SmallStepper(
                value: '${line.quantity}',
                isDecimal: false,
                onMinus: () {
                  if (line.quantity > 1) {
                    line.quantity--;
                    onChanged();
                  }
                },
                onPlus: () {
                  line.quantity++;
                  onChanged();
                },
                onValueInput: (val) {
                  final parsed = int.tryParse(val);
                  if (parsed != null && parsed > 0) {
                    line.quantity = parsed;
                    onChanged();
                  }
                },
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '৳${line.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: AppColors.primaryStrong,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.isSelected,
    required this.quantity,
    required this.onTap,
    required this.onDecrease,
    required this.onIncrease,
    this.onQuantityInput,
  });

  final Product product;
  final bool isSelected;
  final int quantity;
  final VoidCallback onTap;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<int>? onQuantityInput;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : Colors.white,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : const Color(0xFFDDE6F2),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '৳${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${product.code ?? 'No code'} • ${product.uom}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (product.stock != null) ...[
              const SizedBox(height: 6),
              Text(
                'DB: ${product.stock!.toStringAsFixed(0)} ${product.uom}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            if (isSelected) ...[
              const SizedBox(height: 12),
              SmallStepper(
                value: '$quantity',
                onMinus: onDecrease,
                onPlus: onIncrease,
                onValueInput: (val) {
                  final parsed = int.tryParse(val);
                  if (parsed != null && onQuantityInput != null) {
                    onQuantityInput!(parsed);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ConfirmPanel extends StatelessWidget {
  const ConfirmPanel({
    super.key,
    required this.expectedDeliveryDate,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.isLoading,
    required this.canConfirm,
    required this.onDateTap,
    required this.onConfirm,
  });

  final DateTime expectedDeliveryDate;
  final double subtotal;
  final double discount;
  final double total;
  final bool isLoading;
  final bool canConfirm;
  final VoidCallback onDateTap;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expected Delivery Date *',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onDateTap,
            child: InputDecorator(
              decoration: ssInputDecoration('', Icons.calendar_today_outlined),
              child: Text(ssFormatDate(expectedDeliveryDate)),
            ),
          ),
          const SizedBox(height: 12),
          _AmountRow(label: 'Subtotal', amount: subtotal),
          _AmountRow(label: 'Discount', amount: -discount, isDiscount: true),
          const Divider(),
          _AmountRow(label: 'Total', amount: total, isTotal: true),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: (!canConfirm || isLoading) ? null : onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Confirm Order',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.isDiscount = false,
    this.isTotal = false,
  });

  final String label;
  final double amount;
  final bool isDiscount;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isTotal ? Colors.black : AppColors.textSecondary,
                fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${amount < 0 ? '-' : ''}৳${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: isDiscount
                  ? Colors.red
                  : isTotal
                  ? const Color(0xFF2563EB)
                  : Colors.black,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The "not in the van, settle it on the bill" switch.
///
/// Appears only when a line actually carries a return, because that is the only
/// time the choice exists. It states the consequence rather than the mechanism:
/// a rep does not care which stock documents get written, they care whether the
/// goods ride out on the van and whether the customer's bill moves.
class AdjustReturnToggle extends StatelessWidget {
  const AdjustReturnToggle({
    required this.value,
    required this.vanStock,
    required this.onChanged,
  });

  final bool value;
  final int vanStock;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // The requirement's actual trigger is "product not available in Van". When
    // that is true and the rep has not flipped the switch, say so -- it is the
    // one moment the app knows more than they do.
    final bool suggest = !value && vanStock <= 0;
    final Color accent = value ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
        decoration: BoxDecoration(
          color: value
              ? AppColors.primary.withValues(alpha: 0.06)
              : (suggest ? Colors.amber.withValues(alpha: 0.10) : Colors.transparent),
          border: const Border(
            top: BorderSide(color: AppColors.borderSoft),
          ),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
        ),
        child: Row(
          children: [
            Icon(
              value ? Icons.receipt_long : Icons.swap_horiz,
              size: 18,
              color: accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Adjust Return',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: value ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value
                        ? 'Taken back without delivery · adjusted on the bill'
                        : (suggest
                            ? 'No van stock — turn on to take this return'
                            : 'Exchanged from van stock'),
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      color: suggest
                          ? Colors.amber.shade900
                          : AppColors.textSecondary,
                      fontWeight: suggest ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
