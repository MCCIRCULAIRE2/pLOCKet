import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'pdf_ocr_stub.dart'
    if (dart.library.js) 'pdf_ocr_web.dart';
import 'image_ocr_stub.dart'
    if (dart.library.js) 'image_ocr_web.dart';

class OcrService {
  static final RegExp _pdfShowString =
      RegExp(r'\(([^)]*)\)\s*Tj', caseSensitive: false);
  static final RegExp _pdfTextInParens = RegExp(r'\(([^)]*)\)');
  static final RegExp _pdfTextBlock =
      RegExp(r'BT\s*([\s\S]*?)ET', caseSensitive: false);

  Future<String> extractTextFromImage(String imagePath) async {
    if (kIsWeb) {
      debugPrint('[OCR] ÉTAPE 5a - OCR image Web : début');
      return '';
    }
    final sw = Stopwatch()..start();
    debugPrint('[OCR] ÉTAPE 5a - OCR image : début sur $imagePath');
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final recognizedText = await textRecognizer.processImage(inputImage);
        final text = recognizedText.text.trim();
        debugPrint('[OCR] ÉTAPE 5a - OCR image : SUCCÈS (${text.length} car.) [${sw.elapsedMilliseconds}ms]');
        return text;
      } finally {
        textRecognizer.close();
      }
    } catch (e) {
      debugPrint('[OCR] ÉTAPE 5a - OCR image : ÉCHEC — $e [${sw.elapsedMilliseconds}ms]');
      return '';
    }
  }

  Future<String> extractTextFromImageBytesNative(Uint8List imageBytes) async {
    if (kIsWeb) return '';
    final sw = Stopwatch()..start();
    debugPrint('[OCR] ÉTAPE 5c - OCR image bytes native : début (${imageBytes.length} octets)');
    try {
      final tempDir = await Directory.systemTemp.createTemp('ocr_');
      final tempFile = File('${tempDir.path}/ocr_image.jpg');
      await tempFile.writeAsBytes(imageBytes);
      
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final recognizedText = await textRecognizer.processImage(inputImage);
        final text = recognizedText.text.trim();
        debugPrint('[OCR] ÉTAPE 5c - OCR image bytes native : SUCCÈS (${text.length} car.) [${sw.elapsedMilliseconds}ms]');
        return text;
      } finally {
        textRecognizer.close();
        try {
          await tempFile.delete();
          await tempDir.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[OCR] ÉTAPE 5c - OCR image bytes native : ÉCHEC — $e [${sw.elapsedMilliseconds}ms]');
      return '';
    }
  }

  Future<String> extractTextFromImageBytes(Uint8List imageBytes) async {
    if (!kIsWeb) {
      debugPrint('[OCR] ÉTAPE 5b - OCR image bytes : NON (plateforme native)');
      return '';
    }
    
    debugPrint('[OCR] ÉTAPE 5b - OCR image Web : début (${imageBytes.length} octets)');
    final sw = Stopwatch()..start();
    
    try {
      final text = await extractTextFromImageWeb(imageBytes);
      debugPrint('[OCR] ÉTAPE 5b - OCR image Web : SUCCÈS (${text.length} car.) [${sw.elapsedMilliseconds}ms]');
      return text;
    } catch (e) {
      debugPrint('[OCR] ÉTAPE 5b - OCR image Web : ÉCHEC — $e [${sw.elapsedMilliseconds}ms]');
      return '';
    }
  }

  Future<String> extractTextFromPdf(String filePath) async {
    if (kIsWeb) {
      debugPrint('[OCR] ÉTAPE 4a - Extraction PDF : NON (web)');
      return '';
    }
    final sw = Stopwatch()..start();
    debugPrint('[OCR] ÉTAPE 2 - Lecture fichier : début $filePath');
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      debugPrint('[OCR] ÉTAPE 2 - Lecture fichier : SUCCÈS (${bytes.length} octets) [${sw.elapsedMilliseconds}ms]');
      sw.reset();
      debugPrint('[OCR] ÉTAPE 4a - Extraction PDF : début');
      final text = _extractPdfText(bytes);
      return text;
    } catch (e) {
      debugPrint('[OCR] ÉTAPE 2 - Lecture fichier : ÉCHEC — $e [${sw.elapsedMilliseconds}ms]');
      return '';
    }
  }

  Future<String> extractTextFromBytes(Uint8List bytes, String name) async {
    final ext = name.split('.').last.toLowerCase();
    debugPrint('[OCR] ÉTAPE 3 - Détection type : $ext');
    
    if (_isImage(ext)) {
      debugPrint('[OCR] ÉTAPE 4b - Extraction image (depuis bytes) : début');
      return await extractTextFromImageBytes(bytes);
    }
    
    if (ext != 'pdf') {
      debugPrint('[OCR] ÉTAPE 4b - Extraction : NON (type inconnu: $ext)');
      return '';
    }

    debugPrint('[OCR] ÉTAPE 4b - Extraction PDF (depuis bytes) : début');
    debugPrint('[TRACE] Avant OCR : bytes length=${bytes.length}');
    final sw = Stopwatch()..start();

    // Work on an independent copy — the original must survive for later save
    final ocrCopy = Uint8List.fromList(bytes);
    String text = _extractPdfText(ocrCopy);
    debugPrint('[TRACE] Après _extractPdfText : bytes length=${bytes.length}');

    if (kIsWeb && text.length < 50 && bytes.length > 10000) {
      debugPrint('[OCR] ÉTAPE 4b - Texte natif insuffisant (${text.length} car. pour ${bytes.length} octets) → pdf.js');
      // processPdfWeb already makes its own copy internally
      final result = await processPdfWeb(ocrCopy);
      debugPrint('[TRACE] Après processPdfWeb : bytes length=${bytes.length}');
      final elapsed = sw.elapsedMilliseconds;

      if (result.method == 'text') {
        debugPrint('[OCR] ÉTAPE 4c - pdf.js texte natif : SUCCÈS (${result.pages} pages, ${result.text.length} car.) [${elapsed}ms]');
        text = result.text;
      } else if (result.method == 'ocr') {
        debugPrint('[OCR] ÉTAPE 4c - pdf.js + OCR image : SUCCÈS (${result.pages} pages, ${result.text.length} car.) [${elapsed}ms]');
        text = result.text;
      } else {
        debugPrint('[OCR] ÉTAPE 4c - pdf.js : ÉCHEC — ${result.error} [${elapsed}ms]');
      }
    }

    debugPrint('[OCR] ÉTAPE 4 - Extraction contenu : SUCCÈS (${text.length} car.) [${sw.elapsedMilliseconds}ms]');
    if (text.length > 500) {
      debugPrint('[OCR] ÉTAPE 4 - Début du texte (500 premiers car.) :\n${text.substring(0, 500)}');
    } else if (text.isNotEmpty) {
      debugPrint('[OCR] ÉTAPE 4 - Texte extrait :\n$text');
    }
    return text;
  }

  bool _isImage(String ext) {
    return ['jpg', 'jpeg', 'png', 'heic', 'webp', 'gif', 'bmp'].contains(ext.toLowerCase());
  }

  String _extractPdfText(Uint8List bytes) {
    final sw = Stopwatch()..start();
    try {
      final raw = latin1.decode(bytes);
      if (!raw.contains('%PDF-')) {
        debugPrint('[OCR] ÉTAPE 4 - Extraction contenu : ÉCHEC — pas un PDF valide [${sw.elapsedMilliseconds}ms]');
        return '';
      }

      final textParts = <String>[];

      for (final m in _pdfShowString.allMatches(raw)) {
        final t = m.group(1)!.trim();
        if (t.isNotEmpty && t.length > 1) textParts.add(t);
      }

      if (textParts.isEmpty) {
        for (final m in _pdfTextBlock.allMatches(raw)) {
          final block = m.group(1)!;
          for (final im in _pdfTextInParens.allMatches(block)) {
            final t = im.group(1)!.trim();
            if (t.isNotEmpty && t.length > 2) textParts.add(t);
          }
        }
      }

      if (textParts.isEmpty) {
        for (final m in _pdfTextInParens.allMatches(raw)) {
          final t = m.group(1)!.trim();
          if (t.isNotEmpty && t.length > 2) textParts.add(t);
        }
      }

      final result = textParts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      debugPrint('[OCR] ÉTAPE 4 - Extraction regex : ${result.length} car., ${textParts.length} segments [${sw.elapsedMilliseconds}ms]');
      return result;
    } catch (e) {
      debugPrint('[OCR] ÉTAPE 4 - Extraction contenu : ÉCHEC — $e [${sw.elapsedMilliseconds}ms]');
      return '';
    }
  }
}
