import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/card_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class RecentCardCard extends StatelessWidget {
  final CardModel card;
  final VoidCallback? onTap;

  const RecentCardCard({super.key, required this.card, this.onTap});

  Color _color(CardType type) {
    switch (type) {
      case CardType.document: return AppColors.documentColor;
      case CardType.event: return AppColors.eventColor;
      case CardType.information: return AppColors.infoColor;
    }
  }

  IconData _icon(CardType type) {
    switch (type) {
      case CardType.document: return Icons.description_outlined;
      case CardType.event: return Icons.event_outlined;
      case CardType.information: return Icons.info_outline;
    }
  }

  String _typeLabel(CardType type) {
    switch (type) {
      case CardType.document: return 'Document';
      case CardType.event: return 'Événement';
      case CardType.information: return 'Information';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color(card.type);
    final dateStr = card.date != null
        ? DateFormat('dd/MM/yyyy').format(card.date!)
        : DateFormat('dd/MM/yyyy').format(card.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Material(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(_icon(card.type), color: color, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$dateStr · ${_typeLabel(card.type)}${card.tags.isNotEmpty ? ' · ${card.tags.first}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
