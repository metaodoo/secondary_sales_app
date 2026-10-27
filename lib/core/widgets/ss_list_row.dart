import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';

/// One record in a list: a title, up to a few one-line details, an optional
/// status line and one action. Compact, so a 720p phone shows about five
/// rows; tap the row for everything else about the record.
///
/// The action sits on the right, and moves below the text when the row is
/// too narrow for both (narrow phones, large text).
class SsListRow extends StatelessWidget {
  const SsListRow({
    super.key,
    required this.title,
    this.details = const [],
    this.status = const [],
    this.action,
    this.onTap,
    this.selected = false,
  });

  /// Two lines at most.
  final String title;

  /// One line each, cut with "..." when long. Empty strings are skipped.
  final List<String> details;

  /// Small widgets on one line under the details, e.g. a distance or
  /// "Checked in at 10:30". Wraps when there is no room.
  final List<Widget> status;

  /// One button, e.g. [SsRowAction].
  final Widget? action;

  final VoidCallback? onTap;

  /// Draws a green border, for the record now in use.
  final bool selected;

  /// Below this width per unit of text size, the action moves under the text.
  static const _minTextWidth = 220.0;

  @override
  Widget build(BuildContext context) {
    final shown = details.where((d) => d.trim().isNotEmpty);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: AppTextSizes.bodyLarge,
            fontWeight: FontWeight.w600,
            height: 1.25,
            color: AppColors.textPrimary,
          ),
        ),
        for (final line in shown)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              line,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppTextSizes.caption,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: status,
            ),
          ),
      ],
    );

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(
          color: selected ? AppColors.success : AppColors.borderSoft,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.card),
          child: LayoutBuilder(
            builder: (context, box) {
              final action = this.action;
              if (action == null) return text;
              final scale = MediaQuery.textScalerOf(context).scale(1);
              if (box.maxWidth / scale < _minTextWidth) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    text,
                    const SizedBox(height: AppSpacing.sm),
                    action,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: text),
                  const SizedBox(width: AppSpacing.sm),
                  action,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The one button of an [SsListRow]: 40 dp tall, white text on [color].
class SsRowAction extends StatelessWidget {
  const SsRowAction({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final Color color;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Shows a small spinner in place of the icon.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      icon: busy
          ? const SizedBox.square(
              dimension: AppSizes.iconSmall,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon, size: AppSizes.iconSmall),
      label: Text(label),
    );
  }
}

/// A small coloured label for an [SsListRow] status line, e.g.
/// "Checked in at 10:30".
class SsStatusPill extends StatelessWidget {
  const SsStatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;

  /// Text colour; needs 4.5:1 contrast on [background].
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTextSizes.caption,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
