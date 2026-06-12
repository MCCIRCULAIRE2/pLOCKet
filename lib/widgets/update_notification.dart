import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/update_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class UpdateNotification extends StatelessWidget {
  const UpdateNotification({super.key});

  @override
  Widget build(BuildContext context) {
    final updateService = context.watch<UpdateService>();

    if (!updateService.updateAvailable) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            children: [
              const Icon(Icons.system_update, color: Colors.white, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Mise à jour disponible',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Une nouvelle version est prête',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => updateService.dismiss(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(8),
                ),
                child: const Text('Plus tard'),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: () => updateService.applyUpdate(),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text('Mettre à jour'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
