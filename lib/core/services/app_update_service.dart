import 'dart:io' show Platform;

import 'package:firebase_app_distribution/firebase_app_distribution.dart'
    as app_distribution;
import 'package:flutter/foundation.dart';

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

  /// Guards against a second prompt when the widget tree rebuilds or the app is
  /// resumed. The SDK is cheap to call but the sign-in sheet is modal, and
  /// showing it twice in one session is jarring.
  static bool _checkedThisSession = false;

  static bool get _isSupported => !kIsWeb && Platform.isAndroid;

  /// Checks App Distribution for a newer build and, if there is one, shows the
  /// update dialog. Safe to call from app startup: it never throws and never
  /// blocks the first frame.
  ///
  /// The first call on a device also asks the employee to sign in with the
  /// Google account they were invited as a tester with. That is a one-time
  /// consent per device and persists across updates.
  ///
  /// Pass [force] to bypass the once-per-session guard, e.g. from a manual
  /// "Check for updates" action.
  static Future<void> checkForUpdate({bool force = false}) async {
    if (!_isSupported || !kReleaseMode) return;
    if (_checkedThisSession && !force) return;
    _checkedThisSession = true;

    try {
      await app_distribution.updateIfNewReleaseAvailable();
    } catch (e) {
      // A tester who declines sign-in, an unreachable Firebase, or a device
      // that blocks unknown-source installs must never stop the app from
      // opening. The next launch retries.
      debugPrint('AppUpdateService: update check failed: $e');
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
}
