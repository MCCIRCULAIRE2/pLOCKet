import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/card_model.dart';
import '../models/draft_card.dart';
import '../models/typed_field.dart';
import '../models/field_type.dart';
import '../providers/card_provider.dart';
import '../widgets/tag_chip.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../database/daos/document_dao.dart';
import '../platform/source_reader/source_reader_stub.dart'
    if (dart.library.io) '../platform/source_reader/source_reader_io.dart';
import '../platform/blob_helper/blob_helper_stub.dart'
    if (dart.library.js_interop) '../platform/blob_helper/blob_helper_web.dart';
import 'verification_screen.dart';

class CardDetailScreen extends StatefulWidget {
  final String cardId;

  const CardDetailScreen({super.key, required this.cardId});

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  CardModel? _card;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCard();
  }

  Future<void> _loadCard() async {
    debugPrint('[LOAD] ═══════════════════════════════════════════════════════════');
    debugPrint('[LOAD] Chargement fiche cardId=${widget.cardId}');
    debugPrint('[LOAD] ═══════════════════════════════════════════════════════════');
    
    final provider = context.read<CardProvider>();
    CardModel? loaded;
    if (provider.selectedCard?.id == widget.cardId) {
      loaded = provider.selectedCard;
    } else {
      await provider.selectCard(widget.cardId);
      loaded = provider.selectedCard;
    }
    if (mounted) {
      setState(() {
        _card = loaded;
        _isLoading = false;
      });
      
      if (loaded != null) {
        debugPrint('[LOAD] ✓ Fiche chargée: ${loaded.title}');
        debugPrint('[LOAD] ─── Champs chargés (${loaded.fields.length}) ───');
        for (final entry in loaded.fields.entries) {
          final value = entry.value;
          final displayValue = value is Map<String, dynamic> ? value['v'] : value;
          debugPrint('[LOAD] ✓ ${entry.key} = $displayValue');
        }
      } else {
        debugPrint('[LOAD] ⚠ Fiche non trouvée');
      }
      debugPrint('[LOAD] ═══════════════════════════════════════════════════════════');
    }
  }

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

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détail fiche')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_card == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détail fiche')),
        body: const Center(child: Text('Fiche introuvable')),
      );
    }

    final card = _card!;
    final color = _color(card.type);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail fiche'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editCard(card),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Supprimer'),
                  content: const Text('Supprimer cette fiche ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<CardProvider>().deleteCard(widget.cardId);
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text('Supprimer'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      resizeToAvoidBottomInset: false,
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          // ── Header ──
          Container(
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(color: Color(0x4D000000), blurRadius: 12, offset: Offset(0, 4)),
                BoxShadow(color: Color(0x26000000), blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Icon(_icon(card.type), color: color, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_typeLabel(card.type), style: theme.textTheme.labelSmall),
                          Text(card.subType, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    if (card.date != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(card.date!),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(card.title, style: theme.textTheme.titleLarge),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Structured fields ──
          if (card.fields.isNotEmpty) ...[
            _sectionHeader(theme, 'CHAMPS EXTRAITS'),
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: card.fields.entries.map((e) => _fieldRow(theme, e.key, _displayFieldValue(e.value), e == card.fields.entries.last)).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ── AI extracted value ──
          if (card.value != null && card.value!.isNotEmpty) ...[
            Container(
              padding: AppSpacing.cardPadding,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: AppColors.primaryBlue),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      card.value!,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ── Tags ──
          if (card.tags.isNotEmpty) ...[
            _sectionHeader(theme, 'ÉTIQUETTES'),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: card.tags.map((t) => TagChip(label: t)).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ── Raw text ──
          _sectionHeader(theme, 'TEXTE EXTRAIT'),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(card.rawText, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Document source ──
          if (card.filePath != null || card.sourceDocumentId != null) ...[
            _sectionHeader(theme, 'DOCUMENT SOURCE'),
            const SizedBox(height: AppSpacing.md),
            Material(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                onTap: () => _openSourceDocument(card),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Icon(
                        card.mimeType?.startsWith('image') == true ? Icons.image : Icons.picture_as_pdf,
                        color: AppColors.primaryBlue, size: 22,
                      ),
                    ),
                    title: const Text('Voir le document original'),
                    trailing: Icon(Icons.open_in_new, size: 18, color: AppColors.primaryBlue),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
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

  String _displayFieldValue(dynamic value) {
    // Si c'est un Map (TypedField encodé), extraire la valeur 'v'
    if (value is Map<String, dynamic>) {
      // Extraire la valeur 'v' si elle existe
      if (value.containsKey('v')) {
        return value['v']?.toString() ?? '';
      }
      // Fallback: afficher la première valeur non-nulle
      for (final entry in value.entries) {
        if (entry.value != null && entry.key != 't' && entry.key != 'nr' && entry.key != 'vu') {
          return entry.value.toString();
        }
      }
      return '';
    }
    return value.toString();
  }

  Widget _fieldRow(ThemeData theme, String key, String value, bool isLast) {
    return Container(
      padding: AppSpacing.fieldPadding,
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(key, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Future<void> _editCard(CardModel card) async {
    debugPrint('[EDIT] ═══════════════════════════════════════════════════════════');
    debugPrint('[EDIT] Début édition fiche: ${card.id}');
    debugPrint('[EDIT] Titre: ${card.title}');
    debugPrint('[EDIT] ═══════════════════════════════════════════════════════════');
    
    // Convertir CardModel en DraftCard
    final draft = _cardModelToDraftCard(card);
    
    debugPrint('[EDIT] DraftCard créé avec ${draft.fields.length} champ(s)');
    debugPrint('[EDIT] Champs personnalisés: ${draft.customFields.length}');
    debugPrint('[EDIT] Étiquettes: ${draft.tags.length}');
    debugPrint('[EDIT] ═══════════════════════════════════════════════════════════');
    
    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerificationScreen(
          draft: draft,
          existingCardId: card.id,
        ),
      ),
    );
  }

  DraftCard _cardModelToDraftCard(CardModel card) {
    // Convertir les champs de CardModel en TypedField
    final fields = <String, TypedField>{};
    final customFields = <String, TypedField>{};
    
    for (final entry in card.fields.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is Map<String, dynamic>) {
        // Format TypedField encodé
        final rawValue = value['v']?.toString() ?? '';
        final typeName = value['t']?.toString() ?? 'text';
        final type = FieldType.values.firstWhere(
          (t) => t.name == typeName,
          orElse: () => FieldType.text,
        );
        final needsReview = value['nr'] as bool? ?? false;
        final validatedByUser = value['vu'] as bool? ?? false;
        
        fields[key] = TypedField(
          rawValue: rawValue,
          type: type,
          needsReview: needsReview,
          validatedByUser: validatedByUser,
        );
      } else {
        // Format legacy (string simple)
        fields[key] = TypedField(
          rawValue: value.toString(),
          type: FieldType.text,
        );
      }
    }
    
    return DraftCard(
      title: card.title,
      type: card.type,
      subType: card.subType,
      rawText: card.rawText,
      value: card.value,
      date: card.date,
      filePath: card.filePath,
      mimeType: card.mimeType,
      fields: fields,
      customFields: customFields,
      tags: card.tags,
    );
  }

  Future<void> _openSourceDocument(CardModel card) async {
    debugPrint('[SOURCE] documentPath=${card.filePath}');
    debugPrint('[SOURCE] documentUrl=${card.filePath}');
    debugPrint('[SOURCE] attachmentId=${card.sourceDocumentId}');
    debugPrint('[UI] Open document clicked');

    Uint8List? sourceBytes;

    if (card.sourceDocumentId != null) {
      final doc = await DocumentDao().getById(card.sourceDocumentId!);
      if (doc != null) {
        final decoded = doc.decodedSourceData;
        if (decoded != null) {
          sourceBytes = decoded;
          debugPrint('[OPEN] Document found (sourceData)');
          debugPrint('[OPEN] sourceData length (base64) = ${doc.sourceData?.length}');
        } else {
          debugPrint('[OPEN] sourceData is null (no bytes stored)');
        }
      } else {
        debugPrint('[OPEN] Document not found in DB');
      }
    }

    if (sourceBytes == null &&
        card.filePath != null &&
        card.filePath!.isNotEmpty &&
        !card.filePath!.startsWith('blob:')) {
      final fileBytes = await readFileBytes(card.filePath!);
      if (fileBytes != null) {
        sourceBytes = fileBytes;
        debugPrint('[OPEN] Document found (filePath)');
      }
    }

    if (sourceBytes != null) {
      debugPrint('[OPEN] bytes size = ${sourceBytes.length}');
      debugPrint('[OPEN] mime type = ${card.mimeType}');
      if (!mounted) return;

      if (sourceBytes.isEmpty) {
        debugPrint('[OPEN] ERROR: document is empty (0 bytes)');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document vide ou non chargé')),
        );
        return;
      }

      final isImage = card.mimeType?.startsWith('image') == true;
      
      String? blobUrl;
      if (kIsWeb && !isImage) {
        debugPrint('[OPEN] Creating blob URL for Web...');
        blobUrl = await createBlobUrl(sourceBytes, card.mimeType ?? 'application/pdf');
        if (blobUrl != null) {
          debugPrint('[OPEN] ✓ Blob URL created: $blobUrl');
        } else {
          debugPrint('[OPEN] ❌ Failed to create blob URL');
        }
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _DocumentViewer(
            sourceBytes: sourceBytes!,
            blobUrl: blobUrl,
            isImage: isImage,
            mimeType: card.mimeType,
          ),
        ),
      );
    } else {
      debugPrint('[OPEN] Document missing');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document source introuvable')),
      );
    }
  }
}

class _DocumentViewer extends StatefulWidget {
  final Uint8List sourceBytes;
  final String? blobUrl;
  final bool isImage;
  final String? mimeType;

  const _DocumentViewer({
    required this.sourceBytes,
    this.blobUrl,
    required this.isImage,
    this.mimeType,
  });

  @override
  State<_DocumentViewer> createState() => _DocumentViewerState();
}

class _DocumentViewerState extends State<_DocumentViewer> {
  @override
  void dispose() {
    if (widget.blobUrl != null) {
      debugPrint('[OPEN] Revoking blob URL: ${widget.blobUrl}');
      revokeBlobUrl(widget.blobUrl!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: widget.isImage
                ? InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 6.0,
                    child: Center(
                      child: Image.memory(widget.sourceBytes, fit: BoxFit.contain),
                    ),
                  )
                : widget.blobUrl != null
                    ? SfPdfViewer.network(widget.blobUrl!)
                    : SfPdfViewer.memory(widget.sourceBytes),
          ),
          Positioned(
            top: 16, right: 16,
            child: SafeArea(
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
          ),
        ],
      ),
    );
  }
}
