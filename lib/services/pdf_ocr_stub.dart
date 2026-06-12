import 'dart:typed_data';

Future<PdfOcrResult> processPdfWeb(Uint8List bytes) async {
  return PdfOcrResult(text: '', method: 'unavailable', pages: 0, nativeChars: 0);
}

class PdfOcrResult {
  final String text;
  final String method;
  final int pages;
  final int nativeChars;
  final String? error;

  PdfOcrResult({
    required this.text,
    required this.method,
    required this.pages,
    required this.nativeChars,
    this.error,
  });
}
