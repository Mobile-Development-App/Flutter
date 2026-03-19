import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────
// num extensions — works on int, double and num.
// Defined on num (not double) so Dart's type inference
// never causes NoSuchMethodError at runtime.
// ─────────────────────────────────────────────
extension NumFormatting on num {
  /// "$1.200.000"  – Colombian peso, no decimals
  String get currencyFormatted {
    final formatter = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    return formatter.format(toDouble());
  }

  /// Compact: "$1.2M", "$500K", "$800"
  String get compactCurrency {
    final v = toDouble();
    if (v >= 1000000) {
      return '\$${(v / 1000000).toStringAsFixed(1)}M';
    } else if (v >= 1000) {
      return '\$${(v / 1000).toStringAsFixed(0)}K';
    }
    return '\$${v.toStringAsFixed(0)}';
  }

  /// "12.5%"
  String get percentFormatted => '${toDouble().toStringAsFixed(1)}%';
}

// ─────────────────────────────────────────────
// int extensions
// ─────────────────────────────────────────────
extension IntFormatting on int {
  /// "1.200.000" with thousands separator
  String get formatted {
    final formatter = NumberFormat.decimalPattern('es_CO');
    return formatter.format(this);
  }
}

// ─────────────────────────────────────────────
// DateTime extensions
// ─────────────────────────────────────────────
extension DateFormatting on DateTime {
  /// "15 mar. 2025"
  String get shortFormatted =>
      DateFormat.yMMMd('es_ES').format(this);

  /// "15 mar"
  String get dayMonth => DateFormat('dd MMM', 'es_ES').format(this);

  /// "hace 3 min"  /  "en 2 días"
  String get relativeFormatted {
    final diff = difference(DateTime.now());
    final abs = diff.abs();

    if (abs.inSeconds < 60) return 'hace un momento';
    if (abs.inMinutes < 60) {
      final m = abs.inMinutes;
      return diff.isNegative ? 'hace $m min' : 'en $m min';
    }
    if (abs.inHours < 24) {
      final h = abs.inHours;
      return diff.isNegative ? 'hace $h h' : 'en $h h';
    }
    final d = abs.inDays;
    return diff.isNegative ? 'hace $d días' : 'en $d días';
  }

  /// "lun", "mar", "mié" …
  String get dayOfWeek => DateFormat('EEE', 'es_ES').format(this);
}

// ─────────────────────────────────────────────
// BuildContext extensions  (theme shortcuts)
// ─────────────────────────────────────────────
extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Dismiss the software keyboard
  void hideKeyboard() => FocusScope.of(this).unfocus();
}

// ─────────────────────────────────────────────
// Widget extensions
// ─────────────────────────────────────────────
extension WidgetX on Widget {
  /// Conditionally wrap a widget: `myWidget.if(condition, (w) => Padding(...))`
  Widget applyIf(bool condition, Widget Function(Widget child) transform) =>
      condition ? transform(this) : this;
}

// ─────────────────────────────────────────────
// HapticManager  (mirrors HapticManager in Swift)
// ─────────────────────────────────────────────
abstract final class HapticManager {
  /// Medium impact (default)
  static Future<void> impact([
    HapticFeedbackType type = HapticFeedbackType.mediumImpact,
  ]) async {
    switch (type) {
      case HapticFeedbackType.lightImpact:
        await HapticFeedback.lightImpact();
      case HapticFeedbackType.mediumImpact:
        await HapticFeedback.mediumImpact();
      case HapticFeedbackType.heavyImpact:
        await HapticFeedback.heavyImpact();
      case HapticFeedbackType.selection:
        await HapticFeedback.selectionClick();
      case HapticFeedbackType.vibrate:
        await HapticFeedback.vibrate();
    }
  }

  static Future<void> selection() => HapticFeedback.selectionClick();
  static Future<void> success() => HapticFeedback.mediumImpact();
  static Future<void> warning() => HapticFeedback.heavyImpact();
  static Future<void> error() => HapticFeedback.vibrate();
}

enum HapticFeedbackType {
  lightImpact,
  mediumImpact,
  heavyImpact,
  selection,
  vibrate,
}
