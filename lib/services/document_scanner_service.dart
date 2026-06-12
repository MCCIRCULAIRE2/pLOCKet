import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Service de prétraitement documentaire pour améliorer la qualité OCR
/// 
/// Pipeline de prétraitement :
/// 1. Détection format et décodage
/// 2. Correction orientation EXIF
/// 3. Redimensionnement intelligent (max 2000px)
/// 4. Conversion niveaux de gris
/// 5. Amélioration contraste
/// 6. Binarisation adaptative
class DocumentScannerService {
  static const int _maxDimension = 2000; // Taille max en pixels
  static const int _minDimension = 800;  // Taille min pour garder la lisibilité

  /// Prétraite une image pour optimiser l'OCR
  /// 
  /// [imageBytes] : Bytes de l'image originale
  /// Retourne : Bytes de l'image prétraitée (JPEG qualité 95%)
  Future<Uint8List> preprocessImage(Uint8List imageBytes) async {
    print('[PREPROCESS] ═══════════════════════════════════════════════════════════');
    print('[PREPROCESS] Début prétraitement documentaire');
    print('[PREPROCESS] Taille originale: ${imageBytes.length} octets');
    
    final sw = Stopwatch()..start();
    
    try {
      // ÉTAPE 1 : Décodage de l'image
      print('[PREPROCESS] ÉTAPE 1 - Décodage image...');
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        print('[PREPROCESS] ❌ Échec décodage image');
        return imageBytes; // Retourner l'image originale si échec
      }
      
      print('[PREPROCESS] ✓ Image décodée: ${originalImage.width}x${originalImage.height} pixels');
      print('[PREPROCESS]   Canaux: ${originalImage.numChannels}');
      
      img.Image processedImage = originalImage;
      
      // ÉTAPE 2 : Correction orientation EXIF
      print('[PREPROCESS] ÉTAPE 2 - Correction orientation EXIF...');
      processedImage = _fixOrientation(processedImage, imageBytes);
      print('[PREPROCESS] ✓ Orientation corrigée: ${processedImage.width}x${processedImage.height} pixels');
      
      // ÉTAPE 3 : Redimensionnement intelligent
      print('[PREPROCESS] ÉTAPE 3 - Redimensionnement intelligent...');
      processedImage = _smartResize(processedImage);
      print('[PREPROCESS] ✓ Image redimensionnée: ${processedImage.width}x${processedImage.height} pixels');
      
      // ÉTAPE 4 : Conversion niveaux de gris
      print('[PREPROCESS] ÉTAPE 4 - Conversion niveaux de gris...');
      processedImage = img.grayscale(processedImage);
      print('[PREPROCESS] ✓ Conversion niveaux de gris terminée');
      
      // ÉTAPE 5 : Amélioration contraste
      print('[PREPROCESS] ÉTAPE 5 - Amélioration contraste...');
      processedImage = _enhanceContrast(processedImage);
      print('[PREPROCESS] ✓ Contraste amélioré');
      
      // ÉTAPE 6 : Binarisation adaptative
      print('[PREPROCESS] ÉTAPE 6 - Binarisation adaptative...');
      processedImage = _adaptiveThreshold(processedImage);
      print('[PREPROCESS] ✓ Binarisation terminée');
      
      // ÉTAPE 7 : Débruitage (suppression pixels isolés)
      print('[PREPROCESS] ÉTAPE 7 - Débruitage...');
      processedImage = _denoise(processedImage);
      print('[PREPROCESS] ✓ Débruitage terminé');
      
      // ÉTAPE 8 : Encodage JPEG qualité 95%
      print('[PREPROCESS] ÉTAPE 8 - Encodage JPEG...');
      final processedBytes = img.encodeJpg(processedImage, quality: 95);
      
      final elapsed = sw.elapsedMilliseconds;
      print('[PREPROCESS] ✓ Image prétraitée: ${processedBytes.length} octets');
      print('[PREPROCESS] ✓ Temps total: ${elapsed}ms');
      print('[PREPROCESS] ═══════════════════════════════════════════════════════════');
      
      return processedBytes;
    } catch (e, stackTrace) {
      print('[PREPROCESS] ❌ Erreur prétraitement: $e');
      print('[PREPROCESS] Stack trace: $stackTrace');
      print('[PREPROCESS] Retour à l\'image originale');
      print('[PREPROCESS] ═══════════════════════════════════════════════════════════');
      return imageBytes; // Retourner l'image originale en cas d'erreur
    }
  }

  /// Corrige l'orientation basée sur les métadonnées EXIF
  /// Note: La bibliothèque `image` ne supporte pas la lecture EXIF complète
  /// Pour l'instant, on retourne l'image telle quelle
  img.Image _fixOrientation(img.Image image, Uint8List bytes) {
    try {
      final baked = img.bakeOrientation(image);
      if (baked.width != image.width || baked.height != image.height) {
        print('[PREPROCESS]   ✓ Orientation EXIF corrigée: ${image.width}x${image.height} → ${baked.width}x${baked.height}');
        return baked;
      }
      print('[PREPROCESS]   Orientation OK, pas de rotation nécessaire');
      return image;
    } catch (e) {
      print('[PREPROCESS]   ⚠ Erreur orientation EXIF: $e');
      return image;
    }
  }

  /// Redimensionne intelligemment en gardant le ratio
  /// - Si l'image est > 2000px, redimensionne à 2000px
  /// - Si l'image est < 800px, ne redimensionne pas
  /// - Sinon, garde la taille originale
  img.Image _smartResize(img.Image image) {
    final width = image.width;
    final height = image.height;
    final maxDim = width > height ? width : height;
    
    print('[PREPROCESS]   Dimensions actuelles: ${width}x$height');
    print('[PREPROCESS]   Dimension max: $maxDim');
    
    if (maxDim <= _maxDimension && maxDim >= _minDimension) {
      print('[PREPROCESS]   Taille optimale, pas de redimensionnement');
      return image;
    }
    
    if (maxDim < _minDimension) {
      print('[PREPROCESS]   Image trop petite, pas de redimensionnement');
      return image;
    }
    
    // Redimensionner en gardant le ratio
    final scale = _maxDimension / maxDim;
    final newWidth = (width * scale).round();
    final newHeight = (height * scale).round();
    
    print('[PREPROCESS]   Redimensionnement: ${width}x$height → ${newWidth}x$newHeight');
    
    return img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );
  }

  /// Améliore le contraste en étirant l'histogramme
  img.Image _enhanceContrast(img.Image image) {
    // Trouver les valeurs min et max
    int minVal = 255;
    int maxVal = 0;
    
    for (final pixel in image) {
      final r = pixel.r.toInt();
      if (r < minVal) minVal = r;
      if (r > maxVal) maxVal = r;
    }
    
    print('[PREPROCESS]   Histogramme: min=$minVal, max=$maxVal');
    
    // Si le contraste est déjà bon, ne rien faire
    if (maxVal - minVal > 200) {
      print('[PREPROCESS]   Contraste déjà bon, pas d\'amélioration');
      return image;
    }
    
    // Étirer l'histogramme
    final range = maxVal - minVal;
    if (range == 0) return image;
    
    final enhanced = img.Image.from(image);
    for (final pixel in enhanced) {
      final r = pixel.r.toInt();
      final normalized = ((r - minVal) * 255 / range).round().clamp(0, 255);
      pixel.r = normalized;
      pixel.g = normalized;
      pixel.b = normalized;
    }
    
    print('[PREPROCESS]   Contraste étiré: $minVal-$maxVal → 0-255');
    return enhanced;
  }

  /// Binarisation adaptative (seuil local)
  /// Divise l'image en blocs et applique un seuil adaptatif
  img.Image _adaptiveThreshold(img.Image image) {
    const blockSize = 15; // Taille du bloc pour le seuil local
    const c = 10; // Constante de correction
    
    final width = image.width;
    final height = image.height;
    final binary = img.Image.from(image);
    
    print('[PREPROCESS]   Binarisation adaptative (bloc=${blockSize}px, c=$c)');
    
    // Parcourir chaque pixel
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Calculer la moyenne locale
        int sum = 0;
        int count = 0;
        
        for (int dy = -blockSize; dy <= blockSize; dy++) {
          for (int dx = -blockSize; dx <= blockSize; dx++) {
            final nx = x + dx;
            final ny = y + dy;
            
            if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
              sum += image.getPixel(nx, ny).r.toInt();
              count++;
            }
          }
        }
        
        final localMean = sum / count;
        final pixel = image.getPixel(x, y).r.toInt();
        
        // Appliquer le seuil adaptatif
        final threshold = localMean - c;
        final binaryValue = pixel > threshold ? 255 : 0;
        
        binary.setPixelRgba(x, y, binaryValue, binaryValue, binaryValue, 255);
      }
    }
    
    return binary;
  }

  img.Image _denoise(img.Image image) {
    final width = image.width;
    final height = image.height;
    final cleaned = img.Image.from(image);
    int removed = 0;

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final pixel = image.getPixel(x, y).r.toInt();
        int sameCount = 0;

        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final neighbor = image.getPixel(x + dx, y + dy).r.toInt();
            if (neighbor == pixel) sameCount++;
          }
        }

        if (sameCount <= 1) {
          final majority = pixel == 0 ? 255 : 0;
          cleaned.setPixelRgba(x, y, majority, majority, majority, 255);
          removed++;
        }
      }
    }

    print('[PREPROCESS]   Pixels bruités supprimés: $removed');
    return cleaned;
  }
}
