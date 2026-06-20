import 'package:flutter/foundation.dart';
import '../models/entity_type.dart';
import '../services/cloud_repository.dart';

class EntityTypeProvider extends ChangeNotifier {
  final CloudRepository _cloudRepo = CloudRepository();

  List<EntityType> _types = [];
  List<EntityType> get types => _types;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadTypes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _types = await _cloudRepo.getEntityTypes();
    } catch (e) {
      debugPrint('[EntityTypeProvider] loadTypes error: $e');
      _error = 'Erreur chargement types d\'entités: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  EntityType? getTypeById(String id) {
    try {
      return _types.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  EntityType? getTypeByCode(String code) {
    try {
      return _types.firstWhere((t) => t.code == code);
    } catch (_) {
      return null;
    }
  }
}
