import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:geolocator/geolocator.dart';
import 'package:secondary_sales/features/settings/screens/settings_tab.dart';

String initialsFromName(String? rawName, {String fallback = 'U'}) {
  final trimmed = rawName?.trim() ?? '';
  if (trimmed.isEmpty) return fallback;

  final parts = trimmed
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return fallback;

  final firstInitial = parts.first[0];
  if (parts.length > 1) {
    final secondInitial = parts[1][0];
    return '$firstInitial$secondInitial'.toUpperCase();
  }
  return firstInitial.toUpperCase();
}

String firstNameFromName(String? rawName, {String fallback = 'User'}) {
  final trimmed = rawName?.trim() ?? '';
  if (trimmed.isEmpty) return fallback;

  final parts = trimmed
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return fallback;
  return parts.first;
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.onTap, this.borderColor});

  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final userName = user?.employeeName ?? user?.name ?? 'User';
    final initials = initialsFromName(userName);

    return GestureDetector(
      onTap:
          onTap ??
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SettingsTab(onBack: () => Navigator.pop(context)),
              ),
            );
          },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryTint,
          border: Border.all(
            color: borderColor ?? AppColors.primaryTint,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            initials,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class BlueHeader extends StatelessWidget {
  const BlueHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final routeCanPop = ModalRoute.of(context)?.canPop ?? false;
    final effectiveLeading =
        leading ??
        (routeCanPop
            ? IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              )
            : null);

    return Container(
      color: AppColors.primaryStrong,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.section,
        AppSpacing.section,
        AppSpacing.section,
        18,
      ),
      child: Row(
        children: [
          if (effectiveLeading != null) ...<Widget>[
            effectiveLeading,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          trailing ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            color: AppColors.textSecondary,
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// The single "create a new record" action used across every list screen.
///
/// Matches the expense dashboard's `FloatingActionButton.extended`, which is
/// the reference for this control. Screens previously hand-rolled inline
/// `ElevatedButton.icon`s that drifted in radius, weight, and in one case used
/// a hard-coded green instead of the brand colour.
///
/// Pass to `Scaffold.floatingActionButton`. Screens with a scrolling list need
/// [kSsFabScrollPadding] at the bottom of that list so the final row is not
/// covered by the floating button.
class SsCreateFab extends StatelessWidget {
  const SsCreateFab({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add,
    this.heroTag,
  });

  final String label;

  /// Null disables the action (e.g. while a list is still loading).
  final VoidCallback? onPressed;
  final IconData icon;

  /// Required when a screen shows more than one FAB — Flutter throws on
  /// duplicate default hero tags within a single route.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      heroTag: heroTag,
      backgroundColor: onPressed == null
          ? AppColors.primary.withValues(alpha: 0.45)
          : AppColors.primary,
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Bottom padding for a scrolling list on a screen that shows an [SsCreateFab],
/// so the last row clears the floating button.
const double kSsFabScrollPadding = 88;

class ErrorPanel extends StatelessWidget {
  const ErrorPanel(this.message, {super.key});

  final String message;

  /// Providers store `e.toString()` and the API layer throws `Exception(msg)`,
  /// so a perfectly readable backend sentence reaches the UI prefixed with
  /// "Exception: ". Strip it here rather than in every call site.
  String get _display =>
      message.replaceFirst(RegExp(r'^_?Exception:\s*'), '').trim();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Text(_display, style: TextStyle(color: Colors.red.shade800)),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.message = 'Loading...',
    this.padding = const EdgeInsets.all(32),
  });

  final String message;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          const Center(child: CircularProgressIndicator()),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

Future<void> ssShowQtyInputDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  required ValueChanged<String> onConfirm,
  bool isDecimal = false,
}) async {
  final controller = TextEditingController(text: initialValue);
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.length,
  );

  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter quantity',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryStrong,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Confirm'),
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                onConfirm(val);
              }
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

