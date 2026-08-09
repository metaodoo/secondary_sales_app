# Android CI/CD → Firebase App Distribution

Automated build + distribution for the Secondary Sales Android app, plus the
in-app "new version available" prompt.

```
Developer pushes to main
        ↓
GitHub Actions (.github/workflows/android-release.yml)
        ↓
flutter build apk --release --build-number=<run_number>   ← signed with upload key
        ↓
firebase appdistribution:distribute → tester group
        ↓
Employee opens the app
        ↓
AppUpdateService.checkForUpdate()  → isNewReleaseAvailable() compares versionCode
        ↓
"Update available" dialog → opens App Tester → Download → Install
```

The install deliberately happens in App Tester's process rather than this app's.
See §2.3.

Android only. iOS is not wired up (there is no `ios/Runner/GoogleService-Info.plist`
in this repo, so Firebase is not initialised on iOS).

---

## 1. What was changed

| File | Purpose |
| --- | --- |
| [`.github/workflows/android-release.yml`](../.github/workflows/android-release.yml) | Builds and distributes on every push to `main` |
| [`android/app/build.gradle.kts`](../android/app/build.gradle.kts) | Release signing config + App Distribution flavor strategy |
| [`lib/core/services/app_update_service.dart`](../lib/core/services/app_update_service.dart) | Wraps the App Distribution SDK |
| [`lib/main.dart`](../lib/main.dart) | Fires the update check after the first frame |
| [`android/app/src/main/kotlin/.../MainActivity.kt`](../android/app/src/main/kotlin/com/example/secondary_sales/MainActivity.kt) | `openAppTester` method channel |
| [`android/app/src/main/AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml) | `<queries>` entries so App Tester is visible to launch |
| `pubspec.yaml` | Added `firebase_app_distribution: ^1.2.0` |
| `android/key.properties` *(untracked)* | Local signing credentials |
| `android/app/upload-keystore.jks` *(untracked)* | The release signing key |

---

## 2. Two non-obvious details that make or break this

### 2.1 `missingDimensionStrategy` — otherwise the update check is a silent no-op

The `firebase_app_distribution` plugin ships **two** Firebase artifacts:

```gradle
implementation("com.google.firebase:firebase-appdistribution-api:16.0.0-beta14")   // no-op stub
stagingImplementation("com.google.firebase:firebase-appdistribution:16.0.0-beta14") // real thing
```

The real implementation sits behind a product flavor named `staging`. This app
declares no flavors, so without an explicit strategy Gradle resolves the
**API-only stub** and `updateIfNewReleaseAvailable()` does nothing at all — no
error, no dialog. Hence, in `defaultConfig`:

```kotlin
missingDimensionStrategy("default", "staging")
```

To verify it survived a dependency bump, check the built APK contains the
implementation classes:

```bash
unzip -p build/app/outputs/flutter-apk/app-release.apk classes.dex \
  | strings -a | grep -c "com/google/firebase/appdistribution/impl/"
```

A non-zero count means the full SDK is bundled. Zero means you shipped the stub.

> ⚠️ **Google Play policy:** the full SDK contains self-update code that Play
> treats as a policy violation. This is fine while the app is distributed only
> through App Distribution. If it is ever published to Play, change the strategy
> to `"production"` for that build.

### 2.2 Consistent release signing — otherwise updates cannot install

The release build previously used the **debug** keystore. CI generates a fresh
debug key on every runner, so each build would carry a different signature and
Android would refuse to install it over the previous one. The build now signs
with a dedicated, stable upload key.

`android/app/build.gradle.kts` reads `android/key.properties` when present and
falls back to debug signing when it is absent, so a fresh clone can still run
`flutter run --release` without any secrets.

### 2.3 Why `updateIfNewReleaseAvailable()` is not used

That is the SDK's one-call "check, prompt, download, install" helper, and it is
the obvious thing to reach for. It was used originally and had to be removed:
on a test device it downloaded the APK and then **crashed the app** at the
install hand-off, leaving the tester in a loop — relaunch, prompt, download,
crash, repeat — with no way into the app.

The crash cannot be handled from Dart. The plugin's Android side fires the
native call and returns success immediately without attaching a listener to the
returned `UpdateTask`:

```kotlin
"updateIfNewReleaseAvailable" -> {
    firebaseAppDistribution.updateIfNewReleaseAvailable()
    result.success(null)   // fires and forgets
}
```

So download progress and every `FirebaseAppDistributionException` are discarded
before they can reach Dart — and a hard crash would bypass a listener anyway.
Note the contrast with `isNewReleaseAvailable`, which *does* wire up success and
failure listeners; that is why detection is reliable and only the update flow
was blind.

Only the detection half is therefore used. The install is delegated to the App
Tester app via the `openAppTester` method channel, which downloads in its own
process — where a failure cannot take this app down with it.

**Do not "fix" this by restoring the one-call helper.** If the underlying crash
is ever diagnosed (see §7), the current design is still the safer one.

Two supporting details:

- `MainActivity` tries several applicationIds for App Tester, since it has
  shipped under more than one. Any id it tries must also appear in the
  manifest's `<queries>` block — since Android 11, `getLaunchIntentForPackage()`
  returns null for undeclared packages even when the app is installed, which
  would silently degrade to the browser fallback.
- `AppUpdateService.testerInviteUrl` is a **fallback only**, for a device with no
  App Tester installed. It is an *enrolment* page: it registers the visitor as a
  tester and shows "You're in", which is useless to someone who already is one.
  It must never be the primary route to a build.

---

## 3. One-time setup

### 3.1 GitHub Secrets

`Settings → Secrets and variables → Actions → New repository secret`

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | base64 of `android/app/upload-keystore.jks` (below) |
| `ANDROID_KEYSTORE_PASSWORD` | store password from `android/key.properties` |
| `ANDROID_KEY_PASSWORD` | key password (same value) |
| `ANDROID_KEY_ALIAS` | `upload` |
| `FIREBASE_ANDROID_APP_ID` | `1:72502010427:android:69ef0109111ea515bfb21e` |
| `FIREBASE_SERVICE_ACCOUNT` | full JSON of a service account key (§3.2) |

Produce the keystore blob with:

```bash
base64 -w0 android/app/upload-keystore.jks
```

Read the passwords out of `android/key.properties` — that file is gitignored and
exists only on the machine where the key was generated.

Notes that save a debugging session later:

- Secret **names are case-sensitive** and must match the workflow exactly. A
  typo'd name is not an error at save time — the workflow simply reads an empty
  value and fails mid-run.
- Use **Repository secrets**, not *Environment* secrets. Environment secrets only
  resolve for a job that declares an `environment:` key, which this workflow does
  not.
- `ANDROID_KEYSTORE_BASE64` is a single unbroken line (~3,660 chars). Editors
  soft-wrap it; that is cosmetic, but select it with `Home` then `Shift+End`
  rather than dragging across the wrapped display, which can introduce real
  newlines. A corrupted blob fails at `base64 -d` in the *Restore release
  keystore* step.

### 3.2 Firebase service account

Use a **dedicated** service account, not the auto-created `firebase-adminsdk`
one. The Admin SDK account carries broad project access (Realtime Database, Auth,
Firestore); this key lives in CI, so it should only be able to publish builds.
It also isn't guaranteed to hold App Distribution permissions, so reusing it
saves no steps.

1. [Google Cloud Console → Service Accounts](https://console.cloud.google.com/iam-admin/serviceaccounts?project=secondary-sales-6ec10)
2. **+ Create service account** → name `github-app-distribution` →
   **Create and continue**.
3. Role: **Firebase App Distribution Admin** → **Continue**.
4. Step 3 ("Principals with access") is for letting *other humans* impersonate
   the account. Leave both fields blank → **Done**.
5. **Verify the role actually landed.** The step-2 checkmark only means you
   passed through the step, not that a role was chosen. Open **IAM** in the
   sidebar and confirm `github-app-distribution@secondary-sales-6ec10.iam.gserviceaccount.com`
   lists **Firebase App Distribution Admin**. If the account is absent from the
   IAM page entirely, no project role was granted — fix with **Grant access**
   before going further. A missing role surfaces much later as a 403 /
   `Request had insufficient authentication scopes` at the upload step.
6. Creating the account does **not** create a key — a fresh account correctly
   shows "No keys". Click the account's email → **Keys** → **Add key** →
   **Create new key** → **JSON** → **Create**.
7. Paste the entire downloaded file — `{` through `}`, nothing trimmed or
   reformatted — into the `FIREBASE_SERVICE_ACCOUNT` secret, then delete the
   download (see §4).

If key creation is refused by policy, the `iam.disableServiceAccountKeyCreation`
organization policy is blocking it.

### 3.3 Tester group

In [App Distribution → Testers & Groups](https://console.firebase.google.com/project/secondary-sales-6ec10/appdistribution),
create a group whose **alias** is `testers` (the workflow default), and add
employee Google accounts to it.

To use a different alias, either edit the `default:` in the workflow or trigger
a manual run and pass the alias.

### 3.4 Register the new signing certificate (recommended)

Add these to the Android app in
[Firebase project settings](https://console.firebase.google.com/project/secondary-sales-6ec10/settings/general):

```
SHA-1:   45:1B:30:96:4D:8E:E6:5B:2A:24:C9:1A:73:57:5D:38:F6:36:73:E9
SHA-256: F2:7D:31:23:DD:C8:47:F5:6C:8A:63:D0:D2:5C:CC:10:75:D4:B3:2D:86:12:F8:7F:26:8B:9E:46:72:B6:98:FA
```

FCM and App Distribution do not require this, but registering it now avoids a
confusing failure the day Google Sign-In or any certificate-bound Firebase
feature is added.

---

## 4. 🔴 Back up the keystore

`android/app/upload-keystore.jks` is **gitignored and exists in exactly one
place**. If it is lost, no future build can ever update an installed app —
every tester must uninstall and reinstall from scratch.

Store a copy in the team password manager, together with its passwords, before
doing anything else.

The service-account JSON needs the **opposite** treatment — delete your local
copy once it is in the `FIREBASE_SERVICE_ACCOUNT` secret:

```bash
rm ~/Downloads/secondary-sales-6ec10-*.json
```

Google keeps only the public half of that key pair, so there is no re-download.
That sounds like a reason to hoard it; it isn't. A leftover copy in `~/Downloads`
is just a loose credential, and replacing a lost or exposed key takes about
thirty seconds: Service Accounts → `github-app-distribution` → **Keys** → delete
the old key (revokes it immediately) → **Add key → Create new key → JSON** →
update the secret. No rebuild needed; the next run picks it up.

Rotate on any suspected exposure — a key pasted into a chat window, a terminal,
a screenshot, or a shared log. Unlike the keystore, this costs you nothing.

---

## 5. Tester onboarding

For each employee, once per device:

1. Firebase emails an invitation → **Get started**.
2. Sign in with the invited Google account and install **Firebase App Tester**.
3. Install the current build from App Tester.
4. On first launch the app shows a Google sign-in prompt from the App
   Distribution SDK. Accepting it is what enables the in-app update dialog; it
   is a one-time consent that persists across updates.
5. Android will ask permission to install unknown apps — required for the
   in-app update to install itself.

> **Existing installs must be uninstalled once.** Anything installed before this
> change was signed with the debug key. Android will not install an
> upload-key-signed APK over it (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). This is a
> one-time cut-over; every update after it installs cleanly.

---

## 6. Day-to-day use

**Ship a build:** push to `main`. That's the whole loop.

**Ship on demand:** `Actions → Android → Firebase App Distribution → Run workflow`,
optionally overriding the tester group.

**Bump the user-visible version:** edit `version:` in `pubspec.yaml`
(e.g. `1.1.0+1`). CI overrides only the build number, never the version name, so
`1.1.0` sticks while the build number keeps climbing.

**Version numbering:** `versionCode` comes from `github.run_number`, which is
monotonic per workflow. App Distribution offers an update only when the new
`versionCode` exceeds the installed one — so never reset the run counter.

---

## 7. Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| No update dialog in the app | Debug build — the check is `kReleaseMode`-only by design. Test with a release APK. |
| No dialog in a release build | Stub SDK bundled; re-check `missingDimensionStrategy` with the `grep` in §2.1. |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Old debug-signed install still present. Uninstall once (§5). |
| Workflow fails on the keystore step | `ANDROID_KEYSTORE_BASE64` unset or truncated. Re-generate with `base64 -w0`. |
| `Request had insufficient authentication scopes` | Service account lacks **Firebase App Distribution Admin**. |
| Testers get email but no in-app prompt | They never completed the SDK's Google sign-in (§5 step 4). |
| Dialog appears but install silently fails | "Install unknown apps" denied — grant it for **App Tester**, which is the installer here, not for this app. If the toggle is greyed out on Android 13+, tap ⋮ → *Allow restricted settings* first. |
| App downloads the update then crashes, every launch | The old `updateIfNewReleaseAvailable()` path. Fixed by §2.3 — but the fix only takes effect once a build **containing** it is installed, and the broken installer is what would install it. Break the loop with one manual APK install (§6). |
| **Update** opens a browser showing "You're in!" | App Tester is not installed, so the invite-link fallback ran. Install App Tester. If it *is* installed, the `<queries>` entries are missing or its applicationId changed — see §2.3. |
| Tester gets no email | They are in **All testers** but not in the `testers` group. Only group members receive a distribution. The two lists are different things. |
| Re-running a workflow produces no update | A re-run reuses `github.run_number`, so `versionCode` is unchanged and nothing outranks the installed build. Start a **new** run instead. |
| `invalid source release: 21` in CI | `maplibre_gl` pins `sourceCompatibility` to 21. CI must provision JDK 21; local builds hide this because Android Studio's bundled JBR is already 21. |

### Local release build

```bash
flutter build apk --release --build-number=999 --target-platform android-arm64
```

Match CI's flags, or the local APK differs from what testers receive. Pick a
`--build-number` above the newest CI run or the result will not be treated as an
update.

Requires `android/key.properties` + the keystore. Without them the build still
succeeds using debug signing, but the result is **not** distributable as an update.

---

## 8. Known trade-offs

- **APK is `arm64-v8a` only, ~51 MB** (down from ~87 MB universal). Builds one
  ABI instead of three, which also skips two of three AOT compilations.
  32-bit-only devices and x86_64 emulators cannot install it; add `,android-arm`
  to the `--target-platform` flag if a rep turns up with a 32-bit phone.
- **No Gradle caching in CI**, so every run re-downloads Android dependencies and
  spends 5–9 minutes in `assembleRelease`. Adding `cache: gradle` to the
  `setup-java` step would cut steady-state runs to roughly 4–6 minutes.
- **`applicationId` is still `com.example.secondary_sales`.** A placeholder from
  `flutter create`. Changing it now would invalidate `google-services.json`, break
  FCM tokens, and orphan every install — so it was deliberately left alone. If it
  is ever changed, it must be done as a coordinated re-onboarding.
- **App Distribution SDK is beta** (`16.0.0-beta14`) and may introduce breaking
  changes.
- **The plugin is community-maintained** (`thomaspucci.com`), not official
  FlutterFire. It is a thin wrapper over Google's own SDK, so the risk is
  concentrated in the wrapper rather than the update logic.

---

## 9. Reverting this integration

The whole feature lives in commits `b7a66b8..1effed1`, on top of `a02a68a`.
Nothing unrelated is mixed into that range, so today it comes out in one step:

```bash
git revert --no-commit a02a68a..HEAD
git commit -m "revert: remove Firebase App Distribution CI/CD"
```

That stops being true as soon as other work lands on `main`. After that, revert
per file using the table below.

### What each change does

| Path | Purpose | Safe to remove alone? |
| --- | --- | --- |
| `.github/workflows/android-release.yml` | Builds and uploads every `main` push | Yes — deleting it stops all automation and changes nothing in the app |
| `lib/core/services/app_update_service.dart` | In-app update detection and prompt | Yes, with the `main.dart` call site |
| `lib/main.dart` (`initState` post-frame call) | Invokes the check at startup | Yes |
| `pubspec.yaml` / `pubspec.lock` (`firebase_app_distribution`) | The SDK | Only after the service is gone |
| `android/app/src/main/kotlin/.../MainActivity.kt` | `openAppTester` method channel | Yes, with the service |
| `android/app/src/main/AndroidManifest.xml` (`<queries>` packages) | Package visibility for App Tester | Yes — harmless if left |
| `android/app/build.gradle.kts` (`missingDimensionStrategy`) | Selects the SDK's real implementation over its no-op stub | Only with the SDK; removing it while the SDK stays makes every check silently return "no update" |
| `android/app/build.gradle.kts` (signing config) | 🔴 Release signing | **See the warning below** |
| `docs/APP_DISTRIBUTION_CI.md` | This document | Yes |

### 🔴 The signing change is not cleanly revertible

Reverting `build.gradle.kts` returns release builds to debug signing. Android
refuses to replace an app with one signed by a different key, so **every device
running a CI-signed build must uninstall before it can install anything else** —
losing its local data and login. That cost scales with however many reps are
onboarded when the revert happens.

If the goal is only to stop the automation, delete the workflow and leave the
signing config alone. Consistent release signing is worth keeping regardless of
how builds get distributed.

### State outside the repository

None of this is touched by `git revert`, and all of it is safe to leave in place
— it costs nothing while dormant:

- **GitHub** → Settings → Secrets: the six `ANDROID_*` / `FIREBASE_*` secrets
- **Google Cloud** → the `github-app-distribution` service account and its key
- **Firebase** → App Distribution: the `testers` group, the invite link, the
  uploaded releases
- **Locally** → `android/key.properties` and `android/app/upload-keystore.jks`,
  both gitignored. Keep the keystore backed up even if this feature is removed;
  it is unrecoverable and any future release signing needs it.
