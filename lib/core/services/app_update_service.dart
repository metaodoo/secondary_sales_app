import 'dart:io' show Platform;

import 'package:firebase_app_distribution/firebase_app_distribution.dart'
    as app_distribution;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tells testers when a newer build is available on Firebase App Distribution
/// and sends them somewhere that can actually install it.
///
/// CI uploads every `main` build to App Distribution (see
/// `.github/workflows/android-release.yml`), tagging it with a `versionCode`
/// taken from the run number, so each build outranks the last.
///
/// ## Why this does not use `updateIfNewReleaseAvailable()`
///
/// That is the SDK's one-call "check, prompt, download, install" helper, and it
/// is what this service used originally. On at least one test device it
/// downloads the APK and then crashes the app at the install hand-off, leaving
/// the tester in a loop: relaunch, get prompted, download, crash, repeat.
///
/// The crash cannot be caught from Dart. The plugin's Android side fires the
/// native call and immediately returns success without attaching a listener to
/// the returned `UpdateTask`, so download progress and
/// `FirebaseAppDistributionException` failures are discarded before they can
/// reach us — and a hard crash would bypass a listener anyway.
///
/// So only the detection half of the SDK is used here. `isNewReleaseAvailable()`
/// is reliable: the plugin does wire up success and failure listeners for it.
/// The install is then delegated to the App Tester app, which downloads in its
/// own process — where a failure cannot take this app down with it, and where
/// installing an APK is its entire purpose.
class AppUpdateService {
  AppUpdateService._();

  /// Tester link from Firebase Console → App Distribution → **Invite links**.
  ///
  /// Opening it hands off to the App Tester app when installed, and falls back
  /// to the browser otherwise. Leave empty and the prompt still appears, just
  /// without a button — the tester is told to open App Tester themselves.
  static const String testerInviteUrl =
      'https://appdistribution.firebase.dev/i/ad96c9e8f7c36a5e';

  /// How long "Later" suppresses the prompt.
  ///
  /// The SDK only reports *whether* a newer release exists, not which one, so
  /// there is no version to key a dismissal against. A time-based snooze is the
  /// available approximation: long enough not to nag a rep mid-round, short
  /// enough that an urgent fix still reaches them the same day.
  static const Duration _snoozeDuration = Duration(hours: 12);

  static const String _snoozeKey = 'app_update_prompt_snoozed_until';

  /// Guards against a second prompt when the widget tree rebuilds or the app is
  /// resumed.
  static bool _checkedThisSession = false;

  static final List<String> _log = <String>[];

  /// Lines recorded by the most recent [checkForUpdate], oldest first. Exposed
  /// so a support screen can show why an update did or did not appear.
  static List<String> get diagnostics => List.unmodifiable(_log);

  static bool get _isSupported => !kIsWeb && Platform.isAndroid;

  static void _record(String line) {
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    _log.add('[$stamp] $line');
    debugPrint('AppUpdateService: $line');
  }

  /// Checks App Distribution for a newer build and, if there is one, offers to
  /// open App Tester. Safe to call from app startup: it never throws and never
  /// blocks the first frame.
  ///
  /// The first call on a device asks the employee to sign in with the Google
  /// account they were invited as a tester with — a one-time consent per device.
  ///
  /// Pass [force] to bypass both the once-per-session guard and an active
  /// snooze, e.g. from a manual "Check for updates" action.
  static Future<void> checkForUpdate({
    bool force = false,
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    if (!_isSupported) return;
    if (!kReleaseMode) return;
    if (_checkedThisSession && !force) return;
    _checkedThisSession = true;

    _log.clear();

    try {
      final info = await PackageInfo.fromPlatform();
      _record('installed: ${info.version} (${info.buildNumber})');
    } catch (e) {
      _record('package info failed: $e');
    }

    try {
      _record('tester signed in: ${await app_distribution.isTesterSignedIn()}');
    } catch (e) {
      _record('isTesterSignedIn failed: $e');
    }

    bool available = false;
    try {
      available = await app_distribution.isNewReleaseAvailable();
      _record('new release available: $available');
    } catch (e) {
      // Most often an unsigned-in tester or no network. Either way the app must
      // still open; the next launch retries.
      _record('isNewReleaseAvailable failed: $e');
      return;
    }

    if (!available) return;

    if (!force && await _isSnoozed()) {
      _record('prompt suppressed: snoozed');
      return;
    }

    _promptUpdate(navigatorKey);
  }

  /// Whether a newer build exists, without showing any UI.
  ///
  /// Useful for badging an "Update available" item in the drawer. Returns false
  /// on unsupported platforms, in debug, or when the tester is not signed in.
  static Future<bool> isUpdateAvailable() async {
    if (!_isSupported || !kReleaseMode) return false;
    try {
      return await app_distribution.isNewReleaseAvailable();
    } catch (e) {
      debugPrint('AppUpdateService: availability check failed: $e');
      return false;
    }
  }

  static Future<bool> _isSnoozed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final until = prefs.getInt(_snoozeKey);
      if (until == null) return false;
      return DateTime.now().millisecondsSinceEpoch < until;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _snooze() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _snoozeKey,
        DateTime.now().add(_snoozeDuration).millisecondsSinceEpoch,
      );
    } catch (_) {
      // A failed snooze only means the prompt returns next launch.
    }
  }

  /// Offers the update. Always dismissible: a rep who cannot install right now
  /// must still be able to work, which is exactly what the old modal loop took
  /// away from them.
  static void _promptUpdate(GlobalKey<NavigatorState>? navigatorKey) {
    final context = navigatorKey?.currentContext;
    if (context == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Update available'),
          content: Text(
            testerInviteUrl.isEmpty
                ? 'A newer version of Secondary Sales has been released.\n\n'
                      'Open the App Tester app to download and install it.'
                : 'A newer version of Secondary Sales has been released.\n\n'
                      'Tap Update to open App Tester and install it.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _snooze();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Later'),
            ),
            if (testerInviteUrl.isNotEmpty)
              FilledButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _openTesterApp();
                },
                child: const Text('Update'),
              ),
          ],
        ),
      );
    });
  }

  static Future<void> _openTesterApp() async {
    try {
      await launchUrl(
        Uri.parse(testerInviteUrl),
        // Must leave this app: the whole point is that the download and install
        // happen in App Tester's process, not ours.
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      _record('could not open tester app: $e');
    }
  }
}
