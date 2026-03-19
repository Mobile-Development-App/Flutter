import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Equivalent of `.cardStyle()` modifier in Swift.
/// Wraps any child in the themed card decoration.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AppCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inner = padding != null
        ? Padding(padding: padding!, child: child)
        : child;
    return Container(
      decoration: cardDecoration(isDark: isDark),
      child: inner,
    );
  }
}
