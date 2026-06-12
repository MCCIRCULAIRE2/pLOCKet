import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/card_model.dart';
import '../ai/extraction_candidate.dart';
import '../models/draft_card.dart';
import '../models/field_type.dart';
import '../models/typed_field.dart';
import '../models/analytical_field.dart';
import '../providers/card_provider.dart';
import '../providers/analytical_field_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/tag_chip.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class VerificationScreen extends StatefulWidget {
  final DraftCard draft;

  const VerificationScreen({super.key, required this.draft});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  late DraftCard _draft;
  late TextEditingController _titleController;
  bool _isSaving = false;
  bool _rawTextExpanded = false;
  bool _previewExpanded = true;
  static const _internalFields = {'adresse_rue', 'adresse_code_postal', 'adresse_ville'};
  bool _showPanel = false;
  double _panelFraction = 0.38;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
    _titleController = TextEditingController(text: _draft.title);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoDetectEntities();
    });
  }

  void _autoDetectEntities() {
    final afProvider = context.read<AnalyticalFieldProvider>();
    if (afProvider.fields.isEmpty) return;

    final text = _draft.rawText;
    if (text.isEmpty) return;

    debugPrint('[AUTO-DETECT] ═══════════════════════════════════════════════════════════');
    debugPrint('[AUTO-DETECT] Détection automatique d\'entités et identifiants');
    debugPrint('[AUTO-DETECT] ═══════════════════════════════════════════════════════════');

    bool hasChanges = false;

    final entityMatches = afProvider.findMatches(text);
    for (final match in entityMatches) {
      final fieldName = match.field.name;
      if (!_draft.fields.containsKey(fieldName) &&
          !_draft.customFields.containsKey(fieldName)) {
        setState(() {
          _draft.fields[fieldName] = TypedField(
            rawValue: match.value.label,
            type: FieldType.text,
            validatedByUser: false,
            needsReview: match.confidence < 90,
          );
        });
        hasChanges = true;
        debugPrint('[AUTO-DETECT] ✓ Ajout automatique: $fieldName = ${match.value.label}');
      }
    }

    final identifiers = afProvider.detectIdentifiers(text);
    for (final entry in identifiers.entries) {
      if (!_draft.fields.containsKey(entry.key)) {
        final fieldType = entry.key == 'numero_securite_sociale'
            ? FieldType.socialSecurityNumber
            : FieldType.identifier;
        setState(() {
          _draft.fields[entry.key] = TypedField(
            rawValue: entry.value,
            type: fieldType,
            validatedByUser: false,
            needsReview: true,
          );
        });
        hasChanges = true;
        debugPrint('[AUTO-DETECT] ✓ Ajout identifiant: ${entry.key} = ${entry.value}');
      }
    }

    if (hasChanges) {
      setState(() {
        _draft.validate();
      });
    }

    debugPrint('[AUTO-DETECT] ═══════════════════════════════════════════════════════════');
    debugPrint('[AUTO-DETECT] Fin détection — $hasChanges changement(s)');
    debugPrint('[AUTO-DETECT] ═══════════════════════════════════════════════════════════');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _typeLabel() {
    switch (_draft.type) {
      case CardType.event: return 'Événement';
      case CardType.document: return 'Document';
      case CardType.information: return 'Information';
    }
  }

  Color _typeColor() {
    switch (_draft.type) {
      case CardType.document: return AppColors.documentColor;
      case CardType.event: return AppColors.eventColor;
      case CardType.information: return AppColors.infoColor;
    }
  }

  bool get _isImage {
    if (_draft.sourceFileExtension == null) return false;
    return ['jpg', 'jpeg', 'png', 'heic', 'webp', 'gif', 'bmp']
        .contains(_draft.sourceFileExtension!.toLowerCase());
  }

  void _removeField(String key, {bool isCustom = false}) {
    setState(() {
      if (isCustom) {
        _draft.customFields.remove(key);
      } else {
        _draft.fields.remove(key);
      }
      _draft.validate();
    });
  }

  void _editField(String key, String currentValue, FieldType currentType,
      {bool isCustom = false, List<ExtractionCandidate> alternatives = const []}) {
    final controller = TextEditingController(text: currentValue);
    FieldType selectedType = currentType;
    bool showCandidates = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final theme = Theme.of(ctx);
          return AlertDialog(
            title: Text('Modifier $key'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(labelText: 'Valeur'),
                            autofocus: true,
                          ),
                        ),
                        if (alternatives.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              showCandidates ? Icons.expand_less : Icons.expand_more,
                              color: AppColors.primaryBlue,
                            ),
                            onPressed: () => setDialogState(() => showCandidates = !showCandidates),
                            tooltip: 'Suggestions OCR',
                          ),
                        ],
                      ],
                    ),
                    if (showCandidates && alternatives.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        width: double.maxFinite,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                              child: Text('Suggestions OCR',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
                            ),
                            ...alternatives.map((c) {
                              final isCurrent = c.value == controller.text;
                              return InkWell(
                                onTap: () {
                                  controller.text = c.value;
                                  setDialogState(() => showCandidates = false);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isCurrent ? AppColors.primaryBlue.withValues(alpha: 0.08) : null,
                                    border: Border(
                                      bottom: BorderSide(
                                          color: AppColors.borderLight.withValues(alpha: 0.5), width: 0.5),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(c.value,
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w600)),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: c.score >= 80
                                                  ? AppColors.accentGreen.withValues(alpha: 0.15)
                                                  : c.score >= 40
                                                      ? AppColors.accentOrange.withValues(alpha: 0.15)
                                                      : AppColors.accentRed.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text('${c.score} %',
                                                style: theme.textTheme.labelSmall?.copyWith(
                                                  color: c.score >= 80
                                                      ? AppColors.accentGreen
                                                      : c.score >= 40
                                                          ? AppColors.accentOrange
                                                          : AppColors.accentRed,
                                                  fontWeight: FontWeight.w600,
                                                )),
                                          ),
                                        ],
                                      ),
                                      if (c.sourceLine.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text('"${c.sourceLine}"',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                                color: AppColors.textTertiary, fontStyle: FontStyle.italic),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Text('Type', style: theme.textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<FieldType>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: FieldType.values.map((t) => DropdownMenuItem(
                        value: t,
                        child: Row(
                          children: [
                            Icon(t.icon, size: 16, color: t.color),
                            const SizedBox(width: 8),
                            Text(t.displayName),
                          ],
                        ),
                      )).toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedType = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    final typed = TypedField(
                      rawValue: controller.text,
                      type: selectedType,
                      validatedByUser: true,
                    );
                    if (isCustom) {
                      _draft.customFields[key] = typed;
                    } else {
                      _draft.fields[key] = typed;
                    }
                    _draft.validate();
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Valider'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addField({bool custom = false}) {
    final afProvider = context.read<AnalyticalFieldProvider>();
    final analyticalFields = afProvider.fields;

    if (analyticalFields.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                child: Text('Ajouter un champ',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              ...analyticalFields.map((af) => ListTile(
                    leading: Icon(Icons.label_outline,
                        color: AppColors.primaryBlue),
                    title: Text(af.name),
                    subtitle: Text(
                        '${afProvider.valuesForField(af.id).length} valeur(s)',
                        style: TextStyle(fontSize: 12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAnalyticalFieldPicker(af, custom: custom);
                    },
                  )),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Créer un nouveau champ'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFreeFieldDialog(custom: custom);
                },
              ),
            ],
          ),
        ),
      );
    } else {
      _showFreeFieldDialog(custom: custom);
    }
  }

  void _showAnalyticalFieldPicker(AnalyticalField field,
      {bool custom = false}) {
    final afProvider = context.read<AnalyticalFieldProvider>();
    final values = afProvider.valuesForField(field.id);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
              child: Text('Choisir ${field.name}',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...values.map((v) => ListTile(
                        title: Text(v.label),
                        subtitle: v.aliases.isNotEmpty
                            ? Text('Alias: ${v.aliases.join(", ")}',
                                style: const TextStyle(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            final typed = TypedField(
                              rawValue: v.label,
                              type: FieldType.text,
                              validatedByUser: true,
                            );
                            if (custom) {
                              _draft.customFields[field.name] = typed;
                            } else {
                              _draft.fields[field.name] = typed;
                            }
                            _draft.validate();
                          });
                        },
                      )),
                  ListTile(
                    leading: Icon(Icons.add, color: AppColors.accentGreen),
                    title: Text('+ Nouvelle valeur',
                        style: TextStyle(color: AppColors.accentGreen)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAddAnalyticalValueDialog(field, custom: custom);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAnalyticalValueDialog(AnalyticalField field,
      {bool custom = false}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nouvelle valeur pour "${field.name}"'),
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
              final label = controller.text.trim();
              if (label.isNotEmpty) {
                final afProvider =
                    context.read<AnalyticalFieldProvider>();
                final newValue = await afProvider.addValue(
                  fieldId: field.id,
                  label: label,
                );
                if (mounted) {
                  setState(() {
                    final typed = TypedField(
                      rawValue: newValue.label,
                      type: FieldType.text,
                      validatedByUser: true,
                    );
                    if (custom) {
                      _draft.customFields[field.name] = typed;
                    } else {
                      _draft.fields[field.name] = typed;
                    }
                    _draft.validate();
                  });
                  Navigator.pop(ctx);
                }
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _showFreeFieldDialog({bool custom = false}) {
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    FieldType selectedType = FieldType.text;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(custom ? 'Ajouter un champ personnalisé' : 'Ajouter un champ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyController,
                decoration: const InputDecoration(labelText: 'Nom du champ'),
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(labelText: 'Valeur'),
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<FieldType>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: FieldType.values.map((t) => DropdownMenuItem(
                  value: t,
                  child: Row(
                    children: [
                      Icon(t.icon, size: 16, color: t.color),
                      const SizedBox(width: 8),
                      Text(t.displayName),
                    ],
                  ),
                )).toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedType = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final k = keyController.text.trim();
                final v = valueController.text.trim();
                if (k.isNotEmpty && v.isNotEmpty) {
                  setState(() {
                    final typed = TypedField(rawValue: v, type: selectedType);
                    if (custom) {
                      _draft.customFields[k] = typed;
                    } else {
                      _draft.fields[k] = typed;
                    }
                    _draft.validate();
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  void _removeTag(String tag) {
    setState(() => _draft.tags.remove(tag));
  }

  void _addTag() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter un tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nom du tag'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final tag = controller.text.trim().toLowerCase();
              if (tag.isNotEmpty && !_draft.tags.contains(tag)) {
                setState(() => _draft.tags.add(tag));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    debugPrint('[SAVE] Début sauvegarde');
    setState(() => _isSaving = true);
    _draft.title = _titleController.text.trim();

    debugPrint('[SAVE] Sauvegarde fiche');
    debugPrint('[SAVE] Champs extraits: ${_draft.fields.length}');
    debugPrint('[SAVE] Champs personnalisés: ${_draft.customFields.length}');
    debugPrint('[SAVE] Étiquettes: ${_draft.tags.length}');
    debugPrint('[SAVE] Document lié: ${_draft.filePath ?? "aucun"}');
    debugPrint('[SAVE] Alertes: ${_draft.warnings.length} (non bloquantes)');
    debugPrint('[SAVE] Titre: ${_draft.title}');

    final provider = context.read<CardProvider>();
    final card = await provider.finalizeCard(_draft);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (card != null) {
      debugPrint('[SAVE] Succès sauvegarde (id: ${card.id})');
      debugPrint('[SAVE] Fin sauvegarde');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fiche enregistrée avec succès')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      final err = provider.error ?? 'Erreur inconnue lors de la sauvegarde';
      debugPrint('[SAVE] Erreur sauvegarde: $err');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _cancel() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler'),
        content: const Text('Les modifications seront perdues.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continuer'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancel,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: SizedBox(
              height: 36,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(_isSaving ? '...' : 'Enregistrer'),
              ),
            ),
          ),
        ],
      ),
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;

          if (isWide && _showPanel) {
            return _buildWideLayout(theme, constraints);
          }

          return _buildNarrowLayout(theme, constraints);
        },
      ),
    );
  }

  // ─── Wide: form + side panel ──────────────────────────────────────
  Widget _buildWideLayout(ThemeData theme, BoxConstraints constraints) {
    final panelMin = constraints.maxWidth * 0.25;
    final panelMax = constraints.maxWidth * 0.60;
    final panelWidth = (_panelFraction * constraints.maxWidth).clamp(panelMin, panelMax);
    final formWidth = constraints.maxWidth - panelWidth - 8;

    return Row(
      children: [
        SizedBox(width: formWidth, child: _buildFormList(theme)),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            setState(() {
              final delta = -details.delta.dx / constraints.maxWidth;
              _panelFraction = (_panelFraction + delta).clamp(0.25, 0.60);
            });
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: Container(
              width: 8,
              color: AppColors.border,
              child: Center(
                child: Container(
                  width: 3, height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: panelWidth, child: _buildDocPanel(theme)),
      ],
    );
  }

  Widget _buildDocPanel(ThemeData theme) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: theme.scaffoldBackgroundColor,
            child: Row(
              children: [
                Text('Document source', style: theme.textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _showPanel = false),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Expanded(child: _buildDocumentContent()),
        ],
      ),
    );
  }

  Widget _buildDocumentContent() {
    if (_draft.sourceBytes == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined, size: 48, color: Colors.white54),
            SizedBox(height: 12),
            Text("Document source non disponible",
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_isImage) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 6.0,
        child: Center(
          child: Image.memory(_draft.sourceBytes!, fit: BoxFit.contain),
        ),
      );
    }

    return SfPdfViewer.memory(_draft.sourceBytes!);
  }

  // ─── Narrow: form only ────────────────────────────────────────────
  Widget _buildNarrowLayout(ThemeData theme, BoxConstraints constraints) {
    final innerPadding = constraints.maxWidth > 600
        ? constraints.maxWidth > 900 ? AppSpacing.big : AppSpacing.xxl
        : AppSpacing.lg;

    return ListView(
      padding: EdgeInsets.fromLTRB(innerPadding, innerPadding, innerPadding, innerPadding + 32),
      children: _buildFormChildren(theme, constraints, innerPadding),
    );
  }

  // ─── Form list (used in both narrow and wide) ─────────────────────
  Widget _buildFormList(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.big, AppSpacing.big, AppSpacing.big, AppSpacing.big + 32),
      children: _buildFormChildren(theme, BoxConstraints(), AppSpacing.big),
    );
  }

  List<Widget> _buildFormChildren(ThemeData theme, BoxConstraints constraints, double innerPadding) {
    final isWide = constraints.maxWidth > 900;

    return [
      // ── Preview + Summary row (wide) / column (narrow) ──
      if (constraints.maxWidth > 600)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildPreviewSection(theme)),
            const SizedBox(width: AppSpacing.lg),
            Expanded(flex: 2, child: _buildSummaryCard(theme)),
          ],
        )
      else ...[
        _buildPreviewSection(theme),
        const SizedBox(height: AppSpacing.lg),
        _buildSummaryCard(theme),
      ],
      const SizedBox(height: AppSpacing.xxl),

      // ── Validation Warnings ──
      if (_draft.warnings.isNotEmpty) ...[
        _buildWarningsSection(theme),
        const SizedBox(height: AppSpacing.xxl),
      ],

      // ── Suggested Fields ──
      if (_draft.suggestedFields.isNotEmpty) ...[
        _buildSuggestedFieldsSection(theme),
        const SizedBox(height: AppSpacing.xxl),
      ],

      // ── Title ──
      _sectionHeader(theme, 'TITRE'),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        controller: _titleController,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: AppSpacing.xxl),

      // ── Fields + Custom Fields in grid (wide) / column (narrow) ──
      if (isWide)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildFieldsSection(theme)),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: _buildCustomFieldsSection(theme)),
          ],
        )
      else ...[
        _buildFieldsSection(theme),
        const SizedBox(height: AppSpacing.xxl),
        _buildCustomFieldsSection(theme),
      ],
      const SizedBox(height: AppSpacing.xxl),

      // ── Tags ──
      _buildTagsSection(theme),
      const SizedBox(height: AppSpacing.xxl),

      // ── Raw text (collapsible) ──
      _buildRawTextSection(theme),
      const SizedBox(height: AppSpacing.xxxl),

      // ── Save button ──
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined, size: 20),
          label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer la fiche'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    ];
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Row(
      children: [
        Container(width: 3, height: 16,
          decoration: BoxDecoration(
            color: _typeColor(),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleSmall),
      ],
    );
  }

  // ─── Document viewer (narrow: dialog; wide: panel) ────────────────
  void _openDocumentViewer() {
    if (_draft.sourceBytes == null) {
      _showUnavailable();
      return;
    }

    debugPrint('[PREVIEW] Ouverture document');
    debugPrint('[PREVIEW] Type : ${_isImage ? "IMAGE" : "PDF"}');
    debugPrint('[PREVIEW] Chemin fichier : ${_draft.filePath ?? "mémoire"}');

    final contextWidth = MediaQuery.of(context).size.width;

    if (contextWidth > 900) {
      debugPrint('[PREVIEW] Ouvre le panneau latéral');
      setState(() => _showPanel = !_showPanel);
      if (_showPanel) debugPrint('[PREVIEW] Succès ouverture');
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              _buildDocumentContent(),
              Positioned(
                top: 16, right: 16,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: const CircleBorder(),
                  elevation: 6,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 48, height: 48,
                      child: Icon(Icons.close, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      debugPrint('[PREVIEW] Succès ouverture');
    } catch (e) {
      debugPrint('[PREVIEW] Erreur ouverture : $e');
      _showUnavailable();
    }
  }

  void _showUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Impossible d'ouvrir le document source."),
      ),
    );
  }

  // ─── Preview section ──────────────────────────────────────────────
  Widget _buildPreviewSection(ThemeData theme) {
    if (_draft.sourceBytes != null && _isImage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            onTap: _openDocumentViewer,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.image_outlined, size: 16, color: _typeColor()),
                  const SizedBox(width: 8),
                  Text('APERÇU DU DOCUMENT', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  Icon(Icons.open_in_new, size: 16, color: AppColors.textTertiary),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(_previewExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
                    onPressed: () => setState(() => _previewExpanded = !_previewExpanded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_previewExpanded)
            GlassCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.memory(
                    _draft.sourceBytes!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    if (_draft.sourceFileName != null) {
      return GlassCard(
        child: ListTile(
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              _draft.sourceFileExtension == 'pdf' ? Icons.picture_as_pdf : Icons.image,
              color: AppColors.primaryBlue, size: 22,
            ),
          ),
          title: Text(_draft.sourceFileName!, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          subtitle: Text('Document source', style: theme.textTheme.bodySmall),
          trailing: Icon(Icons.open_in_new, size: 18, color: AppColors.textTertiary),
          onTap: _openDocumentViewer,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ─── Summary card ─────────────────────────────────────────────────
  Widget _buildSummaryCard(ThemeData theme) {
    final color = _typeColor();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                ),
                child: Text(_typeLabel(), style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600,
                )),
              ),
              const Spacer(),
              Text(_draft.subType, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _statRow('Champs extraits', _draft.fieldCount.toString(), AppColors.primaryBlue.withValues(alpha: 0.7)),
          const SizedBox(height: AppSpacing.sm),
          _statRow('Champs personnalisés', _draft.customFieldCount.toString(), AppColors.accentGreen.withValues(alpha: 0.7)),
          const SizedBox(height: AppSpacing.sm),
          _statRow('Étiquettes', _draft.tags.length.toString(), AppColors.accentOrange.withValues(alpha: 0.7)),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }

  // ─── Warnings ─────────────────────────────────────────────────────
  Widget _buildWarningsSection(ThemeData theme) {
    final hasErrors = _draft.warnings.any((w) => w.severity == ValidationSeverity.error);
    final hasWarnings = _draft.warnings.any((w) => w.severity == ValidationSeverity.warning);
    
    Color sectionColor;
    IconData sectionIcon;
    String sectionTitle;
    
    if (hasErrors) {
      sectionColor = AppColors.accentRed;
      sectionIcon = Icons.error_outline;
      sectionTitle = 'Erreurs détectées';
    } else if (hasWarnings) {
      sectionColor = AppColors.accentOrange;
      sectionIcon = Icons.warning_amber_rounded;
      sectionTitle = 'Avertissements';
    } else {
      sectionColor = AppColors.primaryBlue;
      sectionIcon = Icons.info_outline;
      sectionTitle = 'Informations';
    }

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: sectionColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: sectionColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(sectionIcon, size: 18, color: sectionColor),
              const SizedBox(width: 8),
              Text(sectionTitle, style: theme.textTheme.titleMedium?.copyWith(
                color: sectionColor,
              )),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ..._draft.warnings.map((w) {
            Color iconColor;
            IconData icon;
            Color textColor;
            
            switch (w.severity) {
              case ValidationSeverity.error:
                iconColor = AppColors.accentRed;
                icon = Icons.error_outline;
                textColor = AppColors.accentRed;
                break;
              case ValidationSeverity.warning:
                iconColor = AppColors.accentOrange;
                icon = Icons.warning_amber_rounded;
                textColor = AppColors.accentOrange;
                break;
              case ValidationSeverity.info:
                iconColor = AppColors.primaryBlue;
                icon = Icons.info_outline;
                textColor = AppColors.primaryBlue;
                break;
            }
            
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                        children: [
                          TextSpan(
                            text: '${w.fieldKey} : ',
                            style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                          ),
                          TextSpan(
                            text: w.message,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Suggested Fields ─────────────────────────────────────────────
  Widget _buildSuggestedFieldsSection(ThemeData theme) {
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.accentOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: AppColors.accentOrange),
              const SizedBox(width: 8),
              Text('Informations suggérées', style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.accentOrange,
              )),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ces informations seraient utiles mais n\'ont pas été détectées dans le texte.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._draft.suggestedFields.map((field) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Icon(Icons.add_circle_outline, size: 16, color: AppColors.accentOrange),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    field,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addSuggestedField(field),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Ajouter'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  void _addSuggestedField(String fieldName) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ajouter $fieldName'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Valeur de $fieldName',
            hintText: 'Saisissez la valeur...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                setState(() {
                  _draft.customFields[fieldName] = TypedField(
                    rawValue: value,
                    type: FieldType.text,
                  );
                  _draft.suggestedFields.remove(fieldName);
                  _draft.validate();
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  // ─── Fields ──────────────────────────────────────────────────────
  Widget _buildFieldsSection(ThemeData theme) {
    final visible = _draft.fields.entries
        .where((e) => !_internalFields.contains(e.key))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionHeader(theme, 'CHAMPS EXTRAITS'),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _addField(custom: false),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ajouter'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(child: Text('Aucun champ extrait', style: theme.textTheme.bodySmall)),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: visible.map((e) => _fieldRow(theme, e.key, e.value, e == visible.last, false)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCustomFieldsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionHeader(theme, 'CHAMPS PERSONNALISÉS'),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _addField(custom: true),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ajouter'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_draft.customFields.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(child: Text('Ajoutez des champs personnalisés au besoin', style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
            ))),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: _draft.customFields.entries.map((e) => _fieldRow(theme, e.key, e.value, e == _draft.customFields.entries.last, true)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _fieldRow(ThemeData theme, String key, TypedField field, bool isLast, bool isCustom) {
    final ambiguous = _draft.isFieldAmbiguous(key);
    final validated = field.validatedByUser;
    final alternatives = _draft.getAlternativesFor(key);
    final hasAlternatives = alternatives.length >= 2;

    Color? bgColor;
    Color? borderColor;
    Color? leftBorderColor;
    if (ambiguous) {
      bgColor = AppColors.accentRed.withValues(alpha: 0.06);
      borderColor = AppColors.accentRed.withValues(alpha: 0.2);
      leftBorderColor = AppColors.accentRed.withValues(alpha: 0.5);
    } else if (validated) {
      bgColor = AppColors.accentGreen.withValues(alpha: 0.06);
      borderColor = AppColors.accentGreen.withValues(alpha: 0.2);
      leftBorderColor = AppColors.accentGreen.withValues(alpha: 0.5);
    }

    return Container(
      padding: AppSpacing.fieldPadding,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: borderColor ?? AppColors.borderLight, width: 0.5),
          left: leftBorderColor != null
              ? BorderSide(color: leftBorderColor, width: 3)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: ambiguous && hasAlternatives
                  ? () => _showCandidatePicker(key, field, alternatives)
                  : null,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  if (ambiguous)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.accentRed),
                    )
                  else if (validated)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.check_circle, size: 18, color: AppColors.accentGreen),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(key, style: theme.textTheme.bodySmall?.copyWith(
                          color: isCustom ? AppColors.accentGreen : AppColors.textSecondary,
                        )),
                        const SizedBox(height: 2),
                        Text(field.rawValue, style: theme.textTheme.bodyMedium),
                        if (ambiguous) ...[
                          const SizedBox(height: 2),
                          Text('Vérification recommandée', style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.accentRed,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          )),
                        ] else if (validated) ...[
                          const SizedBox(height: 2),
                          Text('Validé', style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.accentGreen,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          )),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (ambiguous && hasAlternatives)
            IconButton(
              icon: Icon(Icons.swap_horiz, size: 16, color: AppColors.accentRed),
              onPressed: () => _showCandidatePicker(key, field, alternatives),
              visualDensity: VisualDensity.compact,
              tooltip: 'Choisir une autre valeur',
            ),
          const SizedBox(width: 4),
          _typeBadge(field.type, onTap: () {
            _editField(key, field.rawValue, field.type, isCustom: isCustom, alternatives: alternatives);
          }),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 16, color: AppColors.textTertiary),
            onPressed: () => _editField(key, field.rawValue, field.type, isCustom: isCustom, alternatives: alternatives),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: AppColors.textTertiary),
            onPressed: () => _removeField(key, isCustom: isCustom),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Future<void> _showCandidatePicker(String key, TypedField field, List<ExtractionCandidate> alternatives) async {
    ExtractionCandidate? chosen;
    try {
      chosen = alternatives.firstWhere((c) => c.value == field.rawValue);
    } catch (_) {
      chosen = null;
    }

    bool confirmOnly = false;

    final selected = await showDialog<ExtractionCandidate>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final theme = Theme.of(ctx);
          return AlertDialog(
            title: Text('Suggestions détectées', style: theme.textTheme.titleMedium),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            contentPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: alternatives.map((c) {
                  final isSelected = chosen?.id == c.id;
                  return InkWell(
                    onTap: () {
                      debugPrint('[UI] suggestion clicked');
                      debugPrint('[field] $key');
                      debugPrint('[oldValue] ${field.rawValue}');
                      debugPrint('[newValue] ${c.value}');
                      setDialogState(() => chosen = c);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.08) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            size: 18,
                            color: isSelected ? AppColors.primaryBlue : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.value,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Source : ${c.label}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
                                ),
                              ],
                            ),
                          ),
                          if (c.score >= 80)
                            const Icon(Icons.check_circle, size: 14, color: AppColors.accentGreen)
                          else if (c.score < 0)
                            const Icon(Icons.cancel, size: 14, color: AppColors.accentRed),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  confirmOnly = true;
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Valider'),
              ),
              FilledButton(
                onPressed: () {
                  if (chosen != null) Navigator.pop(ctx, chosen);
                },
                child: const Text('Appliquer'),
              ),
            ],
          );
        },
      ),
    );

    if (!mounted) return;

    if (confirmOnly) {
      setState(() {
        _draft.confirmField(key);
        debugPrint('[UPDATE] field confirmed (validated by user)');
        _draft.validate();
      });
      debugPrint('[UI] refresh complete');
    } else if (selected != null) {
      setState(() {
        _draft.pickAlternative(key, selected);
        debugPrint('[UPDATE] field updated');
        _draft.validate();
      });
      debugPrint('[UI] refresh complete');
    }
  }

  Widget _typeBadge(FieldType type, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: type.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: type.color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.icon, size: 11, color: type.color),
            const SizedBox(width: 3),
            Text(type.shortName, style: TextStyle(
              fontSize: 10,
              color: type.color,
              fontWeight: FontWeight.w600,
            )),
          ],
        ),
      ),
    );
  }

  // ─── Tags ─────────────────────────────────────────────────────────
  Widget _buildTagsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionHeader(theme, 'ÉTIQUETTES'),
            const Spacer(),
            TextButton.icon(
              onPressed: _addTag,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ajouter'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_draft.tags.isEmpty)
          Text('Aucune étiquette', style: theme.textTheme.bodySmall)
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: _draft.tags.map((t) => TagChip(
              label: t,
              onDeleted: () => _removeTag(t),
            )).toList(),
          ),
      ],
    );
  }

  // ─── Raw text ────────────────────────────────────────────────────
  Widget _buildRawTextSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _rawTextExpanded = !_rawTextExpanded),
          child: Row(
            children: [
              Icon(
                _rawTextExpanded ? Icons.expand_less : Icons.expand_more,
                size: 18, color: _typeColor(),
              ),
              const SizedBox(width: 4),
              Text('TEXTE EXTRAIT BRUT', style: theme.textTheme.titleSmall),
              const SizedBox(width: AppSpacing.sm),
              Text('${_draft.rawText.length} car.', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_rawTextExpanded)
          Container(
            width: double.infinity,
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: SelectableText(
              _draft.rawText,
              style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.5),
            ),
          ),
      ],
    );
  }
}
