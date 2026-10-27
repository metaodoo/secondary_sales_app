import 'package:flutter/material.dart';

/// Keeps [child] above the on-screen keyboard, for bottom sheets.
///
/// The keyboard height changes on every frame while the keyboard slides in
/// or out. Reading it with MediaQuery.of(context) in a sheet's build makes
/// the whole sheet rebuild on each of those frames, which lags on entry-level
/// phones. Here only this small widget rebuilds; [child] is built once by
/// the caller.
class SsKeyboardInset extends StatelessWidget {
  const SsKeyboardInset({
    super.key,
    this.decoration,
    this.extra = 0,
    required this.child,
  });

  /// Painted behind the child and the keyboard space, e.g. the sheet's
  /// white background with rounded top corners.
  final Decoration? decoration;

  /// Space kept between the keyboard and [child].
  final double extra;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padded = Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + extra,
      ),
      child: child,
    );
    final decoration = this.decoration;
    return decoration == null
        ? padded
        : DecoratedBox(decoration: decoration, child: padded);
  }
}
