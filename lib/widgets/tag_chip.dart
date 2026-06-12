import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class TagChip extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback? onDeleted;
  final bool selected;
  final double fontSize;

  const TagChip({
    super.key,
    required this.label,
    this.color,
    this.onDeleted,
    this.selected = false,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.surface2;
    final textColor = selected ? AppColors.textPrimary : AppColors.textSecondary;
    final borderColor = selected ? AppColors.primaryBlue.withValues(alpha: 0.4) : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryBlue.withValues(alpha: 0.15) : chipColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (onDeleted != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onDeleted,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close, size: 14, color: AppColors.textTertiary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
