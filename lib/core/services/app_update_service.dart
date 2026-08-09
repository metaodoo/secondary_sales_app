import 'dart:io' show Platform;

import 'package:firebase_app_distribution/firebase_app_distribution.dart'
    as app_distribution;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Prompts testers to install a newer build published to Firebase App
/// Distribution.
///
/// CI uploads every `main` build to App Distribution (see
/// `.github/workflows/android-release.yml`), and the Firebase SDK compares the
/// running build's `versionCode` against the latest release for this app. When a
/// newer one exists it shows Firebase's own update dialog, then downloads and
/// installs the APK.
///
/// This duplicates, on purpose, what the Firebase App Tester app already does
/// out of band: App Tester notifies testers by email and its own push. Field
/// reps routinely ignore both, so the check is repeated inside the app where
/// they cannot miss it.
///
/// Two constraints are baked in deliberately:
///
///  * **Android only.** iOS has no `GoogleService-Info.plist` in this repo, so
///    Firebase is not initialised there and the call would throw.
///  * **Release builds only.** Debug builds are signed with the debug key and
///    are never uploaded, so they can never match a release. Running the check
///    in debug would only pop a Google sign-in prompt at every hot restart.
class AppUpdateService {
  AppUpdateService._();

  /// Shows the diagnostic report on screen after every check.
  ///
  /// TEMPORARY, for diagnosing an update that downloads but never installs.
  /// USB debugging is unavailable on the affected device, so the report has to
  /// surface in the UI rather than in `logcat`.
  ///
  /// Note what it means if this dialog appears at all: a successful install
  /// replaces the APK and Android kills the running process, so the report can
  /// only ever be seen when the update did *not* complete.
  ///
  /// Set to `false` to restore silent operation.
  static const bool showDiagnosticsOnScreen = true;

  /// Guards against a second prompt when the widget tree rebuilds or the app is
  /// resumed. The SDK is cheap to call but the sign-in sheet is modal, and
  /// showing it twice in one session is jarring.
  static bool _checkedThisSession = false;

  static final List<String> _log = <String>[];

  /// Lines recorded by the most recent [checkForUpdate], oldest first.
  static List<String> get diagnostics => List.unmodifiable(_log);

  static bool get _isSupported => !kIsWeb && Platform.isAndroid;

  static void _record(String line) {
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    _log.add('[$stamp] $line');
    debugPrint('AppUpdateService: $line');
  }

  /// Checks App Distribution for a newer build and, if there is one, shows the
  /// update dialog. Safe to call from app startup: it never throws and never
  /// blocks the first frame.
  ///
  /// The first call on a device also asks the employee to sign in with the
  /// Google account they were invited as a tester with. That is a one-time
  /// consent per device and persists across updates.
  ///
  /// Pass [force] to bypass the once-per-session guard, e.g. from a manual
  /// "Check for updates" action. Pass [navigatorKey] to let the diagnostic
  /// report find a context; without it the report is still collected into
  /// [diagnostics] but cannot be displayed.
  static Future<void> checkForUpdate({
    bool force = false,
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    if (!_isSupported) return;
    if (!kReleaseMode) return;
    if (_checkedThisSession && !force) return;
    _checkedThisSession = true;

    _log.clear();

    // Each stage is recorded separately and guarded on its own, so one failing
    // call still leaves the earlier answers visible in the report. Knowing the
    // installed versionCode is the whole point: if it already matches the
    // newest release, the loop is a stale-comparison problem, and if it lags,
    // the install itself is being rejected.
    try {
      final info = await PackageInfo.fromPlatform();
      _record('installed: ${info.version} (${info.buildNumber})');
      _record('package: ${info.packageName}');
    } catch (e) {
      _record('package info failed: $e');
    }

    try {
      _record('tester signed in: ${await app_distribution.isTesterSignedIn()}');
    } catch (e) {
      _record('isTesterSignedIn failed: $e');
    }

    try {
      _record(
        'new release available: ${await app_distribution.isNewReleaseAvailable()}',
      );
    } catch (e) {
      _record('isNewReleaseAvailable failed: $e');
    }

    try {
      await app_distribution.updateIfNewReleaseAvailable();
      // Reaching this line means the SDK finished without installing anything:
      // either there was no newer release, the tester dismissed the dialog, or
      // the download/install was abandoned without raising an error.
      _record('updateIfNewReleaseAvailable: returned without installing');
    } catch (e) {
      // A tester who declines sign-in, an unreachable Firebase, or a device
      // that blocks unknown-source installs must never stop the app from
      // opening. The next launch retries.
      _record('updateIfNewReleaseAvailable threw: $e');
    }

    if (showDiagnosticsOnScreen) {
      _showReport(navigatorKey);
    }
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

  /// Renders [diagnostics] in a dismissible dialog with a copy button.
  ///
  /// Dismissible on purpose: a rep who cannot install the update must still be
  /// able to reach the app and do their day's work.
  static void _showReport(GlobalKey<NavigatorState>? navigatorKey) {
    final context = navigatorKey?.currentContext;
    if (context == null) return;

    final report = _log.join('\n');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Update diagnostics'),
          content: SingleChildScrollView(
            child: SelectableText(
              report,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: report));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    });
  }
}
