# Dynamic System Inset Protection for Bottom Virtual Navigation Bar

## Overview
When Android devices use a 3-button virtual navigation bar (Back, Home, Recents), the system bar overlays ~48-54dp at the bottom of the screen. In the current layout, bottom actions (specifically the "Sign Out" button in `AppDrawer` and bottom action sheets) have no bottom safe-area insets, making them unclickable or obscured by the system navigation buttons.

When users switch to gesture navigation or full screen, the system bar is hidden (bottom inset is 0). The solution must adapt dynamically: adding clearance ONLY when the virtual navigation bar is present, and keeping the default layout unchanged when it is off.

## Technical Architecture

### 1. Inset Detection Mechanism
Flutter exposes system window insets via `MediaQuery.paddingOf(context).bottom` and `SafeArea`:
- **Virtual Navigation Bar Active**: `MediaQuery.paddingOf(context).bottom > 0` (~48dp to 54dp).
- **Virtual Navigation Bar Inactive (Gesture / Fullscreen)**: `MediaQuery.paddingOf(context).bottom == 0` (or minimal gesture inset ~12-16dp).

By wrapping bottom action containers in `SafeArea(top: false, bottom: true)` or dynamically adding `MediaQuery.paddingOf(context).bottom`:
- Zero extra space is added if the virtual navigation bar is disabled.
- The exact required clearance is added when the virtual navigation bar is enabled.

### 2. Components to Update

#### A. `AppDrawer` (`lib/app/navigation/app_drawer.dart`)
- **Current State**: Bottom actions ("Switch Module" and "Sign Out") are inside a `Column` at the end of the `Drawer`, with a static `Padding(padding: EdgeInsets.only(top: 2, bottom: 12))`.
- **Target State**: Wrap the bottom action section in a `SafeArea(top: false, bottom: true, minimum: const EdgeInsets.only(bottom: 8))` to ensure the Sign Out button is elevated above the 3-button bar on devices that have it, and retains its default 12dp spacing on devices without it.

#### B. Modal Wrapper (`lib/core/widgets/ss_ui.dart` - `openAppMenu`)
- **Current State**: `openAppMenu` displays `AppDrawer` within a `showGeneralDialog` inside a transparent `Material` sized with `width: MediaQuery.of(ctx).size.width * 0.78`.
- **Target State**: Ensure the dialog pass-through preserves system window insets so `AppDrawer` receives the true `MediaQuery.paddingOf(context).bottom`.

#### C. Bottom Sheets & Sticky Footers
- Ensure `showModalBottomSheet` calls have `useSafeArea: true` enabled and audit common sticky action containers to include bottom padding.

## Error Handling & Edge Cases
- **Orientation Changes**: Recomputes dynamically upon rotation via `MediaQuery`.
- **Keyboard Appearance**: When virtual keyboard opens, `viewInsets.bottom` increases while `viewPadding.bottom` reflects the system bar; `SafeArea` handles both without overlap.
- **Gesture Bar vs 3-Button Bar**: `SafeArea` seamlessly handles both without requiring device manufacturer specific checks.

## Verification Plan
1. Check `lib/app/navigation/app_drawer.dart` and `lib/core/widgets/ss_ui.dart` for correct compilation with `flutter analyze`.
2. Hot reload or hot restart to device `24117RN76G`.
3. Open the side menu drawer on the phone and verify that the "Sign Out" button sits comfortably above the virtual navigation bar and is fully clickable.
