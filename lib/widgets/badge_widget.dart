import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/product.dart';

enum BadgeStyle {
  defaultStyle,
  success,
  warning,
  destructive,
  info,
  secondary;

  Color get backgroundColor {
    switch (this) {
      case defaultStyle:
        return AppColors.freshSky.withValues(alpha: 0.15);
      case success:
        return AppColors.success.withValues(alpha: 0.12);
      case warning:
        return AppColors.warning.withValues(alpha: 0.12);
      case destructive:
        return AppColors.error.withValues(alpha: 0.12);
      case info:
        return AppColors.freshSky.withValues(alpha: 0.12);
      case secondary:
        return AppColors.dustGrey.withValues(alpha: 0.15);
    }
  }

  Color get textColor {
    switch (this) {
      case defaultStyle:
        return AppColors.freshSky;
      case success:
        return AppColors.success;
      case warning:
        return AppColors.warning;
      case destructive:
        return AppColors.error;
      case info:
        return AppColors.freshSky;
      case secondary:
        return AppColors.dustGrey;
    }
  }

  Color get borderColor {
    return textColor.withValues(alpha: 0.25);
  }
}

class BadgeWidget extends StatelessWidget {
  final String text;
  final BadgeStyle style;

  const BadgeWidget({
    super.key,
    required this.text,
    this.style = BadgeStyle.defaultStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: style.borderColor, width: 0.5),
      ),
      child: Text(
        text,
        style: AppTypography.overline.copyWith(
          color: style.textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class StockBadge extends StatelessWidget {
  final StockStatus status;
  const StockBadge({super.key, required this.status});

  BadgeStyle get _style {
    switch (status) {
      case StockStatus.inStock:
        return BadgeStyle.success;
      case StockStatus.lowStock:
        return BadgeStyle.warning;
      case StockStatus.outOfStock:
        return BadgeStyle.destructive;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BadgeWidget(text: status.label, style: _style);
  }
}
