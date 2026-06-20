import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/analytical_relation.dart';
import '../services/cloud_repository.dart';

class RelationProvider extends ChangeNotifier {
  final CloudRepository _cloudRepo = CloudRepository();
  final Uuid _uuid = const Uuid();

  List<AnalyticalRelation> _relations = [];
  List<AnalyticalRelation> get relations => _relations;

  String? _currentEntityId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadRelations(String entityId) async {
    _currentEntityId = entityId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final outgoing = await _cloudRepo.getRelationsBySourceEntity(entityId);
      final incoming = await _cloudRepo.getRelationsByTargetEntity(entityId);
      _relations = [...outgoing, ...incoming];
    } catch (e) {
      debugPrint('[RelationProvider] loadRelations error: $e');
      _error = 'Erreur chargement relations: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<AnalyticalRelation> createRelation({
    required String sourceEntityId,
    required String targetEntityId,
    required String relationTypeId,
  }) async {
    final relation = AnalyticalRelation(
      id: _uuid.v4(),
      userId: '',
      sourceEntityId: sourceEntityId,
      targetEntityId: targetEntityId,
      relationTypeId: relationTypeId,
    );

    final created = await _cloudRepo.createRelation(relation);

    if (_currentEntityId == sourceEntityId || _currentEntityId == targetEntityId) {
      _relations.add(created);
      notifyListeners();
    }

    return created;
  }

  Future<void> updateRelation(AnalyticalRelation relation) async {
    try {
      await _cloudRepo.updateRelation(relation);

      final index = _relations.indexWhere((r) => r.id == relation.id);
      if (index != -1) {
        _relations[index] = relation;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[RelationProvider] updateRelation error: $e');
      _error = 'Erreur mise à jour relation: $e';
      notifyListeners();
    }
  }

  Future<void> deleteRelation(String id) async {
    try {
      await _cloudRepo.deleteRelation(id);
      _relations.removeWhere((r) => r.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('[RelationProvider] deleteRelation error: $e');
      _error = 'Erreur suppression relation: $e';
      notifyListeners();
    }
  }

  Future<List<EntityRelationWithEntities>> getAllRelationsWithDetails(
      String entityId) async {
    try {
      return await _cloudRepo.getAllEntityRelations(entityId);
    } catch (e) {
      debugPrint('[RelationProvider] getAllRelationsWithDetails error: $e');
      _error = 'Erreur récupération relations détaillées: $e';
      notifyListeners();
      return [];
    }
  }

  Future<EntityWithDetails?> getEntityWithDetails(String entityId) async {
    try {
      return await _cloudRepo.getEntityWithDetails(entityId);
    } catch (e) {
      debugPrint('[RelationProvider] getEntityWithDetails error: $e');
      _error = 'Erreur récupération entité détaillée: $e';
      notifyListeners();
      return null;
    }
  }
}
