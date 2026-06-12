import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/draft_card.dart';
import '../providers/card_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'verification_screen.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  DateTime? _documentDate;
  String _entryType = 'information';
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _titleController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);

    DraftCard? draft;
    if (_entryType == 'information' || _entryType == 'evenement') {
      draft = await context.read<CardProvider>().analyzeText(
        _titleController.text.trim().isNotEmpty
            ? '${_titleController.text.trim()}\n$content'
            : content,
      );
    } else {
      final title = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : 'Document saisi';
      draft = await context.read<CardProvider>().analyzeDocument(
        title: title,
        ocrText: content,
        documentDate: _documentDate,
      );
    }

    setState(() => _isSaving = false);

    if (mounted) {
      if (draft != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerificationScreen(draft: draft!),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<CardProvider>().error ?? 'Erreur lors de l\'analyse'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saisie manuelle'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'information', label: Text('Information')),
                ButtonSegment(value: 'evenement', label: Text('Événement')),
                ButtonSegment(value: 'document', label: Text('Document')),
              ],
              selected: {_entryType},
              onSelectionChanged: (v) => setState(() => _entryType = v.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return AppColors.primaryBlue;
                  return AppColors.surface1;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return Colors.white;
                  return AppColors.textSecondary;
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre (optionnel)',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _contentController,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Contenu',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Material(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _documentDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _documentDate = date);
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.calendar_today, color: AppColors.primaryBlue, size: 20),
                    title: Text(
                      _documentDate != null
                          ? DateFormat('dd/MM/yyyy').format(_documentDate!)
                          : 'Date (optionnelle)',
                      style: theme.textTheme.bodyMedium,
                    ),
                    trailing: Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            if (_isSaving)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined, size: 20),
                  label: Text('Créer le $_entryType'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
