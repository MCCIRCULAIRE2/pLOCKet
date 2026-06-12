abstract class OCRProvider {
  Future<String> extractText(String imagePath);
  Future<String> extractTextFromBytes(List<int> bytes);
}

class OCRResult {
  final String text;
  final double confidence;

  OCRResult({required this.text, required this.confidence});
}
