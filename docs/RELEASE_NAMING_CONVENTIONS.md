# Shokti+ Mobile Application — Release Version & Artifact Naming Conventions

This document establishes the official versioning rules, artifact naming conventions, build commands, and distribution workflows for the **Shokti+** Secondary Sales & SFA Android application.

---

## 1. Core Versioning Scheme (`pubspec.yaml`)

Every release follows [Semantic Versioning 2.0.0](https://semver.org/) paired with a monotonic Android `versionCode`:

```yaml
version: <MAJOR>.<MINOR>.<PATCH>+<BUILD_NUMBER>
```

Example: `version: 1.0.0+2006`

| Segment | Format | Description | When to Increment |
| :--- | :--- | :--- | :--- |
| **`MAJOR`** | Non-negative integer | Major application rewrite or incompatible architectural overhaul. | Breaking DB schema changes, full UI rewrites. |
| **`MINOR`** | Non-negative integer | Substantial new operational features or module rollouts. | New role workflows (e.g. Van Audit, New Settlement). |
| **`PATCH`** | Non-negative integer | Backwards-compatible bug fixes, hotfixes, and UI polish. | Bug fixes, typo corrections, minor layout adjustments. |
| **`BUILD_NUMBER`** | Monotonic integer | Android `versionCode` governing update precedence on devices. | **Every build / CI run**. Monotonically increasing. |

> [!IMPORTANT]
> **Android Update Requirement**: Android package installer and Firebase App Distribution require the new APK's `versionCode` (`BUILD_NUMBER`) to be strictly **greater** than the installed version. Never decrement or reuse a `versionCode` for field distribution.

---

## 2. Release APK Artifact Naming Conventions

When Gradle compiles a release build, it automatically produces files according to the standardized naming structure.

### 2.1 File Naming Matrix

| Target Architecture / Variant | Standard Release Filename | Web / URL / ASCII Safe Filename | Clean Root Shortcut |
| :--- | :--- | :--- | :--- |
| **Universal (All ARM devices)** | `Shokti+_v<VERSION>_Universal.apk` | `Shokti_Plus_v<VERSION>_Universal.apk` | `Shokti+_Universal.apk` |
| **64-bit ARM (`arm64-v8a`)** | `Shokti+_v<VERSION>_arm64-v8a.apk` | `Shokti_Plus_v<VERSION>_arm64-v8a.apk` | `Shokti+_64bit.apk` |
| **32-bit ARM (`armeabi-v7a`)** | `Shokti+_v<VERSION>_armeabi-v7a.apk` | `Shokti_Plus_v<VERSION>_armeabi-v7a.apk` | `Shokti+_32bit.apk` |
| **Dual ARM (`armeabi-v7a` + `arm64-v8a`)** | `Shokti+_v<VERSION>_ARM.apk` | `Shokti_Plus_v<VERSION>_ARM.apk` | `Shokti+_ARM.apk` |

*For `v1.0.0` with build `2006`, standard artifacts produced are:*
- `output/apk/Shokti+_v1.0.0_Universal.apk` (~103 MB - Recommended for field devices; guaranteed compatibility across all phones)
- `output/apk/Shokti+_v1.0.0_arm64-v8a.apk` (~38 MB - Optimized size for modern 64-bit devices)
- `output/apk/Shokti+_v1.0.0_armeabi-v7a.apk` (~33 MB - Legacy support for 32-bit Android phones)

Legacy compatibility symlinks/aliases (`GDFL_64bit.apk`, `GDFL_32bit.apk`) are preserved to prevent breaking legacy build scripts.

---

## 3. Local Build Commands

Run all build commands from the repository root:

### 3.1 Universal APK (Recommended for general field distribution)
```bash
flutter build apk --release --build-name=1.0.0 --build-number=2006
```
*Builds a single APK compatible with all Android devices and automatically copies it to `output/apk/Shokti+_v1.0.0_Universal.apk` and `Shokti+_Universal.apk`.*

### 3.2 Split-per-ABI (Optimized APK sizes)
```bash
flutter build apk --release --split-per-abi --build-name=1.0.0 --build-number=2006
```
*Builds independent 64-bit and 32-bit APKs (~35 MB each) and copies them to `output/apk/Shokti+_v1.0.0_arm64-v8a.apk` and `Shokti+_v1.0.0_armeabi-v7a.apk`.*

---

## 4. GitHub Actions CI/CD & GitHub Releases

The `production` branch is wired to `.github/workflows/production-release.yml`:

```
Git push to production (or manual workflow_dispatch)
        ↓
GitHub Actions: Production Release Build
        ↓
1. Build Universal APK & Split ABIs (signed with upload keystore)
2. Enforce artifact naming convention
        ↓
3. Upload to GitHub Actions Artifacts (Downloadable from Actions run)
4. Publish GitHub Release with direct APK download links
5. (Optional) Distribute to Firebase App Distribution tester groups
```

### Direct Download from GitHub Repository
1. Navigate to `https://github.com/metaodoo/secondary_sales_app/releases`
2. Select the latest release (e.g. `Shokti+ v1.0.0`)
3. Under **Assets**, click to download:
   - **`Shokti+_v1.0.0_Universal.apk`** (Works on 100% of Android phones)
   - **`Shokti+_v1.0.0_arm64-v8a.apk`** (Smaller download for modern phones)
