import '../database_helper.dart';
import '../../models/entity.dart';

class EntityDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<void> insert(Entity entity) async {
    final db = await _db.database;
    await db.insert('entities', entity.toMap());
  }

  Future<void> update(Entity entity) async {
    final db = await _db.database;
    await db.update('entities', entity.toMap(), where: 'id = ?', whereArgs: [entity.id]);
  }

  Future<Entity?> getById(String id) async {
    final db = await _db.database;
    final maps = await db.query('entities', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Entity.fromMap(maps.first);
  }

  Future<List<Entity>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('entities', orderBy: 'name');
    return maps.map((m) => Entity.fromMap(m)).toList();
  }

  Future<List<Entity>> search(String query) async {
    final db = await _db.database;
    final maps = await db.query('entities',
        where: 'name LIKE ? OR entityType LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'name');
    return maps.map((m) => Entity.fromMap(m)).toList();
  }

  Future<void> linkToDocument(String documentId, String entityId) async {
    final db = await _db.database;
    await db.insert('document_entities',
        {'documentId': documentId, 'entityId': entityId});
  }

  Future<List<Entity>> getForDocument(String documentId) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT e.* FROM entities e
      INNER JOIN document_entities de ON e.id = de.entityId
      WHERE de.documentId = ?
    ''', [documentId]);
    return maps.map((m) => Entity.fromMap(m)).toList();
  }
}
