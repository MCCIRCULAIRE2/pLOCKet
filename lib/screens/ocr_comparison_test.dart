import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';
import '../providers/card_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'verification_screen.dart';

class OcrComparisonTest extends StatefulWidget {
  const OcrComparisonTest({super.key});

  @override
  State<OcrComparisonTest> createState() => _OcrComparisonTestState();
}

class _OcrComparisonTestState extends State<OcrComparisonTest> {
  final OcrService _ocr = OcrService();
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  String _statusText = '';
  
  // Résultats Cas A (Import)
  String _importOcrText = '';
  int _importOcrChars = 0;
  int _importFields = 0;
  Map<String, String> _importExtractedFields = {};
  
  // Résultats Cas B (Scanner)
  String _scannerOcrText = '';
  int _scannerOcrChars = 0;
  int _scannerFields = 0;
  Map<String, String> _scannerExtractedFields = {};

  Future<void> _testImport() async {
    setState(() {
      _isProcessing = true;
      _statusText = 'Cas A : Import image...';
    });

    print('[TEST] ═══════════════════════════════════════════════════════════');
    print('[TEST] CAS A : IMPORT IMAGE');
    print('[TEST] ═══════════════════════════════════════════════════════════');

    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      setState(() {
        _isProcessing = false;
        _statusText = '';
      });
      return;
    }

    final file = result.files.first;
    print('[TEST] Fichier sélectionné: ${file.name}');
    print('[TEST] Taille: ${file.size} octets');

    final sw = Stopwatch()..start();
    String ocrText = '';

    try {
      if (kIsWeb && file.bytes != null) {
        print('[TEST] Plateforme: Web (bytes)');
        ocrText = await _ocr.extractTextFromBytes(file.bytes!, file.name);
      } else if (file.path != null) {
        print('[TEST] Plateforme: Native (path)');
        ocrText = await _ocr.extractTextFromImage(file.path!);
      }
    } catch (e) {
      print('[TEST] ❌ Erreur OCR: $e');
    }

    print('[TEST] OCR terminé en ${sw.elapsedMilliseconds}ms');
    print('[TEST] Caractères extraits: ${ocrText.length}');
    print('[TEST] Texte OCR:\n$ocrText');

    // Extraction des champs
    final cardProvider = context.read<CardProvider>();
    final draft = await cardProvider.analyzeDocument(
      title: 'Test Import - ${file.name}',
      ocrText: ocrText,
      filePath: file.path ?? '',
      mimeType: 'image/jpeg',
      sourceFileName: file.name,
      sourceFileExtension: file.extension ?? 'jpg',
      sourceBytes: file.bytes,
    );

    setState(() {
      _importOcrText = ocrText;
      _importOcrChars = ocrText.length;
      _importFields = draft?.fields.length ?? 0;
      _importExtractedFields = {};
      if (draft != null) {
        for (final entry in draft.fields.entries) {
          _importExtractedFields[entry.key] = entry.value.rawValue;
        }
      }
      _isProcessing = false;
      _statusText = '';
    });

