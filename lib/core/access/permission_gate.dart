import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/features/auth/auth_provider.dart';

/// Wraps a button or section so it is only shown (or enabled) when the current
/// user's group is allowed to use the given [resourceKey].
///
/// Use with keys from `AppScreen` / `AppAction`:
/// ```dart
/// PermissionGate(
///   resourceKey: AppAction.transferValidate,
///   child: ValidateButton(...),
/// )
/// ```
///
/// Phase 0 note: until the backend ships grants, `AccessControl` is empty, so
/// `allows()` returns true and the [child] always renders — no behavior change.
class PermissionGate extends StatelessWidget {
  const PermissionGate({
    super.key,
    required this.resourceKey,
    required this.child,
    this.fallback,
    this.disableInsteadOfHide = false,
  });

  /// A key from `AppScreen` or `AppAction`.
  final String resourceKey;

  /// Rendered when access is allowed.
  final Widget child;

  /// Rendered when access is denied and [disableInsteadOfHide] is false.
  /// Defaults to an empty box (hidden).
  final Widget? fallback;

  /// When true, a denied [child] is shown greyed-out and non-interactive
  /// instead of being removed from the tree.
  final bool disableInsteadOfHide;

  @override
  Widget build(BuildContext context) {
    final allowed = context.select<AuthProvider, bool>(
      (auth) => auth.access.allows(resourceKey),
    );

    if (allowed) return child;

    if (disableInsteadOfHide) {
      return IgnorePointer(
        child: Opacity(opacity: 0.4, child: child),
      );
    }

    return fallback ?? const SizedBox.shrink();
  }
}
