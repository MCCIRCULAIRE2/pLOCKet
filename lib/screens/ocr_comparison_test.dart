import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../services/ocr_service.dart';
import '../providers/card_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

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
  Uint8List? _importImageBytes;
  int _importImageWidth = 0;
  int _importImageHeight = 0;
  int _importFileSize = 0;
  
  // Résultats Cas B (Scanner)
  String _scannerOcrText = '';
  int _scannerOcrChars = 0;
  int _scannerFields = 0;
  Map<String, String> _scannerExtractedFields = {};
  Uint8List? _scannerImageBytes;
  int _scannerImageWidth = 0;
  int _scannerImageHeight = 0;
  int _scannerFileSize = 0;

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

    // Capturer les bytes et dimensions
    Uint8List? imageBytes;
    int imageWidth = 0;
    int imageHeight = 0;
    
    if (file.bytes != null) {
      imageBytes = file.bytes!;
      try {
        final decodedImage = img.decodeImage(imageBytes);
        if (decodedImage != null) {
          imageWidth = decodedImage.width;
          imageHeight = decodedImage.height;
          print('[TEST] Dimensions image: ${imageWidth}x$imageHeight pixels');
        }
      } catch (e) {
        print('[TEST] ⚠ Impossible de lire les dimensions: $e');
      }
    }

    final sw = Stopwatch()..start();
    String ocrText = '';

    try {
      if (kIsWeb && file.bytes != null) {
        print('[TEST] Plateforme: Web (bytes)');
        print('[TEST] Bytes envoyés à OCR: ${imageBytes?.length ?? 0} octets');
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
      _importImageBytes = imageBytes;
      _importImageWidth = imageWidth;
      _importImageHeight = imageHeight;
      _importFileSize = file.size;
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

    // Capturer les dimensions
    int imageWidth = 0;
    int imageHeight = 0;
    try {
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage != null) {
        imageWidth = decodedImage.width;
        imageHeight = decodedImage.height;
        print('[TEST] Dimensions image: ${imageWidth}x$imageHeight pixels');
      }
    } catch (e) {
      print('[TEST] ⚠ Impossible de lire les dimensions: $e');
    }

    final sw = Stopwatch()..start();
    String ocrText = '';

    try {
      if (kIsWeb) {
        print('[TEST] Plateforme: Web (bytes)');
        print('[TEST] Bytes envoyés à OCR: ${bytes.length} octets');
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
      _scannerImageBytes = bytes;
      _scannerImageWidth = imageWidth;
      _scannerImageHeight = imageHeight;
      _scannerFileSize = bytes.length;
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
                _buildImageComparison(theme),
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
                  _tableCell('Résolution'),
                  _tableCell(_importImageWidth > 0 ? '${_importImageWidth}x$_importImageHeight' : '-'),
                  _tableCell(_scannerImageWidth > 0 ? '${_scannerImageWidth}x$_scannerImageHeight' : '-'),
                  _tableCell(_formatResolutionDiff()),
                ],
              ),
              TableRow(
                children: [
                  _tableCell('Taille fichier'),
                  _tableCell(_formatFileSize(_importFileSize)),
                  _tableCell(_formatFileSize(_scannerFileSize)),
                  _tableCell(_formatFileSizeDiff(_importFileSize, _scannerFileSize)),
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

  String _formatResolutionDiff() {
    if (_importImageWidth == 0 || _scannerImageWidth == 0) return '-';
    final importPixels = _importImageWidth * _importImageHeight;
    final scannerPixels = _scannerImageWidth * _scannerImageHeight;
    final diff = scannerPixels - importPixels;
    final percent = importPixels > 0 ? ((diff / importPixels) * 100).toStringAsFixed(1) : '?';
    return '$diff px ($percent%)';
  }

  String _formatFileSize(int bytes) {
    if (bytes == 0) return '-';
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  String _formatFileSizeDiff(int a, int b) {
    if (a == 0 || b == 0) return '-';
    final diff = b - a;
    final percent = a > 0 ? ((diff / a) * 100).toStringAsFixed(1) : '?';
    return '${_formatFileSize(diff.abs())} ($percent%)';
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
            color: match ? AppColors.accentGreen.withValues(alpha: 0.1) : AppColors.accentRed.withValues(alpha: 0.1),
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

  Widget _buildImageComparison(ThemeData theme) {
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
          Text('Images envoyées à l\'OCR', style: theme.textTheme.titleMedium),
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
                    if (_importImageBytes != null)
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.memory(
                            _importImageBytes!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Center(
                          child: Text('(aucune image)', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_importImageBytes != null && kIsWeb)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _downloadImage(_importImageBytes!, 'import_image.jpg'),
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Télécharger'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
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
                    if (_scannerImageBytes != null)
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.memory(
                            _scannerImageBytes!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Center(
                          child: Text('(aucune image)', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_scannerImageBytes != null && kIsWeb)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _downloadImage(_scannerImageBytes!, 'scanner_image.jpg'),
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Télécharger'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
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

  void _downloadImage(Uint8List bytes, String filename) {
    if (!kIsWeb) return;
    
    final blob = web.Blob([bytes.toJS].toJS);
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename
      ..click();
    web.URL.revokeObjectURL(url);
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
