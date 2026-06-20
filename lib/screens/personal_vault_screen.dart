import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/entity.dart';
import '../models/entity_type.dart';
import '../models/relation_type.dart';
import '../models/entity_attribute.dart';
import '../models/analytical_field.dart';
import '../models/user_profile.dart';
import '../services/cloud_repository.dart';
import '../providers/user_profile_provider.dart';
import '../providers/entity_provider.dart';
import '../providers/entity_type_provider.dart';
import '../providers/relation_provider.dart';
import '../providers/relation_type_provider.dart';
import '../providers/entity_attribute_provider.dart';
import '../providers/analytical_field_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass_card.dart';
import 'entity_detail_screen.dart';
import 'settings_screen.dart';

class PersonalVaultScreen extends StatefulWidget {
  const PersonalVaultScreen({super.key});

  @override
  State<PersonalVaultScreen> createState() => _PersonalVaultScreenState();
}

class _PersonalVaultScreenState extends State<PersonalVaultScreen> {
  bool _isLoading = true;
  String? _error;

  Entity? _meEntity;
  List<EntityRelationWithEntities> _relations = [];
  List<Entity> _otherEntities = [];
  List<EntityAttributeWithField> _attributes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final entityProvider = context.read<EntityProvider>();
      final userProfileProvider = context.read<UserProfileProvider>();
      final entityTypeProvider = context.read<EntityTypeProvider>();
      final relationTypeProvider = context.read<RelationTypeProvider>();
      final relationProvider = context.read<RelationProvider>();
      final attrProvider = context.read<EntityAttributeProvider>();
      final fieldProvider = context.read<AnalyticalFieldProvider>();

      await Future.wait([
        entityTypeProvider.loadTypes(),
        relationTypeProvider.loadTypes(),
        fieldProvider.loadAll(),
        entityProvider.loadEntities(),
        userProfileProvider.loadProfile(),
      ]);

      final me = await entityProvider.getMeEntity(
        userProfileProvider: userProfileProvider,
        entityTypeProvider: entityTypeProvider,
      );

      if (me == null) {
        setState(() {
          _error = 'Impossible de récupérer l\'entité principale';
          _isLoading = false;
        });
        return;
      }

      _meEntity = me;

      final fields = fieldProvider.fields;

      final results = await Future.wait([
        relationProvider.getAllRelationsWithDetails(me.id),
        attrProvider.getAttributesWithFields(me.id, fields),
      ]);

      _relations = results[0] as List<EntityRelationWithEntities>;
      _attributes = results[1] as List<EntityAttributeWithField>;

