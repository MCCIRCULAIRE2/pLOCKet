import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/analytical_field.dart';
import '../providers/analytical_field_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass_card.dart';
import '../widgets/adaptive_dialog.dart';
import 'ocr_comparison_test.dart';
import 'debug_storage_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        context.read<AnalyticalFieldProvider>().loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      resizeToAvoidBottomInset: false,
      body: Consumer<AnalyticalFieldProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              // Section Diagnostic
              GlassSectionHeader(title: 'Diagnostic'),
              const SizedBox(height: AppSpacing.md),
              GlassCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.compare_arrows),
                      title: const Text('Test comparatif OCR'),
                      subtitle: const Text('Comparer Import vs Scanner sur la même image'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OcrComparisonTest(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.storage),
                      title: const Text('Debug Storage'),
                      subtitle: const Text('Inspecter le stockage localStorage'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DebugStorageScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              
              // Section Champs analytiques
              GlassSectionHeader(
                title: 'Champs analytiques',
                trailing: TextButton.icon(
                  onPressed: () => _showCreateFieldDialog(context, provider),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Créer'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (provider.fields.isEmpty)
                GlassCard(
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.category_outlined,
                            size: 48, color: AppColors.textTertiary),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Aucun champ analytique',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textTertiary)),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Créez des dimensions métier pour organiser vos documents',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.textTertiary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...provider.fields.map((field) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _FieldCard(field: field),
                    )),
            ],
          );
        },
      ),
    );
  }

  void _showCreateFieldDialog(
      BuildContext context, AnalyticalFieldProvider provider) {
    final controller = TextEditingController();
    showAdaptiveModalDialog(
      context: context,
      title: 'Nouveau champ analytique',
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Nom du champ',
          hintText: 'Ex: Personne, Logement, Véhicule...',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              provider.createField(name: name);
              Navigator.pop(context);
            }
          },
          child: const Text('Créer'),
        ),
      ],
    );
  }
}

class _FieldCard extends StatelessWidget {
  final AnalyticalField field;
  const _FieldCard({required this.field});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalyticalFieldProvider>();
    final values = provider.valuesForField(field.id);
    final theme = Theme.of(context);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.label_outline, size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(field.name,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Text('${values.length} valeur(s)',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textTertiary)),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: () => _showRenameDialog(context, provider),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 16, color: AppColors.accentRed),
                visualDensity: VisualDensity.compact,
                onPressed: () => _confirmDelete(context, provider),
              ),
            ],
          ),
          if (values.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: values
                  .map((v) => _ValueChip(value: v, fieldId: field.id))
                  .toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _showAddValueDialog(context, provider),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Ajouter une valeur'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
      BuildContext context, AnalyticalFieldProvider provider) {
    final controller = TextEditingController(text: field.name);
    showAdaptiveModalDialog(
      context: context,
      title: 'Renommer le champ',
      content: TextField(
        controller: controller,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              provider.renameField(field, name);
              Navigator.pop(context);
            }
          },
          child: const Text('Renommer'),
        ),
      ],
    );
  }

  void _confirmDelete(
      BuildContext context, AnalyticalFieldProvider provider) {
    showAdaptiveModalDialog(
      context: context,
      title: 'Supprimer le champ ?',
      content: Text(
          'Supprimer "${field.name}" effacera aussi toutes ses valeurs.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            provider.deleteField(field.id);
            Navigator.pop(context);
          },
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRed),
          child: const Text('Supprimer'),
        ),
      ],
    );
  }

  void _showAddValueDialog(
      BuildContext context, AnalyticalFieldProvider provider) {
    final labelController = TextEditingController();
    final aliasController = TextEditingController();
    final aliases = <String>[];

    showAdaptiveModalDialog(
      context: context,
      title: 'Ajouter une valeur à "${field.name}"',
      content: StatefulBuilder(
        builder: (ctx, setDialogState) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Nom principal',
                    hintText: 'Ex: Maison Saint-Girons',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: aliasController,
                        decoration: const InputDecoration(
                          labelText: 'Alias',
                          hintText: 'Ex: Maison de vacances',
                        ),
                        onSubmitted: (v) {
                          if (v.trim().isNotEmpty) {
                            setDialogState(
                                () => aliases.add(v.trim()));
                            aliasController.clear();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final v = aliasController.text.trim();
                        if (v.isNotEmpty) {
                          setDialogState(() => aliases.add(v));
                          aliasController.clear();
                        }
                      },
                    ),
                  ],
                ),
                if (aliases.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: aliases
                        .map((a) => Chip(
                              label: Text(a, style: const TextStyle(fontSize: 12)),
                              onDeleted: () => setDialogState(
                                  () => aliases.remove(a)),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final label = labelController.text.trim();
            if (label.isNotEmpty) {
              provider.addValue(
                fieldId: field.id,
                label: label,
                aliases: aliases,
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}

class _ValueChip extends StatelessWidget {
  final AnalyticalValue value;
  final String fieldId;
  const _ValueChip({required this.value, required this.fieldId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onLongPress: () => _showValueOptions(context),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value.label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500)),
            if (value.aliases.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text('+${value.aliases.length}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: AppColors.textTertiary, fontSize: 10)),
            ],
          ],
        ),
      ),
    );
  }

  void _showValueOptions(BuildContext context) {
    final provider = context.read<AnalyticalFieldProvider>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Renommer'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameValueDialog(context, provider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.label_outline),
              title: const Text('Gérer les alias'),
              onTap: () {
                Navigator.pop(ctx);
                _showAliasDialog(context, provider);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.accentRed),
              title: Text('Supprimer',
                  style: TextStyle(color: AppColors.accentRed)),
              onTap: () {
                Navigator.pop(ctx);
                provider.deleteValue(value.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameValueDialog(
      BuildContext context, AnalyticalFieldProvider provider) {
    final controller = TextEditingController(text: value.label);
    showAdaptiveModalDialog(
      context: context,
      title: 'Renommer la valeur',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: controller, autofocus: true),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Toutes les fiches liées seront mises à jour automatiquement.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final label = controller.text.trim();
            if (label.isNotEmpty) {
              provider.renameValue(value, label);
              Navigator.pop(context);
            }
          },
          child: const Text('Renommer'),
        ),
      ],
    );
  }

  void _showAliasDialog(
      BuildContext context, AnalyticalFieldProvider provider) {
    final aliasController = TextEditingController();
    final currentAliases = List<String>.from(value.aliases);

    showAdaptiveModalDialog(
      context: context,
      title: 'Alias de "${value.label}"',
      content: StatefulBuilder(
        builder: (ctx, setDialogState) {
          return SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (currentAliases.isNotEmpty)
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: currentAliases
                        .map((a) => Chip(
                              label: Text(a,
                                  style: const TextStyle(fontSize: 12)),
                              onDeleted: () => setDialogState(
                                  () => currentAliases.remove(a)),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: aliasController,
                        decoration: const InputDecoration(
                          labelText: 'Nouvel alias',
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final v = aliasController.text.trim();
                        if (v.isNotEmpty) {
                          setDialogState(
                              () => currentAliases.add(v));
                          aliasController.clear();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            provider.updateValue(
                value.copyWith(aliases: currentAliases));
            Navigator.pop(context);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
