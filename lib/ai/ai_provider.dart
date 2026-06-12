abstract class AIProvider {
  Future<String> analyze(String text, {String? prompt});
  Future<String> answer(String question, String context);
  Future<List<String>> suggestTags(String text);
  Future<Map<String, dynamic>> extractData(String text, List<String> fields);
}