      final personTypeId = entityTypeProvider.getTypeByCode('personne')?.id;
      _otherEntities = entityProvider.entities.where((e) =>
        e.id != me.id && (personTypeId == null || e.entityTypeId != personTypeId)
      ).toList();

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
        appBar: AppBar(title: const Text('Mes données personnelles')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mes données personnelles')),
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
    final profile = context.watch<UserProfileProvider>().profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes données personnelles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            _buildIdentityCard(theme, profile),
            const SizedBox(height: AppSpacing.xl),
            _buildRelationsSection(theme),
            const SizedBox(height: AppSpacing.xl),
            _buildOtherEntitiesSection(theme),
            const SizedBox(height: AppSpacing.xl),
            _buildAttributesSection(theme),
            const SizedBox(height: AppSpacing.huge),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityCard(ThemeData theme, UserProfile? profile) {
    final initials = _getInitials(profile);
    final fullName = profile?.fullName ?? 'Moi';

    final totalRelations = _relations.length;
    final totalAttributes = _attributes.length;
    final totalEntities = _otherEntities.length + 1;

    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                child: Text(
                  initials,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (profile?.birthDate != null)
                      Text(
                        DateFormat('dd MMMM yyyy', 'fr_FR').format(profile!.birthDate!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    if (profile?.phone != null)
                      Text(
                        profile!.phone!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                tooltip: 'Modifier mon identité',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _StatItem(
                icon: Icons.link,
                value: totalEntities.toString(),
                label: 'entités',
              ),
              _StatItem(
                icon: Icons.people_outline,
                value: totalRelations.toString(),
                label: 'relations',
              ),
              _StatItem(
                icon: Icons.label_outline,
                value: totalAttributes.toString(),
                label: 'attributs',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getInitials(UserProfile? profile) {
    if (profile == null) return 'M';
    final first = profile.firstName?.isNotEmpty == true
        ? profile.firstName![0].toUpperCase()
        : '';
    final last = profile.lastName?.isNotEmpty == true
        ? profile.lastName![0].toUpperCase()
        : '';
    if (first.isEmpty && last.isEmpty) return 'M';
    return '$first$last';
  }

  Widget _buildRelationsSection(ThemeData theme) {
    if (_meEntity == null) return const SizedBox.shrink();
    final outgoing = _relations.where((r) => r.isOutgoing).toList();

    final byType = <String, List<EntityRelationWithEntities>>{};
    for (final r in outgoing) {
      byType.putIfAbsent(r.relationType.label, () => []).add(r);
    }

    final totalRelations = outgoing.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassSectionHeader(
          title: 'Relations ($totalRelations)',
        ),
        const SizedBox(height: AppSpacing.md),
        if (outgoing.isEmpty)
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
                    const SizedBox(height: AppSpacing.xs),
                    Text('Ajoutez des proches pour les retrouver rapidement',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              ),
            ),
          )
        else
          ...byType.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(entry.key,
                            style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('${entry.value.length}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...entry.value.map((r) {
                      final target = r.targetEntity;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EntityDetailScreen(entityId: target.id),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xs, horizontal: 4),
                            child: Row(
                              children: [
                                Icon(Icons.person_outline, size: 18,
                                    color: AppColors.textSecondary),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(target.label,
                                      style: theme.textTheme.bodyMedium),
                                ),
                                Icon(Icons.chevron_right, size: 16,
                                    color: AppColors.textTertiary),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showAddRelationSheet(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Ajouter une relation'),
          ),
        ),
      ],
    );
  }

  Widget _buildOtherEntitiesSection(ThemeData theme) {
    if (_meEntity == null) return const SizedBox.shrink();
    final entityTypeProvider = context.read<EntityTypeProvider>();

    final byType = <EntityType, List<Entity>>{};
    for (final e in _otherEntities) {
      final type = entityTypeProvider.getTypeById(e.entityTypeId ?? '');
      if (type != null) {
        byType.putIfAbsent(type, () => []).add(e);
      } else {
        byType.putIfAbsent(EntityType(id: '', code: 'unknown', label: 'Autre'), () => []).add(e);
      }
    }

    final totalOther = _otherEntities.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassSectionHeader(
          title: 'Autres entités ($totalOther)',
        ),
        const SizedBox(height: AppSpacing.md),
        if (byType.isEmpty)
          GlassCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textTertiary),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Aucune autre entité',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary)),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Ajoutez des biens, contrats ou lieux',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              ),
            ),
          )
        else
          ...byType.entries.map((entry) {
            final type = entry.key;
            final icon = _iconForEntityType(type.icon);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 18, color: AppColors.primaryBlue),
                        const SizedBox(width: AppSpacing.sm),
                        Text(type.label,
                            style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('${entry.value.length}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...entry.value.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EntityDetailScreen(entityId: e.id),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xs, horizontal: 4),
                            child: Row(
                              children: [
                                Icon(icon, size: 18, color: AppColors.textSecondary),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(e.label,
                                      style: theme.textTheme.bodyMedium),
                                ),
                                Icon(Icons.chevron_right, size: 16,
                                    color: AppColors.textTertiary),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showAddEntitySheet(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Ajouter une entité'),
          ),
        ),
      ],
    );
  }

  Widget _buildAttributesSection(ThemeData theme) {
    if (_meEntity == null) return const SizedBox.shrink();

    final totalAttributes = _attributes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassSectionHeader(
          title: 'Attributs personnels ($totalAttributes)',
        ),
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
                    Text('Aucun attribut personnalisé',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary)),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Ajoutez des informations comme votre NIR, permis, etc.',
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
                    _AttributeRow(
                      field: awf.field,
                      attribute: awf.attribute,
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
            onPressed: () => _showAddAttributeSheet(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Ajouter un attribut'),
          ),
        ),
      ],
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
                      _showCreateEntityForRelation(type);
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

