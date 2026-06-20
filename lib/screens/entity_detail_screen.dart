import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/entity.dart';
import '../models/entity_type.dart';
import '../models/entity_attribute.dart';
import '../models/analytical_field.dart';
import '../models/relation_type.dart';
import '../services/cloud_repository.dart';
import '../providers/entity_provider.dart';
import '../providers/entity_type_provider.dart';
import '../providers/relation_provider.dart';
import '../providers/relation_type_provider.dart';
import '../providers/entity_attribute_provider.dart';
import '../providers/analytical_field_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass_card.dart';

class EntityDetailScreen extends StatefulWidget {
  final String entityId;

  const EntityDetailScreen({super.key, required this.entityId});

  @override
  State<EntityDetailScreen> createState() => _EntityDetailScreenState();
}

class _EntityDetailScreenState extends State<EntityDetailScreen> {
  bool _isLoading = true;
  String? _error;

  Entity? _entity;
  EntityType? _entityType;
  List<EntityAttributeWithField> _attributes = [];
  List<EntityRelationWithEntities> _outgoingRelations = [];
  List<EntityRelationWithEntities> _incomingRelations = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final entityProvider = context.read<EntityProvider>();
      final entityTypeProvider = context.read<EntityTypeProvider>();
      final relationProvider = context.read<RelationProvider>();
      final fieldProvider = context.read<AnalyticalFieldProvider>();
      final attrProvider = context.read<EntityAttributeProvider>();

      await Future.wait([
        entityTypeProvider.loadTypes(),
        entityProvider.loadEntities(),
        fieldProvider.loadAll(),
      ]);

      final entity = await entityProvider.getEntityById(widget.entityId);
      if (entity == null) {
        setState(() {
          _error = 'Entité introuvable';
          _isLoading = false;
        });
        return;
      }

      _entity = entity;
      _entityType = entityTypeProvider.getTypeById(entity.entityTypeId ?? '');

      final fields = fieldProvider.fields;

      final results = await Future.wait([
        relationProvider.getAllRelationsWithDetails(entity.id),
        attrProvider.getAttributesWithFields(entity.id, fields),
      ]);

