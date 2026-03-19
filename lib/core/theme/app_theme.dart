import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

// ─────────────────────────────────────────────
// Shadow presets  (mirrors AppShadows in Swift)
// ─────────────────────────────────────────────
abstract final class AppShadows {
  static const List<BoxShadow> small = [
    BoxShadow(
      color: Color(0x0D000000), // black 5%
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x1A000000), // black 10%
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> large = [
    BoxShadow(
      color: Color(0x26000000), // black 15%
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> darkMedium = [
    BoxShadow(
      color: Color(0x4D000000), // black 30%
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
}

// ─────────────────────────────────────────────
// Card decoration  (mirrors CardModifier)
// ─────────────────────────────────────────────
BoxDecoration cardDecoration({bool isDark = false}) => BoxDecoration(
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: isDark ? AppShadows.darkMedium : AppShadows.medium,
    );

// ─────────────────────────────────────────────
// Button styles
// ─────────────────────────────────────────────

/// Tea Green + Ink Black text (primary CTA)
final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: AppColors.teaGreen,
  disabledBackgroundColor: AppColors.teaGreen.withValues(alpha: 0.4),
  foregroundColor: AppColors.inkBlack,
  disabledForegroundColor: AppColors.inkBlack.withValues(alpha: 0.4),
  textStyle: AppTypography.headline,
  minimumSize: const Size(double.infinity, 52),
  padding: const EdgeInsets.symmetric(vertical: 16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  elevation: 0,
  animationDuration: const Duration(milliseconds: 150),
);

/// Deep Space Blue outlined  (secondary)
final ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
  foregroundColor: AppColors.deepSpaceBlue,
  textStyle: AppTypography.headline,
  minimumSize: const Size(double.infinity, 52),
  padding: const EdgeInsets.symmetric(vertical: 16),
  side: const BorderSide(color: AppColors.deepSpaceBlue, width: 1.5),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);

/// Fresh Sky ghost button
final ButtonStyle ghostButtonStyle = TextButton.styleFrom(
  foregroundColor: AppColors.freshSky,
  textStyle: AppTypography.headline,
  minimumSize: const Size(double.infinity, 52),
  padding: const EdgeInsets.symmetric(vertical: 16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);

/// Deep Space Blue filled (for dark backgrounds)
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

// ─────────────────────────────────────────────
// ThemeData  (light + dark)
// ─────────────────────────────────────────────
abstract final class AppTheme {
  static ThemeData get light => _buildTheme(brightness: Brightness.light);
  static ThemeData get dark => _buildTheme(brightness: Brightness.dark);

  static ThemeData _buildTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: AppColors.freshSky,
            onPrimary: AppColors.inkBlack,
            secondary: AppColors.teaGreen,
            onSecondary: AppColors.inkBlack,
            tertiary: AppColors.teaGreen,
            surface: AppColors.darkSurface,
            onSurface: AppColors.darkTextPrimary,
            surfaceContainerHighest: AppColors.darkSurfaceSecondary,
            error: AppColors.error,
            onError: Colors.white,
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
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      // ── AppBar ── Material3 tint fix: surfaceTintColor must be transparent
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.deepSpaceBlue,
        foregroundColor: isDark ? AppColors.darkTextPrimary : Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.darkTextPrimary : Colors.white,
        ),
        titleTextStyle: AppTypography.title2.copyWith(
          color: isDark ? AppColors.darkTextPrimary : Colors.white,
        ),
      ),
      // ── Typography ──
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
          color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
        ),
      ),
      // ── Cards ──
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),
      // ── Input / TextField ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.darkSurfaceSecondary
            : AppColors.surfaceSecondary,
        hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkBorder : AppColors.border,
        thickness: 1,
        space: 1,
      ),
      // ── Bottom Nav ──
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.surface,
        indicatorColor: AppColors.teaGreen.withValues(alpha: 0.3),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.deepSpaceBlue);
          }
          return const IconThemeData(color: AppColors.textSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.caption
                .copyWith(color: AppColors.deepSpaceBlue);
          }
          return AppTypography.caption
              .copyWith(color: AppColors.textSecondary);
        }),
      ),
      // ── FAB ──
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.teaGreen,
        foregroundColor: AppColors.inkBlack,
        elevation: 4,
        shape: CircleBorder(),
      ),
      // ── Chip ──
      chipTheme: ChipThemeData(
        backgroundColor:
            isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary,
        selectedColor: AppColors.teaGreen,
        labelStyle: AppTypography.caption,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
    );
  }
}