class SmallStepper extends StatefulWidget {
  const SmallStepper({
    super.key,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.onValueInput,
    this.isDecimal = true,
  });

  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String>? onValueInput;
  final bool isDecimal;

  @override
  State<SmallStepper> createState() => _SmallStepperState();
}

class _SmallStepperState extends State<SmallStepper> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    } else {
      _commitValue();
    }
  }

  @override
  void didUpdateWidget(SmallStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commitValue() {
    final val = _controller.text.trim();
    if (val.isNotEmpty && val != widget.value) {
      widget.onValueInput?.call(val);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onValueInput != null;
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: widget.onMinus,
            icon: const Icon(Icons.remove, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 75,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: enabled,
              keyboardType: TextInputType.numberWithOptions(
                decimal: widget.isDecimal,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (val) {
                if (val.isNotEmpty && val != widget.value) {
                  widget.onValueInput?.call(val);
                }
              },
              onSubmitted: (_) {
                _commitValue();
                _focusNode.unfocus();
              },
            ),
          ),
          IconButton(
            onPressed: widget.onPlus,
            icon: const Icon(Icons.add, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class SSQtyField extends StatefulWidget {
  const SSQtyField({
    super.key,
    required this.value,
    required this.onChanged,
    this.isDecimal = false,
    this.width = 72,
    this.height = 34,
    this.enabled = true,
    this.style,
    this.decoration,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool isDecimal;
  final double width;
  final double height;
  final bool enabled;
  final TextStyle? style;
  final InputDecoration? decoration;

  @override
  State<SSQtyField> createState() => _SSQtyFieldState();
}

class _SSQtyFieldState extends State<SSQtyField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    } else {
      _commitValue();
    }
  }

  @override
  void didUpdateWidget(SSQtyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commitValue() {
    final val = _controller.text.trim();
    if (val != widget.value) {
      widget.onChanged(val);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        keyboardType: TextInputType.numberWithOptions(
          decimal: widget.isDecimal,
        ),
        textAlign: TextAlign.center,
        style: widget.style ?? const TextStyle(fontSize: 14),
        decoration: widget.decoration ??
            const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFDDE6F2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFDDE6F2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
        onTap: () {
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        },
        onChanged: (val) {
          widget.onChanged(val);
        },
        onSubmitted: (_) {
          _commitValue();
          _focusNode.unfocus();
        },
      ),
    );
  }
}

InputDecoration ssInputDecoration(String hint, IconData icon) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: hint.isEmpty
        ? null
        : Icon(icon, color: AppColors.textSecondary),
    suffixIcon: hint.isEmpty ? Icon(icon, color: AppColors.borderSoft) : null,
    filled: true,
    fillColor: AppColors.surfaceTint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.medium),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.medium),
      borderSide: const BorderSide(color: AppColors.border),
    ),
  );
}

BoxDecoration ssPanelDecoration() {
  return BoxDecoration(
    color: AppColors.surface,
    border: Border.all(color: AppColors.border),
    borderRadius: BorderRadius.circular(AppRadii.large),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

String ssFormatDate(DateTime date) {
  return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
}

String ssFormatDateTime(DateTime? dt) {
  if (dt == null) return '-';
  final local = dt.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final month = months[local.month - 1];
  final year = local.year;
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$day $month $year, $hour12:$minute $period';
}

void ssShowLocationErrorDialog(BuildContext context, String message) {
  final bool isGpsDisabled =
      message.toLowerCase().contains('disabled') ||
      message.toLowerCase().contains('enable gps');

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFEE2E2), width: 2),
                ),
                child: const Icon(
                  Icons.location_off,
                  color: Color(0xFFEF4444),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Location Mismatch',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  if (isGpsDisabled) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            await Geolocator.openLocationSettings();
                          } catch (_) {}
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryStrong,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Open Settings',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryStrong,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Got It',
                          style: TextStyle(fontWeight: FontWeight.bold),
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
    },
  );
}
