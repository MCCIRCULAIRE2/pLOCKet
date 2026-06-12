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
    print('[TEST] ÉTAPE 1 - Fichier sélectionné: ${file.name}');
    print('[TEST] ÉTAPE 1 - Taille: ${file.size} octets');
    print('[TEST] ÉTAPE 1 - Extension: ${file.extension}');

    // ÉTAPE 2: Capturer les bytes bruts
    Uint8List? rawBytes;
    if (file.bytes != null) {
      rawBytes = file.bytes!;
      print('[TEST] ÉTAPE 2 - Bytes bruts reçus: ${rawBytes.length} octets');
      print('[TEST] ÉTAPE 2 - Hash MD5: ${_calculateHash(rawBytes)}');
      
      // Sauvegarder l'image brute
      if (kIsWeb) {
        _saveImageForDebug(rawBytes, 'import_step1_raw.jpg');
      }
    }

    // ÉTAPE 3: Décoder l'image pour obtenir les dimensions
    int imageWidth = 0;
    int imageHeight = 0;
    img.Image? decodedImage;
    
    if (rawBytes != null) {
      try {
        decodedImage = img.decodeImage(rawBytes);
        if (decodedImage != null) {
          imageWidth = decodedImage.width;
          imageHeight = decodedImage.height;
          print('[TEST] ÉTAPE 3 - Image décodée: ${imageWidth}x$imageHeight pixels');
          print('[TEST] ÉTAPE 3 - Format: ${decodedImage.numChannels} canaux');
        }
      } catch (e) {
        print('[TEST] ÉTAPE 3 - ⚠ Impossible de décoder: $e');
      }
    }

    // ÉTAPE 4: Prétraitement (aucun pour l'instant, juste passage direct)
    Uint8List? bytesForOcr = rawBytes;
    print('[TEST] ÉTAPE 4 - Bytes pour OCR: ${bytesForOcr?.length ?? 0} octets');
    print('[TEST] ÉTAPE 4 - Aucune transformation appliquée');
    print('[TEST] ÉTAPE 4 - Hash MD5: ${_calculateHash(bytesForOcr ?? Uint8List(0))}');

    final sw = Stopwatch()..start();
    String ocrText = '';

    // ÉTAPE 5: Appel OCR
    try {
      if (kIsWeb && bytesForOcr != null) {
        print('[TEST] ÉTAPE 5 - Plateforme: Web');
        print('[TEST] ÉTAPE 5 - Envoi de ${bytesForOcr.length} octets à Tesseract.js');
        ocrText = await _ocr.extractTextFromImageBytes(bytesForOcr);
      } else if (file.path != null) {
        print('[TEST] ÉTAPE 5 - Plateforme: Native');
        print('[TEST] ÉTAPE 5 - Envoi du path à ML Kit: ${file.path}');
        ocrText = await _ocr.extractTextFromImage(file.path!);
      }
    } catch (e) {
      print('[TEST] ÉTAPE 5 - ❌ Erreur OCR: $e');
    }

    print('[TEST] ÉTAPE 6 - OCR terminé en ${sw.elapsedMilliseconds}ms');
    print('[TEST] ÉTAPE 6 - Caractères extraits: ${ocrText.length}');
    print('[TEST] ÉTAPE 6 - Texte OCR:\n$ocrText');

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
      _importImageBytes = rawBytes;
      _importImageWidth = imageWidth;
      _importImageHeight = imageHeight;
      _importFileSize = file.size;
      _isProcessing = false;
      _statusText = '';
    });

    print('[TEST] ÉTAPE 7 - Champs extraits: ${_importFields}');
    for (final entry in _importExtractedFields.entries) {
      print('[TEST] ÉTAPE 7 - ${entry.key} = ${entry.value}');
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

    print('[TEST] ÉTAPE 1 - Image sélectionnée: ${xFile.name}');
    
    // ÉTAPE 2: Capturer les bytes bruts
    final rawBytes = await xFile.readAsBytes();
    print('[TEST] ÉTAPE 2 - Bytes bruts reçus: ${rawBytes.length} octets');
    print('[TEST] ÉTAPE 2 - Hash MD5: ${_calculateHash(rawBytes)}');
    
    // Sauvegarder l'image brute
    if (kIsWeb) {
      _saveImageForDebug(rawBytes, 'scanner_step1_raw.jpg');
    }

    // ÉTAPE 3: Décoder l'image pour obtenir les dimensions
    int imageWidth = 0;
    int imageHeight = 0;
    img.Image? decodedImage;
    
    try {
      decodedImage = img.decodeImage(rawBytes);
      if (decodedImage != null) {
        imageWidth = decodedImage.width;
        imageHeight = decodedImage.height;
        print('[TEST] ÉTAPE 3 - Image décodée: ${imageWidth}x$imageHeight pixels');
        print('[TEST] ÉTAPE 3 - Format: ${decodedImage.numChannels} canaux');
      }
    } catch (e) {
      print('[TEST] ÉTAPE 3 - ⚠ Impossible de décoder: $e');
    }

    // ÉTAPE 4: Prétraitement (aucun pour l'instant, juste passage direct)
    Uint8List bytesForOcr = rawBytes;
    print('[TEST] ÉTAPE 4 - Bytes pour OCR: ${bytesForOcr.length} octets');
    print('[TEST] ÉTAPE 4 - Aucune transformation appliquée');
    print('[TEST] ÉTAPE 4 - Hash MD5: ${_calculateHash(bytesForOcr)}');

    final sw = Stopwatch()..start();
    String ocrText = '';

    // ÉTAPE 5: Appel OCR
    try {
      if (kIsWeb) {
        print('[TEST] ÉTAPE 5 - Plateforme: Web');
        print('[TEST] ÉTAPE 5 - Envoi de ${bytesForOcr.length} octets à Tesseract.js');
        ocrText = await _ocr.extractTextFromImageBytes(bytesForOcr);
      } else {
        print('[TEST] ÉTAPE 5 - Plateforme: Native');
        print('[TEST] ÉTAPE 5 - Envoi du path à ML Kit: ${xFile.path}');
        ocrText = await _ocr.extractTextFromImage(xFile.path);
      }
    } catch (e) {
      print('[TEST] ÉTAPE 5 - ❌ Erreur OCR: $e');
    }

    print('[TEST] ÉTAPE 6 - OCR terminé en ${sw.elapsedMilliseconds}ms');
    print('[TEST] ÉTAPE 6 - Caractères extraits: ${ocrText.length}');
    print('[TEST] ÉTAPE 6 - Texte OCR:\n$ocrText');

    // Extraction des champs
    final cardProvider = context.read<CardProvider>();
    final draft = await cardProvider.analyzeDocument(
      title: 'Test Scanner - ${xFile.name}',
      ocrText: ocrText,
      filePath: xFile.path,
      mimeType: 'image/jpeg',
      sourceFileName: xFile.name,
      sourceFileExtension: 'jpg',
      sourceBytes: rawBytes,
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
      _scannerImageBytes = rawBytes;
      _scannerImageWidth = imageWidth;
      _scannerImageHeight = imageHeight;
      _scannerFileSize = rawBytes.length;
      _isProcessing = false;
      _statusText = '';
    });

    print('[TEST] ÉTAPE 7 - Champs extraits: ${_scannerFields}');
    for (final entry in _scannerExtractedFields.entries) {
      print('[TEST] ÉTAPE 7 - ${entry.key} = ${entry.value}');
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

  String _calculateHash(Uint8List bytes) {
    if (bytes.isEmpty) return 'empty';
    // Hash simple basé sur les premiers et derniers bytes
    final first = bytes.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final last = bytes.skip(bytes.length > 16 ? bytes.length - 16 : 0).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${first}...${last}';
  }

  void _saveImageForDebug(Uint8List bytes, String filename) {
    if (!kIsWeb) return;
    print('[DEBUG] Sauvegarde image: $filename (${bytes.length} octets)');
    _downloadImage(bytes, filename);
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
