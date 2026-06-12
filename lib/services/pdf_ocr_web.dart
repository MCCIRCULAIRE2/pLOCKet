import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

Future<PdfOcrResult> processPdfWeb(Uint8List bytes) async {
  try {
    // Make a copy BEFORE converting to JS — .toJS can detach the ArrayBuffer
    final safeCopy = Uint8List.fromList(bytes);
    debugPrint('[TRACE] processPdfWeb: original bytes length=${bytes.length}, copy length=${safeCopy.length}');

    final pdfOcr = globalContext['_pdfOcr'] as JSObject?;
    if (pdfOcr == null) {
      return PdfOcrResult(text: '', method: 'failed', pages: 0, nativeChars: 0,
          error: 'pdf_ocr.js pas chargé');
    }

    final jsBytes = safeCopy.toJS;
    final promise = pdfOcr.callMethod<JSPromise>('processPdf'.toJS, jsBytes);
    final jsResult = await promise.toDart;

    final jsonStr = (jsResult as JSString).toDart;
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;

    return PdfOcrResult(
      text: map['text'] as String? ?? '',
      method: map['method'] as String? ?? 'failed',
      pages: map['pages'] as int? ?? 0,
      nativeChars: map['nativeChars'] as int? ?? 0,
      error: map['error'] as String?,
    );
  } catch (e) {
    return PdfOcrResult(
      text: '', method: 'failed', pages: 0, nativeChars: 0, error: e.toString(),
    );
  }
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
