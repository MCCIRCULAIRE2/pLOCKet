import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analytical_field.dart';
import '../models/card_model.dart';
import '../providers/analytical_field_provider.dart';
import '../ai/semantic_relation_engine.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass_card.dart';
import '../widgets/adaptive_dialog.dart';
import 'card_detail_screen.dart';
import 'search_results_screen.dart';

class AnalyticalValueDetailScreen extends StatefulWidget {
  final AnalyticalValue value;
  final AnalyticalField field;

  const AnalyticalValueDetailScreen({
    super.key,
    required this.value,
    required this.field,
  });

  @override
  State<AnalyticalValueDetailScreen> createState() =>
      _AnalyticalValueDetailScreenState();
}

class _AnalyticalValueDetailScreenState
    extends State<AnalyticalValueDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AnalyticalFieldProvider>();
    final currentValue = provider.allValues
            .where((v) => v.id == widget.value.id)
            .firstOrNull ??
        widget.value;
    final cards = provider.getCardsUsingValue(currentValue);
    final relationSuggestions =
        SemanticRelationEngine.getRelationSuggestions(widget.field.name);
    final relationSynonyms = currentValue.relation != null &&
            currentValue.relation!.isNotEmpty
        ? SemanticRelationEngine.getRelationSynonyms(currentValue.relation!)
        : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(currentValue.label),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) {
              switch (action) {
                case 'rename':
                  _showRenameDialog(context, provider, currentValue);
                  break;
                case 'merge':
                  _showMergeDialog(context, provider, currentValue);
                  break;
                case 'delete':
                  _showDeleteDialog(context, provider, currentValue, cards);
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Renommer'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'merge',
                child: Row(
                  children: [
                    Icon(Icons.merge_type, size: 18),
                    SizedBox(width: 8),
                    Text('Fusionner'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: AppColors.accentRed),
                    const SizedBox(width: 8),
                    Text('Supprimer',
                        style: TextStyle(color: AppColors.accentRed)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Informations',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'Nom principal', value: currentValue.label),
                _InfoRow(label: 'Type', value: widget.field.name),
                _InfoRow(
                  label: 'Créé le',
                  value:
                      '${currentValue.createdAt.day}/${currentValue.createdAt.month}/${currentValue.createdAt.year}',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.link, size: 16, color: AppColors.primaryPurple),
                    const SizedBox(width: AppSpacing.xs),
                    Text('Relation',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (relationSuggestions.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: currentValue.relation != null &&
                            relationSuggestions
                                .contains(currentValue.relation)
                        ? currentValue.relation
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Relation contextuelle',
                      hintText: 'Sélectionner une relation...',
                      isDense: true,
                    ),
                    items: relationSuggestions
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r),
                            ))
                        .toList(),
                    onChanged: (v) {
                      provider.updateValue(currentValue.copyWith(relation: v));
                    },
                  )
                else
                  Text('Aucune relation disponible pour ce type de champ',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textTertiary)),
                if (relationSynonyms.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text('Synonymes automatiques',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textTertiary)),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: 2,
                    children: relationSynonyms
                        .map((s) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryPurple
                                    .withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.radiusSm),
                              ),
                              child: Text(s,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.primaryPurple,
                                      fontSize: 10)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'La recherche comprend automatiquement ces termes.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.label_outline,
                        size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: AppSpacing.xs),
                    Text('Alias',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          _showAliasDialog(context, provider, currentValue),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Gérer'),
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (currentValue.aliases.isEmpty)
                  Text('Aucun alias',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.textTertiary))
                else
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: currentValue.aliases
                        .map((a) => Chip(
                              label: Text(a,
                                  style: const TextStyle(fontSize: 12)),
                              onDeleted: () {
                                final updated = List<String>.from(
                                    currentValue.aliases)
                                  ..remove(a);
                                provider.updateValue(
                                    currentValue.copyWith(aliases: updated));
                              },
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_outlined,
                        size: 16, color: AppColors.accentGreen),
                    const SizedBox(width: AppSpacing.xs),
                    Text('Utilisation',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cards.isNotEmpty
                            ? AppColors.primaryBlue.withValues(alpha: 0.15)
                            : AppColors.surface2,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusXl),
                      ),
                      child: Text(
                        '${cards.length} fiche${cards.length > 1 ? 's' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cards.isNotEmpty
                              ? AppColors.primaryBlue
                              : AppColors.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (cards.isEmpty)
                  Text('Non utilisée',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.textTertiary))
                else ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SearchResultsScreen(
                              query: currentValue.label),
                        ),
                      );
                    },
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('Voir les fiches'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...cards.take(5).map((card) => _CardTile(card: card)),
                  if (cards.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        '+ ${cards.length - 5} autre${cards.length - 5 > 1 ? 's' : ''} fiche${cards.length - 5 > 1 ? 's' : ''}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textTertiary),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context,
      AnalyticalFieldProvider provider, AnalyticalValue currentValue) {
    final controller = TextEditingController(text: currentValue.label);
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
              provider.renameValue(currentValue, label);
              Navigator.pop(context);
            }
          },
          child: const Text('Renommer'),
        ),
      ],
    );
  }

  void _showAliasDialog(BuildContext context,
      AnalyticalFieldProvider provider, AnalyticalValue currentValue) {
    final aliasController = TextEditingController();
    final currentAliases = List<String>.from(currentValue.aliases);

    showAdaptiveModalDialog(
      context: context,
      title: 'Alias de "${currentValue.label}"',
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
                        onSubmitted: (v) {
                          if (v.trim().isNotEmpty) {
                            setDialogState(() => currentAliases.add(v.trim()));
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
                          setDialogState(() => currentAliases.add(v));
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
            provider.updateValue(currentValue.copyWith(aliases: currentAliases));
            Navigator.pop(context);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }

  void _showMergeDialog(BuildContext context,
      AnalyticalFieldProvider provider, AnalyticalValue currentValue) {
    final otherValues = provider
        .valuesForField(currentValue.fieldId)
        .where((v) => v.id != currentValue.id)
        .toList();

    if (otherValues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune autre valeur à fusionner')),
      );
      return;
    }

    AnalyticalValue? selectedValue;

    showAdaptiveModalDialog(
      context: context,
      title: 'Fusionner "${currentValue.label}"',
      content: StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sélectionner la valeur à fusionner avec "${currentValue.label}" :',
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<AnalyticalValue>(
                value: selectedValue,
                decoration: const InputDecoration(
                  labelText: 'Valeur à fusionner',
                  isDense: true,
                ),
                items: otherValues
                    .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(v.label),
                        ))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedValue = v),
              ),
              if (selectedValue != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.accentOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conséquences :',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• "${selectedValue!.label}" sera supprimé',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '• Toutes ses fiches seront réaffectées à "${currentValue.label}"',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '• Ses alias seront ajoutés à "${currentValue.label}"',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: selectedValue != null
              ? () async {
                  await provider.mergeValues(currentValue, selectedValue!);
                  if (context.mounted) Navigator.pop(context);
                }
              : null,
          child: const Text('Fusionner'),
        ),
      ],
    );
  }

  void _showDeleteDialog(
      BuildContext context,
      AnalyticalFieldProvider provider,
      AnalyticalValue currentValue,
      List<CardModel> cards) {
    if (cards.isEmpty) {
      showAdaptiveModalDialog(
        context: context,
        title: 'Supprimer "${currentValue.label}" ?',
        content: const Text('Cette valeur n\'est utilisée par aucune fiche.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              provider.deleteValue(currentValue.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.accentRed),
            child: const Text('Supprimer'),
          ),
        ],
      );
      return;
    }

    showAdaptiveModalDialog(
      context: context,
      title: 'Supprimer "${currentValue.label}" ?',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${currentValue.label}" est utilisée dans ${cards.length} fiche${cards.length > 1 ? 's' : ''}.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          _DeleteOptionTile(
            icon: Icons.delete_sweep,
            color: AppColors.accentRed,
            title: 'Option 1 — Supprimer partout',
            description:
                'Supprimer la valeur et supprimer également la liaison analytique dans les ${cards.length} fiches.',
          ),
          const SizedBox(height: AppSpacing.sm),
          _DeleteOptionTile(
            icon: Icons.link_off,
            color: AppColors.accentOrange,
            title: 'Option 2 — Retirer du référentiel',
            description:
                'Supprimer uniquement du référentiel analytique. Les fiches conservent la donnée texte mais perdent la liaison.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        OutlinedButton(
          onPressed: () async {
            await provider.deleteValueWithOption(
                currentValue, ValueDeletionOption.unlinkOnly);
            if (context.mounted) {
              Navigator.pop(context);
              Navigator.pop(context);
            }
          },
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentOrange),
          child: const Text('Option 2'),
        ),
        FilledButton(
          onPressed: () async {
            await provider.deleteValueWithOption(
                currentValue, ValueDeletionOption.removeFromAll);
            if (context.mounted) {
              Navigator.pop(context);
              Navigator.pop(context);
            }
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.accentRed),
          child: const Text('Option 1'),
        ),
      ],
    );
  }
}

class _DeleteOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  const _DeleteOptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600, color: color)),
              Text(description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textTertiary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textTertiary)),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final CardModel card;
  const _CardTile({required this.card});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        card.type == CardType.document
            ? Icons.description_outlined
            : card.type == CardType.event
                ? Icons.event_outlined
                : Icons.info_outline,
        size: 18,
        color: AppColors.textTertiary,
      ),
      title: Text(card.title,
          style: Theme.of(context).textTheme.bodySmall),
      subtitle: card.date != null
          ? Text(
              '${card.date!.day}/${card.date!.month}/${card.date!.year}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textTertiary, fontSize: 10))
          : null,
      trailing: const Icon(Icons.chevron_right, size: 16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CardDetailScreen(cardId: card.id),
          ),
        );
      },
    );
  }
}