      final allRelations = results[0] as List<EntityRelationWithEntities>;
      _outgoingRelations = allRelations.where((r) => r.isOutgoing).toList();
      _incomingRelations = allRelations.where((r) => !r.isOutgoing).toList();
      _attributes = results[1] as List<EntityAttributeWithField>;

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détail')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détail')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.accentRed),
              const SizedBox(height: AppSpacing.md),
              Text('Erreur', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final entity = _entity!;

    return Scaffold(
      appBar: AppBar(
        title: Text(entity.label),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: _showEditLabelDialog,
            tooltip: 'Renommer',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            _buildHeader(theme, entity),
            const SizedBox(height: AppSpacing.xl),
            _buildAttributesSection(theme),
            const SizedBox(height: AppSpacing.xl),
            _buildRelationsSection(theme),
            const SizedBox(height: AppSpacing.huge),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Entity entity) {
    final icon = _iconForEntityType(_entityType?.icon);
    final typeLabel = _entityType?.label ?? 'Entité';

    return GlassCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.2),
            child: Icon(icon, color: AppColors.primaryBlue, size: 28),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entity.label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  typeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassSectionHeader(title: 'Attributs (${_attributes.length})'),
        const SizedBox(height: AppSpacing.md),
        if (_attributes.isEmpty)
          GlassCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Column(
                  children: [
                    Icon(Icons.label_outline, size: 40, color: AppColors.textTertiary),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Aucun attribut',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              ),
            ),
          )
        else
          GlassCard(
            child: Column(
              children: _attributes.map((awf) {
                return Column(
                  children: [
                    if (awf != _attributes.first)
                      const Divider(height: 1),
                    _AttributeDetailRow(
                      field: awf.field,
                      attribute: awf.attribute,
                      onEdit: () => _showEditAttributeDialog(awf),
                      onDelete: () => _showDeleteAttributeDialog(awf),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showAddAttributeSheet,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Ajouter un attribut'),
          ),
        ),
      ],
    );
  }

  Widget _buildRelationsSection(ThemeData theme) {
    final outgoing = _outgoingRelations;
    final incoming = _incomingRelations;
    final total = outgoing.length + incoming.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassSectionHeader(title: 'Relations ($total)'),
        const SizedBox(height: AppSpacing.md),
        if (outgoing.isEmpty && incoming.isEmpty)
          GlassCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 40, color: AppColors.textTertiary),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Aucune relation',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              ),
            ),
          )
        else ...[
          if (outgoing.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text('Sortantes',
                  style: theme.textTheme.titleSmall?.copyWith(color: AppColors.textSecondary)),
            ),
            ...outgoing.map((r) => _RelationCard(
              relation: r,
              isOutgoing: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EntityDetailScreen(entityId: r.targetEntity.id),
                ),
              ),
              onDelete: () => _showDeleteRelationDialog(r),
            )),
          ],
          if (incoming.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text('Entrantes',
                  style: theme.textTheme.titleSmall?.copyWith(color: AppColors.textSecondary)),
            ),
            ...incoming.map((r) => _RelationCard(
              relation: r,
              isOutgoing: false,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EntityDetailScreen(entityId: r.sourceEntity.id),
                ),
              ),
              onDelete: () => _showDeleteRelationDialog(r),
            )),
          ],
        ],
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showAddRelationSheet,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Ajouter une relation'),
          ),
        ),
      ],
    );
  }

  void _showEditLabelDialog() {
    final controller = TextEditingController(text: _entity!.label);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: const Text('Renommer'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nom'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final newLabel = controller.text.trim();
              if (newLabel.isEmpty || newLabel == _entity!.label) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx);
              await context.read<EntityProvider>().updateEntity(
                _entity!.copyWith(label: newLabel),
              );
              if (mounted) _loadData();
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  void _showEditAttributeDialog(EntityAttributeWithField awf) {
    final isSensitive = awf.field.isSensitive;
    final originalValue = awf.attribute.attributeValue;
    final controller = TextEditingController(
      text: isSensitive ? '' : originalValue,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: Row(
          children: [
            if (isSensitive)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Icon(Icons.lock_outline,
                    size: 18, color: AppColors.accentOrange),
              ),
            Text(awf.field.name),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: isSensitive ? 'Nouvelle valeur' : 'Valeur',
                hintText: isSensitive ? 'Laisser vide pour conserver la valeur actuelle' : null,
              ),
              autofocus: true,
            ),
            if (isSensitive)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Les données sensibles ne sont pas pré-affichées par sécurité.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.accentOrange,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final value = controller.text.trim();
              final newValue = value.isEmpty ? originalValue : value;
              Navigator.pop(ctx);
              await context.read<EntityAttributeProvider>().updateAttribute(
                awf.attribute.copyWith(attributeValue: newValue),
              );
              if (mounted) _loadData();
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAttributeDialog(EntityAttributeWithField awf) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: const Text('Supprimer'),
        content: Text('Supprimer "${awf.field.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<EntityAttributeProvider>().deleteAttribute(awf.attribute.id);
              if (mounted) _loadData();
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showDeleteRelationDialog(EntityRelationWithEntities r) {
    final label = r.isOutgoing ? r.targetEntity.label : r.sourceEntity.label;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: const Text('Supprimer la relation'),
        content: Text('Supprimer la relation "${r.relationType.label}" avec $label ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<RelationProvider>().deleteRelation(r.relation.id);
              if (mounted) _loadData();
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showAddAttributeSheet() {
    final fieldProvider = context.read<AnalyticalFieldProvider>();
    final fields = fieldProvider.fields;

    if (fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun champ disponible. Créez-en dans Paramètres.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('Ajouter un attribut',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView(
                shrinkWrap: true,
                children: fields.map((field) {
                  return ListTile(
                    leading: Icon(
                      field.isSensitive ? Icons.lock_outline : Icons.label_outline,
                      size: 20,
                      color: field.isSensitive ? AppColors.accentOrange : AppColors.primaryBlue,
                    ),
                    title: Text(field.name),
                    subtitle: field.isSensitive
                        ? Text('Donnée sensible',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.accentOrange))
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showSetAttributeValue(field);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetAttributeValue(AnalyticalField field) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: Text(field.name),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Valeur',
            hintText: 'Saisissez la valeur',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(ctx);
              await context.read<EntityAttributeProvider>().createAttribute(
                entityId: widget.entityId,
                fieldId: field.id,
                attributeValue: value,
              );
              if (mounted) _loadData();
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showAddRelationSheet() {
    final relationTypeProvider = context.read<RelationTypeProvider>();
    final types = relationTypeProvider.types;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('Ajouter une relation',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView(
                shrinkWrap: true,
                children: types.map((type) {
                  return ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: Text(type.label),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showSelectTargetEntity(type);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectTargetEntity(RelationType relationType) {
    final entityProvider = context.read<EntityProvider>();
    final entities = entityProvider.entities.where((e) => e.id != widget.entityId).toList();

    if (entities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune autre entité disponible. Créez-en d\'abord.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('Choisir ${relationType.label.toLowerCase()}',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView(
                shrinkWrap: true,
                children: entities.map((target) {
                  return ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(target.label),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await context.read<RelationProvider>().createRelation(
                        sourceEntityId: widget.entityId,
                        targetEntityId: target.id,
                        relationTypeId: relationType.id,
                      );
                      if (mounted) _loadData();
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForEntityType(String? iconCode) {
    switch (iconCode) {
      case 'person': return Icons.person_outline;
      case 'home': return Icons.home_outlined;
      case 'car': return Icons.directions_car_outlined;
      case 'contract': return Icons.description_outlined;
      case 'business': return Icons.business_outlined;
      case 'document': return Icons.article_outlined;
      case 'pet': return Icons.pets_outlined;
      case 'device': return Icons.devices_outlined;
      case 'subscription': return Icons.subscriptions_outlined;
      case 'list': return Icons.list_alt_outlined;
      case 'target': return Icons.track_changes_outlined;
      default: return Icons.circle_outlined;
    }
  }
}

class _AttributeDetailRow extends StatefulWidget {
  final AnalyticalField field;
  final EntityAttribute attribute;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AttributeDetailRow({
    required this.field,
    required this.attribute,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_AttributeDetailRow> createState() => _AttributeDetailRowState();
}

class _AttributeDetailRowState extends State<_AttributeDetailRow> {
  bool _obscured = true;
  Timer? _remaskTimer;

  @override
  void initState() {
    super.initState();
    _obscured = widget.field.isSensitive;
  }

  @override
  void dispose() {
    _remaskTimer?.cancel();
    super.dispose();
  }

  void _toggleVisibility() {
    setState(() => _obscured = !_obscured);
    _remaskTimer?.cancel();
    if (!_obscured) {
      _remaskTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) setState(() => _obscured = true);
      });
    }
  }

  String _maskValue(String value) {
    if (value.length <= 4) return '●' * value.length;
    final visible = value.substring(value.length - 4);
    final masked = '●' * (value.length - 4);
    return '$masked$visible';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSensitive = widget.field.isSensitive;
    final displayValue = _obscured ? _maskValue(widget.attribute.attributeValue) : widget.attribute.attributeValue;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            isSensitive ? Icons.lock_outline : Icons.label_outline,
            size: 16,
            color: isSensitive ? AppColors.accentOrange : AppColors.primaryBlue,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.field.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayValue,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (isSensitive)
            IconButton(
              icon: Icon(
                _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 18,
              ),
              onPressed: _toggleVisibility,
              visualDensity: VisualDensity.compact,
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: widget.onEdit,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: AppColors.accentRed),
            onPressed: widget.onDelete,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _RelationCard extends StatelessWidget {
  final EntityRelationWithEntities relation;
  final bool isOutgoing;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RelationCard({
    required this.relation,
    required this.isOutgoing,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relatedEntity = isOutgoing ? relation.targetEntity : relation.sourceEntity;
    final icon = isOutgoing ? Icons.arrow_forward : Icons.arrow_back;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: GlassCard(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primaryBlue),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        relatedEntity.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        relation.relationType.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 18, color: AppColors.accentRed),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
