import '../models/entity.dart';
import '../models/analytical_field.dart';
import '../models/entity_type.dart';
import '../models/relation_type.dart';
import '../services/cloud_repository.dart';

class QaSessionCache {
  Entity? meEntity;
  List<EntityAttributeWithField> meAttributes = [];
  List<EntityRelationWithEntities> meRelations = [];
  List<AnalyticalField> allFields = [];
  List<Entity> allEntities = [];
  Map<String, EntityType> entityTypesByCode = {};
  Map<String, RelationType> relationTypesByCode = {};
  DateTime? _cachedAt;

  bool get isValid {
    if (_cachedAt == null) return false;
    return DateTime.now().difference(_cachedAt!) < const Duration(minutes: 5);
  }

  void markLoaded() {
    _cachedAt = DateTime.now();
  }

  void invalidate() {
    _cachedAt = null;
    meEntity = null;
    meAttributes = [];
    meRelations = [];
    allFields = [];
    allEntities = [];
    entityTypesByCode = {};
    relationTypesByCode = {};
  }
}
