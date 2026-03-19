import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/product.dart';

// ─────────────────────────────────────────────
// BadgeStyle  (mirrors BadgeView.BadgeStyle)
// ─────────────────────────────────────────────
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
        return AppColors.deepSpaceBlue.withValues(alpha: 0.12);
      case success:
        return AppColors.success.withValues(alpha: 0.12);
      case warning:
        return AppColors.warning.withValues(alpha: 0.12);
      case destructive:
        return AppColors.error.withValues(alpha: 0.12);
      case info:
        return AppColors.info.withValues(alpha: 0.12);
      case secondary:
        return AppColors.textSecondary.withValues(alpha: 0.12);
    }
  }

  Color get textColor {
    switch (this) {
      case defaultStyle:
        return AppColors.deepSpaceBlue;
      case success:
        return AppColors.success;
      case warning:
        return AppColors.warning;
      case destructive:
        return AppColors.error;
      case info:
        return AppColors.info;
      case secondary:
        return AppColors.textSecondary;
    }
  }
}

// ─────────────────────────────────────────────
// BadgeWidget  (mirrors BadgeView)
// ─────────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: AppTypography.caption2.copyWith(
          color: style.textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// StockBadge  (mirrors StockBadge struct)
// ─────────────────────────────────────────────
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
