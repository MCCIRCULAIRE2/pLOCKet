import '../database_helper.dart';
import '../../models/event.dart';

class EventDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<void> insert(Event event) async {
    final db = await _db.database;
    await db.insert('events', event.toMap());
  }

  Future<void> update(Event event) async {
    final db = await _db.database;
    await db.update('events', event.toMap(), where: 'id = ?', whereArgs: [event.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  Future<Event?> getById(String id) async {
    final db = await _db.database;
    final maps = await db.query('events', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Event.fromMap(maps.first);
  }

  Future<List<Event>> getAll({String? orderBy = 'date DESC'}) async {
    final db = await _db.database;
    final maps = await db.query('events', orderBy: orderBy);
    return maps.map((m) => Event.fromMap(m)).toList();
  }

  Future<List<Event>> getByEntity(String entityId) async {
    final db = await _db.database;
    final maps = await db.query('events',
        where: 'entityId = ?', whereArgs: [entityId], orderBy: 'date DESC');
    return maps.map((m) => Event.fromMap(m)).toList();
  }

  Future<List<Event>> getByDocument(String documentId) async {
    final db = await _db.database;
    final maps = await db.query('events',
        where: 'documentId = ?', whereArgs: [documentId], orderBy: 'date DESC');
    return maps.map((m) => Event.fromMap(m)).toList();
  }

  Future<List<Event>> getRecent({int limit = 10}) async {
    final db = await _db.database;
    final maps = await db.query('events', orderBy: 'date DESC', limit: limit);
    return maps.map((m) => Event.fromMap(m)).toList();
  }
}
