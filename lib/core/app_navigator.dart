import 'package:flutter/material.dart';

/// The app's root navigator.
///
/// Lives in `core` rather than `main.dart` so non-UI layers (auth, push
/// notifications, update prompts) can drive navigation without importing the
/// entrypoint.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Drops every pushed route so the root (the `AuthGate`) is what the user sees.
///
/// `AuthGate` is the `MaterialApp.home`, which means routes pushed above it
/// survive a session change: a session lost mid-shift used to leave the rep
/// staring at a form that still looked signed in, rendering placeholder names
/// and failing every request.
void resetToRootRoute() {
  appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
}
