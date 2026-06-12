import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('Tesseract.recognize')
external JSPromise<JSAny> _tesseractRecognize(JSAny image, JSString lang);

@JS()
@staticInterop
class _TesseractResult {
  external factory _TesseractResult();
}

extension _TesseractResultExtension on _TesseractResult {
  external _TesseractData get data;
}

@JS()
@staticInterop
class _TesseractData {
  external factory _TesseractData();
}

extension _TesseractDataExtension on _TesseractData {
  external String get text;
}

String _detectImageFormat(Uint8List bytes) {
  if (bytes.length < 8) return 'image/jpeg';
  
  // PNG: 89 50 4E 47
  if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
    return 'image/png';
  }
  
  // JPEG: FF D8 FF
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  
  // WebP: 52 49 46 46 ... 57 45 42 50
  if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
      bytes.length > 11 && bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
    return 'image/webp';
  }
  
  // GIF: 47 49 46 38
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) {
    return 'image/gif';
  }
  
  // BMP: 42 4D
  if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
    return 'image/bmp';
  }
  
  // HEIC/HEIF: 66 74 79 70 68 65 69 63 ou 66 74 79 70 6D 69 66 31
  if (bytes.length > 11 && bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
    if (bytes[8] == 0x68 && bytes[9] == 0x65 && bytes[10] == 0x69 && bytes[11] == 0x63) {
      return 'image/heic';
    }
    if (bytes[8] == 0x6D && bytes[9] == 0x69 && bytes[10] == 0x66 && bytes[11] == 0x31) {
      return 'image/heif';
    }
  }
  
  return 'image/jpeg'; // Fallback
}

Future<String> extractTextFromImageWeb(Uint8List imageBytes) async {
  try {
    print('[OCR WEB] ═══════════════════════════════════════════════════════════');
    print('[OCR WEB] ÉTAPE 1 - Bytes reçus: ${imageBytes.length} octets');
    
    // Détecter le format réel de l'image
    final mimeType = _detectImageFormat(imageBytes);
    print('[OCR WEB] ÉTAPE 2 - Format détecté: $mimeType');
    print('[OCR WEB] ÉTAPE 2 - Magic bytes: ${imageBytes.take(8).map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
    
    print('[OCR WEB] ÉTAPE 3 - Conversion image en Blob...');
    // Convertir Uint8List en Blob avec le bon MIME type
    final blobParts = [imageBytes.toJS].toJS;
    final blob = web.Blob(blobParts, web.BlobPropertyBag(type: mimeType));
    
    print('[OCR WEB] ÉTAPE 4 - Création URL blob...');
    final imageUrl = web.URL.createObjectURL(blob);
    print('[OCR WEB] ÉTAPE 4 - URL créée: ${imageUrl.substring(0, 50)}...');
    
    print('[OCR WEB] ÉTAPE 5 - Chargement Tesseract.js...');
    
    // Créer un élément image
    final img = web.HTMLImageElement();
    img.src = imageUrl;
    
    // Attendre que l'image soit chargée
    await img.onLoad.first;
    print('[OCR WEB] ÉTAPE 5 - Image chargée: ${img.naturalWidth}x${img.naturalHeight} pixels');
    
    print('[OCR WEB] ÉTAPE 6 - Démarrage OCR avec Tesseract.js (lang: fra)...');
    final sw = Stopwatch()..start();
    
    // Appeler Tesseract
    final resultPromise = _tesseractRecognize(img, 'fra'.toJS);
    final result = await resultPromise.toDart;
    
    // Extraire le texte du résultat
    final resultObj = result as _TesseractResult;
    final text = resultObj.data.text;
    
    final elapsed = sw.elapsedMilliseconds;
    print('[OCR WEB] ÉTAPE 7 - OCR terminé en ${elapsed}ms');
    print('[OCR WEB] ÉTAPE 7 - Caractères extraits: ${text.length}');
    print('[OCR WEB] ═══════════════════════════════════════════════════════════');
    
    // Nettoyer
    web.URL.revokeObjectURL(imageUrl);
    
    return text.trim();
  } catch (e) {
    print('[OCR WEB] ❌ Erreur: $e');
    return '';
  }
}
