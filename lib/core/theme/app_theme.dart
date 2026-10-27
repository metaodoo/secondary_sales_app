import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color background = Color(0xFFF7F9FC);
  static const Color surface = Colors.white;
  static const Color surfaceTint = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFDDE6F2);
  static const Color borderSoft = Color(0xFFE2E8F0);
  static const Color borderMuted = Color(0xFFF1F5F9);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color primary = Color(0xFF1D5DE6);
  static const Color primaryStrong = Color(0xFF0E4CD3);
  static const Color primarySoft = Color(0xFFEFF6FF);
  static const Color primaryTint = Color(0xFFDBEAFE);
  static const Color successSoft = Color(0xFFDCFCE7);
  /// Green for buttons with white text: 5.5:1 contrast (WCAG AA needs 4.5).
  static const Color success = Color(0xFF047857);
  /// Red for buttons with white text: 4.8:1 contrast.
  static const Color danger = Color(0xFFDC2626);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color dangerSoft = Color(0xFFFEE2E2);
}

// Design tokens: the sizes screens should use, so the app looks the same on
// every screen and fits 360 dp (720p) company phones. New code takes sizes
// from here instead of writing numbers inline.

/// Spacing on a 4 dp grid.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Side margin of a screen: 16 dp, the Material margin for phones.
  static const double screen = lg;
  static const double section = lg;
  static const double panel = lg;
  static const double card = md;
}

class AppRadii {
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double xLarge = 20;
  static const double pill = 999;
}

/// Text sizes (sp). Text grows with the phone's font setting.
class AppTextSizes {
  static const double caption = 12;
  static const double body = 14;
  static const double bodyLarge = 16;
  static const double title = 18;
  static const double headline = 22;
}

/// Component sizes.
class AppSizes {
  /// Smallest tappable area (Material and Android accessibility rule).
  /// A control may look smaller; its tap area is padded to this size.
  static const double touchTarget = 48;

  /// Visible button height, inside a [touchTarget] tap area.
  static const double buttonHeight = 40;
  static const double inputHeight = 48;
  static const double avatar = 40;
  static const double icon = 24;
  static const double iconSmall = 18;
}

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryStrong,
      primary: AppColors.primaryStrong,
      secondary: AppColors.primary,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.background,
    useMaterial3: true,
    textTheme: GoogleFonts.interTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primarySoft,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    ),
    // Component defaults built from the tokens above; widgets that do not
    // set their own size get these.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    filledButtonTheme: FilledButtonThemeData(style: _buttonStyle),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _buttonStyle),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
      ),
    ),
    // Only the inner padding: fill and borders stay per screen until each
    // screen is moved to the shared look and checked.
    inputDecorationTheme: const InputDecorationTheme(
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      minVerticalPadding: AppSpacing.sm,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.large),
        side: const BorderSide(color: AppColors.borderSoft),
      ),
    ),
  );
}

/// Buttons: 40 dp visible, 48 dp tap area (Material), compact side padding.
final ButtonStyle _buttonStyle = ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size(64, AppSizes.buttonHeight)),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: AppSpacing.lg),
  ),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.medium)),
  ),
  // Inter, as the rest of the app: a plain TextStyle here would replace the
  // theme's font with the system one.
  textStyle: WidgetStatePropertyAll(
    GoogleFonts.inter(fontSize: AppTextSizes.body, fontWeight: FontWeight.w600),
  ),
);

