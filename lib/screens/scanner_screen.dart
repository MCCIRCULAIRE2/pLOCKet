import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';
import '../providers/card_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'verification_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocr = OcrService();
  bool _isProcessing = false;
  String _statusText = '';

  Future<void> _takePhoto() async {
    final xFile = await _picker.pickImage(source: ImageSource.camera);
    if (xFile == null) return;

    setState(() {
      _isProcessing = true;
      _statusText = 'Analyse de l\'image...';
    });

    print('[PHOTO OCR] ═══════════════════════════════════════════════════════════');
    print('[PHOTO OCR] Début OCR photo');
    print('[PHOTO OCR] Fichier: ${xFile.path}');
    print('[PHOTO OCR] ═══════════════════════════════════════════════════════════');

    final ocrText = await _ocr.extractTextFromImage(xFile.path);

    print('[TEXT EXTRACTED] ═══════════════════════════════════════════════════════════');
    print('[TEXT EXTRACTED] Nombre de caractères: ${ocrText.length}');
    if (ocrText.length > 500) {
      print('[TEXT EXTRACTED] 500 premiers caractères:\n${ocrText.substring(0, 500)}');
    } else if (ocrText.isNotEmpty) {
      print('[TEXT EXTRACTED] Texte complet:\n$ocrText');
    } else {
      print('[TEXT EXTRACTED] ⚠ Aucun texte extrait');
    }
    print('[TEXT EXTRACTED] ═══════════════════════════════════════════════════════════');

    setState(() => _statusText = 'Analyse du document...');

    final bytes = kIsWeb ? await xFile.readAsBytes() : null;

    print('[FIELD EXTRACTION] ═══════════════════════════════════════════════════════════');
    print('[FIELD EXTRACTION] Début extraction de champs');
    print('[FIELD EXTRACTION] ═══════════════════════════════════════════════════════════');

    final cardProvider = context.read<CardProvider>();
    final draft = await cardProvider.analyzeDocument(
      title: 'Photo - ${DateTime.now().toLocal().toString().substring(0, 16)}',
      ocrText: ocrText.isNotEmpty ? ocrText : '[Image scannée]',
      filePath: xFile.path,
      mimeType: 'image/jpeg',
      sourceFileName: xFile.name,
      sourceFileExtension: 'jpg',
      sourceBytes: bytes,
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
          SnackBar(content: Text(cardProvider.error ?? 'Erreur lors de l\'analyse')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final xFile = await _picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return;

    setState(() {
      _isProcessing = true;
      _statusText = 'Analyse de l\'image...';
    });

    print('[PHOTO OCR] ═══════════════════════════════════════════════════════════');
    print('[PHOTO OCR] Début OCR galerie');
    print('[PHOTO OCR] Fichier: ${xFile.path}');
    print('[PHOTO OCR] ═══════════════════════════════════════════════════════════');

    final ocrText = await _ocr.extractTextFromImage(xFile.path);

    print('[TEXT EXTRACTED] ═══════════════════════════════════════════════════════════');
    print('[TEXT EXTRACTED] Nombre de caractères: ${ocrText.length}');
    if (ocrText.length > 500) {
      print('[TEXT EXTRACTED] 500 premiers caractères:\n${ocrText.substring(0, 500)}');
    } else if (ocrText.isNotEmpty) {
      print('[TEXT EXTRACTED] Texte complet:\n$ocrText');
    } else {
      print('[TEXT EXTRACTED] ⚠ Aucun texte extrait');
    }
    print('[TEXT EXTRACTED] ═══════════════════════════════════════════════════════════');

    setState(() => _statusText = 'Analyse du document...');

    final bytes = kIsWeb ? await xFile.readAsBytes() : null;

    print('[FIELD EXTRACTION] ═══════════════════════════════════════════════════════════');
    print('[FIELD EXTRACTION] Début extraction de champs');
    print('[FIELD EXTRACTION] ═══════════════════════════════════════════════════════════');

    final cardProvider = context.read<CardProvider>();
    final draft = await cardProvider.analyzeDocument(
      title: 'Image - ${xFile.name}',
      ocrText: ocrText.isNotEmpty ? ocrText : '[Image depuis galerie]',
      filePath: xFile.path,
      mimeType: 'image/jpeg',
      sourceFileName: xFile.name,
      sourceFileExtension: 'jpg',
      sourceBytes: bytes,
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
          SnackBar(content: Text(cardProvider.error ?? 'Erreur lors de l\'analyse')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner'),
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
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                    border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                  ),
                  child: Icon(Icons.camera_alt_outlined, size: 44, color: AppColors.primaryBlue),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('Scanner un document', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text('Prenez une photo ou choisissez depuis la galerie',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xxxl),
                FilledButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt, size: 20),
                  label: const Text('Prendre une photo'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                  label: const Text('Choisir depuis la galerie'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
