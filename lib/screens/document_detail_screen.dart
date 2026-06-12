import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/document_provider.dart';
import '../providers/tag_provider.dart';
import '../providers/entity_provider.dart';
import '../providers/event_provider.dart';
import '../models/tag.dart';
import '../widgets/tag_chip.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class DocumentDetailScreen extends StatefulWidget {
  final String documentId;

  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  List<Tag> _documentTags = [];
  List<dynamic> _entities = [];
  List<dynamic> _events = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final docProvider = context.read<DocumentProvider>();
    final tagProvider = context.read<TagProvider>();
    final entityProvider = context.read<EntityProvider>();
    final eventProvider = context.read<EventProvider>();

    await docProvider.selectDocument(widget.documentId);
    _documentTags = await docProvider.getTagsForDocument(widget.documentId);
    _entities = await entityProvider.getForDocument(widget.documentId);
    _events = await eventProvider.getByDocument(widget.documentId);

    if (tagProvider.tags.isEmpty) await tagProvider.loadTags();
    setState(() {});
  }

  Future<void> _showTagSelector() async {
    final tagProvider = context.read<TagProvider>();
    final docProvider = context.read<DocumentProvider>();

    final selected = await showDialog<List<Tag>>(
      context: context,
      builder: (context) => _TagSelectorDialog(
        availableTags: tagProvider.tags,
        selectedTags: _documentTags,
      ),
    );

    if (selected != null) {
      for (final tag in selected) {
        if (!_documentTags.contains(tag)) {
          await docProvider.addTagToDocument(widget.documentId, tag);
        }
      }
      for (final tag in _documentTags) {
        if (!selected.contains(tag)) {
          await docProvider.removeTagFromDocument(widget.documentId, tag.id);
        }
      }
      _documentTags = selected;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<DocumentProvider>(
      builder: (context, provider, _) {
        final doc = provider.selectedDocument;
        if (doc == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Document'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditDialog(doc),
              ),
            ],
          ),
          body: ListView(
            padding: AppSpacing.screenPadding,
            children: [
              Text(doc.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text('Créé le ${DateFormat('dd/MM/yyyy').format(doc.createdAt)}', style: theme.textTheme.bodySmall),
              if (doc.documentDate != null)
                Text('Date du document : ${DateFormat('dd/MM/yyyy').format(doc.documentDate!)}', style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.lg),

              if (doc.filePath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: doc.mimeType?.startsWith('image/') == true
                      ? Image.file(
                          File(doc.filePath!),
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 100),
                        )
                      : Container(
                          height: 150,
                          color: AppColors.surface1,
                          child: Center(child: Icon(Icons.picture_as_pdf, size: 64, color: AppColors.primaryBlue)),
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              _sectionTitle(theme, 'TAGS'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                children: _documentTags
                    .map((t) => Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 4),
                      child: TagChip(
                        label: t.label,
                        onDeleted: () async {
                          await context.read<DocumentProvider>().removeTagFromDocument(widget.documentId, t.id);
                          _documentTags.remove(t);
                          setState(() {});
                        },
                      ),
                    ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: _showTagSelector,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter un tag'),
              ),
              const SizedBox(height: AppSpacing.lg),

              _sectionTitle(theme, 'ENTITÉS LIÉES'),
              ..._entities.map((e) => ListTile(
                    dense: true,
                    title: Text(e.name),
                    subtitle: Text(e.entityType),
                  )),
              const SizedBox(height: AppSpacing.lg),

              _sectionTitle(theme, 'ÉVÉNEMENTS LIÉS'),
              ..._events.map((e) => ListTile(
                    dense: true,
                    title: Text(e.description),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(e.date)),
                  )),

              if (doc.ocrText != null && doc.ocrText!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _sectionTitle(theme, 'TEXTE OCR'),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: AppSpacing.cardPadding,
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SelectableText(doc.ocrText!, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Row(
      children: [
        Container(width: 3, height: 16,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleSmall),
      ],
    );
  }

  void _showEditDialog(dynamic doc) {
    final titleController = TextEditingController(text: doc.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le document'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Titre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              context.read<DocumentProvider>().updateDocument(doc.copyWith(title: titleController.text));
              Navigator.pop(context);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

class _TagSelectorDialog extends StatefulWidget {
  final List<Tag> availableTags;
  final List<Tag> selectedTags;

  const _TagSelectorDialog({
    required this.availableTags,
    required this.selectedTags,
  });

  @override
  State<_TagSelectorDialog> createState() => _TagSelectorDialogState();
}

class _TagSelectorDialogState extends State<_TagSelectorDialog> {
  late List<Tag> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedTags);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sélectionner des tags'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: widget.availableTags.map((tag) {
            final isSelected = _selected.contains(tag);
            return CheckboxListTile(
              title: Text(tag.label),
              subtitle: Text(tag.category.name),
              value: isSelected,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selected.add(tag);
                  } else {
                    _selected.remove(tag);
                  }
                });
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
