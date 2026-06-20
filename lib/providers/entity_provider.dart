import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/entity.dart';
import '../services/cloud_repository.dart';
import '../database/daos/entity_dao.dart';
import 'user_profile_provider.dart';
import 'entity_type_provider.dart';

class EntityProvider extends ChangeNotifier {
  final CloudRepository _cloudRepo = CloudRepository();
  final EntityDao _entityDao = EntityDao();
  final Uuid _uuid = const Uuid();

  List<Entity> _entities = [];
  List<Entity> get entities => _entities;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  String? _meEntityId;

  Future<void> loadEntities() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _entities = await _cloudRepo.getEntities();
    } catch (e) {
      debugPrint('[EntityProvider] loadEntities error: $e');
      _error = 'Erreur chargement entités: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Entity?> getEntityById(String id) async {
    try {
      return await _cloudRepo.getEntityById(id);
    } catch (e) {
      debugPrint('[EntityProvider] getEntityById error: $e');
      _error = 'Erreur récupération entité: $e';
      notifyListeners();
      return null;
    }
  }

  Future<List<Entity>> getEntitiesByType(String entityTypeId) async {
    try {
      return await _cloudRepo.getEntitiesByType(entityTypeId);
    } catch (e) {
      debugPrint('[EntityProvider] getEntitiesByType error: $e');
      _error = 'Erreur récupération entités par type: $e';
      notifyListeners();
      return [];
    }
  }

  Future<Entity> createEntity({
    required String entityTypeId,
    required String label,
  }) async {
    final entity = Entity(
      id: _uuid.v4(),
      userId: '',
      entityTypeId: entityTypeId,
      label: label,
    );

    final created = await _cloudRepo.createEntity(entity);
    await loadEntities();
    return created;
  }

  Future<void> updateEntity(Entity entity) async {
    try {
      await _cloudRepo.updateEntity(entity);
      await loadEntities();
    } catch (e) {
      debugPrint('[EntityProvider] updateEntity error: $e');
      _error = 'Erreur mise à jour entité: $e';
      notifyListeners();
    }
  }

  Future<void> deleteEntity(String id) async {
    try {
      await _cloudRepo.deleteEntity(id);
      await loadEntities();
    } catch (e) {
      debugPrint('[EntityProvider] deleteEntity error: $e');
      _error = 'Erreur suppression entité: $e';
      notifyListeners();
    }
  }

  Future<Entity?> getMeEntity({
    required UserProfileProvider userProfileProvider,
    required EntityTypeProvider entityTypeProvider,
  }) async {
    _error = null;

    try {
      if (_meEntityId != null) {
        final entity = await _cloudRepo.getEntityById(_meEntityId!);
        if (entity != null) {
          return entity;
        }
        _meEntityId = null;
      }

      final profile = userProfileProvider.profile;
      if (profile?.primaryPersonEntityId != null) {
        final entity =
            await _cloudRepo.getEntityById(profile!.primaryPersonEntityId!);
        if (entity != null) {
          _meEntityId = entity.id;
          return entity;
        }
      }

      final personType = entityTypeProvider.getTypeByCode('personne');
      if (personType == null) {
        _error = "Type d'entité personne introuvable";
        notifyListeners();
        return null;
      }

      final label = (profile?.fullName.isNotEmpty == true)
          ? profile!.fullName
          : 'Moi';

      final entity = Entity(
        id: _uuid.v4(),
        userId: '',
        entityTypeId: personType.id,
        label: label,
      );

      final created = await _cloudRepo.createEntity(entity);

      await userProfileProvider.setPrimaryPersonEntity(created.id);
      _meEntityId = created.id;

      await loadEntities();
      return created;
    } catch (e) {
      debugPrint('[EntityProvider] getMeEntity error: $e');
      _error = 'Erreur récupération entité principale: $e';
      notifyListeners();
      return null;
    }
  }

  Future<void> linkToDocument(String documentId, String entityId) async {
    await _entityDao.linkToDocument(documentId, entityId);
  }

  Future<List<Entity>> getForDocument(String documentId) async {
    return await _entityDao.getForDocument(documentId);
  }
}
