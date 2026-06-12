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

Future<String> extractTextFromImageWeb(Uint8List imageBytes) async {
  try {
    print('[OCR WEB] Conversion image en Blob...');
    
    // Convertir Uint8List en Blob
    final blobParts = [imageBytes.toJS].toJS;
    final blob = web.Blob(blobParts, web.BlobPropertyBag(type: 'image/jpeg'));
    
    print('[OCR WEB] Création URL blob...');
    final imageUrl = web.URL.createObjectURL(blob);
    
    print('[OCR WEB] Chargement Tesseract.js...');
    
    // Créer un élément image
    final img = web.HTMLImageElement();
    img.src = imageUrl;
    
    // Attendre que l'image soit chargée
    await img.onLoad.first;
    
    print('[OCR WEB] Démarrage OCR avec Tesseract.js (lang: fra)...');
    final sw = Stopwatch()..start();
    
    // Appeler Tesseract
    final resultPromise = _tesseractRecognize(img, 'fra'.toJS);
    final result = await resultPromise.toDart;
    
    // Extraire le texte du résultat
    final resultObj = result as _TesseractResult;
    final text = resultObj.data.text;
    
    final elapsed = sw.elapsedMilliseconds;
    print('[OCR WEB] ✓ OCR terminé en ${elapsed}ms');
    print('[OCR WEB] Caractères extraits: ${text.length}');
    
    // Nettoyer
    web.URL.revokeObjectURL(imageUrl);
    
    return text.trim();
  } catch (e) {
    print('[OCR WEB] ❌ Erreur: $e');
    return '';
  }
}
