import '../database_helper.dart';
import '../../models/procedure.dart';

class ProcedureDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<void> insert(Procedure procedure) async {
    final db = await _db.database;
    await db.insert('procedures', procedure.toMap());
  }

  Future<void> update(Procedure procedure) async {
    final db = await _db.database;
    await db.update('procedures', procedure.toMap(),
        where: 'id = ?', whereArgs: [procedure.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('procedures', where: 'id = ?', whereArgs: [id]);
  }

  Future<Procedure?> getById(String id) async {
    final db = await _db.database;
    final maps = await db.query('procedures', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Procedure.fromMap(maps.first);
  }

  Future<List<Procedure>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('procedures', orderBy: 'title');
    return maps.map((m) => Procedure.fromMap(m)).toList();
  }

  Future<void> linkDocument(String procedureId, String documentId) async {
    final db = await _db.database;
    await db.insert('procedure_documents',
        {'procedureId': procedureId, 'documentId': documentId});
  }

  Future<List<Procedure>> search(String query) async {
    final db = await _db.database;
    final maps = await db.query('procedures',
        where: 'title LIKE ? OR description LIKE ?',
        whereArgs: ['%$query%', '%$query%']);
    return maps.map((m) => Procedure.fromMap(m)).toList();
  }
}
