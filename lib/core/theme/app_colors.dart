import 'package:flutter/material.dart';

/// Wiki Palette:
/// Ink Black: #00171F | Dust Grey: #DBD3D8 | Deep Space Blue: #003459
/// Tea Green: #D6FFB7 | Fresh Sky: #00A8E8
abstract final class AppColors {
  // ── Wiki Primary Palette ──
  static const Color inkBlack = Color(0xFF00171F);
  static const Color dustGrey = Color(0xFFDBD3D8);
  static const Color deepSpaceBlue = Color(0xFF003459);
  static const Color teaGreen = Color(0xFFD6FFB7);
  static const Color freshSky = Color(0xFF00A8E8);

  // ── Semantic Aliases ──
  static const Color primary = deepSpaceBlue;
  static const Color primaryLight = Color(0xFF004A7F);
  static const Color primaryDark = inkBlack;

  static const Color secondary = freshSky;
  static const Color secondaryLight = Color(0xFF33BCEF);

  static const Color accent = teaGreen;
  static const Color accentDark = Color(0xFFA8E68A);

  // ── Status Colors ──
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);
  static const Color info = freshSky;

  // ── Light Mode ──
  static const Color background = Color(0xFFF0F4F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFEBF0F5);
  static const Color border = dustGrey;
  static const Color textPrimary = inkBlack;
  static const Color textSecondary = Color(0xFF5A6B7D);
  static const Color textTertiary = dustGrey;

  // ── Dark Mode ──
  static const Color darkBackground = inkBlack;
  static const Color darkSurface = deepSpaceBlue;
  static const Color darkSurfaceSecondary = Color(0xFF004A7F);
  static const Color darkBorder = Color(0xFF3D6B8E);
  static const Color darkTextPrimary = Color(0xFFF0F4F8);
  static const Color darkTextSecondary = dustGrey;
}
