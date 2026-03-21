import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shadow presets
// ─────────────────────────────────────────────────────────────────────────────
abstract final class AppShadows {
  static const List<BoxShadow> small = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 3)),
    BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> large = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  // Dark mode uses depth shadows + subtle inner glow
  static const List<BoxShadow> darkCard = [
    BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 1)),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Card decoration — used throughout the app
// ─────────────────────────────────────────────────────────────────────────────
BoxDecoration cardDecoration({bool isDark = false}) => BoxDecoration(
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: isDark ? AppShadows.darkCard : AppShadows.medium,
      border: isDark
          ? Border.all(color: const Color(0x1AFFFFFF), width: 0.5)
          : Border.all(color: AppColors.border, width: 0.5),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Button styles
// ─────────────────────────────────────────────────────────────────────────────

/// Tea Green — primary CTA (scan, confirm, key actions)
final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: AppColors.teaGreen,
  disabledBackgroundColor: AppColors.teaGreen.withValues(alpha: 0.35),
  foregroundColor: AppColors.inkBlack,
  disabledForegroundColor: AppColors.inkBlack.withValues(alpha: 0.4),
  textStyle: AppTypography.headline,
  minimumSize: const Size(double.infinity, 52),
  padding: const EdgeInsets.symmetric(vertical: 16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  elevation: 0,
  shadowColor: Colors.transparent,
  animationDuration: const Duration(milliseconds: 120),
);

/// Outlined — secondary action
final ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
  foregroundColor: AppColors.freshSky,
  textStyle: AppTypography.headline,
  minimumSize: const Size(double.infinity, 52),
  padding: const EdgeInsets.symmetric(vertical: 16),
  side: const BorderSide(color: AppColors.freshSky, width: 1.5),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  elevation: 0,
);

/// Ghost / text — tertiary
final ButtonStyle ghostButtonStyle = TextButton.styleFrom(
  foregroundColor: AppColors.freshSky,
  textStyle: AppTypography.headline,
  minimumSize: const Size(double.infinity, 52),
  padding: const EdgeInsets.symmetric(vertical: 16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);

/// Deep Space Blue filled (for dark surfaces)
final ButtonStyle accentButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: AppColors.deepSpaceBlue,
  disabledBackgroundColor: AppColors.deepSpaceBlue.withValues(alpha: 0.4),
  foregroundColor: Colors.white,
  textStyle: AppTypography.headline,
  minimumSize: const Size(double.infinity, 52),
  padding: const EdgeInsets.symmetric(vertical: 16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  elevation: 0,
);

// ─────────────────────────────────────────────────────────────────────────────
// ThemeData
// ─────────────────────────────────────────────────────────────────────────────
abstract final class AppTheme {
  static ThemeData get light => _buildTheme(brightness: Brightness.light);
  static ThemeData get dark  => _buildTheme(brightness: Brightness.dark);

  static ThemeData _buildTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: AppColors.teaGreen,
            onPrimary: AppColors.inkBlack,
            secondary: AppColors.freshSky,
            onSecondary: AppColors.inkBlack,
            tertiary: AppColors.dustGrey,
            onTertiary: AppColors.inkBlack,
            surface: AppColors.darkSurface,
            onSurface: AppColors.darkTextPrimary,
            surfaceContainerHighest: AppColors.darkSurfaceSecondary,
            error: AppColors.error,
            onError: Colors.white,
            outline: AppColors.darkBorder,
          )
        : ColorScheme.light(
            primary: AppColors.deepSpaceBlue,
            onPrimary: Colors.white,
            secondary: AppColors.freshSky,
            onSecondary: Colors.white,
            tertiary: AppColors.teaGreen,
            onTertiary: AppColors.inkBlack,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
            surfaceContainerHighest: AppColors.surfaceSecondary,
            error: AppColors.error,
            onError: Colors.white,
            outline: AppColors.border,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,

      // ── Scaffold ──────────────────────────────────────────────────────────
      // Dark:  Deep Space Blue (#003459) per spec — "Main background"
      // Light: Clean off-white
      scaffoldBackgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,

      // ── AppBar ────────────────────────────────────────────────────────────
      // Ink Black per spec — "Top navigation bar"
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.darkNavBackground : AppColors.inkBlack,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: AppTypography.title2.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),

      // ── Typography ────────────────────────────────────────────────────────
      fontFamily: 'Inter',
      textTheme: TextTheme(
        displayLarge: AppTypography.largeTitle.copyWith(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        titleLarge: AppTypography.title.copyWith(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        titleMedium: AppTypography.title2.copyWith(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        titleSmall: AppTypography.title3.copyWith(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        headlineMedium: AppTypography.headline.copyWith(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        bodyLarge: AppTypography.body.copyWith(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        bodyMedium: AppTypography.callout.copyWith(
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
        bodySmall: AppTypography.caption.copyWith(
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
        labelSmall: AppTypography.caption2.copyWith(
          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
        ),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0x1AFFFFFF) : AppColors.border,
            width: 0.5,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Input / TextField ──────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.darkSurfaceSecondary
            : AppColors.surfaceSecondary,
        hintStyle: AppTypography.body.copyWith(
          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
        ),
        labelStyle: AppTypography.callout.copyWith(
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.freshSky, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        prefixIconColor: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
        suffixIconColor: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkBorder : AppColors.border,
        thickness: 0.5,
        space: 1,
      ),

      // ── Bottom Navigation ─────────────────────────────────────────────────
      // Ink Black per spec — "Footer / bottom navigation background"
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkNavBackground : AppColors.inkBlack,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.dustGrey.withValues(alpha: 0.25),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Colors.white, size: 22);
          }
          return const IconThemeData(
              color: AppColors.freshSky, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.caption.copyWith(
                color: Colors.white, fontWeight: FontWeight.w600);
          }
          return AppTypography.caption.copyWith(color: AppColors.freshSky);
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.teaGreen,
        foregroundColor: AppColors.inkBlack,
        elevation: 6,
        shape: const CircleBorder(),
        splashColor: AppColors.accentDark,
      ),

      // ── Chip ──────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? AppColors.darkSurfaceSecondary
            : AppColors.surfaceSecondary,
        selectedColor: AppColors.teaGreen.withValues(alpha: 0.2),
        checkmarkColor: AppColors.teaGreen,
        labelStyle: AppTypography.caption.copyWith(
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            width: 0.5,
          ),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // ── Switch ────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.inkBlack;
          return isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.teaGreen;
          return isDark
              ? AppColors.darkSurfaceSecondary
              : AppColors.surfaceSecondary;
        }),
      ),

      // ── Bottom Sheet ──────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.darkNavBackground : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        dragHandleColor: isDark
            ? AppColors.darkTextTertiary
            : AppColors.textTertiary,
        dragHandleSize: const Size(36, 4),
        showDragHandle: true,
      ),

      // ── List Tile ─────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        textColor: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        subtitleTextStyle: AppTypography.caption.copyWith(
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ── Progress Indicator ────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.freshSky,
        linearTrackColor: AppColors.darkBorder,
      ),

      // ── Snack Bar ─────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.inkBlack,
        contentTextStyle: AppTypography.callout.copyWith(color: Colors.white),
        actionTextColor: AppColors.teaGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
      ),
    );
  }
}
