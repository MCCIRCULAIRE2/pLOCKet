import 'package:flutter/foundation.dart';
import '../models/relation_type.dart';
import '../services/cloud_repository.dart';

class RelationTypeProvider extends ChangeNotifier {
  final CloudRepository _cloudRepo = CloudRepository();

  List<RelationType> _types = [];
  List<RelationType> get types => _types;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadTypes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _types = await _cloudRepo.getRelationTypes();
    } catch (e) {
      debugPrint('[RelationTypeProvider] loadTypes error: $e');
      _error = 'Erreur chargement types de relations: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  RelationType? getTypeById(String id) {
    try {
      return _types.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  RelationType? getTypeByCode(String code) {
    try {
      return _types.firstWhere((t) => t.code == code);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getInverseTypeId(String relationTypeId) async {
    try {
      return await _cloudRepo.getInverseRelationType(relationTypeId);
    } catch (e) {
      debugPrint('[RelationTypeProvider] getInverseTypeId error: $e');
      return null;
    }
  }

  Future<List<String>> getSynonyms(String relationTypeId) async {
    try {
      return await _cloudRepo.getRelationSynonyms(relationTypeId);
    } catch (e) {
      debugPrint('[RelationTypeProvider] getSynonyms error: $e');
      return [];
    }
  }

  Future<String?> getTypeIdBySynonym(String synonym) async {
    try {
      return await _cloudRepo.getRelationTypeBySynonym(synonym);
    } catch (e) {
      debugPrint('[RelationTypeProvider] getTypeIdBySynonym error: $e');
      return null;
    }
  }
}
