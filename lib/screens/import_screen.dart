import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/ocr_service.dart';
import '../providers/card_provider.dart';
import '../services/step_logger.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'verification_screen.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final OcrService _ocr = OcrService();
  bool _isProcessing = false;
  String _statusText = '';

  Future<void> _pickFile() async {
    final sw = Stopwatch()..start();
    debugPrint('[IMPORT] ÉTAPE 1 - Sélection fichier : début');
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      debugPrint('[IMPORT] ÉTAPE 1 - Sélection fichier : ANNULÉ [${sw.elapsedMilliseconds}ms]');
      return;
    }

    final file = result.files.first;
    StepLogger.log('ÉTAPE 1 - Sélection fichier', true, sw.elapsedMilliseconds,
        error: '${file.name} (${file.extension}, ${_fmtSize(file.size)})');

    // Copy bytes IMMEDIATELY — before any async gap
    final platformFileBytes = file.bytes;
    final sourceFileBytes = kIsWeb && platformFileBytes != null
        ? Uint8List.fromList(platformFileBytes)
        : platformFileBytes;
    debugPrint('[IMPORT] fileSize=${file.size}');
    debugPrint('[IMPORT] bytes=${sourceFileBytes?.length ?? 0}');
    debugPrint('[IMPORT] mimeType=${_mimeFromExtension(file.extension ?? '')}');

    await _importFile(file, sourceBytes: sourceFileBytes);
  }

  Future<void> _importFile(PlatformFile file, {Uint8List? sourceBytes}) async {
    setState(() {
      _isProcessing = true;
      _statusText = 'Analyse de ${file.name}...';
    });

    final ext = file.extension ?? '';
    final mimeType = _mimeFromExtension(ext);
    final isImage = _isImage(ext);

    print('[IMPORT FILE] ═══════════════════════════════════════════════════════════');
    print('[IMPORT FILE] Nom: ${file.name}');
    print('[IMPORT FILE] Extension: $ext');
    print('[IMPORT FILE] MIME type: $mimeType');
    print('[IMPORT FILE] Taille: ${file.size} octets');
    print('[IMPORT FILE] Type: ${isImage ? "IMAGE" : "PDF"}');
    print('[IMPORT FILE] ═══════════════════════════════════════════════════════════');

    String ocrText;
    final swOcr = Stopwatch()..start();

    StepLogger.log('ÉTAPE 3 - Détection type', true, 0,
        error: isImage ? 'image ($ext)' : 'pdf ($ext)');

    try {
      if (kIsWeb && sourceBytes != null) {
        print('[IMPORT] ÉTAPE 3b - Source : bytes mémoire (${sourceBytes.length} octets, web)');
        ocrText = await _ocr.extractTextFromBytes(sourceBytes, file.name);
      } else if (file.path != null) {
        print('[IMPORT] ÉTAPE 3b - Source : fichier disque (${file.path})');
        if (isImage) {
          ocrText = await _ocr.extractTextFromImage(file.path!);
        } else {
          ocrText = await _ocr.extractTextFromPdf(file.path!);
        }
      } else if (file.bytes != null) {
        print('[IMPORT] ÉTAPE 3b - Source : bytes mémoire (${file.bytes!.length} octets)');
        ocrText = await _ocr.extractTextFromBytes(file.bytes!, file.name);
      } else {
        ocrText = '';
      }
    } catch (e) {
      print('[IMPORT] ÉTAPE 4/5 - Extraction/OCR : EXCEPTION — $e');
      ocrText = '';
    }

    print('[OCR RESULT] ═══════════════════════════════════════════════════════════');
    print('[OCR RESULT] Nombre de caractères: ${ocrText.length}');
    if (ocrText.length > 500) {
      print('[OCR RESULT] 500 premiers caractères:\n${ocrText.substring(0, 500)}');
    } else if (ocrText.isNotEmpty) {
      print('[OCR RESULT] Texte complet:\n$ocrText');
    } else {
      print('[OCR RESULT] ❌ AUCUN TEXTE EXTRAIT');
    }
    print('[OCR RESULT] ═══════════════════════════════════════════════════════════');

    final success = ocrText.isNotEmpty;
    StepLogger.log('ÉTAPE 4/5 - Extraction contenu${isImage ? ' / OCR' : ''}', success, swOcr.elapsedMilliseconds,
        error: success ? '${ocrText.length} car. extraits' : 'texte vide');

    if (ocrText.isEmpty) {
      setState(() {
        _isProcessing = false;
        _statusText = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'analyser "${file.name}". Le fichier n\'a pas été importé.'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    setState(() => _statusText = 'Extraction des champs...');

    print('[FIELD EXTRACTION] ═══════════════════════════════════════════════════════════');
    print('[FIELD EXTRACTION] Démarrage extraction de champs');
    print('[FIELD EXTRACTION] ═══════════════════════════════════════════════════════════');

    final cardProvider = context.read<CardProvider>();
    final swPipe = Stopwatch()..start();
    final draft = await cardProvider.analyzeDocument(
      title: file.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
      ocrText: ocrText,
      filePath: file.path ?? '',
      mimeType: mimeType,
      documentDate: null,
      sourceFileName: file.name,
      sourceFileExtension: ext,
      sourceBytes: sourceBytes,
    );

    if (draft != null) {
      print('[FIELD EXTRACTION] ✓ ${draft.fields.length} champ(s) extrait(s)');
      for (final field in draft.fields.entries) {
        print('[FIELD EXTRACTION]   ${field.key} = ${field.value.rawValue}');
      }
    } else {
      print('[FIELD EXTRACTION] ❌ Échec extraction');
    }
    print('[FIELD EXTRACTION] ═══════════════════════════════════════════════════════════');

    final analyzed = draft != null;
    StepLogger.log('ÉTAPE 6-8 - Analyse/Classification/Extraction', analyzed, swPipe.elapsedMilliseconds,
        error: analyzed ? '${draft!.fields.length} champs' : (cardProvider.error ?? 'null'));

    setState(() {
      _isProcessing = false;
      _statusText = '';
    });

    if (mounted) {
      if (draft != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerificationScreen(draft: draft),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cardProvider.error ?? 'Erreur lors de l\'analyse'),
          ),
        );
      }
    }
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  bool _isImage(String ext) {
    return ['jpg', 'jpeg', 'png', 'heic'].contains(ext.toLowerCase());
  }

  String _mimeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return 'application/pdf';
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'heic': return 'image/heic';
      default: return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importer un document'),
      ),
      body: Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isProcessing) ...[
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                  ),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 3)),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(_statusText, style: theme.textTheme.bodyMedium),
              ] else ...[
                Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                    border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                  ),
                  child: Icon(Icons.cloud_upload_outlined, size: 40, color: AppColors.primaryBlue),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('Importer un fichier', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text('PDF • JPG • PNG • HEIC', style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.xxxl),
                SizedBox(
                  width: 220,
                  child: FilledButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.folder_open_outlined, size: 20),
                    label: const Text('Sélectionner'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
