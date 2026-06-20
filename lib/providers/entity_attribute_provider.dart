import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/entity_attribute.dart';
import '../models/analytical_field.dart';
import '../services/cloud_repository.dart';

class EntityAttributeProvider extends ChangeNotifier {
  final CloudRepository _cloudRepo = CloudRepository();
  final Uuid _uuid = const Uuid();

  List<EntityAttribute> _attributes = [];
  List<EntityAttribute> get attributes => _attributes;

  String? _currentEntityId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadAttributes(String entityId) async {
    _currentEntityId = entityId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _attributes = await _cloudRepo.getEntityAttributes(entityId);
    } catch (e) {
      debugPrint('[EntityAttributeProvider] loadAttributes error: $e');
      _error = 'Erreur chargement attributs: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<EntityAttribute?> getAttributeById(String id) async {
    try {
      return await _cloudRepo.getEntityAttributeById(id);
    } catch (e) {
      debugPrint('[EntityAttributeProvider] getAttributeById error: $e');
      return null;
    }
  }

  Future<EntityAttribute> createAttribute({
    required String entityId,
    required String fieldId,
    required String attributeValue,
    String provenance = 'manual',
  }) async {
    final attribute = EntityAttribute(
      id: _uuid.v4(),
      entityId: entityId,
      fieldId: fieldId,
      attributeValue: attributeValue,
      provenance: provenance,
    );

    final created = await _cloudRepo.createEntityAttribute(attribute);

    if (_currentEntityId == entityId) {
      _attributes.add(created);
      notifyListeners();
    }

    return created;
  }

  Future<void> updateAttribute(EntityAttribute attribute) async {
    try {
      await _cloudRepo.updateEntityAttribute(attribute);

      final index = _attributes.indexWhere((a) => a.id == attribute.id);
      if (index != -1) {
        _attributes[index] = attribute;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[EntityAttributeProvider] updateAttribute error: $e');
      _error = 'Erreur mise à jour attribut: $e';
      notifyListeners();
    }
  }

  Future<void> deleteAttribute(String id) async {
    try {
      await _cloudRepo.deleteEntityAttribute(id);
      _attributes.removeWhere((a) => a.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('[EntityAttributeProvider] deleteAttribute error: $e');
      _error = 'Erreur suppression attribut: $e';
      notifyListeners();
    }
  }

  Future<List<EntityAttributeWithField>> getAttributesWithFields(
      String entityId, List<AnalyticalField> fields) async {
    try {
      final attributes = await _cloudRepo.getEntityAttributes(entityId);

      final fieldMap = <String, AnalyticalField>{
        for (var f in fields) f.id: f,
      };

      return attributes.where((attr) {
        return fieldMap.containsKey(attr.fieldId);
      }).map((attr) {
        return EntityAttributeWithField(
          attribute: attr,
          field: fieldMap[attr.fieldId]!,
        );
      }).toList();
    } catch (e) {
      debugPrint('[EntityAttributeProvider] getAttributesWithFields error: $e');
      return [];
    }
  }
}
