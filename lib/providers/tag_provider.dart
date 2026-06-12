import 'package:flutter/foundation.dart';
import '../models/tag.dart';
import '../database/daos/tag_dao.dart';

class TagProvider extends ChangeNotifier {
  final TagDao _tagDao = TagDao();

  List<Tag> _tags = [];
  List<Tag> get tags => _tags;

  List<Tag> _typeTags = [];
  List<Tag> get typeTags => _typeTags;

  List<Tag> _domainTags = [];
  List<Tag> get domainTags => _domainTags;

  List<Tag> _subdomainTags = [];
  List<Tag> get subdomainTags => _subdomainTags;

  List<Tag> _statusTags = [];
  List<Tag> get statusTags => _statusTags;

  Future<void> loadTags() async {
    _tags = await _tagDao.getAll();
    _typeTags = _tags.where((t) => t.category == TagCategory.type).toList();
    _domainTags = _tags.where((t) => t.category == TagCategory.domain).toList();
    _subdomainTags = _tags.where((t) => t.category == TagCategory.subdomain).toList();
    _statusTags = _tags.where((t) => t.category == TagCategory.status).toList();
    notifyListeners();
  }

  Future<List<Tag>> searchTags(String query) async {
    return await _tagDao.search(query);
  }
}
