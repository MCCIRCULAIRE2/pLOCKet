import 'package:flutter/material.dart';
import '../ai/ai_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class ResponseCard extends StatelessWidget {
  final AnswerResult result;
  final VoidCallback? onOpenSource;
  final void Function(String cardId)? onOpenSourceById;

  const ResponseCard({
    super.key,
    required this.result,
    this.onOpenSource,
    this.onOpenSourceById,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confColor = AppColors.confidenceColor(result.confidence);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(color: Color(0x4D000000), blurRadius: 12, offset: Offset(0, 4)),
            BoxShadow(color: Color(0x26000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  Text('Réponse', style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.primaryBlue,
                  )),
                  const Spacer(),
                  _confidenceBadge(confColor, theme),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.15)),
                ),
                child: Text(
                  result.answerText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ),
              if (result.extractedValue != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.copy_all, size: 14, color: AppColors.primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          result.extractedValue!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (result.justification != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  result.justification!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (result.sourceCardIds.length > 1) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Sources (${result.sourceCardIds.length})',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...result.sourceTitles.asMap().entries.map((entry) {
                  final index = entry.key;
                  final title = entry.value;
                  final cardId = result.sourceCardIds[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: InkWell(
                      onTap: onOpenSourceById != null 
                          ? () => onOpenSourceById!(cardId)
                          : null,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, 
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.description_outlined, size: 16, color: AppColors.primaryBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(Icons.open_in_new, size: 14, color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ] else if (result.sourceCardId != null) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onOpenSource,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Ouvrir la fiche source'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _confidenceBadge(Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, size: 8, color: color),
          const SizedBox(width: 4),
          Text(
            result.confidence,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
