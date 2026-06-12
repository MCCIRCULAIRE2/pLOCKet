import 'package:flutter/foundation.dart';
import '../services/intelligent_search.dart';

class SearchProvider extends ChangeNotifier {
  final IntelligentSearch _intelligentSearch = IntelligentSearch();

  List<AnswerResult> _results = [];
  List<AnswerResult> get results => _results;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  String _lastQuery = '';
  String get lastQuery => _lastQuery;

  static const int _maxHistory = 10;
  final List<String> _recentQueries = [];
  List<String> get recentQueries => List.unmodifiable(_recentQueries);

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _results = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    _lastQuery = query;
    _addToHistory(query);
    notifyListeners();

    _results = await _intelligentSearch.search(query);

    _isSearching = false;
    notifyListeners();
  }

  void _addToHistory(String query) {
    _recentQueries.remove(query);
    _recentQueries.insert(0, query);
    if (_recentQueries.length > _maxHistory) {
      _recentQueries.removeLast();
    }
  }

  void clearResults() {
    _results = [];
    _lastQuery = '';
    notifyListeners();
  }

  void clearLastQuery() {
    _lastQuery = '';
    notifyListeners();
  }
}