    print('[TEST] Champs extraits: ${_importFields}');
    for (final entry in _importExtractedFields.entries) {
      print('[TEST]   ${entry.key} = ${entry.value}');
    }
    print('[TEST] ═══════════════════════════════════════════════════════════');
  }

  Future<void> _testScanner() async {
    setState(() {
      _isProcessing = true;
      _statusText = 'Cas B : Scanner → Bibliothèque...';
    });

    print('[TEST] ═══════════════════════════════════════════════════════════');
    print('[TEST] CAS B : SCANNER → BIBLIOTHÈQUE');
    print('[TEST] ═══════════════════════════════════════════════════════════');

    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
      maxWidth: null,
      maxHeight: null,
    );

    if (xFile == null) {
      setState(() {
        _isProcessing = false;
        _statusText = '';
      });
      return;
    }

    print('[TEST] Image sélectionnée: ${xFile.name}');
    final bytes = await xFile.readAsBytes();
    print('[TEST] Taille: ${bytes.length} octets');

    final sw = Stopwatch()..start();
    String ocrText = '';

    try {
      if (kIsWeb) {
        print('[TEST] Plateforme: Web (bytes)');
        ocrText = await _ocr.extractTextFromImageBytes(bytes);
      } else {
        print('[TEST] Plateforme: Native (path)');
        ocrText = await _ocr.extractTextFromImage(xFile.path);
      }
    } catch (e) {
      print('[TEST] ❌ Erreur OCR: $e');
    }

    print('[TEST] OCR terminé en ${sw.elapsedMilliseconds}ms');
    print('[TEST] Caractères extraits: ${ocrText.length}');
    print('[TEST] Texte OCR:\n$ocrText');

    // Extraction des champs
    final cardProvider = context.read<CardProvider>();
    final draft = await cardProvider.analyzeDocument(
      title: 'Test Scanner - ${xFile.name}',
      ocrText: ocrText,
      filePath: xFile.path,
      mimeType: 'image/jpeg',
      sourceFileName: xFile.name,
      sourceFileExtension: 'jpg',
      sourceBytes: bytes,
    );

    setState(() {
      _scannerOcrText = ocrText;
      _scannerOcrChars = ocrText.length;
      _scannerFields = draft?.fields.length ?? 0;
      _scannerExtractedFields = {};
      if (draft != null) {
        for (final entry in draft.fields.entries) {
          _scannerExtractedFields[entry.key] = entry.value.rawValue;
        }
      }
      _isProcessing = false;
      _statusText = '';
    });

    print('[TEST] Champs extraits: ${_scannerFields}');
    for (final entry in _scannerExtractedFields.entries) {
      print('[TEST]   ${entry.key} = ${entry.value}');
    }
    print('[TEST] ═══════════════════════════════════════════════════════════');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Comparatif OCR'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isProcessing) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: AppSpacing.md),
              Center(child: Text(_statusText, style: theme.textTheme.bodyMedium)),
            ] else ...[
              // Boutons de test
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _testImport,
                      icon: const Icon(Icons.upload_file, size: 20),
                      label: const Text('Cas A : Import'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _testScanner,
                      icon: const Icon(Icons.photo_library, size: 20),
                      label: const Text('Cas B : Scanner'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Résultats comparatifs
              if (_importOcrText.isNotEmpty || _scannerOcrText.isNotEmpty) ...[
                _buildComparisonTable(theme),
                const SizedBox(height: AppSpacing.xxl),
                _buildOcrTextComparison(theme),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTable(ThemeData theme) {
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comparaison des résultats', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Table(
            border: TableBorder.all(color: AppColors.border),
            children: [
              TableRow(
                decoration: BoxDecoration(color: AppColors.surface2),
                children: [
                  _tableCell('Métrique', bold: true),
                  _tableCell('Cas A\nImport', bold: true),
                  _tableCell('Cas B\nScanner', bold: true),
                  _tableCell('Différence', bold: true),
                ],
              ),
              TableRow(
                children: [
                  _tableCell('Caractères OCR'),
                  _tableCell('$_importOcrChars'),
                  _tableCell('$_scannerOcrChars'),
                  _tableCell(_formatDiff(_importOcrChars, _scannerOcrChars)),
                ],
              ),
              TableRow(
                children: [
                  _tableCell('Champs extraits'),
                  _tableCell('$_importFields'),
                  _tableCell('$_scannerFields'),
                  _tableCell(_formatDiff(_importFields, _scannerFields)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Champs extraits détaillés', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          _buildFieldsComparison(theme),
        ],
      ),
    );
  }

  Widget _tableCell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatDiff(int a, int b) {
    if (a == 0 && b == 0) return '-';
    final diff = b - a;
    final percent = a > 0 ? ((diff / a) * 100).toStringAsFixed(1) : '?';
    return '$diff ($percent%)';
  }

  Widget _buildFieldsComparison(ThemeData theme) {
    final allKeys = <String>{
      ..._importExtractedFields.keys,
      ..._scannerExtractedFields.keys,
    };

    if (allKeys.isEmpty) {
      return Text('Aucun champ extrait', style: theme.textTheme.bodySmall);
    }

    return Column(
      children: allKeys.map((key) {
        final importValue = _importExtractedFields[key] ?? '(absent)';
        final scannerValue = _scannerExtractedFields[key] ?? '(absent)';
        final match = importValue == scannerValue;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: match ? AppColors.accentGreen.withOpacity(0.1) : AppColors.accentRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(key, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Text('Import: $importValue', style: TextStyle(fontSize: 11)),
              Text('Scanner: $scannerValue', style: TextStyle(fontSize: 11)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOcrTextComparison(ThemeData theme) {
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Texte OCR complet', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cas A : Import', style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        _importOcrText.isEmpty ? '(vide)' : _importOcrText,
                        style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cas B : Scanner', style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        _scannerOcrText.isEmpty ? '(vide)' : _scannerOcrText,
                        style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