  void _showCreateEntityForRelation(RelationType relationType) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: Text('Ajouter un(e) ${relationType.label.toLowerCase()}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nom',
            hintText: 'Ex: Jean',
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
              final label = controller.text.trim();
              if (label.isEmpty) return;
              Navigator.pop(ctx);

              final entityProvider = context.read<EntityProvider>();
              final userProfileProvider = context.read<UserProfileProvider>();
              final entityTypeProvider = context.read<EntityTypeProvider>();
              final relationProvider = context.read<RelationProvider>();

              final me = await entityProvider.getMeEntity(
                userProfileProvider: userProfileProvider,
                entityTypeProvider: entityTypeProvider,
              );
              if (me == null || !mounted) return;

              final personTypeId = entityTypeProvider.getTypeByCode('personne')?.id;
              if (personTypeId == null) return;

              final entity = await entityProvider.createEntity(
                entityTypeId: personTypeId,
                label: label,
              );

              await relationProvider.createRelation(
                sourceEntityId: me.id,
                targetEntityId: entity.id,
                relationTypeId: relationType.id,
              );

              if (mounted) _loadData();
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showAddEntitySheet() {
    final entityTypeProvider = context.read<EntityTypeProvider>();
    final types = entityTypeProvider.types
        .where((t) => t.code != 'personne')
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('Ajouter une entité',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView(
                shrinkWrap: true,
                children: types.map((type) {
                  return ListTile(
                    leading: Icon(_iconForEntityType(type.icon)),
                    title: Text(type.label),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCreateEntityOfType(type);
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

  void _showCreateEntityOfType(EntityType entityType) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: Text('Ajouter ${entityType.label.toLowerCase()}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Libellé',
            hintText: 'Ex: ${entityType.label}',
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
              final label = controller.text.trim();
              if (label.isEmpty) return;
              Navigator.pop(ctx);

              final entityProvider = context.read<EntityProvider>();

              await entityProvider.createEntity(
                entityTypeId: entityType.id,
                label: label,
              );

              if (mounted) _loadData();
            },
            child: const Text('Ajouter'),
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
                        ? Text('Donnée sensible', style: TextStyle(fontSize: 12, color: AppColors.accentOrange))
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
        title: Text('${field.name}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
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

              final attrProvider = context.read<EntityAttributeProvider>();
              final entityProvider = context.read<EntityProvider>();
              final userProfileProvider = context.read<UserProfileProvider>();
              final entityTypeProvider = context.read<EntityTypeProvider>();

              final me = await entityProvider.getMeEntity(
                userProfileProvider: userProfileProvider,
                entityTypeProvider: entityTypeProvider,
              );
              if (me == null || !mounted) return;

              await attrProvider.createAttribute(
                entityId: me.id,
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

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttributeRow extends StatefulWidget {
  final AnalyticalField field;
  final EntityAttribute attribute;

  const _AttributeRow({
    required this.field,
    required this.attribute,
  });

  @override
  State<_AttributeRow> createState() => _AttributeRowState();
}

class _AttributeRowState extends State<_AttributeRow> {
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _obscured = widget.field.isSensitive;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = widget.attribute.attributeValue;
    final displayValue = _obscured ? _maskValue(value) : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            widget.field.isSensitive ? Icons.lock_outline : Icons.label_outline,
            size: 16,
            color: widget.field.isSensitive ? AppColors.accentOrange : AppColors.primaryBlue,
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
          if (widget.field.isSensitive)
            IconButton(
              icon: Icon(
                _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 18,
                color: AppColors.textTertiary,
              ),
              onPressed: () => setState(() => _obscured = !_obscured),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  String _maskValue(String value) {
    if (value.length <= 4) return '●' * value.length;
    final visible = value.substring(value.length - 4);
    final masked = '●' * (value.length - 4);
    return '$masked$visible';
  }
}

class GlassSectionHeader extends StatelessWidget {
  final String title;

  const GlassSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }
}
