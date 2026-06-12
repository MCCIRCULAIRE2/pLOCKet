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
    print('[SCAN] ═══════════════════════════════════════════════════════════');
    print('[SCAN] Début capture photo');
    
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,  // Qualité maximale
      maxWidth: null,     // Pas de limite de largeur
      maxHeight: null,    // Pas de limite de hauteur
    );
    
    if (xFile == null) {
      print('[SCAN] ❌ Capture annulée');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusText = 'Analyse de l\'image...';
    });

    print('[SCAN] ✓ Photo capturée');
    print('[SCAN] Fichier: ${xFile.path}');
    print('[SCAN] Nom: ${xFile.name}');
    print('[SCAN] MIME type: ${xFile.mimeType ?? "non spécifié"}');
    
    // Obtenir la taille du fichier
    final bytes = await xFile.readAsBytes();
    print('[SCAN] Taille fichier: ${bytes.length} octets (${(bytes.length / 1024).toStringAsFixed(1)} KB)');
    
    // Sur mobile, essayer d'obtenir les dimensions
    if (!kIsWeb) {
      try {
        // Lire les dimensions depuis les bytes JPEG
        final width = _readJpegWidth(bytes);
        final height = _readJpegHeight(bytes);
        if (width != null && height != null) {
          print('[SCAN] Dimensions originales: ${width}x${height} pixels');
          print('[SCAN] Mégapixels: ${((width * height) / 1000000).toStringAsFixed(2)} MP');
        }
      } catch (e) {
        print('[SCAN] ⚠ Impossible de lire les dimensions: $e');
      }
    }
    
    print('[SCAN] ═══════════════════════════════════════════════════════════');

    print('[BEFORE OCR] ═══════════════════════════════════════════════════════════');
    print('[BEFORE OCR] Taille envoyée à OCR: ${bytes.length} octets');
    print('[BEFORE OCR] ═══════════════════════════════════════════════════════════');

    print('[OCR IMAGE] ═══════════════════════════════════════════════════════════');
    print('[OCR IMAGE] Démarrage OCR');
    print('[OCR IMAGE] Plateforme: ${kIsWeb ? "Web" : "Native"}');
    
    final sw = Stopwatch()..start();
    String ocrText;
    
    if (kIsWeb) {
      // Sur web, utiliser les bytes
      ocrText = await _ocr.extractTextFromImageBytes(bytes);
    } else {
      // Sur natif, utiliser le path
      ocrText = await _ocr.extractTextFromImage(xFile.path);
    }
    
    final elapsed = sw.elapsedMilliseconds;
    
    print('[OCR IMAGE] Temps d\'exécution: ${elapsed}ms');
    print('[OCR IMAGE] ═══════════════════════════════════════════════════════════');

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

    setState(() => _statusText = 'Analyse du document...');

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

  int? _readJpegWidth(Uint8List bytes) {
    try {
      // Chercher le marqueur SOF0 (Start of Frame)
      for (int i = 0; i < bytes.length - 9; i++) {
        if (bytes[i] == 0xFF && bytes[i + 1] == 0xC0) {
          // Largeur aux bytes 7-8
          return (bytes[i + 7] << 8) | bytes[i + 8];
        }
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  int? _readJpegHeight(Uint8List bytes) {
    try {
      // Chercher le marqueur SOF0 (Start of Frame)
      for (int i = 0; i < bytes.length - 9; i++) {
        if (bytes[i] == 0xFF && bytes[i + 1] == 0xC0) {
          // Hauteur aux bytes 5-6
          return (bytes[i + 5] << 8) | bytes[i + 6];
        }
      }
    } catch (e) {
      return null;
    }
    return null;
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
                Text('Prenez une photo de votre document',
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}
