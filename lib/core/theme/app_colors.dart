import 'package:flutter/material.dart';

/// Design Palette — InventarIA
/// Primary:    Ink Black     #00171F  — navigation bars, headers
/// Secondary:  Dust Gray     #DBD3D8  — selected tab indicators, KPI accents
/// Accent:     Tea Green     #D6FFB7  — CTAs, FAB, confirmations
/// Background: Deep SpaceBlue #003459 — main screens, containers
/// Support:    Fresh Sky     #00A8E8  — secondary text, inactive states
abstract final class AppColors {
  // ── Brand Palette ──────────────────────────────────────────────────────────
  static const Color inkBlack      = Color(0xFF00171F);
  static const Color dustGrey      = Color(0xFFDBD3D8);
  static const Color deepSpaceBlue = Color(0xFF003459);
  static const Color teaGreen      = Color(0xFFD6FFB7);
  static const Color freshSky      = Color(0xFF00A8E8);

  // ── Semantic aliases ───────────────────────────────────────────────────────
  static const Color primary      = deepSpaceBlue;
  static const Color primaryLight = Color(0xFF004A7F);
  static const Color primaryDark  = inkBlack;

  static const Color secondary    = freshSky;
  static const Color accent       = teaGreen;
  static const Color accentDark   = Color(0xFFA8E68A);

  // ── Alert / Status system ──────────────────────────────────────────────────
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);
  static const Color error   = Color(0xFFE74C3C);
  static const Color info    = freshSky;

  // ── Light Mode ──────────────────────────────────────────────────────────────
  static const Color background       = Color(0xFFF0F4F8);
  static const Color surface          = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFEBF0F5);
  static const Color border           = Color(0xFFD8E0E8);
  static const Color textPrimary      = inkBlack;
  static const Color textSecondary    = Color(0xFF4A6070);
  static const Color textTertiary     = Color(0xFF8FA8B8);

  // ── Dark Mode ───────────────────────────────────────────────────────────────
  // Spec: background = Deep Space Blue (#003459), nav bars = Ink Black (#00171F)
  static const Color darkBackground       = deepSpaceBlue;        // #003459
  static const Color darkNavBackground    = inkBlack;             // #00171F — nav bars
  static const Color darkSurface          = Color(0xFF004070);    // elevated card
  static const Color darkSurfaceSecondary = Color(0xFF004E80);    // deeper layer
  static const Color darkBorder           = Color(0xFF1A5070);
  static const Color darkBorderStrong     = Color(0xFF2A6890);
  static const Color darkTextPrimary      = Color(0xFFF0F4F8);
  static const Color darkTextSecondary    = dustGrey;             // #DBD3D8
  static const Color darkTextTertiary     = Color(0xFF6A90A8);
}
