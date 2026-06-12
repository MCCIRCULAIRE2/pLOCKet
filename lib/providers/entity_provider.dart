import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/entity.dart';
import '../database/daos/entity_dao.dart';

class EntityProvider extends ChangeNotifier {
  final EntityDao _entityDao = EntityDao();
  final Uuid _uuid = const Uuid();

  List<Entity> _entities = [];
  List<Entity> get entities => _entities;

  Future<void> loadEntities() async {
    _entities = await _entityDao.getAll();
    notifyListeners();
  }

  Future<Entity> createEntity({
    required String entityType,
    required String name,
    Map<String, dynamic>? metadata,
  }) async {
    final entity = Entity(
      id: _uuid.v4(),
      entityType: entityType,
      name: name,
      metadata: metadata,
    );
    await _entityDao.insert(entity);
    await loadEntities();
    return entity;
  }

  Future<void> linkToDocument(String documentId, String entityId) async {
    await _entityDao.linkToDocument(documentId, entityId);
  }

  Future<List<Entity>> getForDocument(String documentId) async {
    return await _entityDao.getForDocument(documentId);
  }
}
