import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<String?> createBlobUrl(Uint8List bytes, String mimeType) async {
  try {
    final blobParts = [bytes.toJS].toJS;
    final options = web.BlobPropertyBag(type: mimeType);
    final blob = web.Blob(blobParts, options);
    final url = web.URL.createObjectURL(blob);
    return url;
  } catch (e) {
    print('[BLOB] Error creating blob URL: $e');
    return null;
  }
}

void revokeBlobUrl(String url) {
  try {
    web.URL.revokeObjectURL(url);
  } catch (e) {
    print('[BLOB] Error revoking blob URL: $e');
  }
}
