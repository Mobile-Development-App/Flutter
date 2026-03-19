import 'package:flutter/material.dart';

/// Mirrors AppTypography from Theme.swift.
/// Uses system font (Inter is not bundled by default; add it via pubspec if needed).
abstract final class AppTypography {
  // ── Title sizes ──
  static const TextStyle largeTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle title2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600, // semibold
  );

  // ── Section header ──
  static const TextStyle title3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  // ── KPI Numbers ──
  static const TextStyle headline = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  // ── Body ──
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle callout = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500, // medium
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle caption2 = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
  );
}
