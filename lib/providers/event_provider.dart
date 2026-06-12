import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/event.dart';
import '../database/daos/event_dao.dart';

class EventProvider extends ChangeNotifier {
  final EventDao _eventDao = EventDao();
  final Uuid _uuid = const Uuid();

  List<Event> _events = [];
  List<Event> get events => _events;

  String? _error;
  String? get error => _error;

  Future<void> loadEvents() async {
    try {
      _events = await _eventDao.getAll();
    } catch (e) {
      _error = 'Erreur chargement événements: $e';
    }
    notifyListeners();
  }

  Future<Event?> createEvent({
    required String eventType,
    String? entityId,
    required DateTime date,
    required String description,
    Map<String, dynamic>? metadata,
    String? documentId,
  }) async {
    try {
      final event = Event(
        id: _uuid.v4(),
        eventType: eventType,
        entityId: entityId,
        date: date,
        description: description,
        metadata: metadata,
        documentId: documentId,
      );
      await _eventDao.insert(event);
      await loadEvents();
      return event;
    } catch (e) {
      _error = 'Erreur création événement: $e';
      notifyListeners();
      return null;
    }
  }

  Future<List<Event>> getByDocument(String documentId) async {
    try {
      return await _eventDao.getByDocument(documentId);
    } catch (e) {
      _error = 'Erreur chargement événements document: $e';
      notifyListeners();
      return [];
    }
  }

  Future<List<Event>> getRecent({int limit = 10}) async {
    try {
      return await _eventDao.getRecent(limit: limit);
    } catch (e) {
      _error = 'Erreur chargement événements récents: $e';
      notifyListeners();
      return [];
    }
  }
}
