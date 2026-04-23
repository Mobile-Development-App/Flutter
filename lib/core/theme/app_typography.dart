import 'package:flutter/material.dart';

/// Typography system — Inter font family
/// Screen Title:   Bold 22–24pt
/// Section Header: SemiBold 18pt
/// Body:           Regular 14–16pt
/// Caption:        Medium 12–13pt
/// KPI/Numbers:    SemiBold 16–18pt
abstract final class AppTypography {
  static const String _font = 'Inter';

  // ── Titles ─────────────────────────────────────────────────────────────────
  static const TextStyle largeTitle = TextStyle(
    fontFamily: _font,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle title = TextStyle(
    fontFamily: _font,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static const TextStyle title2 = TextStyle(
    fontFamily: _font,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
  );

  // ── Section header ─────────────────────────────────────────────────────────
  static const TextStyle title3 = TextStyle(
    fontFamily: _font,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.3,
  );

  // ── KPI / Numbers ──────────────────────────────────────────────────────────
  static const TextStyle headline = TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );

  // ── Body ───────────────────────────────────────────────────────────────────
  static const TextStyle body = TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMedium = callout;

  static const TextStyle callout = TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  // ── Caption ────────────────────────────────────────────────────────────────
  static const TextStyle caption = TextStyle(
    fontFamily: _font,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
  );

  static const TextStyle caption2 = TextStyle(
    fontFamily: _font,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.1,
  );

  // ── Label / overline ───────────────────────────────────────────────────────
  static const TextStyle overline = TextStyle(
    fontFamily: _font,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    height: 1.4,
  );
}
